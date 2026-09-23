defmodule Ankole.WorkHierarchy.TaskChildPolicyHistoryTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.TaskChildPolicyHistory

  @moduledoc """
  Tests for Ankole.WorkHierarchy.TaskChildPolicyHistory schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = TaskChildPolicyHistory.changeset(%TaskChildPolicyHistory{}, %{
        task_uid: "task-001",
        old_policy: "ALL_COMPLETED",
        new_policy: "INDEPENDENT",
        changed_by_uid: "human-001"
      })

      assert changeset.valid?
    end

    test "task_uid is required" do
      changeset = TaskChildPolicyHistory.changeset(%TaskChildPolicyHistory{}, %{
        old_policy: "ALL_COMPLETED",
        new_policy: "INDEPENDENT",
        changed_by_uid: "human-001"
      })

      assert Enum.any?(changeset.errors, fn {:task_uid, _} -> true; _ -> false end)
    end

    test "old_policy is required" do
      changeset = TaskChildPolicyHistory.changeset(%TaskChildPolicyHistory{}, %{
        task_uid: "task-001",
        new_policy: "INDEPENDENT",
        changed_by_uid: "human-001"
      })

      assert Enum.any?(changeset.errors, fn {:old_policy, _} -> true; _ -> false end)
    end

    test "new_policy is required" do
      changeset = TaskChildPolicyHistory.changeset(%TaskChildPolicyHistory{}, %{
        task_uid: "task-001",
        old_policy: "ALL_COMPLETED",
        changed_by_uid: "human-001"
      })

      assert Enum.any?(changeset.errors, fn {:new_policy, _} -> true; _ -> false end)
    end

    test "changed_by_uid is required" do
      changeset = TaskChildPolicyHistory.changeset(%TaskChildPolicyHistory{}, %{
        task_uid: "task-001",
        old_policy: "ALL_COMPLETED",
        new_policy: "INDEPENDENT"
      })

      assert Enum.any?(changeset.errors, fn {:changed_by_uid, _} -> true; _ -> false end)
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = TaskChildPolicyHistory.__schema__(:fields)
      assert :id in fields
      assert :task_uid in fields
      assert :old_policy in fields
      assert :new_policy in fields
      assert :changed_by_uid in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "primary key is id" do
      assert TaskChildPolicyHistory.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "task belongs_to targets Task" do
      assoc = TaskChildPolicyHistory.__schema__(:association, :task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == TaskChildPolicyHistory
      assert assoc.owner_key == :task_uid
    end

    test "changed_by belongs_to targets Principal" do
      assoc = TaskChildPolicyHistory.__schema__(:association, :changed_by)
      assert assoc.related == Ankole.Principals.Principal
      assert assoc.owner == TaskChildPolicyHistory
      assert assoc.owner_key == :changed_by_uid
    end
  end

  describe "constraint wiring" do
    test "FK constraints are wired" do
      constraints = TaskChildPolicyHistory.changeset(%TaskChildPolicyHistory{}, %{
        task_uid: "t1", old_policy: "ALL_COMPLETED",
        new_policy: "INDEPENDENT", changed_by_uid: "c1"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :task_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :changed_by_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "task_uid is stored as :string" do
      assert TaskChildPolicyHistory.__schema__(:type, :task_uid) == :string
    end

    test "old_policy is stored as :string" do
      assert TaskChildPolicyHistory.__schema__(:type, :old_policy) == :string
    end

    test "new_policy is stored as :string" do
      assert TaskChildPolicyHistory.__schema__(:type, :new_policy) == :string
    end

    test "changed_by_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert TaskChildPolicyHistory.__schema__(:type, :changed_by_uid) == Ankole.Ecto.PrincipalKey
    end
  end
end
