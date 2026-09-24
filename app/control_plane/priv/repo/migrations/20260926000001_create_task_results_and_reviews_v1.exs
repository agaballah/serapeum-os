defmodule Ankole.Repo.Migrations.CreateTaskResultsAndReviewsV1 do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:task_results, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :result_uid, :text, null: false
      add :task_uid, :text, null: false
      add :workflow_run_id, :bigint, null: true
      add :workflow_agent_call_id, :bigint, null: true
      add :background_agent_job_id, :bigint, null: true
      add :background_agent_job_turn_id, :uuid, null: true
      add :execution_attempt_ref, :text, null: true
      add :executor_principal_uids, {:array, :text}, null: true
      add :result_metadata, :jsonb, null: true
      add :acceptance_state, :text, null: true
      add :failure_reason, :text, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:task_results, [:result_uid], name: :task_results_result_uid_index)
    create index(:task_results, [:task_uid], name: :task_results_task_uid_index)
    create index(:task_results, [:inserted_at], name: :task_results_inserted_at_index)

    alter table(:task_results) do
      modify :task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :workflow_run_id,
             references(:workflow_runs, column: :id, type: :bigint, on_delete: :restrict),
             null: true
      modify :workflow_agent_call_id,
             references(:workflow_agent_calls, column: :id, type: :bigint, on_delete: :restrict),
             null: true
      modify :background_agent_job_id,
             references(:background_agent_jobs, column: :id, type: :bigint, on_delete: :restrict),
             null: true
      modify :background_agent_job_turn_id,
             references(:background_agent_job_turns, column: :id, type: :uuid, on_delete: :restrict),
             null: true
    end

    create constraint(:task_results, :task_results_execution_reference_present,
      check: "workflow_run_id IS NOT NULL OR workflow_agent_call_id IS NOT NULL OR background_agent_job_id IS NOT NULL OR background_agent_job_turn_id IS NOT NULL OR btrim(execution_attempt_ref) <> ''"
    )

    create constraint(:task_results, :task_results_result_uid_present,
      check: "btrim(result_uid) <> ''"
    )

    create table(:review_records, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :review_uid, :text, null: false
      add :task_uid, :text, null: false
      add :reviewed_result_uid, :text, null: true
      add :reviewer_principal_uid, :text, null: false
      add :criteria_text, :text, null: false
      add :verdict, :text, null: false
      add :rationale_text, :text, null: false
      add :invalidated_at, :utc_datetime_usec, null: true
      add :invalidation_reason, :text, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:review_records, [:review_uid], name: :review_records_review_uid_index)
    create index(:review_records, [:reviewed_result_uid], name: :review_records_reviewed_result_uid_index)
    create index(:review_records, [:task_uid], name: :review_records_task_uid_index)
    create index(:review_records, [:inserted_at], name: :review_records_inserted_at_index)

    alter table(:review_records) do
      modify :task_uid,
             references(:tasks, column: :uid, type: :text, on_delete: :restrict),
             null: false
      modify :reviewed_result_uid,
             references(:task_results, column: :result_uid, type: :text, on_delete: :restrict),
             null: true
      modify :reviewer_principal_uid,
             references(:principals, column: :uid, type: :text, on_delete: :restrict),
             null: false
    end

    create constraint(:review_records, :review_records_verdict_valid,
      check: "verdict IN ('APPROVED', 'CHANGES_REQUIRED', 'REJECTED', 'INCONCLUSIVE')"
    )

    create constraint(:review_records, :review_records_invalidated_fields_coherent,
      check: "(invalidated_at IS NULL AND invalidation_reason IS NULL) OR (invalidated_at IS NOT NULL AND invalidation_reason IS NOT NULL)"
    )

    create constraint(:review_records, :review_records_review_uid_present,
      check: "btrim(review_uid) <> ''"
    )

    create table(:review_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :review_uid, :text, null: false
      add :event_type, :text, null: false
      add :reviewer_uid, :text, null: true
      add :metadata, :jsonb, null: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:review_events, [:review_uid], name: :review_events_review_uid_index)
    create index(:review_events, [:inserted_at], name: :review_events_inserted_at_index)

    alter table(:review_events) do
      modify :review_uid,
             references(:review_records, column: :review_uid, type: :text, on_delete: :delete_all),
             null: false
    end

    create constraint(:review_events, :review_events_event_type_valid,
      check: "event_type IN ('created', 'invalidated')"
    )
  end
end