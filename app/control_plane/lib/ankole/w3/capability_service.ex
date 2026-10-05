defmodule Ankole.W3.CapabilityService do
  @moduledoc """
  Lifecycle operations for Company-scoped Capabilities.

  This layer owns issuance, revocation, expiry, consumption, and
  attenuation validation. It delegates persistence to `CapabilityStore`
  and performs cross-cutting invariants before touching the database.

  This module does not implement risk classification, approval workflow,
  Action Assurance, broker mediation, or W2 integration. Those belong
  to later W3 packages.
  """

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.PrincipalKey
  alias Ankole.Principals.Principal
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityStore
  alias Ankole.W3.Resource

  # A delegation chain deeper than this is refused rather than walked. The
  # visited set already rejects cycles, so this only bounds an acyclic chain
  # that a caller could otherwise grow without limit.
  @max_parent_chain_depth 64

  # ─── public API ──────────────────────────────────────────────────────────

  @doc """
  Issues a new Capability inside the caller's Company.

  Validates the issuer is an active member of the Company. If a
  `parent_capability_uid` is supplied, enforces MA-06 §12 attenuation:
  the child capability must not exceed the parent's authority.

  A child issuance locks its parent with `FOR UPDATE` and commits the child
  in the same transaction, so a parent that changes state concurrently cannot
  pass attenuation and then change before the child exists.
  """
  @spec issue_capability(Ecto.Repo.t(), map()) ::
          {:ok, Capability.t()} | {:error, term()}
  def issue_capability(repo, attrs) do
    case fetch_attr(attrs, :parent_capability_uid) do
      {:ok, parent_uid} when not is_nil(parent_uid) -> issue_child_capability(repo, attrs)
      _ -> do_issue_capability(repo, attrs)
    end
  end

  # A child issuance reads its parent with FOR UPDATE, so the lock must be
  # held until the child row is committed. When the caller already owns the
  # transaction, its lock lasts for that transaction. Otherwise this opens one
  # so the parent lock and the child insert share a transaction.
  defp issue_child_capability(repo, attrs) do
    if repo.in_transaction?() do
      do_issue_capability(repo, attrs)
    else
      repo.transact(fn tx -> do_issue_capability(tx, attrs) end)
    end
  end

  defp do_issue_capability(repo, attrs) do
    case fetch_attr(attrs, :company_uid) do
      {:ok, company_uid} ->
        case assert_company_exists(repo, company_uid) do
          :ok ->
            case fetch_active_principal(repo, attrs, :principal_uid) do
              {:ok, principal_uid} ->
                case assert_member(repo, company_uid, principal_uid) do
                  :ok ->
                    case fetch_active_principal(repo, attrs, :issued_by_principal_uid) do
                      {:ok, issuer_uid} ->
                        case assert_member(repo, company_uid, issuer_uid) do
                          :ok ->
                            case PrincipalKey.normalize(fetch_attr_or_string(attrs, :uid)) do
                              {:ok, normalized_uid} ->
                                case assert_unique_uid(repo, normalized_uid) do
                                  :ok ->
                                    case check_attenuation(repo, company_uid, attrs) do
                                      :ok -> insert_capability(repo, attrs, company_uid, principal_uid, issuer_uid, normalized_uid)
                                      {:error, reason} -> {:error, reason}
                                    end
                                  {:error, {:duplicate, :uid}} -> {:error, {:duplicate, :uid}}
                                end
                              {:error, _} = err -> err
                            end
                          {:error, reason} -> {:error, reason}
                        end
                      {:error, reason} -> {:error, reason}
                    end
                  {:error, reason} -> {:error, reason}
                end
              {:error, reason} -> {:error, reason}
            end
          {:error, reason} -> {:error, reason}
        end
      :error -> {:error, :missing_required_attribute}
    end
  end

  @doc """
  Revokes a Capability by UID within a Company.

  The row is locked before the state decision, so the first transaction to take
  the lock performs the transition and every later one sees the committed result.
  The revoker must be an active Company member. Revocation is irreversible: an
  already revoked Capability fails closed with `:already_revoked`, and a consumed
  or expired one fails closed with its own reason.
  """
  @spec revoke_capability(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          {:ok, Capability.t()} | {:error, term()}
  def revoke_capability(repo, company_uid, capability_uid, revoker_uid) do
    CapabilityStore.with_capability_lock(repo, company_uid, capability_uid, fn tx, capability ->
      with {:ok, normalized_revoker} <- PrincipalKey.normalize(revoker_uid),
           %Principal{status: :active} <- tx.get(Principal, normalized_revoker),
           true <- MembershipStore.member?(tx, company_uid, normalized_revoker) do
        CapabilityStore.revoke_locked(tx, capability)
      else
        false -> {:error, :principal_not_in_company}
        {:error, _} -> {:error, :invalid_uid}
        # A Principal that is absent or not active is one condition.
        _ -> {:error, :principal_disabled}
      end
    end)
  end

  @doc """
  Expires a Capability by UID within a Company.

  The row is locked before the state decision, so the first transaction to take
  the lock performs the transition and every later one sees the committed result.
  An already expired Capability fails closed with `:already_expired`.
  """
  @spec expire_capability(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Capability.t()} | {:error, term()}
  def expire_capability(repo, company_uid, capability_uid) do
    CapabilityStore.with_capability_lock(repo, company_uid, capability_uid, fn tx, capability ->
      CapabilityStore.expire_locked(tx, capability)
    end)
  end

  @doc """
  Validates whether a Capability is currently usable per MA-06 §11.
  """
  @spec validate_capability(Ecto.Repo.t(), String.t(), String.t(), keyword()) ::
          :ok | {:error, atom()}
  def validate_capability(repo, company_uid, capability_uid, opts \\ []) do
    case CapabilityStore.fetch_capability(repo, company_uid, capability_uid) do
      {:ok, %Capability{status: :active} = capability} ->
        check_validation(repo, company_uid, capability, opts)

      {:ok, %Capability{status: :consumed}} -> {:error, :already_consumed}
      {:ok, %Capability{status: :expired}} -> {:error, :expired}
      {:ok, %Capability{status: :revoked}} -> {:error, :revoked}
      {:error, :not_found} -> {:error, :not_found}
      {:error, :company_not_found} -> {:error, :not_found}
      {:error, :invalid_uid} -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Validates exact binding between a Capability and explicit intent.
  Called from ActionAssurance with all required parameters.
  """
  @spec validate_capability(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t(), String.t(), String.t(), String.t(), map(), map()) ::
          :ok | {:error, atom()}
  def validate_capability(repo, company_uid, capability_uid, action, principal_uid, resource, risk_class, approval_uid, scope, constraints) do
    case CapabilityStore.fetch_capability(repo, company_uid, capability_uid) do
      {:ok, %Capability{status: :active} = capability} ->
        check_validation(repo, company_uid, capability, [
          action: action,
          principal_uid: principal_uid,
          resource: resource,
          risk_class: risk_class,
          approval_uid: approval_uid,
          scope: scope,
          constraints: constraints
        ])

      {:ok, %Capability{status: :consumed}} -> {:error, :already_consumed}
      {:ok, %Capability{status: :expired}} -> {:error, :expired}
      {:ok, %Capability{status: :revoked}} -> {:error, :revoked}
      {:error, :not_found} -> {:error, :not_found}
      {:error, :company_not_found} -> {:error, :not_found}
      {:error, :invalid_uid} -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Checks whether a child capability properly attenuates its parent per MA-06 §12.
  Returns `:ok` when no parent exists (top-level capability).

  The parent is read Company-scoped with `FOR UPDATE`, so a parent whose
  state changes concurrently cannot pass this check and then change before the
  child is inserted. `issue_capability/2` wraps the read and the insert in one
  transaction.
  """
  @spec check_attenuation(Ecto.Repo.t(), String.t(), map()) :: :ok | {:error, term()}
  def check_attenuation(repo, company_uid, attrs) when is_map(attrs) do
    case fetch_attr(attrs, :parent_capability_uid) do
      {:ok, nil} -> :ok
      :error -> :ok
      {:ok, parent_uid} -> do_check_attenuation(repo, company_uid, attrs, parent_uid)
    end
  end

  defp do_check_attenuation(repo, company_uid, attrs, parent_uid) do
    case fetch_locked_parent(repo, company_uid, parent_uid) do
      {:ok, parent} -> check_attenuation_attrs(attrs, parent)
      {:error, _} = error -> error
    end
  end

  defp fetch_locked_parent(repo, company_uid, parent_uid) do
    case CapabilityStore.fetch_capability_for_update(repo, company_uid, parent_uid) do
      {:ok, %Capability{status: :active} = parent} ->
        {:ok, parent}

      {:ok, %Capability{}} ->
        {:error, :parent_capability_invalid}

      {:error, :not_found} ->
        {:error, :parent_capability_not_found}

      {:error, :company_not_found} ->
        {:error, :parent_capability_not_found}

      {:error, :invalid_uid} ->
        {:error, :parent_capability_not_found}

      nil ->
        {:error, :parent_capability_not_found}
    end
  rescue
    ArgumentError -> {:error, :parent_capability_not_found}
  end

  # ─── private helpers ────────────────────────────────────────────────────

  defp insert_capability(repo, attrs, company_uid, principal_uid, issuer_uid, normalized_uid) do
    merged =
      attrs
      |> Map.put(:company_uid, company_uid)
      |> Map.put(:principal_uid, principal_uid)
      |> Map.put(:issued_by_principal_uid, issuer_uid)
      |> Map.put(:uid, normalized_uid)
      |> Map.put_new(:scope, %{})
      |> Map.put_new(:constraints, %{})
      |> Map.put_new(:metadata, %{})
      |> Map.delete(:id)

    %Capability{}
    |> Capability.changeset(merged)
    |> repo.insert()
  end

  defp check_validation(repo, company_uid, %Capability{} = capability, opts) do
    with :ok <- check_principal_active(repo, capability.principal_uid),
         :ok <- check_issuer_active(repo, capability.issued_by_principal_uid),
         :ok <- check_not_expired(capability),
         :ok <- check_not_revoked(capability),
         :ok <- check_ancestry(repo, company_uid, capability),
         :ok <- check_action_match(capability, opts),
         :ok <- validate_exact_binding(capability, opts) do
      :ok
    end
  end

  # ─── Public exact-binding validator ─────────────────────────────────────────

  @doc """
  Validates exact binding between a fetched Capability struct and expected intent.

  Pure function: no DB access, no locks, no mutations. Safe to call against
  an already-fetched, eventually locked Capability struct.

  Expected keys:
  - :principal_uid (binary, normalized)
  - :action (binary, lowercased)
  - :resource (binary, exact canonical)
  - :risk_class (binary)
  - :approval_uid (binary or nil)
  - :scope (map)
  - :constraints (map)

  Returns :ok or {:error, reason}.
  """
  def validate_exact_binding(capability, expected) do
    with :ok <- check_principal_match(capability, expected),
         :ok <- check_action_match(capability, expected),
         :ok <- check_resource_match(capability, expected),
         :ok <- check_risk_class_match(capability, expected),
         :ok <- check_approval_linkage(capability, expected),
         :ok <- check_scope_match(capability, expected),
         :ok <- check_constraints_match(capability, expected) do
      :ok
    end
  end

  defp check_principal_active(repo, principal_uid) do
    case repo.get(Principal, principal_uid) do
      %Principal{status: :active} -> :ok
      %Principal{} -> {:error, :principal_disabled}
      nil -> {:error, :principal_not_found}
    end
  end

  defp check_issuer_active(repo, issuer_uid) do
    case repo.get(Principal, issuer_uid) do
      %Principal{status: :active} -> :ok
      %Principal{} -> {:error, :issuer_disabled}
      nil -> {:error, :issuer_not_found}
    end
  end

  defp check_not_expired(%Capability{expires_at: nil}), do: :ok
  defp check_not_expired(%Capability{expires_at: expires_at}) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :gt -> :ok
      _ -> {:error, :expired}
    end
  end

  defp check_not_revoked(%Capability{revoked_at: nil}), do: :ok
  defp check_not_revoked(%Capability{revoked_at: _}), do: {:error, :revoked}

  # A Capability carries its lifecycle state in `status` only. A row moved to
  # `:expired` or `:revoked` by a lifecycle transition has no `expires_at` or
  # `revoked_at` to read, so the status is the sole proof that the Capability
  # is unusable. Validation must gate on it, not on the nullable timestamps.
  defp check_active_status(%Capability{status: :active}), do: :ok
  defp check_active_status(%Capability{} = capability), do: consume_error(capability)

  # ─── parent chain ─────────────────────────────────────────────────────────

  # One delegation step is not enough. A grandchild's authority comes from its
  # whole chain, so every ancestor is validated against the same operational
  # contract as the child itself. Every hop is Company-scoped through the
  # child's own Company, so a forged cross-Company reference fails closed.
  defp check_ancestry(repo, company_uid, capability) do
    check_ancestry(repo, company_uid, capability, MapSet.new([capability.uid]), 0)
  end

  defp check_ancestry(_repo, _company_uid, _capability, _visited, depth)
       when depth > @max_parent_chain_depth do
    {:error, :parent_chain_too_deep}
  end

  defp check_ancestry(repo, company_uid, capability, visited, depth) do
    case capability.parent_capability_uid do
      nil ->
        :ok

      parent_uid ->
        cond do
          MapSet.member?(visited, parent_uid) ->
            {:error, :parent_capability_cycle}

          true ->
            case fetch_ancestor(repo, company_uid, parent_uid) do
              {:ok, ancestor} ->
                case check_ancestor_operational(repo, ancestor) do
                  :ok ->
                    check_ancestry(
                      repo,
                      company_uid,
                      ancestor,
                      MapSet.put(visited, parent_uid),
                      depth + 1
                    )

                  {:error, _} = error ->
                    error
                end

              {:error, _} = error ->
                error
            end
        end
    end
  end

  defp fetch_ancestor(repo, company_uid, parent_uid) do
    case CapabilityStore.fetch_capability(repo, company_uid, parent_uid) do
      {:ok, %Capability{} = ancestor} -> {:ok, ancestor}
      _ -> {:error, :parent_capability_not_found}
    end
  rescue
    ArgumentError -> {:error, :parent_capability_not_found}
  end

  defp check_ancestor_operational(repo, ancestor) do
    with :ok <- check_ancestor_active(ancestor),
         :ok <- check_not_expired(ancestor),
         :ok <- check_not_revoked(ancestor),
         :ok <- check_principal_active(repo, ancestor.principal_uid),
         :ok <- check_issuer_active(repo, ancestor.issued_by_principal_uid) do
      :ok
    else
      {:error, _} -> {:error, :parent_capability_invalid}
    end
  end

  defp check_ancestor_active(%Capability{status: :active}), do: :ok
  defp check_ancestor_active(%Capability{}), do: {:error, :parent_capability_invalid}

  # ─── Capability Consumption ────────────────────────────────────────────────

  @doc """
  Consumes an already-locked Capability within the same transaction.

  Expects the Capability row to already be locked by the caller (via
  fetch_capability_for_update/3 or equivalent). Validates that the Capability
  is still :active, then atomically updates status to :consumed.

  No additional row lock is taken. The caller's transaction must already
  hold the FOR UPDATE lock on the Capability row.

  Returns {:ok, updated_capability} or {:error, reason}.
  """
  @spec consume_locked(Ecto.Repo.t(), Capability.t()) ::
          {:ok, Capability.t()} | {:error, atom()}
  def consume_locked(repo, capability) do
    if capability.status != :active do
      consume_error(capability)
    else
      case Capability.changeset(capability, %{status: :consumed}) |> repo.update() do
        {:ok, updated} -> {:ok, updated}
        {:error, _} -> {:error, :consumption_failed}
      end
    end
  end

  defp consume_error(%Capability{status: :consumed}), do: {:error, :already_consumed}
  defp consume_error(%Capability{status: :revoked}), do: {:error, :revoked}
  defp consume_error(%Capability{status: :expired}), do: {:error, :expired}
  defp consume_error(_), do: {:error, :invalid_state}

  @doc """
  Validates operational checks for a pre-fetched Capability struct.

  Does not fetch from DB. Reuses existing operational validation logic.
  Caller must ensure the Capability is already fetched and locked if needed.

  Checks:
  - status is :active
  - Principal is active
  - Issuer is active
  - Not expired
  - Not revoked
  - Not consumed
  - Parent is active (if present)

  Returns :ok or {:error, reason}.
  """
  @spec validate_prefetched_capability(Ecto.Repo.t(), Capability.t()) ::
          :ok | {:error, atom()}
  def validate_prefetched_capability(repo, capability) do
    with :ok <- check_active_status(capability),
         :ok <- check_not_expired(capability),
         :ok <- check_not_revoked(capability),
         :ok <- check_principal_active(repo, capability.principal_uid),
         :ok <- check_issuer_active(repo, capability.issued_by_principal_uid),
         :ok <- check_ancestry(repo, capability.company_uid, capability) do
      :ok
    end
  end

  

  defp check_principal_match(capability, expected) do
    expected_principal = Keyword.get(expected, :principal_uid)
    if is_nil(expected_principal) do
      :ok
    else
      with {:ok, norm} <- PrincipalKey.normalize(expected_principal) do
        if capability.principal_uid == norm, do: :ok, else: {:error, :principal_mismatch}
      end
    end
  end

  defp check_action_match(capability, expected) do
    expected_action = Keyword.get(expected, :action)
    if is_nil(expected_action) do
      :ok
    else
      norm_expected = String.downcase(String.trim(expected_action))
      if capability.action == norm_expected, do: :ok, else: {:error, :action_mismatch}
    end
  end

  defp check_resource_match(capability, expected) do
    expected_resource = Keyword.get(expected, :resource)
    if is_nil(expected_resource) do
      :ok
    else
      # Validate exact resource: must pass normalize_exact/1 and match byte-for-byte
      case Resource.normalize_exact(expected_resource) do
        {:ok, normalized} ->
          if capability.resource == normalized, do: :ok, else: {:error, :resource_mismatch}
        {:error, _} ->
          {:error, :resource_mismatch}
      end
    end
  end

  defp check_risk_class_match(capability, expected) do
    expected_risk = Keyword.get(expected, :risk_class)
    if is_nil(expected_risk) do
      :ok
    else
      if capability.risk_class == expected_risk, do: :ok, else: {:error, :risk_class_mismatch}
    end
  end

  defp check_approval_linkage(capability, expected) do
    expected_approval = Keyword.get(expected, :approval_uid)
    case expected_approval do
      nil ->
        if is_nil(capability.approval_uid), do: :ok, else: {:error, :approval_mismatch}
      _ ->
        if capability.approval_uid == expected_approval, do: :ok, else: {:error, :approval_mismatch}
    end
  end

  defp check_scope_match(capability, expected) do
    expected_scope = Keyword.get(expected, :scope)
    if is_nil(expected_scope) do
      :ok
    else
      if capability.scope == expected_scope, do: :ok, else: {:error, :scope_mismatch}
    end
  end

  defp check_constraints_match(capability, expected) do
    expected_constraints = Keyword.get(expected, :constraints)
    if is_nil(expected_constraints) do
      :ok
    else
      if capability.constraints == expected_constraints, do: :ok, else: {:error, :constraints_mismatch}
    end
  end

  defp check_attenuation_attrs(attrs, parent) do
    with :ok <- check_child_principal(attrs, parent),
         :ok <- check_child_trimmed(attrs, :action, parent.action, &String.downcase/1),
         :ok <- check_child_trimmed(attrs, :resource, parent.resource, & &1),
         :ok <- check_child_trimmed(attrs, :risk_class, parent.risk_class, & &1),
         :ok <- check_child_approval(attrs, parent),
         :ok <- check_child_map(attrs, :scope, parent.scope),
         :ok <- check_child_map(attrs, :constraints, parent.constraints),
         :ok <- check_child_expiry(attrs, parent) do
      :ok
    else
      {:error, :attenuation_violation} -> {:error, :attenuation_violation}
    end
  end

  defp attenuation_violation, do: {:error, :attenuation_violation}

  # Every comparison runs on the value the issuance path will persist, so a
  # child cannot pass attenuation with one representation and be stored with
  # another. `Capability.changeset/2` trims `:action`, `:resource`, and
  # `:risk_class` and downcases `:action`, so the same normalization is applied
  # before comparing against the already-persisted parent.
  defp check_child_trimmed(attrs, key, parent_value, transform) do
    case fetch_attr(attrs, key) do
      {:ok, value} when is_binary(value) ->
        if parent_value == value |> String.trim() |> transform.() do
          :ok
        else
          attenuation_violation()
        end

      _ ->
        attenuation_violation()
    end
  end

  defp check_child_principal(attrs, parent) do
    with {:ok, raw} <- fetch_attr(attrs, :principal_uid),
         {:ok, normalized} <- PrincipalKey.normalize(raw) do
      if parent.principal_uid == normalized, do: :ok, else: attenuation_violation()
    else
      {:error, _} -> attenuation_violation()
    end
  end

  # An absent `approval_uid` is persisted as nil, so an absent child approval
  # must equal a nil parent approval and differ from a parent that carries one.
  defp check_child_approval(attrs, parent) do
    case fetch_attr(attrs, :approval_uid) do
      {:ok, value} -> if value == parent.approval_uid, do: :ok, else: attenuation_violation()
      :error -> if is_nil(parent.approval_uid), do: :ok, else: attenuation_violation()
    end
  end

  # An absent `scope` or `constraints` is persisted as an empty map, so that
  # empty map is the value compared against the parent's.
  defp check_child_map(attrs, key, parent_value) do
    value =
      case fetch_attr(attrs, key) do
        {:ok, given} -> given
        :error -> %{}
      end

    if value == parent_value, do: :ok, else: attenuation_violation()
  end

  # `expires_at` nil means unbounded lifetime, so a child of a bounded parent
  # may not leave its expiry open.
  defp check_child_expiry(attrs, parent) do
    child =
      case fetch_attr(attrs, :expires_at) do
        {:ok, value} -> value
        :error -> nil
      end

    case {parent.expires_at, child} do
      {nil, _} -> :ok
      {_, nil} -> attenuation_violation()
      {parent_expiry, child_expiry} -> if DateTime.compare(child_expiry, parent_expiry) == :gt, do: attenuation_violation(), else: :ok
    end
  end

  defp assert_company_exists(repo, company_uid) do
    case repo.get_by(Company, uid: company_uid) do
      %Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp fetch_active_principal(repo, attrs, key) do
    case fetch_attr_or_string_attrs(attrs, key) do
      {:ok, raw} ->
        case PrincipalKey.normalize(raw) do
          {:ok, normalized} ->
            case repo.get(Principal, normalized) do
              %Principal{status: :active} -> {:ok, normalized}
              %Principal{status: :disabled} -> {:error, :principal_disabled}
              nil -> {:error, :principal_not_found}
            end
          {:error, _} = err -> err
        end
      :error -> {:error, :missing_principal}
    end
  end

  defp assert_member(repo, company_uid, principal_uid) do
    if MembershipStore.member?(repo, company_uid, principal_uid) do
      :ok
    else
      {:error, :principal_not_in_company}
    end
  end

  defp assert_unique_uid(repo, uid) do
    case repo.get_by(Capability, uid: uid) do
      nil -> :ok
      %Capability{} -> {:error, {:duplicate, :uid}}
    end
  end

  defp fetch_attr_or_string(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp fetch_attr_or_string_attrs(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(attrs, Atom.to_string(key))
    end
  end

  defp fetch_attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(attrs, Atom.to_string(key))
    end
  end
end