defmodule Ankole.WorkHierarchy.ReviewStore do
  @moduledoc """
  Persistence and query operations for formal ReviewRecord rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Domain-changing operations acquire the Task row lock inside that
  transaction and validate structural integrity (company scope, reviewer
  independence, verdict domain) before insert. This layer performs no
  authorization checks beyond structural integrity.
  """

  import Ecto.Query

  alias Ankole.Principals
  alias Ankole.Principals.Principal
  alias Ankole.Company.Membership
  alias Ankole.WorkHierarchy.Task
  alias Ankole.WorkHierarchy.TaskResult
  alias Ankole.WorkHierarchy.ReviewRecord
  alias Ankole.WorkHierarchy.ReviewEvent

  @doc """
  Creates a formal ReviewRecord for an existing Task result, scoped to the
  given Company.

  `company_uid` is authoritative. The Task row is locked FOR UPDATE. The
  reviewed Result must be non-nil, must belong to the Task, and the reviewer
  Principal MUST NOT appear in the Result's `executor_principal_uids`.

  The reviewer Principal must exist, be active, and belong to `company_uid`.
  Status is judged on the reviewer row already locked by this path, so the
  check adds no lock of its own. A Principal type may review; this layer
  performs no authorization beyond structural integrity.
  """
  @spec create_review(
          Ecto.Repo.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          map()
        ) :: {:ok, ReviewRecord.t()} | {:error, term()}
  def create_review(repo, company_uid, task_uid, result_uid, reviewer_principal_uid, attrs) do
    with :ok <- validate_company_exists(repo, company_uid),
         {:ok, task} <- fetch_task_for_update(repo, company_uid, task_uid),
         :ok <- validate_result_uid_present(result_uid),
         {:ok, result} <- fetch_result_for_review(repo, task_uid, result_uid),
         {:ok, normalized_reviewer} <- normalize_reviewer_uid(reviewer_principal_uid),
         {:ok, reviewer} <- fetch_reviewer_for_update(repo, normalized_reviewer),
         :ok <- validate_reviewer_active(reviewer),
         :ok <- validate_reviewer_in_company(repo, normalized_reviewer, company_uid),
         :ok <- validate_reviewer_independence(result, normalized_reviewer),
         attrs <- Map.put(attrs, :reviewed_result_uid, result.result_uid),
         attrs <- Map.put(attrs, :reviewer_principal_uid, normalized_reviewer),
         attrs <- Map.put(attrs, :task_uid, task.uid),
         attrs <- put_review_uid_if_missing(attrs),
         {:ok, review} <- insert_review(repo, attrs),
         {:ok, _event} <- insert_review_event(repo, review, "created", normalized_reviewer) do
      {:ok, review}
    end
  end

  @doc """
  Fetches one Review by stable UID.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_review(Ecto.Repo.t(), String.t()) :: ReviewRecord.t() | nil
  def fetch_review(repo, review_uid) do
    repo.one(from r in ReviewRecord, where: r.review_uid == ^review_uid)
  end

  @doc """
  Invalidates an existing non-invalidated Review, recording the reason and
  emitting a `review_events` `invalidated` row that names the invalidator.

  The invalidator is a Principal distinct from the reviewer: invalidating a
  verdict is not the same act as delivering one, so the two roles keep their own
  validation and their own errors. The invalidator must be an active Principal
  belonging to `company_uid`. `review_events.reviewer_uid` carries the Principal
  responsible for that event, so a manual invalidation always names its actor.

  This is the manual path only. `Ankole.WorkHierarchy.ResultStore` invalidates
  superseded reviews as a domain cascade and records that event without a
  Principal, which stays legitimate.
  """
  @spec invalidate_review(Ecto.Repo.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, ReviewRecord.t()} | {:error, term()}
  def invalidate_review(repo, company_uid, review_uid, invalidator_principal_uid, reason) do
    with :ok <- validate_company_exists(repo, company_uid),
         :ok <- validate_invalidator(repo, company_uid, invalidator_principal_uid),
         {:ok, review} <- fetch_review_for_update(repo, review_uid),
         :ok <- validate_review_not_invalidated(review),
         :ok <- validate_review_company_scope(repo, review, company_uid),
         attrs <- %{invalidation_reason: reason},
         {:ok, review} <- apply_invalidation(repo, review, attrs, invalidator_principal_uid) do
      {:ok, review}
    end
  end

  @doc """
  Lists all Reviews for one Task, ordered chronologically.

  Read-only query. No transaction or lock required.
  """
  @spec list_task_reviews(Ecto.Repo.t(), String.t()) :: [ReviewRecord.t()]
  def list_task_reviews(repo, task_uid) do
    repo.all(
      from r in ReviewRecord,
        where: r.task_uid == ^task_uid,
        order_by: [asc: r.inserted_at, asc: r.id]
    )
  end

  @doc """
  Lists all Reviews against one Result, ordered chronologically.

  Read-only query. No transaction or lock required.
  """
  @spec list_result_reviews(Ecto.Repo.t(), String.t()) :: [ReviewRecord.t()]
  def list_result_reviews(repo, result_uid) do
    repo.all(
      from r in ReviewRecord,
        where: r.reviewed_result_uid == ^result_uid,
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

  defp validate_result_uid_present(nil), do: {:error, :reviewed_result_uid_required}
  defp validate_result_uid_present(result_uid) when is_binary(result_uid) do
    if String.trim(result_uid) == "" do
      {:error, :reviewed_result_uid_required}
    else
      :ok
    end
  end
  defp validate_result_uid_present(_uid), do: {:error, :reviewed_result_uid_required}

  defp fetch_result_for_review(repo, task_uid, result_uid) do
    case repo.one(
           from r in TaskResult,
             where: r.result_uid == ^result_uid and r.task_uid == ^task_uid
         ) do
      %TaskResult{} = result -> {:ok, result}
      nil -> {:error, :reviewed_result_not_found}
    end
  end

  defp normalize_reviewer_uid(reviewer_uid) do
    Principals.normalize_uid(reviewer_uid)
  end

  defp fetch_reviewer_for_update(repo, reviewer_uid) do
    case repo.one(
           from p in Principal,
             where: p.uid == ^reviewer_uid,
             lock: "FOR UPDATE"
         ) do
      %Principal{} = principal -> {:ok, principal}
      nil -> {:error, :reviewer_not_found}
    end
  end

  # The reviewer row is already locked by fetch_reviewer_for_update/2, so status
  # is judged on that same read. Any status other than active is refused, which
  # keeps the rule correct if another status is added later.
  defp validate_reviewer_active(%Principal{status: :active}), do: :ok
  defp validate_reviewer_active(%Principal{status: status}), do: {:error, {:reviewer_not_active, status}}

  defp validate_reviewer_in_company(repo, reviewer_uid, company_uid) do
    case repo.one(
           from m in Membership,
             where: m.principal_uid == ^reviewer_uid and m.company_uid == ^company_uid
         ) do
      %Membership{} -> :ok
      nil -> {:error, :reviewer_not_in_company}
    end
  end

  defp validate_reviewer_independence(%TaskResult{executor_principal_uids: nil}, _reviewer_uid),
    do: :ok

  defp validate_reviewer_independence(%TaskResult{executor_principal_uids: executors}, reviewer_uid) do
    if reviewer_uid in executors do
      {:error, :reviewer_is_executor}
    else
      :ok
    end
  end

  defp put_review_uid_if_missing(attrs) do
    case Map.has_key?(attrs, :review_uid) do
      true -> attrs
      false -> Map.put(attrs, :review_uid, generate_review_uid())
    end
  end

  defp generate_review_uid do
    suffix = System.unique_integer([:positive])
    "review-#{suffix}"
  end

  defp fetch_review_for_update(repo, review_uid) do
    case repo.one(
           from r in ReviewRecord,
             where: r.review_uid == ^review_uid,
             lock: "FOR UPDATE"
         ) do
      %ReviewRecord{} = review -> {:ok, review}
      nil -> {:error, :review_not_found}
    end
  end

  defp validate_review_not_invalidated(%ReviewRecord{invalidated_at: nil}), do: :ok
  defp validate_review_not_invalidated(%ReviewRecord{}), do: {:error, :review_already_invalidated}

  defp validate_review_company_scope(repo, %ReviewRecord{task_uid: review_task_uid}, company_uid) do
    case repo.one(from t in Task, where: t.uid == ^review_task_uid and t.company_uid == ^company_uid) do
      %Task{} -> :ok
      nil -> {:error, :review_not_found}
    end
  end

  # ─── Invalidator validation ──────────────────────────────────────────────

  # The invalidator is a separate domain role from the reviewer, so it carries
  # its own errors rather than borrowing the reviewer's. The row is locked
  # because the invalidation is judged against the Principal as it stands inside
  # the same transaction that writes the event naming it.
  defp validate_invalidator(repo, company_uid, invalidator_principal_uid) do
    with {:ok, normalized_uid} <- normalize_invalidator_uid(invalidator_principal_uid),
         {:ok, principal} <- fetch_invalidator_for_update(repo, normalized_uid),
         :ok <- validate_invalidator_active(principal),
         :ok <- validate_invalidator_in_company(repo, principal.uid, company_uid) do
      :ok
    end
  end

  # PrincipalKey.normalize/1 already rejects nil as :invalid_uid. Absence is a
  # distinct condition from a malformed UID, so it is answered before
  # normalization rather than folded into it.
  defp normalize_invalidator_uid(nil), do: {:error, :invalidator_uid_required}
  defp normalize_invalidator_uid(uid), do: Principals.normalize_uid(uid)

  defp fetch_invalidator_for_update(repo, invalidator_uid) do
    case repo.one(
           from p in Principal,
             where: p.uid == ^invalidator_uid,
             lock: "FOR UPDATE"
         ) do
      %Principal{} = principal -> {:ok, principal}
      nil -> {:error, :invalidator_not_found}
    end
  end

  defp validate_invalidator_active(%Principal{status: :active}), do: :ok
  defp validate_invalidator_active(%Principal{status: status}), do: {:error, {:invalidator_not_active, status}}

  defp validate_invalidator_in_company(repo, invalidator_uid, company_uid) do
    case repo.one(
           from m in Membership,
             where: m.principal_uid == ^invalidator_uid and m.company_uid == ^company_uid
         ) do
      %Membership{} -> :ok
      nil -> {:error, :invalidator_not_in_company}
    end
  end

  # ─── Insert helpers ───────────────────────────────────────────────────────

  defp insert_review(repo, attrs) do
    %ReviewRecord{}
    |> ReviewRecord.changeset(attrs)
    |> repo.insert()
  end

  defp insert_review_event(repo, %ReviewRecord{} = review, event_type, reviewer_uid) do
    %ReviewEvent{}
    |> ReviewEvent.changeset(%{
      review_uid: review.review_uid,
      event_type: event_type,
      reviewer_uid: reviewer_uid,
      metadata: nil
    })
    |> repo.insert()
  end

  defp apply_invalidation(repo, %ReviewRecord{} = review, attrs, invalidator_uid) do
    reason = Map.get(attrs, :invalidation_reason)

    changeset =
      review
      |> ReviewRecord.changeset(%{
        invalidated_at: DateTime.utc_now(:microsecond),
        invalidation_reason: reason
      })

    with {:ok, review} <- repo.update(changeset),
         {:ok, _event} <-
           insert_review_event(repo, review, "invalidated", invalidator_uid) do
      {:ok, review}
    else
      {:error, _} = error -> error
    end
  end
end
