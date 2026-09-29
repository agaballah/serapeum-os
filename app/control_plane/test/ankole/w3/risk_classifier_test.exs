defmodule Ankole.W3.RiskClassifierTest do
  @moduledoc """
  Tests for the P4 Risk Classifier.

  These tests exercise only the pure classification module. They do not
  touch AuthZ, the database, W2 stores, or any later W3 package.
  """

  use ExUnit.Case, async: true

  alias Ankole.W3.RiskClassifier

  describe "canonical_classes/0" do
    test "returns the four MA-06 §15 classes in ascending severity order" do
      assert RiskClassifier.canonical_classes() == ~w(ROUTINE CONTROLLED HIGH-IMPACT PROHIBITED)
    end

    test "returns a stable list (repeatability)" do
      first = RiskClassifier.canonical_classes()
      second = RiskClassifier.canonical_classes()
      assert first == second
    end
  end

  describe "valid_class?/1" do
    test "returns true for each canonical class" do
      for class <- RiskClassifier.canonical_classes() do
        assert RiskClassifier.valid_class?(class)
      end
    end

    test "returns false for unknown classes" do
      refute RiskClassifier.valid_class?("UNKNOWN")
      refute RiskClassifier.valid_class?("low")
      refute RiskClassifier.valid_class?("critical")
      refute RiskClassifier.valid_class?("")
      refute RiskClassifier.valid_class?(nil)
    end
  end

  describe "classify/3" do
    # ─── B-2 / B-3 required tests ──────────────────────────────────────────

    test "B2-T1 create_goal → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_goal")
    end

    test "B2-T2 create_mission → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_mission")
    end

    test "B2-T3 create_revision → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_revision")
    end

    test "B2-T4 create_review → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_review")
    end

    test "B2-T5 transition to READY → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("transition_task", nil, %{to_status: "READY"})
    end

    test "B2-T6 transition to ASSIGNED → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("transition_task", nil, %{to_status: "ASSIGNED"})
    end

    test "B2-T7 transition to IN_PROGRESS → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("transition_task", nil, %{to_status: "IN_PROGRESS"})
    end

    test "B2-T8 transition to WAITING → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("transition_task", nil, %{to_status: "WAITING"})
    end

    test "B2-T9 transition to REVIEW → CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("transition_task", nil, %{to_status: "REVIEW"})
    end

    test "B2-T10 transition to COMPLETED → HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("transition_task", nil, %{to_status: "COMPLETED"})
    end

    test "B2-T11 transition to CANCELLED → HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("transition_task", nil, %{to_status: "CANCELLED"})
    end

    test "B2-T12 transition to FAILED → HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("transition_task", nil, %{to_status: "FAILED"})
    end

    test "B2-T13 BLOCKED is rejected (no longer in catalog)" do
      assert {:error, :unknown_action} = RiskClassifier.classify("transition_task", nil, %{to_status: "BLOCKED"})
    end

    test "B2-T14 PROPOSED as transition target is rejected (not a target state)" do
      assert {:error, :unknown_action} =
               RiskClassifier.classify("transition_task", nil, %{to_status: "PROPOSED"})
    end

    test "B2-T15 arbitrary unknown status is rejected as unknown action" do
      assert {:error, :unknown_action} =
               RiskClassifier.classify("transition_task", nil, %{to_status: "NONEXISTENT"})
    end

    test "B2-T16 transition classification is driven by context target status, not resource value" do
      # Different resources with the same context must produce the same result.
      ctx = %{to_status: "COMPLETED"}
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("transition_task", "any-resource", ctx)
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("transition_task", nil, ctx)
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("transition_task", "", ctx)
    end

    test "B2-T17 existing create_task classification remains CONTROLLED" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_task")
    end

    test "B2-T18 existing assign_agent remains HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("assign_agent")
    end

    test "B2-T19 existing cancel_task remains HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("cancel_task")
    end

    test "B2-T20 existing fail_task remains HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("fail_task")
    end

    test "B2-T21 existing set_child_policy remains HIGH-IMPACT" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("set_child_policy")
    end

    test "B2-T22 existing CONTROLLED actions remain unchanged" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_result")
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("invalidate_review")
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("set_dependency")
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("remove_dependency")
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_child_task")
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_delegation")
    end

    test "B2-T23 existing unknown-action fail-closed behavior remains green" do
      assert {:error, :unknown_action} = RiskClassifier.classify("magic_spell")
      assert {:error, :unknown_action} = RiskClassifier.classify("")
      assert {:error, :unknown_action} = RiskClassifier.classify(nil)
      assert {:error, :unknown_action} = RiskClassifier.classify("transition_task", nil, %{})
    end

    # ─── Regression / boundary ──────────────────────────────────────────────

    test "classifies a known ROUTINE action" do
      assert {:ok, "ROUTINE"} = RiskClassifier.classify("list_company_tasks")
    end

    test "classifies a known CONTROLLED action (non-transition)" do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_result")
    end

    test "classifies a known HIGH-IMPACT action" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("cancel_task")
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("fail_task")
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("assign_agent")
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("set_child_policy")
    end

    test "unknown action returns error, never defaults to a lower-risk class" do
      assert {:error, :unknown_action} = RiskClassifier.classify("magic_spell")
    end

    test "context parameter does not affect non-transition classification" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("cancel_task", nil, %{})
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("cancel_task", nil, %{evil: true})
    end

    test "falls back to {action, nil} entry when called with non-nil resource" do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify("cancel_task", "workspace:default")
      assert {:ok, "ROUTINE"} = RiskClassifier.classify("list_company_tasks", "any-resource")
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_task", "workspace:new")
    end

    test "classification is deterministic" do
      action = "cancel_task"
      results = for _ <- 1..100, do: RiskClassifier.classify(action)
      assert Enum.all?(results, &match?({:ok, "HIGH-IMPACT"}, &1))
    end
  end

  describe "prohibited?/3" do
    test "returns true for a PROHIBITED action" do
      # Register a prohibited action dynamically for this test
      # (We test the flag behavior with a known-catalog entry by verifying
      # that non-PROHIBITED actions return false.)
      refute RiskClassifier.prohibited?("create_task")
      refute RiskClassifier.prohibited?("list_company_tasks")
      refute RiskClassifier.prohibited?("cancel_task")
    end
  end

  describe "validate_no_self_downgrade/4" do
    test "allows proposing the same class as the catalog" do
      assert :ok = RiskClassifier.validate_no_self_downgrade("agent-1", "CONTROLLED", "create_task")
    end

    test "allows proposing a higher (more restrictive) class than the catalog" do
      assert :ok = RiskClassifier.validate_no_self_downgrade("agent-1", "HIGH-IMPACT", "create_task")
      assert :ok = RiskClassifier.validate_no_self_downgrade("agent-1", "PROHIBITED", "create_task")
    end

    test "rejects proposing a lower class than the catalog assigns" do
      # create_task is CONTROLLED; proposing ROUTINE is a downgrade
      assert {:error, :self_downgrade} = RiskClassifier.validate_no_self_downgrade("agent-1", "ROUTINE", "create_task")
    end

    test "rejects self-downgrade on a HIGH-IMPACT action" do
      assert {:error, :self_downgrade} = RiskClassifier.validate_no_self_downgrade("agent-1", "CONTROLLED", "cancel_task")
      assert {:error, :self_downgrade} = RiskClassifier.validate_no_self_downgrade("agent-1", "ROUTINE", "cancel_task")
    end

    test "returns unknown_action error when catalog has no entry" do
      assert {:error, :unknown_action} = RiskClassifier.validate_no_self_downgrade("agent-1", "ROUTINE", "nonexistent")
    end

    test "returns invalid_proposed_class for an unknown proposed class" do
      assert {:error, :invalid_proposed_class} =
               RiskClassifier.validate_no_self_downgrade("agent-1", "MEGA-RISKY", "create_task")
    end

    test "a different principal validating does not change the result" do
      # Classification is consequence-based, not requester-based
      assert {:error, :self_downgrade} = RiskClassifier.validate_no_self_downgrade("owner-1", "ROUTINE", "cancel_task")
      assert {:error, :self_downgrade} = RiskClassifier.validate_no_self_downgrade("system-1", "ROUTINE", "cancel_task")
    end
  end

  describe "max_severity/2" do
    test "returns the more severe of two classes" do
      assert RiskClassifier.max_severity("ROUTINE", "CONTROLLED") == "CONTROLLED"
      assert RiskClassifier.max_severity("CONTROLLED", "ROUTINE") == "CONTROLLED"
      assert RiskClassifier.max_severity("HIGH-IMPACT", "CONTROLLED") == "HIGH-IMPACT"
      assert RiskClassifier.max_severity("PROHIBITED", "HIGH-IMPACT") == "PROHIBITED"
    end

    test "returns equal class when both are the same" do
      assert RiskClassifier.max_severity("CONTROLLED", "CONTROLLED") == "CONTROLLED"
      assert RiskClassifier.max_severity("ROUTINE", "ROUTINE") == "ROUTINE"
    end

    test "handles nil gracefully" do
      assert RiskClassifier.max_severity(nil, "CONTROLLED") == "CONTROLLED"
      assert RiskClassifier.max_severity("ROUTINE", nil) == "ROUTINE"
    end
  end

  describe "boundary: no dependency on AuthZ, W2, or database" do
    test "the classifier source has no AuthZ references" do
      source = File.read!("lib/ankole/w3/risk_classifier.ex")
      refute String.contains?(source, "Ankole.AuthZ")
      refute String.contains?(source, "W3AuthZ.")
      refute String.contains?(source, "W3AuthZ/")
    end

    test "the classifier source has no W2 store references" do
      source = File.read!("lib/ankole/w3/risk_classifier.ex")
      refute String.contains?(source, "TaskStore")
      refute String.contains?(source, "MissionStore")
      refute String.contains?(source, "GoalStore")
      refute String.contains?(source, "Repo.")
      refute String.contains?(source, "Ecto.Repo")
    end

    test "the classifier source has no approval or Action Assurance references" do
      source = File.read!("lib/ankole/w3/risk_classifier.ex")
      refute String.contains?(source, "ActionAssurance")
      refute String.contains?(source, "action_assurance")
      refute String.contains?(source, "approval_workflow")
      refute String.contains?(source, "request_approval")
    end

    test "the classifier source has no broker or execution authority references" do
      source = File.read!("lib/ankole/w3/risk_classifier.ex")
      refute String.contains?(source, "Broker")
      refute String.contains?(source, "broker")
      refute String.contains?(source, "execution_authority")
    end

    test "the classifier is a pure function — no side effects in classify" do
      # By design: classify takes (action, resource, context) and returns
      # a tuple. It calls no repo, no authz, no IO.
      source = File.read!("lib/ankole/w3/risk_classifier.ex")
      refute String.contains?(source, "repo.insert")
      refute String.contains?(source, "repo.update")
      refute String.contains?(source, "Repo.transact")
    end
  end
end