defmodule Ankole.WorkHierarchy.TaskStoreResultTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.ExecutionReferenceFixtures
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.ResultStore
  alias Ankole.WorkHierarchy.ReviewRecord
  alias Ankole.WorkHierarchy.ReviewStore
  alias Ankole.WorkHierarchy.TaskStore

  @moduledoc """
  Tests for P6 TaskResult schema, ResultStore mutations, and result
  invalidation behavior.
  """

  defp transact(fun), do: Repo.transact(fn repo -> fun.(repo) end)

  # A Result must cite a real execution record owned by an Agent of the Task's
  # Company. Existing result-behavior tests use this to satisfy that requirement
  # without restating the Company setup in each test.
  defp execution_run_fixture(company) do
    %{principal: agent} = PrincipalsFixtures.agent_fixture()

    {:ok, _membership} = transact(fn repo ->
      Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
    end)

    ExecutionReferenceFixtures.run_fixture(agent.uid)
  end


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

      run = execution_run_fixture(company)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          workflow_run_id: run.id,
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

    test "execution_attempt_ref alone does not satisfy the reference requirement" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-attempt-001",
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
          result_uid: "result-001",
          execution_attempt_ref: "attempt-001"
        })
      end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
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

      run = execution_run_fixture(company)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          workflow_run_id: run.id,
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, result_2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          workflow_run_id: run.id,
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
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, _r1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          workflow_run_id: run.id,
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, _r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          workflow_run_id: run.id,
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
          workflow_run_id: run.id,
          execution_attempt_ref: "attempt-002",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, _r3} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-003",
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, result_1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-001",
          workflow_run_id: run.id,
          execution_attempt_ref: "attempt-001",
          executor_principal_uids: [human.uid]
        })
      end)

      {:ok, _r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-002",
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-fetch-001",
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, _r1} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-cur-001",
          workflow_run_id: run.id,
          execution_attempt_ref: "attempt-001"
        })
      end)

      {:ok, r2} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-cur-002",
          workflow_run_id: run.id,
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

      run = execution_run_fixture(company)

      {:ok, _r} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "result-lcr-001",
          workflow_run_id: run.id,
          execution_attempt_ref: "attempt-001"
        })
      end)

      results = ResultStore.list_company_results(Repo, company.uid)
      assert length(results) == 1
      assert hd(results).result_uid == "result-lcr-001"
    end
  end

  # ─── B-11: execution reference ownership ──────────────────────────────────

  describe "create_result — B11 execution reference validation" do
    setup do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-b11-#{System.unique_integer([:positive])}",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      %{company: company, human: human, task: task}
    end

    defp same_company_agent(company) do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      agent
    end

    defp other_company_agent do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      agent
    end

    # ─── workflow_run_id ─────────────────────────────────────────────────────

    test "B11-T1 workflow_run_id: valid same-Company reference succeeds", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t1", workflow_run_id: run.id})
               end)

      assert result.workflow_run_id == run.id
    end

    test "B11-T2 workflow_run_id: cross-Company reference rejects and persists nothing", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(other_company_agent().uid)

      assert {:error, {:execution_reference_wrong_company, :workflow_run_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t2", workflow_run_id: run.id})
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T3 workflow_run_id: nonexistent reference rejects with a typed error", %{company: company, task: task} do
      assert {:error, {:execution_reference_not_found, :workflow_run_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t3",
                   workflow_run_id: 999_999_999
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T4 workflow_run_id: nil reference stays valid beside a verified one", %{company: company, task: task} do
      job = ExecutionReferenceFixtures.job_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t4",
                   background_agent_job_id: job.id
                 })
               end)

      assert is_nil(result.workflow_run_id)
    end

    # ─── workflow_agent_call_id ──────────────────────────────────────────────

    test "B11-T5 workflow_agent_call_id: valid same-Company reference succeeds", %{company: company, task: task} do
      agent = same_company_agent(company)
      call = ExecutionReferenceFixtures.agent_call_fixture(ExecutionReferenceFixtures.run_fixture(agent.uid), agent.uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t5",
                   workflow_agent_call_id: call.id
                 })
               end)

      assert result.workflow_agent_call_id == call.id
    end

    test "B11-T6 workflow_agent_call_id: cross-Company reference rejects and persists nothing", %{company: company, task: task} do
      foreign_agent = other_company_agent()
      call = ExecutionReferenceFixtures.agent_call_fixture(ExecutionReferenceFixtures.run_fixture(foreign_agent.uid), foreign_agent.uid)

      assert {:error, {:execution_reference_wrong_company, :workflow_agent_call_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t6",
                   workflow_agent_call_id: call.id
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T7 workflow_agent_call_id: nonexistent reference rejects with a typed error", %{company: company, task: task} do
      assert {:error, {:execution_reference_not_found, :workflow_agent_call_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t7",
                   workflow_agent_call_id: 999_999_999
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T8 workflow_agent_call_id: nil reference stays valid beside a verified one", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t8", workflow_run_id: run.id})
               end)

      assert is_nil(result.workflow_agent_call_id)
    end

    # ─── background_agent_job_id ─────────────────────────────────────────────

    test "B11-T9 background_agent_job_id: valid same-Company reference succeeds", %{company: company, task: task} do
      job = ExecutionReferenceFixtures.job_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t9",
                   background_agent_job_id: job.id
                 })
               end)

      assert result.background_agent_job_id == job.id
    end

    test "B11-T10 background_agent_job_id: cross-Company reference rejects and persists nothing", %{company: company, task: task} do
      job = ExecutionReferenceFixtures.job_fixture(other_company_agent().uid)

      assert {:error, {:execution_reference_wrong_company, :background_agent_job_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t10",
                   background_agent_job_id: job.id
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T11 background_agent_job_id: nonexistent reference rejects with a typed error", %{company: company, task: task} do
      assert {:error, {:execution_reference_not_found, :background_agent_job_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t11",
                   background_agent_job_id: 999_999_999
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T12 background_agent_job_id: nil reference stays valid beside a verified one", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t12", workflow_run_id: run.id})
               end)

      assert is_nil(result.background_agent_job_id)
    end

    # ─── background_agent_job_turn_id ────────────────────────────────────────

    test "B11-T13 background_agent_job_turn_id: valid same-Company reference succeeds", %{company: company, task: task} do
      turn = ExecutionReferenceFixtures.turn_fixture(ExecutionReferenceFixtures.job_fixture(same_company_agent(company).uid))

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t13",
                   background_agent_job_turn_id: turn.id
                 })
               end)

      assert result.background_agent_job_turn_id == turn.id
    end

    test "B11-T14 background_agent_job_turn_id: cross-Company reference rejects and persists nothing", %{company: company, task: task} do
      turn = ExecutionReferenceFixtures.turn_fixture(ExecutionReferenceFixtures.job_fixture(other_company_agent().uid))

      assert {:error, {:execution_reference_wrong_company, :background_agent_job_turn_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t14",
                   background_agent_job_turn_id: turn.id
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T15 background_agent_job_turn_id: nonexistent reference rejects with a typed error", %{company: company, task: task} do
      assert {:error, {:execution_reference_not_found, :background_agent_job_turn_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t15",
                   background_agent_job_turn_id: Ecto.UUID.generate()
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T16 background_agent_job_turn_id: nil reference stays valid beside a verified one", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t16", workflow_run_id: run.id})
               end)

      assert is_nil(result.background_agent_job_turn_id)
    end

    # ─── execution_attempt_ref ───────────────────────────────────────────────

    test "B11-T17 execution_attempt_ref alone rejects", %{company: company, task: task} do
      assert {:error, :execution_reference_required} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t17",
                   execution_attempt_ref: "attempt-001"
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T18 execution_attempt_ref alongside a valid real reference succeeds", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t18",
                   workflow_run_id: run.id,
                   execution_attempt_ref: "attempt-001"
                 })
               end)

      assert result.execution_attempt_ref == "attempt-001"
    end

    test "B11-T19 execution_attempt_ref cannot hide a cross-Company real reference", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(other_company_agent().uid)

      assert {:error, {:execution_reference_wrong_company, :workflow_run_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t19",
                   workflow_run_id: run.id,
                   execution_attempt_ref: "attempt-001"
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    # ─── pair consistency ────────────────────────────────────────────────────

    test "B11-T20 mismatched workflow_run_id and workflow_agent_call_id rejects", %{company: company, task: task} do
      agent = same_company_agent(company)
      cited_run = ExecutionReferenceFixtures.run_fixture(agent.uid)
      other_run = ExecutionReferenceFixtures.run_fixture(agent.uid)
      call = ExecutionReferenceFixtures.agent_call_fixture(other_run, agent.uid)

      assert {:error, :workflow_agent_call_run_mismatch} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t20",
                   workflow_run_id: cited_run.id,
                   workflow_agent_call_id: call.id
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T21 matched workflow pair succeeds", %{company: company, task: task} do
      agent = same_company_agent(company)
      run = ExecutionReferenceFixtures.run_fixture(agent.uid)
      call = ExecutionReferenceFixtures.agent_call_fixture(run, agent.uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t21",
                   workflow_run_id: run.id,
                   workflow_agent_call_id: call.id
                 })
               end)

      assert result.workflow_run_id == run.id
      assert result.workflow_agent_call_id == call.id
    end

    test "B11-T22 mismatched background_agent_job_id and turn rejects", %{company: company, task: task} do
      agent = same_company_agent(company)
      cited_job = ExecutionReferenceFixtures.job_fixture(agent.uid)
      other_turn = ExecutionReferenceFixtures.turn_fixture(ExecutionReferenceFixtures.job_fixture(agent.uid))

      assert {:error, :background_agent_job_turn_job_mismatch} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t22",
                   background_agent_job_id: cited_job.id,
                   background_agent_job_turn_id: other_turn.id
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T23 matched background-job pair succeeds", %{company: company, task: task} do
      job = ExecutionReferenceFixtures.job_fixture(same_company_agent(company).uid)
      turn = ExecutionReferenceFixtures.turn_fixture(job)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t23",
                   background_agent_job_id: job.id,
                   background_agent_job_turn_id: turn.id
                 })
               end)

      assert result.background_agent_job_id == job.id
      assert result.background_agent_job_turn_id == turn.id
    end

    # ─── every supplied reference is validated ──────────────────────────────

    test "B11-T24 a valid first reference does not excuse a cross-Company second one", %{company: company, task: task} do
      good_run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)
      foreign_job = ExecutionReferenceFixtures.job_fixture(other_company_agent().uid)

      assert {:error, {:execution_reference_wrong_company, :background_agent_job_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t24",
                   workflow_run_id: good_run.id,
                   background_agent_job_id: foreign_job.id
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T25 a valid first reference does not excuse a nonexistent second one", %{company: company, task: task} do
      good_run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:error, {:execution_reference_not_found, :background_agent_job_id}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t25",
                   workflow_run_id: good_run.id,
                   background_agent_job_id: 999_999_999
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    # ─── execution owner type ────────────────────────────────────────────────

    test "B11-T26 a Human-owned execution record is rejected", %{company: company, human: human, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(human.uid)

      assert {:error, {:invalid_execution_owner_type, :workflow_run_id, :human}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t26", workflow_run_id: run.id})
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T27 a System-owned execution record is rejected", %{company: company, task: task} do
      system = PrincipalsFixtures.system_fixture()
      run = ExecutionReferenceFixtures.run_fixture(system.uid)

      assert {:error, {:invalid_execution_owner_type, :workflow_run_id, :system}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{result_uid: "b11-t27", workflow_run_id: run.id})
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    # ─── identifier normalization ────────────────────────────────────────────

    test "B11-T28 a malformed identifier rejects instead of degrading to a missing reference", %{company: company, task: task} do
      assert {:error, {:invalid_execution_reference, "not-an-id"}} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t28",
                   workflow_run_id: "not-an-id"
                 })
               end)

      assert Repo.all(Ankole.WorkHierarchy.TaskResult) == []
    end

    test "B11-T29 a string integer identifier normalizes to the cited run", %{company: company, task: task} do
      run = ExecutionReferenceFixtures.run_fixture(same_company_agent(company).uid)

      assert {:ok, result} =
               transact(fn repo ->
                 ResultStore.create_result(repo, company.uid, task.uid, %{
                   result_uid: "b11-t29",
                   workflow_run_id: Integer.to_string(run.id)
                 })
               end)

      assert result.workflow_run_id == run.id
    end
  end
end

