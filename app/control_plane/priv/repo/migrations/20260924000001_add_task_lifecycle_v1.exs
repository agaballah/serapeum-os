defmodule Ankole.Repo.Migrations.AddTaskLifecycleV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :failure_reason, :text, null: true
    end

    create table(:task_lifecycle_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :task_uid, :text, null: false
      add :from_status, :text, null: true
      add :to_status, :text, null: false
      add :changed_by_uid, :text, null: false
      add :metadata, :jsonb, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:task_lifecycle_events, [:task_uid], name: :task_lifecycle_events_task_uid_index)
    create index(:task_lifecycle_events, [:inserted_at], name: :task_lifecycle_events_inserted_at_index)

    alter table(:task_lifecycle_events) do
      modify :task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :changed_by_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: false
    end
  end
end
