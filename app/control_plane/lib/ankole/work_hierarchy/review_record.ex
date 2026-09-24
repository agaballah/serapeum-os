defmodule Ankole.WorkHierarchy.ReviewRecord do
  @moduledoc """
  Durable formal review of a Task result, scoped to one Company.

  A ReviewRecord captures the structural fact that one Principal formally
  reviewed one Task result against stated criteria and recorded a verdict.
  The verdict is immutable after commit. A later re-review produces a new
  review row with a new stable identity.

  A review may be invalidated when a newer result supersedes the result it
  examined. Invalidation marks the review as no longer applicable; it does not
  change the verdict that was recorded and does not delete the row.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Task
  alias Ankole.WorkHierarchy.TaskResult

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @canonical_verdicts ~w(APPROVED CHANGES_REQUIRED REJECTED INCONCLUSIVE)

  schema "review_records" do
    field :review_uid, :string
    field :criteria_text, :string
    field :verdict, :string
    field :rationale_text, :string
    field :invalidated_at, :utc_datetime_usec
    field :invalidation_reason, :string

    belongs_to :task, Task,
      foreign_key: :task_uid,
      references: :uid,
      type: :string

    belongs_to :reviewed_result, TaskResult,
      foreign_key: :reviewed_result_uid,
      references: :result_uid,
      type: :string

    belongs_to :reviewer, Principal,
      foreign_key: :reviewer_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for ReviewRecord rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :review_uid,
      :task_uid,
      :reviewed_result_uid,
      :reviewer_principal_uid,
      :criteria_text,
      :verdict,
      :rationale_text,
      :invalidated_at,
      :invalidation_reason
    ])
    |> normalize_blank([:review_uid, :criteria_text, :rationale_text, :invalidation_reason])
    |> validate_required([:review_uid, :task_uid, :reviewed_result_uid, :reviewer_principal_uid,
                          :criteria_text, :verdict, :rationale_text])
    |> validate_inclusion(:verdict, @canonical_verdicts)
    |> check_constraint(:review_uid, name: :review_records_review_uid_present)
    |> unique_constraint(:review_uid, name: :review_records_review_uid_index)
    |> validate_invalidated_fields_coherence()
    |> foreign_key_constraint(:task_uid)
    |> foreign_key_constraint(:reviewed_result_uid)
    |> foreign_key_constraint(:reviewer_principal_uid)
  end

  defp validate_invalidated_fields_coherence(changeset) do
    invalidated_at = get_field(changeset, :invalidated_at)
    invalidation_reason = get_field(changeset, :invalidation_reason)

    all_nil = is_nil(invalidated_at) and is_nil(invalidation_reason)
    all_present = not is_nil(invalidated_at) and not is_nil(invalidation_reason)

    if all_nil or all_present do
      changeset
    else
      add_error(changeset, :invalidation_reason,
        "must be present when invalidated_at is present, and absent otherwise")
    end
  end
end