defmodule Ankole.WorkHierarchy.ReviewEvent do
  @moduledoc """
  Append-only audit log for ReviewRecord lifecycle events.

  Each row records a typed event on a ReviewRecord (created, invalidated).
  Historical rows are immutable after commit.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @canonical_event_types ~w(created invalidated)

  schema "review_events" do
    field :event_type, :string
    field :reviewer_uid, Ankole.Ecto.PrincipalKey
    field :metadata, :map

    belongs_to :review, Ankole.WorkHierarchy.ReviewRecord,
      foreign_key: :review_uid,
      references: :review_uid,
      type: :string

    timestamps()
  end

  @doc """
  Builds a changeset for ReviewEvent rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:review_uid, :event_type, :reviewer_uid, :metadata])
    |> validate_required([:review_uid, :event_type])
    |> validate_inclusion(:event_type, @canonical_event_types)
    |> foreign_key_constraint(:review_uid)
  end
end