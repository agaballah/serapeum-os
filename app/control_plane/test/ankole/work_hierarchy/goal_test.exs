defmodule Ankole.WorkHierarchy.GoalTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Goal

  @moduledoc """
  Tests for Ankole.WorkHierarchy.Goal schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "goal-001",
        company_uid: "company-001",
        title: "Test Goal",
        description: "A test goal",
        creator_principal_uid: "principal-001"
      })

      assert changeset.valid?
    end

    test "uid is required" do
      changeset = Goal.changeset(%Goal{}, %{
        company_uid: "company-001",
        title: "Test Goal",
        creator_principal_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn
               {:uid, {"can't be blank", _}} -> true
               _ -> false
             end)
    end

    test "uid must be nonblank" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "   ",
        company_uid: "company-001",
        title: "Test Goal",
        creator_principal_uid: "principal-001"
      })

      assert changeset.errors[:uid]
    end

    test "company_uid is required" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "goal-001",
        title: "Test Goal",
        creator_principal_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn
               {:company_uid, {"can't be blank", _}} -> true
               _ -> false
             end)
    end

    test "title is required" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "goal-001",
        company_uid: "company-001",
        creator_principal_uid: "principal-001"
      })

      assert Enum.any?(changeset.errors, fn
               {:title, {"can't be blank", _}} -> true
               _ -> false
             end)
    end

    test "title must be nonblank" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "goal-001",
        company_uid: "company-001",
        title: "   ",
        creator_principal_uid: "principal-001"
      })

      assert changeset.errors[:title]
    end

    test "creator_principal_uid is required" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "goal-001",
        company_uid: "company-001",
        title: "Test Goal"
      })

      assert Enum.any?(changeset.errors, fn
               {:creator_principal_uid, {"can't be blank", _}} -> true
               _ -> false
             end)
    end

    test "description is optional" do
      changeset = Goal.changeset(%Goal{}, %{
        uid: "goal-001",
        company_uid: "company-001",
        title: "Test Goal",
        creator_principal_uid: "principal-001"
      })

      assert changeset.valid?
    end
  end

  describe "schema fields" do
    test "exactly the expected fields" do
      assert Goal.__schema__(:fields) ==
               [:id, :uid, :title, :description, :company_uid, :creator_principal_uid, :inserted_at, :updated_at]
    end

    test "no status field" do
      refute :status in Goal.__schema__(:fields)
    end

    test "no metadata field" do
      refute :metadata in Goal.__schema__(:fields)
    end

    test "no priority field" do
      refute :priority in Goal.__schema__(:fields)
    end

    test "no due_date field" do
      refute :due_date in Goal.__schema__(:fields)
    end

    test "primary key is id" do
      assert Goal.__schema__(:primary_key) == [:id]
    end

    test "inserted_at and updated_at are present" do
      assert :inserted_at in Goal.__schema__(:fields)
      assert :updated_at in Goal.__schema__(:fields)
    end
  end

  describe "associations" do
    test "company belongs_to targets Ankole.Company" do
      assoc = Goal.__schema__(:association, :company)
      assert assoc.related == Company
      assert assoc.owner == Goal
      assert assoc.owner_key == :company_uid
      assert assoc.related_key == :uid
    end

    test "creator belongs_to targets Principal" do
      assoc = Goal.__schema__(:association, :creator)
      assert assoc.related == Principal
      assert assoc.owner == Goal
      assert assoc.owner_key == :creator_principal_uid
      assert assoc.related_key == :uid
    end
  end

  describe "constraint wiring" do
    test "goals_uid_index unique constraint is wired" do
      constraints =
        Goal.changeset(%Goal{}, %{
          uid: "goal-001",
          company_uid: "company-001",
          title: "Test Goal",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :uid and c.type == :unique and
                 c.constraint == "goals_uid_index"
             end)
    end

    test "company_uid FK constraint is wired" do
      constraints =
        Goal.changeset(%Goal{}, %{
          uid: "goal-001",
          company_uid: "company-001",
          title: "Test Goal",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :company_uid and c.type == :foreign_key
             end)
    end

    test "creator_principal_uid FK constraint is wired" do
      constraints =
        Goal.changeset(%Goal{}, %{
          uid: "goal-001",
          company_uid: "company-001",
          title: "Test Goal",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :creator_principal_uid and c.type == :foreign_key
             end)
    end

    test "uid check constraint is wired" do
      constraints =
        Goal.changeset(%Goal{}, %{
          uid: "goal-001",
          company_uid: "company-001",
          title: "Test Goal",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :check and c.constraint == "goals_uid_present"
             end)
    end

    test "title check constraint is wired" do
      constraints =
        Goal.changeset(%Goal{}, %{
          uid: "goal-001",
          company_uid: "company-001",
          title: "Test Goal",
          creator_principal_uid: "principal-001"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :check and c.constraint == "goals_title_present"
             end)
    end
  end

  describe "field types" do
    test "uid is stored as :string" do
      assert Goal.__schema__(:type, :uid) == :string
    end

    test "title is stored as :string" do
      assert Goal.__schema__(:type, :title) == :string
    end

    test "description is stored as :string" do
      assert Goal.__schema__(:type, :description) == :string
    end

    test "company_uid is stored as :string" do
      assert Goal.__schema__(:type, :company_uid) == :string
    end

    test "creator_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert Goal.__schema__(:type, :creator_principal_uid) == Ankole.Ecto.PrincipalKey
    end
  end
end
