defmodule Ankole.WorkHierarchy.Task do
  @moduledoc """
  Durable work item scoped to exactly one Company.

  A Task is the third level of the SerapeumOS work hierarchy, below Mission.
  It carries a stable caller-supplied identity, mandatory Company scope, origin
  lineage, and accountability structure. Lifecycle transition execution is
  handled by later packages; this schema owns only identity and data structure.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Goal
  alias Ankole.WorkHierarchy.Mission

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  @canonical_status_values ~w(PROPOSED READY ASSIGNED IN_PROGRESS WAITING REVIEW COMPLETED FAILED CANCELLED)
  @canonical_origin_kinds ~w(OWNER_REQUEST COMPANY_GOAL MISSION DELEGATION WORKFLOW SYSTEM_EVOLUTION EXTERNAL_EVENT)
  @canonical_completion_policies ~w(ALL_COMPLETED INDEPENDENT)

  schema "tasks" do
    field :uid, :string
    field :version, :integer
    field :origin_kind, :string
    field :origin_reference, :map
    field :status, :string
    field :objective_text, :string
    field :scope_text, :string
    field :required_outcome_text, :string
    field :acceptance_criteria_text, :string
    field :child_completion_policy, :string, default: "ALL_COMPLETED"
    field :cancelled_at, :utc_datetime_usec
    field :cancellation_reason, :string
    field :failure_reason, :string

    belongs_to :company, Company,
      foreign_key: :company_uid,
      references: :uid,
      type: :string

    belongs_to :mission, Mission,
      foreign_key: :mission_uid,
      references: :uid,
      type: :string

    belongs_to :goal, Goal,
      foreign_key: :goal_uid,
      references: :uid,
      type: :string

    belongs_to :parent_task, __MODULE__,
      foreign_key: :parent_task_uid,
      references: :uid,
      type: :string

    belongs_to :accountable_agent, Principal,
      foreign_key: :accountable_agent_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :creator, Principal,
      foreign_key: :creator_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :cancelled_by, Principal,
      foreign_key: :cancelled_by_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for Task rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :uid,
      :company_uid,
      :mission_uid,
      :goal_uid,
      :parent_task_uid,
      :accountable_agent_uid,
      :creator_principal_uid,
      :origin_kind,
      :origin_reference,
      :status,
      :objective_text,
      :scope_text,
      :required_outcome_text,
      :acceptance_criteria_text,
      :child_completion_policy,
      :cancelled_at,
      :cancelled_by_uid,
      :cancellation_reason,
      :failure_reason,
      :version
    ])
    |> normalize_blank([:uid])
    |> validate_required([:uid, :company_uid, :creator_principal_uid, :origin_kind, :status,
                          :objective_text, :scope_text, :required_outcome_text, :acceptance_criteria_text])
    |> check_constraint(:uid, name: :tasks_uid_present)
    |> validate_inclusion(:origin_kind, @canonical_origin_kinds)
    |> validate_inclusion(:status, @canonical_status_values)
    |> validate_inclusion(:child_completion_policy, @canonical_completion_policies)
    |> validate_cancelled_fields_coherence()
    |> unique_constraint(:uid, name: :tasks_uid_index)
    |> foreign_key_constraint(:company_uid)
    |> foreign_key_constraint(:mission_uid)
    |> foreign_key_constraint(:goal_uid)
    |> foreign_key_constraint(:parent_task_uid)
    |> foreign_key_constraint(:accountable_agent_uid)
    |> foreign_key_constraint(:creator_principal_uid)
    |> foreign_key_constraint(:cancelled_by_uid)
    |> optimistic_lock(:version)
  end

  defp validate_cancelled_fields_coherence(changeset) do
    cancelled_at = get_field(changeset, :cancelled_at)
    cancelled_by = get_field(changeset, :cancelled_by_uid)
    cancellation_reason = get_field(changeset, :cancellation_reason)

    all_nil = is_nil(cancelled_at) and is_nil(cancelled_by) and is_nil(cancellation_reason)
    all_present = not is_nil(cancelled_at) and not is_nil(cancelled_by) and not is_nil(cancellation_reason)

    if all_nil or all_present do
      changeset
    else
      add_error(changeset, :cancellation_reason, "must be present when cancelled_at and cancelled_by_uid are present, and absent otherwise")
    end
  end
end
