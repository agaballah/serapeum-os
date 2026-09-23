defmodule Ankole.WorkHierarchy.DelegationRecord do
  @moduledoc """
  Durable delegation record scoped to one Company.

  A DelegationRecord captures the structural fact that one Principal delegated
  work from one Task to another (or to no child at all when only reassignment
  occurs). It is mutable for the `resulting_child_task_uid` back-fill; the
  matching `delegation_events` rows are append-only audit history.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Task

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "delegation_records" do
    field :delegation_uid, :string
    field :scope_description, :string

    belongs_to :delegator, Principal,
      foreign_key: :delegator_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :source_task, Task,
      foreign_key: :source_task_uid,
      references: :uid,
      type: :string

    belongs_to :delegatee, Principal,
      foreign_key: :delegatee_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :resulting_child_task, Task,
      foreign_key: :resulting_child_task_uid,
      references: :uid,
      type: :string

    belongs_to :previous_accountable_agent, Principal,
      foreign_key: :previous_accountable_agent_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :new_accountable_agent, Principal,
      foreign_key: :new_accountable_agent_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for DelegationRecord rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :delegation_uid,
      :scope_description,
      :delegator_principal_uid,
      :source_task_uid,
      :delegatee_principal_uid,
      :resulting_child_task_uid,
      :previous_accountable_agent_uid,
      :new_accountable_agent_uid
    ])
    |> normalize_blank([:delegation_uid, :scope_description])
    |> validate_required([:delegation_uid, :scope_description, :delegator_principal_uid,
                          :source_task_uid])
    |> unique_constraint(:delegation_uid, name: :delegation_records_uid_index)
    |> check_constraint(:scope_description, name: :delegation_records_scope_description_present)
    |> foreign_key_constraint(:delegator_principal_uid)
    |> foreign_key_constraint(:source_task_uid)
    |> foreign_key_constraint(:delegatee_principal_uid)
    |> foreign_key_constraint(:resulting_child_task_uid)
    |> foreign_key_constraint(:previous_accountable_agent_uid)
    |> foreign_key_constraint(:new_accountable_agent_uid)
  end
end
