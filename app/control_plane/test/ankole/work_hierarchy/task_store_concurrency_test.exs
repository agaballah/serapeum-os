defmodule Ankole.WorkHierarchy.TaskStoreConcurrencyTest do
  @moduledoc """
  P7 concurrency tests for W2 task mutations.
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

  defp agent_fixture do
    %{principal: principal} = PrincipalsFixtures.agent_fixture()
    principal
  end

  # ─── M.1: Concurrent lifecycle transitions ────────────────────────────────

  describe "concurrent lifecycle transitions" do
    test "two concurrent READY -> ASSIGNED attempts serialize on Task FOR UPDATE" do
      human = human_owner_fixture()
      agent = agent_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-lifecycle-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _ready} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{
        changed_by_uid: human.uid
      })

      parent = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          Repo.transact(fn repo ->
            TaskStore.assign_agent(repo, company.uid, task.uid, agent.uid, human.uid)
          end)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          Repo.transact(fn repo ->
            TaskStore.assign_agent(repo, company.uid, task.uid, agent.uid, human.uid)
          end)
        end)

      results = [Task.await(task_a, 10_000), Task.await(task_b, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1

      refreshed = Repo.get!(Ankole.WorkHierarchy.Task, task.id)
      assert refreshed.status == "ASSIGNED"
      assert refreshed.accountable_agent_uid == agent.uid
    end
  end

  # ─── M.2: Concurrent assignment ────────────────────────────────────────────

  describe "concurrent assignment" do
    test "two concurrent ASSIGNED attempts with different agents serialize" do
      human = human_owner_fixture()
      agent_a = agent_fixture()
      agent_b = agent_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent_a.uid)
      end)
      {:ok, _membership_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent_b.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-assign-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _ready} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{
        changed_by_uid: human.uid
      })

      parent = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          Repo.transact(fn repo ->
            TaskStore.assign_agent(repo, company.uid, task.uid, agent_a.uid, human.uid)
          end)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          Repo.transact(fn repo ->
            TaskStore.assign_agent(repo, company.uid, task.uid, agent_b.uid, human.uid)
          end)
        end)

      results = [Task.await(task_a, 10_000), Task.await(task_b, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1

      refreshed = Repo.get!(Ankole.WorkHierarchy.Task, task.id)
      assert refreshed.status == "ASSIGNED"
    end
  end

  # ─── M.3: Concurrent child-task creation ───────────────────────────────────

  describe "concurrent child-task creation" do
    test "two children created under the same non-terminal parent" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-child-parent-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      parent_pid = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.create_child_task(repo, company.uid, parent.uid, %{
              uid: "task-concurrent-child-a-001",
              creator_principal_uid: human.uid,
              objective_text: "Child A.",
              scope_text: "Scope.",
              required_outcome_text: "Out.",
              acceptance_criteria_text: "Crit."
            }, %{})
          end)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.create_child_task(repo, company.uid, parent.uid, %{
              uid: "task-concurrent-child-b-001",
              creator_principal_uid: human.uid,
              objective_text: "Child B.",
              scope_text: "Scope.",
              required_outcome_text: "Out.",
              acceptance_criteria_text: "Crit."
            }, %{})
          end)
        end)

      results = [Task.await(task_a, 10_000), Task.await(task_b, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 2

      refreshed_parent = Repo.get!(Ankole.WorkHierarchy.Task, parent.id)
      assert refreshed_parent.status in ["PROPOSED", "READY"]
    end
  end

  # ─── M.4: Concurrent dependency creation ───────────────────────────────────

  describe "concurrent dependency creation" do
    test "two valid dependency edges are inserted atomically" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-dep-a-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-dep-b-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_c} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-dep-c-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
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
            TaskStore.set_dependency(repo, company.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.set_dependency(repo, company.uid, task_b.uid, task_c.uid, "REQUIRES_COMPLETION")
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 2
    end
  end

  # ─── M.5: Concurrent dependency cycle attempts ─────────────────────────────

  describe "concurrent dependency cycle attempts" do
    test "mutually cycle-forming edges do not both commit" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-cycle-a-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-concurrent-cycle-b-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
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
            TaskStore.set_dependency(repo, company.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.set_dependency(repo, company.uid, task_b.uid, task_a.uid, "REQUIRES_COMPLETION")
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000)]

      cycle_count =
        results
        |> Enum.count(fn
          {:ok, _} -> true
          _ -> false
        end)

      assert cycle_count <= 1

      all_deps = Repo.all(Ankole.WorkHierarchy.TaskDependency)
      assert length(all_deps) == cycle_count
    end

    test "longer cycle A->B->C->A does not commit" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-long-cycle-a-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-long-cycle-b-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_c} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-long-cycle-c-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
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
            TaskStore.set_dependency(repo, company.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
          end)
        end)

      task_b_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.set_dependency(repo, company.uid, task_b.uid, task_c.uid, "REQUIRES_COMPLETION")
          end)
        end)

      task_c_fut =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())

          Repo.transact(fn repo ->
            TaskStore.set_dependency(repo, company.uid, task_c.uid, task_a.uid, "REQUIRES_COMPLETION")
          end)
        end)

      results = [Task.await(task_a_fut, 10_000), Task.await(task_b_fut, 10_000), Task.await(task_c_fut, 10_000)]

      cycle_count =
        results
        |> Enum.count(fn
          {:ok, _} -> true
          _ -> false
        end)

      assert cycle_count <= 2

      all_deps = Repo.all(Ankole.WorkHierarchy.TaskDependency)
      assert length(all_deps) == cycle_count

      # Verify no cycle exists in final state
      assert no_cycle_exists?(Repo, all_deps)
    end
  end

  defp no_cycle_exists?(_repo, deps) do
    # Build adjacency list
    adj = Enum.reduce(deps, %{}, fn dep, acc ->
      Map.update(acc, dep.task_uid, [dep.depends_on_task_uid], &[dep.depends_on_task_uid | &1])
    end)

    # DFS cycle detection
    all_nodes = deps |> Enum.map(& &1.task_uid) |> Enum.uniq()

    # Check each node for cycles
    Enum.all?(all_nodes, fn start_node ->
      visited = MapSet.new()
      rec_stack = MapSet.new()
      not has_cycle_from?(adj, start_node, visited, rec_stack)
    end)
  end

  defp has_cycle_from?(adj, node, visited, rec_stack) do
    cond do
      MapSet.member?(rec_stack, node) -> true
      MapSet.member?(visited, node) -> false
      true ->
        new_rec_stack = MapSet.put(rec_stack, node)
        neighbors = Map.get(adj, node, [])
        Enum.any?(neighbors, &has_cycle_from?(adj, &1, visited, new_rec_stack))
    end
  end

  # ─── M.13: Optimistic concurrency with version ─────────────────────────────

  describe "optimistic concurrency" do
    test "version increments on each successful mutation" do
      human = human_owner_fixture()
      agent = agent_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_h} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "task-optimistic-concurrency-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Ecto's optimistic_lock increments version on insert (from 1 to 2)
      assert task.version == 2

      {:ok, task} = TaskStore.transition_task(Repo, company.uid, task.uid, "READY", %{
        changed_by_uid: human.uid
      })
      assert task.version == 3

      {:ok, task} = TaskStore.assign_agent(Repo, company.uid, task.uid, agent.uid, human.uid)
      assert task.version == 4
    end
  end
end
