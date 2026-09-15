defmodule Ankole.Company do
  @moduledoc """
  The durable organizational aggregate that owns Principals, work, and state.

  A Company is not a Principal, Worker, installation, or database row on its own.
  It is a SerapeumOS-owned aggregate that wraps one or more Principals under a
  shared organizational identity. An initial product version exposes one active
  Company per installation; the aggregate keeps explicit scope so future
  multi-Company support does not require a core data-model redesign.

  The exact identifier encoding is a generated UUIDv7 stored in the `uid` field.
  Human-readable Company name and display profile are mutable; the uid is
  immutable once committed.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2, normalize_lower: 2]

  alias Ankole.Principals.Principal

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "companies" do
    field :uid, :string
    field :name, :string
    field :display_name, :string
    field :status, Ecto.Enum, values: [:created, :active, :suspended, :archived], default: :created
    field :metadata, :map, default: %{}

    belongs_to :owner_principal, Principal,
      foreign_key: :owner_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for company rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:uid, :name, :display_name, :status, :metadata, :owner_principal_uid])
    |> normalize_blank([:uid, :name, :display_name])
    |> normalize_lower(:name)
    |> validate_required([:name, :display_name, :status, :metadata, :owner_principal_uid])
    |> validate_format(:name, ~r/\A[a-z0-9][a-z0-9._-]*[a-z0-9]\z/,
      message: "must be lowercase alphanumeric, dots, hyphens, and underscores"
    )
    |> validate_length(:name, min: 3, max: 63)
    |> validate_length(:display_name, min: 1, max: 128)
    |> unique_constraint(:name, name: :companies_name_index)
    |> check_constraint(:name, name: :companies_name_present)
    |> check_constraint(:name, name: :companies_name_lowercase)
    |> check_constraint(:display_name, name: :companies_display_name_present)
    |> foreign_key_constraint(:owner_principal_uid)
  end
end
