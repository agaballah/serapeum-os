defmodule Ankole.W3.ApprovalStore do
  @moduledoc """
  Persistence and Company-scoped query operations for Approval rows.

  This store owns the approval lifecycle: creation, approval, rejection,
  revocation, and validation. It enforces the MA-06 §20 independence
  rule (approver ≠ requester) at the data layer via changeset constraints
  and the `ensure_independent_approver/2` helper.

  P5 consumes this store through `validate_for_assurance/6`, which
  verifies that an approval is valid for a given assurance context
  (Company, requester, action, resource).
  """

  import Ecto.Query

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.PrincipalKey
  alias Ankole.Principals.Principal
  alias Ankole.W3.Approval

  @doc """
  Creates a new Approval in `:requested` status.

  Validates company existence, requester existence and membership,
  and uniqueness of the UID.
  """
  @spec create_approval(Ecto.Repo.t(), map()) ::
          {:ok, Approval.t()} | {:error, term()}
  def create_approval(repo, attrs) do
    with {:ok, company_uid} <- fetch_attr(attrs, :company_uid),
         :ok <- ensure_company_exists(repo, company_uid),
         {:ok, requester_uid} <- fetch_normalized_principal(repo, attrs, :requester_uid),
         :ok <- ensure_member(repo, company_uid, requester_uid),
         {:ok, normalized_uid} <- fetch_normalized_uid(attrs),
         :ok <- ensure_unique_uid(repo, normalized_uid) do
      merged =
        attrs
        |> Map.put(:company_uid, company_uid)
        |> Map.put(:requester_uid, requester_uid)
        |> Map.put(:uid, normalized_uid)
        |> Map.put_new(:status, "requested")
        |> Map.put_new(:metadata, %{})
        |> Map.delete(:id)

      %Approval{}
      |> Approval.changeset(merged)
      |> repo.insert()
    else
      {:error, :company_not_found} -> {:error, :company_not_found}
      {:error, :principal_not_found} -> {:error, :principal_not_found}
      {:error, :principal_disabled} -> {:error, :principal_disabled}
      {:error, :principal_not_in_company} -> {:error, :principal_not_in_company}
      {:error, {:duplicate, :uid}} -> {:error, {:duplicate, :uid}}
      {:error, reason} -> {:error, reason}
      :error -> {:error, :missing_required_attribute}
    end
  end

  @doc """
  Fetches one Approval by UID within a Company scope.
  """
  @spec fetch_approval(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Approval.t()} | {:error, term()}
  def fetch_approval(repo, company_uid, approval_uid) do
    with :ok <- ensure_company_exists(repo, company_uid),
         {:ok, normalized_uid} <- PrincipalKey.normalize(approval_uid) do
      case repo.one(
             from approval in Approval,
               where:
                 approval.uid == ^normalized_uid and
                   approval.company_uid == ^company_uid
           ) do
        %Approval{} = approval -> {:ok, approval}
        nil -> {:error, :not_found}
      end
    end
  end

  @doc """
  Fetches one Approval by UID within a Company scope, acquiring a row-level
  `SELECT ... FOR UPDATE` lock.

  The caller must own the surrounding transaction. This function does not
  start one. It is the single row-lock primitive for Approval rows: the
  lifecycle functions (`approve_approval`, `reject_approval`,
  `revoke_approval`) use it, and so does any caller that must judge an
  Approval and act on it inside one transaction.

  Returns `{:ok, approval}` when the row is found and locked, or
  `{:error, :not_found}` when no Approval matches the UID inside the
  Company scope.
  """
  @spec fetch_approval_for_update(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Approval.t()} | {:error, :not_found | :company_not_found | :invalid_uid}
  def fetch_approval_for_update(repo, company_uid, approval_uid) do
    with :ok <- ensure_company_exists(repo, company_uid),
         {:ok, normalized_uid} <- PrincipalKey.normalize(approval_uid) do
      case repo.one(
             from approval in Approval,
               where:
                 approval.uid == ^normalized_uid and
                   approval.company_uid == ^company_uid,
               lock: "FOR UPDATE"
           ) do
        %Approval{} = approval -> {:ok, approval}
        nil -> {:error, :not_found}
      end
    end
  end

  @doc """
  Transitions an Approval to `:approved` by an independent approver.

  The approver must:
  - Be an active member of the same Company
  - Not be the same Principal as the requester (MA-06 §20)
  - Not already be set on this approval (idempotent on already-approved)

  Uses a row-level lock inside a transaction to prevent concurrent
  approve/revoke races (TOCTOU safety).

  Returns `{:ok, approval}` on success or `{:error, reason}` on failure.
  """
  @spec approve_approval(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          {:ok, Approval.t()} | {:error, term()}
  def approve_approval(repo, company_uid, approval_uid, approver_uid) do
    repo.transact(fn ->
      with {:ok, approval} <- fetch_approval_for_update(repo, company_uid, approval_uid),
           :ok <- can_approve?(approval),
           {:ok, normalized_approver} <- PrincipalKey.normalize(approver_uid),
           %Principal{status: :active} <- repo.get(Principal, normalized_approver),
           true <- MembershipStore.member?(repo, company_uid, normalized_approver),
           :ok <- ensure_independent_approver(approval, normalized_approver) do
        now = DateTime.utc_now()

        changeset =
          approval
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_change(:status, "approved")
          |> Ecto.Changeset.put_change(:approver_uid, normalized_approver)
          |> Ecto.Changeset.put_change(:approved_at, now)

        case repo.update(changeset) do
          {:ok, updated} -> {:ok, updated}
          {:error, _} = err -> err
        end
      else
        {:error, :not_found} -> {:error, :not_found}
        {:error, :already_approved} -> {:error, :already_approved}
        {:error, :already_terminal} -> {:error, :already_terminal}
        {:error, :principal_not_found} -> {:error, :principal_not_found}
        {:error, :principal_disabled} -> {:error, :principal_disabled}
        {:error, :self_approval} -> {:error, :self_approval}
        {:error, :principal_not_in_company} -> {:error, :principal_not_in_company}
        nil -> {:error, :not_found}
      end
    end)
  end

  @doc """
  Transitions an Approval to `:rejected`.
  """
  @spec reject_approval(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          {:ok, Approval.t()} | {:error, term()}
  def reject_approval(repo, company_uid, approval_uid, approver_uid) do
    repo.transact(fn ->
      with {:ok, approval} <- fetch_approval_for_update(repo, company_uid, approval_uid),
           :ok <- can_reject?(approval),
           {:ok, normalized_approver} <- PrincipalKey.normalize(approver_uid),
           %Principal{status: :active} <- repo.get(Principal, normalized_approver),
           true <- MembershipStore.member?(repo, company_uid, normalized_approver) do
        changeset =
          approval
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_change(:status, "rejected")
          |> Ecto.Changeset.put_change(:approver_uid, normalized_approver)

        repo.update(changeset)
      else
        {:error, :not_found} -> {:error, :not_found}
        {:error, :already_terminal} -> {:error, :already_terminal}
        {:error, :principal_not_found} -> {:error, :principal_not_found}
        {:error, :principal_disabled} -> {:error, :principal_disabled}
        {:error, :principal_not_in_company} -> {:error, :principal_not_in_company}
        nil -> {:error, :not_found}
      end
    end)
  end

  @doc """
  Revokes an Approval (marks it as no longer valid).
  """
  @spec revoke_approval(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          {:ok, Approval.t()} | {:error, term()}
  def revoke_approval(repo, company_uid, approval_uid, revoker_uid) do
    repo.transact(fn ->
      with {:ok, approval} <- fetch_approval_for_update(repo, company_uid, approval_uid),
           :ok <- can_revoke?(approval),
           {:ok, normalized_revoker} <- PrincipalKey.normalize(revoker_uid),
           %Principal{status: :active} <- repo.get(Principal, normalized_revoker),
           true <- MembershipStore.member?(repo, company_uid, normalized_revoker) do
        now = DateTime.utc_now()

        changeset =
          approval
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_change(:status, "revoked")
          |> Ecto.Changeset.put_change(:revoked_at, now)

        repo.update(changeset)
      else
        {:error, :not_found} -> {:error, :not_found}
        {:error, :already_terminal} -> {:error, :already_terminal}
        {:error, :principal_not_found} -> {:error, :principal_not_found}
        {:error, :principal_disabled} -> {:error, :principal_disabled}
        {:error, :principal_not_in_company} -> {:error, :principal_not_in_company}
        nil -> {:error, :not_found}
      end
    end)
  end

  @doc """
  Validates an already-fetched Approval without performing a second database
  read.

  The caller is responsible for acquiring the row lock first, typically through
  `fetch_approval_for_update/3` inside the same transaction. This function
  evaluates every assurance-relevant semantic that `validate_for_assurance/6`
  evaluates, over the Approval row it is handed: Company identity, approved
  status, requester identity, action, resource, risk class, approver
  independence, expiry, and revocation / terminal state.

  Expiry is evaluated dynamically against the current time at validation time.
  No database transition is introduced: an Approval is never marked `expired`
  by this function.

  Returns the same error vocabulary as `validate_for_assurance/6`.
  """
  @spec validate_prefetched_approval(Approval.t(), map()) ::
          :ok | {:error, atom()}
  def validate_prefetched_approval(approval, expected) when is_map(expected) do
    company_uid = Map.get(expected, :company_uid)
    requester_uid = Map.get(expected, :requester_uid)
    action = Map.get(expected, :action)
    resource = Map.get(expected, :resource)
    expected_risk_class = Map.get(expected, :risk_class)

    with :ok <- check_company_matches(approval, company_uid),
         :ok <- check_approved(approval),
         :ok <- check_not_expired(approval),
         :ok <- check_not_revoked(approval),
         :ok <- check_requester_matches(approval, requester_uid),
         :ok <- check_action_match(approval, action),
         :ok <- check_resource_match(approval, resource),
         :ok <- check_risk_class_match(approval, expected_risk_class),
         :ok <- check_independent_approver(approval) do
      :ok
    else
      {:error, :company_mismatch} -> {:error, :approval_company_mismatch}
      {:error, :not_approved} -> {:error, :approval_not_approved}
      {:error, :expired} -> {:error, :approval_expired}
      {:error, :revoked} -> {:error, :approval_revoked}
      {:error, :requester_mismatch} -> {:error, :approval_requester_mismatch}
      {:error, :action_mismatch} -> {:error, :approval_action_mismatch}
      {:error, :resource_mismatch} -> {:error, :approval_resource_mismatch}
      {:error, :risk_class_mismatch} -> {:error, :approval_risk_class_mismatch}
      {:error, :self_approval} -> {:error, :approval_self_approval}
    end
  end

  @doc """
  Validates an Approval for use in Action Assurance.

  This is the function P5 calls via `check_approval_independence` to verify
  that a given approval UID is valid for the requesting Principal within
  the specified Company, and that the approval binds to the exact action
  and resource being executed.

  Checks (MA-06 §18 "approve one thing, execute another"):
  - Approval exists within the Company
  - Approval is in `approved` status
  - Approval has not expired (`expires_at` is nil or in the future)
  - Approval has not been revoked
  - The approval was not self-approved (approver ≠ requester)
  - The approval's action matches the proposed action (when provided)
  - The approval's resource matches the proposed resource (when provided)
  - The approval's risk class matches the recomputed risk class (when provided)

  This function fetches the Approval normally and then delegates to
  `validate_prefetched_approval/2`, so there is a single semantic validation
  implementation. It does not acquire a row lock; callers that need
  transactional serialization must use `fetch_approval_for_update/3`.
  """
  @spec validate_for_assurance(
          Ecto.Repo.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil,
          String.t() | nil
        ) ::
          :ok | {:error, atom()}
  def validate_for_assurance(
        repo,
        company_uid,
        approval_uid,
        requester_uid,
        action \\ nil,
        resource \\ nil,
        expected_risk_class \\ nil
      ) do
    with {:ok, approval} <- fetch_approval(repo, company_uid, approval_uid) do
      validate_prefetched_approval(approval, %{
        company_uid: company_uid,
        requester_uid: requester_uid,
        action: action,
        resource: resource,
        risk_class: expected_risk_class
      })
    else
      # `:company_not_found` from `fetch_approval/3` propagates unchanged,
      # matching the pre-existing behavior of this function.
      {:error, :not_found} -> {:error, :approval_not_found}
    end
  end

  @doc """
  Lists approvals within one Company, ordered by creation time descending.
  """
  @spec list_company_approvals(Ecto.Repo.t(), String.t()) :: [Approval.t()]
  def list_company_approvals(repo, company_uid) do
    Approval
    |> where([a], a.company_uid == ^company_uid)
    |> order_by([a], desc: a.inserted_at)
    |> repo.all()
  end

  # ─── private helpers ────────────────────────────────────────────────────

  defp ensure_company_exists(repo, company_uid) do
    case repo.get_by(Company, uid: company_uid) do
      %Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp fetch_normalized_principal(repo, attrs, key) do
    with {:ok, raw} <- fetch_attr(attrs, key),
         {:ok, normalized} <- PrincipalKey.normalize(raw) do
      case repo.get(Principal, normalized) do
        %Principal{status: :active} -> {:ok, normalized}
        %Principal{status: :disabled} -> {:error, :principal_disabled}
        nil -> {:error, :principal_not_found}
      end
    end
  end

  defp ensure_member(repo, company_uid, principal_uid) do
    if MembershipStore.member?(repo, company_uid, principal_uid) do
      :ok
    else
      {:error, :principal_not_in_company}
    end
  end

  defp fetch_normalized_uid(attrs) do
    with {:ok, raw} <- fetch_attr(attrs, :uid),
         {:ok, normalized} <- PrincipalKey.normalize(raw) do
      {:ok, normalized}
    end
  end

  defp ensure_unique_uid(repo, uid) do
    case repo.get_by(Approval, uid: uid) do
      nil -> :ok
      %Approval{} -> {:error, {:duplicate, :uid}}
    end
  end

  defp can_approve?(%Approval{status: status})
       when status in ~w(approved rejected expired revoked) do
    {:error, :already_terminal}
  end

  defp can_approve?(_), do: :ok

  defp can_reject?(%Approval{status: status})
       when status in ~w(approved rejected expired revoked) do
    {:error, :already_terminal}
  end

  defp can_reject?(_), do: :ok

  defp can_revoke?(%Approval{status: status}) when status in ~w(rejected expired revoked) do
    {:error, :already_terminal}
  end

  defp can_revoke?(_), do: :ok

  defp ensure_independent_approver(%Approval{requester_uid: req_uid}, approver_uid)
       when req_uid == approver_uid, do: {:error, :self_approval}

  defp ensure_independent_approver(_approval, _approver_uid), do: :ok

  # MA-06 §20 independence re-checked at validation time. An Approval whose
  # stored approver is the same Principal as its requester was never reachable
  # through `approve_approval/4` (it rejects there), but the check is repeated
  # here so a prefetched row cannot be validated as independent authority.
  defp check_independent_approver(%Approval{requester_uid: req_uid, approver_uid: approver_uid})
       when is_binary(req_uid) and is_binary(approver_uid) and req_uid == approver_uid,
       do: {:error, :self_approval}

  defp check_independent_approver(_approval), do: :ok

  defp check_company_matches(%Approval{company_uid: company_uid}, company_uid)
       when is_binary(company_uid),
       do: :ok

  defp check_company_matches(_approval, _company_uid), do: {:error, :company_mismatch}

  defp check_approved(%Approval{status: "approved"}), do: :ok
  defp check_approved(%Approval{status: "revoked"}), do: {:error, :revoked}
  defp check_approved(_), do: {:error, :not_approved}

  defp check_not_expired(%Approval{expires_at: nil}), do: :ok

  defp check_not_expired(%Approval{expires_at: expires_at}) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :gt -> :ok
      _ -> {:error, :expired}
    end
  end

  defp check_not_revoked(%Approval{revoked_at: nil}), do: :ok
  defp check_not_revoked(%Approval{revoked_at: _}), do: {:error, :revoked}

  defp check_requester_matches(%Approval{requester_uid: requester_uid}, requester_uid), do: :ok
  defp check_requester_matches(_, _), do: {:error, :requester_mismatch}

  defp check_action_match(_approval, nil), do: :ok
  defp check_action_match(%Approval{action: action}, action), do: :ok
  defp check_action_match(_, _), do: {:error, :action_mismatch}

  defp check_resource_match(_approval, nil), do: :ok
  defp check_resource_match(%Approval{resource: resource}, resource), do: :ok
  defp check_resource_match(_, _), do: {:error, :resource_mismatch}

  defp check_risk_class_match(_approval, nil), do: :ok

  defp check_risk_class_match(%Approval{risk_class: risk_class}, expected_risk) do
    if risk_class == expected_risk do
      :ok
    else
      {:error, :risk_class_mismatch}
    end
  end

  defp fetch_attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(attrs, Atom.to_string(key))
    end
  end
end
