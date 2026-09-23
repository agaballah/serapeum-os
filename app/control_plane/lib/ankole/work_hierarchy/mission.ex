defmodule Ankole.WorkHierarchy.Mission do
  @moduledoc """
  Durable Mission identity scoped to exactly one Company.

  A Mission is the second level of the SerapeumOS work hierarchy, below Goal.
  It carries a stable caller-supplied identity, mandatory Company scope, and
  creation provenance. Revision history lives in `MissionRevision` rows; this
  table owns only identity metadata.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Company
  alias Ankole.Principals.Principal

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "missions" do
    field :uid, :string

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
  Builds a changeset for Mission identity rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(mission, attrs) do
    mission
    |> cast(attrs, [:uid, :company_uid, :creator_principal_uid])
    |> normalize_blank([:uid])
    |> validate_required([:uid, :company_uid, :creator_principal_uid])
    |> check_constraint(:uid, name: :missions_uid_present)
    |> unique_constraint(:uid, name: :missions_uid_index)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:creator_principal_uid)
  end
end
