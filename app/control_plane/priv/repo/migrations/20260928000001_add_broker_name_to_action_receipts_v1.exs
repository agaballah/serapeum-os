defmodule Ankole.Repo.Migrations.AddBrokerNameToActionReceiptsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    alter table(:action_receipts) do
      add :broker_name, :text, null: true
    end
  end
end
