defmodule Ankole.WorkHierarchy.Goal do
  @moduledoc """
  Durable desired outcome scoped to exactly one Company.

  A Goal is the top of the SerapeumOS work hierarchy. It has a stable
  caller-supplied identity, mandatory Company scope, user-defined outcome
  content, and creation provenance. It carries no lifecycle status.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Company
  alias Ankole.Principals.Principal

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "goals" do
    field :uid, :string
    field :title, :string
    field :description, :string

    belongs_to :company, Company,
      foreign_key: :company_uid,
      references: :uid,
      type: :string

    belongs_to :creator, Principal,
      foreign_key: :creator_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for Goal rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:uid, :company_uid, :title, :description, :creator_principal_uid])
    |> normalize_blank([:uid, :title])
    |> validate_required([:uid, :company_uid, :title, :creator_principal_uid])
    |> check_constraint(:uid, name: :goals_uid_present)
    |> check_constraint(:title, name: :goals_title_present)
    |> unique_constraint(:uid, name: :goals_uid_index)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:creator_principal_uid)
  end
end
