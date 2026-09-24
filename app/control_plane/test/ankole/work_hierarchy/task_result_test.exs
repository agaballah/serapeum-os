defmodule Ankole.WorkHierarchy.TaskResultTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.TaskResult

  @moduledoc """
  Tests for Ankole.WorkHierarchy.TaskResult schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        executor_principal_uids: ["human-001"]
      })

      assert changeset.valid?
    end

    test "result_uid is required" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001"
      })

      assert Enum.any?(changeset.errors, fn {:result_uid, _} -> true; _ -> false end)
    end

    test "blank result_uid is rejected by check constraint" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "   ",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:result_uid, _} -> true; _ -> false end)
    end

    test "task_uid is required" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        execution_attempt_ref: "attempt-001"
      })

      assert Enum.any?(changeset.errors, fn {:task_uid, _} -> true; _ -> false end)
    end

    test "at least one execution reference is required" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:execution_reference, _} -> true; _ -> false end)
    end

    test "execution_attempt_ref alone satisfies the reference invariant" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001"
      })

      assert changeset.valid?
    end

    test "all execution references can be present" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        workflow_agent_call_id: 2,
        background_agent_job_id: 3,
        background_agent_job_turn_id: "00000000-0000-0000-0000-000000000001",
        execution_attempt_ref: "attempt-001"
      })

      assert changeset.valid?
    end

    test "executor_principal_uids accepts array" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        executor_principal_uids: ["human-001", "agent-001"]
      })

      assert changeset.valid?
    end

    test "executor_principal_uids accepts nil" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        executor_principal_uids: nil
      })

      assert changeset.valid?
    end

    test "result_metadata accepts jsonb" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        result_metadata: %{"key" => "value"}
      })

      assert changeset.valid?
    end

    test "acceptance_state accepts nullable text" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        acceptance_state: "pending"
      })

      assert changeset.valid?
    end

    test "acceptance_state accepts nil" do
      changeset = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "result-001",
        task_uid: "task-001",
        execution_attempt_ref: "attempt-001",
        acceptance_state: nil
      })

      assert changeset.valid?
    end

    test "unique constraint on result_uid is wired" do
      constraints = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "d1", task_uid: "t1", execution_attempt_ref: "attempt-001"
      }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :unique and c.constraint == "task_results_result_uid_index"
             end)
    end

    test "FK constraints are wired" do
      constraints = TaskResult.changeset(%TaskResult{}, %{
        result_uid: "d1", task_uid: "t1", execution_attempt_ref: "attempt-001"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :task_uid and c.type == :foreign_key end)
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = TaskResult.__schema__(:fields)
      assert :id in fields
      assert :result_uid in fields
      assert :task_uid in fields
      assert :workflow_run_id in fields
      assert :executor_principal_uids in fields
      assert :result_metadata in fields
      assert :acceptance_state in fields
      assert :failure_reason in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "primary key is id" do
      assert TaskResult.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "task belongs_to targets Task" do
      assoc = TaskResult.__schema__(:association, :task)
      assert assoc.related == Ankole.WorkHierarchy.Task
      assert assoc.owner == TaskResult
      assert assoc.owner_key == :task_uid
    end

    test "workflow_run belongs_to targets Workflow Run" do
      assoc = TaskResult.__schema__(:association, :workflow_run)
      assert assoc.related == Ankole.Workflow.Schemas.Run
      assert assoc.owner == TaskResult
      assert assoc.owner_key == :workflow_run_id
    end

    test "background_agent_job belongs_to targets BackgroundAgentJob" do
      assoc = TaskResult.__schema__(:association, :background_agent_job)
      assert assoc.related == Ankole.BackgroundAgentJobs.Schemas.Job
      assert assoc.owner == TaskResult
      assert assoc.owner_key == :background_agent_job_id
    end
  end

  describe "field types" do
    test "result_uid is stored as :string" do
      assert TaskResult.__schema__(:type, :result_uid) == :string
    end

    test "task_uid is stored as :string" do
      assert TaskResult.__schema__(:type, :task_uid) == :string
    end

    test "workflow_run_id is stored as :id" do
      assert TaskResult.__schema__(:type, :workflow_run_id) == :id
    end

    test "executor_principal_uids is an array type" do
      assert TaskResult.__schema__(:type, :executor_principal_uids) == {:array, Ankole.Ecto.PrincipalKey}
    end

    test "result_metadata is stored as :map" do
      assert TaskResult.__schema__(:type, :result_metadata) == :map
    end

    test "acceptance_state is stored as :string" do
      assert TaskResult.__schema__(:type, :acceptance_state) == :string
    end
  end
end

