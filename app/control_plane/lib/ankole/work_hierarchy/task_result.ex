defmodule Ankole.WorkHierarchy.TaskResult do
  @moduledoc """
  Durable Task result scoped to exactly one Company.

  A TaskResult is an append-only record of one execution attempt against a
  Task. It carries stable caller identity, the execution context that produced
  it, the Principals who materially executed, and structured metadata. It does
  not own artifact bytes (MA-09) or the full evidence payload (MA-05).

  Multiple results per Task are permitted. A result is immutable after commit;
  it is never revised. A later attempt produces a new result row.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.WorkHierarchy.Task

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "task_results" do
    field :result_uid, :string
    field :execution_attempt_ref, :string
    field :executor_principal_uids, {:array, Ankole.Ecto.PrincipalKey}
    field :result_metadata, :map
    field :acceptance_state, :string
    field :failure_reason, :string

    belongs_to :task, Task,
      foreign_key: :task_uid,
      references: :uid,
      type: :string

    belongs_to :workflow_run, Ankole.Workflow.Schemas.Run,
      foreign_key: :workflow_run_id,
      references: :id,
      type: :id

    belongs_to :workflow_agent_call, Ankole.Workflow.Schemas.AgentCall,
      foreign_key: :workflow_agent_call_id,
      references: :id,
      type: :id

    belongs_to :background_agent_job, Ankole.BackgroundAgentJobs.Schemas.Job,
      foreign_key: :background_agent_job_id,
      references: :id,
      type: :id

    belongs_to :background_agent_job_turn, Ankole.BackgroundAgentJobs.Schemas.Turn,
      foreign_key: :background_agent_job_turn_id,
      references: :id,
      type: Ankole.Ecto.UUIDv7

    timestamps()
  end

  @doc """
  Builds a changeset for TaskResult rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :result_uid,
      :task_uid,
      :workflow_run_id,
      :workflow_agent_call_id,
      :background_agent_job_id,
      :background_agent_job_turn_id,
      :execution_attempt_ref,
      :executor_principal_uids,
      :result_metadata,
      :acceptance_state,
      :failure_reason
    ])
    |> normalize_blank([:result_uid, :execution_attempt_ref, :acceptance_state, :failure_reason])
    |> validate_required([:result_uid, :task_uid])
    |> check_constraint(:result_uid, name: :task_results_result_uid_present)
    |> unique_constraint(:result_uid, name: :task_results_result_uid_index)
    |> foreign_key_constraint(:task_uid)
    |> foreign_key_constraint(:workflow_run_id)
    |> foreign_key_constraint(:workflow_agent_call_id)
    |> foreign_key_constraint(:background_agent_job_id)
    |> foreign_key_constraint(:background_agent_job_turn_id)
    |> validate_execution_reference()
  end

  defp validate_execution_reference(changeset) do
    refs = [
      get_field(changeset, :workflow_run_id),
      get_field(changeset, :workflow_agent_call_id),
      get_field(changeset, :background_agent_job_id),
      get_field(changeset, :background_agent_job_turn_id),
      get_field(changeset, :execution_attempt_ref)
    ]

    if Enum.all?(refs, &is_nil/1) do
      add_error(changeset, :execution_reference, "at least one execution reference is required")
    else
      changeset
    end
  end
end