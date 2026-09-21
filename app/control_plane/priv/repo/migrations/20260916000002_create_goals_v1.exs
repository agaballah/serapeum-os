defmodule Ankole.Repo.Migrations.CreateGoalsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:goals, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :title, :text, null: false
      add :description, :text, null: true
      add :creator_principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:goals, [:uid], name: :goals_uid_index)
    create index(:goals, [:company_uid], name: :goals_company_uid_index)

    create constraint(:goals, :goals_uid_present, check: "btrim(uid) <> ''")
    create constraint(:goals, :goals_title_present, check: "btrim(title) <> ''")
  end
end
