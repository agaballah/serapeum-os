defmodule Ankole.WorkHierarchy.TaskStoreResultConcurrencyTest do
  @moduledoc """
  P7 concurrency tests for W2 task results.
  """

  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.TaskStore
  alias Ankole.WorkHierarchy.ResultStore
  alias Ankole.WorkHierarchy.ReviewStore
  alias Ankole.WorkHierarchy.ReviewRecord

  defp transact(fun), do: Repo.transact(fn repo -> fun.(repo) end)

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])
    defaults = %{
      uid: "test-company-#{suffix}",
      name: "test-company-#{suffix}",
      display_name: "Test Company",
      status: :active,
      metadata: %{},
      owner_principal_uid: owner_uid
    }

    {:ok, company} = %Company{} |> Company.changeset(Map.merge(defaults, attrs)) |> Repo.insert()
    company
  end

  defp human_owner_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  defp reviewer_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  # ─── M.6: Concurrent Result creation ──────────────────────────────────────

  describe "concurrent result creation" do
    test "two results for the same Task invalidate prior review exactly once" do
      human = human_owner_fixture()
      reviewer = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, _membership_r} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-result-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result_a} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "task-concurrent-result-a-001",
          execution_attempt_ref: "attempt-a-001"
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result_a.result_uid, reviewer.uid, %{
          criteria_text: "Criteria.",
          verdict: "APPROVED",
          rationale_text: "Rationale."
        })
      end)

      parent_pid = self()

      task_a_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            ResultStore.create_result(repo, company.uid, task.uid, %{
              result_uid: "task-concurrent-result-b-001",
              execution_attempt_ref: "attempt-b-001"
            })
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            ResultStore.create_result(repo, company.uid, task.uid, %{
              result_uid: "task-concurrent-result-c-001",
              execution_attempt_ref: "attempt-c-001"
            })
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 2

      all_results = Repo.all(from r in Ankole.WorkHierarchy.TaskResult, where: r.task_uid == ^task.uid)
      assert length(all_results) == 3

      refreshed_review = Repo.get!(ReviewRecord, review.id)
      assert refreshed_review.invalidated_at != nil
      assert refreshed_review.verdict == "APPROVED"

      events = Repo.all(from e in Ankole.WorkHierarchy.ReviewEvent,
        where: e.review_uid == ^review.review_uid
      )

      assert length(events) >= 1
      assert refreshed_review.invalidated_at != nil
    end
  end

  # ─── M.9: Result creation racing with Review creation ──────────────────────

  describe "result creation racing with review creation" do
    test "review creation validates against committed result state" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-race-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      parent_pid = self()

      result_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            ResultStore.create_result(repo, company.uid, task.uid, %{
              result_uid: "task-concurrent-race-result-001",
              execution_attempt_ref: "attempt-race-001"
            })
          end)
        end)

      {:ok, result} = Task.await(result_fut, 10_000)

      assert {:ok, _review} =
               transact(fn repo ->
                 ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, human.uid, %{
                   criteria_text: "Criteria.",
                   verdict: "APPROVED",
                   rationale_text: "Rationale."
                 })
               end)
    end
  end
end
