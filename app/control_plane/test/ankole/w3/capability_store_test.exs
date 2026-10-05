defmodule Ankole.W3.CapabilityStoreTest do
  @moduledoc """
  Store-level tests for the P2 Capability persistence layer.

  These tests exercise create, fetch, list, uniqueness, company isolation,
  and the security-boundary proof: a valid Principal plus a valid P1 AuthZ
  grant in Company A still cannot retrieve a Capability from Company B.
  """

  use Ankole.DataCase, async: true

  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.AuthZ, as: W3AuthZ
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityStore

  import Ankole.PrincipalsFixtures
  alias Ankole.W3.CapabilityService

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Map.merge(%{
          uid: "w3-p2-company-#{suffix}",
          name: "w3-p2-company-#{suffix}",
          display_name: "W3 P2 Test Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner_uid
        }, attrs)
      )
      |> Repo.insert()

    company
  end

  defp capability_fixture(company_uid, principal_uid, issued_by_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, capability} =
      %Capability{}
      |> Capability.changeset(
        Map.merge(%{
          uid: "w3-p2-cap-#{suffix}",
          company_uid: company_uid,
          principal_uid: principal_uid,
          action: "workspace:read",
          resource: "workspace:default",
          status: :active,
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26T10:00:00Z],
          issued_by_principal_uid: issued_by_uid,
          scope: %{},
          constraints: %{},
          metadata: %{}
        }, attrs)
      )
      |> Repo.insert()

    capability
  end

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end

  # ─── create_capability ────────────────────────────────────────────────────

  describe "create_capability" do
    test "creates a capability when all references are valid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-holder")
      %{principal: issuer} = human_fixture(uid: "w3-p2-issuer")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:ok, capability} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-create-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:write",
                   resource: "workspace:default",
                   risk_class: "CONTROLLED",
                   issued_at: ~U[2026-09-26T10:00:00Z],
                   issued_by_principal_uid: issuer.uid,
                   scope: %{"task_uid" => "task-1"},
                   constraints: %{"max_duration" => 3600},
                   metadata: %{"source" => "bootstrap"}
                 })
               end)

      assert capability.company_uid == company.uid
      assert capability.principal_uid == holder.uid
      assert capability.issued_by_principal_uid == issuer.uid
      assert capability.status == :active
      assert capability.risk_class == "CONTROLLED"
      assert capability.action == "workspace:write"
      assert capability.resource == "workspace:default"
      assert capability.scope == %{"task_uid" => "task-1"}
      assert capability.constraints == %{"max_duration" => 3600}
      assert capability.metadata == %{"source" => "bootstrap"}
      refute is_nil(capability.id)
    end

    test "lowercases action on insert" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-lower")
      %{principal: issuer} = human_fixture(uid: "w3-p2-lower-iss")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:ok, capability} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-lower-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "Workspace:READ",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T11:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)

      assert capability.action == "workspace:read"
    end

    test "defaults scope, constraints, and metadata to empty maps" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-default-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-default-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:ok, capability} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-default-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T12:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)

      assert capability.scope == %{}
      assert capability.constraints == %{}
      assert capability.metadata == %{}
    end

    test "accepts nullable lifecycle fields at creation" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-lifecycle-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-lifecycle-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:ok, capability} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-lifecycle-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "CONTROLLED",
                   issued_at: ~U[2026-09-26T13:00:00Z],
                   issued_by_principal_uid: issuer.uid,
                   expires_at: ~U[2026-10-26T13:00:00Z],
                   approval_uid: "approval-uid"
                 })
               end)

      assert capability.expires_at >= ~U[2026-10-26T13:00:00Z]
      assert capability.approval_uid == "approval-uid"
    end

    test "rejects nonexistent company" do
      %{principal: holder} = human_fixture(uid: "w3-p2-nonexist-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-nonexist-i")

      assert {:error, :company_not_found} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-ne-001",
                   company_uid: "nonexistent-company",
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T14:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects nonexistent principal (holder)" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: issuer} = human_fixture(uid: "w3-p2-holder-miss-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:error, :principal_not_found} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-hm-001",
                   company_uid: company.uid,
                   principal_uid: "nonexistent-holder",
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T15:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects nonexistent principal (issuer)" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-iss-miss-h")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      assert {:error, :principal_not_found} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-im-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T16:00:00Z],
                   issued_by_principal_uid: "nonexistent-issuer"
                 })
               end)
    end

    test "rejects disabled holder" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-dis-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-dis-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      Repo.update!(
        Principal.changeset(
          Repo.get!(Principal, holder.uid),
          %{status: :disabled}
        )
      )

      assert {:error, :principal_disabled} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-dis-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T17:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects holder not a member of the Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-no-member-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-no-member-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      assert {:error, :principal_not_in_company} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-nm-001",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T18:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects issuer not a member of the Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-iss-not-memb-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-iss-not-memb-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)

      assert {:error, :principal_not_in_company} =
               transact(fn repo ->
                 CapabilityStore.create_capability(repo, %{
                   uid: "w3-p2-im-002",
                   company_uid: company.uid,
                   principal_uid: holder.uid,
                   action: "workspace:read",
                   resource: "workspace:default",
                   risk_class: "ROUTINE",
                   issued_at: ~U[2026-09-26T19:00:00Z],
                   issued_by_principal_uid: issuer.uid
                 })
               end)
    end

    test "rejects duplicate uid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-dup-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-dup-i")

      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      attrs = %{
        uid: "w3-p2-dup-001",
        company_uid: company.uid,
        principal_uid: holder.uid,
        action: "workspace:read",
        resource: "workspace:default",
        risk_class: "ROUTINE",
        issued_at: ~U[2026-09-26T20:00:00Z],
        issued_by_principal_uid: issuer.uid
      }

      assert {:ok, _} = transact(fn repo -> CapabilityStore.create_capability(repo, attrs) end)
      assert {:error, {:duplicate, :uid}} =
               transact(fn repo -> CapabilityStore.create_capability(repo, attrs) end)
    end
  end

  # ─── fetch_capability ─────────────────────────────────────────────────────

  describe "fetch_capability" do
    test "returns the capability within its Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-fetch-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-fetch-i")
      capability = capability_fixture(company.uid, holder.uid, issuer.uid)

      assert {:ok, fetched} =
               transact(fn repo -> CapabilityStore.fetch_capability(repo, company.uid, capability.uid) end)

      assert fetched.uid == capability.uid
      assert fetched.company_uid == company.uid
      assert fetched.principal_uid == holder.uid
      assert fetched.risk_class == "ROUTINE"
      assert fetched.scope == %{}
      assert fetched.constraints == %{}
      assert fetched.metadata == %{}
    end

    test "returns error when uid does not exist in the Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :not_found} =
               transact(fn repo -> CapabilityStore.fetch_capability(repo, company.uid, "nonexistent") end)
    end

    test "returns error when uid exists but belongs to a different Company" do
      %{principal: owner_a} = human_fixture()
      company_a = company_fixture(owner_a.uid)
      %{principal: owner_b} = human_fixture(uid: "w3-p2-fetch-other-owner")
      company_b = company_fixture(owner_b.uid)
      %{principal: holder_b} = human_fixture(uid: "w3-p2-fetch-b-h")
      %{principal: issuer_b} = human_fixture(uid: "w3-p2-fetch-b-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company_b.uid, holder_b.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company_b.uid, issuer_b.uid)

      cap_b = capability_fixture(company_b.uid, holder_b.uid, issuer_b.uid, %{
        uid: "w3-p2-cross-company"
      })

      assert {:error, :not_found} =
               transact(fn repo ->
                 CapabilityStore.fetch_capability(repo, company_a.uid, cap_b.uid)
               end)
    end
  end

  # ─── list_principal_capabilities ──────────────────────────────────────────

  describe "list_principal_capabilities" do
    test "returns only capabilities for the given principal in the given Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: alice} = human_fixture(uid: "w3-p2-list-alice")
      %{principal: bob} = human_fixture(uid: "w3-p2-list-bob")
      %{principal: issuer} = human_fixture(uid: "w3-p2-list-iss")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, alice.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, bob.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      cap_a = capability_fixture(company.uid, alice.uid, issuer.uid)
      cap_b = capability_fixture(company.uid, bob.uid, issuer.uid)

      assert [^cap_a] =
                CapabilityStore.list_principal_capabilities(Ankole.Repo, company.uid, alice.uid)

      assert [^cap_b] =
                CapabilityStore.list_principal_capabilities(Ankole.Repo, company.uid, bob.uid)

      assert [] =
                CapabilityStore.list_principal_capabilities(Ankole.Repo, company.uid, "nonexistent-person")
    end
  end

  # ─── list_company_capabilities ────────────────────────────────────────────

  describe "list_company_capabilities" do
    test "returns all capabilities inside one Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: alice} = human_fixture(uid: "w3-p2-lcc-alice")
      %{principal: bob} = human_fixture(uid: "w3-p2-lcc-bob")
      %{principal: issuer} = human_fixture(uid: "w3-p2-lcc-iss")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company.uid, alice.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company.uid, bob.uid)
      assert {:ok, _m3} = MembershipStore.add_member(Ankole.Repo, company.uid, issuer.uid)

      _cap_alice = capability_fixture(company.uid, alice.uid, issuer.uid)
      _cap_bob = capability_fixture(company.uid, bob.uid, issuer.uid)

      result =
        CapabilityStore.list_company_capabilities(Ankole.Repo, company.uid)

      assert length(result) == 2
    end

    test "returns empty list for a Company with no capabilities" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert [] =
                CapabilityStore.list_company_capabilities(Ankole.Repo, company.uid)
    end
  end

  # ─── capability? ─────────────────────────────────────────────────────────

  describe "capability?/3" do
    test "reports true when the capability exists in the Company" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-yes-h")
      %{principal: issuer} = human_fixture(uid: "w3-p2-yes-i")
      capability = capability_fixture(company.uid, holder.uid, issuer.uid)

      assert CapabilityStore.capability?(Ankole.Repo, company.uid, capability.uid)
    end

    test "reports false when the capability exists but belongs to another Company" do
      %{principal: owner_a} = human_fixture()
      company_a = company_fixture(owner_a.uid)
      %{principal: owner_b} = human_fixture(uid: "w3-p2-no-b-owner")
      company_b = company_fixture(owner_b.uid)
      %{principal: holder_b} = human_fixture(uid: "w3-p2-no-b-h")
      %{principal: issuer_b} = human_fixture(uid: "w3-p2-no-b-i")

      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company_b.uid, holder_b.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company_b.uid, issuer_b.uid)

      capability_fixture(company_b.uid, holder_b.uid, issuer_b.uid, %{
        uid: "w3-p2-no-exists"
      })

      refute CapabilityStore.capability?(Ankole.Repo, company_a.uid, "w3-p2-no-exists")
    end
  end

  # ─── security boundary ──────────────────────────────────────────────────

  describe "security boundary: cross-Company access fails closed" do
    test "valid Principal + valid W3AuthZ + wrong Company = NOT FOUND" do
      %{principal: owner_a} = human_fixture()
      company_a = company_fixture(owner_a.uid)
      %{principal: owner_b} = human_fixture(uid: "w3-p2-sb-b-owner")
      company_b = company_fixture(owner_b.uid)
      %{principal: holder} = human_fixture(uid: "w3-p2-sb-holder")
      %{principal: issuer} = human_fixture(uid: "w3-p2-sb-issuer")
      uid = "w3-p2-sb-capability-uid"

      # Holder belongs to Company B.
      assert {:ok, _m1} = MembershipStore.add_member(Ankole.Repo, company_b.uid, holder.uid)
      assert {:ok, _m2} = MembershipStore.add_member(Ankole.Repo, company_b.uid, issuer.uid)

      # Capability lives in Company B.
      capability_fixture(company_b.uid, holder.uid, issuer.uid, %{uid: uid})

      # Holder is authorized in Company B via P1 AuthZ.
      {:ok, _grant} =
        AuthZ.upsert_permission_grant(%{
          principal_uid: holder.uid,
          company_uid: company_b.uid,
          resource_pattern: "workspace:**",
          action: "read",
          granted_by_principal_uid: issuer.uid
        })

      assert :ok = W3AuthZ.authorize(company_b.uid, holder.uid, "workspace:default", "read")

      # Same valid principal + same valid W3AuthZ + Company A scope = NOT FOUND.
      assert {:error, :not_found} =
               transact(fn repo -> CapabilityStore.fetch_capability(repo, company_a.uid, uid) end)
    end
  end

  # ─── store boundary ──────────────────────────────────────────────────────

  describe "store boundary" do
    test "the store source has no dependency on W3AuthZ" do
      source = File.read!("lib/ankole/w3/capability_store.ex")
      refute String.contains?(source, "Ankole.W3.AuthZ")
      refute String.contains?(source, "W3AuthZ.")
      refute String.contains?(source, "W3AuthZ/")
    end

    test "the store source has no dependency on ReviewRecord" do
      source = File.read!("lib/ankole/w3/capability_store.ex")
      refute String.contains?(source, "ReviewRecord")
      refute String.contains?(source, "TaskResult")
    end

    test "the store contains no update or delete function" do
      source = File.read!("lib/ankole/w3/capability_store.ex")
      refute String.contains?(source, "def update_capability")
      refute String.contains?(source, "def delete_capability")
      # Lifecycle transitions are in CapabilityService, not store
    # Lifecycle transitions are in CapabilityService, not store
    end
  end

  # ─── B-5: Capability Consumption / Non-Replay ───────────────────────────

  describe "B-5: Capability FOR UPDATE fetch and consume_locked" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "b5-owner-#{suffix}")
      company = company_fixture(owner.uid)

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, owner.uid)
      end)

      %{principal: holder} = human_fixture(uid: "b5-holder-#{suffix}")
      %{principal: issuer} = human_fixture(uid: "b5-issuer-#{suffix}")

      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, holder.uid)
      end)
      {:ok, _membership} = transact(fn repo ->
        Ankole.Company.MembershipStore.add_member(repo, company.uid, issuer.uid)
      end)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        uid: "b5-cap-#{suffix}",
        action: "workspace:read",
        resource: "workspace:default",
        risk_class: "CONTROLLED",
        scope: %{"task_uid" => "task-a"},
        constraints: %{"max_duration" => 3600}
      })

      %{company: company, holder: holder, issuer: issuer, cap: cap}
    end

    # B5-T1 Active Capability can be fetched FOR UPDATE and consumed once.
    test "B5-T1 Active Capability can be fetched FOR UPDATE and consumed once", %{company: company, cap: cap} do
      {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert locked.uid == cap.uid
      assert locked.status == :active

      assert {:ok, consumed} = CapabilityService.consume_locked(Repo, locked)
      assert consumed.status == :consumed

      # Verify it's persisted
      refreshed = Repo.get(Capability, consumed.id)
      assert refreshed.status == :consumed
    end

    # B5-T2 Consumed Capability cannot be consumed again.
    test "B5-T2 Consumed Capability cannot be consumed again", %{company: company, cap: cap} do
      {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:ok, _consumed} = CapabilityService.consume_locked(Repo, locked)

      # Re-fetch to get the consumed state
      {:ok, consumed} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:error, :already_consumed} = CapabilityService.consume_locked(Repo, consumed)
    end

    # B5-T3 Consumed Capability fails prefetched operational validation.
    test "B5-T3 Consumed Capability fails prefetched operational validation", %{company: company, cap: cap} do
      {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:ok, _consumed} = CapabilityService.consume_locked(Repo, locked)

      # Re-fetch to get the consumed state
      {:ok, consumed} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:error, :already_consumed} = CapabilityService.validate_prefetched_capability(Repo, consumed)
    end

    # B5-T4 Revoked Capability cannot consume -> :revoked.
    test "B5-T4 Revoked Capability cannot consume -> :revoked", %{company: company, cap: cap} do
      assert {:ok, _} = CapabilityService.revoke_capability(Repo, company.uid, cap.uid, cap.issued_by_principal_uid)

      # Re-fetch to get the revoked state
      {:ok, revoked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:error, :revoked} = CapabilityService.consume_locked(Repo, revoked)
    end

    # B5-T5 A persisted expired Capability is rejected by consume and by validation.
    test "B5-T5 A persisted expired Capability is rejected by consume and by validation", %{company: company, holder: holder, issuer: issuer, cap: cap} do
      # Expire by lifecycle transition: the row keeps no expires_at, so only
      # the lifecycle status proves it is unusable.
      assert {:ok, expired} = CapabilityService.expire_capability(Repo, company.uid, cap.uid)
      assert expired.status == :expired
      assert is_nil(expired.expires_at)

      {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:error, :expired} = CapabilityService.consume_locked(Repo, locked)
      assert {:error, :expired} = CapabilityService.validate_prefetched_capability(Repo, locked)

      # A Capability past its expires_at is rejected before consumption too.
      timed = capability_fixture(company.uid, holder.uid, issuer.uid, %{
        uid: "b5-exp-#{System.unique_integer([:positive])}",
        expires_at: ~U[2020-01-01T00:00:00Z]
      })

      {:ok, timed_locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, timed.uid)
      assert {:error, :expired} = CapabilityService.validate_prefetched_capability(Repo, timed_locked)
    end

    # B5-T6 Wrong Company cannot fetch for update -> :not_found.
    test "B5-T6 Wrong Company cannot fetch for update -> :not_found", %{cap: cap} do
      %{principal: owner2} = human_fixture(uid: "b5-owner2-#{System.unique_integer([:positive])}")
      company2 = company_fixture(owner2.uid)

      assert {:error, :not_found} = CapabilityStore.fetch_capability_for_update(Repo, company2.uid, cap.uid)

      # The same wrong-Company attempt through consumption fails closed too.
      assert {:error, :not_found} =
               CapabilityService.validate_capability(Repo, company2.uid, cap.uid, [])
    end

    # B5-T7 Two sequential replays in separate transactions produce one success.
    test "B5-T7 Two sequential replays in separate transactions produce one success", %{company: company, cap: cap} do
      results =
        for _attempt <- 1..2 do
          transact(fn repo ->
            {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, cap.uid)

            case CapabilityService.consume_locked(repo, locked) do
              {:ok, consumed} -> {:ok, consumed.status}
              {:error, reason} -> {:error, reason}
            end
          end)
        end

      assert [{:ok, :consumed}, {:error, :already_consumed}] = results
      assert %Capability{status: :consumed} = Repo.get!(Capability, cap.id)
    end

    # B5-T9 A rolled back consume leaves the Capability active and reusable.
    test "B5-T9 A rolled back consume leaves the Capability active and reusable", %{company: company, cap: cap} do
      assert {:error, :rolled_back} =
               transact(fn repo ->
                 {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, cap.uid)
                 assert {:ok, %Capability{status: :consumed}} = CapabilityService.consume_locked(repo, locked)
                 Repo.rollback(:rolled_back)
               end)

      assert %Capability{status: :active} = Repo.get!(Capability, cap.id)

      # The row is still consumable, so the rollback released both the update
      # and the row lock.
      assert {:ok, _consumed} =
               transact(fn repo ->
                 {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, cap.uid)
                 CapabilityService.consume_locked(repo, locked)
               end)

      assert %Capability{status: :consumed} = Repo.get!(Capability, cap.id)
    end

    # B5-T10 A failure after consume rolls the whole transaction back.
    test "B5-T10 A failure after consume rolls the whole transaction back", %{company: company, cap: cap} do
      assert {:error, :downstream_failed} =
               transact(fn repo ->
                 {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, cap.uid)
                 assert {:ok, _consumed} = CapabilityService.consume_locked(repo, locked)

                 # A later step of the same action fails, so the consume must
                 # not survive the transaction.
                 Repo.rollback(:downstream_failed)
               end)

      assert %Capability{status: :active} = Repo.get!(Capability, cap.id)
      assert :ok = CapabilityService.validate_capability(Repo, company.uid, cap.uid, [])
    end

    # B5-T11 The B-4 exact binding validator accepts the already-locked struct.
    test "B5-T11 The B-4 exact binding validator accepts the already-locked struct", %{company: company, holder: holder, cap: cap} do
      expected = [
        principal_uid: holder.uid,
        action: cap.action,
        resource: cap.resource,
        risk_class: cap.risk_class,
        approval_uid: nil,
        scope: cap.scope,
        constraints: cap.constraints
      ]

      assert {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert :ok = CapabilityService.validate_exact_binding(locked, expected)
      assert :ok = CapabilityService.validate_prefetched_capability(Repo, locked)

      # A wrong intent on the same locked struct fails closed.
      assert {:error, :principal_mismatch} =
               CapabilityService.validate_exact_binding(
                 locked,
                 Keyword.put(expected, :principal_uid, cap.issued_by_principal_uid)
               )

      assert {:error, :resource_mismatch} =
               CapabilityService.validate_exact_binding(
                 locked,
                 Keyword.put(expected, :resource, "workspace:other")
               )

      assert {:error, :risk_class_mismatch} =
               CapabilityService.validate_exact_binding(
                 locked,
                 Keyword.put(expected, :risk_class, "ROUTINE")
               )
    end

    # B5-T12 The consumption path uses the supplied repo and no global Repo.
    test "B5-T12 The consumption path uses the supplied repo and no global Repo", %{company: company, cap: cap} do
      # Both production functions take the transaction-local repo as their
      # first argument, so the caller decides which connection sees the write.
      assert Code.ensure_loaded?(CapabilityStore)
      assert Code.ensure_loaded?(CapabilityService)
      assert function_exported?(CapabilityStore, :fetch_capability_for_update, 3)
      assert function_exported?(CapabilityService, :consume_locked, 2)
      assert function_exported?(CapabilityService, :validate_prefetched_capability, 2)

      # Neither module calls or aliases the global Repo module.
      for file <- ["lib/ankole/w3/capability_store.ex", "lib/ankole/w3/capability_service.ex"] do
        source = File.read!(file)

        refute source =~ ~r/(?<![.\w])Repo\.[a-z_]+/,
               "#{file} must not call the global Repo module"

        refute source =~ "alias Ankole.Repo",
               "#{file} must not alias the global Repo module"
      end

      # A consume written through the caller's transaction repo is undone by
      # that transaction's rollback, so the write cannot have escaped it.
      assert {:error, :rolled_back} =
               transact(fn repo ->
                 {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company.uid, cap.uid)
                 assert {:ok, _consumed} = CapabilityService.consume_locked(repo, locked)
                 Repo.rollback(:rolled_back)
               end)

      assert %Capability{status: :active} = Repo.get!(Capability, cap.id)
    end

    # B5-T13 Consuming a child leaves its parent and sibling active.
    test "B5-T13 Consuming a child leaves its parent and sibling active", %{company: company, holder: holder, issuer: issuer, cap: parent} do
      child =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          uid: "b5-child-#{System.unique_integer([:positive])}",
          action: parent.action,
          resource: parent.resource,
          risk_class: parent.risk_class,
          scope: parent.scope,
          constraints: parent.constraints,
          parent_capability_uid: parent.uid
        })

      sibling =
        capability_fixture(company.uid, holder.uid, issuer.uid, %{
          uid: "b5-sibling-#{System.unique_integer([:positive])}",
          action: parent.action,
          resource: parent.resource,
          risk_class: parent.risk_class,
          scope: parent.scope,
          constraints: parent.constraints,
          parent_capability_uid: parent.uid
        })

      assert {:ok, locked_child} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, child.uid)
      assert :ok = CapabilityService.validate_prefetched_capability(Repo, locked_child)
      assert {:ok, %Capability{status: :consumed}} = CapabilityService.consume_locked(Repo, locked_child)

      assert %Capability{status: :active} = Repo.get!(Capability, parent.id)
      assert %Capability{status: :active} = Repo.get!(Capability, sibling.id)

      # The sibling still consumes, so consuming one child does not consume the
      # delegation chain it came from.
      assert {:ok, locked_sibling} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, sibling.uid)
      assert {:ok, %Capability{status: :consumed}} = CapabilityService.consume_locked(Repo, locked_sibling)
    end

    # B5-T14 Consuming one Capability leaves unrelated Capabilities active.
    test "B5-T14 Consuming one Capability leaves unrelated Capabilities active", %{company: company, holder: holder, issuer: issuer, cap: cap} do
      other = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "b5-other-#{System.unique_integer([:positive])}"})

      %{principal: outsider} = human_fixture(uid: "b5-outsider-#{System.unique_integer([:positive])}")

      {:ok, _} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, outsider.uid)
        end)

      foreign = capability_fixture(company.uid, outsider.uid, issuer.uid, %{uid: "b5-foreign-#{System.unique_integer([:positive])}"})

      assert {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      assert {:ok, _consumed} = CapabilityService.consume_locked(Repo, locked)

      assert %Capability{status: :active} = Repo.get!(Capability, other.id)
      assert %Capability{status: :active} = Repo.get!(Capability, foreign.id)

      assert :ok = CapabilityService.validate_capability(Repo, company.uid, other.uid, [])
      assert :ok = CapabilityService.validate_capability(Repo, company.uid, foreign.uid, [])
    end

    # B5-T15 Consumption records no consumed_at and needs no migration.
    test "B5-T15 Consumption records no consumed_at and needs no migration", %{company: company, cap: cap} do
      refute :consumed_at in Capability.__schema__(:fields)

      {:ok, locked} = CapabilityStore.fetch_capability_for_update(Repo, company.uid, cap.uid)
      {:ok, consumed} = CapabilityService.consume_locked(Repo, locked)

      refute Map.has_key?(consumed, :consumed_at)
      assert consumed.status == :consumed

      persisted = Repo.get!(Capability, cap.id)
      refute Map.has_key?(persisted, :consumed_at)
      assert persisted.revoked_at == locked.revoked_at
      assert persisted.updated_at >= consumed.inserted_at

      columns =
        Repo.query!(
          "SELECT column_name FROM information_schema.columns WHERE table_name = 'capabilities'"
        ).rows |> List.flatten()

      refute "consumed_at" in columns
      assert "status" in columns
    end
  end

  # ─── lifecycle transition semantics ───────────────────────────────────────

  describe "lifecycle transition semantics" do
    setup do
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "lc-owner-#{suffix}")
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "lc-holder-#{suffix}")
      %{principal: issuer} = human_fixture(uid: "lc-issuer-#{suffix}")

      for uid <- [owner.uid, holder.uid, issuer.uid] do
        assert {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
      end

      %{company: company, holder: holder, issuer: issuer}
    end

    test "both entrypoints revoke an active Capability and refuse every terminal state",
         context do
      for label <- [:store, :service] do
        capability = capability_in(context, :active)

        assert {:ok, revoked} =
                 revoke_via(label, context.company.uid, capability.uid, context.issuer.uid)

        assert revoked.status == :revoked
        assert revoked.revoked_at
      end

      for {state, reason} <- [
            {:revoked, :already_revoked},
            {:consumed, :already_consumed},
            {:expired, :already_expired}
          ],
          label <- [:store, :service] do
        capability = capability_in(context, state)

        assert revoke_via(label, context.company.uid, capability.uid, context.issuer.uid) ==
                 {:error, reason}

        # The refused transition left the row exactly as it was.
        assert {:ok, unchanged} =
                 CapabilityStore.fetch_capability(Repo, context.company.uid, capability.uid)

        assert unchanged.status == state
      end

      # `requested` is schema valid but not an operational state, so it fails
      # closed instead of being treated as absent.
      for label <- [:store, :service] do
        capability = capability_in(context, :requested)

        assert revoke_via(label, context.company.uid, capability.uid, context.issuer.uid) ==
                 {:error, :invalid_state}
      end
    end

    test "both entrypoints expire an active Capability and refuse every terminal state",
         context do
      for label <- [:store, :service] do
        capability = capability_in(context, :active)

        assert {:ok, expired} = expire_via(label, context.company.uid, capability.uid)
        assert expired.status == :expired
      end

      for {state, reason} <- [
            {:expired, :already_expired},
            {:consumed, :already_consumed},
            {:revoked, :already_revoked}
          ],
          label <- [:store, :service] do
        capability = capability_in(context, state)

        assert expire_via(label, context.company.uid, capability.uid) == {:error, reason}

        assert {:ok, unchanged} =
                 CapabilityStore.fetch_capability(Repo, context.company.uid, capability.uid)

        assert unchanged.status == state
      end

      for label <- [:store, :service] do
        capability = capability_in(context, :authorized)

        assert expire_via(label, context.company.uid, capability.uid) == {:error, :invalid_state}
      end
    end

    test "the transition holds the row lock until the caller commits", context do
      capability = capability_in(context, :active)

      assert {:error, :caller_aborted} =
               Repo.transact(fn tx ->
                 assert {:ok, _revoked} =
                          CapabilityStore.revoke_capability(
                            tx,
                            context.company.uid,
                            capability.uid,
                            context.issuer.uid
                          )

                 Repo.rollback(:caller_aborted)
               end)

      # The caller decided the outcome, so the transition is not in the database.
      assert {:ok, active} =
               CapabilityStore.fetch_capability(Repo, context.company.uid, capability.uid)

      assert active.status == :active
      assert is_nil(active.revoked_at)
    end

    # Builds one Capability already sitting in `state`. The operational states
    # are reached through the public lifecycle API, so the fixture itself
    # proves those transitions. `requested` and `authorized` have no transition,
    # so they are written directly.
    defp capability_in(context, state) do
      uid = "lc-#{state}-#{System.unique_integer([:positive])}"

      capability =
        capability_fixture(context.company.uid, context.holder.uid, context.issuer.uid, %{
          uid: uid,
          status: if(state in [:requested, :authorized, :issued], do: state, else: :active)
        })

      case state do
        :active ->
          capability

        :revoked ->
          assert {:ok, revoked} =
                   CapabilityService.revoke_capability(
                     Repo,
                     context.company.uid,
                     uid,
                     context.issuer.uid
                   )

          revoked

        :expired ->
          assert {:ok, expired} =
                   CapabilityService.expire_capability(Repo, context.company.uid, uid)

          expired

        :consumed ->
          assert {:ok, consumed} =
                   Repo.transact(fn tx ->
                     {:ok, locked} =
                       CapabilityStore.fetch_capability_for_update(tx, context.company.uid, uid)

                     CapabilityService.consume_locked(tx, locked)
                   end)

          consumed

        # A schema-valid state that no live transition produces is already in
        # the state the fixture asks for.
        _dead ->
          capability
      end
    end

    defp revoke_via(:store, company_uid, capability_uid, revoker_uid) do
      CapabilityStore.revoke_capability(Repo, company_uid, capability_uid, revoker_uid)
    end

    defp revoke_via(:service, company_uid, capability_uid, revoker_uid) do
      CapabilityService.revoke_capability(Repo, company_uid, capability_uid, revoker_uid)
    end

    defp expire_via(:store, company_uid, capability_uid) do
      CapabilityStore.expire_capability(Repo, company_uid, capability_uid)
    end

    defp expire_via(:service, company_uid, capability_uid) do
      CapabilityService.expire_capability(Repo, company_uid, capability_uid)
    end
  end
  end

defmodule Ankole.W3.CapabilityStoreConcurrencyTest do
  @moduledoc """
  B5-T8: the real two-transaction non-replay proof.

  The sandbox gives one process one connection, so it cannot show that a
  second transaction blocks on the first transaction's `FOR UPDATE` lock. This
  module therefore leaves the sandbox with `unboxed_run` and drives two
  separate connections against one committed Capability row. Because those rows
  are committed for real, the module deletes every row it creates.
  """

  # Serial: this test commits rows outside the sandbox and coordinates two
  # blocking connections, so it cannot run concurrently with other tests.
  use Ankole.DataCase, async: false

  import Ankole.PrincipalsFixtures

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.CapabilityStore

  alias Ecto.Adapters.SQL.Sandbox

  # B5-T8 Two independent transactions consuming the same row: one success.
  @tag ownership_timeout: 30_000
  test "B5-T8 Two independent transactions consuming the same row: one success" do
    parent = self()

    {company_uid, capability_uid, principal_uids} =
      Sandbox.unboxed_run(Repo, fn ->
        suffix = System.unique_integer([:positive])

        %{principal: owner} = human_fixture(uid: "b5-t8-owner-#{suffix}")

        {:ok, company} =
          %Company{}
          |> Company.changeset(%{
            uid: "b5-t8-company-#{suffix}",
            name: "b5-t8-company-#{suffix}",
            display_name: "B5 T8 Company",
            status: :active,
            metadata: %{},
            owner_principal_uid: owner.uid
          })
          |> Repo.insert()

        %{principal: holder} = human_fixture(uid: "b5-t8-holder-#{suffix}")
        %{principal: issuer} = human_fixture(uid: "b5-t8-issuer-#{suffix}")

        for uid <- [owner.uid, holder.uid, issuer.uid] do
          {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
        end

        {:ok, capability} =
          %Capability{}
          |> Capability.changeset(%{
            uid: "b5-t8-cap-#{suffix}",
            company_uid: company.uid,
            principal_uid: holder.uid,
            action: "workspace:read",
            resource: "workspace:default",
            status: :active,
            risk_class: "CONTROLLED",
            issued_at: ~U[2026-09-26T10:00:00Z],
            issued_by_principal_uid: issuer.uid,
            scope: %{},
            constraints: %{}
          })
          |> Repo.insert()

        {company.uid, capability.uid, [owner.uid, holder.uid, issuer.uid]}
      end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        import Ecto.Query

        Capability
        |> where([capability], capability.uid == ^capability_uid)
        |> Repo.delete_all()

        Ankole.Company.Membership
        |> where([membership], membership.company_uid == ^company_uid)
        |> Repo.delete_all()

        Company
        |> where([company], company.uid == ^company_uid)
        |> Repo.delete_all()

        slugs = Enum.map(principal_uids, &"people/#{&1}")

        Ankole.Brain.Schemas.Object
        |> where([object], object.slug in ^slugs)
        |> Repo.delete_all()

        Ankole.Principals.HumanUser
        |> where([human], human.principal_uid in ^principal_uids)
        |> Repo.delete_all()

        Principal
        |> where([principal], principal.uid in ^principal_uids)
        |> Repo.delete_all()
      end)
    end)

    # Tx A locks the row with FOR UPDATE and holds the lock open.
    tx_a =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(fn repo ->
            {:ok, locked} = CapabilityStore.fetch_capability_for_update(repo, company_uid, capability_uid)
            assert locked.status == :active

            send(parent, {:tx_a_locked, self()})

            receive do
              :consume_and_commit -> {:ok, CapabilityService.consume_locked(repo, locked)}
            end
          end)
        end)
      end)

    assert_receive {:tx_a_locked, tx_a_pid}, 10_000

    # Tx B is a genuinely independent transaction on its own connection. It
    # announces that it is about to lock the row, then blocks inside the
    # `FOR UPDATE` while Tx A holds the lock.
    tx_b =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          send(parent, {:tx_b_attempting_lock, System.monotonic_time(:millisecond)})

          Repo.transact(fn repo ->
            started = System.monotonic_time(:millisecond)
            {:ok, locked_b} = CapabilityStore.fetch_capability_for_update(repo, company_uid, capability_uid)
            waited = System.monotonic_time(:millisecond) - started

            send(parent, {:tx_b_observed, locked_b.status, waited})

            case CapabilityService.consume_locked(repo, locked_b) do
              {:ok, consumed} -> {:ok, consumed.status}
              {:error, reason} -> {:error, reason}
            end
          end)
        end)
      end)

    assert_receive {:tx_b_attempting_lock, attempted_at}, 10_000

    # Tx B has reached the lock query while Tx A still holds the lock, so any
    # status it reports must have been read after Tx A released the lock.
    Process.sleep(300)
    refute_received {:tx_b_observed, _status, _waited}
    assert Process.alive?(tx_b.pid)

    # Tx A consumes and commits, releasing the lock.
    send(tx_a_pid, :consume_and_commit)
    assert {:ok, {:ok, %Capability{status: :consumed}}} = Task.await(tx_a, 15_000)

    # Tx B resumes and observes the committed :consumed row.
    assert_receive {:tx_b_observed, :consumed, waited}, 15_000
    assert waited >= 250, "Tx B must have blocked on Tx A's row lock, waited #{waited}ms"
    assert System.monotonic_time(:millisecond) - attempted_at >= 250

    assert {:error, :already_consumed} = Task.await(tx_b, 15_000)

    # Exactly one of the two transactions consumed the Capability.
    Sandbox.unboxed_run(Repo, fn ->
      assert %Capability{status: :consumed} =
               Repo.get_by!(Capability, uid: capability_uid, company_uid: company_uid)
    end)
  end
end