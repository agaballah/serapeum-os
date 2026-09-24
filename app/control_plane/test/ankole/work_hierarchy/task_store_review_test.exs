defmodule Ankole.WorkHierarchy.TaskStoreReviewTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.ResultStore
  alias Ankole.WorkHierarchy.ReviewRecord
  alias Ankole.WorkHierarchy.ReviewStore

  @moduledoc """
  Tests for P6 ReviewRecord schema, ReviewStore mutations, reviewer
  independence, verdict immutability, and invalidation behavior.
  """

  defp transact(fun), do: Repo.transact(fn repo -> fun.(repo) end)

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])
    defaults = %{
      uid: "test-company-#{suffix}",
      name: "test-company-#{suffix}",
      display_name: "Test Company",
      status: :active,
      metadata: %{},
      owner_principal_uid: owner_uid
    }
    {:ok, company} = %Company{} |> Company.changeset(Map.merge(defaults, attrs)) |> Repo.insert()
    company
  end

  defp reviewer_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  defp human_owner_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  describe "create_review" do
    test "valid review creation emits review_events created row" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-review-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-review-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      assert review.review_uid != nil
      assert review.verdict == "APPROVED"
      assert review.invalidated_at == nil

      events = Repo.all(from e in Ankole.WorkHierarchy.ReviewEvent,
        where: e.review_uid == ^review.review_uid
      )
      assert length(events) == 1
      assert hd(events).event_type == "created"
    end

    test "unknown Task is rejected by create_result" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, "nonexistent-task", %{
          result_uid: "result-unknown-task-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, "nonexistent-task", "result-unknown-task-001", human.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)
    end

    test "unknown Result is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-unk-result-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :reviewed_result_not_found} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, "nonexistent-result", human.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)
    end

    test "result belonging to a different Task is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-mismatch-a",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-mismatch-b",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result_a} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task_a.uid, %{
          result_uid: "result-mismatch-a",
          execution_attempt_ref: "attempt-001"
        })
      end)

      assert {:error, :reviewed_result_not_found} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task_b.uid, result_a.result_uid, human.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)
    end

    test "nil reviewed_result_uid is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-nil-result-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :reviewed_result_uid_required} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, nil, human.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)
    end

    test "reviewer who is an executor is rejected for independence" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-indep-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-indep-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      assert {:error, :reviewer_is_executor} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, human.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)
    end

    test "independent reviewer is accepted" do
      human = human_owner_fixture()
      %{principal: reviewer} = PrincipalsFixtures.human_fixture()
      company = company_fixture(human.uid)

      {:ok, _m_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _m_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-indep-ok-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-indep-ok-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      assert review.reviewer_principal_uid == reviewer.uid
    end

    test "invalid verdict is rejected" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-verdict-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-verdict-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      assert {:error, _} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "INVALID",
          rationale_text: "Rationale."
        })
      end)
    end

    test "cross-Company review is rejected" do
      human = human_owner_fixture()
      owner_b = human_owner_fixture()
      company_a = company_fixture(human.uid)
      company_b = company_fixture(owner_b.uid)

      {:ok, _m_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_a.uid, human.uid)
      end)
      {:ok, _m_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_b.uid, owner_b.uid)
      end)

      {:ok, task_b} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company_b.uid, %{
          uid: "task-cross-review",
          creator_principal_uid: owner_b.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result_b} = transact(fn repo ->
        ResultStore.create_result(repo, company_b.uid, task_b.uid, %{
          result_uid: "result-cross-review",
          execution_attempt_ref: "attempt-001"
        })
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        ReviewStore.create_review(repo, company_a.uid, task_b.uid, result_b.result_uid, human.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)
    end
  end

  describe "invalidate_review" do
    test "explicit invalidation sets invalidated_at and reason" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-inv-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-inv-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      {:ok, _review} = transact(fn repo ->
        ReviewStore.invalidate_review(repo, company.uid, review.review_uid, "manual re-review")
      end)

      refreshed = Repo.get(Ankole.WorkHierarchy.ReviewRecord, review.id)
      assert refreshed.invalidated_at != nil
      assert refreshed.invalidation_reason == "manual re-review"
      assert refreshed.verdict == "APPROVED"

      events = Repo.all(from e in Ankole.WorkHierarchy.ReviewEvent,
        where: e.review_uid == ^review.review_uid
      )
      assert "invalidated" in Enum.map(events, & &1.event_type)
    end

    test "invalidation of already-invalidated review is rejected" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-dbl-inv-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-dbl-inv-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      {:ok, _} = transact(fn repo ->
        ReviewStore.invalidate_review(repo, company.uid, review.review_uid, "first")
      end)

      assert {:error, :review_already_invalidated} = transact(fn repo ->
        ReviewStore.invalidate_review(repo, company.uid, review.review_uid, "second")
      end)
    end

    test "unknown review invalidation is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:error, :review_not_found} = transact(fn repo ->
        ReviewStore.invalidate_review(repo, company.uid, "nonexistent-review", "reason")
      end)
    end
  end

  describe "read-only listing" do
    test "list_task_reviews returns reviews for one task" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-ltr-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-ltr-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      {:ok, _r1} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "c1", verdict: "APPROVED", rationale_text: "r1"
        })
      end)

      reviews = ReviewStore.list_task_reviews(Repo, task.uid)
      assert length(reviews) == 1
    end

    test "list_result_reviews returns reviews for one result" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-lrr-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-lrr-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      {:ok, _r1} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
          criteria_text: "c1", verdict: "APPROVED", rationale_text: "r1"
        })
      end)

      reviews = ReviewStore.list_result_reviews(Repo, result.result_uid)
      assert length(reviews) == 1
    end
  end
end

