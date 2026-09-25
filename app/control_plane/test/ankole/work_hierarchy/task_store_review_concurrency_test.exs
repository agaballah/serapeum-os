defmodule Ankole.WorkHierarchy.TaskStoreReviewConcurrencyTest do
  @moduledoc """
  P7 concurrency tests for W2 task reviews.
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

  # ─── M.7: Concurrent Review creation ──────────────────────────────────────

  describe "concurrent review creation" do
    test "two independent reviews against the same Result are both accepted" do
      human = human_owner_fixture()
      reviewer_a = reviewer_fixture()
      reviewer_b = reviewer_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer_a.uid)
      end)
      {:ok, _membership_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, reviewer_b.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-review-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "task-concurrent-review-result-001",
          execution_attempt_ref: "attempt-review-001"
        })
      end)

      parent_pid = self()

      task_a_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer_a.uid, %{
              criteria_text: "Criteria A.",
              verdict: "APPROVED",
              rationale_text: "Rationale A."
            })
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer_b.uid, %{
              criteria_text: "Criteria B.",
              verdict: "REJECTED",
              rationale_text: "Rationale B."
            })
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 2

      all_reviews = Repo.all(from r in ReviewRecord, where: r.reviewed_result_uid == ^result.result_uid)
      assert length(all_reviews) == 2
    end
  end

  # ─── M.8: Concurrent Review invalidation ───────────────────────────────────

  describe "concurrent review invalidation" do
    test "two concurrent invalidations of the same Review: second is rejected" do
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
          uid: "task-concurrent-inv-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, result} = transact(fn repo ->
        ResultStore.create_result(repo, company.uid, task.uid, %{
          result_uid: "task-concurrent-inv-result-001",
          execution_attempt_ref: "attempt-inv-001"
        })
      end)

      {:ok, review} = transact(fn repo ->
        ReviewStore.create_review(repo, company.uid, task.uid, result.result_uid, reviewer.uid, %{
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
            ReviewStore.invalidate_review(repo, company.uid, review.review_uid, "first")
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            ReviewStore.invalidate_review(repo, company.uid, review.review_uid, "second")
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.any?(results, &match?({:error, :review_already_invalidated}, &1))

      refreshed = Repo.get!(ReviewRecord, review.id)
      assert refreshed.invalidated_at != nil
      assert refreshed.invalidation_reason == "first"
    end
  end
end
