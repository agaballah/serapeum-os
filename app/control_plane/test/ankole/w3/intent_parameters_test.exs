defmodule Ankole.W3.IntentParametersTest do
  @moduledoc """
  Proves that one assured action is described by its fingerprint, and that the
  fingerprint changes exactly when the effective intent changes.
  """

  use ExUnit.Case, async: true

  alias Ankole.W3.IntentParameters

  @company "company-1"
  @other_company "company-2"

  @task_texts %{
    uid: "task-1",
    origin_kind: "OWNER_REQUEST",
    objective_text: "Do the thing",
    scope_text: "Only the thing",
    required_outcome_text: "Thing done",
    acceptance_criteria_text: "Verified"
  }

  defp task_input(overrides \\ %{}) do
    Map.merge(%{company_uid: @company} |> Map.merge(@task_texts), overrides)
  end

  defp child_input(overrides \\ %{}) do
    Map.merge(
      %{
        company_uid: @company,
        parent_task_uid: "parent-1",
        uid: "child-1",
        objective_text: "Child work",
        scope_text: "Child scope",
        required_outcome_text: "Child outcome",
        acceptance_criteria_text: "Child criteria"
      },
      overrides
    )
  end

  defp review_input(overrides \\ %{}) do
    Map.merge(
      %{
        company_uid: @company,
        task_uid: "task-1",
        result_uid: "result-1",
        criteria_text: "Criteria",
        verdict: "APPROVED",
        rationale_text: "Rationale"
      },
      overrides
    )
  end

  defp result_input(overrides \\ %{}) do
    Map.merge(
      %{company_uid: @company, task_uid: "task-1", result_uid: "result-1", workflow_run_id: 7},
      overrides
    )
  end

  defp build(action, input), do: IntentParameters.build(action, input)

  defp hash!(action, input) do
    assert {:ok, intent} = build(action, input)
    intent.params_hash
  end

  # ─── preimage and persisted shape ────────────────────────────────────────

  describe "fingerprint shape" do
    test "uses the locked domain separator and schema version" do
      assert IntentParameters.domain_separator() == "serapeumos.p8.intent.v1"
      assert IntentParameters.schema_version() == 1
    end

    test "persists as a versioned lowercase sha-256" do
      hash = hash!("create_task", task_input())

      assert hash =~ IntentParameters.hash_pattern()
      assert ["v1", digest] = String.split(hash, ":")
      assert String.length(digest) == 64
      assert digest == String.downcase(digest)
      assert Regex.match?(~r/^[0-9a-f]{64}$/, digest)
    end

    test "serializes the preimage deterministically regardless of input key order" do
      forward = Map.new(task_input(), fn {k, v} -> {k, v} end)
      reordered = forward |> Enum.reverse() |> Map.new()

      assert hash!("create_task", forward) == hash!("create_task", reordered)
    end

    test "a different action yields a different hash from identical canonical fields" do
      fields = [{"company_uid", {:string, @company}}, {"task_uid", {:string, "task-1"}}]

      assert IntentParameters.fingerprint("transition_task", fields) !=
               IntentParameters.fingerprint("assign_agent", fields)
    end

    test "a different schema version yields a different hash for the same fields" do
      assert {:ok, intent} = build("create_task", task_input())

      current = IntentParameters.fingerprint("create_task", intent.canonical_fields)
      next = fingerprint_at_version(2, "create_task", intent.canonical_fields)

      assert current != next
      assert next =~ ~r/^v2:[0-9a-f]{64}$/
    end

    test "recomputes the same digest the module stored" do
      assert {:ok, intent} = build("create_task", task_input())

      assert intent.params_hash ==
               IntentParameters.fingerprint("create_task", intent.canonical_fields)
    end
  end

  # ─── redundant resource binding ──────────────────────────────────────────

  describe "company and resource identifiers are bound redundantly" do
    test "company_uid changes the hash for every schema that binds one" do
      mutations = [
        {"create_task", task_input(), %{company_uid: @other_company}},
        {"create_child_task", child_input(), %{company_uid: @other_company}},
        {"create_result", result_input(), %{company_uid: @other_company}},
        {"create_review", review_input(), %{company_uid: @other_company}},
        {"invalidate_review", %{company_uid: @company, review_uid: "review-1", reason: "stale"},
         %{company_uid: @other_company}},
        {"transition_task", %{company_uid: @company, task_uid: "task-1", to_status: "READY"},
         %{company_uid: @other_company}},
        {"assign_agent", %{company_uid: @company, task_uid: "task-1", agent_uid: "agent-1"},
         %{company_uid: @other_company}},
        {"set_dependency",
         %{company_uid: @company, task_uid: "task-1", depends_on_task_uid: "task-2"},
         %{company_uid: @other_company}},
        {"remove_dependency",
         %{company_uid: @company, task_uid: "task-1", depends_on_task_uid: "task-2"},
         %{company_uid: @other_company}},
        {"create_delegation",
         %{company_uid: @company, source_task_uid: "task-1", scope_description: "scope"},
         %{company_uid: @other_company}},
        {"list_company_tasks", %{company_uid: @company}, %{company_uid: @other_company}}
      ]

      for {action, base, override} <- mutations do
        assert hash!(action, base) != hash!(action, Map.merge(base, override)),
               "#{action} did not bind company_uid"
      end
    end

    test "every positional resource and target identifier changes the hash" do
      mutations = [
        {"create_result", result_input(), %{task_uid: "task-9"}},
        {"create_review", review_input(), %{task_uid: "task-9"}},
        {"create_review", review_input(), %{result_uid: "result-9"}},
        {"invalidate_review", %{company_uid: @company, review_uid: "review-1", reason: "stale"},
         %{review_uid: "review-9"}},
        {"transition_task", %{company_uid: @company, task_uid: "task-1", to_status: "READY"},
         %{task_uid: "task-9"}},
        {"assign_agent", %{company_uid: @company, task_uid: "task-1", agent_uid: "agent-1"},
         %{task_uid: "task-9"}},
        {"assign_agent", %{company_uid: @company, task_uid: "task-1", agent_uid: "agent-1"},
         %{agent_uid: "agent-9"}},
        {"set_dependency",
         %{company_uid: @company, task_uid: "task-1", depends_on_task_uid: "task-2"},
         %{task_uid: "task-9"}},
        {"set_dependency",
         %{company_uid: @company, task_uid: "task-1", depends_on_task_uid: "task-2"},
         %{depends_on_task_uid: "task-9"}},
        {"remove_dependency",
         %{company_uid: @company, task_uid: "task-1", depends_on_task_uid: "task-2"},
         %{depends_on_task_uid: "task-9"}},
        {"create_delegation",
         %{company_uid: @company, source_task_uid: "task-1", scope_description: "scope"},
         %{source_task_uid: "task-9"}},
        {"create_child_task", child_input(), %{parent_task_uid: "parent-9"}},
        {"create_revision",
         %{
           company_uid: @company,
           mission_uid: "mission-1",
           content: "Mandate",
           assigned_agent_uid: "agent-1"
         }, %{mission_uid: "mission-9"}}
      ]

      for {action, base, override} <- mutations do
        assert hash!(action, base) != hash!(action, Map.merge(base, override)),
               "#{action} did not bind #{inspect(Map.keys(override))}"
      end
    end

    test "a resource identifier is bound even though intent_resource already repeats it" do
      base = %{company_uid: @company, task_uid: "task-1", to_status: "READY"}
      other = %{base | task_uid: "task-2"}

      resource_for = fn task_uid -> "w2:v1/company/#{@company}/tasks/#{task_uid}" end

      assert resource_for.("task-1") != resource_for.("task-2")
      assert hash!("transition_task", base) != hash!("transition_task", other)
    end
  end

  # ─── every caller-controlled non-actor field ─────────────────────────────

  describe "every caller-controlled non-actor field is bound" do
    test "create_task binds each of its mutable fields" do
      base = task_input(%{mission_uid: "m-1", goal_uid: "g-1", accountable_agent_uid: "agent-1"})

      mutations = [
        %{uid: "task-2"},
        %{status: "READY"},
        %{origin_kind: "COMPANY_GOAL"},
        %{origin_reference: %{"k" => "v"}},
        %{mission_uid: "m-2"},
        %{goal_uid: "g-2"},
        %{parent_task_uid: "p-1"},
        %{accountable_agent_uid: "agent-2"},
        %{objective_text: "Other"},
        %{scope_text: "Other"},
        %{required_outcome_text: "Other"},
        %{acceptance_criteria_text: "Other"},
        %{child_completion_policy: "INDEPENDENT"},
        %{cancelled_at: ~U[2026-01-01 00:00:00.000000Z]},
        %{cancelled_by_uid: "agent-2"},
        %{cancellation_reason: "Because"},
        %{failure_reason: "Broke"}
      ]

      reference = hash!("create_task", base)

      for override <- mutations do
        assert hash!("create_task", Map.merge(base, override)) != reference,
               "create_task did not bind #{inspect(Map.keys(override))}"
      end
    end

    test "create_child_task binds each of its mutable fields" do
      base = child_input(%{mission_uid: "m-1", accountable_agent_uid: "agent-1"})

      mutations = [
        %{uid: "child-2"},
        %{status: "READY"},
        %{origin_kind: "MISSION"},
        %{child_completion_policy: "INDEPENDENT"},
        %{mission_uid: "m-2"},
        %{goal_uid: "g-1"},
        %{accountable_agent_uid: "agent-2"},
        %{objective_text: "Other"},
        %{scope_text: "Other"},
        %{required_outcome_text: "Other"},
        %{acceptance_criteria_text: "Other"},
        %{cancelled_by_uid: "agent-2"},
        %{cancellation_reason: "Because"},
        %{failure_reason: "Broke"}
      ]

      reference = hash!("create_child_task", base)

      for override <- mutations do
        assert hash!("create_child_task", Map.merge(base, override)) != reference,
               "create_child_task did not bind #{inspect(Map.keys(override))}"
      end
    end

    test "create_result binds each of its mutable fields" do
      base =
        result_input(%{
          workflow_agent_call_id: 3,
          background_agent_job_id: 4,
          background_agent_job_turn_id: "11111111-1111-4111-8111-111111111111",
          execution_attempt_ref: "attempt-1",
          executor_principal_uids: ["agent-1"],
          result_metadata: %{"a" => 1},
          acceptance_state: "ACCEPTED",
          failure_reason: "none"
        })

      mutations = [
        %{result_uid: "result-9"},
        %{workflow_run_id: 8},
        %{workflow_agent_call_id: 9},
        %{background_agent_job_id: 9},
        %{background_agent_job_turn_id: "22222222-2222-4222-8222-222222222222"},
        %{execution_attempt_ref: "attempt-2"},
        %{executor_principal_uids: ["agent-2"]},
        %{result_metadata: %{"a" => 2}},
        %{acceptance_state: "REJECTED"},
        %{failure_reason: "other"}
      ]

      reference = hash!("create_result", base)

      for override <- mutations do
        assert hash!("create_result", Map.merge(base, override)) != reference,
               "create_result did not bind #{inspect(Map.keys(override))}"
      end
    end

    test "create_review, invalidate_review, transition_task and delegation bind their fields" do
      cases = [
        {"create_review",
         review_input(%{
           invalidated_at: ~U[2026-01-01 00:00:00.000000Z],
           invalidation_reason: "x"
         }),
         [
           %{criteria_text: "Other"},
           %{verdict: "REJECTED"},
           %{rationale_text: "Other"},
           %{review_uid: "review-9"},
           %{invalidation_reason: "y"}
         ]},
        {"invalidate_review", %{company_uid: @company, review_uid: "review-1", reason: "stale"},
         [%{reason: "other"}]},
        {"transition_task",
         %{
           company_uid: @company,
           task_uid: "task-1",
           to_status: "FAILED",
           accountable_agent_uid: "agent-1",
           cancellation_reason: "Because",
           failure_reason: "Broke",
           cancelled_by_uid: "agent-1",
           metadata: %{"a" => 1}
         },
         [
           %{to_status: "COMPLETED"},
           %{accountable_agent_uid: "agent-2"},
           %{cancellation_reason: "Other"},
           %{failure_reason: "Other"},
           %{cancelled_by_uid: "agent-2"},
           %{metadata: %{"a" => 2}}
         ]},
        {"create_delegation",
         %{
           company_uid: @company,
           source_task_uid: "task-1",
           delegatee_principal_uid: "agent-1",
           scope_description: "scope"
         }, [%{delegatee_principal_uid: "agent-2"}, %{scope_description: "other"}]}
      ]

      for {action, base, mutations} <- cases do
        reference = hash!(action, base)

        for override <- mutations do
          assert hash!(action, Map.merge(base, override)) != reference,
                 "#{action} did not bind #{inspect(Map.keys(override))}"
        end
      end
    end

    test "goal, mission, revision, cancel, fail, dependency and policy bind their fields" do
      cases = [
        {"create_goal",
         %{company_uid: @company, uid: "goal-1", title: "Title", description: "Body"},
         [%{uid: "goal-2"}, %{title: "Other"}, %{description: "Other body"}]},
        {"create_mission",
         %{
           company_uid: @company,
           uid: "mission-1",
           content: "Mandate",
           goal_uid: "goal-1",
           assigned_agent_uid: "agent-1"
         },
         [
           %{uid: "mission-2"},
           %{content: "Other"},
           %{goal_uid: "goal-2"},
           %{assigned_agent_uid: "agent-2"}
         ]},
        {"cancel_task",
         %{company_uid: @company, task_uid: "task-1", cancellation_reason: "Because"},
         [%{cancellation_reason: "Other"}, %{metadata: %{"a" => 1}}]},
        {"fail_task", %{company_uid: @company, task_uid: "task-1", failure_reason: "Broke"},
         [%{failure_reason: "Other"}, %{metadata: %{"a" => 1}}]},
        {"set_dependency",
         %{
           company_uid: @company,
           task_uid: "task-1",
           depends_on_task_uid: "task-2",
           dependency_type: "OPTIONAL"
         }, [%{dependency_type: "REQUIRES_RESULT"}]},
        {"set_child_policy",
         %{company_uid: @company, task_uid: "task-1", new_policy: "INDEPENDENT"},
         [%{new_policy: "ALL_COMPLETED"}]}
      ]

      for {action, base, mutations} <- cases do
        reference = hash!(action, base)

        for override <- mutations do
          assert hash!(action, Map.merge(base, override)) != reference,
                 "#{action} did not bind #{inspect(Map.keys(override))}"
        end
      end
    end

    test "no unknown key is ever silently ignored" do
      assert {:error, {:intent_parameters, {:unknown_parameter, :surprise}}} =
               build("create_task", Map.put(task_input(), :surprise, 1))
    end
  end

  # ─── actor fields ────────────────────────────────────────────────────────

  describe "actor fields" do
    test "a genuine actor change does not change the fingerprint" do
      cases = [
        {"create_task", task_input(), :creator_principal_uid, "creator-a"},
        {"create_mission",
         %{company_uid: @company, uid: "m-1", content: "Mandate", assigned_agent_uid: "agent-1"},
         :creator_principal_uid, "creator-b"},
        {"transition_task", %{company_uid: @company, task_uid: "task-1", to_status: "READY"},
         :changed_by_uid, "changer-b"},
        {"cancel_task",
         %{company_uid: @company, task_uid: "task-1", cancellation_reason: "Because"},
         :cancelled_by_uid, "canceller-b"},
        {"fail_task", %{company_uid: @company, task_uid: "task-1", failure_reason: "Broke"},
         :failed_by_uid, "failer-b"},
        {"assign_agent", %{company_uid: @company, task_uid: "task-1", agent_uid: "agent-1"},
         :changed_by_uid, "changer-b"},
        {"set_child_policy",
         %{company_uid: @company, task_uid: "task-1", new_policy: "INDEPENDENT"}, :changed_by_uid,
         "changer-b"},
        {"invalidate_review", %{company_uid: @company, review_uid: "review-1", reason: "stale"},
         :invalidator_principal_uid, "invalidator-b"},
        {"create_delegation",
         %{company_uid: @company, source_task_uid: "task-1", scope_description: "scope"},
         :delegator_principal_uid, "delegator-b"},
        {"create_review", review_input(), :reviewer_principal_uid, "reviewer-b"}
      ]

      for {action, base, actor_key, actor_value} <- cases do
        assert {:ok, actors} = IntentParameters.actor_keys(action)
        assert actor_key in actors, "#{action} does not recognize #{actor_key}"

        assert hash!(action, Map.put(base, actor_key, actor_value)) == hash!(action, base),
               "#{action} fingerprinted its actor #{actor_key}"
      end
    end

    test "actor fields stay declared and available to a future actor check" do
      assert {:ok, keys} = IntentParameters.declared_keys("cancel_task")
      assert :cancelled_by_uid in keys
      assert {:ok, [:cancelled_by_uid]} = IntentParameters.actor_keys("cancel_task")

      assert {:ok, [:creator_principal_uid]} = IntentParameters.actor_keys("create_task")
      assert {:ok, [:changed_by_uid]} = IntentParameters.actor_keys("transition_task")
      assert {:ok, [:failed_by_uid]} = IntentParameters.actor_keys("fail_task")
      assert {:ok, [:reviewer_principal_uid]} = IntentParameters.actor_keys("create_review")

      assert {:ok, [:invalidator_principal_uid]} =
               IntentParameters.actor_keys("invalidate_review")

      assert {:ok, [:delegator_principal_uid]} = IntentParameters.actor_keys("create_delegation")
    end

    test "an actor is recognized but never bound as a canonical field" do
      assert {:ok, intent} =
               build("create_task", Map.put(task_input(), :creator_principal_uid, "c-1"))

      assert IntentParameters.bound_value(intent, :creator_principal_uid) == :not_canonicalized
    end

    test "a cancellation claimant is an actor only for cancel_task" do
      cancel = %{
        company_uid: @company,
        task_uid: "task-1",
        cancellation_reason: "Because",
        cancelled_by_uid: "agent-1"
      }

      transition = %{
        company_uid: @company,
        task_uid: "task-1",
        to_status: "CANCELLED",
        cancellation_reason: "Because",
        cancelled_by_uid: "agent-1"
      }

      create = task_input(%{cancelled_by_uid: "agent-1"})

      assert hash!("cancel_task", cancel) ==
               hash!("cancel_task", %{cancel | cancelled_by_uid: "agent-2"}),
             "cancel_task must not fingerprint its own cancellation claimant"

      refute hash!("transition_task", transition) ==
               hash!("transition_task", %{transition | cancelled_by_uid: "agent-2"})

      refute hash!("create_task", create) ==
               hash!("create_task", %{create | cancelled_by_uid: "agent-2"})
    end

    test "non-actor principal fields stay bound" do
      assignee = %{
        company_uid: @company,
        task_uid: "task-1",
        to_status: "ASSIGNED",
        accountable_agent_uid: "agent-1"
      }

      refute hash!("transition_task", assignee) ==
               hash!("transition_task", %{assignee | accountable_agent_uid: "agent-2"})

      executors = result_input(%{executor_principal_uids: ["agent-1"]})

      refute hash!("create_result", executors) ==
               hash!("create_result", %{executors | executor_principal_uids: ["agent-2"]})

      delegatee = %{
        company_uid: @company,
        source_task_uid: "task-1",
        delegatee_principal_uid: "agent-1",
        scope_description: "scope"
      }

      refute hash!("create_delegation", delegatee) ==
               hash!("create_delegation", %{delegatee | delegatee_principal_uid: "agent-2"})

      mission = %{
        company_uid: @company,
        uid: "m-1",
        content: "Mandate",
        assigned_agent_uid: "agent-1"
      }

      refute hash!("create_mission", mission) ==
               hash!("create_mission", %{mission | assigned_agent_uid: "agent-2"})
    end
  end

  # ─── optional and default semantics ──────────────────────────────────────

  describe "optional and default semantics follow the store, not one global rule" do
    test "create_task status defaults to PROPOSED when absent and rejects nil" do
      default = hash!("create_task", task_input())

      assert {:ok, intent} = build("create_task", task_input())
      assert IntentParameters.bound_value(intent, :status) == {:string, "PROPOSED"}

      assert {:error, {:intent_parameters, :invalid_parameter}} =
               build("create_task", Map.put(task_input(), :status, nil))

      assert hash!("create_task", Map.put(task_input(), :status, "PROPOSED")) == default
      assert hash!("create_task", Map.put(task_input(), :status, "READY")) != default
    end

    test "create_task status accepts every live task status and rejects an unknown one" do
      for status <-
            ~w(PROPOSED READY ASSIGNED IN_PROGRESS WAITING REVIEW COMPLETED FAILED CANCELLED) do
        assert {:ok, _intent} = build("create_task", Map.put(task_input(), :status, status))
      end

      assert {:error, {:intent_parameters, :invalid_parameter}} =
               build("create_task", Map.put(task_input(), :status, "PAUSED"))
    end

    test "create_child_task status binds and defaults the same way" do
      default = hash!("create_child_task", child_input())

      assert {:ok, intent} = build("create_child_task", child_input())
      assert IntentParameters.bound_value(intent, :status) == {:string, "PROPOSED"}

      assert hash!("create_child_task", Map.put(child_input(), :status, "READY")) != default
    end

    test "create_child_task binds an inherited sentinel when the policy is absent" do
      assert {:ok, inherited} = build("create_child_task", child_input())

      assert IntentParameters.bound_value(inherited, :child_completion_policy) ==
               {:inherited, "parent_task_uid"}

      assert {:ok, explicit} =
               build(
                 "create_child_task",
                 Map.put(child_input(), :child_completion_policy, "INDEPENDENT")
               )

      assert IntentParameters.bound_value(explicit, :child_completion_policy) ==
               {:string, "INDEPENDENT"}

      assert inherited.params_hash != explicit.params_hash

      assert {:error, {:intent_parameters, :invalid_parameter}} =
               build(
                 "create_child_task",
                 Map.put(child_input(), :child_completion_policy, "SOMETIMES")
               )
    end

    test "create_task applies its own schema default for the child policy" do
      assert {:ok, intent} = build("create_task", task_input())

      assert IntentParameters.bound_value(intent, :child_completion_policy) ==
               {:string, "ALL_COMPLETED"}
    end

    test "an absent nullable reference and an explicit nil share one effective value" do
      assert {:ok, absent} = build("create_task", task_input())
      assert {:ok, explicit_nil} = build("create_task", Map.put(task_input(), :mission_uid, nil))

      assert IntentParameters.bound_value(absent, :mission_uid) == {:null}
      assert IntentParameters.bound_value(explicit_nil, :mission_uid) == {:null}
      assert absent.params_hash == explicit_nil.params_hash
    end

    test "a required text field refuses absence, nil and blank" do
      # A required field draws one reason per condition: an absent key and an
      # explicit `nil` both mean "not supplied", while a blank value was
      # supplied and is refused for what it contains.
      assert {:error, {:intent_parameters, :missing_parameter}} =
               build("create_task", Map.delete(task_input(), :objective_text))

      assert {:error, {:intent_parameters, :missing_parameter}} =
               build("create_task", Map.put(task_input(), :objective_text, nil))

      for value <- ["", "   "] do
        assert {:error, {:intent_parameters, :invalid_parameter}} =
                 build("create_task", Map.put(task_input(), :objective_text, value))
      end

      assert {:ok, _intent} =
               build("create_task", Map.put(task_input(), :objective_text, "Do it"))
    end

    test "a trimmed required field binds its trimmed value" do
      assert {:ok, intent} =
               build("create_goal", %{company_uid: @company, uid: "  goal-1  ", title: "Title"})

      assert IntentParameters.bound_value(intent, :uid) == {:string, "goal-1"}

      assert hash!("create_goal", %{company_uid: @company, uid: "goal-1", title: "Title"}) ==
               intent.params_hash
    end

    test "a text field stored verbatim binds its untrimmed value" do
      assert {:ok, intent} =
               build("create_task", Map.put(task_input(), :objective_text, "  Do it  "))

      assert IntentParameters.bound_value(intent, :objective_text) == {:string, "  Do it  "}
    end

    test "an executor list keeps nil apart from an empty list, with order and duplicates" do
      assert {:ok, nil_list} =
               build("create_result", result_input(%{executor_principal_uids: nil}))

      assert IntentParameters.bound_value(nil_list, :executor_principal_uids) == {:null}

      assert {:ok, empty} = build("create_result", result_input(%{executor_principal_uids: []}))
      assert IntentParameters.bound_value(empty, :executor_principal_uids) == {:list, []}

      refute nil_list.params_hash == empty.params_hash

      forward = result_input(%{executor_principal_uids: ["agent-1", "agent-2", "agent-1"]})
      reversed = result_input(%{executor_principal_uids: ["agent-1", "agent-1", "agent-2"]})
      deduped = result_input(%{executor_principal_uids: ["agent-1", "agent-2"]})

      assert {:ok, kept} = build("create_result", forward)

      assert IntentParameters.bound_value(kept, :executor_principal_uids) ==
               {:list, [{:string, "agent-1"}, {:string, "agent-2"}, {:string, "agent-1"}]}

      assert hash!("create_result", forward) != hash!("create_result", reversed)
      assert hash!("create_result", forward) != hash!("create_result", deduped)
    end

    test "an execution reference binds the value its own column will hold" do
      assert {:ok, as_text} = build("create_result", result_input(%{workflow_run_id: "7"}))
      assert {:ok, as_integer} = build("create_result", result_input(%{workflow_run_id: 7}))

      assert IntentParameters.bound_value(as_text, :workflow_run_id) == {:int, 7}
      assert as_text.params_hash == as_integer.params_hash

      turn = "11111111-1111-4111-8111-111111111111"

      assert {:ok, with_turn} =
               build("create_result", result_input(%{background_agent_job_turn_id: turn}))

      assert IntentParameters.bound_value(with_turn, :background_agent_job_turn_id) ==
               {:string, turn}

      assert {:error, {:intent_parameters, :invalid_parameter}} =
               build("create_result", result_input(%{background_agent_job_turn_id: "not-a-uuid"}))

      assert {:error, {:intent_parameters, :invalid_parameter}} =
               build("create_result", result_input(%{workflow_run_id: 0}))
    end

    test "a transition treats absent and nil alike but keeps an empty string real" do
      assert {:ok, absent} =
               build("transition_task", %{
                 company_uid: @company,
                 task_uid: "task-1",
                 to_status: "READY"
               })

      assert {:ok, explicit_nil} =
               build(
                 "transition_task",
                 %{
                   company_uid: @company,
                   task_uid: "task-1",
                   to_status: "READY",
                   failure_reason: nil
                 }
               )

      assert absent.params_hash == explicit_nil.params_hash
      assert IntentParameters.bound_value(absent, :failure_reason) == {:null}

      blank =
        build("transition_task", %{
          company_uid: @company,
          task_uid: "task-1",
          to_status: "READY",
          failure_reason: ""
        })

      assert {:ok, blank_intent} = blank
      assert IntentParameters.bound_value(blank_intent, :failure_reason) == {:string, ""}
      refute blank_intent.params_hash == absent.params_hash
    end

    test "cancel and fail bind the merged lifecycle metadata W2 will store" do
      cancel = %{company_uid: @company, task_uid: "task-1", cancellation_reason: "Because"}

      assert {:ok, bare} = build("cancel_task", cancel)

      assert IntentParameters.bound_value(bare, :metadata) ==
               {:map, [{"cancellation_reason", {:string, "Because"}}]}

      with_extra = Map.put(cancel, :metadata, %{"ticket" => "T-1"})
      assert {:ok, extra} = build("cancel_task", with_extra)

      assert IntentParameters.bound_value(extra, :metadata) ==
               {:map,
                [{"cancellation_reason", {:string, "Because"}}, {"ticket", {:string, "T-1"}}]}

      refute bare.params_hash == extra.params_hash

      overridden = Map.put(cancel, :metadata, %{"cancellation_reason" => "Caller wins"})
      assert {:ok, winning} = build("cancel_task", overridden)

      assert IntentParameters.bound_value(winning, :metadata) ==
               {:map, [{"cancellation_reason", {:string, "Caller wins"}}]}

      assert {:error, {:intent_parameters, :unsupported_type}} =
               build("fail_task", %{
                 company_uid: @company,
                 task_uid: "task-1",
                 failure_reason: "Broke",
                 metadata: "nope"
               })
    end

    test "a dependency type falls back to its column default when absent" do
      base = %{company_uid: @company, task_uid: "task-1", depends_on_task_uid: "task-2"}

      assert {:ok, intent} = build("set_dependency", base)

      assert IntentParameters.bound_value(intent, :dependency_type) ==
               {:string, "REQUIRES_COMPLETION"}

      assert hash!("set_dependency", Map.put(base, :dependency_type, "REQUIRES_COMPLETION")) ==
               intent.params_hash

      assert {:error, {:intent_parameters, :invalid_parameter}} =
               build("set_dependency", Map.put(base, :dependency_type, nil))
    end
  end

  # ─── generated values ────────────────────────────────────────────────────

  describe "generated values" do
    test "a server-generated review UID is a sentinel and a caller UID is bound" do
      assert {:ok, generated} = build("create_review", review_input())

      assert IntentParameters.bound_value(generated, :review_uid) ==
               {:server_generated, "review_uid"}

      supplied = Map.put(review_input(), :review_uid, "  review-supplied  ")
      assert {:ok, caller} = build("create_review", supplied)

      assert IntentParameters.bound_value(caller, :review_uid) ==
               {:caller_supplied, "review-supplied"}

      refute generated.params_hash == caller.params_hash
    end

    test "a generated delegation UID is not part of the child schema" do
      {:ok, keys} = IntentParameters.declared_keys("create_child_task")

      refute :delegation_uid in keys
      refute :origin_reference in keys

      assert {:error, {:intent_parameters, {:unknown_parameter, :delegation_uid}}} =
               build("create_child_task", Map.put(child_input(), :delegation_uid, "delegation-1"))
    end
  end

  # ─── metadata canonicalization ───────────────────────────────────────────

  describe "metadata canonicalization" do
    test "map order does not matter" do
      one = task_input(%{origin_reference: %{"a" => 1, "b" => 2, "c" => 3}})
      two = task_input(%{origin_reference: %{"c" => 3, "b" => 2, "a" => 1}})

      assert hash!("create_task", one) == hash!("create_task", two)
    end

    test "an atom key that normalizes to a string key fails closed on collision" do
      assert {:error, {:intent_parameters, {:metadata_key_collision, ["foo"]}}} =
               build("create_task", task_input(%{origin_reference: %{:foo => 1, "foo" => 2}}))
    end

    test "a collision is detected recursively and reports its path" do
      assert {:error, {:intent_parameters, {:metadata_key_collision, ["outer", "bar"]}}} =
               build(
                 "create_task",
                 task_input(%{origin_reference: %{"outer" => %{:bar => 1, "bar" => 2}}})
               )
    end

    test "atom keys normalize to strings when no collision results" do
      atom_keys = task_input(%{origin_reference: %{:foo => 1, :bar => 2}})
      string_keys = task_input(%{origin_reference: %{"foo" => 1, "bar" => 2}})

      assert hash!("create_task", atom_keys) == hash!("create_task", string_keys)
    end

    test "a nested structure is preserved and ordered" do
      nested =
        task_input(%{origin_reference: %{"list" => [3, 1, 2], "flag" => true, "ratio" => 1.5}})

      assert {:ok, intent} = build("create_task", nested)

      assert IntentParameters.bound_value(intent, :origin_reference) ==
               {:map,
                [
                  {"flag", {:bool, true}},
                  {"list", {:list, [{:int, 3}, {:int, 1}, {:int, 2}]}},
                  {"ratio", {:float, 1.5}}
                ]}
    end

    test "a keyword list is refused as a second spelling of a map" do
      assert {:error, {:intent_parameters, :unsupported_type}} =
               build("create_task", task_input(%{origin_reference: [foo: 1]}))
    end

    test "unsupported value types fail closed" do
      for value <- [self(), make_ref(), &Enum.map/2, {1, 2}, ~U[2026-01-01 00:00:00Z]] do
        assert {:error, {:intent_parameters, :unsupported_type}} =
                 build("create_task", task_input(%{origin_reference: value})),
               "#{inspect(value)} was accepted"
      end
    end

    test "nil metadata and absent metadata share one effective value" do
      absent = hash!("create_task", task_input())
      explicit = hash!("create_task", Map.put(task_input(), :origin_reference, nil))

      assert absent == explicit
    end
  end

  # ─── catalog coverage ────────────────────────────────────────────────────

  describe "catalog coverage" do
    test "every mutation action in the risk catalog has a schema" do
      for action <- ~w(create_goal create_mission create_revision create_task create_child_task
                       create_result create_review invalidate_review transition_task assign_agent
                       cancel_task fail_task set_dependency remove_dependency set_child_policy
                       create_delegation) do
        assert action in IntentParameters.actions(), "#{action} has no schema"
      end

      assert length(IntentParameters.actions()) == 30
      assert length(IntentParameters.routine_actions()) == 14
    end

    test "every routine read binds its company and its own identity arguments" do
      cases = [
        {"list_company_tasks", [:company_uid]},
        {"list_company_results", [:company_uid]},
        {"list_mission_tasks", [:company_uid, :mission_uid]},
        {"list_dependencies", [:company_uid, :task_uid]},
        {"list_children", [:company_uid, :parent_task_uid]},
        {"fetch_delegation", [:company_uid, :delegation_uid]},
        {"fetch_result", [:company_uid, :result_uid]},
        {"fetch_current_result", [:company_uid, :task_uid]},
        {"list_task_results", [:company_uid, :task_uid]},
        {"list_task_reviews", [:company_uid, :task_uid]},
        {"list_result_reviews", [:company_uid, :result_uid]},
        {"fetch_review", [:company_uid, :review_uid]},
        {"validate_assignment_eligibility", [:company_uid, :task_uid, :agent_uid]},
        {"workspace_read", [:company_uid]}
      ]

      for {action, keys} <- cases do
        assert {:ok, ^keys} = IntentParameters.declared_keys(action)
      end
    end

    test "routine identity arguments change the hash" do
      cases = [
        {"list_mission_tasks", %{mission_uid: "mission-1"}, %{mission_uid: "mission-2"}},
        {"list_dependencies", %{task_uid: "task-1"}, %{task_uid: "task-2"}},
        {"list_children", %{parent_task_uid: "task-1"}, %{parent_task_uid: "task-2"}},
        {"fetch_delegation", %{delegation_uid: "delegation-1"},
         %{delegation_uid: "delegation-2"}},
        {"fetch_result", %{result_uid: "result-1"}, %{result_uid: "result-2"}},
        {"fetch_current_result", %{task_uid: "task-1"}, %{task_uid: "task-2"}},
        {"list_task_results", %{task_uid: "task-1"}, %{task_uid: "task-2"}},
        {"list_task_reviews", %{task_uid: "task-1"}, %{task_uid: "task-2"}},
        {"list_result_reviews", %{result_uid: "result-1"}, %{result_uid: "result-2"}},
        {"fetch_review", %{review_uid: "review-1"}, %{review_uid: "review-2"}},
        {"validate_assignment_eligibility", %{task_uid: "task-1", agent_uid: "agent-1"},
         %{task_uid: "task-2"}},
        {"validate_assignment_eligibility", %{task_uid: "task-1", agent_uid: "agent-1"},
         %{agent_uid: "agent-2"}}
      ]

      for {action, base, override} <- cases do
        input = Map.merge(%{company_uid: @company}, base)

        assert hash!(action, input) != hash!(action, Map.merge(input, override)),
               "#{action} did not bind #{inspect(Map.keys(override))}"
      end

      # The two company-wide reads bind nothing else, so they stay distinct
      # only through the company scope.
      refute hash!("list_company_tasks", %{company_uid: @company}) ==
               hash!("list_company_results", %{company_uid: @company})
    end

    test "workspace_read is a deterministic company-scoped catalog fingerprint" do
      assert {:ok, intent} = build("workspace_read", %{company_uid: @company})

      assert intent.action == "workspace_read"
      assert intent.canonical_fields == [{"company_uid", {:string, @company}}]
      assert intent.params_hash == hash!("workspace_read", %{company_uid: @company})

      refute intent.params_hash == hash!("workspace_read", %{company_uid: @other_company})
    end

    test "workspace_read invents no workspace argument" do
      assert {:error, {:intent_parameters, {:unknown_parameter, :workspace_uid}}} =
               build("workspace_read", %{company_uid: @company, workspace_uid: "w-1"})
    end

    test "an unknown action fails closed" do
      assert {:error, {:intent_parameters, :unknown_action}} = build("delete_everything", %{})

      assert {:error, {:intent_parameters, :unknown_action}} =
               IntentParameters.declared_keys("nope")

      assert {:error, {:intent_parameters, :unknown_action}} = IntentParameters.actor_keys("nope")
    end
  end

  # A private re-implementation of the preimage, used only to prove that the
  # schema version participates in the digest.
  defp fingerprint_at_version(version, action, fields) do
    serialized =
      {IntentParameters.domain_separator(), version, action, fields}
      |> :erlang.term_to_binary([:deterministic])

    "v#{version}:" <> Base.encode16(:crypto.hash(:sha256, serialized), case: :lower)
  end
end
