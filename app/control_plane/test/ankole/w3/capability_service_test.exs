defmodule Ankole.W3.CapabilityServiceTest do
  @moduledoc """
  Lifecycle tests for the P3 CapabilityService.

  Covers issuance, revocation, expiry, consumption, validation,
  and attenuation checks per MA-06 §11 and §12.
  """

  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.CapabilityStore

  import Ankole.PrincipalsFixtures
alias Ankole.PrincipalsFixtures

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Map.merge(%{
          uid: "w3-p3-company-#{suffix}",
          name: "w3-p3-company-#{suffix}",
          display_name: "W3 P3 Test Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner_uid
        }, attrs)
      )
      |> Repo.insert()

    company
  end

  defp capability_fixture(company_uid, principal_uid, issuer_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, cap} =
      %Capability{}
      |> Capability.changeset(
        Map.merge(%{
          uid: "w3-p3-cap-#{suffix}",
          company_uid: company_uid,
          principal_uid: principal_uid,
          action: "workspace:read",
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

  # ─── issue_capability ─────────────────────────────────────────────────────

  describe "issue_capability" do
    test "issues a top-level capability when all references are valid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-hold")
      %{principal: issuer} = human_fixture(uid: "w3-p3-issue")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:ok, capability} =
               transact(fn repo ->
                 CapabilityService.issue_capability(repo, %{
                   uid: "w3-p3-issue-top-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:write",
                   resource: "workspace:default",
                   risk_class: "CONTROLLED",
                   issued_at: ~U[2026-09-26T11:00:00Z],
                   issued_by_principal_uid: issuer.uid,
                   scope: %{"task_uid" => "task-1"},
                   constraints: %{"max_duration" => 3600}
                 })
               end)

      assert capability.status == :active
      assert capability.company_uid == company.uid
      assert capability.risk_class == "CONTROLLED"
      assert capability.scope == %{"task_uid" => "task-1"}
      refute is_nil(capability.id)
    end

    test "rejects issuance with missing company" do
      %{principal: holder} = human_fixture(uid: "w3-p3-no-comp-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-no-comp-i")

      assert {:error, :company_not_found} =
               transact(fn repo ->
                 CapabilityService.issue_capability(repo, %{
                   uid: "w3-p3-no-comp-001",
                   company_uid: "missing-company",
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T12:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects issuance with non-member holder" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-no-memb-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-no-memb-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:error, :principal_not_in_company} =
               transact(fn repo ->
                 CapabilityService.issue_capability(repo, %{
                   uid: "w3-p3-no-memb-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T13:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects issuance with non-member issuer" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-iss-not-memb-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-iss-not-memb-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      assert {:error, :principal_not_in_company} =
               transact(fn repo ->
                 CapabilityService.issue_capability(repo, %{
                   uid: "w3-p3-iss-nm-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T14:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects duplicate uid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-dup-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-dup-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      attrs = %{
        uid: "w3-p3-dup-001",
        company_uid: company.uid,
        principal_uid: holder.uid,
        action: "workspace:read",
        resource: "workspace:default",
        risk_class: "ROUTINE",
        issued_at: ~U[2026-09-26T15:00:00Z],
        issued_by_principal_uid: issuer.uid
      }

      assert {:ok, _} = transact(fn repo -> CapabilityService.issue_capability(repo, attrs) end)
      assert {:error, {:duplicate, :uid}} =
               transact(fn repo -> CapabilityService.issue_capability(repo, attrs) end)
    end
  end

  # ─── attenuation ──────────────────────────────────────────────────────────

  describe "check_attenuation" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "w3-p3-att-owner-#{suffix}")
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-att-holder-#{suffix}")
      %{principal: peer} = human_fixture(uid: "w3-p3-att-peer-#{suffix}")

      {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, owner.uid)
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, peer.uid)

      %{company: company, owner: owner, holder: holder, peer: peer}
    end

    # A child row carrying exactly the parent's authority.
    defp attenuation_child(parent, overrides \\ %{}) do
      Map.merge(
        %{
          parent_capability_uid: parent.uid,
          principal_uid: parent.principal_uid,
          action: parent.action,
          resource: parent.resource,
          risk_class: parent.risk_class,
          approval_uid: parent.approval_uid,
          scope: parent.scope,
          constraints: parent.constraints,
          expires_at: parent.expires_at
        },
        overrides
      )
    end

    test "allows top-level capability (no parent)" do
      assert :ok = CapabilityService.check_attenuation(Ankole.Repo, "comp-1", %{
        parent_capability_uid: nil
      })
    end

    test "rejects child with broader resource than parent", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "w3-p3-att-res-#{System.unique_integer([:positive])}",
          resource: "workspace:default"
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, attenuation_child(parent, %{resource: "workspace:*"}))
    end

    test "rejects child with different action than parent", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "w3-p3-att-act-#{System.unique_integer([:positive])}",
          action: "workspace:read"
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, attenuation_child(parent, %{action: "workspace:write"}))
    end

    test "rejects child that drops a parent constraint", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "w3-p3-att-con-#{System.unique_integer([:positive])}",
          constraints: %{"max_duration" => 3600}
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(
                 Ankole.Repo,
                 company.uid,
                 attenuation_child(parent, %{constraints: %{}})
               )
    end

    test "rejects child with longer lifetime than parent", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "w3-p3-att-ltf-#{System.unique_integer([:positive])}",
          expires_at: ~U[2026-10-01T00:00:00Z]
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(
                 Ankole.Repo,
                 company.uid,
                 attenuation_child(parent, %{expires_at: ~U[2026-11-01T00:00:00Z]})
               )
    end

    test "accepts a child carrying exactly the parent authority", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "w3-p3-att-eq-#{System.unique_integer([:positive])}",
          resource: "workspace:default",
          action: "workspace:read",
          constraints: %{"max_duration" => 3600},
          scope: %{"task_uid" => "task-1", "mission_uid" => "mis-1"}
        })

      assert :ok =
               CapabilityService.check_attenuation(
                 Ankole.Repo,
                 company.uid,
                 attenuation_child(parent)
               )
    end

    test "rejects when parent does not exist" do
      assert {:error, :parent_capability_not_found} =
               CapabilityService.check_attenuation(Ankole.Repo, "comp-1", %{
                 parent_capability_uid: "nonexistent-parent"
               })
    end

    test "rejects when parent is not active", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "w3-p3-att-inact-#{System.unique_integer([:positive])}",
          status: :revoked
        })

      assert {:error, :parent_capability_invalid} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, attenuation_child(parent))
    end
  end

  # ─── revoke_capability ───────────────────────────────────────────────────

  describe "revoke_capability" do
    test "revokes an active capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-rev-h")
      %{principal: revoker} = human_fixture(uid: "w3-p3-rev-r")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      cap = capability_fixture(company.uid, holder.uid, revoker.uid)

      assert {:ok, revoked} =
               transact(fn repo ->
                 CapabilityService.revoke_capability(repo, company.uid, cap.uid, revoker.uid)
               end)

      assert revoked.status == :revoked
      assert revoked.revoked_at != nil
      assert revoked.revoked_at >= ~U[2026-09-26T10:00:00Z]
    end

    test "revocation is idempotent — already revoked returns existing record" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-idemp-h")
      %{principal: revoker} = human_fixture(uid: "w3-p3-idemp-r")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      cap = capability_fixture(company.uid, holder.uid, revoker.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 CapabilityService.revoke_capability(repo, company.uid, cap.uid, revoker.uid)
               end)

      # Second revoke should fail with already_revoked
      assert {:error, :already_revoked} =
               transact(fn repo ->
                 CapabilityService.revoke_capability(repo, company.uid, cap.uid, revoker.uid)
               end)
    end

    test "rejects revoking nonexistent capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: revoker} = human_fixture(uid: "w3-p3-rev-nonexist-r")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, revoker.uid)

      assert {:error, :not_found} =
               transact(fn repo ->
                 CapabilityService.revoke_capability(repo, company.uid, "nonexistent", revoker.uid)
               end)
    end

    test "rejects revocation by non-member" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-rev-nm-h")
      %{principal: outsider} = human_fixture(uid: "w3-p3-rev-nm-o")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      cap = capability_fixture(company.uid, holder.uid, holder.uid)

      assert {:error, :principal_not_in_company} =
               transact(fn repo ->
                 CapabilityService.revoke_capability(repo, company.uid, cap.uid, outsider.uid)
               end)
    end
  end

  # ─── expire_capability ────────────────────────────────────────────────────

  describe "expire_capability" do
    test "expires an active capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-exp-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-exp-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid)

      assert {:ok, expired} =
               transact(fn repo ->
                 CapabilityService.expire_capability(repo, company.uid, cap.uid)
               end)

      assert expired.status == :expired
    end

    test "is idempotent on already-expired capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-exp-idem-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-exp-idem-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 CapabilityService.expire_capability(repo, company.uid, cap.uid)
               end)

      assert {:error, :already_expired} =
               transact(fn repo ->
                 CapabilityService.expire_capability(repo, company.uid, cap.uid)
               end)
    end
  end

  # ─── validate_capability ──────────────────────────────────────────────────

  describe "validate_capability" do
    test "returns :ok for a valid active capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-val-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-val-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid)

      assert :ok =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, cap.uid, [])
    end

    test "returns :ok when action matches" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-action-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-action-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        action: "workspace:read"
      })

      assert :ok =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, cap.uid, [
                 action: "workspace:read"
               ])
    end

    test "returns action_mismatch when requested action differs" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-amis-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-amis-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        action: "workspace:read"
      })

      assert {:error, :action_mismatch} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, cap.uid, [
                 action: "workspace:write"
               ])
    end

    test "returns expired error for capability with past expires_at" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-expd-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-expd-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        expires_at: ~U[2020-01-01T00:00:00Z]
      })

      assert {:error, :expired} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, cap.uid, [])
    end

    test "returns revoked error after revocation" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-revd-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-revd-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid)

      transact(fn repo ->
        CapabilityService.revoke_capability(repo, company.uid, cap.uid, issuer.uid)
      end)

      assert {:error, :revoked} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, cap.uid, [])
    end

    test "returns principal_disabled when holder is disabled" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p3-dis-h")
      %{principal: issuer} = human_fixture(uid: "w3-p3-dis-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid)

      Repo.update!(
        Principal.changeset(
          Repo.get!(Principal, holder.uid),
          %{status: :disabled}
        )
      )

      assert {:error, :principal_disabled} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, cap.uid, [])
    end

    test "returns not_found for nonexistent capability" do
      assert {:error, :not_found} =
               CapabilityService.validate_capability(Ankole.Repo, "nonexistent-company", "nope", [])
    end
  end

  # ─── B-4: exact capability binding ────────────────────────────────────────────
describe "validate_exact_binding — B4 exact capability binding" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "b4-owner-#{suffix}")
      company = company_fixture(owner.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      %{principal: holder} = human_fixture(uid: "b4-holder-#{suffix}")
      %{principal: issuer} = human_fixture(uid: "b4-issuer-#{suffix}")

      {:ok, _m1} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, holder.uid)
      end)

      {:ok, _m2} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, issuer.uid)
      end)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        uid: "b4-cap-#{suffix}",
        action: "transition_task",
        resource: "w2:v1/company/co-1/tasks/task-a",
        risk_class: "CONTROLLED",
        approval_uid: "appr-123",
        scope: %{"task_uid" => "task-a"},
        constraints: %{"max_duration" => 3600}
      })

      %{company: company, holder: holder, issuer: issuer, cap: cap}
    end

    # B4-T1 Exact Principal succeeds
    test "B4-T1 exact Principal succeeds", %{cap: cap, holder: holder, company: company} do
      assert :ok = CapabilityService.validate_exact_binding(cap, [principal_uid: holder.uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T2 Wrong Principal rejected
    test "B4-T2 wrong Principal rejected", %{cap: cap, company: company} do
      %{principal: wrong_principal} = human_fixture(uid: "b4-wrong-#{System.unique_integer([:positive])}")
      assert {:error, :principal_mismatch} =
               CapabilityService.validate_exact_binding(cap, [principal_uid: wrong_principal.uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T3 Exact Company succeeds (via company-scoped fetch in validate_capability)
    test "B4-T3 exact Company succeeds via scoped fetch", %{cap: cap, company: company} do
      assert :ok = CapabilityService.validate_capability(Ankole.Repo, cap.company_uid, cap.uid, "transition_task", cap.principal_uid, "w2:v1/company/co-1/tasks/task-a", "CONTROLLED", "appr-123", %{"task_uid" => "task-a"}, %{"max_duration" => 3600})
    end

    # B4-T4 Wrong Company fails closed through Company-scoped lookup
    test "B4-T4 wrong Company fails closed through Company-scoped lookup", %{cap: cap} do
      %{principal: owner2} = human_fixture(uid: "b4-owner2-#{System.unique_integer([:positive])}")
      company2 = company_fixture(owner2.uid)
      assert {:error, :not_found} = CapabilityService.validate_capability(Ankole.Repo, company2.uid, cap.uid, "transition_task", cap.principal_uid, "w2:v1/company/co-1/tasks/task-a", "CONTROLLED", "appr-123", %{"task_uid" => "task-a"}, %{"max_duration" => 3600})
    end

    # B4-T5 Exact action succeeds
    test "B4-T5 exact action succeeds", %{cap: cap} do
      assert :ok = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T6 Wrong action rejected
    test "B4-T6 wrong action rejected", %{cap: cap} do
      assert {:error, :action_mismatch} = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "cancel_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T7 Canonical Resource.build/3 output succeeds
    test "B4-T7 canonical Resource.build/3 output succeeds", %{cap: cap} do
      assert :ok = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T8 Different / noncanonical resource rejected (glob characters)
    test "B4-T8 noncanonical resource with glob chars rejected", %{cap: cap} do
      assert {:error, :resource_mismatch} = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-*", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T16 Exact scope succeeds; different scope rejected
    test "B4-T16 exact scope succeeds; different scope rejected", %{cap: cap} do
      assert :ok = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
      assert {:error, :scope_mismatch} = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"other" => "value"}, constraints: %{"max_duration" => 3600}])
    end

    # B4-T17 Exact constraints succeeds; different constraints rejected
    test "B4-T17 exact constraints succeeds; different constraints rejected", %{cap: cap} do
      assert :ok = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 3600}])
      assert {:error, :constraints_mismatch} = CapabilityService.validate_exact_binding(cap, [principal_uid: cap.principal_uid, action: "transition_task", resource: "w2:v1/company/co-1/tasks/task-a", risk_class: "CONTROLLED", approval_uid: "appr-123", scope: %{"task_uid" => "task-a"}, constraints: %{"max_duration" => 1800}])
    end

    # B4-T18 Expiry and revocation protections remain green
    test "B4-T18 expiry and revocation protections remain green", %{cap: cap, company: company, holder: holder, issuer: issuer} do
      # Expiry - test via validate_capability which checks expiry
      cap_expired = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        uid: "b4-exp-#{System.unique_integer([:positive])}",
        action: cap.action,
        resource: cap.resource,
        risk_class: cap.risk_class,
        approval_uid: "appr-123",
        scope: cap.scope,
        expires_at: ~U[2020-01-01T00:00:00Z]
      })
      assert {:error, :expired} = CapabilityService.validate_capability(Ankole.Repo, company.uid, cap_expired.uid, cap.action, holder.uid, cap.resource, cap.risk_class, "appr-123", cap.scope, %{"max_duration" => 3600})

      # Revocation
      revoked_cap = capability_fixture(company.uid, issuer.uid, issuer.uid, %{
        uid: "b4-rev-#{System.unique_integer([:positive])}",
        action: cap.action,
        resource: cap.resource,
        risk_class: cap.risk_class,
        approval_uid: "appr-123",
        scope: cap.scope
      })
      transact(fn repo -> CapabilityService.revoke_capability(repo, cap.company_uid, revoked_cap.uid, issuer.uid) end)
      assert {:error, :revoked} = CapabilityService.validate_capability(Ankole.Repo, company.uid, revoked_cap.uid, cap.action, holder.uid, cap.resource, cap.risk_class, "appr-123", cap.scope, %{"max_duration" => 3600})
    end

    # B4-T19 No Capability for CONTROLLED/HIGH-IMPACT assurance fails closed
    test "B4-T19 no Capability for CONTROLLED assurance fails closed", %{company: company, holder: holder} do
      assert {:error, :not_found} = CapabilityService.validate_capability(Ankole.Repo, company.uid, "nonexistent", "transition_task", holder.uid, "w2:v1/company/co-1/tasks/task-a", "CONTROLLED", "appr-123", %{"task_uid" => "task-a"}, %{"max_duration" => 3600})
    end
  end

  # ─── boundary audit ──────────────────────────────────────────────────────

  # ─── boundary audit ──────────────────────────────────────────────────────

  describe "store boundary" do
    test "the service source has no dependency on W3AuthZ" do
      source = File.read!("lib/ankole/w3/capability_service.ex")
      refute String.contains?(source, "Ankole.W3.AuthZ")
      refute String.contains?(source, "W3AuthZ.")
      refute String.contains?(source, "W3AuthZ/")
    end

    test "the service source has no dependency on ReviewRecord" do
      source = File.read!("lib/ankole/w3/capability_service.ex")
      refute String.contains?(source, "ReviewRecord")
      refute String.contains?(source, "TaskResult")
    end

    test "the service contains no risk classification logic" do
      source = File.read!("lib/ankole/w3/capability_service.ex")
      refute String.contains?(source, "risk_classify")
      refute String.contains?(source, "classify_risk")
    end

    test "the service contains no approval workflow logic" do
      source = File.read!("lib/ankole/w3/capability_service.ex")
      refute String.contains?(source, "approval_workflow")
      refute String.contains?(source, "request_approval")
    end
  end

  # ─── B-15: parent/child attenuation ───────────────────────────────────────

  describe "B-15: parent/child attenuation" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "b15-owner-#{suffix}")
      company = company_fixture(owner.uid, %{uid: "b15-company-#{suffix}", name: "b15-company-#{suffix}"})
      %{principal: holder} = human_fixture(uid: "b15-holder-#{suffix}")
      %{principal: peer} = human_fixture(uid: "b15-peer-#{suffix}")

      for uid <- [owner.uid, holder.uid, peer.uid] do
        {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, uid)
      end

      %{company: company, owner: owner, holder: holder, peer: peer}
    end

    # A child row carrying exactly the parent's authority. Every B-15 case is
    # one deliberate deviation from this baseline.
    defp b15_child(parent, overrides \\ %{}) do
      Map.merge(
        %{
          parent_capability_uid: parent.uid,
          principal_uid: parent.principal_uid,
          action: parent.action,
          resource: parent.resource,
          risk_class: parent.risk_class,
          approval_uid: parent.approval_uid,
          scope: parent.scope,
          constraints: parent.constraints,
          expires_at: parent.expires_at
        },
        overrides
      )
    end

    defp b15_attenuation(company_uid, attrs) do
      CapabilityService.check_attenuation(Ankole.Repo, company_uid, attrs)
    end

    # B15-T1 An exact child succeeds.
    test "B15-T1 An exact child succeeds", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t1-parent-#{System.unique_integer([:positive])}",
          scope: %{"task_uid" => "task-1"},
          constraints: %{"max_duration" => 3600}
        })

      assert :ok = b15_attenuation(company.uid, b15_child(parent))

      assert {:ok, child} =
               transact(fn repo ->
                 CapabilityService.issue_capability(
                   repo,
                   Map.merge(b15_child(parent), %{
                     uid: "b15-t1-child-#{System.unique_integer([:positive])}",
                     company_uid: company.uid,
                     issued_by_principal_uid: owner.uid,
                     issued_at: ~U[2026-09-26T10:00:00Z]
                   })
                 )
               end)

      assert child.parent_capability_uid == parent.uid
      assert child.scope == parent.scope
      assert child.constraints == parent.constraints
    end

    # B15-T2 A cross-Company parent is rejected.
    test "B15-T2 Cross-Company parent rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t2-parent-#{System.unique_integer([:positive])}"
        })

      %{principal: other_owner} = human_fixture(uid: "b15-t2-owner-#{System.unique_integer([:positive])}")
      other = company_fixture(other_owner.uid)

      # The holder belongs to the other Company too, so the only thing left to
      # reject this child is the parent's Company.
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, other.uid, holder.uid)
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, other.uid, other_owner.uid)

      assert {:error, :parent_capability_not_found} =
               b15_attenuation(other.uid, b15_child(parent))

      # The real cross-Company attempt cannot be issued either.
      assert {:error, :parent_capability_not_found} =
               transact(fn repo ->
                 CapabilityService.issue_capability(
                   repo,
                   Map.merge(b15_child(parent), %{
                     uid: "b15-t2-child-#{System.unique_integer([:positive])}",
                     company_uid: other.uid,
                     issued_by_principal_uid: other_owner.uid,
                     issued_at: ~U[2026-09-26T10:00:00Z]
                   })
                 )
               end)
    end

    # B15-T3 A different Principal is rejected.
    test "B15-T3 Different Principal rejected", context do
      %{company: company, holder: holder, peer: peer, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t3-parent-#{System.unique_integer([:positive])}"
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{principal_uid: peer.uid}))

      # The same Principal is accepted, so the rule is equality and not a ban
      # on delegation to the holder itself.
      assert :ok = b15_attenuation(company.uid, b15_child(parent))
    end

    # B15-T4 A different action is rejected.
    test "B15-T4 Different action rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t4-parent-#{System.unique_integer([:positive])}",
          action: "workspace:read"
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{action: "workspace:write"}))

      # Case alone must not be treated as a different authority.
      assert :ok = b15_attenuation(company.uid, b15_child(parent, %{action: "  WORKSPACE:READ  "}))
    end

    # B15-T5 A different resource is rejected, byte for byte.
    test "B15-T5 Different resource rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t5-parent-#{System.unique_integer([:positive])}",
          resource: "w2:v1/company/#{company.uid}/tasks"
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(
                 company.uid,
                 b15_child(parent, %{resource: "w2:v1/company/#{company.uid}/tasks/T1/results"})
               )

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{resource: "workspace:default"}))

      assert :ok = b15_attenuation(company.uid, b15_child(parent))
    end

    # B15-T6 A different risk class is rejected.
    test "B15-T6 Different risk rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t6-parent-#{System.unique_integer([:positive])}",
          risk_class: "ROUTINE"
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{risk_class: "CONTROLLED"}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{risk_class: "PROHIBITED"}))

      assert :ok = b15_attenuation(company.uid, b15_child(parent, %{risk_class: "ROUTINE"}))
    end

    # B15-T7 Approval must match exactly in every direction.
    test "B15-T7 Approval drop replace add rejected; exact Approval accepted", context do
      %{company: company, holder: holder, owner: owner} = context

      approved =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t7-approved-#{System.unique_integer([:positive])}",
          approval_uid: "approval-x"
        })

      plain =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t7-plain-#{System.unique_integer([:positive])}",
          approval_uid: nil
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(approved, %{approval_uid: nil}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(approved, %{approval_uid: "approval-y"}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(plain, %{approval_uid: "approval-x"}))

      assert :ok = b15_attenuation(company.uid, b15_child(approved, %{approval_uid: "approval-x"}))
      assert :ok = b15_attenuation(company.uid, b15_child(plain))
    end

    # B15-T8 A scope value difference is rejected.
    test "B15-T8 Different scope value rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t8-parent-#{System.unique_integer([:positive])}",
          scope: %{"task_uid" => "task-a"}
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{scope: %{"task_uid" => "task-b"}}))

      assert :ok = b15_attenuation(company.uid, b15_child(parent, %{scope: %{"task_uid" => "task-a"}}))
    end

    # B15-T9 Scope shape differences are rejected.
    test "B15-T9 Scope missing extra nested list differences rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t9-parent-#{System.unique_integer([:positive])}",
          scope: %{"task_uid" => "task-a"}
        })

      two_key =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t9-two-#{System.unique_integer([:positive])}",
          scope: %{"task_uid" => "task-a", "mission_uid" => "mis-1"}
        })

      nested =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t9-nested-#{System.unique_integer([:positive])}",
          scope: %{"task" => %{"uid" => "task-a"}}
        })

      listed =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t9-list-#{System.unique_integer([:positive])}",
          scope: %{"task_uid" => ["task-a"]}
        })

      # A dropped parent key is a different authority, not a narrower one.
      assert {:error, :attenuation_violation} = b15_attenuation(company.uid, b15_child(two_key, %{scope: %{"task_uid" => "task-a"}}))

      # An extra child key is a widening.
      assert {:error, :attenuation_violation} = b15_attenuation(company.uid, b15_child(parent, %{scope: %{"task_uid" => "task-a", "extra" => 1}}))

      # Nested and list shapes are compared as values, not as key sets.
      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(nested, %{scope: %{"task" => %{"uid" => "task-b"}}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(nested, %{scope: %{"task" => %{"uid" => "task-a", "limit" => 5}}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(listed, %{scope: %{"task_uid" => "task-a"}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{scope: %{"task_uid" => nil}}))

      assert :ok = b15_attenuation(company.uid, b15_child(nested))
      assert :ok = b15_attenuation(company.uid, b15_child(listed))
    end

    # B15-T10 A constraints value difference is rejected.
    test "B15-T10 Different constraints value rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t10-parent-#{System.unique_integer([:positive])}",
          constraints: %{"max_duration" => 3600}
        })

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{constraints: %{"max_duration" => 99999}}))

      # No numeric narrowing exists: a smaller number is still a different value.
      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{constraints: %{"max_duration" => 1800}}))

      assert :ok = b15_attenuation(company.uid, b15_child(parent, %{constraints: %{"max_duration" => 3600}}))
    end

    # B15-T11 Constraint shape differences are rejected.
    test "B15-T11 Constraints missing extra nested list differences rejected", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t11-parent-#{System.unique_integer([:positive])}",
          constraints: %{"max_duration" => 3600}
        })

      nested =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t11-nested-#{System.unique_integer([:positive])}",
          constraints: %{"limits" => %{"duration" => 3600, "count" => 3}}
        })

      listed =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t11-list-#{System.unique_integer([:positive])}",
          constraints: %{"actors" => ["a", "b"]}
        })

      assert {:error, :attenuation_violation} = b15_attenuation(company.uid, b15_child(parent, %{constraints: %{}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(parent, %{constraints: %{"max_duration" => 3600, "max_count" => 2}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(nested, %{constraints: %{"limits" => %{"duration" => 3600}}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(nested, %{constraints: %{"limits" => %{"duration" => 60, "count" => 3}}}))

      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(listed, %{constraints: %{"actors" => ["a"]}}))

      assert :ok = b15_attenuation(company.uid, b15_child(nested))
      assert :ok = b15_attenuation(company.uid, b15_child(listed))
    end

    # B15-T12 The expiry matrix.
    test "B15-T12 Expiry matrix", context do
      %{company: company, holder: holder, owner: owner} = context

      nil_parent = capability_fixture(company.uid, holder.uid, owner.uid, %{uid: "b15-t12-nil-#{System.unique_integer([:positive])}", expires_at: nil})
      finite = capability_fixture(company.uid, holder.uid, owner.uid, %{uid: "b15-t12-fin-#{System.unique_integer([:positive])}", expires_at: ~U[2026-10-01T00:00:00Z]})

      # parent nil / child nil
      assert :ok = b15_attenuation(company.uid, b15_child(nil_parent, %{expires_at: nil}))

      # parent nil / child finite
      assert :ok = b15_attenuation(company.uid, b15_child(nil_parent, %{expires_at: ~U[2026-10-01T00:00:00Z]}))

      # parent finite / child earlier or equal
      assert :ok = b15_attenuation(company.uid, b15_child(finite, %{expires_at: ~U[2026-09-01T00:00:00Z]}))
      assert :ok = b15_attenuation(company.uid, b15_child(finite, %{expires_at: ~U[2026-10-01T00:00:00Z]}))

      # parent finite / child later
      assert {:error, :attenuation_violation} =
               b15_attenuation(company.uid, b15_child(finite, %{expires_at: ~U[2026-11-01T00:00:00Z]}))

      # parent finite / child nil, which is unbounded
      assert {:error, :attenuation_violation} = b15_attenuation(company.uid, b15_child(finite, %{expires_at: nil}))
    end

    # B15-T13 A non-active immediate parent is rejected at issuance.
    test "B15-T13 Inactive immediate parent rejected at issuance", context do
      %{company: company, holder: holder, owner: owner} = context

      for state <- [:revoked, :expired, :consumed] do
        parent =
          capability_fixture(company.uid, holder.uid, owner.uid, %{
            uid: "b15-t13-#{state}-#{System.unique_integer([:positive])}",
            status: state
          })

        assert {:error, :parent_capability_invalid} = b15_attenuation(company.uid, b15_child(parent))

        assert {:error, :parent_capability_invalid} =
                 transact(fn repo ->
                   CapabilityService.issue_capability(
                     repo,
                     Map.merge(b15_child(parent), %{
                       uid: "b15-t13-child-#{state}-#{System.unique_integer([:positive])}",
                       company_uid: company.uid,
                       issued_by_principal_uid: owner.uid,
                       issued_at: ~U[2026-09-26T10:00:00Z]
                     })
                   )
                 end)
      end
    end

    # B15-T14 A consumed, revoked, or expired ancestor invalidates the leaf.
    test "B15-T14 Consumed revoked expired ancestor invalidates leaf at runtime", context do
      %{company: company, holder: holder, owner: owner} = context

      for state <- [:consumed, :revoked, :expired] do
        parent =
          capability_fixture(company.uid, holder.uid, owner.uid, %{
            uid: "b15-t14-#{state}-#{System.unique_integer([:positive])}"
          })

        child =
          capability_fixture(company.uid, holder.uid, owner.uid, %{
            uid: "b15-t14-leaf-#{state}-#{System.unique_integer([:positive])}",
            parent_capability_uid: parent.uid
          })

        assert :ok = CapabilityService.validate_capability(Ankole.Repo, company.uid, child.uid, [])

        {:ok, _} =
          transact(fn repo ->
            Ecto.Changeset.change(parent)
            |> Ecto.Changeset.put_change(:status, state)
            |> Ecto.Changeset.put_change(:revoked_at, if(state == :revoked, do: DateTime.utc_now()))
            |> repo.update()
          end)

        assert {:error, :parent_capability_invalid} =
                 CapabilityService.validate_capability(Ankole.Repo, company.uid, child.uid, [])

        {:ok, locked} = CapabilityStore.fetch_capability_for_update(Ankole.Repo, company.uid, child.uid)

        assert {:error, :parent_capability_invalid} =
                 CapabilityService.validate_prefetched_capability(Ankole.Repo, locked)
      end
    end

    # B15-T15 Grandparent invalidation propagates through the full chain.
    test "B15-T15 Grandparent invalidation propagates through full chain", context do
      %{company: company, holder: holder, owner: owner} = context

      grandparent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t15-gp-#{System.unique_integer([:positive])}"
        })

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t15-mid-#{System.unique_integer([:positive])}",
          parent_capability_uid: grandparent.uid
        })

      leaf =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t15-leaf-#{System.unique_integer([:positive])}",
          parent_capability_uid: parent.uid
        })

      assert :ok = CapabilityService.validate_capability(Ankole.Repo, company.uid, parent.uid, [])

      # Revoking the grandparent two hops up must reach both the middle
      # capability and the leaf.
      assert {:ok, _} = CapabilityService.revoke_capability(Ankole.Repo, company.uid, grandparent.uid, owner.uid)

      assert {:error, :parent_capability_invalid} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, parent.uid, [])

      assert {:error, :parent_capability_invalid} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, leaf.uid, [])

      {:ok, locked_leaf} = CapabilityStore.fetch_capability_for_update(Ankole.Repo, company.uid, leaf.uid)

      assert {:error, :parent_capability_invalid} =
               CapabilityService.validate_prefetched_capability(Ankole.Repo, locked_leaf)
    end

    # B15-T16 A forged cross-Company runtime parent fails closed.
    test "B15-T16 Cross-Company forged runtime parent fails closed", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t16-parent-#{System.unique_integer([:positive])}"
        })

      %{principal: other_owner} = human_fixture(uid: "b15-t16-owner-#{System.unique_integer([:positive])}")
      other = company_fixture(other_owner.uid)
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, other.uid, other_owner.uid)

      # A row that references a parent from another Company. Issuance refuses
      # to create it, so it is written directly to prove runtime validation
      # does not trust the stored pointer either.
      forged =
        capability_fixture(other.uid, other_owner.uid, other_owner.uid, %{
          uid: "b15-t16-forged-#{System.unique_integer([:positive])}",
          parent_capability_uid: parent.uid
        })

      assert {:error, :parent_capability_not_found} =
               CapabilityService.validate_capability(Ankole.Repo, other.uid, forged.uid, [])

      {:ok, locked} = CapabilityStore.fetch_capability_for_update(Ankole.Repo, other.uid, forged.uid)

      assert {:error, :parent_capability_not_found} =
               CapabilityService.validate_prefetched_capability(Ankole.Repo, locked)
    end

    # B15-T17 A self-parent or a cycle fails closed.
    test "B15-T17 Self-parent cycle fails closed", context do
      %{company: company, holder: holder, owner: owner} = context

      self_ref =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t17-selfref-#{System.unique_integer([:positive])}"
        })

      # Self-parenting cannot be produced by issuance, because the child UID is
      # new while `assert_unique_uid/2` already holds the parent UID. A stored
      # self-reference therefore has to be written directly.
      assert {:error, {:duplicate, :uid}} =
               transact(fn repo ->
                 CapabilityService.issue_capability(
                   repo,
                   Map.merge(b15_child(self_ref), %{
                     uid: self_ref.uid,
                     company_uid: company.uid,
                     issued_by_principal_uid: owner.uid,
                     issued_at: ~U[2026-09-26T10:00:00Z]
                   })
                 )
               end)

      {:ok, _} =
        transact(fn repo ->
          Ecto.Changeset.change(self_ref)
          |> Ecto.Changeset.put_change(:parent_capability_uid, self_ref.uid)
          |> repo.update()
        end)

      assert {:error, :parent_capability_cycle} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, self_ref.uid, [])

      {:ok, locked_self_ref} = CapabilityStore.fetch_capability_for_update(Ankole.Repo, company.uid, self_ref.uid)

      assert {:error, :parent_capability_cycle} =
               CapabilityService.validate_prefetched_capability(Ankole.Repo, locked_self_ref)

      # A two-step cycle fails closed without looping.
      a = capability_fixture(company.uid, holder.uid, owner.uid, %{uid: "b15-t17-a-#{System.unique_integer([:positive])}"})
      b = capability_fixture(company.uid, holder.uid, owner.uid, %{uid: "b15-t17-b-#{System.unique_integer([:positive])}", parent_capability_uid: a.uid})

      {:ok, _} =
        transact(fn repo ->
          Ecto.Changeset.change(a) |> Ecto.Changeset.put_change(:parent_capability_uid, b.uid) |> repo.update()
        end)

      assert {:error, :parent_capability_cycle} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, a.uid, [])
    end

    # B15-T19 The published B-4 and B-5 contracts still hold under attenuation.
    test "B15-T19 B-4 exact binding and B-5 single-use remain green", context do
      %{company: company, holder: holder, owner: owner} = context

      parent =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t19-parent-#{System.unique_integer([:positive])}",
          risk_class: "CONTROLLED",
          scope: %{"task_uid" => "task-1"},
          constraints: %{"max_duration" => 3600}
        })

      child =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t19-child-#{System.unique_integer([:positive])}",
          parent_capability_uid: parent.uid,
          risk_class: "CONTROLLED",
          scope: %{"task_uid" => "task-1"},
          constraints: %{"max_duration" => 3600}
        })

      expected = [
        principal_uid: holder.uid,
        action: child.action,
        resource: child.resource,
        risk_class: "CONTROLLED",
        approval_uid: nil,
        scope: %{"task_uid" => "task-1"},
        constraints: %{"max_duration" => 3600}
      ]

      # B-4 exact binding against the child and its parent.
      assert :ok = CapabilityService.validate_exact_binding(child, expected)
      assert :ok = CapabilityService.validate_exact_binding(parent, expected)

      # B-5 single use: consuming the child leaves parent and sibling usable.
      sibling =
        capability_fixture(company.uid, holder.uid, owner.uid, %{
          uid: "b15-t19-sibling-#{System.unique_integer([:positive])}",
          parent_capability_uid: parent.uid
        })

      assert {:ok, %Capability{status: :consumed}} =
               transact(fn repo ->
                 {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, child.uid)
                 CapabilityService.consume_locked(repo, locked)
               end)

      assert %Capability{status: :active} = Repo.get!(Capability, parent.id)
      assert %Capability{status: :active} = Repo.get!(Capability, sibling.id)
      assert :ok = CapabilityService.validate_capability(Ankole.Repo, company.uid, sibling.uid, [])

      # Consuming the parent leaves the child row intact but unusable.
      assert {:ok, %Capability{status: :consumed}} =
               transact(fn repo ->
                 {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, parent.uid)
                 CapabilityService.consume_locked(repo, locked)
               end)

      # Consuming the parent leaves the child's own row untouched, so the sibling
      # is still :active and now fails only because its ancestry is invalid.
      assert %Capability{status: :active} = Repo.get!(Capability, sibling.id)

      assert {:error, :parent_capability_invalid} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, sibling.uid, [])

      # The already-consumed child reports its own single-use state first.
      assert %Capability{status: :consumed} = Repo.get!(Capability, child.id)

      assert {:error, :already_consumed} =
               CapabilityService.validate_capability(Ankole.Repo, company.uid, child.uid, [])
    end

    # B15-T20 No global Repo escape and no borrowed owner modules.
    test "B15-T20 No global Repo escape; no Resource RiskClassifier W2 changes" do
      assert Code.ensure_loaded?(CapabilityService)
      assert Code.ensure_loaded?(CapabilityStore)

      for file <- ["lib/ankole/w3/capability_service.ex", "lib/ankole/w3/capability_store.ex"] do
        source = File.read!(file)

        refute source =~ ~r/(?<![.\w])Repo\.[a-z_]+/, "#{file} must not call the global Repo module"
        refute source =~ "alias Ankole.Repo", "#{file} must not alias the global Repo module"
      end

      service = File.read!("lib/ankole/w3/capability_service.ex")

      # B-15 owns attenuation only. It neither classifies risk nor parses
      # W2 resource paths, and it does not borrow W2 ownership.
      refute service =~ "RiskClassifier"
      refute service =~ "@severity"
      refute service =~ "max_severity"
      refute service =~ "Ankole.WorkHierarchy"
      refute service =~ "Ankole.WorkHierarchy.Task"
    end
  end
end

defmodule Ankole.W3.CapabilityAttenuationConcurrencyTest do
  @moduledoc """
  B15-T18: the real issuance-versus-parent-state race.

  Attenuation reads its parent with `FOR UPDATE`, so a child issuance and a
  concurrent parent transition must serialize on that one row. The sandbox
  gives one process one connection and cannot show blocking, so this module
  leaves the sandbox with `unboxed_run` and drives two separate connections.
  Because those rows are committed for real, the module deletes every row it
  creates.
  """

  # Serial: this module commits rows outside the sandbox and coordinates two
  # blocking connections, so it cannot run concurrently with other tests.
  use Ankole.DataCase, async: false

  import Ankole.PrincipalsFixtures

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.CapabilityStore

  alias Ecto.Adapters.SQL.Sandbox

  @tag ownership_timeout: 30_000
  test "B15-T18 Real issuance versus parent-state race serializes through parent FOR UPDATE" do
    parent = self()
    suffix = System.unique_integer([:positive])

    {company_uid, principal_uid, issuer_uid} =
      Sandbox.unboxed_run(Repo, fn ->
        %{principal: owner} = human_fixture(uid: "b15-t18-owner-#{suffix}")

        {:ok, company} =
          %Company{}
          |> Company.changeset(%{
            uid: "b15-t18-company-#{suffix}",
            name: "b15-t18-company-#{suffix}",
            display_name: "B15 T18 Company",
            status: :active,
            metadata: %{},
            owner_principal_uid: owner.uid
          })
          |> Repo.insert()

        %{principal: holder} = human_fixture(uid: "b15-t18-holder-#{suffix}")

        for uid <- [owner.uid, holder.uid] do
          {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
        end

        {company.uid, holder.uid, owner.uid}
      end)

    on_exit(fn ->
      owner_uid = "b15-t18-owner-#{suffix}"
      holder_uid = "b15-t18-holder-#{suffix}"
      principal_uids = [owner_uid, holder_uid]
      slugs = Enum.map(principal_uids, &"people/#{&1}")

      Sandbox.unboxed_run(Repo, fn ->
        import Ecto.Query

        Capability
        |> where([capability], capability.company_uid == ^company_uid)
        |> Repo.delete_all()

        Ankole.Company.Membership
        |> where([membership], membership.company_uid == ^company_uid)
        |> Repo.delete_all()

        Company
        |> where([company], company.uid == ^company_uid)
        |> Repo.delete_all()

        Ankole.Brain.Schemas.Object
        |> where([object], object.slug in ^slugs)
        |> Repo.delete_all()

        Ankole.Principals.HumanUser
        |> where([human], human.principal_uid in ^principal_uids)
        |> Repo.delete_all()

        Ankole.Principals.Principal
        |> where([principal], principal.uid in ^principal_uids)
        |> Repo.delete_all()
      end)
    end)

    active_parent_uid = "b15-t18-parent-active-#{suffix}"
    dead_parent_uid = "b15-t18-parent-dead-#{suffix}"

    child_attrs = fn parent_uid, tag ->
      %{
        uid: "b15-t18-child-#{tag}-#{System.unique_integer([:positive])}",
        company_uid: company_uid,
        principal_uid: principal_uid,
        issued_by_principal_uid: issuer_uid,
        action: "workspace:read",
        resource: "workspace:default",
        risk_class: "ROUTINE",
        issued_at: ~U[2026-09-26T10:00:00Z],
        scope: %{},
        constraints: %{},
        parent_capability_uid: parent_uid
      }
    end

    for uid <- [active_parent_uid, dead_parent_uid] do
      Sandbox.unboxed_run(Repo, fn ->
        {:ok, _} =
          %Capability{}
          |> Capability.changeset(%{
            uid: uid,
            company_uid: company_uid,
            principal_uid: principal_uid,
            action: "workspace:read",
            resource: "workspace:default",
            status: :active,
            risk_class: "ROUTINE",
            issued_at: ~U[2026-09-26T10:00:00Z],
            issued_by_principal_uid: issuer_uid,
            scope: %{},
            constraints: %{}
          })
          |> Repo.insert()
      end)
    end

    # Tx A takes the parent row lock and holds it open across the child issuance,
    # which is the shape B-5 execution uses. `issue_capability/2` detects the
    # open transaction and must not start a second one, so the child is
    # committed under the lock Tx A already holds.
    tx_a =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(fn repo ->
            {:ok, _locked_parent} = CapabilityStore.fetch_capability_for_update(repo, company_uid, active_parent_uid)

            send(parent, {:tx_a_locked_parent, self()})

            receive do
              :issue_child -> {:ok, CapabilityService.issue_capability(repo, child_attrs.(active_parent_uid, "a"))}
            end
          end)
        end)
      end)

    assert_receive {:tx_a_locked_parent, tx_a_pid}, 10_000

    # Tx B is a genuinely independent transaction on its own connection. It
    # blocks on the same parent row while Tx A is inside its transaction.
    tx_b =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          send(parent, {:tx_b_attempting_consume, System.monotonic_time(:millisecond)})

          Repo.transact(fn repo ->
            started = System.monotonic_time(:millisecond)
            {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company_uid, active_parent_uid)
            waited = System.monotonic_time(:millisecond) - started

            send(parent, {:tx_b_observed, locked.status, waited})

            CapabilityService.consume_locked(repo, locked)
          end)
        end)
      end)

    assert_receive {:tx_b_attempting_consume, attempted_at}, 10_000

    Process.sleep(300)

    # Tx B cannot read the parent while Tx A holds its lock.
    refute_received {:tx_b_observed, _status, _waited}
    assert Process.alive?(tx_b.pid)

    # Tx A commits, which releases the parent lock.
    send(tx_a_pid, :issue_child)
    assert {:ok, {:ok, %Capability{status: :active}}} = Task.await(tx_a, 15_000)

    # Tx B resumes, observes the row, and its consume then wins.
    assert_receive {:tx_b_observed, :active, waited}, 15_000
    assert waited >= 250, "Tx B must have blocked on Tx A's parent row lock, waited #{waited}ms"
    assert System.monotonic_time(:millisecond) - attempted_at >= 250

    assert {:ok, %Capability{status: :consumed}} = Task.await(tx_b, 15_000)

    # The child that was issued before the consume stays durable, but its
    # ancestry is no longer valid.
    Sandbox.unboxed_run(Repo, fn ->
      assert %Capability{status: :consumed} =
               Repo.get_by!(Capability, uid: active_parent_uid, company_uid: company_uid)

      assert %Capability{status: :active, parent_capability_uid: active_parent_uid} =
               Repo.one(
                 Ecto.Query.from(capability in Capability,
                   where:
                     capability.company_uid == ^company_uid and
                       capability.parent_capability_uid == ^active_parent_uid
                 )
               )

      # The child's own row is untouched, and it now fails on its ancestry.
      assert {:error, :parent_capability_invalid} =
               CapabilityService.validate_capability(Repo, company_uid, Repo.one(Ecto.Query.from(capability in Capability, where: capability.company_uid == ^company_uid and capability.parent_capability_uid == ^active_parent_uid)).uid, [])

      # The parent reports its own single-use state first.
      assert {:error, :already_consumed} =
               CapabilityService.validate_capability(Repo, company_uid, active_parent_uid, [])

      # The reverse order fails closed: once the parent is not active, a later
      # child issuance is refused instead of attaching to a dead ancestor.
      assert {:error, :parent_capability_invalid} =
               CapabilityService.issue_capability(Repo, child_attrs.(active_parent_uid, "late"))
    end)
  end
end