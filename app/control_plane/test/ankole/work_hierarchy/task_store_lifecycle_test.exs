defmodule Ankole.WorkHierarchy.TaskStoreLifecycleTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.TaskStore
  alias Ankole.WorkHierarchy.TaskLifecycleEvent

  @moduledoc """
  Tests for P4 Task lifecycle transitions and history.
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

  describe "transition_task valid transitions" do
    test "PROPOSED -> READY" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      assert task.status == "PROPOSED"

      {:ok, updated_task} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{
        changed_by_uid: human.uid
      })

      assert updated_task.status == "READY"
    end

    test "ASSIGNED -> IN_PROGRESS" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, _membership_owner} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-002",
          creator_principal_uid: agent.uid,
          origin_kind: "MISSION",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria.",
          accountable_agent_uid: agent.uid
        })
      end)

      # Transition through states: PROPOSED -> READY -> ASSIGNED
      {:ok, _ready_task} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: agent.uid})
      {:ok, _assigned_task} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, agent.uid)

      # Now transition to IN_PROGRESS
      {:ok, updated_task} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{
        changed_by_uid: agent.uid
      })

      assert updated_task.status == "IN_PROGRESS"
    end

    test "IN_PROGRESS -> COMPLETED" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-003",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Use agent for assignment since humans cannot be ACCOUNTABLE AGENT
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      # Transition through states: PROPOSED -> READY -> ASSIGNED -> IN_PROGRESS
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})

      {:ok, completed_task} = TaskStore.transition_task(Repo, company.uid, task.uid, "COMPLETED", %{
        changed_by_uid: human.uid
      })

      assert completed_task.status == "COMPLETED"
    end

    test "IN_PROGRESS -> FAILED with failure_reason" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-004",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Use agent for assignment
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      # Transition to IN_PROGRESS first
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})

      {:ok, failed_task} = TaskStore.fail_task(Repo, company.uid, task.uid, human.uid, "Something went wrong.")

      assert failed_task.status == "FAILED"
      assert failed_task.failure_reason == "Something went wrong."
    end

    test "any non-terminal -> CANCELLED" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-005",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      {:ok, cancelled_task} = TaskStore.cancel_task(Repo, company.uid, task.uid, human.uid, "No longer needed.")

      assert cancelled_task.status == "CANCELLED"
      assert cancelled_task.cancellation_reason == "No longer needed."
      assert cancelled_task.cancelled_at != nil
      assert cancelled_task.cancelled_by_uid == human.uid
    end
  end

  describe "transition_task invalid transitions" do
    test "terminal state cannot transition" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-fail-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Complete the task via proper transitions
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "COMPLETED", %{changed_by_uid: human.uid})

      # Cannot transition from terminal
      assert {:error, {:terminal_state, "COMPLETED"}} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})
    end

    test "invalid transition rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-fail-002",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # PROPOSED cannot go directly to COMPLETED
      assert {:error, {:invalid_transition, from: "PROPOSED", to: "COMPLETED"}} =
        TaskStore.transition_task(Repo, company.uid, task.uid, "COMPLETED", %{changed_by_uid: human.uid})
    end

    test "missing cancellation fields rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-fail-003",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Cannot cancel without required fields
      assert {:error, :cancellation_fields_missing} =
        TaskStore.transition_task(Repo, company.uid, task.uid, "CANCELLED", %{changed_by_uid: human.uid})
    end

    test "missing failure_reason rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-lifecycle-fail-004",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Transition to IN_PROGRESS first using agent
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})

      # Cannot fail without failure_reason
      assert {:error, :failure_reason_required} =
        TaskStore.transition_task(Repo, company.uid, task.uid, "FAILED", %{changed_by_uid: human.uid})
    end
  end

  describe "assign_agent" do
    test "valid agent assignment transitions READY -> ASSIGNED" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, _membership_owner} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-assign-001",
          creator_principal_uid: owner.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # First transition: PROPOSED -> READY
      {:ok, _ready_task} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: owner.uid})
      
      # Then assign agent (transitions READY -> ASSIGNED)
      {:ok, assigned_task} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, owner.uid)

      assert assigned_task.status == "ASSIGNED"
      assert assigned_task.accountable_agent_uid == agent.uid
    end

    test "agent not in company rejected" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      # Add owner as member so they can create tasks
      {:ok, _membership_owner} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      # Agent has no membership

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-assign-002",
          creator_principal_uid: owner.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # First need to get to READY
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: owner.uid})

      assert {:error, :agent_not_in_company} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, owner.uid)
    end
  end

  describe "lifecycle history events" do
    test "each transition creates exactly one lifecycle event" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-history-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # No lifecycle event created by P3 task creation
      events_before = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      assert events_before == []

      # Create first transition: PROPOSED -> READY
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      events_after_ready = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      assert length(events_after_ready) == 1
      assert hd(events_after_ready).from_status == "PROPOSED"
      assert hd(events_after_ready).to_status == "READY"
      assert hd(events_after_ready).changed_by_uid == human.uid

      # Second transition: READY -> ASSIGNED (using agent)
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      
      events_after_assigned = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      assert length(events_after_assigned) == 2
      assert Enum.at(events_after_assigned, 1).from_status == "READY"
      assert Enum.at(events_after_assigned, 1).to_status == "ASSIGNED"
    end

    test "WAITING transition captures waiting_reason in metadata" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-waiting-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Use agent for assignment
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})

      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "WAITING", %{
        changed_by_uid: human.uid,
        metadata: %{"waiting_reason" => "Blocked on external dependency"}
      })

      events = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      waiting_event = Enum.find(events, fn e -> e.to_status == "WAITING" end)
      assert waiting_event != nil
      assert waiting_event.metadata["waiting_reason"] == "Blocked on external dependency"
    end

    test "FAILED transition stores failure_reason" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-failed-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      # Use agent for assignment
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      {:ok, _membership_agent} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      # Transition through proper lifecycle
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = TaskStore.transition_task(Repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})

      {:ok, failed_task} = TaskStore.fail_task(Repo, company.uid, task.uid, human.uid, "Something went wrong.")

      assert failed_task.status == "FAILED"
      assert failed_task.failure_reason == "Something went wrong."

      events = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      failed_event = Enum.find(events, fn e -> e.to_status == "FAILED" end)
      assert failed_event != nil
      assert failed_event.metadata["failure_reason"] == "Something went wrong."
    end
  end

  describe "P3 behavior preserved" do
    test "Task creation does not create lifecycle event" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-preserve-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      assert task.status == "PROPOSED"
      assert task.uid == "task-preserve-001"

      # No lifecycle event should exist
      events = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      assert events == []
    end
  end

  # ─── B-14: lifecycle transition actor validation ───────────────────────────

  describe "transition_task — B14 changed_by_uid validation" do
    setup do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-b14-#{System.unique_integer([:positive])}",
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

    defp active_same_company_agent(company) do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      agent
    end

    defp disabled_same_company_agent(company) do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      assert {:ok, _principal} =
               agent
               |> Ankole.Principals.Principal.changeset(%{status: :disabled})
               |> Repo.update()

      agent
    end

    defp other_company_agent do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      agent
    end

    defp do_transition(repo, company_uid, task_uid, to_status, changed_by_uid) do
      TaskStore.transition_task(repo, company_uid, task_uid, to_status, %{
        changed_by_uid: changed_by_uid
      })
    end

    # ─── B14-T1 ───

    test "B14-T1 active same-Company changer allows lifecycle transition", %{company: company, task: task, human: human} do
      assert {:ok, updated} = do_transition(Repo, company.uid, task.uid, "READY", human.uid)
      assert updated.status == "READY"
    end

    # ─── B14-T2 ───

    test "B14-T2 nonexistent changer rejects transition", %{company: company, task: task} do
      assert {:error, :changer_not_found} =
               do_transition(Repo, company.uid, task.uid, "READY", "human-nonexistent-b14")
    end

    # ─── B14-T3 ───

    test "B14-T3 disabled changer rejects transition", %{company: company, task: task} do
      agent = disabled_same_company_agent(company)

      assert {:error, {:creator_not_active, :disabled}} =
               do_transition(Repo, company.uid, task.uid, "READY", agent.uid)
    end

    # ─── B14-T4 ───

    test "B14-T4 cross-Company changer rejects transition", %{company: company, task: task} do
      agent = other_company_agent()

      assert {:error, :creator_not_member} =
               do_transition(Repo, company.uid, task.uid, "READY", agent.uid)
    end

    # ─── B14-T5 ───

    test "B14-T5 malformed changer UID rejects transition", %{company: company, task: task} do
      assert {:error, :invalid_uid} =
               do_transition(Repo, company.uid, task.uid, "READY", "  ")
    end

    # ─── B14-T6 ───

    test "B14-T6 rejected actor validation leaves Task state/version unchanged", %{company: company, task: task} do
      agent = disabled_same_company_agent(company)

      before_task = Repo.get!(Ankole.WorkHierarchy.Task, task.id)
      assert before_task.status == "PROPOSED"
      before_version = before_task.version

      assert {:error, {:creator_not_active, :disabled}} =
               do_transition(Repo, company.uid, task.uid, "READY", agent.uid)

      after_task = Repo.get!(Ankole.WorkHierarchy.Task, task.id)
      assert after_task.status == "PROPOSED"
      assert after_task.version == before_version
    end

    # ─── B14-T7 ───

    test "B14-T7 rejected actor validation creates no lifecycle event", %{company: company, task: task} do
      agent = disabled_same_company_agent(company)

      before_events = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      assert before_events == []

      assert {:error, {:creator_not_active, :disabled}} =
               do_transition(Repo, company.uid, task.uid, "READY", agent.uid)

      after_events = Repo.all(from e in TaskLifecycleEvent, where: e.task_uid == ^task.uid)
      assert after_events == []
    end

    # ─── B14-T8 ───

    test "B14-T8 existing valid lifecycle transitions remain green", %{company: company, task: task, human: human} do
      # Full lifecycle: PROPOSED -> READY -> ASSIGNED -> IN_PROGRESS -> COMPLETED
      agent = active_same_company_agent(company)

      {:ok, _} = do_transition(Repo, company.uid, task.uid, "READY", human.uid)
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = do_transition(Repo, company.uid, task.uid, "IN_PROGRESS", human.uid)
      {:ok, completed} = do_transition(Repo, company.uid, task.uid, "COMPLETED", human.uid)

      assert completed.status == "COMPLETED"
    end

    # ─── B14-T9 ───

    test "B14-T9 terminal transition behavior remains unchanged", %{company: company, human: human, task: task} do
      agent = active_same_company_agent(company)

      {:ok, _} = do_transition(Repo, company.uid, task.uid, "READY", human.uid)
      {:ok, _} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      {:ok, _} = do_transition(Repo, company.uid, task.uid, "IN_PROGRESS", human.uid)
      {:ok, _} = do_transition(Repo, company.uid, task.uid, "COMPLETED", human.uid)

      # Terminal state cannot transition
      assert {:error, {:terminal_state, "COMPLETED"}} =
               do_transition(Repo, company.uid, task.uid, "IN_PROGRESS", human.uid)

      # Task remains COMPLETED
      task_after = Repo.get!(Ankole.WorkHierarchy.Task, task.id)
      assert task_after.status == "COMPLETED"
    end

    # ─── B14-T10 ───

    test "B14-T10 cancellation-specific changer requirement preserved", %{company: company, task: task, human: human} do
      # cancel_task requires changed_by_uid (guard enforces it)
      assert {:error, :cancelled_by_uid_required} =
               TaskStore.cancel_task(Repo, company.uid, task.uid, nil, "reason")

      # fail_task requires failure_reason but also uses changed_by_uid
      {:ok, task2} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-b14-#{System.unique_integer([:positive])}",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :failure_reason_required} =
               TaskStore.fail_task(Repo, company.uid, task2.uid, human.uid, nil)
    end
  end
end
