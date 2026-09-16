defmodule Ankole.Company.MembershipTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company.Membership

  @valid_attrs %{
    company_uid: "test-company-001",
    principal_uid: "test-principal-001"
  }

  describe "changeset" do
    test "valid attrs produce a valid changeset" do
      cs = Membership.changeset(%Membership{}, @valid_attrs)
      assert cs.valid?
    end

    test "requires company_uid" do
      cs = Membership.changeset(%Membership{}, %{principal_uid: "test-principal-001"})
      assert not cs.valid?
      assert cs.errors[:company_uid]
    end

    test "requires principal_uid" do
      cs = Membership.changeset(%Membership{}, %{company_uid: "test-company-001"})
      assert not cs.valid?
      assert cs.errors[:principal_uid]
    end

    test "normalizes principal_uid through Ankole.Ecto.PrincipalKey" do
      cs =
        Membership.changeset(%Membership{}, %{
          company_uid: "test-company-001",
          principal_uid: "  OPERATOR-9 "
        })

      assert get_field(cs, :principal_uid) == "operator-9"
    end

    test "rejects a blank principal_uid" do
      cs =
        Membership.changeset(%Membership{}, %{
          company_uid: "test-company-001",
          principal_uid: "   "
        })

      assert not cs.valid?
      assert cs.errors[:principal_uid]
    end

    test "rejects a non-binary principal_uid" do
      cs =
        Membership.changeset(%Membership{}, %{
          company_uid: "test-company-001",
          principal_uid: 42
        })

      assert not cs.valid?
      assert cs.errors[:principal_uid]
    end
  end

  describe "associations" do
    test "company association is stored as :string, principal as Ankole.Ecto.PrincipalKey" do
      assert Membership.__schema__(:type, :company_uid) == :string
      assert Membership.__schema__(:type, :principal_uid) == Ankole.Ecto.PrincipalKey
    end

    test "composite primary key is the membership pair" do
      assert Membership.__schema__(:primary_key) == [:company_uid, :principal_uid]
    end
  end

  describe "fields" do
    test "exactly the key pair plus inserted_at; no id, status, role, metadata, or updated_at" do
      assert Membership.__schema__(:fields) == [:company_uid, :principal_uid, :inserted_at]
    end
  end

  describe "constraint wiring" do
    test "both key fields carry FK constraints" do
      constraints = Membership.changeset(%Membership{}, @valid_attrs).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :company_uid and c.type == :foreign_key and
                 c.constraint == "company_memberships_company_uid_fkey"
             end)

      assert Enum.any?(constraints, fn c ->
               c.field == :principal_uid and c.type == :foreign_key and
                 c.constraint == "company_memberships_principal_uid_fkey"
             end)
    end

    test "duplicate composite PK constraint is wired to company_memberships_pkey" do
      constraints = Membership.changeset(%Membership{}, @valid_attrs).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :company_uid and c.type == :unique and
                 c.constraint == "company_memberships_pkey"
             end)
    end
  end

  describe "timestamps" do
    test "inserted_at only, no updated_at" do
      assert :inserted_at in Membership.__schema__(:fields)
      refute :updated_at in Membership.__schema__(:fields)
      refute :id in Membership.__schema__(:fields)
    end
  end
end
