defmodule Ankole.WorkHierarchy.TaskLifecycleEventTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.TaskLifecycleEvent

  @moduledoc """
  Tests for Ankole.WorkHierarchy.TaskLifecycleEvent schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        task_uid: "task-001",
        to_status: "ASSIGNED",
        changed_by_uid: "principal-001",
        metadata: %{"reason" => "assigned"}
      })

      assert changeset.valid?
    end

    test "task_uid is required" do
      changeset = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        to_status: "ASSIGNED",
        changed_by_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn {:task_uid, _} -> true; _ -> false end)
    end

    test "to_status is required" do
      changeset = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        task_uid: "task-001",
        changed_by_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn {:to_status, _} -> true; _ -> false end)
    end

    test "changed_by_uid is required" do
      changeset = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        task_uid: "task-001",
        to_status: "ASSIGNED"
      })

      assert Enum.any?(changeset.errors, fn {:changed_by_uid, _} -> true; _ -> false end)
    end

    test "from_status is optional" do
      changeset = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        task_uid: "task-001",
        to_status: "ASSIGNED",
        changed_by_uid: "principal-001"
      })

      assert changeset.valid?
      assert get_change(changeset, :from_status) == nil
    end

    test "metadata is optional" do
      changeset = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        task_uid: "task-001",
        to_status: "ASSIGNED",
        changed_by_uid: "principal-001"
      })

      assert changeset.valid?
      assert get_change(changeset, :metadata) == nil
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = TaskLifecycleEvent.__schema__(:fields)
      assert :id in fields
      assert :task_uid in fields
      assert :from_status in fields
      assert :to_status in fields
      assert :changed_by_uid in fields
      assert :metadata in fields
      assert :inserted_at in fields
    end

    test "primary key is id" do
      assert TaskLifecycleEvent.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "task belongs_to targets Task" do
      assoc = TaskLifecycleEvent.__schema__(:association, :task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == TaskLifecycleEvent
      assert assoc.owner_key == :task_uid
    end

    test "changed_by belongs_to targets Principal" do
      assoc = TaskLifecycleEvent.__schema__(:association, :changed_by)
      assert assoc.related == Ankole.Principals.Principal
      assert assoc.owner == TaskLifecycleEvent
      assert assoc.owner_key == :changed_by_uid
    end
  end

  describe "constraint wiring" do
    test "FK constraints are wired" do
      constraints = TaskLifecycleEvent.changeset(%TaskLifecycleEvent{}, %{
        task_uid: "t1", to_status: "ASSIGNED", changed_by_uid: "c1"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :task_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :changed_by_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "task_uid is stored as :string" do
      assert TaskLifecycleEvent.__schema__(:type, :task_uid) == :string
    end

    test "from_status is stored as :string" do
      assert TaskLifecycleEvent.__schema__(:type, :from_status) == :string
    end

    test "to_status is stored as :string" do
      assert TaskLifecycleEvent.__schema__(:type, :to_status) == :string
    end

    test "changed_by_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert TaskLifecycleEvent.__schema__(:type, :changed_by_uid) == Ankole.Ecto.PrincipalKey
    end

    test "metadata is stored as :map" do
      assert TaskLifecycleEvent.__schema__(:type, :metadata) == :map
    end
  end
end
