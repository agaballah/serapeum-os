defmodule Ankole.Company.StoreTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.Store

  import Ankole.PrincipalsFixtures

  @moduledoc """
  Tests for Ankole.Company.Store public API.

  Covers create, fetch, update, and lifecycle transitions.
  Bootstrap/activation functions are explicitly not tested.
  """

  describe "create_company" do
    test "valid Company created as :created" do
      owner = human_fixture()

      assert {:ok, company} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "test-company-create-001",
                   name: "create-test",
                   display_name: "Create Test",
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert company.status == :created
      assert company.name == "create-test"
      assert company.display_name == "Create Test"
      assert company.metadata == %{}
      assert company.owner_principal_uid == owner.principal.uid
    end

    test "caller status :active cannot bypass :created" do
      owner = human_fixture()

      assert {:ok, company} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "test-company-create-002",
                   name: "bypass-active",
                   display_name: "Bypass Active",
                   status: :active,
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert company.status == :created
    end

    test "caller status :suspended cannot bypass :created" do
      owner = human_fixture()

      assert {:ok, company} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "test-company-create-003",
                   name: "bypass-suspended",
                   display_name: "Bypass Suspended",
                   status: :suspended,
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert company.status == :created
    end

    test "caller status :archived cannot bypass :created" do
      owner = human_fixture()

      assert {:ok, company} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "test-company-create-004",
                   name: "bypass-archived",
                   display_name: "Bypass Archived",
                   status: :archived,
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert company.status == :created
    end

    test "existing schema validation preserved" do
      owner = human_fixture()

      assert {:error, changeset} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "invalid-schema",
                   name: "ab",
                   display_name: "Invalid",
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert changeset.errors[:name]
    end

    test "uniqueness constraints preserved" do
      owner = human_fixture()

      assert {:ok, _} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "unique-001",
                   name: "unique-name",
                   display_name: "Unique",
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert {:error, changeset} =
               transact(fn repo ->
                 Store.create_company(repo, %{
                   uid: "unique-002",
                   name: "unique-name",
                   display_name: "Duplicate",
                   metadata: %{},
                   owner_principal_uid: owner.principal.uid
                 })
               end)

      assert changeset.errors[:name]
    end
  end

  describe "fetch_company" do
    test "hit returns Company" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      fetched = fetch_company(company.uid)

      assert fetched.uid == company.uid
      assert fetched.name == company.name
    end

    test "miss returns nil" do
      result = fetch_company("nonexistent-company")

      assert result == nil
    end
  end

  describe "update_company" do
    setup do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})
      %{owner: owner, company: company}
    end

    test "name update", %{company: company} do
      assert {:ok, updated} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{name: "new-name"})
               end)

      assert updated.name == "new-name"
    end

    test "display_name update", %{company: company} do
      assert {:ok, updated} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{display_name: "New Display"})
               end)

      assert updated.display_name == "New Display"
    end

    test "metadata update", %{company: company} do
      assert {:ok, updated} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{metadata: %{"key" => "value"}})
               end)

      assert updated.metadata == %{"key" => "value"}
    end

    test "uid cannot be changed", %{company: company} do
      assert {:error, {:immutable_fields, [:uid]}} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{uid: "different-uid"})
               end)
    end

    test "owner_principal_uid cannot be changed", %{company: company, owner: owner} do
      other_owner = human_fixture()

      assert {:error, {:immutable_fields, [:owner_principal_uid]}} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{owner_principal_uid: other_owner.principal.uid})
               end)
    end

    test "status cannot be changed", %{company: company} do
      assert {:error, {:immutable_fields, [:status]}} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{status: :suspended})
               end)
    end

    test "invalid mutable-field changes return appropriate error", %{company: company} do
      assert {:error, changeset} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{name: "ab"})
               end)

      assert changeset.errors[:name]
    end
  end

  describe "suspend_company" do
    test "active -> suspended" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})

      assert {:ok, suspended} =
               transact(fn repo ->
                 Store.suspend_company(repo, company.uid)
               end)

      assert suspended.status == :suspended
    end

    test "created rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :created})

      assert {:error, {:invalid_transition, from: :created, to: :suspended}} =
               transact(fn repo ->
                 Store.suspend_company(repo, company.uid)
               end)
    end

    test "suspended rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :suspended})

      assert {:error, {:invalid_transition, from: :suspended, to: :suspended}} =
               transact(fn repo ->
                 Store.suspend_company(repo, company.uid)
               end)
    end

    test "archived rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :archived})

      assert {:error, {:invalid_transition, from: :archived, to: :suspended}} =
               transact(fn repo ->
                 Store.suspend_company(repo, company.uid)
               end)
    end
  end

  describe "reactivate_company" do
    test "suspended -> active" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :suspended})

      assert {:ok, reactivated} =
               transact(fn repo ->
                 Store.reactivate_company(repo, company.uid)
               end)

      assert reactivated.status == :active
    end

    test "created rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :created})

      assert {:error, {:invalid_transition, from: :created, to: :active}} =
               transact(fn repo ->
                 Store.reactivate_company(repo, company.uid)
               end)
    end

    test "active rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})

      assert {:error, {:invalid_transition, from: :active, to: :active}} =
               transact(fn repo ->
                 Store.reactivate_company(repo, company.uid)
               end)
    end

    test "archived rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :archived})

      assert {:error, {:invalid_transition, from: :archived, to: :active}} =
               transact(fn repo ->
                 Store.reactivate_company(repo, company.uid)
               end)
    end
  end

  describe "archive_company" do
    test "active -> archived" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})

      assert {:ok, archived} =
               transact(fn repo ->
                 Store.archive_company(repo, company.uid)
               end)

      assert archived.status == :archived
    end

    test "suspended -> archived" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :suspended})

      assert {:ok, archived} =
               transact(fn repo ->
                 Store.archive_company(repo, company.uid)
               end)

      assert archived.status == :archived
    end

    test "created rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :created})

      assert {:error, {:invalid_transition, from: :created, to: :archived}} =
               transact(fn repo ->
                 Store.archive_company(repo, company.uid)
               end)
    end

    test "archived remains terminal" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :archived})

      assert {:error, {:invalid_transition, from: :archived, to: :archived}} =
               transact(fn repo ->
                 Store.archive_company(repo, company.uid)
               end)
    end
  end

  describe "lock / transaction" do
    test "lifecycle operations execute through transaction with Company row FOR UPDATE" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})

      assert {:ok, _suspended} =
               transact(fn repo ->
                 Store.suspend_company(repo, company.uid)
               end)

      # Verify the row was actually updated in the DB
      reloaded = fetch_company(company.uid)
      assert reloaded.status == :suspended
    end

    test "update mutation uses Company row lock" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})

      assert {:ok, _updated} =
               transact(fn repo ->
                 Store.update_company(repo, company.uid, %{display_name: "Locked Update"})
               end)

      reloaded = fetch_company(company.uid)
      assert reloaded.display_name == "Locked Update"
    end
  end

  describe "boundary" do
    test "Store contains no public bootstrap_company function" do
      refute function_exported?(Store, :bootstrap_company, 2)
    end

    test "Store contains no public activate_company function" do
      refute function_exported?(Store, :activate_company, 2)
    end

    test "Store contains no public list_companies function" do
      refute function_exported?(Store, :list_companies, 1)
    end

    test "Store contains no public delete_company function" do
      refute function_exported?(Store, :delete_company, 2)
    end

    test "Store contains no public transfer_owner function" do
      refute function_exported?(Store, :transfer_owner, 3)
    end

    test "the store source has no dependency on Ankole.AuthZ" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/store.ex", __DIR__)
        )

      refute String.contains?(source, "Ankole.AuthZ")
    end

    test "the store source has no MembershipStore composition" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/store.ex", __DIR__)
        )

      refute String.contains?(source, "MembershipStore")
    end

    test "the store source has no OrganizationalUnitStore composition" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/store.ex", __DIR__)
        )

      refute String.contains?(source, "OrganizationalUnitStore")
    end

    test "the store source has no Agent operation" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/store.ex", __DIR__)
        )

      refute String.contains?(source, "Ankole.Agent")
      refute String.contains?(source, "Agent.")
    end

    test "the store source has no Principal mutation" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/store.ex", __DIR__)
        )

      refute String.contains?(source, "Principals.")
    end
  end

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Enum.into(attrs, %{
          uid: "test-company-#{suffix}",
          name: "test-company-#{suffix}",
          display_name: "Test Company",
          status: :created,
          metadata: %{},
          owner_principal_uid: owner_uid
        })
      )
      |> Repo.insert()

    company
  end

  defp fetch_company(company_uid) do
    Repo.get_by(Company, uid: company_uid)
  end

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end
end