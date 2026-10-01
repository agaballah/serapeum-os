defmodule Ankole.Repo.Migrations.ActionReceiptTruthfulnessV1 do
  @moduledoc """
  Makes the two ActionReceipt columns that had no established fact behind them
  nullable.

  `precondition_status` was written as the literal `"met"` although no
  precondition is evaluated anywhere in W3, and `approval_independent` was
  written as the literal `true` even when no Approval existed and no
  independence was checked. Both columns are now nullable so B-6 can record
  "not evaluated" instead of a fabricated fact.

  The existing CHECK constraints need no change: in PostgreSQL a CHECK against
  NULL evaluates to NULL, which is not false, so a NULL value passes
  `precondition_status IN ('met', 'not_met')`.

  No column is dropped or added. The receipt keeps its shape so the B-7
  sequencing work has somewhere to record real values.

  ## Referential truthfulness

  Two schema gaps let a receipt claim authority it never proved, so this
  migration closes both.

  `approval_uid` was a bare text column with no foreign key, unlike
  `principal_uid`, `company_uid`, and `capability_uid`. Nothing stopped a
  receipt from naming an Approval that does not exist, which is precisely the
  claim B-6 exists to prevent. It now references `approvals.uid` with
  `ON DELETE RESTRICT`, matching the other three references. A receipt may
  still record NULL, which truthfully means no Approval was presented.

  `capability_uid` had a foreign key but no index, so any lookup of the
  receipts for one Capability required a sequential scan. It now has a
  non-unique index, matching the existing non-unique indexes on
  `company_uid` and `principal_uid`. It must stay non-unique because many
  receipts can reference the same Capability.
  """

  use Ecto.Migration

  def up do
    alter table(:action_receipts) do
      modify :precondition_status, :text, null: true
      modify :approval_independent, :boolean, null: true
    end

    execute(
      "ALTER TABLE action_receipts ADD CONSTRAINT action_receipts_approval_uid_fkey " <>
        "FOREIGN KEY (approval_uid) REFERENCES approvals (uid) ON DELETE RESTRICT",
      "Adding a restrictive foreign key from action_receipts.approval_uid to approvals.uid"
    )

    create index(:action_receipts, [:capability_uid], name: :action_receipts_capability_uid_index)
  end

  def down do
    drop index(:action_receipts, [:capability_uid], name: :action_receipts_capability_uid_index)

    drop constraint(:action_receipts, :action_receipts_approval_uid_fkey)

    execute "UPDATE action_receipts SET precondition_status = 'met' WHERE precondition_status IS NULL"
    execute "UPDATE action_receipts SET approval_independent = true WHERE approval_independent IS NULL"

    alter table(:action_receipts) do
      modify :precondition_status, :text, null: false
      modify :approval_independent, :boolean, null: false, default: true
    end
  end
end