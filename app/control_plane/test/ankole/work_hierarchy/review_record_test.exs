defmodule Ankole.WorkHierarchy.ReviewRecordTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.ReviewRecord

  @moduledoc """
  Tests for Ankole.WorkHierarchy.ReviewRecord schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Passes QA.",
        verdict: "APPROVED",
        rationale_text: "LGTM."
      })

      assert changeset.valid?
    end

    test "review_uid is required" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale."
      })

      assert Enum.any?(changeset.errors, fn {:review_uid, _} -> true; _ -> false end)
    end

    test "blank review_uid is rejected by check constraint" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "   ",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale."
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:review_uid, _} -> true; _ -> false end)
    end

    test "task_uid is required" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale."
      })

      assert Enum.any?(changeset.errors, fn {:task_uid, _} -> true; _ -> false end)
    end

    test "reviewed_result_uid is required by changeset" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale."
      })

      assert Enum.any?(changeset.errors, fn {:reviewed_result_uid, _} -> true; _ -> false end)
    end

    test "reviewer_principal_uid is required" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale."
      })

      assert Enum.any?(changeset.errors, fn {:reviewer_principal_uid, _} -> true; _ -> false end)
    end

    test "verdict accepts all four canonical values" do
      for verdict <- ["APPROVED", "CHANGES_REQUIRED", "REJECTED", "INCONCLUSIVE"] do
        changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
          review_uid: "review-001",
          task_uid: "task-001",
          reviewed_result_uid: "result-001",
          reviewer_principal_uid: "human-001",
          criteria_text: "Criteria.",
          verdict: verdict,
          rationale_text: "Rationale."
        })

        assert changeset.valid?, "verdict #{verdict} should be valid"
      end
    end

    test "invalid verdict is rejected" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "INVALID",
        rationale_text: "Rationale."
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:verdict, _} -> true; _ -> false end)
    end

    test "invalidated_at and invalidation_reason coherence: both nil" do
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale."
      })

      assert changeset.valid?
    end

    test "invalidated_at and invalidation_reason coherence: both present" do
      now = DateTime.utc_now(:microsecond)
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale.",
        invalidated_at: now,
        invalidation_reason: "superseded"
      })

      assert changeset.valid?
    end

    test "invalidated_at alone is rejected" do
      now = DateTime.utc_now(:microsecond)
      changeset = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "review-001",
        task_uid: "task-001",
        reviewed_result_uid: "result-001",
        reviewer_principal_uid: "human-001",
        criteria_text: "Criteria.",
        verdict: "APPROVED",
        rationale_text: "Rationale.",
        invalidated_at: now,
        invalidation_reason: nil
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:invalidation_reason, _} -> true; _ -> false end)
    end

    test "unique constraint on review_uid is wired" do
      constraints = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "r1", task_uid: "t1", reviewed_result_uid: "r2",
        reviewer_principal_uid: "h1", criteria_text: "c", verdict: "APPROVED", rationale_text: "r"
      }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :unique and c.constraint == "review_records_review_uid_index"
             end)
    end

    test "FK constraints are wired" do
      constraints = ReviewRecord.changeset(%ReviewRecord{}, %{
        review_uid: "r1", task_uid: "t1", reviewed_result_uid: "r2",
        reviewer_principal_uid: "h1", criteria_text: "c", verdict: "APPROVED", rationale_text: "r"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :task_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :reviewed_result_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :reviewer_principal_uid and c.type == :foreign_key end)
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = ReviewRecord.__schema__(:fields)
      assert :id in fields
      assert :review_uid in fields
      assert :task_uid in fields
      assert :reviewed_result_uid in fields
      assert :reviewer_principal_uid in fields
      assert :criteria_text in fields
      assert :verdict in fields
      assert :rationale_text in fields
      assert :invalidated_at in fields
      assert :invalidation_reason in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "primary key is id" do
      assert ReviewRecord.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "task belongs_to targets Task" do
      assoc = ReviewRecord.__schema__(:association, :task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == ReviewRecord
      assert assoc.owner_key == :task_uid
    end

    test "reviewed_result belongs_to targets TaskResult" do
      assoc = ReviewRecord.__schema__(:association, :reviewed_result)
      assert assoc.related == Ankole.WorkHierarchy.TaskResult
      assert assoc.owner == ReviewRecord
      assert assoc.owner_key == :reviewed_result_uid
    end

    test "reviewer belongs_to targets Principal" do
      assoc = ReviewRecord.__schema__(:association, :reviewer)
      assert assoc.related == Ankole.Principals.Principal
      assert assoc.owner == ReviewRecord
      assert assoc.owner_key == :reviewer_principal_uid
    end
  end

  describe "field types" do
    test "review_uid is stored as :string" do
      assert ReviewRecord.__schema__(:type, :review_uid) == :string
    end

    test "verdict is stored as :string" do
      assert ReviewRecord.__schema__(:type, :verdict) == :string
    end

    test "invalidated_at is stored as :utc_datetime_usec" do
      assert ReviewRecord.__schema__(:type, :invalidated_at) == :utc_datetime_usec
    end

    test "reviewer_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert ReviewRecord.__schema__(:type, :reviewer_principal_uid) == Ankole.Ecto.PrincipalKey
    end
  end
end
