defmodule Ankole.Repo.Migrations.CreateCompanyV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:companies, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :name, :text, null: false
      add :display_name, :text, null: false
      add :status, :text, null: false, default: "active"
      add :metadata, :jsonb, null: false, default: "{}"
      add :owner_principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :nothing),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:companies, [:uid], name: :companies_uid_index)
    create unique_index(:companies, [:name], name: :companies_name_index)

    create constraint(
             :companies,
             :companies_name_present,
             check: "btrim(name) <> ''"
           )

    create constraint(
             :companies,
             :companies_name_lowercase,
             check: "name = lower(name)"
           )

    create constraint(
             :companies,
             :companies_display_name_present,
             check: "btrim(display_name) <> ''"
           )

    create constraint(
             :companies,
             :companies_status_valid,
             check: "status IN ('active', 'disabled')"
           )
  end
end
