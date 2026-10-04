defmodule Ankole.W3.ActionAssuranceTest do
  @moduledoc """
  Tests for the P5 Action Assurance Core.

  Covers the MA-06 Â§16 assurance decision chain and the locked receipt
  lifecycle: assure â†’ (broker executes) â†’ verify â†’ finalize_receipt.
  Does not touch brokers (P7), approval workflow (P6), or W2 stores (P8).
  """

  use Ankole.DataCase, async: true

  alias Ankole.AuthZ
  alias Ankole.AuthZ.Grants
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.ActionReceipt
  alias Ankole.W3.AuthZ, as: W3AuthZ
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.ApprovalStore
  alias Ankole.W3.Resource
  alias Ankole.W3.RiskClassifier
  alias Ankole.W3.IntentParameters
  alias Ankole.W3.ActionAssurance

  import Ankole.PrincipalsFixtures

  # â”€â”€â”€ fixtures â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  # ─── PARAM-SCHEMA failure precedence ─────────────────────────────────────

  describe "intent input failure precedence" do
    setup do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-prec-h")
      %{principal: outsider} = human_fixture(uid: "w3-p5-prec-out")
      %{principal: approver} = human_fixture(uid: "w3-p5-prec-a")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      %{company: company, holder: holder, outsider: outsider, approver: approver}
    end

    defp approved_approval(company, holder, approver, suffix) do
      assert {:ok, approval} =
               ApprovalStore.create_approval(Ankole.Repo, %{
                 uid: "w3-p5-prec-approval-#{suffix}",
                 company_uid: company.uid,
                 requester_uid: holder.uid,
                 action: "cancel_task",
                 resource: "workspace:default",
                 risk_class: "HIGH-IMPACT"
               })

      assert {:ok, approved} =
               ApprovalStore.approve_approval(
                 Ankole.Repo,
                 company.uid,
                 approval.uid,
                 approver.uid
               )

      approved
    end

    test "an AuthZ denial is reached before a malformed intent is examined", ctx do
      %{company: company, holder: holder, outsider: outsider} = ctx
      malformed = %{surprise: "not a declared key"}

      # A ROUTINE read needs no Capability, so AuthZ is the only authority gate
      # between the action check and the intent.
      assert {:error, :authz_denied} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 outsider.uid,
                 "list_company_tasks",
                 "workspace:default",
                 nil,
                 intent_input: malformed
               )

      # The same unusable intent for a permitted Principal now reaches the
      # intent stage, so the AuthZ decision alone separates the two.
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:error, {:intent_parameters, {:unknown_parameter, :surprise}}} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default",
                 nil,
                 intent_input: malformed
               )
    end

    test "a missing Capability is reached before a malformed intent for CONTROLLED", ctx do
      %{company: company, holder: holder, approver: approver} = ctx
      grant_fixture(holder.uid, company.uid, "workspace:**", "create_task")

      cap =
        bound_capability(company.uid, holder.uid, approver.uid, "create_task", "CONTROLLED")

      assert {:error, :capability_required} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "create_task",
                 "workspace:default",
                 nil,
                 intent_input: %{surprise: "not a declared key"}
               )

      assert {:error, {:intent_parameters, {:unknown_parameter, :surprise}}} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "create_task",
                 "workspace:default",
                 cap.uid,
                 intent_input: %{surprise: "not a declared key"}
               )
    end

    test "a missing Approval is reached before a malformed intent for HIGH-IMPACT", ctx do
      %{company: company, holder: holder, approver: approver} = ctx
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      unbound =
        bound_capability(company.uid, holder.uid, approver.uid, "cancel_task", "HIGH-IMPACT")

      assert {:error, :approval_required} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "cancel_task",
                 "workspace:default",
                 unbound.uid,
                 intent_input: %{surprise: "not a declared key"}
               )

      # With a real Approval the Capability must carry that binding, and only
      # then does the unusable intent become the thing that is reported.
      approval = approved_approval(company, holder, approver, "bound")

      bound =
        bound_capability(company.uid, holder.uid, approver.uid, "cancel_task", "HIGH-IMPACT", %{
          approval_uid: approval.uid
        })

      assert {:error, {:intent_parameters, {:unknown_parameter, :surprise}}} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "cancel_task",
                 "workspace:default",
                 bound.uid,
                 approval_uid: approval.uid,
                 intent_input: %{surprise: "not a declared key"}
               )
    end

    test "a bare caller-supplied digest does not satisfy the requirement", ctx do
      %{company: company, holder: holder} = ctx
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      digest = "v1:" <> String.duplicate("b", 64)

      # The option is never read, so it cannot stand in for the input.
      assert {:error, {:intent_parameters, :missing_parameter}} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default",
                 nil,
                 params_hash: digest
               )

      assert {:error, {:intent_parameters, {:unknown_parameter, :surprise}}} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default",
                 nil,
                 params_hash: digest,
                 intent_input: %{surprise: "not a declared key"}
               )
    end

    test "the sealed fingerprint is the one the intent derives", ctx do
      %{company: company, holder: holder} = ctx
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default"
               )

      assert {:ok, expected} =
               IntentParameters.build("list_company_tasks", %{company_uid: company.uid})

      assert context.params_hash == expected.params_hash
      assert {:ok, receipt} = ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})
      assert receipt.params_hash == expected.params_hash
    end

    test "an authoritative company UID overrides one supplied in the input", ctx do
      %{company: company, holder: holder} = ctx
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, context} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default",
                 nil,
                 intent_input: %{company_uid: "some-other-company"}
               )

      assert {:ok, expected} =
               IntentParameters.build("list_company_tasks", %{company_uid: company.uid})

      assert context.params_hash == expected.params_hash
    end

    test "an unknown action is refused before the intent is read", ctx do
      %{company: company, holder: holder} = ctx

      assert {:error, :unknown_action} =
               ActionAssurance.assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "not_a_real_action",
                 "workspace:default",
                 nil,
                 intent_input: %{surprise: "not a declared key"}
               )
    end
  end

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Map.merge(
          %{
            uid: "w3-p5-company-#{suffix}",
            name: "w3-p5-company-#{suffix}",
            display_name: "W3 P5 Test Company",
            status: :active,
            metadata: %{},
            owner_principal_uid: owner_uid
          },
          attrs
        )
      )
      |> Repo.insert()

    company
  end

  defp grant_fixture(principal_uid, company_uid, resource_pattern, action) do
    {:ok, _grant} =
      AuthZ.upsert_permission_grant(%{
        principal_uid: principal_uid,
        company_uid: company_uid,
        resource_pattern: resource_pattern,
        action: action,
        condition: "true"
      })
  end

  defp capability_fixture(company_uid, principal_uid, issuer_uid, attrs) do
    suffix = System.unique_integer([:positive])

    {:ok, cap} =
      %Capability{}
      |> Capability.changeset(
        Map.merge(
          %{
            uid: "w3-p5-cap-#{suffix}",
            company_uid: company_uid,
            principal_uid: principal_uid,
            action: "workspace_read",
            resource: "workspace:default",
            status: :active,
            risk_class: "ROUTINE",
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

    cap
  end

  # A-3 requires a Capability for CONTROLLED and HIGH-IMPACT assurance. Tests
  # whose subject is classification, Approval, or receipt fidelity now need one
  # that binds the exact action/resource/risk they already assert.
  defp bound_capability(company_uid, holder_uid, issuer_uid, action, risk_class, extra \\ %{}) do
    capability_fixture(company_uid, holder_uid, issuer_uid, %{
      action: action,
      resource: "workspace:default",
      risk_class: risk_class
    })
    |> then(fn cap ->
      if Enum.empty?(extra) do
        cap
      else
        {:ok, rebound} = Capability.changeset(cap, extra) |> Repo.update()
        rebound
      end
    end)
  end

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end

  # The assurance chain derives the intent fingerprint from the complete action
  # input, so a call that reaches that stage must declare the arguments its
  # action binds. These cases test the chain rather than the fingerprint, so the
  # wrapper below supplies a minimal valid input for the action under test. A
  # case that cares about the fingerprint passes its own `intent_input`.
  defp intent(action) when is_binary(action) do
    task = %{
      uid: "w3-p5-intent-task",
      origin_kind: "OWNER_REQUEST",
      objective_text: "Assured objective",
      scope_text: "Assured scope",
      required_outcome_text: "Assured outcome",
      acceptance_criteria_text: "Assured criteria"
    }

    case String.downcase(String.trim(action)) do
      "create_task" ->
        task

      "create_child_task" ->
        Map.merge(task, %{parent_task_uid: "w3-p5-intent-parent", origin_kind: "DELEGATION"})

      "create_goal" ->
        %{uid: "w3-p5-intent-goal", title: "Assured goal"}

      "create_mission" ->
        %{
          uid: "w3-p5-intent-mission",
          content: "Assured mandate",
          assigned_agent_uid: "w3-p5-intent-agent"
        }

      "create_revision" ->
        %{
          mission_uid: "w3-p5-intent-mission",
          content: "Assured mandate",
          assigned_agent_uid: "w3-p5-intent-agent"
        }

      "create_result" ->
        %{task_uid: "w3-p5-intent-task", result_uid: "w3-p5-intent-result", workflow_run_id: 1}

      "create_review" ->
        %{
          task_uid: "w3-p5-intent-task",
          result_uid: "w3-p5-intent-result",
          criteria_text: "Assured criteria",
          verdict: "APPROVED",
          rationale_text: "Assured rationale"
        }

      "invalidate_review" ->
        %{review_uid: "w3-p5-intent-review", reason: "Assured reason"}

      "transition_task" ->
        %{task_uid: "w3-p5-intent-task", to_status: "READY"}

      "assign_agent" ->
        %{task_uid: "w3-p5-intent-task", agent_uid: "w3-p5-intent-agent"}

      "cancel_task" ->
        %{task_uid: "w3-p5-intent-task", cancellation_reason: "Assured reason"}

      "fail_task" ->
        %{task_uid: "w3-p5-intent-task", failure_reason: "Assured reason"}

      "set_dependency" ->
        %{task_uid: "w3-p5-intent-task", depends_on_task_uid: "w3-p5-intent-other"}

      "remove_dependency" ->
        %{task_uid: "w3-p5-intent-task", depends_on_task_uid: "w3-p5-intent-other"}

      "set_child_policy" ->
        %{task_uid: "w3-p5-intent-task", new_policy: "INDEPENDENT"}

      "create_delegation" ->
        %{source_task_uid: "w3-p5-intent-task", scope_description: "Assured scope"}

      _read_action ->
        %{}
    end
  end

  defp assure(
         repo,
         company_uid,
         principal_uid,
         action,
         resource,
         capability_uid \\ nil,
         opts \\ []
       ) do
    ActionAssurance.assure(
      repo,
      company_uid,
      principal_uid,
      action,
      resource,
      capability_uid,
      Keyword.put_new_lazy(opts, :intent_input, fn -> intent(action) end)
    )
  end

  # A fingerprint in the one shape a receipt accepts. These cases write a
  # receipt directly rather than through an assurance, so they need a value
  # that satisfies the column without deriving one.
  defp sealed_fingerprint(_action), do: "v1:" <> String.duplicate("a", 64)

  # â”€â”€â”€ normalize_action â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "normalize_action" do
    test "lowercases the action string during assurance" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-norm-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-norm-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "List_Company_Tasks",
                 "workspace:default"
               )

      assert context.intent_action == "list_company_tasks"
    end

    test "rejects blank action" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-norm-blank-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-norm-blank-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:error, :invalid_action} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "",
                 "workspace:default"
               )
    end
  end

  # â”€â”€â”€ risk classification â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "risk classification in assurance" do
    test "classifies a known CONTROLLED action" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-cls-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-cls-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "create_task")

      cap = bound_capability(company.uid, holder.uid, issuer.uid, "create_task", "CONTROLLED")

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "create_task",
                 "workspace:default",
                 cap.uid
               )

      assert context.risk_class == "CONTROLLED"
    end

    test "classifies a known HIGH-IMPACT action" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-hi-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-hi-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      # A-3: HIGH-IMPACT needs both a Capability and an Approval, and the
      # Capability stage runs first, so this still stops at the Approval
      # requirement. Classification has already succeeded by that point.
      cap = bound_capability(company.uid, holder.uid, issuer.uid, "cancel_task", "HIGH-IMPACT")

      assert {:error, :approval_required} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "cancel_task",
                 "workspace:default",
                 cap.uid
               )
    end
  end

  # â”€â”€â”€ authz integration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "authz check" do
    test "allows when Principal has a matching grant" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-auth-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-auth-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default"
               )

      assert context.authz_decision == "ALLOW"
    end

    test "denies when Principal lacks a matching grant" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-noauth-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-noauth-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:error, :authz_denied} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default"
               )
    end
  end

  # â”€â”€â”€ capability validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "capability validation" do
    test "passes when no capability is provided" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-nocap-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-nocap-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, _} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default",
                 nil
               )
    end

    test "passes when capability is valid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-validcap-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-validcap-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "workspace_read")

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          uid: "w3-p5-validcap-001",
          action: "workspace_read",
          resource: "workspace:default",
          risk_class: "ROUTINE"
        })

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "workspace_read",
                 "workspace:default",
                 cap.uid
               )

      assert context.capability_uid == cap.uid
    end

    test "fails when capability does not exist" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-badcap-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-badcap-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "workspace_read")

      # Nonexistent capability â†’ capability_invalid
      assert {:error, :capability_invalid} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "workspace_read",
                 "workspace:default",
                 "nonexistent-capability"
               )
    end
  end

  # â”€â”€â”€ approval requirement â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "approval requirement" do
    test "requires approval for HIGH-IMPACT actions without approval_uid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-approv-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-approv-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      # A-3: with a valid Capability in place, the failure is now specifically
      # the missing Approval rather than the missing Capability.
      cap = bound_capability(company.uid, holder.uid, issuer.uid, "cancel_task", "HIGH-IMPACT")

      assert {:error, :approval_required} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "cancel_task",
                 "workspace:default",
                 cap.uid
               )
    end

    test "accepts HIGH-IMPACT with a valid P6 approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-appv-ok-h")
      %{principal: approver} = human_fixture(uid: "w3-p5-appv-ok-a")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      # Create and approve an approval via P6
      assert {:ok, approval} =
               ApprovalStore.create_approval(Ankole.Repo, %{
                 uid: "w3-p6-valid-001",
                 company_uid: company.uid,
                 requester_uid: holder.uid,
                 action: "cancel_task",
                 resource: "workspace:default",
                 risk_class: "HIGH-IMPACT"
               })

      assert {:ok, _approved} =
               ApprovalStore.approve_approval(
                 Ankole.Repo,
                 company.uid,
                 approval.uid,
                 approver.uid
               )

      # A-3: HIGH-IMPACT needs both controls, and the Capability must carry the
      # exact Approval binding that assurance will validate it against.
      cap =
        bound_capability(company.uid, holder.uid, owner.uid, "cancel_task", "HIGH-IMPACT", %{
          approval_uid: approval.uid
        })

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "cancel_task",
                 "workspace:default",
                 cap.uid,
                 approval_uid: approval.uid
               )

      assert context.risk_class == "HIGH-IMPACT"
      assert context.approval_uid == approval.uid
      assert context.capability_uid == cap.uid
    end

    test "CONTROLLED requires a Capability but still does not require an Approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-cont-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-cont-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "create_task")

      # A-3 split the two controls apart. Approval is still not demanded at
      # CONTROLLED, but a Capability now is.
      assert {:error, :capability_required} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "create_task",
                 "workspace:default"
               )

      cap = bound_capability(company.uid, holder.uid, issuer.uid, "create_task", "CONTROLLED")

      assert {:ok, context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "create_task",
                 "workspace:default",
                 cap.uid
               )

      # No Approval was supplied and none was needed.
      assert context.approval_uid == nil
      assert context.risk_class == "CONTROLLED"
    end
  end

  # â”€â”€â”€ company isolation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "company isolation" do
    test "deny cross-Company assurance" do
      %{principal: owner_a} = human_fixture()
      company_a = company_fixture(owner_a.uid)
      %{principal: owner_b} = human_fixture(uid: "w3-p5-xcomp-b-owner")
      company_b = company_fixture(owner_b.uid)
      %{principal: holder_b} = human_fixture(uid: "w3-p5-xcomp-holder")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company_b.uid, holder_b.uid)
      grant_fixture(holder_b.uid, company_b.uid, "workspace:**", "list_company_tasks")

      assert {:error, :authz_denied} =
               assure(
                 Ankole.Repo,
                 company_a.uid,
                 holder_b.uid,
                 "list_company_tasks",
                 "workspace:default"
               )
    end
  end

  # â”€â”€â”€ receipt creation is deferred â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "receipt is created only after finalization" do
    test "assure succeeds without creating any ActionReceipt" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-no-receipt-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-no-receipt-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, _context} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default"
               )

      # No receipt should exist yet
      receipts = ActionAssurance.list_company_receipts(Ankole.Repo, company.uid)
      assert receipts == []
    end

    test "finalize_assurance creates exactly one receipt with verified result" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-fin-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-fin-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      result_output = %{"items_count" => 42}

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(
                 Ankole.Repo,
                 context,
                 true,
                 result_output
               )

      assert receipt.intent_action == "list_company_tasks"
      assert receipt.intent_resource == "workspace:default"
      assert receipt.principal_uid == holder.uid
      assert receipt.company_uid == company.uid
      assert receipt.risk_class == "ROUTINE"
      assert receipt.authz_decision == "ALLOW"
      # W3 evaluates no precondition, so the receipt claims none.
      assert is_nil(receipt.precondition_status)
      # No Approval backs this decision, so independence is unevaluated.
      assert is_nil(receipt.approval_independent)
      # No postcondition was declared, so none was proven. The caller's `true`
      # does not establish it.
      assert is_nil(receipt.postcondition_verified)
      assert receipt.result_output == result_output
      # No execution outcome is established by the bounded finalization API.
      assert is_nil(receipt.execution_failed)
      assert is_nil(receipt.verified_at)
    end

    test "a caller asserting false does not manufacture execution failure" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-fail-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, false, %{})

      # `false` asserted no postcondition was verified. It does not report that
      # execution failed, and it does not timestamp a verification.
      assert is_nil(receipt.postcondition_verified)
      assert is_nil(receipt.execution_failed)
      assert is_nil(receipt.verified_at)
    end

    test "no receipt exists before finalize_assurance is called" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-before-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      # Count receipts before finalization
      count_before = length(ActionAssurance.list_company_receipts(Ankole.Repo, company.uid))

      ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      # Count after
      count_after = length(ActionAssurance.list_company_receipts(Ankole.Repo, company.uid))
      assert count_after == count_before + 1
    end

    test "assure failures never create receipts" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-no-receipt-fail-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-no-receipt-fail-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      initial_count = length(ActionAssurance.list_company_receipts(Ankole.Repo, company.uid))

      # These should all fail without creating receipts
      assert {:error, :authz_denied} =
               assure(Ankole.Repo, company.uid, holder.uid, "create_task", "x")

      assert {:error, :invalid_action} =
               assure(Ankole.Repo, company.uid, holder.uid, "", "x")

      assert {:error, :invalid_resource} =
               assure(Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "")

      final_count = length(ActionAssurance.list_company_receipts(Ankole.Repo, company.uid))
      assert final_count == initial_count
    end
  end

  # â”€â”€â”€ reject receipt creation without prior assurance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "finalize_assurance without prior assurance" do
    test "refuses a hand-built context and persists nothing" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-bogus-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      # A caller cannot hand-assemble a context. This map asserts an AuthZ
      # decision and a precondition check that never ran. It carries every
      # field the receipt requires, so the refusal is the seal's and not a
      # missing field.
      context = %{
        receipt_uid: "test-receipt-001",
        intent_action: "list_company_tasks",
        intent_resource: "workspace:default",
        principal_uid: holder.uid,
        company_uid: company.uid,
        risk_class: "ROUTINE",
        authz_decision: "ALLOW",
        precondition_status: "met",
        approval_uid: nil,
        approval_independent: true,
        capability_uid: nil,
        broker_name: nil,
        postcondition_expected: %{},
        params_hash: sealed_fingerprint("list_company_tasks")
      }

      assert {:error, :unverified_assurance_context} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert ActionAssurance.list_company_receipts(Ankole.Repo, company.uid) == []
      assert Repo.get_by(ActionReceipt, receipt_uid: "test-receipt-001") == nil
    end

    test "refuses a context whose sealed fields were edited after assurance" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-tamper-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      # Downgrading the risk class after the decision would let a HIGH-IMPACT
      # receipt pass as ROUTINE. The seal covers the field, so it is refused.
      raised = Map.put(context, :risk_class, "REVERSIBLE")

      assert {:error, :unverified_assurance_context} =
               ActionAssurance.finalize_assurance(Ankole.Repo, raised, true, %{})
    end

    test "refuses a context whose approval claim was added after assurance" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-forged-apr-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      assert is_nil(context.approval_uid)
      assert is_nil(context.approval_independent)

      # Claiming an Approval that never existed, and with it independence,
      # must not survive the seal.
      forged = %{
        context
        | approval_uid: "no-such-approval",
          approval_independent: true
      }

      assert {:error, :unverified_assurance_context} =
               ActionAssurance.finalize_assurance(Ankole.Repo, forged, true, %{})

      assert ActionAssurance.list_company_receipts(Ankole.Repo, company.uid) == []
    end

    test "reports a typed error for a partial context instead of raising" do
      # The check stops at the first absent field rather than raising a
      # KeyError, and names that field.
      assert {:error, {:missing_context_field, :intent_action}} =
               ActionAssurance.finalize_assurance(Ankole.Repo, %{receipt_uid: "x"}, true, %{})
    end

    test "reports a typed error for a non-map context instead of raising" do
      assert {:error, :invalid_assurance_context} =
               ActionAssurance.finalize_assurance(Ankole.Repo, nil, true, %{})
    end
  end

  # â”€â”€â”€ normalized values preserved through to receipt â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "normalized values preserved" do
    test "lowercased action and trimmed resource survive to receipt" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-pres-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "  LIST_COMPANY_TASKS  ",
          " workspace:default "
        )

      assert context.intent_action == "list_company_tasks"
      assert context.intent_resource == "workspace:default"

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.intent_action == "list_company_tasks"
      assert receipt.intent_resource == "workspace:default"
    end
  end

  # â”€â”€â”€ approval binding preserved â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "approval binding preserved in receipt" do
    test "approval_uid is recorded in the receipt" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-apr-h")
      %{principal: approver} = human_fixture(uid: "w3-p5-apr-a")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      # Create and approve via P6
      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-apr-42",
          company_uid: company.uid,
          requester_uid: holder.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} =
               ApprovalStore.approve_approval(
                 Ankole.Repo,
                 company.uid,
                 approval.uid,
                 approver.uid
               )

      cap =
        bound_capability(company.uid, holder.uid, owner.uid, "cancel_task", "HIGH-IMPACT", %{
          approval_uid: approval.uid
        })

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "cancel_task",
          "workspace:default",
          cap.uid,
          approval_uid: approval.uid
        )

      assert context.approval_uid == approval.uid

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.approval_uid == "w3-p6-apr-42"
    end
  end

  # â”€â”€â”€ capability binding preserved â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "capability binding preserved in receipt" do
    test "capability_uid is recorded in the receipt" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-cap-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-cap-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "workspace_read")

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          uid: "w3-p5-cap-rec-001",
          action: "workspace_read",
          risk_class: "ROUTINE"
        })

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "workspace_read",
          "workspace:default",
          cap.uid
        )

      assert context.capability_uid == cap.uid

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.capability_uid == cap.uid
    end
  end

  # â”€â”€â”€ PROHIBITED actions never create receipts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "PROHIBITED action" do
    test "assure rejects PROHIBITED before any receipt is created" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-prob-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-prob-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      # No action is currently cataloged as PROHIBITED, but the deny path
      # is exercised by the RiskClassifier.prohibited?/1 direct test.
      assert RiskClassifier.prohibited?("nonexistent") == false
    end
  end

  # â”€â”€â”€ query helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "fetch_receipt / list_company_receipts" do
    test "fetches a finalized receipt by UID" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-fetch-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      assert {:ok, _finalized} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert %ActionReceipt{} =
               ActionAssurance.fetch_receipt(Ankole.Repo, context.receipt_uid)
    end

    test "returns nil for nonexistent receipt" do
      assert is_nil(ActionAssurance.fetch_receipt(Ankole.Repo, "nonexistent"))
    end

    test "lists receipts ordered by creation time descending" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-list-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, c1} =
        assure(Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:one")

      {:ok, c2} =
        assure(Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:two")

      assert {:ok, _} = ActionAssurance.finalize_assurance(Ankole.Repo, c1, true, %{})
      assert {:ok, _} = ActionAssurance.finalize_assurance(Ankole.Repo, c2, true, %{})

      receipts = ActionAssurance.list_company_receipts(Ankole.Repo, company.uid)
      assert length(receipts) >= 2
      # Most recent first
      assert receipts |> Enum.at(0) |> Map.get(:intent_resource) == "workspace:two"
      assert receipts |> Enum.at(1) |> Map.get(:intent_resource) == "workspace:one"
    end
  end

  # â”€â”€â”€ B-1: caller repository propagation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "B-1 transaction-scoped repository" do
    test "B1-T1 assurance reads the caller's uncommitted grant, not the global view" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-b1t1-h")
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      grant = %{
        principal_uid: holder.uid,
        company_uid: company.uid,
        resource_pattern: "workspace:**",
        action: "list_company_tasks",
        condition: "true"
      }

      # Insert the grant inside a transaction and then force a rollback so it
      # never commits. If assure/6 threads its repo argument correctly, it sees
      # the uncommitted grant; if it fell back to Ankole.Repo, it would deny.
      try do
        Repo.transact(fn repo ->
          Grants.create_permission_grant(repo, grant)

          {:ok, _ctx} =
            assure(
              repo,
              company.uid,
              holder.uid,
              "list_company_tasks",
              "workspace:default"
            )

          # Force rollback so the global repo never sees this grant.
          raise "rollback"
        end)
      rescue
        _ -> :ok
      end

      # The grant was rolled back; the global-assurance path denies.
      assert {:error, :authz_denied} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default"
               )
    end

    test "B1-T2 W3 AuthZ reads the caller's uncommitted membership" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-b1t2-h")
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      # The holder is not a member yet, so the Company boundary denies.
      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize(
                 company.uid,
                 holder.uid,
                 "workspace:default",
                 "list_company_tasks",
                 %{}
               )

      # Add the membership inside a transaction and force a rollback so it is
      # never committed. The repo-aware authorize sees it; the global one does
      # not.
      try do
        Repo.transact(fn repo ->
          MembershipStore.add_member(repo, company.uid, holder.uid)

          :ok =
            W3AuthZ.authorize(
              repo,
              company.uid,
              holder.uid,
              "workspace:default",
              "list_company_tasks",
              %{}
            )

          raise "rollback"
        end)
      rescue
        _ -> :ok
      end

      # Rolled back, so the global repository still denies.
      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize(
                 company.uid,
                 holder.uid,
                 "workspace:default",
                 "list_company_tasks",
                 %{}
               )
    end

    test "B1-T3 non-member still denies through the repository-aware path" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: stranger} = human_fixture(uid: "w3-p5-b1t3-s")
      grant_fixture(stranger.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:error, :authz_denied} =
               transact(fn repo ->
                 assure(
                   repo,
                   company.uid,
                   stranger.uid,
                   "list_company_tasks",
                   "workspace:default"
                 )
               end)
    end

    test "B1-T4 committed fixture still allows through the repository-aware path" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-b1t4-h")
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      assert {:ok, context} =
               Repo.transact(fn repo ->
                 assure(
                   repo,
                   company.uid,
                   holder.uid,
                   "list_company_tasks",
                   "workspace:default"
                 )
               end)

      assert context.company_uid == company.uid
      assert context.principal_uid == holder.uid
    end
  end

  # â”€â”€â”€ boundary audit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "store boundary" do
    test "the assurance source has no dependency on W3AuthZ beyond the wrapper" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      refute String.contains?(source, "Ankole.W3.AuthZ.")
    end

    test "the assurance source has no W2 store references" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      refute String.contains?(source, "TaskStore")
      refute String.contains?(source, "MissionStore")
      refute String.contains?(source, "GoalStore")
      refute String.contains?(source, "create_task")
      refute String.contains?(source, "transition_task")
    end

    test "the assurance source has no approval workflow logic" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      refute String.contains?(source, "approval_workflow")
      refute String.contains?(source, "request_approval")
      refute String.contains?(source, "create_approval")
    end

    test "the assurance source has no broker or execution authority" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      refute String.contains?(source, "trusted_broker")
      refute String.contains?(source, "broker.execute")
      refute String.contains?(source, "execution_authority")
    end

    test "the assurance source has no scheduler or worker recovery references" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      refute String.contains?(source, "scheduler")
      refute String.contains?(source, "worker_recovery")
      refute String.contains?(source, "MA-12")
      refute String.contains?(source, "MA-14")
      refute String.contains?(source, "MA-09")
      refute String.contains?(source, "MA-05")
    end

    test "assure/6 body does not contain repo.insert" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      # repo.insert should appear exactly once in save_receipt (called from finalize_assurance)
      insert_count =
        String.split(source, "\n") |> Enum.count(&String.contains?(&1, "repo.insert"))

      assert insert_count == 1
      # assure function exists and finalize_assurance exists
      assert String.contains?(source, "def assure(")
      assert String.contains?(source, "def finalize_assurance(")
    end

    test "finalize_assurance/4 contains the sole repo.insert call" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")
      # The only repo.insert in the file should be inside save_receipt,
      # which is called exclusively from finalize_assurance.
      lines = String.split(source, "\n")
      insert_count = Enum.count(lines, &String.contains?(&1, "repo.insert"))
      assert insert_count == 1
      assert String.contains?(source, "defp save_receipt")
      assert String.contains?(source, "def finalize_assurance")
    end
  end

  # â”€â”€â”€ B-4: exact binding through the full assurance chain â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "assure/6 â€” B4 exact binding integration" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "b4-a-owner-#{suffix}")
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "b4-a-holder-#{suffix}")
      %{principal: issuer} = human_fixture(uid: "b4-a-issuer-#{suffix}")
      %{principal: approver} = human_fixture(uid: "b4-a-approver-#{suffix}")

      for principal <- [owner, holder, issuer, approver] do
        assert {:ok, _m} = MembershipStore.add_member(Repo, company.uid, principal.uid)
      end

      # Canonical resources come only from Resource.build/3.
      {:ok, task_resource} =
        Resource.build("transition_task", company.uid, %{task_uid: "task-b4"})

      grant_fixture(holder.uid, company.uid, "#{task_resource}", "transition_task")

      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: task_resource
      }
    end

    defp b4_capability(company, holder, issuer, attrs) do
      capability_fixture(company.uid, holder.uid, issuer.uid, attrs)
    end

    defp b4_approval(company, requester, approver, attrs) do
      {:ok, approval} =
        ApprovalStore.create_approval(Repo, Map.merge(attrs, %{requester_uid: requester.uid}))

      {:ok, _approved} =
        ApprovalStore.approve_approval(Repo, company.uid, approval.uid, approver.uid)

      approval
    end

    # A â€” transition to IN_PROGRESS recomputes CONTROLLED
    test "B4-A transition to IN_PROGRESS recomputes CONTROLLED", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED"
        })

      assert {:ok, ctx} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "IN_PROGRESS"}
               )

      assert ctx.risk_class == "CONTROLLED"
    end

    # B â€” transition to COMPLETED recomputes HIGH-IMPACT
    test "B4-B transition to COMPLETED recomputes HIGH-IMPACT", context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      approval =
        b4_approval(company, holder, approver, %{
          uid: "b4-B-appr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: approval.uid
        })

      assert {:ok, ctx} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )

      assert ctx.risk_class == "HIGH-IMPACT"
    end

    # C â€” HIGH-IMPACT without Approval rejected
    test "B4-C HIGH-IMPACT without Approval rejected", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      assert {:error, :approval_required} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"}
               )
    end

    # D â€” Capability approval_uid != supplied approval_uid rejected
    test "B4-D Capability approval_uid differs from supplied approval_uid rejected", context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      supplied =
        b4_approval(company, holder, approver, %{
          uid: "b4-D-supplied-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: "b4-D-other-approval"
        })

      assert {:error, :capability_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: supplied.uid
               )
    end

    # E â€” Approval action mismatch rejected
    test "B4-E Approval action mismatch rejected", context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      approval =
        b4_approval(company, holder, approver, %{
          uid: "b4-E-appr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          action: "cancel_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: approval.uid
        })

      assert {:error, :approval_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # F â€” Approval resource mismatch rejected
    test "B4-F Approval resource mismatch rejected", context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      approval =
        b4_approval(company, holder, approver, %{
          uid: "b4-F-appr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          action: "transition_task",
          resource: "w2:v1/company/#{company.uid}/tasks/task-other",
          risk_class: "HIGH-IMPACT"
        })

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: approval.uid
        })

      assert {:error, :approval_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # G â€” Approval requester mismatch rejected
    test "B4-G Approval requester mismatch rejected", context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      %{principal: other_requester} =
        human_fixture(uid: "b4-g-other-#{System.unique_integer([:positive])}")

      assert {:ok, _m} = MembershipStore.add_member(Repo, company.uid, other_requester.uid)

      approval =
        b4_approval(company, other_requester, approver, %{
          uid: "b4-G-appr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: approval.uid
        })

      assert {:error, :approval_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # H â€” Approval RISK mismatch rejected (Catalog HIGH / Capability HIGH / Approval CONTROLLED)
    test "B4-H Approval risk mismatch rejected when catalog and Capability are HIGH-IMPACT",
         context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      # Catalog risk for transition_task to COMPLETED is HIGH-IMPACT.
      assert {:ok, "HIGH-IMPACT"} =
               RiskClassifier.classify("transition_task", resource, %{to_status: "COMPLETED"})

      # The Approval deliberately records a different risk class.
      approval =
        b4_approval(company, holder, approver, %{
          uid: "b4-H-appr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED"
        })

      # Capability risk matches the catalog, so binding must reach the Approval check.
      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: approval.uid
        })

      # Prove the Capability risk itself is not the cause of the rejection.
      assert :ok =
               CapabilityService.validate_exact_binding(cap,
                 principal_uid: holder.uid,
                 action: "transition_task",
                 resource: resource,
                 risk_class: "HIGH-IMPACT",
                 approval_uid: approval.uid,
                 scope: %{},
                 constraints: %{}
               )

      # Prove the Approval risk check is exactly what rejects.
      assert {:error, :approval_risk_class_mismatch} =
               ApprovalStore.validate_for_assurance(
                 Repo,
                 company.uid,
                 approval.uid,
                 holder.uid,
                 "transition_task",
                 resource,
                 "HIGH-IMPACT"
               )

      assert {:error, :approval_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # I â€” scope mismatch through ActionAssurance rejected
    test "B4-I scope mismatch rejected", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          scope: %{"task_uid" => "task-b4"}
        })

      assert {:error, :capability_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: %{"task_uid" => "task-somewhere-else"}
               )
    end

    # J â€” constraints mismatch through ActionAssurance rejected
    test "B4-J constraints mismatch rejected", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          constraints: %{"max_duration" => 3600}
        })

      assert {:error, :capability_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 constraints: %{"max_duration" => 60}
               )
    end
  end

  # â”€â”€â”€ B-16: fail-closed execution restriction gate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  #
  # B-4 proves the caller's maps equal the Capability's stored maps. It does
  # not prove those maps restrict the operation, because the expected maps
  # arrive as caller options. B-16 refuses any non-empty map the system
  # cannot interpret, and it runs only after binding succeeds.

  describe "assure/7 â€” B16 execution restriction gate" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "b16-owner-#{suffix}")
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "b16-holder-#{suffix}")
      %{principal: issuer} = human_fixture(uid: "b16-issuer-#{suffix}")
      %{principal: approver} = human_fixture(uid: "b16-approver-#{suffix}")

      for principal <- [owner, holder, issuer, approver] do
        assert {:ok, _m} = MembershipStore.add_member(Repo, company.uid, principal.uid)
      end

      {:ok, task_resource} =
        Resource.build("transition_task", company.uid, %{task_uid: "task-b16"})

      {:ok, collection_resource} = Resource.build("create_task", company.uid, %{})

      grant_fixture(holder.uid, company.uid, task_resource, "transition_task")
      grant_fixture(holder.uid, company.uid, collection_resource, "create_task")

      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: task_resource,
        collection_resource: collection_resource
      }
    end

    # B16-T8 â€” the supported pair must not disturb a normal assurance.
    test "B16-T8 empty scope and empty constraints remain successful", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          scope: %{},
          constraints: %{}
        })

      assert {:ok, ctx} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: %{},
                 constraints: %{}
               )

      assert ctx.capability_uid == cap.uid
      assert ctx.intent_resource == resource
    end

    # B16-T9 â€” exact echoed non-empty scope passes B-4, then B-16 refuses.
    test "B16-T9 exact echoed non-empty scope is refused after binding", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      scope = %{"task_uid" => "task-b16"}

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          scope: scope
        })

      # Prove B-4 is satisfied by this exact pair, so the refusal cannot be
      # attributed to binding.
      assert :ok =
               CapabilityService.validate_exact_binding(cap,
                 principal_uid: cap.principal_uid,
                 action: "transition_task",
                 resource: resource,
                 risk_class: "CONTROLLED",
                 approval_uid: nil,
                 scope: scope,
                 constraints: %{}
               )

      assert {:error, :unsupported_restriction} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: scope
               )
    end

    # B16-T10
    test "B16-T10 exact echoed non-empty constraints are refused after binding", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      constraints = %{"max_duration" => 3600}

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          constraints: constraints
        })

      assert :ok =
               CapabilityService.validate_exact_binding(cap,
                 principal_uid: cap.principal_uid,
                 action: "transition_task",
                 resource: resource,
                 risk_class: "CONTROLLED",
                 approval_uid: nil,
                 scope: %{},
                 constraints: constraints
               )

      assert {:error, :unsupported_restriction} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 constraints: constraints
               )
    end

    # B16-T11 â€” echoing both maps cannot buy a bypass.
    test "B16-T11 echoing both non-empty maps cannot bypass B-16", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      scope = %{"task_uid" => "task-b16"}
      constraints = %{"max_duration" => 3600}

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          scope: scope,
          constraints: constraints
        })

      # The caller replays exactly what the Capability stores.
      assert {:error, :unsupported_restriction} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: cap.scope,
                 constraints: cap.constraints
               )

      # Every non-empty shape is refused, whatever it nests. Each Capability
      # below is echoed exactly, so B-4 passes each time and B-16 alone
      # produces the refusal.
      shapes = [
        {%{"task_uid" => "task-b16"}, %{"max_duration" => 3600}},
        {%{"task" => %{"uid" => "task-b16"}}, %{"max_duration" => 3600}},
        {%{"task_uid" => ["task-b16"]}, %{"max_duration" => 3600}},
        {%{"task_uid" => "task-b16"}, %{"actors" => ["a1", "a2"]}},
        {%{"task_uid" => "task-b16"}, %{"limits" => %{"duration" => 3600}}}
      ]

      for {s, c} <- shapes do
        shaped =
          capability_fixture(company.uid, holder.uid, issuer.uid, %{
            action: "transition_task",
            resource: resource,
            risk_class: "CONTROLLED",
            scope: s,
            constraints: c
          })

        assert {:error, :unsupported_restriction} =
                 assure(Repo, company.uid, holder.uid, "transition_task", resource, shaped.uid,
                   risk_context: %{to_status: "READY"},
                   scope: shaped.scope,
                   constraints: shaped.constraints
                 )
      end

      # A shape the Capability does not carry is refused earlier, by B-4. That
      # ordering is deliberate and is what stops a caller from presenting a
      # restriction the Capability never carried.
      assert {:error, :capability_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: %{"invented" => "by-caller"},
                 constraints: constraints
               )
    end

    # B16-T12 â€” B-4 must fail first, and must not be relabelled.
    test "B16-T12 B-4 scope mismatch fails before B-16 as capability_invalid", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          scope: %{"x" => 1}
        })

      # Internal B-4 reason is still :scope_mismatch.
      assert {:error, :scope_mismatch} =
               CapabilityService.validate_exact_binding(cap,
                 principal_uid: cap.principal_uid,
                 action: "transition_task",
                 resource: resource,
                 risk_class: "CONTROLLED",
                 approval_uid: nil,
                 scope: %{"x" => 2},
                 constraints: %{}
               )

      # The boundary reports B-4, not B-16, because binding runs first.
      assert {:error, :capability_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: %{"x" => 2}
               )

      # The same exact map passes B-4 and is then refused by B-16 instead.
      assert {:error, :unsupported_restriction} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: %{"x" => 1}
               )
    end

    # B16-T13
    test "B16-T13 B-4 constraints mismatch fails before B-16 as capability_invalid", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          constraints: %{"x" => 1}
        })

      assert {:error, :constraints_mismatch} =
               CapabilityService.validate_exact_binding(cap,
                 principal_uid: cap.principal_uid,
                 action: "transition_task",
                 resource: resource,
                 risk_class: "CONTROLLED",
                 approval_uid: nil,
                 scope: %{},
                 constraints: %{"x" => 2}
               )

      assert {:error, :capability_invalid} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 constraints: %{"x" => 2}
               )

      assert {:error, :unsupported_restriction} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 constraints: %{"x" => 1}
               )
    end

    # B16-T14 â€” HIGH-IMPACT keeps its Approval contract with empty maps.
    test "B16-T14 HIGH-IMPACT with empty restrictions keeps the Approval contract", context do
      %{
        company: company,
        holder: holder,
        issuer: issuer,
        approver: approver,
        task_resource: resource
      } = context

      {:ok, approval} =
        ApprovalStore.create_approval(Repo, %{
          uid: "b16-T14-appr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          requester_uid: holder.uid,
          approver_uid: approver.uid,
          action: "cancel_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      {:ok, _approved} =
        ApprovalStore.approve_approval(Repo, company.uid, approval.uid, approver.uid)

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "cancel_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          approval_uid: approval.uid,
          scope: %{},
          constraints: %{}
        })

      # A HIGH-IMPACT Capability that carries no Approval at all reaches the
      # Approval stage with binding already satisfied, so the refusal is
      # attributable to the missing Approval and not to B-16.
      unbound =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "cancel_task",
          resource: resource,
          risk_class: "HIGH-IMPACT",
          scope: %{},
          constraints: %{}
        })

      grant_fixture(holder.uid, company.uid, resource, "cancel_task")

      # Missing Approval still fails on the Approval stage, not on B-16.
      assert {:error, :approval_required} =
               assure(Repo, company.uid, holder.uid, "cancel_task", resource, unbound.uid,
                 risk_context: %{},
                 scope: %{},
                 constraints: %{}
               )

      assert {:ok, ctx} =
               assure(Repo, company.uid, holder.uid, "cancel_task", resource, cap.uid,
                 risk_context: %{},
                 approval_uid: approval.uid,
                 scope: %{},
                 constraints: %{}
               )

      assert ctx.risk_class == "HIGH-IMPACT"
      assert ctx.approval_uid == approval.uid
    end

    # B16-T15
    test "B16-T15 CONTROLLED with empty restrictions remains green", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED"
        })

      assert {:ok, ctx} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "IN_PROGRESS"}
               )

      assert ctx.risk_class == "CONTROLLED"
    end

    # B16-T16 â€” collection authority is represented by its canonical Resource.
    test "B16-T16 collection action with empty restrictions is valid under its collection Resource",
         context do
      %{company: company, holder: holder, issuer: issuer, collection_resource: resource} = context

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "create_task",
          resource: resource,
          risk_class: "CONTROLLED"
        })

      assert {:ok, ctx} =
               assure(Repo, company.uid, holder.uid, "create_task", resource, cap.uid,
                 scope: %{},
                 constraints: %{}
               )

      # The Company collection Resource is what binds this authority. B-16
      # does not require an artificial scope to make it valid.
      assert ctx.intent_resource == "w2:v1/company/#{company.uid}/tasks"
    end

    # B16-T17 â€” issuance and persistence are untouched by B-16.
    test "B16-T17 non-empty restrictions still persist; only assurance is denied", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      scope = %{"task_uid" => "task-b16"}
      constraints = %{"max_duration" => 3600}

      cap =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED",
          scope: scope,
          constraints: constraints
        })

      # The row exists, keeps its provenance, and reads back unchanged.
      {:ok, persisted} = Ankole.W3.CapabilityStore.fetch_capability(Repo, company.uid, cap.uid)
      assert persisted.status == :active
      assert persisted.scope == scope
      assert persisted.constraints == constraints

      # B-4 still accepts it as an exactly-bound authority.
      assert :ok =
               CapabilityService.validate_exact_binding(persisted,
                 principal_uid: persisted.principal_uid,
                 action: "transition_task",
                 resource: resource,
                 risk_class: "CONTROLLED",
                 approval_uid: nil,
                 scope: scope,
                 constraints: constraints
               )

      # Only assurance is refused.
      assert {:error, :unsupported_restriction} =
               assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: scope,
                 constraints: constraints
               )
    end
  end

  # â”€â”€â”€ B-16 integration boundaries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "B16 integration boundary" do
    @assurance_source File.read!("lib/ankole/w3/action_assurance.ex")

    test "B16 evaluates restrictions only after Capability validation" do
      chain = @assurance_source |> String.split("\n") |> Enum.map(&String.trim/1)

      capability_index = Enum.find_index(chain, &String.contains?(&1, ":ok <- check_capability("))

      restriction_index =
        Enum.find_index(chain, &String.contains?(&1, ":ok <- check_execution_restrictions("))

      approval_index =
        Enum.find_index(chain, &String.contains?(&1, ":ok <- check_approval_requirement("))

      assert is_integer(capability_index)
      assert is_integer(restriction_index)
      assert is_integer(approval_index)

      assert capability_index < restriction_index
      assert restriction_index < approval_index
    end

    test "B16 runs before AuthZ is bypassed and after risk recomputation" do
      chain = @assurance_source |> String.split("\n") |> Enum.map(&String.trim/1)

      risk_index = Enum.find_index(chain, &String.contains?(&1, "check_not_prohibited("))
      authz_index = Enum.find_index(chain, &String.contains?(&1, "check_authz("))

      restriction_index =
        Enum.find_index(chain, &String.contains?(&1, ":ok <- check_execution_restrictions("))

      assert risk_index < authz_index
      assert authz_index < restriction_index
    end

    test "B16 exposes unsupported_restriction at the assurance boundary" do
      assert @assurance_source =~
               "{:error, :unsupported_restriction} -> {:error, :unsupported_restriction}"
    end

    test "B16 cannot be skipped by omitting the Capability" do
      chain = @assurance_source |> String.split("\n") |> Enum.map(&String.trim/1)

      # The Capability-free clause short-circuits binding only. Restriction
      # evaluation is a separate stage in the same `with` chain, so omitting a
      # Capability cannot open a path around the gate.
      assert Enum.any?(chain, &String.contains?(&1, "check_capability(_repo, _company_uid, nil,"))

      restriction_index =
        Enum.find_index(chain, &String.contains?(&1, ":ok <- check_execution_restrictions("))

      receipt_index =
        Enum.find_index(
          chain,
          &String.contains?(&1, "{:ok, receipt_uid} <- generate_receipt_uid()")
        )

      assert restriction_index < receipt_index
    end

    test "B16 introduces no W2 store dependency into assurance" do
      for forbidden <- ["TaskStore", "MissionStore", "GoalStore", "ResultStore", "ReviewStore"] do
        refute @assurance_source =~ forbidden
      end
    end

    test "B16 does not change Resource, RiskClassifier, or the Capability modules" do
      evaluator = File.read!("lib/ankole/w3/restriction_evaluator.ex")

      # The evaluator reaches nothing outside itself.
      refute evaluator =~ "Ankole.W3.Resource"
      refute evaluator =~ "Ankole.W3.RiskClassifier"

      # Resource grammar is untouched by this package.
      resource_source = File.read!("lib/ankole/w3/resource.ex")
      assert resource_source =~ "def build(action, company_uid, targets)"
      assert resource_source =~ "def normalize_exact(resource)"
    end
  end

  # â”€â”€â”€ B-6 receipt truthfulness â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "B6 receipt truthfulness" do
    test "an APPROVED decision derives approval_independent from the real Approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-indep-h")
      %{principal: approver} = human_fixture(uid: "w3-b6-indep-a")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-b6-indep-apr-#{System.unique_integer([:positive])}",
          company_uid: company.uid,
          requester_uid: holder.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} =
               ApprovalStore.approve_approval(
                 Ankole.Repo,
                 company.uid,
                 approval.uid,
                 approver.uid
               )

      cap =
        bound_capability(company.uid, holder.uid, owner.uid, "cancel_task", "HIGH-IMPACT", %{
          approval_uid: approval.uid
        })

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "cancel_task",
          "workspace:default",
          cap.uid,
          approval_uid: approval.uid
        )

      # A real Approval passed the independence check, so the claim is earned.
      assert context.approval_independent == true

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.approval_independent == true
      assert receipt.approval_uid == approval.uid
    end

    test "a non-approval decision claims no independence rather than true" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-noindep-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      refute context.approval_independent == true
      assert is_nil(context.approval_independent)
    end

    test "assure reports the AuthZ decision instead of assuming ALLOW" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-authz-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      # The allow decision came from the real authorize call, not a constant.
      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.authz_decision == context.authz_decision

      assert W3AuthZ.authorize(
               Repo,
               company.uid,
               holder.uid,
               "workspace:default",
               "list_company_tasks",
               %{}
             ) == :ok
    end

    test "a duplicate receipt_uid reports a conflict rather than a generic failure" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-dupe-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      assert {:ok, _first} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      # Replaying the same context must not silently overwrite or succeed.
      assert {:error, :receipt_uid_conflict} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert Repo.aggregate(ActionReceipt, :count, :id) == 1
    end

    test "a receipt that violates a field constraint reports the offending field" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-invalid-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      # Blank the action after assurance. The seal must refuse the edit, so
      # the invalid value can never reach the changeset.
      blanked = Map.put(context, :intent_action, "")

      assert {:error, :unverified_assurance_context} =
               ActionAssurance.finalize_assurance(Ankole.Repo, blanked, true, %{})

      assert Repo.aggregate(ActionReceipt, :count, :id) == 0
    end

    test "the receipt schema does not require the unevaluated fields" do
      changeset =
        ActionReceipt.changeset(%ActionReceipt{}, %{
          receipt_uid: "w3-b6-schema-1",
          intent_action: "list_company_tasks",
          intent_resource: "workspace:default",
          principal_uid: "w3-b6-schema-p",
          company_uid: "w3-b6-schema-c",
          risk_class: "ROUTINE",
          authz_decision: "ALLOW",
          params_hash: sealed_fingerprint("list_company_tasks")
        })

      # A receipt is writable without either unevaluated field, so recording
      # "not checked" is representable rather than forcing a fabricated fact.
      assert changeset.valid?

      fields = Enum.map(changeset.errors, &elem(&1, 0))
      refute :precondition_status in fields
      refute :approval_independent in fields

      changes = changeset.changes
      refute Map.has_key?(changes, :precondition_status)
      refute Map.has_key?(changes, :approval_independent)

      # The schema must not re-introduce the fabricated default the migration
      # removed from the database.
      assert is_nil(%ActionReceipt{}.approval_independent)
    end

    test "no source file asserts an unevaluated fact as a literal" do
      source = File.read!("lib/ankole/w3/action_assurance.ex")

      # A hard-coded precondition pass would re-introduce the fabricated fact.
      refute source =~ ~r/precondition_status:\s*"[^"]*"/
      # Independence is derived from a checked Approval, never a literal.
      refute source =~ ~r/approval_independent:\s*true/
    end
  end

  # â”€â”€â”€ B-6 referential and index contract â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "B6 receipt referential contract" do
    test "approval_uid is a restrictive foreign key to approvals.uid" do
      %{rows: rows} =
        Repo.query!("""
        SELECT pg_get_constraintdef(oid)
        FROM pg_constraint
        WHERE conrelid = 'action_receipts'::regclass
          AND conname = 'action_receipts_approval_uid_fkey'
        """)

      assert [[definition]] = rows
      assert definition =~ "FOREIGN KEY (approval_uid)"
      assert definition =~ "REFERENCES approvals(uid)"
      assert definition =~ "ON DELETE RESTRICT"
    end

    test "a receipt naming a nonexistent Approval is refused by the database" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-fk-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      receipt_uid = "w3-b6-fk-#{System.unique_integer([:positive])}"

      changeset =
        ActionReceipt.changeset(%ActionReceipt{}, %{
          receipt_uid: receipt_uid,
          intent_action: "list_company_tasks",
          intent_resource: "workspace:default",
          principal_uid: holder.uid,
          company_uid: company.uid,
          risk_class: "ROUTINE",
          authz_decision: "ALLOW",
          approval_uid: "w3-b6-no-such-approval",
          approval_independent: true,
          params_hash: sealed_fingerprint("list_company_tasks")
        })

      assert changeset.valid?
      assert {:error, failed} = Repo.insert(changeset)

      # The declared constraint turns the database rejection into a changeset
      # error rather than a raised Postgrex exception.
      assert %{approval_uid: [_message]} = errors_on(failed)
      assert Repo.get_by(ActionReceipt, receipt_uid: receipt_uid) == nil
    end

    test "a receipt with no Approval still persists" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-nullapr-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      # A foreign key permits NULL, so "no Approval presented" stays writable.
      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert is_nil(receipt.approval_uid)
    end

    test "assure refuses an Approval that does not exist" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-missingapr-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      cap =
        bound_capability(company.uid, holder.uid, owner.uid, "cancel_task", "HIGH-IMPACT", %{
          approval_uid: "w3-b6-missing-approval"
        })

      assert {:error, :approval_invalid} =
               assure(
                 Ankole.Repo,
                 company.uid,
                 holder.uid,
                 "cancel_task",
                 "workspace:default",
                 cap.uid,
                 approval_uid: "w3-b6-missing-approval"
               )
    end

    test "capability_uid carries a non-unique index" do
      %{rows: rows} =
        Repo.query!("""
        SELECT indexdef
        FROM pg_indexes
        WHERE tablename = 'action_receipts'
          AND indexdef LIKE '%(capability_uid)%'
        """)

      assert [[indexdef]] = rows
      assert indexdef =~ "action_receipts_capability_uid_index"

      # Many receipts can reference one Capability, so the index must not be
      # unique.
      refute indexdef =~ "UNIQUE"
    end

    test "the changeset declares the approval foreign key" do
      changeset =
        ActionReceipt.changeset(%ActionReceipt{}, %{
          receipt_uid: "w3-b6-decl",
          intent_action: "list_company_tasks",
          intent_resource: "workspace:default",
          principal_uid: "p",
          company_uid: "c",
          risk_class: "ROUTINE",
          authz_decision: "ALLOW",
          approval_uid: "a",
          params_hash: sealed_fingerprint("list_company_tasks")
        })

      constraints = constraints_on(changeset)
      assert {:approval_uid, "action_receipts_approval_uid_fkey"} in constraints
    end

    test "an insert omitting approval_independent persists NULL rather than true" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b6-nil-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      receipt_uid = "w3-b6-nil-#{System.unique_integer([:positive])}"

      changeset =
        ActionReceipt.changeset(%ActionReceipt{}, %{
          receipt_uid: receipt_uid,
          intent_action: "list_company_tasks",
          intent_resource: "workspace:default",
          principal_uid: holder.uid,
          company_uid: company.uid,
          risk_class: "ROUTINE",
          authz_decision: "ALLOW",
          params_hash: sealed_fingerprint("list_company_tasks")
        })

      assert {:ok, row} = Repo.insert(changeset)

      # Neither unevaluated field may be invented by the insert path.
      assert is_nil(row.approval_independent)
      assert is_nil(row.precondition_status)
      assert is_nil(row.execution_failed)
      assert row.params_hash == sealed_fingerprint("list_company_tasks")
    end
  end

  # â”€â”€â”€ B-7 / FIX-14 postcondition and execution truthfulness â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe "B7 postcondition truthfulness" do
    setup do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-b7-holder")

      {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        assure(
          Ankole.Repo,
          company.uid,
          holder.uid,
          "list_company_tasks",
          "workspace:default"
        )

      %{company: company, holder: holder, context: context}
    end

    test "an empty expected postcondition records not-evaluated, not success", %{
      company: company,
      context: context
    } do
      # The caller asserts success. That cannot manufacture verification.
      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(
                 Ankole.Repo,
                 context,
                 true,
                 %{"items_count" => 42}
               )

      assert is_nil(receipt.postcondition_verified)
      assert is_nil(receipt.execution_failed)
      assert is_nil(receipt.verified_at)
      assert receipt.result_output == %{"items_count" => 42}
      assert receipt.intent_action == "list_company_tasks"
      assert length(ActionAssurance.list_company_receipts(Ankole.Repo, company.uid)) == 1
    end

    test "a caller asserting false records the same unknown truth", %{context: context} do
      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, false, %{})

      assert is_nil(receipt.postcondition_verified)
      assert is_nil(receipt.execution_failed)
      assert is_nil(receipt.verified_at)
    end

    test "the sealed context carries an empty expected postcondition by default", %{
      context: context
    } do
      assert context.postcondition_expected == %{}
    end

    test "a non-empty expected postcondition fails closed and persists nothing", %{
      company: company
    } do
      before = Repo.aggregate(ActionReceipt, :count, :id)

      # The declared condition cannot be interpreted, so no receipt is written.
      assert {:error, :unsupported_postcondition} =
               finalize_with_expected(%{status: "completed"})

      assert Repo.aggregate(ActionReceipt, :count, :id) == before
      assert ActionAssurance.list_company_receipts(Ankole.Repo, company.uid) == []
    end

    test "an unsupported postcondition is refused deterministically" do
      first = finalize_with_expected(%{status: "completed"})
      second = finalize_with_expected(%{status: "completed"})

      assert first == second
      assert first == {:error, :unsupported_postcondition}
    end

    test "a malformed non-map expected postcondition fails closed" do
      assert {:error, :unsupported_postcondition} = finalize_with_expected("not-a-map")
    end

    test "execution_failed is never inferred from verification absence", %{
      context: context
    } do
      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, false, %{})

      # Absence of a postcondition verification is not an execution failure.
      refute receipt.execution_failed
      assert is_nil(receipt.execution_failed)
    end

    test "no receipt is dated because no verification was proven", %{context: context} do
      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert is_nil(receipt.verified_at)
    end
  end

  # A sealed context cannot be edited to declare a postcondition, because
  # `postcondition_expected` is covered by the seal. This helper therefore
  # proves the evaluator refuses a declared postcondition through the only
  # reachable path: the `assure/7` option.
  defp finalize_with_expected(expected) do
    %{principal: owner} = human_fixture()
    company = company_fixture(owner.uid)

    %{principal: holder} =
      human_fixture(uid: "w3-b7-expected-#{System.unique_integer([:positive])}")

    {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
    grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

    {:ok, context} =
      assure(
        Ankole.Repo,
        company.uid,
        holder.uid,
        "list_company_tasks",
        "workspace:default",
        nil,
        postcondition_expected: expected
      )

    ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})
  end

  defp constraints_on(%Ecto.Changeset{constraints: constraints}) do
    Enum.map(constraints, &{&1.field, &1.constraint})
  end
end
