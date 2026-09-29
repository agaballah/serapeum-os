defmodule Ankole.WorkHierarchy.ResultStore do
  @moduledoc """
  Persistence and query operations for Task result rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Domain-changing operations acquire the Task row lock inside that
  transaction and validate structural integrity against the target Company.
  This layer performs no authorization checks beyond structural integrity.
  """

  import Ecto.Query

  alias Ankole.BackgroundAgentJobs.Schemas.Job
  alias Ankole.BackgroundAgentJobs.Schemas.Turn
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Task
  alias Ankole.WorkHierarchy.TaskResult
  alias Ankole.WorkHierarchy.ReviewRecord
  alias Ankole.WorkHierarchy.ReviewEvent
  alias Ankole.Workflow.Schemas.AgentCall
  alias Ankole.Workflow.Schemas.Run

  @doc """
  Creates a durable Task result scoped to the given Company.

  `company_uid` is authoritative; any `company_uid` in `attrs` is ignored.
  The Task row is locked FOR UPDATE. If a newer result supersedes a prior
  result that already carries a non-invalidated review, that review is
  invalidated atomically within the same transaction and a `review_events`
  `invalidated` row is inserted.

  The Result must cite at least one real execution record: a workflow run, a
  workflow agent call, a background agent job, or a background agent job turn.
  `execution_attempt_ref` is supplemental opaque metadata and never satisfies
  that requirement on its own. Every cited record must exist, must be owned by
  an Agent that belongs to `company_uid`, and a cited run and call, or job and
  turn, must describe the same execution. Execution rows are read without any
  lock, so this adds no row lock beyond the Task.

  `executor_principal_uids` is normalized as a whole or rejected as a whole.
  Every supplied executor UID must normalize, because reviewer independence is
  judged against the stored executor set and a dropped UID would let a real
  executor review their own work.
  """
  @spec create_result(Ecto.Repo.t(), String.t(), String.t(), map()) ::
          {:ok, TaskResult.t()} | {:error, term()}
  def create_result(repo, company_uid, task_uid, attrs) do
    attrs =
      attrs
      |> Map.delete(:id)
      |> Map.put(:task_uid, task_uid)

    with :ok <- validate_company_exists(repo, company_uid),
         {:ok, _task} <- fetch_task_for_update(repo, company_uid, task_uid),
         {:ok, normalized_refs} <- normalize_execution_references(attrs),
         :ok <- validate_execution_references(repo, company_uid, normalized_refs),
         {:ok, normalized_executors} <- normalize_executor_uids(attrs[:executor_principal_uids]),
         attrs <- attrs |> Map.merge(normalized_refs) |> Map.put(:executor_principal_uids, normalized_executors),
         {:ok, result} <- insert_result(repo, attrs),
         :ok <- invalidate_prior_review_if_superseded(repo, task_uid, result) do
      {:ok, result}
    end
  end

  @doc """
  Fetches one Task result by stable UID.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_result(Ecto.Repo.t(), String.t()) :: TaskResult.t() | nil
  def fetch_result(repo, result_uid) do
    repo.one(from r in TaskResult, where: r.result_uid == ^result_uid)
  end

  @doc """
  Fetches the current Task result: the newest result by `created_at`, with
  `id` as a deterministic tie-break.

  Read-only projection. No lock required. Returns nil when the Task has no
  results.
  """
  @spec fetch_current_result(Ecto.Repo.t(), String.t()) :: TaskResult.t() | nil
  def fetch_current_result(repo, task_uid) do
    repo.one(
      from r in TaskResult,
        where: r.task_uid == ^task_uid,
        order_by: [desc: r.inserted_at, desc: r.id],
        limit: 1
    )
  end

  @doc """
  Lists all Task results for one Task, ordered chronologically.

  Read-only query. No transaction or lock required.
  """
  @spec list_task_results(Ecto.Repo.t(), String.t()) :: [TaskResult.t()]
  def list_task_results(repo, task_uid) do
    repo.all(
      from r in TaskResult,
        where: r.task_uid == ^task_uid,
        order_by: [asc: r.inserted_at, asc: r.id]
    )
  end

  @doc """
  Lists all Task results for one Company, resolved through Task ownership.

  Read-only query. No transaction or lock required.
  """
  @spec list_company_results(Ecto.Repo.t(), String.t()) :: [TaskResult.t()]
  def list_company_results(repo, company_uid) do
    repo.all(
      from r in TaskResult,
        join: t in Task, on: r.task_uid == t.uid,
        where: t.company_uid == ^company_uid,
        order_by: [asc: r.inserted_at, asc: r.id]
    )
  end

  # ─── Validation helpers ───────────────────────────────────────────────────

  defp validate_company_exists(repo, company_uid) do
    case repo.get_by(Ankole.Company, uid: company_uid) do
      %Ankole.Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp fetch_task_for_update(repo, company_uid, task_uid) do
    case repo.one(
           from t in Task,
             where: t.uid == ^task_uid and t.company_uid == ^company_uid,
             lock: "FOR UPDATE"
         ) do
      %Task{} = task -> {:ok, task}
      nil -> {:error, :task_not_found}
    end
  end

  # ─── Execution reference validation ───────────────────────────────────────

  @real_reference_fields [
    :workflow_run_id,
    :workflow_agent_call_id,
    :background_agent_job_id,
    :background_agent_job_turn_id
  ]

  # Every real reference is normalized once, to the type its column already
  # stores: an integer id for the three bigint columns, a UUID for the turn.
  # A value that cannot be read as that type is rejected rather than dropped, so
  # a malformed reference never degrades into a missing one.
  defp normalize_execution_references(attrs) do
    Enum.reduce_while(@real_reference_fields, {:ok, %{}}, fn field, {:ok, acc} ->
      case normalize_reference_id(Map.get(attrs, field), reference_kind(field)) do
        {:ok, id} when not is_nil(id) ->
          {:cont, {:ok, Map.put(acc, field, id)}}

        {:ok, nil} ->
          {:cont, {:ok, acc}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  defp reference_kind(:background_agent_job_turn_id), do: :uuid
  defp reference_kind(_field), do: :integer

  defp normalize_reference_id(nil, _kind), do: {:ok, nil}

  defp normalize_reference_id(value, :integer) when is_integer(value) do
    if value > 0, do: {:ok, value}, else: {:error, {:invalid_execution_reference, value}}
  end

  defp normalize_reference_id(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _other -> {:error, {:invalid_execution_reference, value}}
    end
  end

  defp normalize_reference_id(value, :uuid) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, {:invalid_execution_reference, value}}
    end
  end

  defp normalize_reference_id(value, _kind), do: {:error, {:invalid_execution_reference, value}}

  defp validate_execution_references(repo, company_uid, refs) do
    with :ok <- require_real_execution_reference(refs),
         {:ok, run} <- fetch_workflow_run(repo, refs[:workflow_run_id]),
         {:ok, call} <- fetch_workflow_agent_call(repo, refs[:workflow_agent_call_id]),
         :ok <- validate_workflow_pair(run, call),
         {:ok, job} <- fetch_background_job(repo, refs[:background_agent_job_id]),
         {:ok, turn} <- fetch_background_job_turn(repo, refs[:background_agent_job_turn_id]),
         :ok <- validate_background_pair(job, turn),
         {:ok, turn_job} <- fetch_turn_job(repo, turn),
         :ok <- validate_execution_owner(repo, company_uid, :workflow_run_id, owner_of_run(run)),
         :ok <- validate_execution_owner(repo, company_uid, :workflow_agent_call_id, owner_of_call(call)),
         :ok <- validate_execution_owner(repo, company_uid, :background_agent_job_id, owner_of_job(job)),
         :ok <-
           validate_execution_owner(repo, company_uid, :background_agent_job_turn_id, owner_of_job(turn_job)) do
      :ok
    end
  end

  defp require_real_execution_reference(refs) do
    if Enum.any?(@real_reference_fields, &(not is_nil(Map.get(refs, &1)))) do
      :ok
    else
      {:error, :execution_reference_required}
    end
  end

  # Execution rows are read without a lock. The Task row is already held FOR
  # UPDATE by the caller, and locking a second row in another subsystem would
  # order locks across the work hierarchy and the execution subsystems.

  defp fetch_workflow_run(_repo, nil), do: {:ok, nil}

  defp fetch_workflow_run(repo, run_id) do
    case repo.get(Run, run_id) do
      %Run{} = run -> {:ok, run}
      nil -> {:error, {:execution_reference_not_found, :workflow_run_id}}
    end
  end

  defp fetch_workflow_agent_call(_repo, nil), do: {:ok, nil}

  defp fetch_workflow_agent_call(repo, call_id) do
    case repo.get(AgentCall, call_id) do
      %AgentCall{} = call -> {:ok, call}
      nil -> {:error, {:execution_reference_not_found, :workflow_agent_call_id}}
    end
  end

  defp fetch_background_job(_repo, nil), do: {:ok, nil}

  defp fetch_background_job(repo, job_id) do
    case repo.get(Job, job_id) do
      %Job{} = job -> {:ok, job}
      nil -> {:error, {:execution_reference_not_found, :background_agent_job_id}}
    end
  end

  defp fetch_background_job_turn(_repo, nil), do: {:ok, nil}

  defp fetch_background_job_turn(repo, turn_id) do
    case repo.get(Turn, turn_id) do
      %Turn{} = turn -> {:ok, turn}
      nil -> {:error, {:execution_reference_not_found, :background_agent_job_turn_id}}
    end
  end

  defp owner_of_run(nil), do: nil
  defp owner_of_run(%Run{agent_uid: agent_uid}), do: agent_uid

  defp owner_of_call(nil), do: nil
  defp owner_of_call(%AgentCall{agent_uid: agent_uid}), do: agent_uid

  defp owner_of_job(nil), do: nil
  defp owner_of_job(%Job{agent_uid: agent_uid}), do: agent_uid

  # A turn names its owning job, so a cited turn is owned by the Agent that runs
  # that job. The job must exist, which the turn's own foreign key already
  # guarantees, but reading it keeps the owner an explicit checked row.
  defp fetch_turn_job(_repo, nil), do: {:ok, nil}

  defp fetch_turn_job(repo, %Turn{job_id: job_id}) do
    case repo.get(Job, job_id) do
      %Job{} = job -> {:ok, job}
      nil -> {:error, {:execution_reference_not_found, :background_agent_job_turn_id}}
    end
  end

  defp validate_workflow_pair(nil, _call), do: :ok
  defp validate_workflow_pair(_run, nil), do: :ok

  defp validate_workflow_pair(%Run{id: run_id}, %AgentCall{run_id: call_run_id}) do
    if run_id == call_run_id, do: :ok, else: {:error, :workflow_agent_call_run_mismatch}
  end

  defp validate_background_pair(nil, _turn), do: :ok
  defp validate_background_pair(_job, nil), do: :ok

  defp validate_background_pair(%Job{id: job_id}, %Turn{job_id: turn_job_id}) do
    if job_id == turn_job_id, do: :ok, else: {:error, :background_agent_job_turn_job_mismatch}
  end

  defp validate_execution_owner(_repo, _company_uid, _field, nil), do: :ok

  defp validate_execution_owner(repo, company_uid, field, agent_uid) do
    case Principals.get_principal(repo, agent_uid) do
      {:ok, %Principal{type: :agent} = principal} ->
        if MembershipStore.member?(repo, company_uid, principal.uid) do
          :ok
        else
          {:error, {:execution_reference_wrong_company, field}}
        end

      {:ok, %Principal{type: type}} ->
        {:error, {:invalid_execution_owner_type, field, type}}

      {:error, :not_found} ->
        {:error, {:execution_reference_owner_not_found, field}}
    end
  end

  # An executor list is normalized as a whole or rejected as a whole. Dropping
  # one unnormalizable UID would shrink the executor set that reviewer
  # independence is judged against, so a real executor could disappear from the
  # Result and then review it. Order and duplicates are preserved.
  defp normalize_executor_uids(nil), do: {:ok, nil}

  defp normalize_executor_uids(uids) when is_list(uids) do
    Enum.reduce_while(uids, {:ok, []}, fn uid, {:ok, acc} ->
      case Principals.normalize_uid(uid) do
        {:ok, normalized_uid} -> {:cont, {:ok, acc ++ [normalized_uid]}}
        {:error, :invalid_uid} -> {:halt, {:error, {:invalid_executor_uid, uid}}}
      end
    end)
  end

  defp normalize_executor_uids(_uids), do: {:error, :invalid_executor_uids}

  # ─── Insert helpers ───────────────────────────────────────────────────────

  defp insert_result(repo, attrs) do
    %TaskResult{}
    |> TaskResult.changeset(attrs)
    |> repo.insert()
  end

  # ─── Review invalidation on superseding result ────────────────────────────

  defp invalidate_prior_review_if_superseded(repo, task_uid, %TaskResult{} = result) do
    prior_result = fetch_prior_result(repo, task_uid, result.id)

    case prior_result do
      nil ->
        :ok

      %TaskResult{} ->
        case fetch_non_invalidated_review(repo, prior_result.result_uid) do
          nil ->
            :ok

          %ReviewRecord{} = review ->
            invalidate_review_in_tx(repo, review, result.result_uid)
        end
    end
  end

  defp fetch_prior_result(repo, task_uid, exclude_id) do
    repo.one(
      from r in TaskResult,
        where: r.task_uid == ^task_uid and r.id != ^exclude_id,
        order_by: [desc: r.inserted_at, desc: r.id],
        limit: 1
    )
  end

  defp fetch_non_invalidated_review(repo, result_uid) do
    repo.one(
      from rv in ReviewRecord,
        where: rv.reviewed_result_uid == ^result_uid and is_nil(rv.invalidated_at),
        lock: "FOR UPDATE",
        limit: 1
    )
  end

  defp invalidate_review_in_tx(repo, %ReviewRecord{} = review, new_result_uid) do
    now = DateTime.utc_now(:microsecond)

    with {:ok, review} <-
           review
           |> ReviewRecord.changeset(%{
             invalidated_at: now,
             invalidation_reason: "superseded by result #{new_result_uid}"
           })
           |> repo.update(),
         {:ok, _event} <-
           %ReviewEvent{}
           |> ReviewEvent.changeset(%{
             review_uid: review.review_uid,
             event_type: "invalidated",
             reviewer_uid: nil,
             metadata: %{"reason" => "superseded", "new_result_uid" => new_result_uid}
           })
           |> repo.insert() do
      {:ok, review}
    else
      {:error, _} = error -> error
    end
  end
end