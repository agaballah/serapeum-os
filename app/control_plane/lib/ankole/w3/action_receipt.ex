defmodule Ankole.W3.ActionReceipt do
  @moduledoc """
  Durable receipt record for an Action Assurance decision.

  Per MA-06 §28, every consequential action produces a receipt sufficient
  to answer who requested it, which Principal was accountable, what exact
  action was authorized, whether verification succeeded, and what output
  occurred.

  This is the minimal P5 persistence contract. It records the assurance
  decision outcome without storing broker implementation details (P7) or
  approval workflow internals (P6).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.W3.Capability

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @authz_decisions ~w(ALLOW DENY)
  @precondition_statuses ~w(met not_met)
  @canonical_risk_classes ~w(ROUTINE CONTROLLED HIGH-IMPACT PROHIBITED)

  schema "action_receipts" do
    field :receipt_uid, :string
    field :intent_action, :string
    field :intent_resource, :string
    field :risk_class, :string
    field :authz_decision, :string
    field :precondition_status, :string
    field :approval_uid, :string
    field :approval_independent, :boolean, default: true
    field :postcondition_expected, :map, default: %{}
    field :postcondition_verified, :boolean
    field :verified_at, :utc_datetime_usec
    field :result_output, :map
    field :execution_failed, :boolean, default: false

    belongs_to :principal, Principal,
      foreign_key: :principal_uid,
      references: :uid,
      type: :string

    belongs_to :company, Company,
      foreign_key: :company_uid,
      references: :uid,
      type: :string

    belongs_to :capability, Capability,
      foreign_key: :capability_uid,
      references: :uid,
      type: :string

    timestamps()
  end

  @doc """
  Builds a changeset for action receipt rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(receipt, attrs) do
    receipt
    |> cast(attrs, [
      :receipt_uid,
      :intent_action,
      :intent_resource,
      :principal_uid,
      :company_uid,
      :risk_class,
      :authz_decision,
      :precondition_status,
      :approval_uid,
      :approval_independent,
      :capability_uid,
      :postcondition_expected,
      :postcondition_verified,
      :verified_at,
      :result_output,
      :execution_failed
    ])
    |> validate_required([
      :receipt_uid,
      :intent_action,
      :intent_resource,
      :principal_uid,
      :company_uid,
      :risk_class,
      :authz_decision,
      :precondition_status,
      :approval_independent
    ])
    |> validate_inclusion(:risk_class, @canonical_risk_classes)
    |> validate_inclusion(:authz_decision, @authz_decisions)
    |> validate_inclusion(:precondition_status, @precondition_statuses)
    |> unique_constraint(:receipt_uid, name: :action_receipts_receipt_uid_index)
    |> foreign_key_constraint(:principal_uid)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:capability_uid)
    |> check_constraint(:risk_class, name: :action_receipts_risk_class_valid)
    |> check_constraint(:authz_decision, name: :action_receipts_authz_decision_valid)
    |> check_constraint(:precondition_status, name: :action_receipts_precondition_valid)
  end
end