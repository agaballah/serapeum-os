defmodule Ankole.WorkHierarchy.MissionRevisionTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company.OrganizationalUnit
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Goal
  alias Ankole.WorkHierarchy.MissionRevision

  @moduledoc """
  Tests for Ankole.WorkHierarchy.MissionRevision schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        assigned_agent_uid: "agent-001",
        creator_principal_uid: "principal-001",
        content: "Be excellent to each other.",
        content_hash: "abc123"
      })

      assert changeset.valid?
    end

    test "mission_uid is required" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        revision_number: 1,
        current_revision: true,
        creator_principal_uid: "principal-001",
        content: "Test content",
        content_hash: "abc"
      })

      assert Enum.any?(changeset.errors, fn {:mission_uid, _} -> true; _ -> false end)
    end

    test "revision_number is required" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        current_revision: true,
        creator_principal_uid: "principal-001",
        content: "Test content",
        content_hash: "abc"
      })

      assert Enum.any?(changeset.errors, fn {:revision_number, _} -> true; _ -> false end)
    end

    test "current_revision is required" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        creator_principal_uid: "principal-001",
        content: "Test content",
        content_hash: "abc"
      })

      assert Enum.any?(changeset.errors, fn {:current_revision, _} -> true; _ -> false end)
    end

    test "creator_principal_uid is required" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        content: "Test content",
        content_hash: "abc"
      })

      assert Enum.any?(changeset.errors, fn {:creator_principal_uid, _} -> true; _ -> false end)
    end

    test "content is required" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        creator_principal_uid: "principal-001",
        content_hash: "abc"
      })

      assert Enum.any?(changeset.errors, fn {:content, _} -> true; _ -> false end)
    end

    test "content must be nonblank" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        creator_principal_uid: "principal-001",
        content: "   ",
        content_hash: "abc"
      })

      assert changeset.errors[:content]
    end

    test "content_hash is required" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        creator_principal_uid: "principal-001",
        content: "Test content"
      })

      assert Enum.any?(changeset.errors, fn {:content_hash, _} -> true; _ -> false end)
    end

    test "rejects both target types" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        assigned_agent_uid: "agent-001",
        organizational_unit_uid: "unit-001",
        creator_principal_uid: "principal-001",
        content: "Test",
        content_hash: "abc"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:target, _} -> true; _ -> false end)
    end

    test "rejects neither target type" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        creator_principal_uid: "principal-001",
        content: "Test",
        content_hash: "abc"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:target, _} -> true; _ -> false end)
    end

    test "accepts Agent target only" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        assigned_agent_uid: "agent-001",
        creator_principal_uid: "principal-001",
        content: "Test",
        content_hash: "abc"
      })

      assert changeset.valid?
    end

    test "accepts Unit target only" do
      changeset = MissionRevision.changeset(%MissionRevision{}, %{
        mission_uid: "mission-001",
        revision_number: 1,
        current_revision: true,
        organizational_unit_uid: "unit-001",
        creator_principal_uid: "principal-001",
        content: "Test",
        content_hash: "abc"
      })

      assert changeset.valid?
    end
  end

  describe "schema fields" do
    test "exactly the expected fields" do
      assert MissionRevision.__schema__(:fields) ==
               [
                 :id,
                 :revision_number,
                 :current_revision,
                 :content,
                 :content_hash,
                 :mission_uid,
                 :goal_uid,
                 :assigned_agent_uid,
                 :organizational_unit_uid,
                 :creator_principal_uid,
                 :inserted_at,
                 :updated_at
               ]
    end

    test "primary key is id" do
      assert MissionRevision.__schema__(:primary_key) == [:id]
    end
  end

  describe "associations" do
    test "mission belongs_to targets Mission" do
      assoc = MissionRevision.__schema__(:association, :mission)
      assert assoc.related == Ankole.WorkHierarchy.Mission
      assert assoc.owner == MissionRevision
      assert assoc.owner_key == :mission_uid
    end

    test "goal optional belongs_to targets Goal" do
      assoc = MissionRevision.__schema__(:association, :goal)
      assert assoc.related == Goal
      assert assoc.owner == MissionRevision
      assert assoc.owner_key == :goal_uid
    end

    test "assigned_agent belongs_to targets Principal" do
      assoc = MissionRevision.__schema__(:association, :assigned_agent)
      assert assoc.related == Principal
      assert assoc.owner == MissionRevision
      assert assoc.owner_key == :assigned_agent_uid
    end

    test "unit belongs_to targets OrganizationalUnit" do
      assoc = MissionRevision.__schema__(:association, :unit)
      assert assoc.related == OrganizationalUnit
      assert assoc.owner == MissionRevision
      assert assoc.owner_key == :organizational_unit_uid
    end

    test "creator belongs_to targets Principal" do
      assoc = MissionRevision.__schema__(:association, :creator)
      assert assoc.related == Principal
      assert assoc.owner == MissionRevision
      assert assoc.owner_key == :creator_principal_uid
    end
  end

  describe "constraint wiring" do
    test "uid_version unique constraint is wired" do
      constraints =
        MissionRevision.changeset(%MissionRevision{}, %{
          mission_uid: "m1",
          revision_number: 1,
          current_revision: true,
          assigned_agent_uid: "a1",
          creator_principal_uid: "c1",
          content: "Test",
          content_hash: "abc"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :unique and c.constraint == "mission_revisions_uid_version_index"
             end)
    end

    test "one_current_per_mission partial unique is wired" do
      constraints =
        MissionRevision.changeset(%MissionRevision{}, %{
          mission_uid: "m1",
          revision_number: 1,
          current_revision: true,
          assigned_agent_uid: "a1",
          creator_principal_uid: "c1",
          content: "Test",
          content_hash: "abc"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :unique and c.constraint == "mission_revisions_one_current_per_mission"
             end)
    end

    test "one_current_per_agent partial unique is wired" do
      constraints =
        MissionRevision.changeset(%MissionRevision{}, %{
          mission_uid: "m1",
          revision_number: 1,
          current_revision: true,
          assigned_agent_uid: "a1",
          creator_principal_uid: "c1",
          content: "Test",
          content_hash: "abc"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :unique and c.constraint == "mission_revisions_one_current_per_agent"
             end)
    end

    test "content check constraint is wired" do
      constraints =
        MissionRevision.changeset(%MissionRevision{}, %{
          mission_uid: "m1",
          revision_number: 1,
          current_revision: true,
          assigned_agent_uid: "a1",
          creator_principal_uid: "c1",
          content: "Test",
          content_hash: "abc"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.type == :check and c.constraint == "mission_revisions_content_present"
             end)
    end

    test "FK constraints are wired" do
      constraints =
        MissionRevision.changeset(%MissionRevision{}, %{
          mission_uid: "m1",
          revision_number: 1,
          current_revision: true,
          assigned_agent_uid: "a1",
          creator_principal_uid: "c1",
          content: "Test",
          content_hash: "abc"
        }).constraints

      assert Enum.any?(constraints, fn c ->
               c.field == :mission_uid and c.type == :foreign_key
             end)

      assert Enum.any?(constraints, fn c ->
               c.field == :assigned_agent_uid and c.type == :foreign_key
             end)

      assert Enum.any?(constraints, fn c ->
               c.field == :organizational_unit_uid and c.type == :foreign_key
             end)

      assert Enum.any?(constraints, fn c ->
               c.field == :creator_principal_uid and c.type == :foreign_key
             end)
    end
  end

  describe "field types" do
    test "mission_uid is stored as :string" do
      assert MissionRevision.__schema__(:type, :mission_uid) == :string
    end

    test "revision_number is stored as :integer" do
      assert MissionRevision.__schema__(:type, :revision_number) == :integer
    end

    test "current_revision is stored as :boolean" do
      assert MissionRevision.__schema__(:type, :current_revision) == :boolean
    end

    test "goal_uid is stored as :string" do
      assert MissionRevision.__schema__(:type, :goal_uid) == :string
    end

    test "assigned_agent_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert MissionRevision.__schema__(:type, :assigned_agent_uid) == Ankole.Ecto.PrincipalKey
    end

    test "organizational_unit_uid is stored as :string" do
      assert MissionRevision.__schema__(:type, :organizational_unit_uid) == :string
    end

    test "creator_principal_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert MissionRevision.__schema__(:type, :creator_principal_uid) == Ankole.Ecto.PrincipalKey
    end

    test "content is stored as :string" do
      assert MissionRevision.__schema__(:type, :content) == :string
    end

    test "content_hash is stored as :string" do
      assert MissionRevision.__schema__(:type, :content_hash) == :string
    end
  end
end
