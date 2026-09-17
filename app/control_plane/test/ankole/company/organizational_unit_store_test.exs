defmodule Ankole.Company.OrganizationalUnitStoreTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.OrganizationalUnitStore

  import Ankole.PrincipalsFixtures

  describe "root unit" do
    test "valid root unit creation" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, unit} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "eng-unit-001",
                   name: "Engineering"
                 })
               end)

      assert unit.uid == "eng-unit-001"
      assert unit.name == "Engineering"
      assert unit.company_uid == company.uid
      assert unit.parent_unit_uid == nil
      assert unit.status == :active
    end

    test "default status is active" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, unit} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "dept-unit-001",
                   name: "Department"
                 })
               end)

      assert unit.status == :active
    end

    test "explicit archived status is allowed" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, unit} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "arch-unit-001",
                   name: "Archive Me",
                   status: :archived
                 })
               end)

      assert unit.status == :archived
    end
  end

  describe "child unit" do
    test "valid child unit creation" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, parent} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "parent-unit-001",
                   name: "Parent"
                 })
               end)

      assert {:ok, child} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "child-unit-001",
                   name: "Child",
                   parent_unit_uid: parent.uid
                 })
               end)

      assert child.parent_unit_uid == parent.uid
      assert child.company_uid == company.uid
    end

    test "unknown parent is rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:error, :parent_not_found} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "orphan-unit-001",
                   name: "Orphan",
                   parent_unit_uid: "nonexistent-unit"
                 })
               end)
    end

    test "parent from another company is rejected" do
      owner = human_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      assert {:ok, foreign_parent} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company_b.uid, %{
                   uid: "foreign-parent-001",
                   name: "Foreign Parent"
                 })
               end)

      assert {:error, :parent_company_mismatch} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company_a.uid, %{
                   uid: "cross-unit-001",
                   name: "Cross Company",
                   parent_unit_uid: foreign_parent.uid
                 })
               end)
    end

    test "self-parent is rejected" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:error, :self_parent_rejected} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "self-unit-001",
                   name: "Self",
                   parent_unit_uid: "self-unit-001"
                 })
               end)
    end

    test "multiple children under same parent are allowed" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, parent} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "multi-parent-001",
                   name: "Parent"
                 })
               end)

      for n <- 1..3 do
        assert {:ok, _} =
                 transact(fn repo ->
                   OrganizationalUnitStore.create_unit(repo, company.uid, %{
                     uid: "multi-child-#{n}",
                     name: "Child #{n}",
                     parent_unit_uid: parent.uid
                   })
                 end)
      end

      children = OrganizationalUnitStore.list_children(Ankole.Repo, parent.uid)
      assert length(children) == 3
    end
  end

  describe "company scope" do
    test "unknown company is rejected" do
      assert {:error, :company_not_found} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, "nonexistent-company", %{
                   uid: "no-company-unit-001",
                   name: "No Company"
                 })
               end)
    end

    test "multiple root units in same company are allowed" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      for n <- 1..3 do
        assert {:ok, _} =
                 transact(fn repo ->
                   OrganizationalUnitStore.create_unit(repo, company.uid, %{
                     uid: "root-#{n}",
                     name: "Root #{n}"
                   })
                 end)
      end

      units = OrganizationalUnitStore.list_company_units(Ankole.Repo, company.uid)
      assert length(units) == 3
    end

    test "attrs company_uid does not override the explicit argument" do
      owner = human_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      assert {:ok, unit} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company_a.uid, %{
                   uid: "override-test-001",
                   name: "Override Test",
                   company_uid: company_b.uid
                 })
               end)

      assert unit.company_uid == company_a.uid
      refute unit.company_uid == company_b.uid
    end
  end

  describe "queries" do
    test "fetch_unit returns the unit on hit" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, unit} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "fetch-hit-001",
                   name: "Fetch Hit"
                 })
               end)

      fetched = OrganizationalUnitStore.fetch_unit(Ankole.Repo, unit.uid)
      assert fetched.uid == unit.uid
      assert fetched.name == unit.name
    end

    test "fetch_unit returns nil on miss" do
      assert OrganizationalUnitStore.fetch_unit(Ankole.Repo, "nonexistent-unit") == nil
    end

    test "list_company_units returns all units for the company" do
      owner = human_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      for {n, company} <- [{1, company_a}, {2, company_a}, {3, company_b}] do
        transact(fn repo ->
          OrganizationalUnitStore.create_unit(repo, company.uid, %{
            uid: "list-unit-#{n}",
            name: "List Unit #{n}"
          })
        end)
      end

      units_a = OrganizationalUnitStore.list_company_units(Ankole.Repo, company_a.uid)
      assert length(units_a) == 2

      units_b = OrganizationalUnitStore.list_company_units(Ankole.Repo, company_b.uid)
      assert length(units_b) == 1
    end

    test "list_children returns direct children" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, parent} =
               transact(fn repo ->
                 OrganizationalUnitStore.create_unit(repo, company.uid, %{
                   uid: "list-parent-001",
                   name: "List Parent"
                 })
               end)

      for n <- 1..2 do
        transact(fn repo ->
          OrganizationalUnitStore.create_unit(repo, company.uid, %{
            uid: "list-child-#{n}",
            name: "List Child #{n}",
            parent_unit_uid: parent.uid
          })
        end)
      end

      children = OrganizationalUnitStore.list_children(Ankole.Repo, parent.uid)
      assert length(children) == 2
    end

    test "list_children returns empty list for unknown unit" do
      assert OrganizationalUnitStore.list_children(Ankole.Repo, "nonexistent") == []
    end
  end

  describe "boundary" do
    test "the store source has no dependency on Ankole.AuthZ" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/organizational_unit_store.ex", __DIR__)
        )

      refute String.contains?(source, "Ankole.AuthZ")
    end

    test "the store source has no dependency on Ankole.Principals" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/organizational_unit_store.ex", __DIR__)
        )

      refute String.contains?(source, "Ankole.Principals")
    end

    test "the store source has no Company status authorization" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/organizational_unit_store.ex", __DIR__)
        )

      refute String.contains?(source, "company.status")
      refute String.contains?(source, "Company.status")
    end

    test "no move/reparent/update/delete/archive public operation" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/organizational_unit_store.ex", __DIR__)
        )

      refute String.contains?(source, "def move_unit")
      refute String.contains?(source, "def reparent_unit")
      refute String.contains?(source, "def update_unit")
      refute String.contains?(source, "def remove_unit")
      refute String.contains?(source, "def archive_unit")
      refute String.contains?(source, "def ancestors")
      refute String.contains?(source, "def descendants")
    end

    test "no recursive hierarchy machinery" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/organizational_unit_store.ex", __DIR__)
        )

      refute String.contains?(source, "WITH RECURSIVE")
      refute String.contains?(source, "pg_advisory_xact_lock")
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

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end
end
