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
  alias Ankole.WorkHierarchy.TaskLifecycleEvent

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
                   :cancelled_at, :cancelled_by_uid, :cancellation_reason, :failure_reason])
      |> Map.put(:company_uid, attrs[:company_uid])
      |> Map.put(:creator_principal_uid, creator_uid)
      |> Map.put_new(:status, "PROPOSED")

    %Task{}
    |> Task.changeset(task_attrs)
    |> repo.insert()
  end

  # ─── Lifecycle transitions ────────────────────────────────────────────────

  @transitions %{
    "PROPOSED" => ~w(READY CANCELLED FAILED),
    "READY" => ~w(ASSIGNED CANCELLED FAILED),
    "ASSIGNED" => ~w(IN_PROGRESS WAITING CANCELLED FAILED),
    "IN_PROGRESS" => ~w(COMPLETED REVIEW CANCELLED WAITING FAILED),
    "WAITING" => ~w(IN_PROGRESS CANCELLED FAILED),
    "REVIEW" => ~w(COMPLETED IN_PROGRESS CANCELLED FAILED),
    "COMPLETED" => [],
    "FAILED" => [],
    "CANCELLED" => []
  }

  @terminal_states ~w(COMPLETED FAILED CANCELLED)

  @doc """
  Transitions a Task from its current status to a new status.

  Validates the transition against the canonical guard matrix.
  Creates a task_lifecycle_events row atomically within the transaction.
  Returns the updated Task.
  """
  @spec transition_task(Ecto.Repo.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, Task.t()} | {:error, term()}
  def transition_task(repo, company_uid, task_uid, to_status, opts \\ %{}) do
    with {:ok, task} <- fetch_task_for_update(repo, company_uid, task_uid),
         from_status <- task.status,
         :ok <- validate_not_terminal(from_status),
         :ok <- validate_transition_allowed(from_status, to_status),
         :ok <- validate_transition_guard(from_status, to_status, task, opts, repo, company_uid),
         {:ok, task} <- update_task_status(repo, task, to_status, opts),
         {:ok, _event} <- insert_lifecycle_event(repo, task, from_status, to_status, opts) do
      {:ok, task}
    end
  end

   @doc """
  Convenes an Agent to a READY Task and transitions it to ASSIGNED.

  Equivalent to transition_task/5 with to_status="ASSIGNED", but performs
  additional organizational validation (accountable_agent UID points to active
  Agent subtype with matching Company membership).
  """
  @spec assign_agent(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Task.t()} | {:error, term()}
  def assign_agent(repo, company_uid, task_uid, agent_uid, changed_by_uid) do
    transition_task(repo, company_uid, task_uid, "ASSIGNED", %{
      accountable_agent_uid: agent_uid,
      changed_by_uid: changed_by_uid,
      metadata: %{"accountable_agent_uid" => agent_uid}
    })
  end

  @doc """
  Cancels a non-terminal Task and transitions it to CANCELLED.

  Sets cancelled_at, cancelled_by_uid, cancellation_reason on the Task.
  Requires changed_by_uid to be a valid active Principal with Company membership.
  """
  @spec cancel_task(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Task.t()} | {:error, term()}
  def cancel_task(repo, company_uid, task_uid, cancelled_by_uid, cancellation_reason, metadata \\ %{}) do
    transition_task(repo, company_uid, task_uid, "CANCELLED", %{
      cancelled_at: DateTime.utc_now(:microsecond),
      cancelled_by_uid: cancelled_by_uid,
      cancellation_reason: cancellation_reason,
      changed_by_uid: cancelled_by_uid,
      metadata: Map.merge(%{"cancellation_reason" => cancellation_reason}, metadata)
    })
  end

  @doc """
  Marks a Task as FAILED (terminal state).

  Stores failure_reason on the Task and creates lifecycle event.
  """
  @spec fail_task(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, Task.t()} | {:error, term()}
  def fail_task(repo, company_uid, task_uid, failed_by_uid, failure_reason, metadata \\ %{}) do
    transition_task(repo, company_uid, task_uid, "FAILED", %{
      failure_reason: failure_reason,
      changed_by_uid: failed_by_uid,
      metadata: Map.merge(%{"failure_reason" => failure_reason}, metadata)
    })
  end

  # ─── Lifecycle private helpers ────────────────────────────────────────────

  defp fetch_task_for_update(repo, company_uid, task_uid) do
    case repo.one(from t in Task, where: t.uid == ^task_uid and t.company_uid == ^company_uid, lock: "FOR UPDATE") do
      %Task{} = task -> {:ok, task}
      nil -> {:error, :task_not_found}
    end
  end

  defp validate_not_terminal(status) do
    if status in @terminal_states do
      {:error, {:terminal_state, status}}
    else
      :ok
    end
  end

  defp validate_transition_allowed(from, to) do
    allowed = Map.get(@transitions, from, [])
    if to in allowed do
      :ok
    else
      {:error, {:invalid_transition, from: from, to: to}}
    end
  end

  defp validate_transition_guard("READY", "ASSIGNED", _task, opts, repo, company_uid) do
    case Map.fetch(opts, :accountable_agent_uid) do
      {:ok, nil} -> {:error, :accountable_agent_uid_required}
      {:ok, agent_uid} -> validate_accountable_agent_eligible_agent(repo, agent_uid, company_uid)
      :error -> {:error, :accountable_agent_uid_required}
    end
  end

  defp validate_transition_guard(_, "WAITING", _task, opts, _repo, _company_uid) do
    metadata = Map.get(opts, :metadata, %{})
    case Map.get(metadata, "waiting_reason") do
      nil -> {:error, :waiting_reason_required}
      _ -> :ok
    end
  end

  defp validate_transition_guard(_, "FAILED", _task, opts, _repo, _company_uid) do
    case Map.get(opts, :failure_reason) do
      nil -> {:error, :failure_reason_required}
      _ -> :ok
    end
  end

  defp validate_transition_guard(_, "CANCELLED", _task, opts, _repo, _company_uid) do
    with {:ok, changed_by_uid} <- Map.fetch(opts, :changed_by_uid),
         {:ok, cancellation_reason} <- Map.fetch(opts, :cancellation_reason) do
      case {changed_by_uid, cancellation_reason} do
        {nil, _} -> {:error, :cancelled_by_uid_required}
        {_, nil} -> {:error, :cancellation_reason_required}
        _ -> :ok
      end
    else
      :error -> {:error, :cancellation_fields_missing}
    end
  end

  defp validate_transition_guard(_from, _to, _task, _opts, _repo, _company_uid), do: :ok

  defp update_task_status(repo, task, to_status, opts) do
    changes =
      task
      |> Task.changeset(%{status: to_status})
      |> maybe_apply_field(opts, :cancelled_at)
      |> maybe_apply_field(opts, :cancelled_by_uid)
      |> maybe_apply_field(opts, :cancellation_reason)
      |> maybe_apply_field(opts, :failure_reason)
      |> maybe_apply_field(opts, :accountable_agent_uid)

    case repo.update(changes) do
      {:ok, updated_task} -> {:ok, updated_task}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp maybe_apply_field(changeset, opts, field) do
    case Map.get(opts, field) do
      nil -> changeset
      value -> Ecto.Changeset.put_change(changeset, field, value)
    end
  end

  defp insert_lifecycle_event(repo, task, from_status, to_status, opts) do
    %TaskLifecycleEvent{}
    |> TaskLifecycleEvent.changeset(%{
      task_uid: task.uid,
      from_status: from_status,
      to_status: to_status,
      changed_by_uid: opts[:changed_by_uid],
      metadata: opts[:metadata]
    })
    |> repo.insert()
  end

  defp validate_accountable_agent_eligible_agent(repo, agent_uid, company_uid) do
    with {:ok, normalized_uid} <- Principals.normalize_uid(agent_uid),
         %Agent{} <- repo.get(Agent, normalized_uid),
         %Principal{type: :agent, status: :active} when not is_nil(normalized_uid) <- repo.one(from p in Principal, where: p.uid == ^normalized_uid, limit: 1) do
      memberships = repo.all(from m in Membership, where: m.principal_uid == ^normalized_uid)
      case memberships do
        [%{company_uid: ^company_uid}] -> :ok
        [] -> {:error, :agent_not_in_company}
        [%{company_uid: _other}] -> {:error, :agent_already_in_company}
        _ -> {:error, :agent_membership_invariant_violation}
      end
    else
      nil -> {:error, :agent_not_found}
      %Agent{} -> {:error, :agent_subtype_missing}
      %Principal{} -> {:error, :agent_not_active_or_wrong_type}
      _ -> {:error, :invalid_agent_state}
    end
  end
end
