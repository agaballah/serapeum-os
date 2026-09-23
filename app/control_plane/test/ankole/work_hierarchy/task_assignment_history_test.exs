defmodule Ankole.WorkHierarchy.TaskAssignmentHistoryTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Principals
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.TaskAssignmentHistory
  alias Ankole.WorkHierarchy.TaskStore

  @moduledoc """
  Tests for Ankole.WorkHierarchy.TaskAssignmentHistory schema and changeset.
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

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        task_uid: "task-001",
        new_agent_uid: "agent-001",
        changed_by_uid: "human-001",
        reason: "Initial assignment."
      })

      assert changeset.valid?
    end

    test "task_uid is required" do
      changeset = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        new_agent_uid: "agent-001",
        changed_by_uid: "human-001"
      })

      assert Enum.any?(changeset.errors, fn {:task_uid, _} -> true; _ -> false end)
    end

    test "new_agent_uid is required" do
      changeset = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        task_uid: "task-001",
        changed_by_uid: "human-001"
      })

      assert Enum.any?(changeset.errors, fn {:new_agent_uid, _} -> true; _ -> false end)
    end

    test "changed_by_uid is required" do
      changeset = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        task_uid: "task-001",
        new_agent_uid: "agent-001"
      })

      assert Enum.any?(changeset.errors, fn {:changed_by_uid, _} -> true; _ -> false end)
    end

    test "previous_agent_uid is optional" do
      changeset = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        task_uid: "task-001",
        new_agent_uid: "agent-001",
        changed_by_uid: "human-001"
      })

      assert changeset.valid?
      assert get_change(changeset, :previous_agent_uid) == nil
    end

    test "reason is optional" do
      changeset = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        task_uid: "task-001",
        new_agent_uid: "agent-001",
        changed_by_uid: "human-001"
      })

      assert changeset.valid?
      assert get_change(changeset, :reason) == nil
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = TaskAssignmentHistory.__schema__(:fields)
      assert :id in fields
      assert :task_uid in fields
      assert :previous_agent_uid in fields
      assert :new_agent_uid in fields
      assert :changed_by_uid in fields
      assert :reason in fields
      assert :inserted_at in fields
    end

    test "primary key is id" do
      assert TaskAssignmentHistory.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "task belongs_to targets Task" do
      assoc = TaskAssignmentHistory.__schema__(:association, :task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == TaskAssignmentHistory
      assert assoc.owner_key == :task_uid
    end

    test "changed_by belongs_to targets Principal" do
      assoc = TaskAssignmentHistory.__schema__(:association, :changed_by)
      assert assoc.related == Ankole.Principals.Principal
      assert assoc.owner == TaskAssignmentHistory
      assert assoc.owner_key == :changed_by_uid
    end
  end

  describe "constraint wiring" do
    test "FK constraints are wired" do
      constraints = TaskAssignmentHistory.changeset(%TaskAssignmentHistory{}, %{
        task_uid: "t1", new_agent_uid: "a1", changed_by_uid: "c1"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :task_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :new_agent_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :changed_by_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :previous_agent_uid and c.type == :foreign_key end)
    end
  end

  describe "FK behavior" do
    test "deleting referenced Principal sets new_agent_uid to NULL without error" do
      # This test verifies that the ON DELETE SET NULL constraint on new_agent_uid
      # allows Principal deletion even when referenced by assignment history.
      # The historical record is preserved with new_agent_uid = NULL.

      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      # Add owner as member so they can create tasks
      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-fk-001",
          creator_principal_uid: owner.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Create agent and add to company
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      # Insert assignment history with valid agent as new_agent_uid
      {:ok, history} = %TaskAssignmentHistory{}
        |> TaskAssignmentHistory.changeset(%{
          task_uid: task.uid,
          new_agent_uid: agent.uid,
          changed_by_uid: owner.uid
        })
        |> Repo.insert()

      assert history.new_agent_uid == agent.uid

      # Delete the Agent Principal - should NOT fail due to FK constraint
      deleted_principal = Repo.get(Ankole.Principals.Principal, agent.uid)
      refute is_nil(deleted_principal)
      {:ok, _} = Repo.delete(deleted_principal)

      # History row still exists but new_agent_uid is now NULL
      refreshed = Repo.get(TaskAssignmentHistory, history.id)
      assert refreshed != nil
      assert refreshed.new_agent_uid == nil
      assert refreshed.task_uid == task.uid
      assert refreshed.changed_by_uid == owner.uid
    end
  end

  describe "field types" do
    test "task_uid is stored as :string" do
      assert TaskAssignmentHistory.__schema__(:type, :task_uid) == :string
    end

    test "previous_agent_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert TaskAssignmentHistory.__schema__(:type, :previous_agent_uid) == Ankole.Ecto.PrincipalKey
    end

    test "new_agent_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert TaskAssignmentHistory.__schema__(:type, :new_agent_uid) == Ankole.Ecto.PrincipalKey
    end

    test "changed_by_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert TaskAssignmentHistory.__schema__(:type, :changed_by_uid) == Ankole.Ecto.PrincipalKey
    end
  end
end
