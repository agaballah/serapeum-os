defmodule Ankole.WorkHierarchy.TaskStoreDelegationTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.WorkHierarchy.DelegationEvent
  alias Ankole.WorkHierarchy.TaskChildPolicyHistory
  alias Ankole.WorkHierarchy.TaskStore

  @moduledoc """
  Tests for P5 Task delegation, child creation, dependencies, and child policy.
  """

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

  # ─── create_child_task ─────────────────────────────────────────────────────

  describe "create_child_task" do
    test "valid child task creation with atomic delegation record" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "parent-task-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build the thing.",
          scope_text: "Q3 2026.",
          required_outcome_text: "Shipped.",
          acceptance_criteria_text: "Passes QA.",
          child_completion_policy: "ALL_COMPLETED"
        })
      end)

      assert parent.status == "PROPOSED"
      assert parent.child_completion_policy == "ALL_COMPLETED"

      {:ok, child} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, parent.uid, %{
          uid: "child-task-001",
          creator_principal_uid: human.uid,
          objective_text: "Do the sub-work.",
          scope_text: "Week 1.",
          required_outcome_text: "Sub-outcome.",
          acceptance_criteria_text: "Verified."
        }, %{})
      end)

      assert child.status == "PROPOSED"
      assert child.parent_task_uid == parent.uid
      assert child.company_uid == company.uid
      assert child.child_completion_policy == "ALL_COMPLETED"
      assert child.origin_kind == "DELEGATION"

      # Reload child from DB to verify origin_reference persists
      refreshed = Repo.get(Ankole.WorkHierarchy.Task, child.id)
      refute is_nil(refreshed)
      assert refreshed.origin_kind == "DELEGATION"
      assert refreshed.origin_reference["delegation_uid"] != nil
      assert refreshed.origin_reference["source_task_uid"] == parent.uid
    end

    test "terminal parent is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "parent-terminal-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Complete the parent
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, parent.uid, "READY", %{changed_by_uid: human.uid})
      end)
      transact(fn repo ->
        TaskStore.assign_agent(repo, company.uid, parent.uid, agent.uid, human.uid)
      end)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, parent.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})
      end)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, parent.uid, "COMPLETED", %{changed_by_uid: human.uid})
      end)

      assert {:error, :parent_task_terminal} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, parent.uid, %{
          uid: "child-of-completed-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)
    end

    test "nonexistent parent is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:error, :parent_task_not_found} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, "nonexistent-parent", %{
          uid: "child-orphan-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)
    end

    test "cross-Company parent reference is rejected" do
      human = human_owner_fixture()
      owner_b = human_owner_fixture()
      company_a = company_fixture(human.uid)
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_a.uid, human.uid)
      end)

      {:ok, _membership_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_b.uid, owner_b.uid)
      end)

      {:ok, parent_b} = transact(fn repo ->
        TaskStore.create_task(repo, company_b.uid, %{
          uid: "parent-b-001",
          creator_principal_uid: owner_b.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :parent_task_not_found} = transact(fn repo ->
        TaskStore.create_child_task(repo, company_a.uid, parent_b.uid, %{
          uid: "cross-company-child-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)
    end

    test "child inherits parent's child_completion_policy by default" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "parent-policy-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit.",
          child_completion_policy: "INDEPENDENT"
        })
      end)

      {:ok, child} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, parent.uid, %{
          uid: "child-policy-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)

      assert child.child_completion_policy == "INDEPENDENT"
    end

    test "child does not inherit parent status" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "parent-status-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Transition parent to READY (in a separate transaction)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, parent.uid, "READY", %{changed_by_uid: human.uid})
      end)

      # Create child
      {:ok, child} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, parent.uid, %{
          uid: "child-status-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)

      # Child is PROPOSED regardless of parent status
      assert child.status == "PROPOSED"
    end

    test "duplicate delegation_uid is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "parent-dup-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, _child} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, parent.uid, %{
          uid: "child-dup-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        }, %{})
      end)

      # Same uid should fail on second attempt
      assert {:error, _} = transact(fn repo ->
        TaskStore.create_child_task(repo, company.uid, parent.uid, %{
          uid: "child-dup-001",
          creator_principal_uid: human.uid,
          objective_text: "Obj 2.",
          scope_text: "Scope 2.",
          required_outcome_text: "Out 2.",
          acceptance_criteria_text: "Crit 2."
        }, %{})
      end)
    end
  end

  # ─── set_dependency ─────────────────────────────────────────────────────────

  describe "set_dependency" do
    test "valid dependency creation" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "dep-task-a-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj A.",
          scope_text: "Scope A.",
          required_outcome_text: "Out A.",
          acceptance_criteria_text: "Crit A."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "dep-task-b-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj B.",
          scope_text: "Scope B.",
          required_outcome_text: "Out B.",
          acceptance_criteria_text: "Crit B."
        })
      end)

      assert {:ok, dep} = transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
      end)

      assert dep.task_uid == task_a.uid
      assert dep.depends_on_task_uid == task_b.uid
      assert dep.dependency_type == "REQUIRES_COMPLETION"
    end

    test "all three dependency types are accepted" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_x} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "dep-type-x-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_y} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "dep-type-y-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      Enum.each(~w(REQUIRES_COMPLETION REQUIRES_RESULT OPTIONAL)a, fn dtype ->
        {:ok, tx} = transact(fn repo ->
          TaskStore.create_task(repo, company.uid, %{
            uid: "dep-type-#{dtype}-tx-001",
            creator_principal_uid: human.uid,
            origin_kind: "OWNER_REQUEST",
            objective_text: "Obj.",
            scope_text: "Scope.",
            required_outcome_text: "Out.",
            acceptance_criteria_text: "Crit."
          })
        end)
        {:ok, ty} = transact(fn repo ->
          TaskStore.create_task(repo, company.uid, %{
            uid: "dep-type-#{dtype}-ty-001",
            creator_principal_uid: human.uid,
            origin_kind: "OWNER_REQUEST",
            objective_text: "Obj.",
            scope_text: "Scope.",
            required_outcome_text: "Out.",
            acceptance_criteria_text: "Crit."
          })
        end)
        assert {:ok, dep} = transact(fn repo ->
          TaskStore.set_dependency(repo, company.uid, tx.uid, ty.uid, Atom.to_string(dtype))
        end)
        assert dep.dependency_type == Atom.to_string(dtype)
      end)
    end

    test "self-dependency is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "self-dep-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :self_dependency_rejected} = transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task.uid, task.uid, "REQUIRES_COMPLETION")
      end)
    end

    test "cycle is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "cycle-a-001",
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
          uid: "cycle-b-001",
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
          uid: "cycle-c-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Create A depends on B, then B depends on C, then try C depends on A (cycle)
      transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
      end)
      transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task_b.uid, task_c.uid, "REQUIRES_COMPLETION")
      end)

      assert {:error, :dependency_cycle} = transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task_c.uid, task_a.uid, "REQUIRES_COMPLETION")
      end)
    end

    test "cross-Company dependency is rejected" do
      human = human_owner_fixture()
      owner_b = human_owner_fixture()
      company_a = company_fixture(human.uid)
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_a} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_a.uid, human.uid)
      end)
      {:ok, _membership_b} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company_b.uid, owner_b.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company_a.uid, %{
          uid: "crossdep-a-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      {:ok, task_b} = transact(fn repo ->
        TaskStore.create_task(repo, company_b.uid, %{
          uid: "crossdep-b-001",
          creator_principal_uid: owner_b.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        TaskStore.set_dependency(repo, company_a.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
      end)
    end

    test "nonexistent task is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "dep-miss-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :task_not_found} = transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task.uid, "nonexistent-task", "REQUIRES_COMPLETION")
      end)
    end
  end

  # ─── remove_dependency ──────────────────────────────────────────────────────

  describe "remove_dependency" do
    test "removes an existing dependency" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task_a} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "rmd-a-001",
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
          uid: "rmd-b-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      transact(fn repo ->
        TaskStore.set_dependency(repo, company.uid, task_a.uid, task_b.uid, "REQUIRES_COMPLETION")
      end)

      assert {:ok, :deleted} = transact(fn repo ->
        TaskStore.remove_dependency(repo, company.uid, task_a.uid, task_b.uid)
      end)
    end

    test "removing nonexistent dependency returns error" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "rmd-miss-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :dependency_not_found} = transact(fn repo ->
        TaskStore.remove_dependency(repo, company.uid, task.uid, "nonexistent-task")
      end)
    end
  end

  # ─── set_child_policy ────────────────────────────────────────────────────────

  describe "set_child_policy" do
    test "valid policy mutation creates history row" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "policy-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert task.child_completion_policy == "ALL_COMPLETED"

      assert {:ok, updated_task} = transact(fn repo ->
        TaskStore.set_child_policy(repo, company.uid, task.uid, "INDEPENDENT", human.uid)
      end)

      assert updated_task.child_completion_policy == "INDEPENDENT"

      history = Repo.all(from h in TaskChildPolicyHistory, where: h.task_uid == ^task.uid, order_by: [asc: h.id])
      assert length(history) == 1
      assert hd(history).old_policy == "ALL_COMPLETED"
      assert hd(history).new_policy == "INDEPENDENT"
      assert hd(history).changed_by_uid == human.uid
    end

    test "invalid policy is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "policy-invalid-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, {:invalid_child_policy, "BAD_POLICY"}} = transact(fn repo ->
        TaskStore.set_child_policy(repo, company.uid, task.uid, "BAD_POLICY", human.uid)
      end)
    end

    test "terminal task cannot have its policy changed" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "policy-terminal-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      # Transition through proper lifecycle to COMPLETED
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, task.uid, "READY", %{changed_by_uid: human.uid})
      end)
      transact(fn repo ->
        TaskStore.assign_agent(repo, company.uid, task.uid, agent.uid, human.uid)
      end)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, task.uid, "IN_PROGRESS", %{changed_by_uid: human.uid})
      end)
      transact(fn repo ->
        TaskStore.transition_task(repo, company.uid, task.uid, "COMPLETED", %{changed_by_uid: human.uid})
      end)

      assert {:error, {:terminal_state, "COMPLETED"}} = transact(fn repo ->
        TaskStore.set_child_policy(repo, company.uid, task.uid, "INDEPENDENT", human.uid)
      end)
    end

    test "history is append-only with multiple mutations" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "policy-multi-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      transact(fn repo ->
        TaskStore.set_child_policy(repo, company.uid, task.uid, "INDEPENDENT", human.uid)
      end)

      transact(fn repo ->
        TaskStore.set_child_policy(repo, company.uid, task.uid, "ALL_COMPLETED", human.uid)
      end)

      history = Repo.all(from h in TaskChildPolicyHistory, where: h.task_uid == ^task.uid, order_by: [asc: h.id])
      assert length(history) == 2
      assert Enum.at(history, 0).old_policy == "ALL_COMPLETED"
      assert Enum.at(history, 0).new_policy == "INDEPENDENT"
      assert Enum.at(history, 1).old_policy == "INDEPENDENT"
      assert Enum.at(history, 1).new_policy == "ALL_COMPLETED"
    end
  end

  # ─── create_delegation ──────────────────────────────────────────────────────

  describe "create_delegation" do
    test "valid delegation creation with event" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, source_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "del-source-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:ok, delegation} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, source_task.uid, human.uid, nil, %{
          scope_description: "Delegate sub-task to agent."
        })
      end)

      assert delegation.scope_description == "Delegate sub-task to agent."
      assert delegation.delegator_principal_uid == human.uid
      assert delegation.source_task_uid == source_task.uid
      assert delegation.delegatee_principal_uid == nil

      events = Repo.all(from e in DelegationEvent, where: e.delegation_uid == ^delegation.delegation_uid)
      assert length(events) == 1
      assert hd(events).event_type == "created"
    end

    test "delegatee may be set at creation time" do
      human = human_owner_fixture()
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership_human} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)
      transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
      end)

      {:ok, source_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "del-agent-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:ok, delegation} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, source_task.uid, human.uid, agent.uid, %{
          scope_description: "Assign to agent."
        })
      end)

      assert delegation.delegatee_principal_uid == agent.uid
    end

    test "blank scope_description is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, source_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "del-blank-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :scope_description_blank} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, source_task.uid, human.uid, nil, %{
          scope_description: "   "
        })
      end)
    end

    test "missing scope_description is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, source_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "del-noscope-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :scope_description_required} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, source_task.uid, human.uid, nil, %{})
      end)
    end

    test "system principal cannot delegate" do
      system = PrincipalsFixtures.system_fixture()
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, source_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "del-system-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, :system_principal_not_allowed_as_delegator} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, source_task.uid, system.uid, nil, %{
          scope_description: "System delegation."
        })
      end)
    end

    test "nonexistent source task is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:error, :source_task_not_found} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, "nonexistent-task", human.uid, nil, %{
          scope_description: "Delegate."
        })
      end)
    end

    test "inactive delegator is rejected" do
      %{principal: disabled} = PrincipalsFixtures.human_fixture()
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      # Disable the fixture human
      disabled
      |> Ankole.Principals.Principal.changeset(%{status: :disabled})
      |> Repo.update() |> elem(1)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, source_task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "del-inactive-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert {:error, {:creator_not_active, :disabled}} = transact(fn repo ->
        TaskStore.create_delegation(repo, company.uid, source_task.uid, disabled.uid, nil, %{
          scope_description: "Inactive delegation."
        })
      end)
    end
  end

  # ─── read-only helpers ──────────────────────────────────────────────────────

  describe "list_dependencies" do
    test "returns empty list when no dependencies exist" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "lod-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert TaskStore.list_dependencies(Repo, task.uid) == []
    end
  end

  describe "list_children" do
    test "returns empty list when no children exist" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      {:ok, parent} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "loc-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Obj.",
          scope_text: "Scope.",
          required_outcome_text: "Out.",
          acceptance_criteria_text: "Crit."
        })
      end)

      assert TaskStore.list_children(Repo, parent.uid) == []
    end
  end

  describe "fetch_delegation" do
    test "miss returns nil" do
      assert TaskStore.fetch_delegation(Repo, "nonexistent-delegation") == nil
    end
  end

  # ─── W1 / P3 / P4 regression ────────────────────────────────────────────────

  describe "P3 behavior preserved" do
    test "Task creation still works without P5 changes" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
      end)

      assert {:ok, task} = transact(fn repo ->
        TaskStore.create_task(repo, company.uid, %{
          uid: "reg-p3-001",
          creator_principal_uid: human.uid,
          origin_kind: "OWNER_REQUEST",
          objective_text: "Build it.",
          scope_text: "Scope.",
          required_outcome_text: "Outcome.",
          acceptance_criteria_text: "Criteria."
        })
      end)

      assert task.uid == "reg-p3-001"
      assert task.status == "PROPOSED"
    end
  end
end
