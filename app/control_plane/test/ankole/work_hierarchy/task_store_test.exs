defmodule Ankole.WorkHierarchy.TaskStoreTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.GoalStore
  alias Ankole.WorkHierarchy.MissionStore
  alias Ankole.WorkHierarchy.TaskStore

  @moduledoc """
  Tests for Ankole.WorkHierarchy.TaskStore public API.
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

  describe "create_task" do
    test "valid Human member creates Task in PROPOSED state" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-human-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build the widget.",
          scope_text: "Q3 2026.",
          required_outcome_text: "Shipped widget.",
          acceptance_criteria_text: "Passes QA."
        })
      end)

      assert task.uid == "task-human-001"
      assert task.company_uid == company.uid
      assert task.status == "PROPOSED"
      assert task.origin_kind == "OWNER_REQUEST"
    end

    test "nonexistent Company is rejected" do
      human = human_owner_fixture()
      assert {:error, :company_not_found} = transact(fn repo ->
        TaskStore.create_task(repo, "nonexistent-company", %{
          uid: "task-fail-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)
    end

    test "nonexistent creator is rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)
      assert {:error, :not_found} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-fail-002",
          creator_principal_uid: "nonexistent-principal",
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)
    end

    test "disabled Human creator is rejected" do
      human = human_owner_fixture()
      disabled = Principal.changeset(human, %{status: :disabled}) |> Repo.update() |> elem(1)
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, {:creator_not_active, :disabled}} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-fail-003",
          creator_principal_uid: disabled.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)
    end

    test "Human non-member is rejected" do
      human = human_owner_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :creator_not_member} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-fail-004",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)
    end

    test "duplicate uid is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:ok, _task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-dup-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, _} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-dup-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj 2.",
          scope_text: "Scope 2.",
          required_outcome_text: "Out 2.",
          acceptance_criteria_text: "Crit 2."
        })
      end)
    end

    test "nil creator UID is normalized to nil and rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)
      assert {:error, :invalid_uid} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-fail-005",
          creator_principal_uid: nil,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)
    end
  end

  describe "fetch_task" do
    test "hit returns Task" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-fetch-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      fetched = TaskStore.fetch_task(Repo, company.uid, task.uid)
      assert fetched.uid == task.uid
      assert fetched.status == "PROPOSED"
    end

    test "miss returns nil" do
      assert TaskStore.fetch_task(Repo, "nonexistent-company", "nonexistent-task") == nil
    end
  end

  describe "list_company_tasks" do
    test "returns only tasks for the Company" do
      human = human_owner_fixture()
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_a.uid, human.uid)
      end)

      {:ok, _membership_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_b.uid, human.uid)
      end)

      transact(fn repo ->
        TaskStore.create_task(repo, company_a.uid, %{
          uid: "task-comp-a-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj A.",
          scope_text: "Scope A.",
          required_outcome_text: "Out A.",
          acceptance_criteria_text: "Crit A."
        })
      end)

      transact(fn repo ->
        TaskStore.create_task(repo, company_b.uid, %{
          uid: "task-comp-b-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj B.",
          scope_text: "Scope B.",
          required_outcome_text: "Out B.",
          acceptance_criteria_text: "Crit B."
        })
      end)

      tasks_a = TaskStore.list_company_tasks(Repo, company_a.uid)
      assert length(tasks_a) == 1
      assert hd(tasks_a).uid == "task-comp-a-001"

      tasks_b = TaskStore.list_company_tasks(Repo, company_b.uid)
      assert length(tasks_b) == 1
      assert hd(tasks_b).uid == "task-comp-b-001"
    end
  end

  describe "validate_assignment_eligibility" do
    test "valid Agent in same Company returns :ok" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      # Add owner as member so they can create the task
      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      # Create task with human creator
      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-assign-001",
          creator_principal_uid: owner.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Add agent to company
      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      assert :ok = TaskStore.validate_assignment_eligibility(Repo, task.uid, agent.uid, company.uid)
    end

    test "Agent not in Company is rejected" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      # Add owner as member so they can create the task
      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      # Create task with human creator (agent not a member)
      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-assign-002",
          creator_principal_uid: owner.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Agent has no membership
      assert {:error, :agent_not_in_company} = TaskStore.validate_assignment_eligibility(Repo, task.uid, agent.uid, company.uid)
    end

    test "nonexistent Agent is rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      # Add owner as member so they can create the task
      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-assign-003",
          creator_principal_uid: owner.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :agent_not_found} = TaskStore.validate_assignment_eligibility(Repo, task.uid, "nonexistent-agent", company.uid)
    end
  end
end
