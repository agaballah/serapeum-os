defmodule Ankole.Company.Membership do
  @moduledoc """
  Durable membership of a Principal in a Company.

  A membership row answers "Is this Principal part of this Company?" and
  nothing else: it carries no status, role, or metadata. Permission remains
  AuthZ. A Human Principal may hold zero-to-many memberships. An Agent
  Principal belongs to exactly one Company. System Principals hold no
  membership in this layer.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ankole.Company
  alias Ankole.Principals.Principal

  @primary_key false
  @timestamps_opts [type: :utc_datetime_usec, updated_at: false]

  schema "company_memberships" do
    belongs_to :company, Company,
      foreign_key: :company_uid,
      references: :uid,
      type: :string,
      primary_key: true

    belongs_to :principal, Principal,
      foreign_key: :principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey,
      primary_key: true

    timestamps(updated_at: false)
  end

  @doc """
  Builds a changeset for company membership rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:company_uid, :principal_uid])
    |> validate_required([:company_uid, :principal_uid])
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:principal_uid)
    |> unique_constraint(:company_uid, name: :company_memberships_pkey)
  end
end
