defmodule Ankole.Repo.Migrations.AddTaskVersionV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :version, :integer, null: false, default: 1
    end

    create constraint(:tasks, :tasks_version_positive,
      check: "version > 0"
    )

    create index(:tasks, [:version], name: :tasks_version_index)
  end
end
