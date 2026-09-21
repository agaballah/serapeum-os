defmodule Ankole.WorkHierarchy.GoalStore do
  @moduledoc """
  Persistence and query operations for Goal rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2` callback.
  Domain-changing operations acquire the creator Principal row lock inside
  that transaction and validate creator eligibility against the target
  Company. This layer performs no authorization checks beyond structural
  integrity.
  """

  import Ecto.Query

  alias Ankole.Principals
  alias Ankole.Principals.Principal
  alias Ankole.Company.Membership
  alias Ankole.WorkHierarchy.Goal

  @doc """
  Creates a durable Goal scoped to the given Company.

  `company_uid` is authoritative; any `company_uid` in `attrs` is ignored.
  The creator Principal is locked and validated before insert.
  """
  @spec create_goal(Ecto.Repo.t(), String.t(), map()) ::
          {:ok, Goal.t()} | {:error, term()}
  def create_goal(repo, company_uid, attrs) do
    attrs =
      attrs
      |> Map.delete(:id)
      |> Map.put(:company_uid, company_uid)

    with :ok <- validate_company_exists(repo, company_uid),
         {:ok, creator_uid} <- normalize_creator_uid(attrs[:creator_principal_uid]),
         {:ok, locked_creator} <- fetch_creator_for_update(repo, creator_uid),
         :ok <- validate_creator_eligible(repo, locked_creator, company_uid) do
      Goal.changeset(%Goal{}, attrs)
      |> repo.insert()
    end
  end

  @doc """
  Fetches one Goal by stable UID within a Company.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_goal(Ecto.Repo.t(), String.t(), String.t()) :: Goal.t() | nil
  def fetch_goal(repo, company_uid, goal_uid) do
    repo.one(
      from goal in Goal,
        where: goal.company_uid == ^company_uid and goal.uid == ^goal_uid
    )
  end

  @doc """
  Lists all Goals for one Company.

  Read-only query. No transaction or lock required.
  """
  @spec list_company_goals(Ecto.Repo.t(), String.t()) :: [Goal.t()]
  def list_company_goals(repo, company_uid) do
    repo.all(
      from goal in Goal,
        where: goal.company_uid == ^company_uid,
        order_by: goal.uid
    )
  end

  defp validate_company_exists(repo, company_uid) do
    case repo.get_by(Ankole.Company, uid: company_uid) do
      %Ankole.Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp normalize_creator_uid(uid) do
    Principals.normalize_uid(uid)
  end

  defp fetch_creator_for_update(repo, creator_uid) do
    case repo.one(
           from principal in Principal,
             where: principal.uid == ^creator_uid,
             lock: "FOR UPDATE"
         ) do
      %Principal{} = principal -> {:ok, principal}
      nil -> {:error, :creator_not_found}
    end
  end

  defp validate_creator_eligible(repo, %Principal{type: :human} = creator, company_uid) do
    with :ok <- validate_active(creator),
         :ok <- validate_member(repo, creator.uid, company_uid) do
      :ok
    end
  end

  defp validate_creator_eligible(repo, %Principal{type: :agent} = creator, company_uid) do
    with :ok <- validate_active(creator),
         :ok <- validate_agent_subtype_exists(repo, creator.uid),
         :ok <- validate_agent_company_membership(repo, creator.uid, company_uid) do
      :ok
    end
  end

  defp validate_creator_eligible(_repo, %Principal{type: :system} = creator, _company_uid) do
    validate_active(creator)
  end

  defp validate_creator_eligible(_repo, %Principal{type: type}, _company_uid) do
    {:error, {:invalid_creator_type, type}}
  end

  defp validate_active(%Principal{status: :active}), do: :ok
  defp validate_active(%Principal{status: status}), do: {:error, {:creator_not_active, status}}

  defp validate_member(repo, principal_uid, company_uid) do
    case repo.one(
           from m in Membership,
             where: m.company_uid == ^company_uid and m.principal_uid == ^principal_uid
         ) do
      %Membership{} -> :ok
      nil -> {:error, :creator_not_member}
    end
  end

  defp validate_agent_subtype_exists(repo, agent_uid) do
    case repo.get(Ankole.Principals.Agent, agent_uid) do
      %Ankole.Principals.Agent{} -> :ok
      nil -> {:error, :agent_subtype_missing}
    end
  end

  defp validate_agent_company_membership(repo, agent_uid, company_uid) do
    memberships =
      repo.all(
        from m in Membership,
          where: m.principal_uid == ^agent_uid
      )

    case memberships do
      [] -> {:error, :agent_not_in_company}
      [%{company_uid: ^company_uid}] -> :ok
      [_other] -> {:error, :agent_already_in_company}
      _corrupt -> {:error, :agent_membership_invariant_violation}
    end
  end
end
