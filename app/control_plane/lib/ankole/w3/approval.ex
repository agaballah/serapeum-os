defmodule Ankole.W3.Approval do
  @moduledoc """
  Durable approval record for Action Assurance.

  Per MA-06 §18, approval is explicit consent for a particular governed
  action. It binds to exact normalized parameters to prevent
  "approve one thing, execute another." It is distinct from W2 review
  verdicts (MA-04), which evaluate work quality rather than authorize
  execution.

  P6 enforces independence: the approver must not be the requester
  (MA-06 §20). It enforces Company scoping and tracks expiry/revocation.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.W3.Capability

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @statuses ~w(requested pending approved rejected expired revoked)
  @canonical_risk_classes ~w(ROUTINE CONTROLLED HIGH-IMPACT PROHIBITED)

  schema "approvals" do
    field :uid, :string
    field :action, :string
    field :resource, :string
    field :task_uid, :string
    field :risk_class, :string
    field :status, :string
    field :reason, :string
    field :approved_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    belongs_to :company, Company,
      foreign_key: :company_uid,
      references: :uid,
      type: :string

    belongs_to :requester, Principal,
      foreign_key: :requester_uid,
      references: :uid,
      type: :string

    belongs_to :approver, Principal,
      foreign_key: :approver_uid,
      references: :uid,
      type: :string

    belongs_to :capability, Capability,
      foreign_key: :capability_uid,
      references: :uid,
      type: :string

    timestamps()
  end

  @doc """
  Builds a changeset for approval rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(approval, attrs) do
    approval
    |> cast(attrs, [
      :uid,
      :company_uid,
      :requester_uid,
      :approver_uid,
      :action,
      :resource,
      :capability_uid,
      :task_uid,
      :risk_class,
      :status,
      :reason,
      :approved_at,
      :expires_at,
      :revoked_at,
      :metadata
    ])
    |> normalize_blank([:uid, :action, :resource, :risk_class])
    |> validate_required([
      :uid,
      :company_uid,
      :requester_uid,
      :action,
      :resource,
      :risk_class
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:risk_class, @canonical_risk_classes)
    |> validate_length(:uid, min: 1, max: 255)
    |> validate_length(:action, min: 1, max: 255)
    |> validate_length(:resource, min: 1, max: 512)
    |> check_constraint(:uid, name: :approvals_uid_present)
    |> check_constraint(:action, name: :approvals_action_present)
    |> check_constraint(:resource, name: :approvals_resource_present)
    |> check_constraint(:risk_class, name: :approvals_risk_class_valid)
    |> check_constraint(:status, name: :approvals_status_valid)
    |> check_constraint(:approved_at, name: :approvals_approved_coherent)
    |> check_constraint(:revoked_at, name: :approvals_revocation_coherent)
    |> unique_constraint(:uid, name: :approvals_uid_index)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:requester_uid)
    |> foreign_key_constraint(:approver_uid)
    |> foreign_key_constraint(:capability_uid)
  end
end