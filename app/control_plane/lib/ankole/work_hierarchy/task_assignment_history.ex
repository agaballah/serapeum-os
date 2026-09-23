defmodule Ankole.WorkHierarchy.TaskAssignmentHistory do
  @moduledoc """
  Append-only audit log for Task assignment changes.

  Each row records a transition of the accountable Agent for a Task, including
  the previous and new Agent UIDs, the timestamp, who triggered the change,
  and an optional reason. Historical rows are immutable after commit.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "task_assignment_history" do
    field :previous_agent_uid, Ankole.Ecto.PrincipalKey
    field :new_agent_uid, Ankole.Ecto.PrincipalKey
    field :reason, :string

    belongs_to :task, Ankole.WorkHierarchy.Task,
      foreign_key: :task_uid,
      references: :uid,
      type: :string

    belongs_to :changed_by, Ankole.Principals.Principal,
      foreign_key: :changed_by_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps(update_at: false)
  end

  @doc """
  Builds a changeset for TaskAssignmentHistory rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(history, attrs) do
    history
    |> cast(attrs, [:task_uid, :previous_agent_uid, :new_agent_uid, :changed_by_uid, :reason])
    |> validate_required([:task_uid, :new_agent_uid, :changed_by_uid])
    |> foreign_key_constraint(:task_uid)
    |> foreign_key_constraint(:previous_agent_uid)
    |> foreign_key_constraint(:new_agent_uid)
    |> foreign_key_constraint(:changed_by_uid)
  end
end
