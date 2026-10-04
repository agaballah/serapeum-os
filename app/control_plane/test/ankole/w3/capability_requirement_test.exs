defmodule Ankole.W3.CapabilityRequirementTest do
  @moduledoc """
  A-3: Capability policy by risk class.

  Policy B is locked:

  - ROUTINE actions may present `capability_uid: nil`, on AuthZ alone.
  - CONTROLLED actions require a Capability.
  - HIGH-IMPACT actions require a Capability and, independently, an Approval.

  A missing Capability and an invalid Capability are different failures and keep
  different errors: `:capability_required` versus `:capability_invalid`.
  """

  use Ankole.DataCase, async: true

  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.ActionAssurance
  alias Ankole.W3.ApprovalStore
  alias Ankole.W3.Capability
  alias Ankole.W3.RiskClassifier

  import Ankole.PrincipalsFixtures

  @resource "workspace:default"

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(%{
        uid: "a3-company-#{suffix}",
        name: "a3-company-#{suffix}",
        display_name: "A3 Policy Test Company",
        status: :active,
        metadata: %{},
        owner_principal_uid: owner_uid
      })
      |> Repo.insert()

    company
  end

  defp grant_fixture(principal_uid, company_uid, action) do
    {:ok, _grant} =
      AuthZ.upsert_permission_grant(%{
        principal_uid: principal_uid,
        company_uid: company_uid,
        resource_pattern: "workspace:**",
        action: action,
        condition: "true"
      })
  end

  defp capability_fixture(company_uid, principal_uid, issuer_uid, attrs) do
    suffix = System.unique_integer([:positive])

    {:ok, capability} =
      %Capability{}
      |> Capability.changeset(
        Map.merge(
          %{
            uid: "a3-cap-#{suffix}",
            company_uid: company_uid,
            principal_uid: principal_uid,
            action: "create_task",
            resource: @resource,
            status: :active,
            risk_class: "CONTROLLED",
            issued_at: ~U[2026-09-26T10:00:00Z],
            issued_by_principal_uid: issuer_uid,
            scope: %{},
            constraints: %{},
            metadata: %{}
          },
          attrs
        )
      )
      |> Repo.insert()

    capability
  end

  defp world(action) do
    %{principal: owner} = human_fixture()
    company = company_fixture(owner.uid)
    %{principal: holder} = human_fixture()
    %{principal: issuer} = human_fixture()

    for uid <- [owner.uid, holder.uid, issuer.uid] do
      {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
    end

    grant_fixture(holder.uid, company.uid, action)

    %{
      company: company,
      owner: owner,
      holder: holder,
      issuer: issuer,
      action: action
    }
  end

  defp bound(world, attrs) do
    capability_fixture(world.company.uid, world.holder.uid, world.issuer.uid, attrs)
  end

  defp approved(world, action, risk_class) do
    {:ok, approval} =
      ApprovalStore.create_approval(Repo, %{
        uid: "a3-apr-#{System.unique_integer([:positive])}",
        company_uid: world.company.uid,
        requester_uid: world.holder.uid,
        action: action,
        resource: @resource,
        risk_class: risk_class
      })

    {:ok, _approved} =
      ApprovalStore.approve_approval(Repo, world.company.uid, approval.uid, world.owner.uid)

    approval
  end

  # The assurance chain derives the intent fingerprint from the complete action
  # input, so a case that reaches that stage must declare its action's
  # arguments. These cases test the Capability requirement rather than the
  # fingerprint, so the wrapper supplies a minimal valid input for the action.
  defp intent(action) when is_binary(action) do
    identity = %{
      uid: "w3-a3-intent-task",
      origin_kind: "OWNER_REQUEST",
      objective_text: "Assured objective",
      scope_text: "Assured scope",
      required_outcome_text: "Assured outcome",
      acceptance_criteria_text: "Assured criteria"
    }

    case action do
      "create_task" ->
        identity

      "create_goal" ->
        %{uid: "w3-a3-intent-goal", title: "Assured goal"}

      "cancel_task" ->
        %{task_uid: "w3-a3-intent-task", cancellation_reason: "Assured reason"}

      "fail_task" ->
        %{task_uid: "w3-a3-intent-task", failure_reason: "Assured reason"}

      "assign_agent" ->
        %{task_uid: "w3-a3-intent-task", agent_uid: "w3-a3-intent-agent"}

      "set_child_policy" ->
        %{task_uid: "w3-a3-intent-task", new_policy: "INDEPENDENT"}

      # Every catalogued read names the identity its own W2 read takes.
      "list_mission_tasks" ->
        %{mission_uid: "w3-a3-intent-mission"}

      "list_dependencies" ->
        %{task_uid: "w3-a3-intent-task"}

      "list_children" ->
        %{parent_task_uid: "w3-a3-intent-task"}

      "fetch_delegation" ->
        %{delegation_uid: "w3-a3-intent-delegation"}

      "fetch_result" ->
        %{result_uid: "w3-a3-intent-result"}

      "fetch_current_result" ->
        %{task_uid: "w3-a3-intent-task"}

      "list_task_results" ->
        %{task_uid: "w3-a3-intent-task"}

      "list_task_reviews" ->
        %{task_uid: "w3-a3-intent-task"}

      "list_result_reviews" ->
        %{result_uid: "w3-a3-intent-result"}

      "fetch_review" ->
        %{review_uid: "w3-a3-intent-review"}

      "validate_assignment_eligibility" ->
        %{task_uid: "w3-a3-intent-task", agent_uid: "w3-a3-intent-agent"}

      _company_wide_read ->
        %{}
    end
  end

  defp assure(world, capability_uid, opts \\ []) do
    ActionAssurance.assure(
      Repo,
      world.company.uid,
      world.holder.uid,
      world.action,
      @resource,
      capability_uid,
      Keyword.put_new_lazy(opts, :intent_input, fn -> intent(world.action) end)
    )
  end

  # ─── A3-1: ROUTINE permits a nil Capability ───────────────────────────────

  test "A3-1a a ROUTINE action succeeds with AuthZ ALLOW and no Capability" do
    world = world("list_company_tasks")

    assert {:ok, context} = assure(world, nil)

    assert context.risk_class == "ROUTINE"
    assert context.authz_decision == "ALLOW"
    # A permitted nil stays truthfully nil in the sealed context.
    assert context.capability_uid == nil
    assert is_binary(context.seal)
  end

  test "A3-1b AuthZ still governs a ROUTINE action that presents no Capability" do
    world = world("list_company_tasks")
    %{principal: outsider} = human_fixture()

    {:ok, _membership} = MembershipStore.add_member(Repo, world.company.uid, world.owner.uid)

    # The outsider is not the granted holder, so AuthZ must deny even though
    # no Capability was ever in play.
    assert {:error, :authz_denied} =
             ActionAssurance.assure(
               Repo,
               world.company.uid,
               outsider.uid,
               world.action,
               @resource,
               nil
             )
  end

  # ─── A3-2 / A3-3: nil rejected by risk class ─────────────────────────────

  test "A3-2 a CONTROLLED action rejects a nil Capability" do
    world = world("create_task")

    assert {:error, :capability_required} = assure(world, nil)
  end

  test "A3-3 a HIGH-IMPACT action rejects a nil Capability even with a valid Approval" do
    world = world("cancel_task")
    approval = approved(world, "cancel_task", "HIGH-IMPACT")

    assert {:error, :capability_required} =
             assure(world, nil, approval_uid: approval.uid)
  end

  # ─── A3-4: a valid CONTROLLED Capability is accepted ─────────────────────

  test "A3-4 a CONTROLLED action accepts an exactly bound Capability" do
    world = world("create_task")

    cap = bound(world, %{action: "create_task", risk_class: "CONTROLLED"})

    assert {:ok, context} = assure(world, cap.uid)

    assert context.risk_class == "CONTROLLED"
    assert context.capability_uid == cap.uid
  end

  # ─── A3-5: supplied-but-invalid stays :capability_invalid ────────────────

  test "A3-5a a consumed Capability keeps the existing invalid contract" do
    world = world("create_task")

    cap = bound(world, %{action: "create_task", risk_class: "CONTROLLED"})
    {:ok, _consumed} = Capability.changeset(cap, %{status: :consumed}) |> Repo.update()

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5b a revoked Capability keeps the existing invalid contract" do
    world = world("create_task")

    cap = bound(world, %{action: "create_task", risk_class: "CONTROLLED"})
    {:ok, _revoked} = Capability.changeset(cap, %{status: :revoked}) |> Repo.update()

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5c an expired Capability keeps the existing invalid contract" do
    world = world("create_task")

    cap =
      bound(world, %{
        action: "create_task",
        risk_class: "CONTROLLED",
        expires_at: ~U[2020-01-01T00:00:00Z]
      })

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5d a Capability held by another Principal is invalid, not merely absent" do
    world = world("create_task")

    cap =
      bound(world, %{
        action: "create_task",
        risk_class: "CONTROLLED",
        principal_uid: world.issuer.uid
      })

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5e a Capability bound to the wrong action is invalid" do
    world = world("create_task")

    cap = bound(world, %{action: "create_goal", risk_class: "CONTROLLED"})

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5f a Capability bound to the wrong resource is invalid" do
    world = world("create_task")

    cap =
      bound(world, %{action: "create_task", risk_class: "CONTROLLED", resource: "workspace:other"})

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5g a Capability carrying the wrong risk class is invalid" do
    world = world("create_task")

    cap = bound(world, %{action: "create_task", risk_class: "ROUTINE"})

    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5h a Capability from another Company is invalid" do
    world = world("create_task")

    %{principal: other_owner} = human_fixture()
    other_company = company_fixture(other_owner.uid)
    %{principal: other_holder} = human_fixture()
    %{principal: other_issuer} = human_fixture()

    for uid <- [other_owner.uid, other_holder.uid, other_issuer.uid] do
      {:ok, _membership} = MembershipStore.add_member(Repo, other_company.uid, uid)
    end

    cap =
      capability_fixture(other_company.uid, other_holder.uid, other_issuer.uid, %{
        action: "create_task",
        risk_class: "CONTROLLED"
      })

    # The holder is a member of `world.company`, but the Capability it presents
    # belongs to a different Company.
    assert {:error, :capability_invalid} = assure(world, cap.uid)
  end

  test "A3-5i a nil Capability and an invalid Capability never share an error" do
    world = world("create_task")

    assert {:error, :capability_required} = assure(world, nil)
    assert {:error, :capability_invalid} = assure(world, "a3-does-not-exist")
  end

  # ─── A3-6: HIGH-IMPACT needs both controls, independently ────────────────

  test "A3-6a a valid Approval without a Capability is refused" do
    world = world("cancel_task")
    approval = approved(world, "cancel_task", "HIGH-IMPACT")

    assert {:error, :capability_required} = assure(world, nil, approval_uid: approval.uid)
  end

  test "A3-6b a valid Capability without an Approval is refused" do
    world = world("cancel_task")

    cap = bound(world, %{action: "cancel_task", risk_class: "HIGH-IMPACT"})

    assert {:error, :approval_required} = assure(world, cap.uid)
  end

  test "A3-6c a valid Capability with an invalid Approval is refused" do
    world = world("cancel_task")

    cap =
      bound(world, %{
        action: "cancel_task",
        risk_class: "HIGH-IMPACT",
        approval_uid: "a3-absent-approval"
      })

    assert {:error, :approval_invalid} =
             assure(world, cap.uid, approval_uid: "a3-absent-approval")
  end

  test "A3-6d a valid Capability with a valid Approval proceeds" do
    world = world("cancel_task")
    approval = approved(world, "cancel_task", "HIGH-IMPACT")

    # The Capability must carry the exact Approval binding assurance validates.
    cap =
      bound(world, %{
        action: "cancel_task",
        risk_class: "HIGH-IMPACT",
        approval_uid: approval.uid
      })

    assert {:ok, context} = assure(world, cap.uid, approval_uid: approval.uid)

    assert context.risk_class == "HIGH-IMPACT"
    assert context.capability_uid == cap.uid
    assert context.approval_uid == approval.uid
  end

  # ─── A3-7: the catalog boundary ──────────────────────────────────────────

  @routine_actions [
    "list_company_tasks",
    "list_mission_tasks",
    "list_dependencies",
    "list_children",
    "fetch_delegation",
    "fetch_result",
    "fetch_current_result",
    "list_task_results",
    "list_company_results",
    "fetch_review",
    "list_task_reviews",
    "list_result_reviews",
    "workspace_read",
    "validate_assignment_eligibility"
  ]

  @controlled_actions [
    "create_task",
    "create_goal",
    "create_mission",
    "create_revision",
    "create_review",
    "create_result",
    "invalidate_review",
    "set_dependency",
    "remove_dependency",
    "create_child_task",
    "create_delegation"
  ]

  @high_impact_actions [
    "cancel_task",
    "fail_task",
    "assign_agent",
    "set_child_policy"
  ]

  @controlled_targets ~w(READY ASSIGNED IN_PROGRESS WAITING REVIEW)
  @high_impact_targets ~w(COMPLETED CANCELLED FAILED)

  test "A3-7a the catalogued counts are exactly 14 ROUTINE, 16 CONTROLLED, and 7 HIGH-IMPACT outcomes" do
    assert length(@routine_actions) == 14
    assert length(@controlled_actions) == 11
    assert length(@controlled_targets) == 5
    assert length(@high_impact_actions) == 4
    assert length(@high_impact_targets) == 3

    controlled_outcomes = length(@controlled_actions) + length(@controlled_targets)
    high_impact_outcomes = length(@high_impact_actions) + length(@high_impact_targets)

    assert controlled_outcomes == 16
    assert high_impact_outcomes == 7

    # Every mutation outcome requires a Capability under Policy B.
    assert controlled_outcomes + high_impact_outcomes == 23
  end

  test "A3-7b every catalogued ROUTINE action permits a nil Capability" do
    for action <- @routine_actions do
      assert {:ok, "ROUTINE"} = RiskClassifier.classify(action)
      world = world(action)

      result = assure(world, nil)

      assert {:ok, context} = result,
             "expected #{action} to permit a nil Capability, got #{inspect(result)}"

      assert context.capability_uid == nil
    end
  end

  test "A3-7c every named CONTROLLED action requires a Capability" do
    for action <- @controlled_actions do
      assert {:ok, "CONTROLLED"} = RiskClassifier.classify(action)
      world = world(action)

      assert {:error, :capability_required} = assure(world, nil),
             "expected #{action} to require a Capability"
    end
  end

  test "A3-7d every named HIGH-IMPACT action requires a Capability" do
    for action <- @high_impact_actions do
      assert {:ok, "HIGH-IMPACT"} = RiskClassifier.classify(action)
      world = world(action)

      assert {:error, :capability_required} = assure(world, nil),
             "expected #{action} to require a Capability"
    end
  end

  # ─── A3-8: transition_task target boundary ───────────────────────────────

  test "A3-8a every CONTROLLED transition target requires a Capability" do
    for target <- @controlled_targets do
      assert {:ok, "CONTROLLED"} =
               RiskClassifier.classify("transition_task", nil, %{to_status: target})

      world = world("transition_task")

      assert {:error, :capability_required} =
               assure(world, nil, risk_context: %{to_status: target}),
             "expected transition to #{target} to require a Capability"
    end
  end

  test "A3-8b every HIGH-IMPACT transition target requires a Capability" do
    for target <- @high_impact_targets do
      assert {:ok, "HIGH-IMPACT"} =
               RiskClassifier.classify("transition_task", nil, %{to_status: target})

      world = world("transition_task")

      assert {:error, :capability_required} =
               assure(world, nil, risk_context: %{to_status: target}),
             "expected transition to #{target} to require a Capability"
    end
  end

  test "A3-8c an unsupported transition target stays an unknown action" do
    for target <- ["PROPOSED", "NOT_A_STATUS", nil] do
      assert {:error, :unknown_action} =
               RiskClassifier.classify("transition_task", nil, %{to_status: target})

      world = world("transition_task")

      assert {:error, :unknown_action} =
               assure(world, nil, risk_context: %{to_status: target}),
             "expected target #{inspect(target)} to remain an unknown action"
    end
  end

  test "A3-8d an unknown action is not converted into a Capability requirement" do
    world = world("no_such_action")

    assert {:error, :unknown_action} = assure(world, nil)
  end

  test "A3-8e an invalid action still fails before any Capability decision" do
    world = world("create_task")

    assert {:error, :invalid_action} =
             ActionAssurance.assure(Repo, world.company.uid, world.holder.uid, "", @resource, nil)
  end

  # ─── A3-9: policy ownership ──────────────────────────────────────────────

  # The module that owns the policy.
  @policy_owner "lib/ankole/w3/action_assurance.ex"

  # Modules that must not restate or reproduce the requirement.
  @must_not_own_policy [
    "lib/ankole/w3/p8_controlled_action.ex",
    "lib/ankole/w3/capability_service.ex",
    "lib/ankole/w3/capability_store.ex",
    "lib/ankole/w3/risk_classifier.ex",
    "lib/ankole/w3/authz.ex"
  ]

  # The test file lives at `test/ankole/w3`, so the application root is three
  # levels up.
  defp app_root, do: Path.expand("../../..", __DIR__)

  defp read_source(relative) do
    path = Path.join(app_root(), relative)
    assert File.exists?(path), "expected #{relative} to exist"
    File.read!(path)
  end

  test "A3-9a ActionAssurance is the single owner of the requirement" do
    source = read_source(@policy_owner)

    assert source =~ "requires_capability?",
           "expected ActionAssurance to own requires_capability?/1"

    assert source =~ ":capability_required",
           "expected ActionAssurance to produce :capability_required"
  end

  test "A3-9b no other W3 module restates the requirement" do
    for relative <- @must_not_own_policy do
      source = read_source(relative)

      refute source =~ "requires_capability?",
             "#{relative} must not duplicate the Capability requirement policy"

      refute source =~ ":capability_required",
             "#{relative} must not produce the capability_required error"
    end
  end

  test "A3-9c no W2 module knows about the requirement" do
    w2_dir = Path.join(app_root(), "lib/ankole/work_hierarchy")

    for entry <- Path.wildcard(Path.join(w2_dir, "*.ex")) do
      source = File.read!(entry)

      refute source =~ ":capability_required",
             "#{Path.basename(entry)} must not reference the A-3 policy error"

      refute source =~ "ActionAssurance",
             "#{Path.basename(entry)} must not depend on ActionAssurance"
    end
  end

  test "A3-9d the risk classifier still classifies and does not decide authority" do
    source = read_source("lib/ankole/w3/risk_classifier.ex")

    assert {:ok, "CONTROLLED"} = RiskClassifier.classify("create_task")
    refute source =~ "capability_uid"
  end

  test "A3-9e P8 stays fail-closed and owns no policy" do
    assert Ankole.W3.P8ControlledAction.ready?() == false

    source = read_source("lib/ankole/w3/p8_controlled_action.ex")

    refute source =~ ":capability_required"
  end
end
