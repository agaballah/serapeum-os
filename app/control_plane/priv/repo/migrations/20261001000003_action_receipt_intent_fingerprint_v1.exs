defmodule Ankole.Repo.Migrations.ActionReceiptIntentFingerprintV1 do
  @moduledoc """
  Adds `action_receipts.params_hash`, the fingerprint of the effective intent.

  A receipt recorded which action and which resource string were assured, but
  not the caller-controlled values behind them. Two assurances for the same
  action and resource could therefore carry identical receipts while describing
  different mutations. The fingerprint binds those values.

  The column is nullable in the database because historical rows predate it and
  rewriting them would record a value no assurance ever computed. The column
  carries no default for the same reason a default would be a fabrication: an
  omitted fingerprint must stay absent, not become a plausible-looking value.

  New receipts are required to carry one at the application level. The CHECK
  constraint keeps a stored fingerprint in the one shape this system defines,
  `v<schema version>:<64 lowercase hex digits>`, so a malformed or
  wrongly-cased value cannot be written directly.
  """

  use Ecto.Migration

  def up do
    alter table(:action_receipts) do
      add :params_hash, :text, null: true
    end

    execute """
    ALTER TABLE action_receipts
    ADD CONSTRAINT action_receipts_params_hash_format
    CHECK (params_hash IS NULL OR params_hash ~ '^v[1-9][0-9]*:[0-9a-f]{64}$')
    """
  end

  def down do
    execute "ALTER TABLE action_receipts DROP CONSTRAINT IF EXISTS action_receipts_params_hash_format"

    alter table(:action_receipts) do
      remove :params_hash
    end
  end
end
