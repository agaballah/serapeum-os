defmodule Ankole.Repo.Migrations.CreateCompanyMembershipsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:company_memberships, primary_key: false) do
      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :nothing),
          primary_key: true,
          null: false

      add :principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :delete_all),
          primary_key: true,
          null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:company_memberships, [:principal_uid])
  end
end
