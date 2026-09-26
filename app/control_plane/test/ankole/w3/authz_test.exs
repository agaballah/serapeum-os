defmodule Ankole.W3.AuthZTest do
  use Ankole.DataCase, async: true

  alias Ankole.W3.AuthZ, as: W3AuthZ
  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore

  import Ankole.PrincipalsFixtures

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])
    defaults = %{
      uid: "w3-p1-company-#{suffix}",
      name: "w3-p1-company-#{suffix}",
      display_name: "W3 P1 Test Company",
      status: :active,
      metadata: %{},
      owner_principal_uid: owner_uid
    }

    attrs_map = if is_map(attrs), do: attrs, else: Enum.into(attrs, %{})
    {:ok, company} = %Company{} |> Company.changeset(Map.merge(defaults, attrs_map)) |> Repo.insert()
    company
  end

  # ─── helpers ──────────────────────────────────────────────────────────────

  defp deny?({:error, _}), do: true
  defp deny?(_), do: false

  defp forbidden_action?(result) do
    case result do
      {:error, :forbidden} -> true
      {:error, {:forbidden, _}} -> true
      _ -> false
    end
  end

  # ─── Company boundary ────────────────────────────────────────────────────

  describe "authorize/5 — Company boundary" do
    test "allows when Principal is active member with valid grant" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "workspace:**",
        action: "read"
      })

      assert :ok = W3AuthZ.authorize(company.uid, human.uid, "workspace:default", "read")
    end

    test "denies when Principal is not a member of the Company" do
      %{principal: owner} = human_fixture()
      %{principal: other} = human_fixture(uid: unique_uid("other-human"))
      company = company_fixture(owner.uid)

      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize(company.uid, other.uid, "workspace:default", "read")
    end

    test "denies cross-Company access even with valid grant in other Company" do
      %{principal: human_a} = human_fixture(uid: unique_uid("cross-a"))
      %{principal: human_b} = human_fixture(uid: unique_uid("cross-b"))

      company_a = company_fixture(human_a.uid, uid: unique_uid("company-a"))
      company_b = company_fixture(human_b.uid, uid: unique_uid("company-b"))

      {:ok, _mem_a} = MembershipStore.add_member(Ankole.Repo, company_a.uid, human_a.uid)
      {:ok, _mem_b} = MembershipStore.add_member(Ankole.Repo, company_b.uid, human_b.uid)

      AuthZ.upsert_permission_grant(%{
        principal_uid: human_a.uid,
        resource_pattern: "workspace:**",
        action: "read"
      })

      # human_a is NOT a member of company_b
      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize(company_b.uid, human_a.uid, "workspace:default", "read")

      # But IS authorized in company_a
      assert :ok = W3AuthZ.authorize(company_a.uid, human_a.uid, "workspace:default", "read")
    end

    test "denies when Company does not exist" do
      %{principal: human} = human_fixture()

      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize("nonexistent-company-uid", human.uid, "workspace:default", "read")
    end

    test "denies when Principal does not exist" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :principal_not_found} =
               W3AuthZ.authorize(company.uid, "nonexistent-principal", "workspace:default", "read")
    end

    test "denies when Principal is disabled" do
      %{principal: human} = human_fixture(status: :disabled)
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      # Disabled principals fall through to AuthZ which denies with :forbidden
      assert forbidden_action?(W3AuthZ.authorize(company.uid, human.uid, "workspace:default", "read"))
    end

    test "denies when Company context is nil" do
      %{principal: human} = human_fixture()

      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize(nil, human.uid, "workspace:default", "read")
    end

    test "denies when Company context is empty string" do
      %{principal: human} = human_fixture()

      assert {:error, :company_scope_mismatch} =
               W3AuthZ.authorize("", human.uid, "workspace:default", "read")
    end

    test "denies when Principal context is nil" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :principal_not_found} =
               W3AuthZ.authorize(company.uid, nil, "workspace:default", "read")
    end

    test "denies when Principal context is empty string" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :principal_not_found} =
               W3AuthZ.authorize(company.uid, "", "workspace:default", "read")
    end
  end

  # ─── AuthZ integration ───────────────────────────────────────────────────

  describe "authorize/5 — underlying AuthZ behavior" do
    test "passes through AuthZ allow decision" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "data:**",
        action: "write"
      })

      assert :ok = W3AuthZ.authorize(company.uid, human.uid, "data:record:1", "write")
    end

    test "passes through AuthZ deny decision" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      # No grant exists, so AuthZ denies
      result = W3AuthZ.authorize(company.uid, human.uid, "data:record:1", "write")
      assert forbidden_action?(result)
    end

    test "membership valid but AuthZ denied remains denied" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      # Valid membership but no grant
      result = W3AuthZ.authorize(company.uid, human.uid, "secret:data", "delete")
      assert forbidden_action?(result)
    end

    test "exact action matching from Ankole AuthZ is preserved" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "files:**",
        action: "Read"
      })

      # Uppercase Read is allowed
      assert :ok = W3AuthZ.authorize(company.uid, human.uid, "files:doc", "Read")

      # Lowercase read is denied (AuthZ exact matching)
      result = W3AuthZ.authorize(company.uid, human.uid, "files:doc", "read")
      assert forbidden_action?(result)
    end
  end

  # ─── Fail-closed behavior ────────────────────────────────────────────────

  describe "fail-closed behavior" do
    test "missing company fails closed" do
      %{principal: human} = human_fixture()
      assert {:error, :company_scope_mismatch} = W3AuthZ.authorize(nil, human.uid, "r", "a")
    end

    test "malformed company fails closed" do
      %{principal: human} = human_fixture()
      assert {:error, :company_scope_mismatch} = W3AuthZ.authorize(123, human.uid, "r", "a")
    end

    test "missing principal fails closed" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      assert {:error, :principal_not_found} = W3AuthZ.authorize(company.uid, nil, "r", "a")
    end

    test "malformed principal fails closed" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      assert {:error, :principal_not_found} = W3AuthZ.authorize(company.uid, 123, "r", "a")
    end

    test "non-member in valid company fails closed" do
      %{principal: a} = human_fixture(uid: unique_uid("fail-a"))
      %{principal: b} = human_fixture(uid: unique_uid("fail-b"))
      company = company_fixture(a.uid)
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, a.uid)

      # b is not a member
      assert {:error, :company_scope_mismatch} = W3AuthZ.authorize(company.uid, b.uid, "r", "a")
    end
  end

  # ─── allowed? helper ─────────────────────────────────────────────────────

  describe "allowed?/5" do
    test "returns true for authorized principal" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "x:**",
        action: "y"
      })

      assert W3AuthZ.allowed?(company.uid, human.uid, "x:z", "y")
    end

    test "returns false for unauthorized principal" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      refute W3AuthZ.allowed?(company.uid, human.uid, "x:z", "no-grant-action")
    end
  end

  # ─── build_snapshot/5 ────────────────────────────────────────────────────

  describe "build_snapshot/5" do
    test "returns snapshot for valid member with grant" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "s:**",
        action: "t"
      })

      assert {:ok, snapshot} = W3AuthZ.build_snapshot(company.uid, human.uid, "s:a", "t")
      assert snapshot["principal"]["uid"] == human.uid
    end

    test "returns error for non-member" do
      %{principal: a} = human_fixture(uid: unique_uid("snap-a"))
      %{principal: b} = human_fixture(uid: unique_uid("snap-b"))
      company = company_fixture(a.uid)
      {:ok, _} = MembershipStore.add_member(Ankole.Repo, company.uid, a.uid)

      assert {:error, :company_scope_mismatch} =
               W3AuthZ.build_snapshot(company.uid, b.uid, "s:a", "t")
    end

    test "returns error for cross-Company Principal" do
      %{principal: a} = human_fixture(uid: unique_uid("cross-snap-a"))
      %{principal: b} = human_fixture(uid: unique_uid("cross-snap-b"))

      company_a = company_fixture(a.uid, uid: unique_uid("company-snap-a"))
      company_b = company_fixture(b.uid, uid: unique_uid("company-snap-b"))

      {:ok, _mem_a} = MembershipStore.add_member(Ankole.Repo, company_a.uid, a.uid)
      {:ok, _mem_b} = MembershipStore.add_member(Ankole.Repo, company_b.uid, b.uid)

      # b is not a member of company_a
      assert {:error, :company_scope_mismatch} =
               W3AuthZ.build_snapshot(company_a.uid, b.uid, "s:a", "t")

      # a IS authorized in company_a
      assert {:ok, _} = W3AuthZ.build_snapshot(company_a.uid, a.uid, "s:a", "t")
    end

    test "returns error for missing Company" do
      %{principal: human} = human_fixture()

      assert {:error, :company_scope_mismatch} =
               W3AuthZ.build_snapshot("nonexistent", human.uid, "r", "a")
    end

    test "returns error for disabled Principal" do
      %{principal: human} = human_fixture()
      {:ok, _disabled} = Ankole.Principals.disable_principal(human.uid)
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      assert {:error, :principal_disabled} =
               W3AuthZ.build_snapshot(company.uid, human.uid, "s:a", "t")
    end

    test "returns error for nonexistent Principal" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :principal_not_found} =
               W3AuthZ.build_snapshot(company.uid, "missing", "s:a", "t")
    end
  end

  # ─── Review independence ─────────────────────────────────────────────────

  describe "Review independence" do
    test "authorization does not depend on W2 ReviewRecord verdicts" do
      %{principal: human} = human_fixture()
      company = company_fixture(human.uid)
      {:ok, _membership} = MembershipStore.add_member(Ankole.Repo, company.uid, human.uid)

      # Even without any Review records, authorization works based on grants
      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "tasks:**",
        action: "list"
      })

      assert :ok = W3AuthZ.authorize(company.uid, human.uid, "tasks:1", "list")
    end
  end

  # ─── Regression: existing AuthZ still works ──────────────────────────────

  describe "Ankole AuthZ unchanged" do
    test "direct Ankole.AuthZ.authorize still works without Company context" do
      %{principal: human} = human_fixture()

      AuthZ.upsert_permission_grant(%{
        principal_uid: human.uid,
        resource_pattern: "legacy:**",
        action: "access"
      })

      # Direct Ankole call should still work
      assert :ok = AuthZ.authorize(human.uid, "legacy:x", "access")
    end
  end
end
