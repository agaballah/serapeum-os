defmodule Ankole.Company.OrganizationalUnitTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company.OrganizationalUnit

  describe "changeset" do
    test "valid attrs produce a valid changeset with default status" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          company_uid: "company-001"
        })

      assert cs.valid?
      assert get_field(cs, :status) == :active
    end

    test "uid is required" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          name: "Engineering",
          company_uid: "company-001"
        })

      refute cs.valid?
      assert cs.errors[:uid]
    end

    test "blank uid is rejected" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "   ",
          name: "Engineering",
          company_uid: "company-001"
        })

      refute cs.valid?
      assert cs.errors[:uid]
    end

    test "name is required" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          company_uid: "company-001"
        })

      refute cs.valid?
      assert cs.errors[:name]
    end

    test "blank name is rejected" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "  ",
          company_uid: "company-001"
        })

      refute cs.valid?
      assert cs.errors[:name]
    end

    test "company_uid is required" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering"
        })

      refute cs.valid?
      assert cs.errors[:company_uid]
    end

    test ":active status is valid" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          status: :active,
          company_uid: "company-001"
        })

      assert cs.valid?
      assert get_field(cs, :status) == :active
    end

    test ":archived status is valid" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          status: :archived,
          company_uid: "company-001"
        })

      assert cs.valid?
      assert get_field(cs, :status) == :archived
    end

    test ":created status is rejected" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          status: :created,
          company_uid: "company-001"
        })

      refute cs.valid?
    end

    test ":suspended status is rejected" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          status: :suspended,
          company_uid: "company-001"
        })

      refute cs.valid?
    end

    test "uid is cast as a string" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          company_uid: "company-001"
        })

      assert get_field(cs, :uid) == "unit-001"
    end

    test "uid is preserved exactly" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "  unit-001  ",
          name: "Engineering",
          company_uid: "company-001"
        })

      assert get_field(cs, :uid) == "  unit-001  "
    end

    test "name is trimmed" do
      cs =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "  Engineering  ",
          company_uid: "company-001"
        })

      assert get_field(cs, :name) == "Engineering"
    end

    test "no display_name field in schema" do
      refute :display_name in OrganizationalUnit.__schema__(:fields)
    end

    test "no metadata field in schema" do
      refute :metadata in OrganizationalUnit.__schema__(:fields)
    end
  end

  describe "associations" do
    test "company association is stored as :string" do
      assert OrganizationalUnit.__schema__(:type, :company_uid) == :string
    end

    test "parent_unit_uid is stored as :string" do
      assert OrganizationalUnit.__schema__(:type, :parent_unit_uid) == :string
    end
  end

  describe "fields" do
    test "exactly the expected fields" do
      assert OrganizationalUnit.__schema__(:fields) ==
               [:id, :uid, :name, :status, :company_uid, :parent_unit_uid, :inserted_at, :updated_at]
    end

    test "primary key is id" do
      assert OrganizationalUnit.__schema__(:primary_key) == [:id]
    end
  end

  describe "constraint wiring" do
    test "uid unique constraint is wired" do
      constraints =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          company_uid: "company-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :uid and c.type == :unique and
                 c.constraint == "organizational_units_uid_index"
             end)
    end

    test "company_uid FK constraint is wired" do
      constraints =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          company_uid: "company-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :company_uid and c.type == :foreign_key
             end)
    end

    test "parent_unit_uid FK constraint is wired" do
      constraints =
        OrganizationalUnit.changeset(%OrganizationalUnit{}, %{
          uid: "unit-001",
          name: "Engineering",
          company_uid: "company-001",
          parent_unit_uid: "unit-000"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :parent_unit_uid and c.type == :foreign_key
             end)
    end
  end

  describe "timestamps" do
    test "inserted_at and updated_at are present" do
      assert :inserted_at in OrganizationalUnit.__schema__(:fields)
      assert :updated_at in OrganizationalUnit.__schema__(:fields)
    end
  end
end
