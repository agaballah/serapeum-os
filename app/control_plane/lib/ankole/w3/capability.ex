defmodule Ankole.W3.Capability do
  @moduledoc """
  Durable Company-scoped Capability.

  A Capability is a bounded authorization artifact owned by exactly one
  Company. It binds one Principal to one action/resource pair under that
  Company, with provenance recording who issued it, what risk class applies,
  and whether it carries an approval binding, expiration, or delegation source.

  This module is the P2 persistence contract only. It does not evaluate,
  attenuate, or enforce capabilities; enforcement belongs to later W3
  packages. The schema exists so the durable record is queryable, auditable,
  and Company-scoped from day one.

  Identity
  -------
  `uid` is the stable Capability identity. It is immutable once committed and
  unique installation-wide.

  Company scope
  ------------
  Every Capability carries an unambiguous `company_uid` foreign key. A
  Capability cannot exist outside a Company, and the Store enforces that
  scoping at read time. Cross-Company access fails closed.

  Subject
  -------
  `principal_uid` is the Principal the Capability is issued to. It is a
  foreign key into `principals`. The Company boundary is enforced by the
  Store, not by the schema alone: a Principal that belongs to Company A can
  hold a Capability in Company B only if the Store validates membership.

  Action/resource binding
  ----------------------
  `action` and `resource` are the exact authorized binding. Both are
  non-blank text. `action` is normalized to lowercase so the same binding
  cannot be recorded in two casings.

  Lifecycle state
  -------------
  `status` records the current lifecycle state. P2 accepts the canonical
  states defined by the architecture: `active`, `revoked`, `expired`.
  Lifecycle transitions are owned by W3-P3 and are NOT implemented here.

  Bounded lifetime
  ---------------
  `expires_at` and `revoked_at` are nullable timestamps that mark when
  the Capability ceases to be valid. P2 persists these fields; expiry
  processing and revocation workflow belong to later packages.

  Provenance
  ---------
  `issued_by_principal_uid` records who issued the Capability.
  `parent_capability_uid` records the source Capability in a delegation
  chain (nullable; absent for top-level issuances).
  `approval_uid` records an approved reference where the action requires
  independent consent (nullable).
  `scope` carries originating Task/Mission context.
  `constraints` carries bounded parameters.
  `risk_class` records the architectural risk classification.
  `metadata` carries auditable supplementary information.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2, normalize_lower: 2]

  alias Ankole.Company
  alias Ankole.Principals.Principal

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @canonical_statuses [:active, :revoked, :expired]
  @canonical_risk_classes ~w(ROUTINE CONTROLLED HIGH-IMPACT PROHIBITED)

  schema "capabilities" do
    field :uid, :string
    field :action, :string
    field :resource, :string
    field :status, Ecto.Enum, values: @canonical_statuses, default: :active
    field :risk_class, :string
    field :issued_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    field :scope, :map, default: %{}
    field :constraints, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :company, Company,
      foreign_key: :company_uid,
      references: :uid,
      type: :string

    belongs_to :principal, Principal,
      foreign_key: :principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :issuer, Principal,
      foreign_key: :issued_by_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    field :parent_capability_uid, :string
    field :approval_uid, :string

    timestamps()
  end

  @doc """
  Builds a changeset for Capability rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(capability, attrs) do
    capability
    |> cast(attrs, [
      :uid,
      :company_uid,
      :principal_uid,
      :action,
      :resource,
      :status,
      :risk_class,
      :issued_at,
      :expires_at,
      :revoked_at,
      :issued_by_principal_uid,
      :parent_capability_uid,
      :approval_uid,
      :scope,
      :constraints,
      :metadata
    ])
    |> normalize_blank([:uid, :action, :resource, :risk_class])
    |> normalize_lower(:action)
    |> validate_required([
      :uid,
      :company_uid,
      :principal_uid,
      :action,
      :resource,
      :risk_class,
      :issued_at,
      :issued_by_principal_uid
    ])
    |> validate_inclusion(:status, @canonical_statuses)
    |> validate_inclusion(:risk_class, @canonical_risk_classes)
    |> validate_length(:uid, min: 1, max: 255)
    |> validate_length(:action, min: 1, max: 255)
    |> validate_length(:resource, min: 1, max: 512)
    |> check_constraint(:uid, name: :capabilities_uid_present)
    |> check_constraint(:action, name: :capabilities_action_present)
    |> check_constraint(:resource, name: :capabilities_resource_present)
    |> check_constraint(:status, name: :capabilities_status_valid)
    |> check_constraint(:risk_class, name: :capabilities_risk_class_valid)
    |> check_constraint(:action, name: :capabilities_action_lowercase)
    |> unique_constraint(:uid, name: :capabilities_uid_index)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:principal_uid)
    |> foreign_key_constraint(:issued_by_principal_uid)
    |> foreign_key_constraint(:parent_capability_uid)
  end

  @doc """
  Returns the canonical status values accepted by the P2 schema.
  """
  @spec canonical_statuses() :: [atom()]
  def canonical_statuses, do: @canonical_statuses

  @doc """
  Returns the canonical risk class values accepted by the P2 schema.
  """
  @spec canonical_risk_classes() :: [String.t()]
  def canonical_risk_classes, do: @canonical_risk_classes
end