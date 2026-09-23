defmodule Ankole.WorkHierarchy.TaskChildPolicyHistory do
  @moduledoc """
  Append-only audit log for Task child-completion-policy mutations.

  Each row records the old and new policy values for a Task at the moment of
  mutation. Historical rows are immutable after commit.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ankole.Principals.Principal

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "task_child_policy_history" do
    field :old_policy, :string
    field :new_policy, :string

    belongs_to :task, Ankole.WorkHierarchy.Task,
      foreign_key: :task_uid,
      references: :uid,
      type: :string

    belongs_to :changed_by, Principal,
      foreign_key: :changed_by_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for TaskChildPolicyHistory rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(history, attrs) do
    history
    |> cast(attrs, [:task_uid, :old_policy, :new_policy, :changed_by_uid])
    |> validate_required([:task_uid, :old_policy, :new_policy, :changed_by_uid])
    |> foreign_key_constraint(:task_uid)
    |> foreign_key_constraint(:changed_by_uid)
  end
end
