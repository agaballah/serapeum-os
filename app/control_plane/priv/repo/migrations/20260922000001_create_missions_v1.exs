defmodule Ankole.Repo.Migrations.CreateMissionsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:missions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :creator_principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:missions, [:uid], name: :missions_uid_index)
    create index(:missions, [:company_uid], name: :missions_company_uid_index)
    create constraint(:missions, :missions_uid_present, check: "btrim(uid) <> ''")

    create table(:mission_revisions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :mission_uid,
          references(:missions, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :revision_number, :integer, null: false
      add :current_revision, :boolean, null: false
      add :goal_uid,
          references(:goals, column: :uid, type: :text, on_delete: :restrict),
          null: true
      add :assigned_agent_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: true
      add :organizational_unit_uid,
          references(:organizational_units, column: :uid, type: :text, on_delete: :restrict),
          null: true
      add :creator_principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :content, :text, null: false
      add :content_hash, :text, null: false

      timestamps(type: :utc_datetime_usec, update_at: false)
    end

    create unique_index(
             :mission_revisions,
             [:mission_uid, :revision_number],
             name: :mission_revisions_uid_version_index
           )

    create unique_index(
             :mission_revisions,
             [:mission_uid],
             name: :mission_revisions_one_current_per_mission,
             where: "current_revision = true"
           )

    create unique_index(
             :mission_revisions,
             [:assigned_agent_uid],
             name: :mission_revisions_one_current_per_agent,
             where: "current_revision = true AND assigned_agent_uid IS NOT NULL"
           )

    create index(
             :mission_revisions,
             [:mission_uid],
             name: :mission_revisions_mission_uid_index
           )

    create constraint(
             :mission_revisions,
             :mission_revisions_content_present,
             check: "length(btrim(content)) > 0"
           )

    create constraint(
             :mission_revisions,
             :mission_revisions_revision_number_positive,
             check: "revision_number >= 1"
           )

    create constraint(
             :mission_revisions,
             :mission_revisions_xor_target,
             check: "(assigned_agent_uid IS NOT NULL AND organizational_unit_uid IS NULL) OR (assigned_agent_uid IS NULL AND organizational_unit_uid IS NOT NULL)"
           )
  end
end
