defmodule Ankole.Repo.Migrations.ActionReceiptExecutionTruthfulnessV1 do
  @moduledoc """
  Makes `action_receipts.execution_failed` nullable and removes its default.

  `execution_failed` was written as `!verified?`, so the column asserted a
  fact about execution that the finalization API never established: a missing
  postcondition verification became an execution failure, and a caller-supplied
  `true` became an execution success. The column was also `null: false` with
  `default: false`, so any insert that omitted the field recorded "execution
  did not fail" without evidence.

  This migration changes only nullability and the default. Existing rows keep
  their stored values, because those values are historical records of what the
  previous code asserted and rewriting them would fabricate a different past.

  `up` drops the default and permits NULL so the column can represent
  "not established". `down` restores the previous `null: false` shape, which
  requires resolving NULLs first; it writes `false` because the previous
  schema had no way to record that execution had not been observed.
  """

  use Ecto.Migration

  def up do
    alter table(:action_receipts) do
      modify :execution_failed, :boolean, null: true, default: nil
    end
  end

  def down do
    # The previous schema was NOT NULL, so a downgrade cannot restore it while
    # NULL rows remain. Rows written after the forward migration recorded "not
    # established"; the old shape cannot express that, so it collapses to
    # `false`. This is a deliberate loss of the unknown state, forced by the
    # schema being restored rather than chosen.
    execute "UPDATE action_receipts SET execution_failed = false WHERE execution_failed IS NULL"

    alter table(:action_receipts) do
      modify :execution_failed, :boolean, null: false, default: false
    end
  end
end