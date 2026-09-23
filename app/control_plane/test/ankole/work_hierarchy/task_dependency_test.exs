defmodule Ankole.WorkHierarchy.TaskDependencyTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.TaskDependency

  @moduledoc """
  Tests for Ankole.WorkHierarchy.TaskDependency schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset with default dependency_type" do
      changeset = TaskDependency.changeset(%TaskDependency{}, %{
        task_uid: "task-001",
        depends_on_task_uid: "task-002"
      })

      assert changeset.valid?
      assert get_change(changeset, :dependency_type) == nil
    end

    test "valid attrs with explicit dependency_type" do
      Enum.each(~w(REQUIRES_COMPLETION REQUIRES_RESULT OPTIONAL)a, fn type ->
        changeset = TaskDependency.changeset(%TaskDependency{}, %{
          task_uid: "task-001",
          depends_on_task_uid: "task-002",
          dependency_type: Atom.to_string(type)
        })

        assert changeset.valid?, "expected valid for dependency_type=#{type}"
        assert get_field(changeset, :dependency_type) == Atom.to_string(type)
      end)
    end

    test "rejects invalid dependency_type" do
      changeset = TaskDependency.changeset(%TaskDependency{}, %{
        task_uid: "task-001",
        depends_on_task_uid: "task-002",
        dependency_type: "INVALID_TYPE"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:dependency_type, _} -> true; _ -> false end)
    end

    test "task_uid is required" do
      changeset = TaskDependency.changeset(%TaskDependency{}, %{
        depends_on_task_uid: "task-002"
      })

      assert Enum.any?(changeset.errors, fn {:task_uid, _} -> true; _ -> false end)
    end

    test "depends_on_task_uid is required" do
      changeset = TaskDependency.changeset(%TaskDependency{}, %{
        task_uid: "task-001"
      })

      assert Enum.any?(changeset.errors, fn {:depends_on_task_uid, _} -> true; _ -> false end)
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = TaskDependency.__schema__(:fields)
      assert :id in fields
      assert :task_uid in fields
      assert :depends_on_task_uid in fields
      assert :dependency_type in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "primary key is id" do
      assert TaskDependency.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "task belongs_to targets Task" do
      assoc = TaskDependency.__schema__(:association, :task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == TaskDependency
      assert assoc.owner_key == :task_uid
    end

    test "depends_on belongs_to targets Task" do
      assoc = TaskDependency.__schema__(:association, :depends_on)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == TaskDependency
      assert assoc.owner_key == :depends_on_task_uid
    end
  end

  describe "constraint wiring" do
    test "FK constraints are wired" do
      constraints = TaskDependency.changeset(%TaskDependency{}, %{
        task_uid: "t1", depends_on_task_uid: "t2"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :task_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :depends_on_task_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "task_uid is stored as :string" do
      assert TaskDependency.__schema__(:type, :task_uid) == :string
    end

    test "depends_on_task_uid is stored as :string" do
      assert TaskDependency.__schema__(:type, :depends_on_task_uid) == :string
    end

    test "dependency_type is stored as :string" do
      assert TaskDependency.__schema__(:type, :dependency_type) == :string
    end
  end
end
