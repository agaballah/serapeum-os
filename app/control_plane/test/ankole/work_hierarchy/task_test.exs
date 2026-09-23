defmodule Ankole.WorkHierarchy.TaskTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Goal
  alias Ankole.WorkHierarchy.Mission
  alias Ankole.WorkHierarchy.Task

  @moduledoc """
  Tests for Ankole.WorkHierarchy.Task schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert changeset.valid?
    end

    test "uid is required" do
      changeset = Task.changeset(%Task{}, %{
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:uid, _} -> true; _ -> false end)
    end

    test "uid must be nonblank" do
      changeset = Task.changeset(%Task{}, %{
        uid: "   ",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert changeset.errors[:uid]
    end

    test "company_uid is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:company_uid, _} -> true; _ -> false end)
    end

    test "creator_principal_uid is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:creator_principal_uid, _} -> true; _ -> false end)
    end

    test "origin_kind is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:origin_kind, _} -> true; _ -> false end)
    end

    test "status is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:status, _} -> true; _ -> false end)
    end

    test "objective_text is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:objective_text, _} -> true; _ -> false end)
    end

    test "scope_text is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:scope_text, _} -> true; _ -> false end)
    end

    test "required_outcome_text is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        acceptance_criteria_text: "Passes all tests."
      })

      assert Enum.any?(changeset.errors, fn {:required_outcome_text, _} -> true; _ -> false end)
    end

    test "acceptance_criteria_text is required" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype."
      })

      assert Enum.any?(changeset.errors, fn {:acceptance_criteria_text, _} -> true; _ -> false end)
    end

    test "rejects invalid status value" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "INVALID_STATUS",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:status, _} -> true; _ -> false end)
    end

    test "rejects invalid origin_kind value" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "INVALID_KIND",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests."
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:origin_kind, _} -> true; _ -> false end)
    end

    test "rejects invalid child_completion_policy value" do
      changeset = Task.changeset(%Task{}, %{
        uid: "task-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "PROPOSED",
        objective_text: "Build the thing.",
        scope_text: "Within Q3.",
        required_outcome_text: "Working prototype.",
        acceptance_criteria_text: "Passes all tests.",
        child_completion_policy: "INVALID_POLICY"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:child_completion_policy, _} -> true; _ -> false end)
    end

    test "allows all canonical status values" do
      Enum.each(~w(PROPOSED READY ASSIGNED IN_PROGRESS WAITING REVIEW COMPLETED FAILED CANCELLED)a, fn status ->
        changeset = Task.changeset(%Task{}, %{
          uid: "task-#{status}",
          company_uid: "company-001",
          creator_principal_uid: "principal-001",
          origin_kind: "OWNER_REQUEST",
          status: Atom.to_string(status),
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
        assert Enum.all?(changeset.errors, fn {:status, _} -> false; _ -> true end)
      end)
    end

    test "allows all canonical origin_kind values" do
      Enum.each(~w(OWNER_REQUEST COMPANY_GOAL MISSION DELEGATION WORKFLOW SYSTEM_EVOLUTION EXTERNAL_EVENT)a, fn kind ->
        changeset = Task.changeset(%Task{}, %{
          uid: "task-#{kind}",
          company_uid: "company-001",
          creator_principal_uid: "principal-001",
          origin_kind: Atom.to_string(kind),
          status: "PROPOSED",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
        assert Enum.all?(changeset.errors, fn {:origin_kind, _} -> false; _ -> true end)
      end)
    end

    test "cancellation fields must be coherent" do
      # All nil is valid
      changeset = Task.changeset(%Task{}, %{
        uid: "task-cancel-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "CANCELLED",
        objective_text: "Build it.",
        scope_text: "Scope.",
        required_outcome_text: "Outcome.",
        acceptance_criteria_text: "Criteria.",
        cancelled_at: nil,
        cancelled_by_uid: nil,
        cancellation_reason: nil
      })
      assert Enum.all?(changeset.errors, fn {:cancellation_reason, _} -> false; _ -> true end)

      # All present is valid
      changeset = Task.changeset(%Task{}, %{
        uid: "task-cancel-002",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "CANCELLED",
        objective_text: "Build it.",
        scope_text: "Scope.",
        required_outcome_text: "Outcome.",
        acceptance_criteria_text: "Criteria.",
        cancelled_at: ~U[2026-01-01 00:00:00Z],
        cancelled_by_uid: "principal-001",
        cancellation_reason: "No longer needed."
      })
      assert Enum.all?(changeset.errors, fn {:cancellation_reason, _} -> false; _ -> true end)

      # Partial present is invalid
      changeset = Task.changeset(%Task{}, %{
        uid: "task-cancel-003",
        company_uid: "company-001",
        creator_principal_uid: "principal-001",
        origin_kind: "OWNER_REQUEST",
        status: "CANCELLED",
        objective_text: "Build it.",
        scope_text: "Scope.",
        required_outcome_text: "Outcome.",
        acceptance_criteria_text: "Criteria.",
        cancelled_at: ~U[2026-01-01 00:00:00Z],
        cancelled_by_uid: nil,
        cancellation_reason: nil
      })
      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:cancellation_reason, _} -> true; _ -> false end)
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = Task.__schema__(:fields)
      assert :id in fields
      assert :uid in fields
      assert :company_uid in fields
      assert :mission_uid in fields
      assert :goal_uid in fields
      assert :parent_task_uid in fields
      assert :accountable_agent_uid in fields
      assert :creator_principal_uid in fields
      assert :origin_kind in fields
      assert :origin_reference in fields
      assert :status in fields
      assert :objective_text in fields
      assert :scope_text in fields
      assert :required_outcome_text in fields
      assert :acceptance_criteria_text in fields
      assert :child_completion_policy in fields
      assert :inserted_at in fields
      assert :updated_at in fields
      assert :cancelled_at in fields
      assert :cancelled_by_uid in fields
      assert :cancellation_reason in fields
    end

    test "primary key is id" do
      assert Task.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "company belongs_to targets Company" do
      assoc = Task.__schema__(:association, :company)
      assert assoc.related == Company
      assert assoc.owner == Task
      assert assoc.owner_key == :company_uid
    end

    test "mission optional belongs_to targets Mission" do
      assoc = Task.__schema__(:association, :mission)
      assert assoc.related == Mission
      assert assoc.owner == Task
      assert assoc.owner_key == :mission_uid
    end

    test "goal optional belongs_to targets Goal" do
      assoc = Task.__schema__(:association, :goal)
      assert assoc.related == Goal
      assert assoc.owner == Task
      assert assoc.owner_key == :goal_uid
    end

    test "parent_task self-referencing belongs_to" do
      assoc = Task.__schema__(:association, :parent_task)
      assert assoc.related == Task
      assert assoc.owner == Task
      assert assoc.owner_key == :parent_task_uid
    end

    test "accountable_agent belongs_to targets Principal" do
      assoc = Task.__schema__(:association, :accountable_agent)
      assert assoc.related == Principal
      assert assoc.owner == Task
      assert assoc.owner_key == :accountable_agent_uid
    end

    test "creator belongs_to targets Principal" do
      assoc = Task.__schema__(:association, :creator)
      assert assoc.related == Principal
      assert assoc.owner == Task
      assert assoc.owner_key == :creator_principal_uid
    end

    test "cancelled_by optional belongs_to targets Principal" do
      assoc = Task.__schema__(:association, :cancelled_by)
      assert assoc.related == Principal
      assert assoc.owner == Task
      assert assoc.owner_key == :cancelled_by_uid
    end
  end

  describe "constraint wiring" do
    test "uid unique constraint is wired" do
      constraints = Task.changeset(%Task{}, %{}).constraints
      assert Enum.any?(constraints, fn c -> c.type == :unique and c.constraint == "tasks_uid_index" end)
    end

    test "FK constraints are wired for required references" do
      constraints = Task.changeset(%Task{}, %{
        uid: "t1", company_uid: "c1", creator_principal_uid: "p1",
        origin_kind: "OWNER_REQUEST", status: "PROPOSED",
        objective_text: "O", scope_text: "S", required_outcome_text: "R",
        acceptance_criteria_text: "A"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :company_uid and c.type == :foreign_key end)
      assert Enum.any?(constraints, fn c -> c.field == :creator_principal_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "uid is stored as :string" do
      assert Task.__schema__(:type, :uid) == :string
    end

    test "company_uid is stored as :string" do
      assert Task.__schema__(:type, :company_uid) == :string
    end

    test "mission_uid is stored as :string" do
      assert Task.__schema__(:type, :mission_uid) == :string
    end

    test "goal_uid is stored as :string" do
      assert Task.__schema__(:type, :goal_uid) == :string
    end

    test "parent_task_uid is stored as :string" do
      assert Task.__schema__(:type, :parent_task_uid) == :string
    end

    test "accountable_agent_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert Task.__schema__(:type, :accountable_agent_uid) == Ankole.Ecto.PrincipalKey
    end

    test "creator_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert Task.__schema__(:type, :creator_principal_uid) == Ankole.Ecto.PrincipalKey
    end

    test "origin_reference is stored as :map" do
      assert Task.__schema__(:type, :origin_reference) == :map
    end
  end
end
