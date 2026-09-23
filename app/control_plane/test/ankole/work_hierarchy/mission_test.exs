defmodule Ankole.WorkHierarchy.MissionTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Mission

  @moduledoc """
  Tests for Ankole.WorkHierarchy.Mission schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = Mission.changeset(%Mission{}, %{
        uid: "mission-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001"
      })

      assert changeset.valid?
    end

    test "uid is required" do
      changeset = Mission.changeset(%Mission{}, %{
        company_uid: "company-001",
        creator_principal_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn
               {:uid, _} -> true
               _ -> false
             end)
    end

    test "uid must be nonblank" do
      changeset = Mission.changeset(%Mission{}, %{
        uid: "   ",
        company_uid: "company-001",
        creator_principal_uid: "principal-001"
      })

      assert changeset.errors[:uid]
    end

    test "company_uid is required" do
      changeset = Mission.changeset(%Mission{}, %{
        uid: "mission-001",
        creator_principal_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn
               {:company_uid, _} -> true
               _ -> false
             end)
    end

    test "creator_principal_uid is required" do
      changeset = Mission.changeset(%Mission{}, %{
        uid: "mission-001",
        company_uid: "company-001"
      })

      assert Enum.any?(changeset.errors, fn
               {:creator_principal_uid, _} -> true
               _ -> false
             end)
    end
  end

  describe "schema fields" do
    test "exactly the expected fields" do
      assert Mission.__schema__(:fields) ==
               [:id, :uid, :company_uid, :creator_principal_uid, :inserted_at, :updated_at]
    end

    test "no revision fields on identity row" do
      refute :revision_number in Mission.__schema__(:fields)
      refute :current_revision in Mission.__schema__(:fields)
      refute :content in Mission.__schema__(:fields)
      refute :assigned_agent_uid in Mission.__schema__(:fields)
      refute :organizational_unit_uid in Mission.__schema__(:fields)
    end

    test "primary key is id" do
      assert Mission.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "company belongs_to targets Company" do
      assoc = Mission.__schema__(:association, :company)
      assert assoc.related == Company
      assert assoc.owner == Mission
      assert assoc.owner_key == :company_uid
    end

    test "creator belongs_to targets Principal" do
      assoc = Mission.__schema__(:association, :creator)
      assert assoc.related == Principal
      assert assoc.owner == Mission
      assert assoc.owner_key == :creator_principal_uid
    end
  end

  describe "constraint wiring" do
    test "uid unique constraint is wired" do
      constraints =
        Mission.changeset(%Mission{}, %{
          uid: "mission-001",
          company_uid: "company-001",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :uid and c.type == :unique and c.constraint == "missions_uid_index"
             end)
    end

    test "company_uid FK constraint is wired" do
      constraints =
        Mission.changeset(%Mission{}, %{
          uid: "mission-001",
          company_uid: "company-001",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :company_uid and c.type == :foreign_key
             end)
    end

    test "creator_principal_uid FK constraint is wired" do
      constraints =
        Mission.changeset(%Mission{}, %{
          uid: "mission-001",
          company_uid: "company-001",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :creator_principal_uid and c.type == :foreign_key
             end)
    end

    test "uid check constraint is wired" do
      constraints =
        Mission.changeset(%Mission{}, %{
          uid: "mission-001",
          company_uid: "company-001",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :check and c.constraint == "missions_uid_present"
             end)
    end
  end

  describe "field types" do
    test "uid is stored as :string" do
      assert Mission.__schema__(:type, :uid) == :string
    end

    test "company_uid is stored as :string" do
      assert Mission.__schema__(:type, :company_uid) == :string
    end

    test "creator_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert Mission.__schema__(:type, :creator_principal_uid) == Ankole.Ecto.PrincipalKey
    end
  end
end
