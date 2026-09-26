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
      refute String.contains?(source, "def revoke_capability")
      refute String.contains?(source, "def expire_capability")
    end
  end
end