defmodule Ankole.WorkHierarchy.DelegationEvent do
  @moduledoc """
  Append-only audit log for DelegationRecord lifecycle events.

  Each row records a typed event on a DelegationRecord (created, reassignment,
  completed, cancelled). Historical rows are immutable after commit.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "delegation_events" do
    field :delegation_uid, :string
    field :event_type, :string

    timestamps()
  end

  @doc """
  Builds a changeset for DelegationEvent rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:delegation_uid, :event_type])
    |> validate_required([:delegation_uid, :event_type])
    |> foreign_key_constraint(:delegation_uid)
  end
end
