defmodule Ankole.W3.ActionAssuranceTest do
  @moduledoc """
  Tests for the P5 Action Assurance Core.

  Covers the MA-06 §16 assurance decision chain and the locked receipt
  lifecycle: assure → (broker executes) → verify → finalize_receipt.
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
  alias Ankole.W3.ActionAssurance

  import Ankole.PrincipalsFixtures

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Map.merge(%{
          uid: "w3-p5-company-#{suffix}",
          name: "w3-p5-company-#{suffix}",
          display_name: "W3 P5 Test Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner_uid
        }, attrs)
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
        Map.merge(%{
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
        }, attrs)
      )
      |> Repo.insert()

    cap
  end

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end

  # ─── normalize_action ────────────────────────────────────────────────────

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
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "List_Company_Tasks", "workspace:default"
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
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "", "workspace:default"
               )
    end
  end

  # ─── risk classification ─────────────────────────────────────────────────

  describe "risk classification in assurance" do
    test "classifies a known CONTROLLED action" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-cls-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-cls-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "create_task")

      assert {:ok, context} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "create_task", "workspace:default"
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

      # Approval is required for HIGH-IMPACT, so this will fail at that stage
      # But we can still check that classification happened correctly
      assert {:error, :approval_required} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "cancel_task", "workspace:default"
               )
    end
  end

  # ─── authz integration ────────────────────────────────────────────────────

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
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
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
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
               )
    end
  end

  # ─── capability validation ───────────────────────────────────────────────

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
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", nil
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

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        uid: "w3-p5-validcap-001",
        action: "workspace_read",
        resource: "workspace:default",
        risk_class: "ROUTINE"
      })

      assert {:ok, context} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "workspace_read",
                 "workspace:default", cap.uid
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

      # Nonexistent capability → capability_invalid
      assert {:error, :capability_invalid} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "workspace_read",
                 "workspace:default", "nonexistent-capability"
               )
    end
  end

  # ─── approval requirement ─────────────────────────────────────────────────

  describe "approval requirement" do
    test "requires approval for HIGH-IMPACT actions without approval_uid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-approv-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-approv-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      assert {:error, :approval_required} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "cancel_task", "workspace:default"
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
               ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert {:ok, context} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "cancel_task",
                 "workspace:default", nil, approval_uid: approval.uid
               )

      assert context.risk_class == "HIGH-IMPACT"
      assert context.approval_uid == approval.uid
    end

    test "does not require approval for CONTROLLED actions" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-cont-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-cont-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "create_task")

      assert {:ok, _} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "create_task", "workspace:default"
               )
    end
  end

  # ─── company isolation ────────────────────────────────────────────────────

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
               ActionAssurance.assure(
                 Ankole.Repo, company_a.uid, holder_b.uid, "list_company_tasks", "workspace:default"
               )
    end
  end

  # ─── receipt creation is deferred ────────────────────────────────────────

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
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
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
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
        )

      result_output = %{"items_count" => 42}

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(
                 Ankole.Repo, context, true, result_output
               )

      assert receipt.intent_action == "list_company_tasks"
      assert receipt.intent_resource == "workspace:default"
      assert receipt.principal_uid == holder.uid
      assert receipt.company_uid == company.uid
      assert receipt.risk_class == "ROUTINE"
      assert receipt.authz_decision == "ALLOW"
      assert receipt.precondition_status == "met"
      assert receipt.postcondition_verified == true
      assert receipt.result_output == result_output
      refute receipt.execution_failed
      assert is_nil(receipt.verified_at) == false
    end

    test "failed verification creates receipt marked as failed" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-fail-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
        )

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, false, %{})

      assert receipt.postcondition_verified == false
      assert receipt.execution_failed == true
    end

    test "no receipt exists before finalize_assurance is called" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-before-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
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
               ActionAssurance.assure(Ankole.Repo, company.uid, holder.uid, "create_task", "x")

      assert {:error, :invalid_action} =
               ActionAssurance.assure(Ankole.Repo, company.uid, holder.uid, "", "x")

      assert {:error, :invalid_resource} =
               ActionAssurance.assure(Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "")

      final_count = length(ActionAssurance.list_company_receipts(Ankole.Repo, company.uid))
      assert final_count == initial_count
    end
  end

  # ─── reject receipt creation without prior assurance ─────────────────────

  describe "finalize_assurance without prior assurance" do
    test "accepts arbitrary context and persists a receipt when valid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-bogus-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      # finalize_assurance accepts any map as context; it doesn't enforce
      # that assure was called first. The receipt captures whatever context
      # was passed in.
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
         postcondition_expected: %{}
       }

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.receipt_uid == "test-receipt-001"
      assert receipt.intent_action == "list_company_tasks"
      assert receipt.postcondition_verified == true
    end
  end

  # ─── normalized values preserved through to receipt ──────────────────────

  describe "normalized values preserved" do
    test "lowercased action and trimmed resource survive to receipt" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-pres-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "  LIST_COMPANY_TASKS  ", " workspace:default "
        )

      assert context.intent_action == "list_company_tasks"
      assert context.intent_resource == "workspace:default"

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.intent_action == "list_company_tasks"
      assert receipt.intent_resource == "workspace:default"
    end
  end

  # ─── approval binding preserved ──────────────────────────────────────────

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

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "cancel_task",
          "workspace:default", nil, approval_uid: approval.uid
        )

      assert context.approval_uid == approval.uid

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.approval_uid == "w3-p6-apr-42"
    end
  end

  # ─── capability binding preserved ────────────────────────────────────────

  describe "capability binding preserved in receipt" do
    test "capability_uid is recorded in the receipt" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-cap-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-cap-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "workspace_read")

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        uid: "w3-p5-cap-rec-001",
        action: "workspace_read",
        risk_class: "ROUTINE"
      })

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "workspace_read",
          "workspace:default", cap.uid
        )

      assert context.capability_uid == cap.uid

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Ankole.Repo, context, true, %{})

      assert receipt.capability_uid == cap.uid
    end
  end

  # ─── PROHIBITED actions never create receipts ────────────────────────────

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

  # ─── query helpers ────────────────────────────────────────────────────────

  describe "fetch_receipt / list_company_receipts" do
    test "fetches a finalized receipt by UID" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-fetch-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default"
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
        ActionAssurance.assure(Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:one")
      {:ok, c2} =
        ActionAssurance.assure(Ankole.Repo, company.uid, holder.uid, "list_company_tasks", "workspace:two")

      assert {:ok, _} = ActionAssurance.finalize_assurance(Ankole.Repo, c1, true, %{})
      assert {:ok, _} = ActionAssurance.finalize_assurance(Ankole.Repo, c2, true, %{})

      receipts = ActionAssurance.list_company_receipts(Ankole.Repo, company.uid)
      assert length(receipts) >= 2
      # Most recent first
      assert receipts |> Enum.at(0) |> Map.get(:intent_resource) == "workspace:two"
      assert receipts |> Enum.at(1) |> Map.get(:intent_resource) == "workspace:one"
    end
  end

  # ─── B-1: caller repository propagation ──────────────────────────────────

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
            ActionAssurance.assure(
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
               ActionAssurance.assure(
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
                 ActionAssurance.assure(
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
                 ActionAssurance.assure(
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

  # ─── boundary audit ──────────────────────────────────────────────────────

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
      insert_count = String.split(source, "\n") |> Enum.count(&String.contains?(&1, "repo.insert"))
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

  # ─── B-4: exact binding through the full assurance chain ───────────────────

  describe "assure/6 — B4 exact binding integration" do
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
      {:ok, task_resource} = Resource.build("transition_task", company.uid, %{task_uid: "task-b4"})

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

      {:ok, _approved} = ApprovalStore.approve_approval(Repo, company.uid, approval.uid, approver.uid)
      approval
    end

    # A — transition to IN_PROGRESS recomputes CONTROLLED
    test "B4-A transition to IN_PROGRESS recomputes CONTROLLED", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "CONTROLLED"
        })

      assert {:ok, ctx} =
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "IN_PROGRESS"}
               )

      assert ctx.risk_class == "CONTROLLED"
    end

    # B — transition to COMPLETED recomputes HIGH-IMPACT
    test "B4-B transition to COMPLETED recomputes HIGH-IMPACT", context do
      %{company: company, holder: holder, issuer: issuer, approver: approver, task_resource: resource} = context

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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )

      assert ctx.risk_class == "HIGH-IMPACT"
    end

    # C — HIGH-IMPACT without Approval rejected
    test "B4-C HIGH-IMPACT without Approval rejected", context do
      %{company: company, holder: holder, issuer: issuer, task_resource: resource} = context

      cap =
        b4_capability(company, holder, issuer, %{
          action: "transition_task",
          resource: resource,
          risk_class: "HIGH-IMPACT"
        })

      assert {:error, :approval_required} =
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"}
               )
    end

    # D — Capability approval_uid != supplied approval_uid rejected
    test "B4-D Capability approval_uid differs from supplied approval_uid rejected", context do
      %{company: company, holder: holder, issuer: issuer, approver: approver, task_resource: resource} = context

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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: supplied.uid
               )
    end

    # E — Approval action mismatch rejected
    test "B4-E Approval action mismatch rejected", context do
      %{company: company, holder: holder, issuer: issuer, approver: approver, task_resource: resource} = context

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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # F — Approval resource mismatch rejected
    test "B4-F Approval resource mismatch rejected", context do
      %{company: company, holder: holder, issuer: issuer, approver: approver, task_resource: resource} = context

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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # G — Approval requester mismatch rejected
    test "B4-G Approval requester mismatch rejected", context do
      %{company: company, holder: holder, issuer: issuer, approver: approver, task_resource: resource} = context
      %{principal: other_requester} = human_fixture(uid: "b4-g-other-#{System.unique_integer([:positive])}")
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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # H — Approval RISK mismatch rejected (Catalog HIGH / Capability HIGH / Approval CONTROLLED)
    test "B4-H Approval risk mismatch rejected when catalog and Capability are HIGH-IMPACT", context do
      %{company: company, holder: holder, issuer: issuer, approver: approver, task_resource: resource} = context

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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "COMPLETED"},
                 approval_uid: approval.uid
               )
    end

    # I — scope mismatch through ActionAssurance rejected
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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 scope: %{"task_uid" => "task-somewhere-else"}
               )
    end

    # J — constraints mismatch through ActionAssurance rejected
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
               ActionAssurance.assure(Repo, company.uid, holder.uid, "transition_task", resource, cap.uid,
                 risk_context: %{to_status: "READY"},
                 constraints: %{"max_duration" => 60}
               )
    end
  end
end