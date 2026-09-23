defmodule Ankole.WorkHierarchy.TaskStore do
  @moduledoc """
  Persistence and query operations for Task identity rows and assignment history.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2` callback.
  Domain-changing operations acquire relevant rows locked inside that transaction
  and validate structural eligibility against the target Company. This layer
  performs no authorization checks beyond structural integrity.
  """

  import Ecto.Query

  alias Ankole.Principals
  alias Ankole.Principals.Principal
  alias Ankole.Principals.Agent
  alias Ankole.Company.Membership
  alias Ankole.WorkHierarchy.Goal
  alias Ankole.WorkHierarchy.Mission
  alias Ankole.WorkHierarchy.Task

  @doc """
  Creates a new Task within the given Company.

  `company_uid` is authoritative; any `company_uid` in `attrs` is ignored.
  The creator Principal is locked and validated before insert.
  """
  @spec create_task(Ecto.Repo.t(), String.t(), map()) :: {:ok, Task.t()} | {:error, term()}
  def create_task(repo, company_uid, attrs) do
    attrs =
      attrs
      |> Map.delete(:id)
      |> Map.put(:company_uid, company_uid)

    with :ok <- validate_company_exists(repo, company_uid),
         {:ok, creator_uid} <- normalize_uid(attrs[:creator_principal_uid]),
         {:ok, locked_creator} <- fetch_creator_for_update(repo, creator_uid),
         :ok <- validate_creator_eligible(repo, locked_creator, company_uid),
         :ok <- validate_optional_references(repo, attrs, company_uid),
         {:ok, task} <- insert_task(repo, attrs, creator_uid) do
      {:ok, task}
    end
  end

  @doc """
  Fetches one Task by stable UID within a Company.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_task(Ecto.Repo.t(), String.t(), String.t()) :: Task.t() | nil
  def fetch_task(repo, company_uid, task_uid) do
    repo.one(
      from t in Task,
        where: t.company_uid == ^company_uid and t.uid == ^task_uid
    )
  end

  @doc """
  Lists all Tasks for one Company.

  Read-only query. No transaction or lock required.
  """
  @spec list_company_tasks(Ecto.Repo.t(), String.t()) :: [Task.t()]
  def list_company_tasks(repo, company_uid) do
    repo.all(
      from t in Task,
        where: t.company_uid == ^company_uid,
        order_by: [asc: t.uid]
    )
  end

  @doc """
  Lists all Tasks linked to one Mission within a Company.

  Read-only query. No transaction or lock required.
  """
  @spec list_mission_tasks(Ecto.Repo.t(), String.t(), String.t()) :: [Task.t()]
  def list_mission_tasks(repo, company_uid, mission_uid) do
    repo.all(
      from t in Task,
        where: t.company_uid == ^company_uid and t.mission_uid == ^mission_uid,
        order_by: [asc: t.uid]
    )
  end

  @doc """
  Pre-flight validation for assigning an Agent to a Task.

  Validates that the Agent is eligible without mutating the Task row.
  Returns `:ok` when eligible or an error term when not.
  """
  @spec validate_assignment_eligibility(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def validate_assignment_eligibility(repo, task_uid, agent_uid, company_uid) do
    case repo.one(from t in Task, where: t.uid == ^task_uid and t.company_uid == ^company_uid, limit: 1) do
      %Task{} -> :ok
      nil -> {:error, :task_not_found}
    end |> do_validate_agent_eligibility(repo, agent_uid, company_uid)
  end

  defp do_validate_agent_eligibility(:ok, repo, agent_uid, company_uid) do
    with {:ok, normalized_uid} <- Principals.normalize_uid(agent_uid),
         %Principal{type: :agent, status: :active} <- repo.one(from p in Principal, where: p.uid == ^normalized_uid, limit: 1),
         %Agent{} <- repo.get(Agent, normalized_uid) do
      memberships = repo.all(from m in Membership, where: m.principal_uid == ^normalized_uid)
      case memberships do
        [%{company_uid: ^company_uid}] -> :ok
        [] -> {:error, :agent_not_in_company}
        [%{company_uid: _other}] -> {:error, :agent_already_in_company}
        _ -> {:error, :agent_membership_invariant_violation}
      end
    else
      nil -> {:error, :agent_not_found}
      %Principal{} -> {:error, :agent_not_active_or_wrong_type}
      %Agent{} -> {:error, :agent_subtype_missing}
      _ -> {:error, :invalid_agent_state}
    end
  end

  defp do_validate_agent_eligibility({:error, _} = err, _repo, _agent_uid, _company_uid), do: err

  # ─── Validation helpers ───────────────────────────────────────────────────

  defp validate_company_exists(repo, company_uid) do
    case repo.get_by(Ankole.Company, uid: company_uid) do
      %Ankole.Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp normalize_uid(uid) when is_binary(uid) do
    Principals.normalize_uid(uid)
  end

  defp normalize_uid(nil), do: {:error, :invalid_uid}

  defp fetch_creator_for_update(repo, creator_uid) do
    case repo.one(from p in Principal, where: p.uid == ^creator_uid, lock: "FOR UPDATE") do
      %Principal{} = principal -> {:ok, principal}
      nil -> {:error, :not_found}
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
    case repo.one(from m in Membership, where: m.company_uid == ^company_uid and m.principal_uid == ^principal_uid) do
      %Membership{} -> :ok
      nil -> {:error, :creator_not_member}
    end
  end

  defp validate_agent_subtype_exists(repo, agent_uid) do
    case repo.get(Agent, agent_uid) do
      %Agent{} -> :ok
      nil -> {:error, :agent_subtype_missing}
    end
  end

  defp validate_agent_company_membership(repo, agent_uid, company_uid) do
    memberships = repo.all(from m in Membership, where: m.principal_uid == ^agent_uid)

    case memberships do
      [] -> {:error, :agent_not_in_company}
      [%{company_uid: ^company_uid}] -> :ok
      [_other] -> {:error, :agent_already_in_company}
      _corrupt -> {:error, :agent_membership_invariant_violation}
    end
  end

  defp validate_optional_references(repo, attrs, company_uid) do
    with :ok <- validate_mission_reference(repo, attrs),
         :ok <- validate_goal_reference(repo, attrs),
         :ok <- validate_parent_task(repo, attrs, company_uid),
         :ok <- validate_accountable_agent(repo, attrs, company_uid) do
      :ok
    end
  end

  defp validate_mission_reference(_repo, %{mission_uid: nil}), do: :ok
  defp validate_mission_reference(repo, %{mission_uid: uid}) when is_binary(uid) do
    case repo.get(Mission, uid) do
      %Mission{} -> :ok
      nil -> {:error, :mission_not_found}
    end
  end
  defp validate_mission_reference(_repo, _attrs), do: :ok

  defp validate_goal_reference(_repo, %{goal_uid: nil}), do: :ok
  defp validate_goal_reference(repo, %{goal_uid: uid}) when is_binary(uid) do
    case repo.get(Goal, uid) do
      %Goal{} -> :ok
      nil -> {:error, :goal_not_found}
    end
  end
  defp validate_goal_reference(_repo, _attrs), do: :ok

  defp validate_parent_task(repo, %{parent_task_uid: parent_uid}, company_uid) when is_binary(parent_uid) do
    case repo.one(from t in Task, where: t.uid == ^parent_uid, select: t.company_uid) do
      ^company_uid -> :ok
      nil -> {:error, :parent_task_not_found}
      _other -> {:error, :parent_task_different_company}
    end
  end
  defp validate_parent_task(_repo, _attrs, _company_uid), do: :ok

  defp validate_accountable_agent(repo, %{accountable_agent_uid: agent_uid}, company_uid) when is_binary(agent_uid) do
    with {:ok, normalized_uid} <- Principals.normalize_uid(agent_uid),
         %Principal{type: :agent, status: :active} <- repo.one(from p in Principal, where: p.uid == ^normalized_uid, limit: 1),
         %Agent{} <- repo.get(Agent, normalized_uid) do
      memberships = repo.all(from m in Membership, where: m.principal_uid == ^normalized_uid)
      case memberships do
        [%{company_uid: ^company_uid}] -> :ok
        [] -> {:error, :agent_not_in_company}
        [%{company_uid: _other}] -> {:error, :agent_already_in_company}
        _ -> {:error, :agent_membership_invariant_violation}
      end
    else
      nil -> {:error, :accountable_agent_not_found}
      %Principal{} -> {:error, :accountable_agent_invalid}
      _ -> {:error, :accountable_agent_subtype_missing}
    end
  end
  defp validate_accountable_agent(_repo, _attrs, _company_uid), do: :ok

  # ─── Insert helpers ───────────────────────────────────────────────────────

  defp insert_task(repo, attrs, creator_uid) do
    task_attrs =
      attrs
      |> Map.take([:uid, :mission_uid, :goal_uid, :parent_task_uid, :accountable_agent_uid,
                   :origin_kind, :origin_reference, :status, :objective_text, :scope_text,
                   :required_outcome_text, :acceptance_criteria_text, :child_completion_policy,
                   :cancelled_at, :cancelled_by_uid, :cancellation_reason])
      |> Map.put(:company_uid, attrs[:company_uid])
      |> Map.put(:creator_principal_uid, creator_uid)
      |> Map.put_new(:status, "PROPOSED")

    %Task{}
    |> Task.changeset(task_attrs)
    |> repo.insert()
  end
end
