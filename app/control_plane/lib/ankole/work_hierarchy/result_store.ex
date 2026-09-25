defmodule Ankole.WorkHierarchy.ResultStore do
  @moduledoc """
  Persistence and query operations for Task result rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Domain-changing operations acquire the Task row lock inside that
  transaction and validate structural integrity against the target Company.
  This layer performs no authorization checks beyond structural integrity.
  """

  import Ecto.Query

  alias Ankole.Principals
  alias Ankole.WorkHierarchy.Task
  alias Ankole.WorkHierarchy.TaskResult
  alias Ankole.WorkHierarchy.ReviewRecord
  alias Ankole.WorkHierarchy.ReviewEvent

  @doc """
  Creates a durable Task result scoped to the given Company.

  `company_uid` is authoritative; any `company_uid` in `attrs` is ignored.
  The Task row is locked FOR UPDATE. If a newer result supersedes a prior
  result that already carries a non-invalidated review, that review is
  invalidated atomically within the same transaction and a `review_events`
  `invalidated` row is inserted.
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
         :ok <- validate_execution_reference(attrs),
         {:ok, normalized_executors} <- normalize_executor_uids(attrs[:executor_principal_uids]),
         attrs <- Map.put(attrs, :executor_principal_uids, normalized_executors),
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

  defp validate_execution_reference(attrs) do
    refs = [
      Map.get(attrs, :workflow_run_id),
      Map.get(attrs, :workflow_agent_call_id),
      Map.get(attrs, :background_agent_job_id),
      Map.get(attrs, :background_agent_job_turn_id),
      Map.get(attrs, :execution_attempt_ref)
    ]

    if Enum.all?(refs, &is_nil_or_blank/1) do
      {:error, :execution_reference_required}
    else
      :ok
    end
  end

  defp is_nil_or_blank(nil), do: true
  defp is_nil_or_blank(val) when is_binary(val), do: String.trim(val) == ""
  defp is_nil_or_blank(_val), do: false

  defp normalize_executor_uids(nil), do: {:ok, nil}

  defp normalize_executor_uids(uids) when is_list(uids) do
    normalized =
      Enum.reduce(uids, [], fn uid, acc ->
        case Principals.normalize_uid(uid) do
          {:ok, normalized_uid} -> acc ++ [normalized_uid]
          {:error, _} -> acc
        end
      end)

    {:ok, normalized}
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