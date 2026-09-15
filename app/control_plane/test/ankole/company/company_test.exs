defmodule Ankole.CompanyTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company

  describe "changeset" do
    test "valid attrs produce a valid changeset with default status" do
      attrs = %{
        uid: "test-company-001",
        name: "acme-corp",
        display_name: "Acme Corporation",
        metadata: %{},
        owner_principal_uid: "owner-uid-123"
      }

      cs = Company.changeset(%Company{}, attrs)
      assert cs.valid?
      assert get_field(cs, :status) == :created
    end

    test ":created status is valid" do
      cs = Company.changeset(%Company{}, %{
        uid: "test-1",
        name: "test-corp",
        display_name: "Test",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-1"
      })

      assert cs.valid?
      assert get_field(cs, :status) == :created
    end

    test ":active status is valid" do
      cs = Company.changeset(%Company{}, %{
        uid: "test-2",
        name: "active-corp",
        display_name: "Active",
        status: :active,
        metadata: %{},
        owner_principal_uid: "owner-2"
      })

      assert cs.valid?
      assert get_field(cs, :status) == :active
    end

    test ":suspended status is valid" do
      cs = Company.changeset(%Company{}, %{
        uid: "test-3",
        name: "susp-corp",
        display_name: "Suspended",
        status: :suspended,
        metadata: %{},
        owner_principal_uid: "owner-3"
      })

      assert cs.valid?
      assert get_field(cs, :status) == :suspended
    end

    test ":archived status is valid" do
      cs = Company.changeset(%Company{}, %{
        uid: "test-4",
        name: "arch-corp",
        display_name: "Archived",
        status: :archived,
        metadata: %{},
        owner_principal_uid: "owner-4"
      })

      assert cs.valid?
      assert get_field(cs, :status) == :archived
    end

    test ":disabled status is rejected" do
      cs = Company.changeset(%Company{}, %{
        uid: "test-disabled",
        name: "disabled-corp",
        display_name: "Disabled",
        status: :disabled,
        metadata: %{},
        owner_principal_uid: "owner-5"
      })

      assert not cs.valid?
      assert cs.errors[:status]
    end

    test "invalid when required fields are missing" do
      cs = Company.changeset(%Company{}, %{uid: "x", metadata: %{}})
      assert not cs.valid?
      assert cs.errors[:name]
      assert cs.errors[:display_name]
      assert cs.errors[:owner_principal_uid]
    end

    test "rejects empty display_name after trim" do
      cs = Company.changeset(%Company{}, %{
        uid: "trim-test",
        name: "trim-test",
        display_name: "   ",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert not cs.valid?
      assert cs.errors[:display_name]
    end

    test "lowercases name during normalization" do
      cs = Company.changeset(%Company{}, %{
        uid: "lower-test",
        name: "ACME-CORP",
        display_name: "Acme Corp",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert "acme-corp" == get_field(cs, :name)
      assert cs.valid?
    end

    test "rejects name shorter than 3 characters" do
      cs = Company.changeset(%Company{}, %{
        uid: "short-name",
        name: "ab",
        display_name: "Ab",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert [{:name, {_msg, _}}] = cs.errors
    end

    test "rejects name longer than 63 characters" do
      long_name = String.duplicate("a", 64)

      cs = Company.changeset(%Company{}, %{
        uid: "long-name",
        name: long_name,
        display_name: "Long",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert [{:name, {_msg, _}}] = cs.errors
    end

    test "normalizes uppercase name to lowercase and passes validation" do
      cs = Company.changeset(%Company{}, %{
        uid: "upper-name",
        name: "ACME-CORP",
        display_name: "Acme Corp",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert get_field(cs, :name) == "acme-corp"
      assert cs.valid?
    end

    test "rejects name with invalid characters" do
      cs = Company.changeset(%Company{}, %{
        uid: "bad-chars",
        name: "acme corp!",
        display_name: "Acme Corp",
        status: :created,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert [{:name, {_msg, _}}] = cs.errors
    end

    test "rejects invalid status value" do
      cs = Company.changeset(%Company{}, %{
        uid: "bad-status",
        name: "bad-status",
        display_name: "Bad Status",
        status: :invalid_enum,
        metadata: %{},
        owner_principal_uid: "owner-uid"
      })

      assert [{:status, {_msg, _}}] = cs.errors
    end
  end

  describe "foreign key integrity" do
    test "owner_principal_uid field is present in changeset" do
      cs = Company.changeset(%Company{}, %{
        uid: "orphan",
        name: "orphan-company",
        display_name: "Orphan Company",
        status: :created,
        metadata: %{},
        owner_principal_uid: "nonexistent-uid-that-does-not-exist-in-db"
      })

      assert get_field(cs, :owner_principal_uid) ==
               "nonexistent-uid-that-does-not-exist-in-db"
    end
  end
end
