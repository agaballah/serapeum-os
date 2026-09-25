defmodule Ankole.WorkHierarchy.CrossCompanyConcurrencyTest do
  @moduledoc """
  P7 concurrency tests for cross-Company isolation.
  """

  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.TaskStore

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

  # ─── M.10: Cross-Company concurrent operations ─────────────────────────────

  describe "cross-Company concurrent operations" do
    test "concurrent mutations against separate Companies do not cross-leak" do
      owner_a = human_owner_fixture()
      owner_b = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_a.uid, owner_a.uid)
      end)

      {:ok, _membership_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_b.uid, owner_b.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company_a.uid, %{
          uid: "task-cross-company-a-001",
          creator_principal_uid: owner_a.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj A.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        TaskStore.create_task(repo, company_b.uid, %{
          uid: "task-cross-company-b-001",
          creator_principal_uid: owner_b.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj B.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      parent_pid = self()

      task_a_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.transition_task(repo, company_a.uid, task_a.uid, "READY", %{
              changed_by_uid: owner_a.uid
            })
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.transition_task(repo, company_b.uid, task_b.uid, "READY", %{
              changed_by_uid: owner_b.uid
            })
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 2

      refreshed_a = Repo.get!(Ankole.WorkHierarchy.Task, task_a.id)
      refreshed_b = Repo.get!(Ankole.WorkHierarchy.Task, task_b.id)

      assert refreshed_a.status == "READY"
      assert refreshed_b.status == "READY"

      assert refreshed_a.company_uid == company_a.uid
      assert refreshed_b.company_uid == company_b.uid
    end
  end
end
