defmodule Ankole.Repo.Migrations.CreateOrganizationalUnitsV1 do
  @moduledoc false

  use Ecto.Migration

  def up do
    # STEP 1 — CREATE TABLE (parent_unit_uid without FK)
    create table(:organizational_units, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :name, :text, null: false
      add :status, :text, null: false, default: "active"

      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :nothing),
          null: false

      add :parent_unit_uid, :text, null: true

      timestamps(type: :utc_datetime_usec)
    end

    # STEP 2 — UID UNIQUENESS
    create unique_index(:organizational_units, [:uid], name: :organizational_units_uid_index)

    # STEP 3 — SELF-REFERENCING FK (only after uid uniqueness exists)
    execute(
      "ALTER TABLE organizational_units ADD CONSTRAINT organizational_units_parent_unit_uid_fkey " <>
        "FOREIGN KEY (parent_unit_uid) REFERENCES organizational_units(uid) ON DELETE NO ACTION"
    )

    # STEP 4 — QUERY INDEXES
    create index(:organizational_units, [:company_uid], name: :organizational_units_company_uid_index)
    create index(:organizational_units, [:parent_unit_uid], name: :organizational_units_parent_unit_uid_index)

    # STEP 5 — CHECK CONSTRAINTS
    create constraint(
             :organizational_units,
             :organizational_units_uid_present,
             check: "btrim(uid) <> ''"
           )

    create constraint(
             :organizational_units,
             :organizational_units_name_present,
             check: "btrim(name) <> ''"
           )

    create constraint(
             :organizational_units,
             :organizational_units_status_valid,
             check: "status IN ('active', 'archived')"
           )
  end

  def down do
    drop constraint(:organizational_units, :organizational_units_status_valid)
    drop constraint(:organizational_units, :organizational_units_name_present)
    drop constraint(:organizational_units, :organizational_units_uid_present)
    execute("DROP INDEX IF EXISTS organizational_units_parent_unit_uid_index")
    execute("DROP INDEX IF EXISTS organizational_units_company_uid_index")
    execute("ALTER TABLE organizational_units DROP CONSTRAINT IF EXISTS organizational_units_parent_unit_uid_fkey")
    execute("DROP INDEX IF EXISTS organizational_units_uid_index")
    drop table(:organizational_units)
  end
end
