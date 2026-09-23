defmodule Ankole.WorkHierarchy.TaskLifecycleEvent do
  @moduledoc """
  Append-only audit log for Task lifecycle transitions.

  Each row records a transition of a Task's status, including the prior and
  target states, who triggered the change, when it occurred, and optional
  structured metadata (e.g. waiting_reason, failure_context). Historical rows
  are immutable after commit.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "task_lifecycle_events" do
    field :from_status, :string
    field :to_status, :string
    field :metadata, :map

    belongs_to :task, Ankole.WorkHierarchy.Task,
      foreign_key: :task_uid,
      references: :uid,
      type: :string

    belongs_to :changed_by, Ankole.Principals.Principal,
      foreign_key: :changed_by_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for TaskLifecycleEvent rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:task_uid, :from_status, :to_status, :changed_by_uid, :metadata])
    |> validate_required([:task_uid, :to_status, :changed_by_uid])
    |> foreign_key_constraint(:task_uid)
    |> foreign_key_constraint(:changed_by_uid)
  end
end
