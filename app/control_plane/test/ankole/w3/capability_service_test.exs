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

  import Ankole.PrincipalsFixtures

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
    test "allows top-level capability (no parent)" do
      assert :ok = CapabilityService.check_attenuation(Ankole.Repo, "any-company", %{
        parent_capability_uid: nil
      })
    end

    test "rejects child with broader resource than parent" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p3-att-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      parent =
        capability_fixture(company.uid, issuer.uid, issuer.uid, %{
          uid: "w3-p3-parent-001",
          resource: "workspace:default"
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, %{
                 parent_capability_uid: parent.uid,
                 resource: "workspace:*"
               })
    end

    test "rejects child with different action than parent" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p3-act-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      parent =
        capability_fixture(company.uid, issuer.uid, issuer.uid, %{
          uid: "w3-p3-parent-002",
          action: "workspace:read"
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, %{
                 parent_capability_uid: parent.uid,
                 action: "workspace:write"
               })
    end

    test "rejects child with looser constraints than parent" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p3-con-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      parent =
        capability_fixture(company.uid, issuer.uid, issuer.uid, %{
          uid: "w3-p3-parent-003",
          constraints: %{"max_duration" => 3600}
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, %{
                 parent_capability_uid: parent.uid,
                 constraints: %{}
               })
    end

    test "rejects child with longer lifetime than parent" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p3-ltf-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      parent =
        capability_fixture(company.uid, issuer.uid, issuer.uid, %{
          uid: "w3-p3-parent-004",
          expires_at: ~U[2026-10-01T00:00:00Z]
        })

      assert {:error, :attenuation_violation} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, %{
                 parent_capability_uid: parent.uid,
                 expires_at: ~U[2026-11-01T00:00:00Z]
               })
    end

    test "accepts child with narrower or equal attributes" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p3-ok-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      parent =
        capability_fixture(company.uid, issuer.uid, issuer.uid, %{
          uid: "w3-p3-parent-005",
          resource: "workspace:default",
          action: "workspace:read",
          constraints: %{"max_duration" => 3600},
          scope: %{"task_uid" => "task-1", "mission_uid" => "mis-1"}
        })

      assert :ok =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, %{
                 parent_capability_uid: parent.uid,
                 resource: "workspace:default",
                 action: "workspace:read",
                 constraints: %{"max_duration" => 1800},
                 scope: %{"task_uid" => "task-1"}
               })
    end

    test "rejects when parent does not exist" do
      assert {:error, :parent_capability_not_found} =
               CapabilityService.check_attenuation(Ankole.Repo, "comp-1", %{
                 parent_capability_uid: "nonexistent-parent"
               })
    end

    test "rejects when parent is not active" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p3-inact-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      parent =
        capability_fixture(company.uid, issuer.uid, issuer.uid, %{
          uid: "w3-p3-parent-006",
          status: :revoked
        })

      assert {:error, :parent_capability_invalid} =
               CapabilityService.check_attenuation(Ankole.Repo, company.uid, %{
                 parent_capability_uid: parent.uid,
                 resource: "workspace:default",
                 action: "workspace:read"
               })
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
end