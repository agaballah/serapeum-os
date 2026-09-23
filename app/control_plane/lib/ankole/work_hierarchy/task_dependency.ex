defmodule Ankole.WorkHierarchy.TaskDependency do
  @moduledoc """
  Durable dependency edge between two Tasks in the same Company.

  A dependency means "the Task with `task_uid` cannot proceed without satisfying
  the predecessor identified by `depends_on_task_uid`". The blocking semantics
  depend on `dependency_type` and are evaluated at read time by the consumer.
  Dependencies are mutable (hard delete); there is no soft-delete model in P5.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @canonical_dependency_types ~w(REQUIRES_COMPLETION REQUIRES_RESULT OPTIONAL)

  schema "task_dependencies" do
    field :dependency_type, :string, default: "REQUIRES_COMPLETION"

    belongs_to :task, Ankole.WorkHierarchy.Task,
      foreign_key: :task_uid,
      references: :uid,
      type: :string

    belongs_to :depends_on, Ankole.WorkHierarchy.Task,
      foreign_key: :depends_on_task_uid,
      references: :uid,
      type: :string

    timestamps()
  end

  @doc """
  Builds a changeset for TaskDependency rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(dependency, attrs) do
    dependency
    |> cast(attrs, [:task_uid, :depends_on_task_uid, :dependency_type])
    |> validate_required([:task_uid, :depends_on_task_uid])
    |> put_change_if_set(:dependency_type, attrs)
    |> validate_inclusion(:dependency_type, @canonical_dependency_types)
    |> unique_constraint(:task_uid, name: :task_dependencies_pkey)
    |> foreign_key_constraint(:task_uid)
    |> foreign_key_constraint(:depends_on_task_uid)
  end

  defp put_change_if_set(changeset, field, attrs) do
    case Map.fetch(attrs, field) do
      {:ok, value} when is_binary(value) -> put_change(changeset, field, value)
      _ -> changeset
    end
  end
end
