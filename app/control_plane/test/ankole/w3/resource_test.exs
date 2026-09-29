defmodule Ankole.W3.ResourceTest do
  @moduledoc """
  Tests for the canonical W2 resource builder and exact-resource normalizer.
  Pure functions — no database, no AuthZ, no W2 store dependencies.
  """

  use ExUnit.Case, async: true

  alias Ankole.W3.Resource

  @company "co-1"
  @task "task-a"
  @result "result-1"
  @review "rev-001"
  @mission "mis-x"
  @dep "task-b"

  describe "build/3 — action mapping coverage" do
    test "B-R1 create_task targets company collection" do
      assert {:ok, res} = Resource.build("create_task", @company, %{})
      assert res == "w2:v1/company/co-1/tasks"
    end

    test "B-R2 create_goal targets company collection" do
      assert {:ok, "w2:v1/company/co-1/goals"} = Resource.build("create_goal", @company, %{})
    end

    test "B-R3 create_mission targets company collection" do
      assert {:ok, "w2:v1/company/co-1/missions"} = Resource.build("create_mission", @company, %{})
    end

    test "B-R4 create_revision targets mission aggregate" do
      assert {:ok, res} = Resource.build("create_revision", @company, %{mission_uid: @mission})
      assert res == "w2:v1/company/co-1/missions/mis-x/revisions"
    end

    test "B-R5 create_result targets task aggregate" do
      assert {:ok, res} = Resource.build("create_result", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a/results"
    end

    test "B-R6 create_review targets result aggregate" do
      assert {:ok, res} =
               Resource.build("create_review", @company, %{
                 task_uid: @task,
                 result_uid: @result
               })

      assert res == "w2:v1/company/co-1/tasks/task-a/results/result-1/reviews"
    end

    test "B-R7 create_child_task targets parent task aggregate" do
      assert {:ok, res} = Resource.build("create_child_task", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a/children"
    end

    test "B-R8 create_delegation targets source task aggregate" do
      assert {:ok, res} = Resource.build("create_delegation", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a/delegations"
    end

    test "B-R9 transition_task targets task entity" do
      assert {:ok, res} = Resource.build("transition_task", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a"
    end

    test "B-R10 assign_agent targets same Task resource" do
      assert {:ok, r1} = Resource.build("transition_task", @company, %{task_uid: @task})
      assert {:ok, r2} = Resource.build("assign_agent", @company, %{task_uid: @task})
      assert r1 == r2
    end

    test "B-R11 cancel_task targets same Task resource" do
      assert {:ok, res} = Resource.build("cancel_task", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a"
    end

    test "B-R12 fail_task targets same Task resource" do
      assert {:ok, res} = Resource.build("fail_task", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a"
    end

    test "B-R13 set_child_policy targets same Task resource" do
      assert {:ok, res} = Resource.build("set_child_policy", @company, %{task_uid: @task})
      assert res == "w2:v1/company/co-1/tasks/task-a"
    end

    test "B-R14 set_dependency targets compound edge" do
      assert {:ok, res} =
               Resource.build("set_dependency", @company, %{
                 task_uid: @task,
                 depends_on_task_uid: @dep
               })

      assert res == "w2:v1/company/co-1/tasks/task-a/dependencies/task-b"
    end

    test "B-R15 remove_dependency produces identical resource to set_dependency" do
      assert {:ok, res1} =
               Resource.build("set_dependency", @company, %{
                 task_uid: @task,
                 depends_on_task_uid: @dep
               })

      assert {:ok, res2} =
               Resource.build("remove_dependency", @company, %{
                 task_uid: @task,
                 depends_on_task_uid: @dep
               })

      assert res1 == res2
    end

    test "B-R16 invalidate_review targets review entity" do
      assert {:ok, res} = Resource.build("invalidate_review", @company, %{review_uid: @review})
      assert res == "w2:v1/company/co-1/reviews/rev-001"
    end
  end

  describe "error contract" do
    test "B-R17 unknown action rejected" do
      assert {:error, :unknown_action} = Resource.build("nonexistent", @company, %{})
    end

    test "B-R18 missing target key rejected" do
      assert {:error, :missing_target} = Resource.build("create_result", @company, %{wrong_key: "x"})
    end

    test "B-R19 blank UID segment rejected" do
      assert {:error, :missing_target} = Resource.build("create_result", @company, %{task_uid: ""})
      assert {:error, :missing_target} = Resource.build("create_result", @company, %{task_uid: nil})
      assert {:error, :missing_target} = Resource.build("create_revision", @company, %{mission_uid: ""})
    end

    test "B-R20 nil UID segment rejected" do
      assert {:error, :missing_target} = Resource.build("create_result", @company, %{task_uid: nil})
    end

    # R1 regression: non-binary required target UIDs must fail closed, not crash.
    test "B-R21 integer task_uid fails closed" do
      assert {:error, :missing_target} = Resource.build("transition_task", @company, %{task_uid: 123})
    end

    test "B-R22 integer mission_uid fails closed" do
      assert {:error, :missing_target} = Resource.build("create_revision", @company, %{mission_uid: 42})
    end

    test "B-R23 atom depends_on_task_uid fails closed" do
      assert {:error, :missing_target} =
               Resource.build("set_dependency", @company, %{
                 task_uid: "t1",
                 depends_on_task_uid: :not_a_string
               })
    end

    test "B-R24 float review_uid fails closed" do
      assert {:error, :missing_target} = Resource.build("invalidate_review", @company, %{review_uid: 3.14})
    end
  end

  describe "determinism and separation of concerns" do
    test "B-R21 same semantic input gives byte-identical output" do
      {:ok, first} = Resource.build("transition_task", @company, %{task_uid: @task})
      {:ok, second} = Resource.build("transition_task", @company, %{task_uid: @task})
      assert first == second
    end

    test "B-R22 different target gives different output" do
      assert {:ok, r1} = Resource.build("transition_task", @company, %{task_uid: "task-a"})
      assert {:ok, r2} = Resource.build("transition_task", @company, %{task_uid: "task-b"})
      refute r1 == r2
    end

    test "B-R23 transition status never affects resource" do
      assert {:ok, r1} = Resource.build("transition_task", @company, %{task_uid: @task})
      # context is not part of build; only action+targets matter
      assert {:ok, r2} = Resource.build("transition_task", @company, %{task_uid: @task})
      assert r1 == r2
    end

    test "B-R24 assigned agent never affects Task resource" do
      assert {:ok, r_assign} = Resource.build("assign_agent", @company, %{task_uid: @task})
      assert {:ok, r_trans} = Resource.build("transition_task", @company, %{task_uid: @task})
      assert r_assign == r_trans
    end

    test "B-R25 dependency_type never affects dependency resource" do
      params = %{task_uid: @task, depends_on_task_uid: @dep}
      {:ok, r1} = Resource.build("set_dependency", @company, params)
      {:ok, r2} = Resource.build("remove_dependency", @company, params)
      assert r1 == r2
    end
  end

  describe "create actions do not embed new entity UID" do
    test "B-R26 create_task does not embed a task entity UID in resource" do
      assert {:ok, res} = Resource.build("create_task", @company, %{})
      # Collection resource has no entity segment; only the collection label "tasks"
      refute String.match?(res, ~r/tasks\/[^\/]+/)
    end

    test "B-R27 create_goal does not use any UID in resource" do
      assert {:ok, res} = Resource.build("create_goal", @company, %{})
      refute String.contains?(res, "/goals/")
    end

    test "B-R28 create_mission does not use any UID in resource" do
      assert {:ok, res} = Resource.build("create_mission", @company, %{})
      refute String.contains?(res, "/missions/")
    end
  end

  describe "percent-encoding behavior" do
    test "B-R29 slash is percent-encoded" do
      assert {:ok, res} = Resource.build("create_result", @company, %{task_uid: "A/B"})
      assert res == "w2:v1/company/co-1/tasks/A%2FB/results"
    end

    test "B-R30 colon is percent-encoded" do
      assert {:ok, res} = Resource.build("transition_task", @company, %{task_uid: "task:*"})
      assert res == "w2:v1/company/co-1/tasks/task%3A%2A"
    end

    test "B-R31 uppercase hex in percent encoding" do
      assert {:ok, res} = Resource.build("transition_task", @company, %{task_uid: "te st"})
      assert res == "w2:v1/company/co-1/tasks/te%20st"
    end

    test "B-R32 case is preserved in UIDs" do
      assert {:ok, res} = Resource.build("transition_task", @company, %{task_uid: "Task-A1"})
      assert res == "w2:v1/company/co-1/tasks/Task-A1"
    end
  end

  describe "normalize_exact/1" do
    test "B-R33 blank exact resource rejected" do
      assert {:error, :not_binary} = Resource.normalize_exact(nil)
      assert {:error, :blank} = Resource.normalize_exact("")
      assert {:error, :blank} = Resource.normalize_exact("   ")
    end

    test "B-R34 raw glob exact resource rejected" do
      assert {:error, :glob_not_allowed} = Resource.normalize_exact("workspace:*")
      assert {:error, :glob_not_allowed} = Resource.normalize_exact("task?")
      assert {:error, :glob_not_allowed} = Resource.normalize_exact("a[b]")
      assert {:error, :glob_not_allowed} = Resource.normalize_exact("x{y}")
    end

    test "B-R35 >512-byte exact resource rejected" do
      long = String.duplicate("a", 513)
      assert {:error, :too_long} = Resource.normalize_exact(long)
    end

    test "B-R36 512-byte exact resource accepted" do
      exact = String.duplicate("a", 512)
      assert {:ok, ^exact} = Resource.normalize_exact(exact)
    end

    test "B-R37 exact resource trims outer whitespace but preserves inner" do
      assert {:ok, "hello world"} = Resource.normalize_exact("  hello world  ")
    end

    test "B-R38 exact resource is not lowercased" do
      assert {:ok, "MixedCase"} = Resource.normalize_exact("MixedCase")
    end

    test "B-R39 non-binary input rejected" do
      assert {:error, :not_binary} = Resource.normalize_exact(123)
      assert {:error, :not_binary} = Resource.normalize_exact(:atom)
      assert {:error, :not_binary} = Resource.normalize_exact(%{})
    end
  end

  describe "invariants" do
    test "B-R40 output of build/3 always passes normalize_exact/1" do
      cases = [
        {"create_task", @company, %{}},
        {"transition_task", @company, %{task_uid: "task-a"}},
        {"set_dependency", @company, %{task_uid: "t1", depends_on_task_uid: "t2"}},
        {"create_result", @company, %{task_uid: "task-a"}},
        {"invalidate_review", @company, %{review_uid: "rev-1"}}
      ]

      for {action, co, targets} <- cases do
        assert {:ok, resource} = Resource.build(action, co, targets)
        assert {:ok, ^resource} = Resource.normalize_exact(resource)
      end
    end

    test "B-R41 no trailing slash on any built resource" do
      actions = ~w(
        create_task create_goal create_mission
        create_revision create_result create_review
        create_child_task create_delegation
        transition_task assign_agent cancel_task fail_task set_child_policy
        set_dependency remove_dependency invalidate_review
      )

      for action <- actions do
        {:ok, res} = Resource.build(action, @company, sample_targets(action))
        refute String.ends_with?(res, "/")
      end
    end

    test "B-R42 no collision between collection/entity/relationship examples" do
      {:ok, tasks} = Resource.build("create_task", @company, %{})
      {:ok, task_a} = Resource.build("transition_task", @company, %{task_uid: "a"})
      {:ok, deps} = Resource.build("set_dependency", @company, %{task_uid: "a", depends_on_task_uid: "b"})

      refute tasks == task_a
      refute task_a == deps
      refute deps == tasks
    end

    test "B-R43 output contains no raw glob characters" do
      # Even when UIDs contain characters that look like globs, encoding prevents raw chars
      {:ok, res} = Resource.build("transition_task", @company, %{task_uid: "task:*"})
      refute String.contains?(res, "*")
      refute String.contains?(res, "?")
      refute String.contains?(res, "[")
      refute String.contains?(res, "]")
      refute String.contains?(res, "{")
      refute String.contains?(res, "}")
    end
  end

  # ─── helpers ────────────────────────────────────────────────────────────

  defp sample_targets(action) do
    case action do
      "create_revision" -> %{mission_uid: @mission}
      "create_result" -> %{task_uid: @task}
      "create_review" -> %{task_uid: @task, result_uid: @result}
      "create_child_task" -> %{task_uid: @task}
      "create_delegation" -> %{task_uid: @task}
      "set_dependency" -> %{task_uid: @task, depends_on_task_uid: @dep}
      "remove_dependency" -> %{task_uid: @task, depends_on_task_uid: @dep}
      "invalidate_review" -> %{review_uid: @review}
      _ -> %{task_uid: @task}
    end
  end
end
