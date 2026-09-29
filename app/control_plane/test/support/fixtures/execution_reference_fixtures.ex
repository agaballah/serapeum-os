defmodule Ankole.ExecutionReferenceFixtures do
  @moduledoc """
  Test helpers that create real execution records for Task result provenance.

  A TaskResult must cite at least one real execution row, so tests that build
  a result need an actual workflow run, agent call, background agent job, or
  background agent job turn owned by an Agent.
  """

  alias Ankole.BackgroundAgentJobs.Schemas.Job
  alias Ankole.BackgroundAgentJobs.Schemas.Turn
  alias Ankole.Repo
  alias Ankole.Workflow.Schemas.AgentCall
  alias Ankole.Workflow.Schemas.Run

  def run_fixture(agent_uid) do
    suffix = unique_suffix()

    Repo.insert!(
      Run.creation_changeset(%Run{}, %{
        agent_uid: agent_uid,
        owner_session_id: "execution-ref-owner-#{suffix}",
        reply_route: %{"binding_name" => "bot"},
        source_tool_call_id: "execution-ref-tool-#{suffix}",
        title: "Execution reference run",
        script: "return 'done';",
        args: %{},
        status: "running",
        concurrency: 8,
        max_agent_calls: 256,
        error: %{}
      })
    )
  end

  def agent_call_fixture(%Run{} = run, agent_uid) do
    Repo.insert!(
      AgentCall.creation_changeset(%AgentCall{}, %{
        run_id: run.id,
        agent_uid: agent_uid,
        call_seq: 0,
        arguments: %{"prompt" => "Do the work."},
        status: "queued",
        attempts: 0,
        error: %{}
      })
    )
  end

  def job_fixture(agent_uid) do
    %{rows: [[id]]} =
      Repo.query!("SELECT nextval(pg_get_serial_sequence('background_agent_jobs', 'id'))")

    %Job{id: id}
    |> Job.creation_changeset(%{
      agent_uid: agent_uid,
      owner_session_id: "execution-ref-session-#{unique_suffix()}",
      source_tool_call_id: "execution-ref-#{id}",
      workspace_owner_job_id: id,
      status: "queued",
      title: "Execution reference job",
      task: "Do the work.",
      reply_route: %{"binding_name" => "lark"},
      metadata: %{},
      error: %{}
    })
    |> Repo.insert!()
  end

  def turn_fixture(%Job{} = job) do
    now = DateTime.utc_now(:microsecond)

    Repo.insert!(
      Turn.changeset(%Turn{}, %{
        job_id: job.id,
        attempt: 1,
        runtime_thread_id: "execution-ref-thread-#{job.id}",
        runtime_turn_id: "execution-ref-turn-#{job.id}-#{unique_suffix()}",
        kind: "agent",
        status: "completed",
        revision: 1,
        trajectory: %{"format" => "ankole_chatml", "version" => 1},
        started_at: now,
        completed_at: now
      })
    )
  end

  defp unique_suffix, do: Integer.to_string(System.unique_integer([:positive]))
end
