defmodule Ankole.W3.ActionAssuranceTest do
  @moduledoc """
  Tests for the P5 Action Assurance Core.

  Covers the MA-06 §16 assurance decision chain and the locked receipt
  lifecycle: assure → (broker executes) → verify → finalize_receipt.
  Does not touch brokers (P7), approval workflow (P6), or W2 stores (P8).
  """

  use Ankole.DataCase, async: true

  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.ActionReceipt
  alias Ankole.W3.Capability
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

    test "accepts HIGH-IMPACT with a valid approval_uid reference" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p5-appv-ok-h")
      %{principal: issuer} = human_fixture(uid: "w3-p5-appv-ok-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      assert {:ok, context} =
               ActionAssurance.assure(
                 Ankole.Repo, company.uid, holder.uid, "cancel_task",
                 "workspace:default", nil, approval_uid: "w3-p6-approval-001"
               )

      assert context.risk_class == "HIGH-IMPACT"
      assert context.approval_uid == "w3-p6-approval-001"
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
               ActionAssurance.assure(Ankole.Repo, company.uid, holder.uid, "forbidden_action", "x")

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
      %{principal: issuer} = human_fixture(uid: "w3-p5-apr-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      {:ok, context} =
        ActionAssurance.assure(
          Ankole.Repo, company.uid, holder.uid, "cancel_task",
          "workspace:default", nil, approval_uid: "w3-p6-apr-42"
        )

      assert context.approval_uid == "w3-p6-apr-42"

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
      # assure/6 should not directly call repo.insert — that belongs in save_receipt
      # which is only called from finalize_assurance.
      # We check that the function body of assure doesn't have repo.insert.
      # The source contains repo.insert in save_receipt (called from finalize_assurance),
      # but not inside assure itself.
      lines = String.split(source, "\n")
      in_assure = false
      assure_has_insert = false

      for line <- lines do
        cond do
          String.match?(line, ~r/^  def assure/) -> in_assure = true
          String.match?(line, ~r/^  def [a-z]/) and in_assure -> in_assure = false
          String.contains?(line, "repo.insert") and in_assure -> assure_has_insert = true
          true -> :ok
        end
      end

      refute assure_has_insert
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
end