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

  alias Ankole.Company.MembershipStore
  alias Ankole.PrincipalKey
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityStore

  # ─── public API ──────────────────────────────────────────────────────────

  @doc """
  Issues a new Capability inside the caller's Company.

  Validates the issuer is an active member of the Company. If a
  `parent_capability_uid` is supplied, enforces MA-06 §12 attenuation:
  the child capability must not exceed the parent's authority.
  """
  @spec issue_capability(Ecto.Repo.t(), map()) ::
          {:ok, Capability.t()} | {:error, term()}
  def issue_capability(repo, attrs) do
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

  The revoker must be an active Company member. Revocation is idempotent:
  calling revoke on an already-revoked Capability returns `:ok` with the
  existing record rather than an error.
  """
  @spec revoke_capability(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          {:ok, Capability.t()} | {:error, term()}
  def revoke_capability(repo, company_uid, capability_uid, revoker_uid) do
    case CapabilityStore.fetch_capability(repo, company_uid, capability_uid) do
      {:ok, %Capability{status: :active} = capability} ->
        case PrincipalKey.normalize(revoker_uid) do
          {:ok, normalized_revoker} ->
            case repo.get(Principal, normalized_revoker) do
              %Principal{status: :active} = _p ->
                case MembershipStore.member?(repo, company_uid, normalized_revoker) do
                  true -> do_revoke(repo, capability)
                  false -> {:error, :principal_not_in_company}
                end
              _ -> {:error, :principal_disabled}
            end
          {:error, _} -> {:error, :invalid_uid}
        end

      {:ok, %Capability{status: :revoked}} -> {:error, :already_revoked}
      {:ok, %Capability{status: :expired}} -> {:error, :already_expired}
      {:ok, %Capability{status: :consumed}} -> {:error, :already_consumed}
      {:error, :not_found} -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Expires a Capability by UID within a Company.

  Idempotent: expiring an already-expired Capability returns `:ok`.
  """
  @spec expire_capability(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Capability.t()} | {:error, term()}
  def expire_capability(repo, company_uid, capability_uid) do
    case CapabilityStore.fetch_capability(repo, company_uid, capability_uid) do
      {:ok, %Capability{status: :active} = capability} -> do_expire(repo, capability)
      {:ok, %Capability{status: :expired}} -> {:error, :already_expired}
      {:ok, %Capability{status: :revoked}} -> {:error, :already_revoked}
      {:ok, %Capability{status: :consumed}} -> {:error, :already_consumed}
      {:error, :not_found} -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Validates whether a Capability is currently usable per MA-06 §11.
  """
  @spec validate_capability(Ecto.Repo.t(), String.t(), String.t(), keyword()) ::
          :ok | {:error, atom()}
  def validate_capability(repo, company_uid, capability_uid, opts \\ []) do
    case CapabilityStore.fetch_capability(repo, company_uid, capability_uid) do
      {:ok, %Capability{status: :active} = capability} ->
        check_validation(repo, capability, opts)

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
  """
  @spec check_attenuation(Ecto.Repo.t(), String.t(), map()) :: :ok | {:error, term()}
  def check_attenuation(repo, company_uid, attrs) when is_map(attrs) do
    case Map.fetch(attrs, :parent_capability_uid) do
      {:ok, nil} -> :ok
      :error -> :ok
      {:ok, parent_uid} -> do_check_attenuation(repo, company_uid, attrs, parent_uid)
    end
  end

  defp do_check_attenuation(repo, company_uid, attrs, parent_uid) do
    case CapabilityStore.fetch_capability(repo, company_uid, parent_uid) do
      {:ok, %Capability{status: :active} = parent} ->
        check_attenuation_attrs(attrs, parent)

      {:ok, %Capability{}} -> {:error, :parent_capability_invalid}
      {:error, :not_found} -> {:error, :parent_capability_not_found}
      {:error, :company_not_found} -> {:error, :parent_capability_not_found}
      {:error, :invalid_uid} -> {:error, :parent_capability_not_found}
      nil -> {:error, :parent_capability_not_found}
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

  defp do_revoke(_repo, capability) do
    now = DateTime.utc_now()
    changeset = Ecto.Changeset.change(capability) |> Ecto.Changeset.put_change(:status, :revoked) |> Ecto.Changeset.put_change(:revoked_at, now)
    Repo.update(changeset)
  end

  defp do_expire(_repo, capability) do
    changeset = Ecto.Changeset.change(capability) |> Ecto.Changeset.put_change(:status, :expired)
    Repo.update(changeset)
  end

  defp check_validation(repo, %Capability{} = capability, opts) do
    with :ok <- check_principal_active(repo, capability.principal_uid),
         :ok <- check_issuer_active(repo, capability.issued_by_principal_uid),
         :ok <- check_not_expired(capability),
         :ok <- check_not_revoked(capability),
         :ok <- check_parent_active(repo, capability.parent_capability_uid),
         :ok <- check_action_match(capability, opts) do
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

  defp check_parent_active(_repo, nil), do: :ok
  defp check_parent_active(_repo, parent_uid) do
    case Repo.get(Capability, uid: parent_uid) do
      %Capability{status: :active} -> :ok
      _ -> {:error, :parent_capability_invalid}
    end
  end

  defp check_action_match(capability, opts) do
    case Keyword.get(opts, :action) do
      nil -> :ok
      requested when requested == capability.action -> :ok
      _ -> {:error, :action_mismatch}
    end
  end

  defp check_attenuation_attrs(attrs, parent) do
    child_resource = fetch_attr_or_string(attrs, :resource)
    child_action = fetch_attr_or_string(attrs, :action)
    child_constraints = Map.get(attrs, :constraints, %{})
    child_expires_at = Map.get(attrs, :expires_at)
    child_scope = Map.get(attrs, :scope, %{})

    cond do
      child_resource != parent.resource -> {:error, :attenuation_violation}
      child_action != parent.action -> {:error, :attenuation_violation}
      !maps_are_subset(child_constraints, parent.constraints) -> {:error, :attenuation_violation}
      not_nil_and_later(child_expires_at, parent.expires_at) -> {:error, :attenuation_violation}
      !maps_are_subset(child_scope, parent.scope) -> {:error, :attenuation_violation}
      true -> :ok
    end
  end

  defp assert_company_exists(_repo, company_uid) do
    case Repo.get_by(Ankole.Company, uid: company_uid) do
      %Ankole.Company{} -> :ok
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

  defp assert_unique_uid(_repo, uid) do
    case Repo.get_by(Capability, uid: uid) do
      nil -> :ok
      %Capability{} -> {:error, {:duplicate, :uid}}
    end
  end

  defp maps_are_subset(subset, superset) do
    case {subset, superset} do
      {nil, _} -> true
      {_, nil} -> true
      {s, sp} when is_map(s) and is_map(sp) -> subset_keys_in_superset?(s, sp)
      _ -> true
    end
  end

  defp subset_keys_in_superset?(subset, superset) do
    subset
    |> Map.keys()
    |> Enum.all?(fn key -> Map.has_key?(superset, key) end)
  end

  defp not_nil_and_later(a, b) do
    case {a, b} do
      {nil, _} -> false
      {_, nil} -> false
      {aa, bb} -> DateTime.compare(aa, bb) == :gt
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