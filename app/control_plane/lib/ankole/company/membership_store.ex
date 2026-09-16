defmodule Ankole.Company.MembershipStore do
  @moduledoc """
  Persistence and query operations for Company membership rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Domain-changing operations acquire the Principal row lock inside
  that transaction so the Agent exactly-one-Company invariant is enforced
  transactionally. This layer performs no Company lifecycle authorization.
  """

  import Ecto.Query

  alias Ankole.Company
  alias Ankole.Company.Membership
  alias Ankole.Principals.Principal

  @doc """
  Adds one Company membership for a Principal.

  Human Principals may hold zero-to-many memberships; a same-pair add is
  idempotent. Agent Principals are allowed while they hold no memberships,
  and the same-Company add is idempotent; any other Company is rejected.
  System Principals are rejected fail closed.
  """
  @spec add_member(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Membership.t()} | {:error, term()}
  def add_member(repo, company_uid, principal_uid) do
    with :ok <- ensure_company_exists(repo, company_uid),
         {:ok, principal} <- fetch_principal_for_update(repo, principal_uid),
         :ok <- add_guard(repo, principal, company_uid) do
      insert_membership(repo, company_uid, principal.uid)
    end
  end

  @doc """
  Removes one Company membership for a Principal.

  An Agent's sole Company membership is never removed here; that behavior is
  owned by the future Agent transfer/decommission operation. System
  memberships may be removed as cleanup.
  """
  @spec remove_member(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, :deleted} | {:error, term()}
  def remove_member(repo, company_uid, principal_uid) do
    with {:ok, principal} <- fetch_principal_for_update(repo, principal_uid) do
      case principal.type do
        :agent ->
          guard_agent_remove(repo, principal, company_uid)

        _ ->
          delete_membership(repo, company_uid, principal.uid)
      end
    end
  end

  @doc """
  Reports whether one Company membership exists for a Principal.
  """
  @spec member?(Ecto.Repo.t(), String.t(), String.t()) :: boolean()
  def member?(repo, company_uid, principal_uid) do
    case Ankole.Principals.normalize_uid(principal_uid) do
      {:ok, normalized_uid} ->
        !!fetch_membership(repo, company_uid, normalized_uid)

      {:error, _} ->
        false
    end
  end

  @doc """
  Lists the Principal UIDs that are members of one Company.
  """
  @spec member_uids(Ecto.Repo.t(), String.t()) :: [String.t()]
  def member_uids(repo, company_uid) do
    Membership
    |> where([membership], membership.company_uid == ^company_uid)
    |> select([membership], membership.principal_uid)
    |> repo.all()
  end

  @doc """
  Lists the zero-to-many Company UIDs a Principal is a member of.
  """
  @spec company_uids_for_principal(Ecto.Repo.t(), String.t()) :: [String.t()]
  def company_uids_for_principal(repo, principal_uid) do
    case Ankole.Principals.normalize_uid(principal_uid) do
      {:ok, normalized_uid} ->
        Membership
        |> where([membership], membership.principal_uid == ^normalized_uid)
        |> select([membership], membership.company_uid)
        |> repo.all()

      {:error, _} ->
        []
    end
  end

  @doc """
  Counts the Company memberships held by one Principal.
  """
  @spec membership_count(Ecto.Repo.t(), String.t()) :: non_neg_integer()
  def membership_count(repo, principal_uid) do
    case Ankole.Principals.normalize_uid(principal_uid) do
      {:ok, normalized_uid} ->
        Membership
        |> where([membership], membership.principal_uid == ^normalized_uid)
        |> repo.aggregate(:count)

      {:error, _} ->
        0
    end
  end

  defp ensure_company_exists(repo, company_uid) do
    case repo.get_by(Company, uid: company_uid) do
      %Company{} -> :ok
      nil -> {:error, :not_found}
    end
  end

  defp fetch_principal_for_update(repo, principal_uid) do
    with {:ok, normalized_uid} <- Ankole.Principals.normalize_uid(principal_uid) do
      case repo.one(
             from principal in Principal,
               where: principal.uid == ^normalized_uid,
               lock: "FOR UPDATE"
           ) do
        %Principal{} = principal -> {:ok, principal}
        nil -> {:error, :not_found}
      end
    end
  end

  defp add_guard(repo, %Principal{type: :agent} = principal, company_uid) do
    case company_uids_for_principal(repo, principal.uid) do
      [] ->
        :ok

      [^company_uid] ->
        :ok

      [_other] ->
        {:error, :agent_already_in_company}

      _corrupt ->
        {:error, :agent_membership_invariant_violation}
    end
  end

  defp add_guard(_repo, %Principal{type: :system}, _company_uid) do
    {:error, :system_principal_membership_denied}
  end

  defp add_guard(_repo, _principal, _company_uid), do: :ok

  defp guard_agent_remove(repo, principal, company_uid) do
    case company_uids_for_principal(repo, principal.uid) do
      [] ->
        {:error, :not_found}

      [^company_uid] ->
        {:error, :agent_requires_company}

      [_other] ->
        {:error, :not_found}

      _corrupt ->
        {:error, :agent_membership_invariant_violation}
    end
  end

  defp insert_membership(repo, company_uid, principal_uid) do
    result =
      %Membership{}
      |> Membership.changeset(%{company_uid: company_uid, principal_uid: principal_uid})
      |> repo.insert(on_conflict: :nothing, conflict_target: [:company_uid, :principal_uid])

    case result do
      {:ok, _} ->
        # The no-op path returns a stale struct, so re-read the authoritative
        # row before reporting success.
        {:ok, fetch_membership(repo, company_uid, principal_uid)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp delete_membership(repo, company_uid, principal_uid) do
    {count, _rows} =
      repo.delete_all(
        from membership in Membership,
          where:
            membership.company_uid == ^company_uid and
              membership.principal_uid == ^principal_uid
      )

    case count do
      0 -> {:error, :not_found}
      _count -> {:ok, :deleted}
    end
  end

  defp fetch_membership(repo, company_uid, principal_uid) do
    repo.one(
      from membership in Membership,
        where:
          membership.company_uid == ^company_uid and
            membership.principal_uid == ^principal_uid
    )
  end
end
