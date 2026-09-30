defmodule Ankole.W3.RestrictionEvaluatorTest do
  @moduledoc """
  B-16 tests for the fail-closed execution restriction gate.

  The contract is deliberately narrow: an empty scope and empty constraints
  pair is the only supported input, because the repository defines zero
  recognized execution-restriction keys. Every other value must fail closed
  rather than be interpreted under an invented semantic.
  """

  use ExUnit.Case, async: true

  alias Ankole.W3.RestrictionEvaluator

  @source File.read!("lib/ankole/w3/restriction_evaluator.ex")

  describe "evaluate/2 — supported input" do
    # B16-T1
    test "B16-T1 empty scope with empty constraints is supported" do
      assert :ok = RestrictionEvaluator.evaluate(%{}, %{})
    end

    test "B16-T1 empty maps accept fresh literals that are not the same terms" do
      assert :ok = RestrictionEvaluator.evaluate(%{}, Map.new([]))
      assert :ok = RestrictionEvaluator.evaluate(Map.new([]), %{})
    end
  end

  describe "evaluate/2 — unsupported scope" do
    # B16-T2
    test "B16-T2 non-empty scope is refused" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"task_uid" => "TASK-A"}, %{})
    end

    test "B16-T2 a single scalar-valued key is refused" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"any" => nil}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"any" => true}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"any" => 1}, %{})
    end

    # B16-T5
    test "B16-T5 nested, listed, and arbitrarily shaped scope stays unsupported" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"task" => %{"uid" => "TASK-A"}}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"task_uid" => ["TASK-A"]}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"a" => %{"b" => %{"c" => [1, %{"d" => nil}]}}}, %{})

      # Names that look meaningful elsewhere are still refused: this module
      # recognizes no key at all.
      for key <- ["task_uid", "mission_uid", "goal_uid", "result_uid", "review_uid", "agent_uid", "to_status", "company_uid"] do
        assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{key => "value"}, %{})
      end
    end
  end

  describe "evaluate/2 — unsupported constraints" do
    # B16-T3
    test "B16-T3 non-empty constraints are refused" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, %{"max_duration" => 3600})
    end

    # B16-T6
    test "B16-T6 nested, listed, and arbitrarily shaped constraints stay unsupported" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, %{"limits" => %{"duration" => 1}})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, %{"actors" => ["a", "b"]})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, %{"a" => %{"b" => [nil, 1, "x"]}})

      # Numeric, allowlist-shaped, and target-shaped names carry no meaning
      # here because no predicate is defined for any of them.
      for key <- ["max_duration", "max_count", "target_id", "allowed_agent_ids", "limits", "actors"] do
        assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, %{key => [1]})
      end
    end
  end

  describe "evaluate/2 — both non-empty" do
    # B16-T4
    test "B16-T4 non-empty scope and constraints are refused" do
      assert {:error, :unsupported_restriction} =
               RestrictionEvaluator.evaluate(%{"task_uid" => "TASK-A"}, %{"max_duration" => 3600})
    end

    test "B16-T4 one empty side does not make a non-empty pair supported" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"task_uid" => "TASK-A"}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, %{"max_duration" => 3600})
    end
  end

  describe "evaluate/2 — malformed input fails closed" do
    # B16-T7
    test "B16-T7 non-map scope or constraints fail closed" do
      for value <- [nil, "scope", 1, 1.0, true, [], [%{}], {:ok, %{}}] do
        assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(value, %{})
        assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, value)
      end
    end

    test "B16-T7 a struct is not treated as an empty map" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%URI{}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{}, ~D[2026-09-30])
    end

    test "B16-T7 both sides malformed still fails closed" do
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(nil, nil)
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate("x", "y")
    end
  end

  describe "evaluate/2 — purity" do
    test "repeated evaluation of the same input is deterministic" do
      assert :ok = RestrictionEvaluator.evaluate(%{}, %{})
      assert :ok = RestrictionEvaluator.evaluate(%{}, %{})

      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"k" => "v"}, %{})
      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(%{"k" => "v"}, %{})
    end

    test "evaluate/2 does not mutate its arguments" do
      scope = %{"task_uid" => "TASK-A"}
      constraints = %{"max_duration" => 3600}

      assert {:error, :unsupported_restriction} = RestrictionEvaluator.evaluate(scope, constraints)
      assert scope == %{"task_uid" => "TASK-A"}
      assert constraints == %{"max_duration" => 3600}
    end
  end

  describe "module boundary" do
    # The boundary assertions below inspect executable code only. The moduledoc
    # deliberately discusses Resource, locking, and restriction key names in
    # prose, and prose is not a dependency or a semantic.
    defp code_only do
      @source
      |> String.replace(~r/"""[\s\S]*?"""/, "")
    end

    # B16-T18
    test "B16-T18 the evaluator has no Repo, global Repo, or W2 dependency" do
      source = code_only()

      refute source =~ "Ankole.Repo"
      refute source =~ "Ecto.Repo"
      refute source =~ "CapabilityStore"
      refute source =~ "CapabilityService"
      refute source =~ "Ankole.W3.Capability"
      refute source =~ "WorkHierarchy"
      refute source =~ "TaskStore"
      refute source =~ "MissionStore"
      refute source =~ "ActionAssurance"
      refute source =~ "Ankole.W3.Resource"
      refute source =~ "RiskClassifier"
      refute source =~ "ApprovalStore"
    end

    test "B16-T18 the evaluator takes no repository argument and declares none" do
      refute RestrictionEvaluator.__info__(:functions) |> Enum.any?(fn {name, _arity} ->
               name in [:evaluate, :evaluate!] and function_exported?(RestrictionEvaluator, name, 3)
             end)

      # The only public entry point is evaluate/2.
      assert Enum.sort(RestrictionEvaluator.__info__(:functions)) == [evaluate: 2]
    end

    test "B16-T18 the evaluator declares no reference to any storage process" do
      source = code_only()

      refute source =~ "Repo"
      refute source =~ "transact"
      refute source =~ "FOR UPDATE"
      refute source =~ "lock"
      refute source =~ "fetch"
      refute source =~ "query"
      refute source =~ "transaction"
    end

    # B16-T19
    test "B16-T19 the evaluator contains no dynamic or arbitrary execution mechanism" do
      source = code_only()

      for forbidden <- [
            "Code.eval",
            "Code.eval_string",
            "Code.eval_quoted",
            "String.to_atom",
            "String.to_existing_atom",
            ":erlang.binary_to_term",
            "Kernel.apply",
            "apply(",
            "Regex.",
            "~r",
            "System.cmd",
            "Code.eval_file",
            "module_eval",
            "instance_eval",
            "Function.",
            "send(self()",
            "GenServer",
            "Task.",
            "defprotocol"
          ] do
        refute source =~ forbidden
      end
    end

    test "B16-T19 the evaluator contains no arithmetic or comparison predicate that could imply a semantic" do
      source = code_only()

      # Only emptiness is inspected. Any numeric comparison or membership test
      # would be the start of an invented `<=`, `>=`, or allowlist semantic.
      for forbidden <- ["<=", ">=", "in [", "<-", "Enum.all?", "Enum.any?", "Enum.filter?", "Enum.member?"] do
        refute source =~ forbidden
      end
    end

    test "B16-T19 the evaluator special-cases no restriction key name" do
      source = code_only()

      for forbidden <- [
            "\"task_uid\"",
            "\"mission_uid\"",
            "\"max_duration\"",
            "\"target_id\"",
            "\"actors\"",
            "\"limits\"",
            "\"allowed_",
            "\"max_",
            "\"to_status\""
          ] do
        refute source =~ forbidden,
               "evaluator must not name a restriction key in code; found #{forbidden}"
      end
    end
  end
end