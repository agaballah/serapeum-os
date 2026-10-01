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

  ## Field provenance

  A receipt field must represent a fact the system established. This module
  distinguishes three states so a reader is never misled by an absent value:

  - **Established.** `intent_action`, `intent_resource`, `risk_class`,
    `receipt_uid`, and `inserted_at` are derived by the system before the row
    is written.
  - **Established when present.** `capability_uid`, `approval_uid`,
    `principal_uid`, and `company_uid` are proved only when the caller
    supplied them and the corresponding validation passed. `nil` is a
    truthful statement that no such authority was presented.
  - **Not yet established.** `precondition_status`, `approval_independent`,
    `broker_name`, `postcondition_verified`, `verified_at`, `result_output`,
    and `execution_failed` describe an execution stage that does not exist in
    W3. They are nullable for exactly that reason, and `nil` means "not
    evaluated" rather than "passed".

  `precondition_status` and `approval_independent` were previously written as
  unconditional literals. Recording a fact nobody checked is worse than
  recording nothing, so both now default to `nil`.

  `postcondition_verified` is `nil` whenever no postcondition was declared.
  An empty `postcondition_expected` means the caller asserted no expected
  post-state, so there is nothing to prove and nothing to claim; it is never
  read as a vacuous success. `execution_failed` is `nil` because the
  finalization API receives no trustworthy execution outcome. Absence of
  verification is not evidence that execution succeeded or failed.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.W3.Approval
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
    # No default. The migration that made this column nullable also dropped the
    # database default, so an absent value stays NULL and truthfully reports
    # that no independence check ran. A `true` default here would fabricate the
    # fact on every insert that omitted the field.
    field :approval_independent, :boolean
    field :broker_name, :string
    field :postcondition_expected, :map, default: %{}
    field :postcondition_verified, :boolean
    field :verified_at, :utc_datetime_usec
    field :result_output, :map
    # No default. Execution failure is an observed fact about the action
    # itself, and the bounded finalization API receives no trustworthy
    # execution signal. A `false` default would claim every receipt's action
    # succeeded, which is exactly as fabricated as asserting `true`.
    field :execution_failed, :boolean

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

    # A receipt may name no Approval, but any Approval it does name must exist.
    belongs_to :approval, Approval,
      foreign_key: :approval_uid,
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
      :broker_name,
      :capability_uid,
      :postcondition_expected,
      :postcondition_verified,
      :verified_at,
      :result_output,
      :execution_failed
    ])
    # `precondition_status` and `approval_independent` are intentionally
    # absent: no precondition is evaluated and no independence check runs when
    # no Approval exists, so requiring them would force a fabricated fact.
    |> validate_required([
      :receipt_uid,
      :intent_action,
      :intent_resource,
      :principal_uid,
      :company_uid,
      :risk_class,
      :authz_decision
    ])
    |> validate_inclusion(:risk_class, @canonical_risk_classes)
    |> validate_inclusion(:authz_decision, @authz_decisions)
    |> validate_inclusion(:precondition_status, @precondition_statuses)
    |> unique_constraint(:receipt_uid, name: :action_receipts_receipt_uid_index)
    |> foreign_key_constraint(:principal_uid)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:capability_uid)
    |> foreign_key_constraint(:approval_uid, name: :action_receipts_approval_uid_fkey)
    |> check_constraint(:risk_class, name: :action_receipts_risk_class_valid)
    |> check_constraint(:authz_decision, name: :action_receipts_authz_decision_valid)
    |> check_constraint(:precondition_status, name: :action_receipts_precondition_valid)
  end
end