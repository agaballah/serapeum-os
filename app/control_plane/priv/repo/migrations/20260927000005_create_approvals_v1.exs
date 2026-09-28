defmodule Ankole.Repo.Migrations.CreateApprovalsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:approvals, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :text, null: false
      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :requester_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :approver_uid, :text, null: true
      add :action, :text, null: false
      add :resource, :text, null: false
      add :capability_uid,
          references(:capabilities, column: :uid, type: :text, on_delete: :restrict),
          null: true
      add :task_uid, :text, null: true
      add :risk_class, :text, null: false
      add :status, :text, null: false, default: "requested"
      add :approved_at, :utc_datetime_usec, null: true
      add :expires_at, :utc_datetime_usec, null: true
      add :revoked_at, :utc_datetime_usec, null: true
      add :reason, :text, null: true
      add :metadata, :jsonb, null: false, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:approvals, [:uid], name: :approvals_uid_index)
    create index(:approvals, [:company_uid], name: :approvals_company_uid_index)
    create index(:approvals, [:requester_uid], name: :approvals_requester_uid_index)
    create index(:approvals, [:status], name: :approvals_status_index)
    create index(:approvals, [:expires_at], name: :approvals_expires_at_index)

    alter table(:approvals) do
      modify :approver_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: true
    end

    create constraint(:approvals, :approvals_uid_present,
      check: "btrim(uid) <> ''"
    )

    create constraint(:approvals, :approvals_action_present,
      check: "btrim(action) <> ''"
    )

    create constraint(:approvals, :approvals_resource_present,
      check: "btrim(resource) <> ''"
    )

    create constraint(:approvals, :approvals_risk_class_valid,
      check: "risk_class IN ('ROUTINE', 'CONTROLLED', 'HIGH-IMPACT', 'PROHIBITED')"
    )

    create constraint(:approvals, :approvals_status_valid,
      check: "status IN ('requested', 'pending', 'approved', 'rejected', 'expired', 'revoked')"
    )
  end
end