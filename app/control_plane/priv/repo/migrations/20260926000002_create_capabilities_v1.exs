defmodule Ankole.Repo.Migrations.CreateCapabilitiesV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:capabilities, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :action, :text, null: false
      add :resource, :text, null: false
      add :status, :text, null: false, default: "active"
      add :risk_class, :text, null: false
      add :issued_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: true
      add :revoked_at, :utc_datetime_usec, null: true
      add :issued_by_principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :parent_capability_uid, :text, null: true
      add :approval_uid, :text, null: true
      add :scope, :jsonb, null: false, default: "{}"
      add :constraints, :jsonb, null: false, default: "{}"
      add :metadata, :jsonb, null: false, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:capabilities, [:uid], name: :capabilities_uid_index)
    create index(:capabilities, [:company_uid], name: :capabilities_company_uid_index)
    create index(:capabilities, [:principal_uid], name: :capabilities_principal_uid_index)
    create index(:capabilities, [:company_uid, :principal_uid],
           name: :capabilities_company_principal_index
         )
    create index(:capabilities, [:company_uid, :status],
           name: :capabilities_company_status_index
         )
    create index(:capabilities, [:expires_at], name: :capabilities_expires_at_index)

    alter table(:capabilities) do
      modify :parent_capability_uid,
             references(:capabilities, column: :uid, type: :text, on_delete: :restrict),
             null: true
    end

    create constraint(:capabilities, :capabilities_uid_present,
      check: "btrim(uid) <> ''"
    )

    create constraint(:capabilities, :capabilities_action_present,
      check: "btrim(action) <> ''"
    )

    create constraint(:capabilities, :capabilities_resource_present,
      check: "btrim(resource) <> ''"
    )

    create constraint(:capabilities, :capabilities_status_valid,
      check: "status IN ('active', 'revoked', 'expired')"
    )

    create constraint(:capabilities, :capabilities_risk_class_valid,
      check: "risk_class IN ('ROUTINE', 'CONTROLLED', 'HIGH-IMPACT', 'PROHIBITED')"
    )

    create constraint(:capabilities, :capabilities_action_lowercase,
      check: "action = lower(action)"
    )
  end
end