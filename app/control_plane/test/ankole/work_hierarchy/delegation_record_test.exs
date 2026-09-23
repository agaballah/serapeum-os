defmodule Ankole.WorkHierarchy.DelegationRecordTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.DelegationRecord

  @moduledoc """
  Tests for Ankole.WorkHierarchy.DelegationRecord schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "del-001",
        scope_description: "Delegate work to agent.",
        delegator_principal_uid: "human-001",
        source_task_uid: "task-001"
      })

      assert changeset.valid?
    end

    test "delegation_uid is required" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        scope_description: "Delegate work.",
        delegator_principal_uid: "human-001",
        source_task_uid: "task-001"
      })

      assert Enum.any?(changeset.errors, fn {:delegation_uid, _} -> true; _ -> false end)
    end

    test "scope_description is required" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "del-001",
        delegator_principal_uid: "human-001",
        source_task_uid: "task-001"
      })

      assert Enum.any?(changeset.errors, fn {:scope_description, _} -> true; _ -> false end)
    end

    test "blank scope_description is rejected" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "del-001",
        scope_description: "   ",
        delegator_principal_uid: "human-001",
        source_task_uid: "task-001"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:scope_description, _} -> true; _ -> false end)
    end

    test "delegator_principal_uid is required" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "del-001",
        scope_description: "Delegate work.",
        source_task_uid: "task-001"
      })

      assert Enum.any?(changeset.errors, fn {:delegator_principal_uid, _} -> true; _ -> false end)
    end

    test "source_task_uid is required" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "del-001",
        scope_description: "Delegate work.",
        delegator_principal_uid: "human-001"
      })

      assert Enum.any?(changeset.errors, fn {:source_task_uid, _} -> true; _ -> false end)
    end

    test "optional fields may be nil" do
      changeset = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "del-001",
        scope_description: "Delegate work.",
        delegator_principal_uid: "human-001",
        source_task_uid: "task-001",
        delegatee_principal_uid: nil,
        resulting_child_task_uid: nil,
        previous_accountable_agent_uid: nil,
        new_accountable_agent_uid: nil
      })

      assert changeset.valid?
      assert get_change(changeset, :delegatee_principal_uid) == nil
      assert get_change(changeset, :resulting_child_task_uid) == nil
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = DelegationRecord.__schema__(:fields)
      assert :id in fields
      assert :delegation_uid in fields
      assert :scope_description in fields
      assert :delegator_principal_uid in fields
      assert :source_task_uid in fields
      assert :delegatee_principal_uid in fields
      assert :resulting_child_task_uid in fields
      assert :previous_accountable_agent_uid in fields
      assert :new_accountable_agent_uid in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "primary key is id" do
      assert DelegationRecord.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "delegator belongs_to targets Principal" do
      assoc = DelegationRecord.__schema__(:association, :delegator)
      assert assoc.related == Ankole.Principals.Principal
      assert assoc.owner == DelegationRecord
      assert assoc.owner_key == :delegator_principal_uid
    end

    test "source_task belongs_to targets Task" do
      assoc = DelegationRecord.__schema__(:association, :source_task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == DelegationRecord
      assert assoc.owner_key == :source_task_uid
    end

    test "delegatee optional belongs_to targets Principal" do
      assoc = DelegationRecord.__schema__(:association, :delegatee)
      assert assoc.related == Ankole.Principals.Principal
      assert assoc.owner == DelegationRecord
      assert assoc.owner_key == :delegatee_principal_uid
    end

    test "resulting_child_task optional belongs_to targets Task" do
      assoc = DelegationRecord.__schema__(:association, :resulting_child_task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == DelegationRecord
      assert assoc.owner_key == :resulting_child_task_uid
    end
  end

  describe "constraint wiring" do
    test "unique constraint on delegation_uid is wired" do
      constraints = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "d1", scope_description: "Scope.",
        delegator_principal_uid: "p1", source_task_uid: "t1"
      }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :unique and c.constraint == "delegation_records_uid_index"
             end)
    end

    test "FK constraints are wired" do
      constraints = DelegationRecord.changeset(%DelegationRecord{}, %{
        delegation_uid: "d1", scope_description: "Scope.",
        delegator_principal_uid: "p1", source_task_uid: "t1"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :delegator_principal_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :source_task_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :delegatee_principal_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :resulting_child_task_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "delegation_uid is stored as :string" do
      assert DelegationRecord.__schema__(:type, :delegation_uid) == :string
    end

    test "scope_description is stored as :string" do
      assert DelegationRecord.__schema__(:type, :scope_description) == :string
    end

    test "delegator_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert DelegationRecord.__schema__(:type, :delegator_principal_uid) == Ankole.Ecto.PrincipalKey
    end

    test "source_task_uid is stored as :string" do
      assert DelegationRecord.__schema__(:type, :source_task_uid) == :string
    end

    test "delegatee_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert DelegationRecord.__schema__(:type, :delegatee_principal_uid) == Ankole.Ecto.PrincipalKey
    end

    test "resulting_child_task_uid is stored as :string" do
      assert DelegationRecord.__schema__(:type, :resulting_child_task_uid) == :string
    end
  end
end
