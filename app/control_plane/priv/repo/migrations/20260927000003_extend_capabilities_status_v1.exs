defmodule Ankole.Repo.Migrations.ExtendCapabilitiesStatusV1 do
  @moduledoc false

  use Ecto.Migration

  def up do
    execute("ALTER TABLE capabilities DROP CONSTRAINT capabilities_status_valid")

    execute("""
    ALTER TABLE capabilities
    ADD CONSTRAINT capabilities_status_valid
    CHECK (status IN ('active', 'requested', 'authorized', 'issued', 'consumed', 'revoked', 'expired'))
    """)
  end

  def down do
    execute("ALTER TABLE capabilities DROP CONSTRAINT capabilities_status_valid")

    execute("""
    ALTER TABLE capabilities
    ADD CONSTRAINT capabilities_status_valid
    CHECK (status IN ('active', 'revoked', 'expired'))
    """)
  end
end