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
  alias Ankole.WorkHierarchy.DelegationRecord
  alias Ankole.WorkHierarchy.DelegationEvent
  alias Ankole.WorkHierarchy.TaskDependency
  alias Ankole.WorkHierarchy.TaskChildPolicyHistory

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

  defp fetch_principal_for_update(repo, principal_uid) do
    case repo.one(from p in Principal, where: p.uid == ^principal_uid, lock: "FOR UPDATE") do
      %Principal{} = principal -> {:ok, principal}
      nil -> {:error, :not_found}
    end
  end

  defp fetch_creator_for_update(repo, creator_uid) do
    fetch_principal_for_update(repo, creator_uid)
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

  # ─── P5: Child Task Creation ────────────────────────────────────────────────

  @doc """
  Creates a child Task under an existing parent Task within the same Company.

  The child is created as a new Task and a DelegationRecord is inserted
  atomically in the same transaction. The delegation record's
  `resulting_child_task_uid` is back-filled before commit. The child does not
  inherit the parent's status or accountable Agent.
  """
  @spec create_child_task(Ecto.Repo.t(), String.t(), String.t(), map(), map()) ::
          {:ok, Task.t()} | {:error, term()}
  def create_child_task(repo, company_uid, parent_task_uid, attrs, _opts \\ %{}) do
    with {:ok, parent} <- fetch_parent_for_child(repo, company_uid, parent_task_uid),
          {:ok, delegated_uid} <- generate_delegation_uid(),
           {:ok, child} <- insert_child_task(repo, company_uid, parent, delegated_uid, attrs),
           {:ok, _delegation} <- insert_delegation_in_tx(
             repo, company_uid, delegated_uid, parent.uid, %{
               scope_description: "Child task of #{parent.uid}",
               delegated_by: parent.creator_principal_uid,
               resulting_child_task_uid: child.uid
             }
           ) do
      {:ok, child}
    end
  end

  defp fetch_parent_for_child(repo, company_uid, parent_task_uid) do
    case repo.one(
           from t in Task,
             where: t.uid == ^parent_task_uid and t.company_uid == ^company_uid,
             lock: "FOR UPDATE"
         ) do
      %Task{status: status} when status in @terminal_states -> {:error, :parent_task_terminal}
      %Task{} = task -> {:ok, task}
      nil -> {:error, :parent_task_not_found}
    end
  end

  defp insert_child_task(repo, company_uid, parent, delegation_uid, attrs) do
    base_attrs =
      attrs
      |> Map.delete(:id)
      |> Map.put(:company_uid, company_uid)
      |> Map.put(:parent_task_uid, parent.uid)
      |> Map.put_new(:child_completion_policy, parent.child_completion_policy)
      |> Map.put_new(:origin_kind, "DELEGATION")
      |> Map.put_new(:status, "PROPOSED")
      |> Map.put(:origin_reference, %{"delegation_uid" => delegation_uid, "source_task_uid" => parent.uid})

    with {:ok, creator_uid} <- normalize_uid(base_attrs[:creator_principal_uid]),
          {:ok, locked_creator} <- fetch_creator_for_update(repo, creator_uid),
          :ok <- validate_creator_eligible(repo, locked_creator, company_uid),
          :ok <- validate_optional_references(repo, base_attrs, company_uid),
          {:ok, task} <- insert_task(repo, base_attrs, creator_uid) do
      {:ok, task}
    end
  end

  # ─── P5: Dependency Management ──────────────────────────────────────────────

  @doc """
  Creates a dependency edge from `task_uid` to `depends_on_task_uid` within
  the same Company. Validates DAG acyclicity using a recursive CTE before
  insertion.
  """
  @spec set_dependency(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, TaskDependency.t()} | {:error, term()}
  def set_dependency(repo, company_uid, task_uid, depends_on_task_uid, dependency_type) do
    with :ok <- self_dependency_check(task_uid, depends_on_task_uid),
          :ok <- both_tasks_exist(repo, company_uid, task_uid, depends_on_task_uid),
          :no_cycle <- detect_cycle(repo, task_uid, depends_on_task_uid, company_uid),
          {:ok, dependency} <- insert_dependency(repo, task_uid, depends_on_task_uid, dependency_type) do
      {:ok, dependency}
    end
  end

  @doc """
  Removes a dependency edge from `task_uid` to `depends_on_task_uid`.
  """
  @spec remove_dependency(Ecto.Repo.t(), String.t(), String.t(), String.t()) ::
          {:ok, :deleted} | {:error, term()}
  def remove_dependency(repo, company_uid, task_uid, depends_on_task_uid) do
    with :ok <- validate_dependency_exists(repo, company_uid, task_uid, depends_on_task_uid) do
      {count, _} =
        repo.delete_all(
          from d in TaskDependency,
            where: d.task_uid == ^task_uid and d.depends_on_task_uid == ^depends_on_task_uid
        )

      case count do
        0 -> {:error, :dependency_not_found}
        _ -> {:ok, :deleted}
      end
    end
  end

  defp self_dependency_check(task_uid, depends_on_task_uid) do
    if task_uid == depends_on_task_uid do
      {:error, :self_dependency_rejected}
    else
      :ok
    end
  end

  defp both_tasks_exist(repo, company_uid, task_uid, depends_on_task_uid) do
    tasks =
      repo.all(
        from t in Task,
          where: t.uid in [^task_uid, ^depends_on_task_uid] and t.company_uid == ^company_uid,
          select: t.uid
      )

    missing = [task_uid, depends_on_task_uid] -- tasks

    case missing do
      [] -> :ok
      [_missing] -> {:error, :task_not_found}
    end
  end

  defp detect_cycle(repo, task_uid, depends_on_task_uid, _company_uid) do
    sql = """
    WITH RECURSIVE path AS (
      SELECT td.depends_on_task_uid AS current_uid, 1 AS depth
      FROM task_dependencies td
      WHERE td.task_uid = $1
      UNION ALL
      SELECT td.depends_on_task_uid, p.depth + 1
      FROM task_dependencies td
      JOIN path p ON td.task_uid = p.current_uid
      WHERE p.depth < 1000
    )
    SELECT EXISTS (SELECT 1 FROM path WHERE current_uid = $2)
    """

    case Ecto.Adapters.SQL.query(repo, sql, [depends_on_task_uid, task_uid]) do
      {:ok, %{rows: [[true]]}} -> {:error, :dependency_cycle}
      {:ok, %{rows: [[false]]}} -> :no_cycle
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_dependency(repo, task_uid, depends_on_task_uid, dependency_type) do
    %TaskDependency{}
    |> TaskDependency.changeset(%{
      task_uid: task_uid,
      depends_on_task_uid: depends_on_task_uid,
      dependency_type: dependency_type
    })
    |> repo.insert()
  end

  defp validate_dependency_exists(repo, company_uid, task_uid, depends_on_task_uid) do
    case repo.one(
           from d in TaskDependency,
             join: t in Task, on: t.uid == d.task_uid,
             where: d.task_uid == ^task_uid and d.depends_on_task_uid == ^depends_on_task_uid
               and t.company_uid == ^company_uid,
             limit: 1
         ) do
      %TaskDependency{} -> :ok
      nil -> {:error, :dependency_not_found}
    end
  end

  # ─── P5: Child Policy Mutation ──────────────────────────────────────────────

  @doc """
  Mutates the `child_completion_policy` of a non-terminal Task within the
  given Company. Creates one `task_child_policy_history` row atomically with
  the policy update.
  """
  @spec set_child_policy(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Task.t()} | {:error, term()}
  def set_child_policy(repo, company_uid, task_uid, new_policy, changed_by_uid) do
    with {:ok, task} <- fetch_task_for_update(repo, company_uid, task_uid),
          old_policy <- task.child_completion_policy,
          :ok <- validate_not_terminal(task.status),
          :ok <- validate_child_policy(new_policy),
           {:ok, _changed_by} <- validate_changer(repo, changed_by_uid, company_uid),
          {:ok, task} <- update_child_policy(repo, task, new_policy) do
      {:ok, _history} = insert_child_policy_history(repo, old_policy, task.uid, new_policy, changed_by_uid)
      {:ok, task}
    end
  end

  defp validate_child_policy(policy) do
    if policy in ["ALL_COMPLETED", "INDEPENDENT"] do
      :ok
    else
      {:error, {:invalid_child_policy, policy}}
    end
  end

  defp validate_changer(repo, changed_by_uid, company_uid) do
    with {:ok, normalized_uid} <- normalize_uid(changed_by_uid),
          {:ok, principal} <- fetch_principal_for_update(repo, normalized_uid),
          :ok <- validate_active(principal),
          :ok <- validate_member(repo, principal.uid, company_uid) do
      {:ok, principal}
    else
      {:error, :not_found} -> {:error, :changer_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_child_policy(repo, task, new_policy) do
    changes = Ecto.Changeset.change(task) |> Ecto.Changeset.put_change(:child_completion_policy, new_policy)
    repo.update(changes)
  end

  defp insert_child_policy_history(repo, old_policy, task_uid, new_policy, changed_by_uid) do
    %TaskChildPolicyHistory{}
    |> TaskChildPolicyHistory.changeset(%{
      task_uid: task_uid,
      old_policy: old_policy,
      new_policy: new_policy,
      changed_by_uid: changed_by_uid
    })
    |> repo.insert()
  end

  # ─── P5: Delegation Records ─────────────────────────────────────────────────

  @doc """
  Creates a DelegationRecord and its initial `created` event atomically.

  Validates that the delegator is an active Principal with Company membership.
  Validates that the source Task exists and belongs to the Company. The
  delegatee may be nil.
  """
  @spec create_delegation(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, DelegationRecord.t()} | {:error, term()}
  def create_delegation(repo, company_uid, source_task_uid, delegator_principal_uid, delegatee_principal_uid, opts \\ %{}) do
    with {:ok, source_task} <- fetch_source_task_for_delegation(repo, company_uid, source_task_uid),
          {:ok, normalized_delegator} <- normalize_uid(delegator_principal_uid),
          {:ok, locked_delegator} <- fetch_principal_for_update(repo, normalized_delegator),
          :ok <- validate_delegator_eligible(repo, locked_delegator, company_uid),
          {:ok, scope_description} <- validate_scope_description(opts[:scope_description]),
          {:ok, delegation_uid} <- generate_delegation_uid() do
      insert_delegation_in_tx(repo, company_uid, delegation_uid, source_task.uid,
        delegated_by: locked_delegator.uid, delegatee: delegatee_principal_uid,
        scope_description: scope_description)
    end
  end

  defp fetch_source_task_for_delegation(repo, company_uid, source_task_uid) do
    case repo.one(
           from t in Task,
             where: t.uid == ^source_task_uid and t.company_uid == ^company_uid,
             limit: 1
         ) do
      %Task{} = task -> {:ok, task}
      nil -> {:error, :source_task_not_found}
    end
  end

  defp validate_delegator_eligible(_repo, %Principal{type: :system}, _company_uid) do
    {:error, :system_principal_not_allowed_as_delegator}
  end

  defp validate_delegator_eligible(repo, %Principal{type: :human} = delegator, company_uid) do
    with :ok <- validate_active(delegator),
         :ok <- validate_member(repo, delegator.uid, company_uid) do
      :ok
    end
  end

  defp validate_delegator_eligible(repo, %Principal{type: :agent} = delegator, company_uid) do
    with :ok <- validate_active(delegator),
         :ok <- validate_agent_company_membership(repo, delegator.uid, company_uid) do
      :ok
    end
  end

  defp validate_delegator_eligible(_repo, %Principal{type: type}, _company_uid) do
    {:error, {:invalid_delegator_type, type}}
  end

  defp validate_scope_description(nil), do: {:error, :scope_description_required}

  defp validate_scope_description(desc) when is_binary(desc) do
    case String.trim(desc) do
      "" -> {:error, :scope_description_blank}
      trimmed -> {:ok, trimmed}
    end
  end

  defp validate_scope_description(_other), do: {:error, :scope_description_invalid}

  defp insert_delegation_in_tx(repo, _company_uid, delegation_uid, source_task_uid, opts) do
    attrs = %{
      delegation_uid: delegation_uid,
      scope_description: opts[:scope_description],
      delegator_principal_uid: opts[:delegated_by],
      source_task_uid: source_task_uid,
      delegatee_principal_uid: opts[:delegatee],
      resulting_child_task_uid: opts[:resulting_child_task_uid]
    }

    with {:ok, record} <-
           %DelegationRecord{}
           |> DelegationRecord.changeset(attrs)
           |> repo.insert(),
          {:ok, _event} <-
           %DelegationEvent{}
           |> DelegationEvent.changeset(%{delegation_uid: delegation_uid, event_type: "created"})
           |> repo.insert() do
      {:ok, record}
    end
  end

  # ─── P5: Read-Only Helpers ──────────────────────────────────────────────────

  @doc """
  Lists all dependency edges for one Task.

  Read-only query. No transaction or lock required.
  """
  @spec list_dependencies(Ecto.Repo.t(), String.t()) :: [TaskDependency.t()]
  def list_dependencies(repo, task_uid) do
    repo.all(
      from d in TaskDependency,
        where: d.task_uid == ^task_uid,
        order_by: [asc: d.id]
    )
  end

  @doc """
  Lists all direct children of one Task.

  Read-only query. No transaction or lock required.
  """
  @spec list_children(Ecto.Repo.t(), String.t()) :: [Task.t()]
  def list_children(repo, parent_task_uid) do
    repo.all(
      from t in Task,
        where: t.parent_task_uid == ^parent_task_uid,
        order_by: [asc: t.uid]
    )
  end

  @doc """
  Fetches one DelegationRecord by stable UID.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_delegation(Ecto.Repo.t(), String.t()) :: DelegationRecord.t() | nil
  def fetch_delegation(repo, delegation_uid) do
    repo.one(
      from d in DelegationRecord,
        where: d.delegation_uid == ^delegation_uid
    )
  end

  # ─── P5: Private helpers ────────────────────────────────────────────────────

  defp generate_delegation_uid() do
    suffix = System.unique_integer([:positive])
    {:ok, "delegation-#{suffix}"}
  end

  # ─── P6: Read-only result and review helpers ──────────────────────────────

  @doc """
  Fetches one Task result by stable UID.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_result(Ecto.Repo.t(), String.t()) :: Ankole.WorkHierarchy.TaskResult.t() | nil
  def fetch_result(repo, result_uid) do
    Ankole.WorkHierarchy.ResultStore.fetch_result(repo, result_uid)
  end

  @doc """
  Fetches the current Task result: the newest result by `created_at`, with
  `id` as a deterministic tie-break.

  Read-only projection. No lock required. Returns nil when the Task has no
  results.
  """
  @spec fetch_current_result(Ecto.Repo.t(), String.t()) :: Ankole.WorkHierarchy.TaskResult.t() | nil
  def fetch_current_result(repo, task_uid) do
    Ankole.WorkHierarchy.ResultStore.fetch_current_result(repo, task_uid)
  end

  @doc """
  Lists all Task results for one Task, ordered chronologically.

  Read-only query. No transaction or lock required.
  """
  @spec list_task_results(Ecto.Repo.t(), String.t()) :: [Ankole.WorkHierarchy.TaskResult.t()]
  def list_task_results(repo, task_uid) do
    Ankole.WorkHierarchy.ResultStore.list_task_results(repo, task_uid)
  end

  @doc """
  Lists all Task results for one Company, resolved through Task ownership.

  Read-only query. No transaction or lock required.
  """
  @spec list_company_results(Ecto.Repo.t(), String.t()) :: [Ankole.WorkHierarchy.TaskResult.t()]
  def list_company_results(repo, company_uid) do
    Ankole.WorkHierarchy.ResultStore.list_company_results(repo, company_uid)
  end

  @doc """
  Fetches one Review by stable UID.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_review(Ecto.Repo.t(), String.t()) :: Ankole.WorkHierarchy.ReviewRecord.t() | nil
  def fetch_review(repo, review_uid) do
    Ankole.WorkHierarchy.ReviewStore.fetch_review(repo, review_uid)
  end

  @doc """
  Lists all Reviews for one Task, ordered chronologically.

  Read-only query. No transaction or lock required.
  """
  @spec list_task_reviews(Ecto.Repo.t(), String.t()) :: [Ankole.WorkHierarchy.ReviewRecord.t()]
  def list_task_reviews(repo, task_uid) do
    Ankole.WorkHierarchy.ReviewStore.list_task_reviews(repo, task_uid)
  end

  @doc """
  Lists all Reviews against one Result, ordered chronologically.

  Read-only query. No transaction or lock required.
  """
  @spec list_result_reviews(Ecto.Repo.t(), String.t()) :: [Ankole.WorkHierarchy.ReviewRecord.t()]
  def list_result_reviews(repo, result_uid) do
    Ankole.WorkHierarchy.ReviewStore.list_result_reviews(repo, result_uid)
  end
end
