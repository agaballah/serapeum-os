defmodule Ankole.Repo.Migrations.CreateTaskDependenciesAndDelegationsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:task_dependencies, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :task_uid, :text, null: false
      add :depends_on_task_uid, :text, null: false
      add :dependency_type, :text, null: false, default: "REQUIRES_COMPLETION"

      timestamps(type: :utc_datetime_usec, update_at: false)
    end

    create index(:task_dependencies, [:task_uid], name: :task_dependencies_task_uid_index)
    create index(:task_dependencies, [:depends_on_task_uid], name: :task_dependencies_depends_on_task_uid_index)

    alter table(:task_dependencies) do
      modify :task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :delete_all),
             null: false
      modify :depends_on_task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :delete_all),
             null: false
    end

    create constraint(:task_dependencies, :task_dependencies_dependency_type_valid,
      check: "dependency_type IN ('REQUIRES_COMPLETION', 'REQUIRES_RESULT', 'OPTIONAL')"
    )

    create table(:delegation_records, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :delegation_uid, :text, null: false
      add :scope_description, :text, null: false
      add :delegator_principal_uid, :text, null: false
      add :source_task_uid, :text, null: false
      add :delegatee_principal_uid, :text, null: true
      add :resulting_child_task_uid, :text, null: true
      add :previous_accountable_agent_uid, :text, null: true
      add :new_accountable_agent_uid, :text, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:delegation_records, [:delegation_uid], name: :delegation_records_uid_index)
    create index(:delegation_records, [:source_task_uid], name: :delegation_records_source_task_uid_index)
    create index(:delegation_records, [:resulting_child_task_uid], name: :delegation_records_child_task_uid_index)

    alter table(:delegation_records) do
      modify :delegator_principal_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :source_task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :delegatee_principal_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: true
      modify :resulting_child_task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :restrict),
             null: true
      modify :previous_accountable_agent_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: true
      modify :new_accountable_agent_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: true
    end

    create constraint(:delegation_records, :delegation_records_scope_description_present,
      check: "btrim(scope_description) <> ''"
    )

    create table(:delegation_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :delegation_uid, :text, null: false
      add :event_type, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:delegation_events, [:delegation_uid], name: :delegation_events_delegation_uid_index)
    create index(:delegation_events, [:inserted_at], name: :delegation_events_inserted_at_index)

    alter table(:delegation_events) do
      modify :delegation_uid,
               references(:delegation_records, column: :delegation_uid, type: :text, on_delete: :delete_all),
              null: false
    end

    create table(:task_child_policy_history, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :task_uid, :text, null: false
      add :old_policy, :text, null: false
      add :new_policy, :text, null: false
      add :changed_by_uid, :text, null: false

      timestamps(type: :utc_datetime_usec, update_at: false)
    end

    create index(:task_child_policy_history, [:task_uid], name: :task_child_policy_history_task_uid_index)
    create index(:task_child_policy_history, [:inserted_at], name: :task_child_policy_history_inserted_at_index)

    alter table(:task_child_policy_history) do
      modify :task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :delete_all),
             null: false
      modify :changed_by_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: false
    end
  end
end
