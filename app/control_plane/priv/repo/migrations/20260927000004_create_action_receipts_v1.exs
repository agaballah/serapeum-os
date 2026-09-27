defmodule Ankole.Repo.Migrations.CreateActionReceiptsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:action_receipts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :receipt_uid, :text, null: false
      add :intent_action, :text, null: false
      add :intent_resource, :text, null: false
      add :principal_uid,
          references(:principals, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :company_uid,
          references(:companies, column: :uid, type: :text, on_delete: :restrict),
          null: false
      add :risk_class, :text, null: false
      add :authz_decision, :text, null: false
      add :precondition_status, :text, null: false
      add :approval_uid, :text, null: true
      add :approval_independent, :boolean, null: false, default: true
      add :capability_uid,
          references(:capabilities, column: :uid, type: :text, on_delete: :restrict),
          null: true
      add :postcondition_expected, :jsonb, null: false, default: "{}"
      add :postcondition_verified, :boolean, null: true
      add :verified_at, :utc_datetime_usec, null: true
      add :result_output, :jsonb, null: true
      add :execution_failed, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:action_receipts, [:receipt_uid], name: :action_receipts_receipt_uid_index)
    create index(:action_receipts, [:company_uid], name: :action_receipts_company_uid_index)
    create index(:action_receipts, [:principal_uid], name: :action_receipts_principal_uid_index)
    create index(:action_receipts, [:inserted_at], name: :action_receipts_inserted_at_index)

    create constraint(:action_receipts, :action_receipts_risk_class_valid,
      check: "risk_class IN ('ROUTINE', 'CONTROLLED', 'HIGH-IMPACT', 'PROHIBITED')"
    )

    create constraint(:action_receipts, :action_receipts_authz_decision_valid,
      check: "authz_decision IN ('ALLOW', 'DENY')"
    )

    create constraint(:action_receipts, :action_receipts_precondition_valid,
      check: "precondition_status IN ('met', 'not_met')"
    )
  end
end