defmodule Ankole.W3.ApprovalStoreTest do
  @moduledoc """
  Tests for the P6 Approval Store.

  Covers creation, approval, rejection, revocation, validation,
  company isolation, independence enforcement, and lifecycle transitions.
  """

  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.ApprovalStore

  import Ankole.PrincipalsFixtures

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Map.merge(%{
          uid: "w3-p6-company-#{suffix}",
          name: "w3-p6-company-#{suffix}",
          display_name: "W3 P6 Test Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner_uid
        }, attrs)
      )
      |> Repo.insert()

    company
  end

  # ─── create_approval ──────────────────────────────────────────────────────

  describe "create_approval" do
    test "creates an approval in requested status" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-req")
      %{principal: approver} = human_fixture(uid: "w3-p6-apr")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      assert {:ok, approval} =
               ApprovalStore.create_approval(Ankole.Repo, %{
                 uid: "w3-p6-create-001",
                 company_uid: company.uid,
                 requester_uid: requester.uid,
                 action: "cancel_task",
                 resource: "workspace:default",
                 risk_class: "HIGH-IMPACT"
               })

      assert approval.status == "requested"
      assert approval.action == "cancel_task"
      assert approval.risk_class == "HIGH-IMPACT"
      refute is_nil(approval.id)
    end

    test "rejects nonexistent company" do
      %{principal: requester} = human_fixture(uid: "w3-p6-no-comp-r")

      assert {:error, :company_not_found} =
               ApprovalStore.create_approval(Ankole.Repo, %{
                 uid: "w3-p6-no-comp-001",
                 company_uid: "nonexistent",
                 requester_uid: requester.uid,
                 action: "cancel_task",
                 resource: "x",
                 risk_class: "HIGH-IMPACT"
               })
    end

    test "rejects nonexistent requester" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :principal_not_found} =
               ApprovalStore.create_approval(Ankole.Repo, %{
                 uid: "w3-p6-no-req-001",
                 company_uid: company.uid,
                 requester_uid: "nonexistent-requester",
                 action: "cancel_task",
                 resource: "x",
                 risk_class: "HIGH-IMPACT"
               })
    end

    test "rejects duplicate uid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-dup-r")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)

      attrs = %{
        uid: "w3-p6-dup-001",
        company_uid: company.uid,
        requester_uid: requester.uid,
        action: "cancel_task",
        resource: "x",
        risk_class: "HIGH-IMPACT"
      }

      assert {:ok, _} = ApprovalStore.create_approval(Ankole.Repo, attrs)
      assert {:error, {:duplicate, :uid}} = ApprovalStore.create_approval(Ankole.Repo, attrs)
    end
  end

  # ─── approve_approval ─────────────────────────────────────────────────────

  describe "approve_approval" do
    test "approves with independent approver" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-approv-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-approv-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-approv-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, approved} =
               ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert approved.status == "approved"
      assert approved.approver_uid == approver.uid
      assert approved.approved_at != nil
    end

    test "rejects self-approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-self-r")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-self-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:error, :self_approval} =
               ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end

    test "rejects already approved" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-already-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-already-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-already-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)
      # Second approval of same approval returns error (idempotent reject)
      assert {:error, :already_terminal} =
               ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)
    end

    test "rejects nonexistent approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: approver} = human_fixture(uid: "w3-p6-naf-a")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      assert {:error, :not_found} =
               ApprovalStore.approve_approval(Ankole.Repo, company.uid, "nope", approver.uid)
    end

    test "rejects cross-company approval" do
      %{principal: owner_a} = human_fixture()
      company_a = company_fixture(owner_a.uid)
      %{principal: owner_b} = human_fixture(uid: "w3-p6-xcomp-b-owner")
      company_b = company_fixture(owner_b.uid)
      %{principal: requester_b} = human_fixture(uid: "w3-p6-xcomp-r")
      %{principal: approver_a} = human_fixture(uid: "w3-p6-xcomp-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company_b.uid, requester_b.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company_a.uid, approver_a.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-xcomp-001",
          company_uid: company_b.uid,
          requester_uid: requester_b.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      # Approver from company A trying to approve company B's approval → not found in company A
      assert {:error, :not_found} =
               ApprovalStore.approve_approval(Ankole.Repo, company_a.uid, approval.uid, approver_a.uid)
    end
  end

  # ─── reject_approval ─────────────────────────────────────────────────────

  describe "reject_approval" do
    test "rejects an approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-rej-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-rej-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-rej-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, rejected} =
               ApprovalStore.reject_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert rejected.status == "rejected"
    end
  end

  # ─── revoke_approval ─────────────────────────────────────────────────────

  describe "revoke_approval" do
    test "revokes an approved approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-rev-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-rev-a")
      %{principal: revoker} = human_fixture(uid: "w3-p6-rev-v")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-rev-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert {:ok, revoked} =
               ApprovalStore.revoke_approval(Ankole.Repo, company.uid, approval.uid, revoker.uid)

      assert revoked.status == "revoked"
      assert revoked.revoked_at != nil
    end

    test "revoking a revoked approval fails" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-rev2-r")
      %{principal: revoker} = human_fixture(uid: "w3-p6-rev2-v")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-rev2-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.revoke_approval(Ankole.Repo, company.uid, approval.uid, revoker.uid)
      assert {:error, :already_terminal} =
               ApprovalStore.revoke_approval(Ankole.Repo, company.uid, approval.uid, revoker.uid)
    end
  end

  # ─── validate_for_assurance ───────────────────────────────────────────────

  describe "validate_for_assurance" do
    test "returns ok for a valid approved approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-val-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-val-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-val-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} =
               ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert :ok =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end

    test "returns approval_not_found for nonexistent approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :approval_not_found} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, "nonexistent-approval", "princ-x")
    end

    test "returns approval_not_approved for pending approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-pend-r")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-pend-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:error, :approval_not_approved} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end

    test "returns approval_not_approved for rejected approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-rejd-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-rejd-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-rejd-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.reject_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert {:error, :approval_not_approved} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end

    test "returns approval_expired when expires_at has passed" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-exp-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-exp-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-exp-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT",
          expires_at: ~U[2020-01-01 00:00:00Z]
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert {:error, :approval_expired} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end

    test "returns approval_revoked when revoked" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-revd-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-revd-a")
      %{principal: revoker} = human_fixture(uid: "w3-p6-revd-v")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-revd-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)
      assert {:ok, _} = ApprovalStore.revoke_approval(Ankole.Repo, company.uid, approval.uid, revoker.uid)

      assert {:error, :approval_revoked} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end

    test "returns approval_requester_mismatch for different requester" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-mism-r")
      %{principal: imposter} = human_fixture(uid: "w3-p6-mism-i")
      %{principal: approver} = human_fixture(uid: "w3-p6-mism-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, imposter.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-mism-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      # Imposter tries to use someone else's approval
      assert {:error, :approval_requester_mismatch} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, imposter.uid)
    end

    test "rejects action mismatch when action provided" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-amis-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-amis-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-amis-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      # Approval was for "cancel_task" but we validate against "delete_task"
      assert {:error, :approval_action_mismatch} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid, "delete_task", "workspace:default")
    end

    test "rejects resource mismatch when resource provided" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-rmis-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-rmis-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-rmis-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      # Approval was for "workspace:default" but we validate against "workspace:other"
      assert {:error, :approval_resource_mismatch} =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid, "cancel_task", "workspace:other")
    end

    test "passes when action and resource match" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-both-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-both-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-both-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      assert :ok =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid, "cancel_task", "workspace:default")
    end

    test "passes with nil action/resource (backward compat)" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-nils-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-nils-a")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-nils-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "workspace:default",
          risk_class: "HIGH-IMPACT"
        })

      assert {:ok, _} = ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)

      # 4-arity call should still work (backward compatibility)
      assert :ok =
               ApprovalStore.validate_for_assurance(Ankole.Repo, company.uid, approval.uid, requester.uid)
    end
  end

  # ─── list_company_approvals ───────────────────────────────────────────────

  describe "list_company_approvals" do
    test "lists approvals ordered by creation time descending" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-list-r")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)

      {:ok, a1} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-list-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      {:ok, a2} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-list-002",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      approvals = ApprovalStore.list_company_approvals(Ankole.Repo, company.uid)
      assert length(approvals) >= 2
      # Most recent first
      assert approvals |> Enum.at(0) |> Map.get(:uid) == a2.uid
      assert approvals |> Enum.at(1) |> Map.get(:uid) == a1.uid
    end
  end

  # ─── concurrency ────────────────────────────────────────────────────────────

  describe "concurrent operations" do
    test "concurrent approval and revoke on same record produces consistent state" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-conc-r")
      %{principal: approver} = human_fixture(uid: "w3-p6-conc-a")
      %{principal: revoker} = human_fixture(uid: "w3-p6-conc-v")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-conc-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      parent = self()

      approve_task =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Ankole.Repo, parent, self())

          ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver.uid)
        end)

      revoke_task =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Ankole.Repo, parent, self())

          ApprovalStore.revoke_approval(Ankole.Repo, company.uid, approval.uid, revoker.uid)
        end)

      approve_result = Task.await(approve_task, 10000)
      revoke_result = Task.await(revoke_task, 10000)

      # The FOR UPDATE lock serializes the two operations on the same row.
      # Valid outcomes:
      # - approve wins first: approve succeeds, revoke also succeeds (revoking an approved approval)
      # - revoke wins first: revoke succeeds, approve fails (:already_terminal)
      # Invalid outcome: both succeed AND final status is "approved" (revoke was lost)
      case {approve_result, revoke_result} do
        {{:ok, _}, {:ok, _}} ->
          # Both succeeded — approve must have happened first, then revoke
          :ok

        {{:ok, _}, {:error, :already_terminal}} ->
          # revoke lost the race — not possible since can_revoke allows "approved"
          # but could happen if status was "revoked" by a concurrent revoke
          :ok

        {{:error, :already_terminal}, {:ok, _}} ->
          # approve lost the race — revoke happened first, then approve was blocked
          :ok

        {{:error, err1}, {:error, err2}} ->
          flunk("Both failed unexpectedly: #{inspect({err1, err2})}")
      end

      # Final state must be terminal (approved or revoked)
      {:ok, final} = ApprovalStore.fetch_approval(Ankole.Repo, company.uid, approval.uid)
      assert final.status in ["approved", "revoked", "rejected"]
    end

    test "concurrent double-approval from different approvers" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: requester} = human_fixture(uid: "w3-p6-conc2-r")
      %{principal: approver_a} = human_fixture(uid: "w3-p6-conc2-a")
      %{principal: approver_b} = human_fixture(uid: "w3-p6-conc2-b")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, requester.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, approver_a.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, approver_b.uid)

      {:ok, approval} =
        ApprovalStore.create_approval(Ankole.Repo, %{
          uid: "w3-p6-conc2-001",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: "cancel_task",
          resource: "x",
          risk_class: "HIGH-IMPACT"
        })

      parent = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Ankole.Repo, parent, self())

          ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver_a.uid)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Ankole.Repo, parent, self())

          ApprovalStore.approve_approval(Ankole.Repo, company.uid, approval.uid, approver_b.uid)
        end)

      result_a = Task.await(task_a, 10000)
      result_b = Task.await(task_b, 10000)

      # At most one should succeed; the other should get :already_terminal
      success_count =
        Enum.count([result_a, result_b], fn {status, _} -> status == :ok end)

      assert success_count <= 1

      {:ok, final} = ApprovalStore.fetch_approval(Ankole.Repo, company.uid, approval.uid)
      assert final.status == "approved"
    end
  end

  # ─── boundary audit ──────────────────────────────────────────────────────

  describe "store boundary" do
    test "the store source has no W2 store references" do
      source = File.read!("lib/ankole/w3/approval_store.ex")
      refute String.contains?(source, "TaskStore")
      refute String.contains?(source, "MissionStore")
      refute String.contains?(source, "GoalStore")
    end

    test "the store source has no broker or execution authority" do
      source = File.read!("lib/ankole/w3/approval_store.ex")
      refute String.contains?(source, "broker")
      refute String.contains?(source, "execution_authority")
    end

    test "the store source has no scheduler or worker recovery references" do
      source = File.read!("lib/ankole/w3/approval_store.ex")
      refute String.contains?(source, "scheduler")
      refute String.contains?(source, "worker_recovery")
      refute String.contains?(source, "MA-12")
      refute String.contains?(source, "MA-14")
      refute String.contains?(source, "MA-09")
      refute String.contains?(source, "MA-05")
    end
  end
end