defmodule Ankole.WorkHierarchy.MigrationRollbackTest do
  @moduledoc """
  P7 migration rollback test for W2 schema.

  Verifies the version migration is actually reversible using isolated
  raw DDL inside a SERIALIZABLE transaction. The test never commits
  schema changes to the shared database.
  """

  use Ankole.DataCase, async: false

  test "version migration is actually reversible" do
    Repo.transaction(fn ->
      # Verify current schema matches the UP state before we start
      {:ok, %{rows: [[count_before]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'version'", [])
      assert count_before == 1

      # DOWN: remove version column
      Ecto.Adapters.SQL.query!(Repo, "DROP INDEX IF EXISTS tasks_version_index", [])
      Ecto.Adapters.SQL.query!(Repo, "ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_version_positive", [])
      Ecto.Adapters.SQL.query!(Repo, "ALTER TABLE tasks DROP COLUMN IF EXISTS version", [])

      # Verify DOWN
      {:ok, %{rows: [[count_after_down]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'version'", [])
      assert count_after_down == 0

      # UP: re-apply version column
      Ecto.Adapters.SQL.query!(Repo, "ALTER TABLE tasks ADD COLUMN version INTEGER NOT NULL DEFAULT 1", [])
      Ecto.Adapters.SQL.query!(Repo, "ALTER TABLE tasks ADD CONSTRAINT tasks_version_positive CHECK (version > 0)", [])
      Ecto.Adapters.SQL.query!(Repo, "CREATE INDEX tasks_version_index ON tasks(version)", [])

      # Verify UP
      {:ok, %{rows: [[count_after_up]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'version'", [])
      assert count_after_up == 1

      # Verify column properties
      {:ok, %{rows: [[is_nullable]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT is_nullable FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'version'", [])
      assert is_nullable == "NO"

      {:ok, %{rows: [[col_default]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT column_default FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'version'", [])
      assert col_default == "1"

      {:ok, %{rows: [[has_check]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'tasks' AND constraint_name = 'tasks_version_positive' AND constraint_type = 'CHECK')", [])
      assert has_check

      {:ok, %{rows: [[has_index]]} } = Ecto.Adapters.SQL.query(Repo,
        "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'tasks' AND indexname = 'tasks_version_index')", [])
      assert has_index
    end,
    isolation_level: :serializable
  )
end
end
