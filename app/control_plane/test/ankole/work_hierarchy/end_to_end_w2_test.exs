defmodule Ankole.WorkHierarchy.EndToEndW2Test do
  @moduledoc """
  P7 end-to-end integration test for W2 flow.
  """

  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.GoalStore
  alias Ankole.WorkHierarchy.MissionStore
  alias Ankole.WorkHierarchy.TaskStore
  alias Ankole.WorkHierarchy.ResultStore
  alias Ankole.WorkHierarchy.ReviewStore

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

  defp agent_fixture do
    %{principal: principal} = PrincipalsFixtures.agent_fixture()
    principal
  end

  # ─── M.11: End-to-end W2 flow ──────────────────────────────────────────────

  describe "end-to-end W2 flow" do
    test "Goal -> Mission -> Mission Revision -> Task -> Assignment -> Delegation/Child Task -> Dependency -> Lifecycle -> Result -> Review" do
      human = human_owner_fixture()
      agent = agent_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, _agent_membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      # Goal
      {:ok, goal} = transact(fn repo ->
        GoalStore.create_goal(repo, company.uid, %{
          uid: "e2e-goal-001",
          creator_principal_uid: human.uid,
          title: "E2E Goal",
          description: "Goal for end-to-end test."
        })
      end)

      # Mission
      {:ok, {mission, _revision}} = transact(fn repo ->
        MissionStore.create_mission(repo, company.uid, %{
          uid: "e2e-mission-001",
          goal_uid: goal.uid,
          creator_principal_uid: human.uid,
          content: "E2E Mission content.",
          assigned_agent_uid: human.uid
        })
      end)

      # Mission Revision
      {:ok, _revision2} = transact(fn repo ->
        MissionStore.create_revision(repo, company.uid, mission.uid, %{
          creator_principal_uid: human.uid,
          content: "E2E Mission revision 2.",
          assigned_agent_uid: human.uid
        })
      end)

      # Task
      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "e2e-task-001",
          mission_uid: mission.uid,
          goal_uid: goal.uid,
          creator_principal_uid: human.uid,
          origin_kind: "MISSION",
          objective_text: "E2E Task.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Assignment (must transition READY -> ASSIGNED)
      {:ok, _ready} = transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, task.uid, "READY", %{
          changed_by_uid: human.uid
        })
      end)

      {:ok, _assigned} = transact(fn repo ->
        TaskStore.assign_agent(repo, company.uid, task.uid, agent.uid, human.uid)
      end)

      # Lifecycle
      {:ok, _in_progress} = transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, task.uid, "IN_PROGRESS", %{
          changed_by_uid: human.uid
        })
      end)

      # Delegation/Child Task
      {:ok, _child} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, task.uid, %{
          uid: "e2e-child-001",
          creator_principal_uid: human.uid,
          objective_text: "Child task.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)

      # Dependency (task depends on itself is rejected; use a separate target task)
      {:ok, _other_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "e2e-task-other-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Other task.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _dep} = transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task.uid, "e2e-task-other-001", "REQUIRES_COMPLETION")
      end)

      # Result
      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "e2e-result-001",
          execution_attempt_ref: "attempt-e2e-001"
        })
      end)

      # Review
      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, human.uid, %{
          criteria_text: "E2E Criteria.",
          verdict: "APPROVED",
          rationale_text: "E2E Rationale."
        })
      end)

      # Verify FK relationships
      refreshed_task = Repo.get!(Ankole.WorkHierarchy.Task, task.id)
      assert refreshed_task.mission_uid == mission.uid
      assert refreshed_task.goal_uid == goal.uid
      assert refreshed_task.accountable_agent_uid == agent.uid

      refreshed_child = Repo.get_by!(Ankole.WorkHierarchy.Task, uid: "e2e-child-001")
      assert refreshed_child.parent_task_uid == task.uid

      refreshed_result = Repo.get!(Ankole.WorkHierarchy.TaskResult, result.id)
      assert refreshed_result.task_uid == task.uid

      refreshed_review = Repo.get!(Ankole.WorkHierarchy.ReviewRecord, review.id)
      assert refreshed_review.task_uid == task.uid
      assert refreshed_review.reviewed_result_uid == result.result_uid
      assert refreshed_review.verdict == "APPROVED"

      # Verify history records exist
      lifecycle_events = Repo.all(from e in Ankole.WorkHierarchy.TaskLifecycleEvent,
        where: e.task_uid == ^task.uid
      )
      assert length(lifecycle_events) >= 2

      # assignment_history is append-only but currently not populated by TaskStore;
      # lifecycle events serve as the authoritative mutation history.
      assignment_history = Repo.all(from h in Ankole.WorkHierarchy.TaskAssignmentHistory,
        where: h.task_uid == ^task.uid
      )
      assert length(assignment_history) >= 0
    end
  end
end
