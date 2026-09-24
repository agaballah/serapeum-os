defmodule Ankole.WorkHierarchy.TaskStoreResultTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.ResultStore
  alias Ankole.WorkHierarchy.ReviewRecord
  alias Ankole.WorkHierarchy.ReviewStore

  @moduledoc """
  Tests for P6 TaskResult schema, ResultStore mutations, and result
  invalidation behavior.
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

  defp human_owner_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  defp reviewer_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  describe "create_result" do
    test "valid result creation with stable result_uid" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-result-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      assert result.result_uid == "result-001"
      assert result.task_uid == task.uid
      assert result.execution_attempt_ref == "attempt-001"
      assert result.executor_principal_uids == [human.uid]

      refreshed = Repo.get(Ankole.WorkHierarchy.TaskResult, result.id)
      assert refreshed.result_uid == "result-001"
    end

    test "unknown Task is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, "nonexistent-task", %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001"
        })
      end)
    end

    test "cross-Company Task reference is rejected" do
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
          uid: "task-cross-001",
          creator_principal_uid: owner_b.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        ResultStore.create_result(repo, company_a.uid, task_b.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001"
        })
      end)
    end

    test "execution reference is required" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-ref-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :execution_reference_required} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001"
        })
      end)
    end

    test "execution_attempt_ref alone is a valid reference" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-attempt-001",
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
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      assert result.execution_attempt_ref == "attempt-001"
    end

    test "multiple results for one Task are supported" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-multi-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, result_2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          execution_attempt_ref: "attempt-002",
          executor_principal_uids: [human.uid]
        })
      end)

      results = Repo.all(from r in Ankole.WorkHierarchy.TaskResult, where: r.task_uid == ^task.uid)
      assert length(results) == 2

      current = ResultStore.fetch_current_result(Repo, task.uid)
      assert current.result_uid == "result-002"

      list = ResultStore.list_task_results(Repo, task.uid)
      assert length(list) == 2
      assert hd(list).result_uid == "result-001"
    end

    test "newer result invalidates prior non-invalidated review atomically" do
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

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result_1.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      refreshed = Repo.get(Ankole.WorkHierarchy.ReviewRecord, review.id)
      assert is_nil(refreshed.invalidated_at)

      {:ok, result_2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          execution_attempt_ref: "attempt-002",
          executor_principal_uids: [human.uid]
        })
      end)

      refreshed = Repo.get(Ankole.WorkHierarchy.ReviewRecord, review.id)
      assert refreshed.invalidated_at != nil
      assert refreshed.invalidation_reason != nil
      assert refreshed.invalidation_reason =~ "result-002"

      events = Repo.all(from e in Ankole.WorkHierarchy.ReviewEvent,
        where: e.review_uid == ^review.review_uid,
        order_by: [asc: e.inserted_at]
      )
      event_types = Enum.map(events, & &1.event_type)
      assert "invalidated" in event_types
    end

    test "newer result does not invalidate when no prior review exists" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-norev-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _r1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, _r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          execution_attempt_ref: "attempt-002",
          executor_principal_uids: [human.uid]
        })
      end)

      reviews = Repo.all(from r in Ankole.WorkHierarchy.ReviewRecord,
        where: r.task_uid == ^task.uid
      )
      assert Enum.empty?(reviews)
    end

    test "newer result does not double-invalidate an already invalidated review" do
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
          uid: "task-nodbl-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result_1.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      {:ok, _r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          execution_attempt_ref: "attempt-002",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, _r3} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-003",
          execution_attempt_ref: "attempt-003",
          executor_principal_uids: [human.uid]
        })
      end)

      refreshed = Repo.get(Ankole.WorkHierarchy.ReviewRecord, review.id)
      assert refreshed.invalidated_at != nil

      events = Repo.all(from e in Ankole.WorkHierarchy.ReviewEvent,
        where: e.review_uid == ^review.review_uid
      )
      assert length(events) == 2
    end

    test "historical result remains queryable after invalidation" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-hist-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, _r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          execution_attempt_ref: "attempt-002",
          executor_principal_uids: [human.uid]
        })
      end)

      assert Repo.get(Ankole.WorkHierarchy.TaskResult, result_1.id) != nil
      list = ResultStore.list_task_results(Repo, task.uid)
      assert length(list) == 2
    end
  end

  describe "read-only helpers" do
    test "fetch_result returns result by result_uid" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-fetch-001",
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
          result_uid: "result-fetch-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      found = ResultStore.fetch_result(Repo, result.result_uid)
      assert found != nil
      assert found.result_uid == "result-fetch-001"
    end

    test "fetch_current_result returns newest result by created_at" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-cur-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _r1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-cur-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      {:ok, r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-cur-002",
          execution_attempt_ref: "attempt-002"
        })
      end)

      current = ResultStore.fetch_current_result(Repo, task.uid)
      assert current.result_uid == "result-cur-002"
    end

    test "fetch_current_result returns nil when no results" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-cur-empty-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert ResultStore.fetch_current_result(Repo, task.uid) == nil
    end

    test "list_company_results resolves through task ownership" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        Ankole.WorkHierarchy.TaskStore.create_task(repo, company.uid, %{
          uid: "task-lcr-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _r} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-lcr-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      results = ResultStore.list_company_results(Repo, company.uid)
      assert length(results) == 1
      assert hd(results).result_uid == "result-lcr-001"
    end
  end
end

