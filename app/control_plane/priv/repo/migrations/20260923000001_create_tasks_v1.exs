defmodule Ankole.Repo.Migrations.CreateTasksV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :company_uid, :text, null: false
      add :mission_uid, :text, null: true
      add :goal_uid, :text, null: true
      add :parent_task_uid, :text, null: true
      add :accountable_agent_uid, :text, null: true
      add :creator_principal_uid, :text, null: false
      add :origin_kind, :text, null: false
      add :origin_reference, :jsonb, null: true
      add :status, :text, null: false
      add :objective_text, :text, null: false
      add :scope_text, :text, null: false
      add :required_outcome_text, :text, null: false
      add :acceptance_criteria_text, :text, null: false
      add :child_completion_policy, :text, null: false, default: "ALL_COMPLETED"
      add :cancelled_at, :utc_datetime_usec, null: true
      add :cancelled_by_uid, :text, null: true
      add :cancellation_reason, :text, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:tasks, [:uid], name: :tasks_uid_index)
    create index(:tasks, [:company_uid], name: :tasks_company_uid_index)
    create index(:tasks, [:mission_uid], name: :tasks_mission_uid_index)
    create index(:tasks, [:parent_task_uid], name: :tasks_parent_task_uid_index)
    create index(:tasks, [:accountable_agent_uid], name: :tasks_accountable_agent_uid_index)
    create index(:tasks, [:creator_principal_uid], name: :tasks_creator_principal_uid_index)
    create index(:tasks, [:status], name: :tasks_status_index)
    create index(:tasks, [:inserted_at], name: :tasks_inserted_at_index)

    create constraint(:tasks, :tasks_uid_present, check: "btrim(uid) <> ''")

    create constraint(:tasks, :tasks_status_valid,
      check: "status IN ('PROPOSED', 'READY', 'ASSIGNED', 'IN_PROGRESS', 'WAITING', 'REVIEW', 'COMPLETED', 'FAILED', 'CANCELLED')"
    )

    create constraint(:tasks, :tasks_origin_kind_valid,
      check: "origin_kind IN ('OWNER_REQUEST', 'COMPANY_GOAL', 'MISSION', 'DELEGATION', 'WORKFLOW', 'SYSTEM_EVOLUTION', 'EXTERNAL_EVENT')"
    )

    create constraint(:tasks, :tasks_child_completion_policy_valid,
      check: "child_completion_policy IN ('ALL_COMPLETED', 'INDEPENDENT')"
    )

    create constraint(:tasks, :tasks_cancelled_fields_coherent,
      check: "(cancelled_at IS NULL AND cancelled_by_uid IS NULL AND cancellation_reason IS NULL) OR (cancelled_at IS NOT NULL AND cancelled_by_uid IS NOT NULL AND cancellation_reason IS NOT NULL)"
    )

    # Add FKs after table and indexes are created
    alter table(:tasks) do
      modify :company_uid,
             references(:companies, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :mission_uid,
             references(:missions, column: :uid, type: :text, on_delete: :restrict),
             null: true
      modify :goal_uid,
             references(:goals, column: :uid, type: :text, on_delete: :nilify_all),
             null: true
      modify :parent_task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :restrict),
             null: true
      modify :accountable_agent_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: true
      modify :creator_principal_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :cancelled_by_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: true
    end

    create table(:task_assignment_history, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :task_uid, :text, null: false
      add :previous_agent_uid, :text, null: true
      add :new_agent_uid, :text, null: false
      add :changed_by_uid, :text, null: false
      add :reason, :text, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:task_assignment_history, [:task_uid], name: :task_assignment_history_task_uid_index)
    create index(:task_assignment_history, [:inserted_at], name: :task_assignment_history_inserted_at_index)
    create index(:task_assignment_history, [:new_agent_uid], name: :task_assignment_history_new_agent_uid_index)

    alter table(:task_assignment_history) do
      modify :task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :delete_all),
             null: false
      modify :previous_agent_uid,
             references(:principals, column: :uid, type: :text, on_delete: :nilify_all),
             null: true
      modify :new_agent_uid,
             references(:principals, column: :uid, type: :text, on_delete: :nilify_all),
             null: true
      modify :changed_by_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: false
    end
  end
end
