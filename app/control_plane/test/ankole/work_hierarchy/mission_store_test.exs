defmodule Ankole.WorkHierarchy.MissionStoreTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.Principals
  alias Ankole.PrincipalsFixtures
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.MissionStore
  alias Ankole.WorkHierarchy.MissionRevision

  @moduledoc """
  Tests for Ankole.WorkHierarchy.MissionStore public API.
  """

  defp transact(fun), do: Repo.transact(fn repo -> fun.(repo) end)

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    defaults = %{
      uid: "test-company-#{suffix}",
      name: "test-company-#{suffix}",
      display_name: "Test Company",
      status: :active,
      metadata: %{},
      owner_principal_uid: owner_uid
    }

    {:ok, company} =
      %Company{}
      |> Company.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    company
  end

  defp human_owner_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end

  defp create_unit!(company_uid) do
    suffix = System.unique_integer([:positive])
    {:ok, unit} =
      %Company.OrganizationalUnit{}
      |> Company.OrganizationalUnit.changeset(%{
        uid: "unit-test-#{suffix}",
        name: "Test Unit #{suffix}",
        company_uid: company_uid
      })
      |> Repo.insert()
    unit
  end

  describe "create_mission" do
    test "valid Human member creates Mission with first revision targeting Agent" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      assert {:ok, {mission, revision}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-human-001",
                   creator_principal_uid: human.uid,
                   content: "Defend the realm.",
                   assigned_agent_uid: human.uid
                 })
               end)

      assert mission.uid == "mission-human-001"
      assert mission.company_uid == company.uid
      assert revision.revision_number == 1
      assert revision.current_revision == true
      assert revision.content == "Defend the realm."
    end

    test "valid same-Company Agent creates Mission" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
        end)

      assert {:ok, {mission, revision}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-agent-001",
                   creator_principal_uid: agent.uid,
                   content: "Research deep topics.",
                   assigned_agent_uid: agent.uid
                 })
               end)

      assert mission.uid == "mission-agent-001"
      assert revision.assigned_agent_uid == agent.uid
      assert revision.current_revision == true
    end

    test "valid active Unit target creates Mission" do
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      unit = create_unit!(company_a.uid)

      system = PrincipalsFixtures.system_fixture()

      assert {:ok, {mission, revision}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company_a.uid, %{
                   uid: "mission-unit-001",
                   creator_principal_uid: system.uid,
                   content: "Coordinate unit activities.",
                   organizational_unit_uid: unit.uid
                 })
               end)

      assert mission.uid == "mission-unit-001"
      assert revision.organizational_unit_uid == unit.uid
      assert revision.current_revision == true
    end

    test "nonexistent Company is rejected" do
      human = human_owner_fixture()

      assert {:error, :company_not_found} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, "nonexistent-company", %{
                   uid: "mission-fail-001",
                   creator_principal_uid: human.uid,
                   content: "Content",
                   assigned_agent_uid: human.uid
                 })
               end)
    end

    test "nonexistent creator is rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :creator_not_found} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-fail-002",
                   creator_principal_uid: "nonexistent-principal",
                   content: "Content",
                   assigned_agent_uid: nil,
                   organizational_unit_uid: create_unit!(company.uid).uid
                 })
               end)
    end

    test "disabled Human creator is rejected" do
      human = human_owner_fixture()

      disabled =
        human
        |> Principal.changeset(%{status: :disabled})
        |> Repo.update()
        |> elem(1)

      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, {:creator_not_active, :disabled}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-fail-003",
                   creator_principal_uid: disabled.uid,
                   content: "Content",
                   assigned_agent_uid: nil,
                   organizational_unit_uid: create_unit!(company.uid).uid
                 })
               end)
    end

    test "Human non-member is rejected" do
      human = human_owner_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :creator_not_member} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-fail-004",
                   creator_principal_uid: human.uid,
                   content: "Content",
                   assigned_agent_uid: human.uid
                 })
               end)
    end

    test "cross-Company Agent is rejected" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_a.uid, agent.uid)
        end)

      assert {:error, :agent_already_in_company} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company_b.uid, %{
                   uid: "mission-fail-005",
                   creator_principal_uid: agent.uid,
                   content: "Content",
                   assigned_agent_uid: agent.uid
                 })
               end)
    end

    test "missing Agent subtype is rejected" do
      human = human_owner_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, principal} =
        %Principal{}
        |> Principal.changeset(%{uid: "fake-agent-no-subtype", type: :agent, status: :active, display_name: "Fake"})
        |> Repo.insert()

      assert {:error, :agent_subtype_missing} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-fail-006",
                   creator_principal_uid: principal.uid,
                   content: "Content",
                   assigned_agent_uid: principal.uid
                 })
               end)
    end

    test "duplicate uid is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      assert {:ok, {_mission, _revision}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-dup-001",
                   creator_principal_uid: human.uid,
                   content: "First mission",
                   assigned_agent_uid: human.uid
                 })
               end)

      assert {:error, _changeset} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-dup-001",
                   creator_principal_uid: human.uid,
                   content: "Duplicate mission",
                   assigned_agent_uid: human.uid
                 })
               end)
    end

    test "nil creator UID is normalized to nil and rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :invalid_uid} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-fail-007",
                   creator_principal_uid: nil,
                   content: "Content",
                   assigned_agent_uid: nil,
                   organizational_unit_uid: create_unit!(company.uid).uid
                 })
               end)
    end

    test "disabled System creator is rejected" do
      system = PrincipalsFixtures.system_fixture()

      disabled_system =
        system
        |> Principal.changeset(%{status: :disabled})
        |> Repo.update()
        |> elem(1)

      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, {:creator_not_active, :disabled}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-fail-008",
                   creator_principal_uid: disabled_system.uid,
                   content: "Content",
                   assigned_agent_uid: nil,
                   organizational_unit_uid: create_unit!(company.uid).uid
                 })
               end)
    end
  end

  describe "fetch_mission" do
    test "hit returns Mission identity" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      {:ok, {mission, _revision}} =
        transact(fn repo ->
          MissionStore.create_mission(repo, company.uid, %{
            uid: "mission-fetch-001",
            creator_principal_uid: human.uid,
            content: "Fetch content",
            assigned_agent_uid: human.uid
          })
        end)

      fetched = MissionStore.fetch_mission(Repo, company.uid, mission.uid)
      assert fetched.uid == mission.uid
      assert fetched.company_uid == company.uid
    end

    test "miss returns nil" do
      result = MissionStore.fetch_mission(Repo, "nonexistent-company", "nonexistent-mission")
      assert result == nil
    end
  end

  describe "fetch_current_revision" do
    test "hit returns current revision" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      {:ok, {_mission, revision}} =
        transact(fn repo ->
          MissionStore.create_mission(repo, company.uid, %{
            uid: "mission-cur-001",
            creator_principal_uid: human.uid,
            content: "Current content",
            assigned_agent_uid: human.uid
          })
        end)

      current = MissionStore.fetch_current_revision(Repo, company.uid, revision.mission_uid)
      assert current.id == revision.id
      assert current.current_revision == true
    end

    test "miss returns nil when no revisions exist" do
      result = MissionStore.fetch_current_revision(Repo, "c1", "m-nonexistent")
      assert result == nil
    end
  end

  describe "list_mission_revisions" do
    test "returns all revisions ordered by version" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      {:ok, {mission, _r1}} =
        transact(fn repo ->
          MissionStore.create_mission(repo, company.uid, %{
            uid: "mission-list-001",
            creator_principal_uid: human.uid,
            content: "Original content",
            assigned_agent_uid: human.uid
          })
        end)

      transact(fn repo ->
        MissionStore.create_revision(repo, company.uid, mission.uid, %{
          creator_principal_uid: human.uid,
          content: "Revised content",
          assigned_agent_uid: human.uid
        })
      end)

      revisions = MissionStore.list_mission_revisions(Repo, company.uid, mission.uid)
      assert length(revisions) == 2
      assert hd(revisions).revision_number == 1
      assert hd(revisions).current_revision == false
      assert revisions |> List.last() |> Map.get(:revision_number) == 2
      assert revisions |> List.last() |> Map.get(:current_revision) == true
    end
  end

  describe "create_revision" do
    test "increments version and flips current flag" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      {:ok, {mission, revision1}} =
        transact(fn repo ->
          MissionStore.create_mission(repo, company.uid, %{
            uid: "mission-rev-001",
            creator_principal_uid: human.uid,
            content: "Version 1 content",
            assigned_agent_uid: human.uid
          })
        end)

      assert revision1.revision_number == 1
      assert revision1.current_revision == true

      {:ok, revision2} =
        transact(fn repo ->
          MissionStore.create_revision(repo, company.uid, mission.uid, %{
            creator_principal_uid: human.uid,
            content: "Version 2 content",
            assigned_agent_uid: human.uid
          })
        end)

      assert revision2.revision_number == 2
      assert revision2.current_revision == true
      assert revision2.content == "Version 2 content"

      # Verify old revision is no longer current
      revisions = MissionStore.list_mission_revisions(Repo, company.uid, mission.uid)
      assert Enum.count(revisions, & &1.current_revision) == 1
      assert revisions |> Enum.find(& &1.current_revision) |> Map.get(:revision_number) == 2
    end

    test "preserves historical revision content" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      {:ok, {mission, _r1}} =
        transact(fn repo ->
          MissionStore.create_mission(repo, company.uid, %{
            uid: "mission-preserve-001",
            creator_principal_uid: human.uid,
            content: "Original mandate",
            assigned_agent_uid: human.uid
          })
        end)

      transact(fn repo ->
        MissionStore.create_revision(repo, company.uid, mission.uid, %{
          creator_principal_uid: human.uid,
          content: "Updated mandate",
          assigned_agent_uid: human.uid
        })
      end)

      revisions = MissionStore.list_mission_revisions(Repo, company.uid, mission.uid)
      original = revisions |> Enum.find(&(&1.revision_number == 1))
      assert original.content == "Original mandate"
    end

    test "nonexistent mission is rejected" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      assert {:error, :mission_not_found} =
               transact(fn repo ->
                 MissionStore.create_revision(repo, company.uid, "nonexistent-mission", %{
                   creator_principal_uid: human.uid,
                   content: "New content",
                   assigned_agent_uid: human.uid
                 })
               end)
    end

    test "Agent target is preserved across revisions" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
        end)

      {:ok, {mission, r1}} =
        transact(fn repo ->
          MissionStore.create_mission(repo, company.uid, %{
            uid: "mission-target-001",
            creator_principal_uid: agent.uid,
            content: "Targeted content",
            assigned_agent_uid: agent.uid
          })
        end)

      assert r1.assigned_agent_uid == agent.uid

      {:ok, r2} =
        transact(fn repo ->
          MissionStore.create_revision(repo, company.uid, mission.uid, %{
            creator_principal_uid: agent.uid,
            content: "Updated targeted content",
            assigned_agent_uid: agent.uid
          })
        end)

      assert r2.assigned_agent_uid == agent.uid
      assert r2.content == "Updated targeted content"
    end
  end

  describe "list_company_missions" do
    test "returns only missions for the Company" do
      %{principal: agent_a} = PrincipalsFixtures.agent_fixture()
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)

      {:ok, _membership_a} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_a.uid, agent_a.uid)
        end)

      transact(fn repo ->
        MissionStore.create_mission(repo, company_a.uid, %{
          uid: "mission-comp-a-001",
          creator_principal_uid: agent_a.uid,
          content: "Company A mission",
          assigned_agent_uid: agent_a.uid
        })
      end)

      %{principal: agent_b} = PrincipalsFixtures.agent_fixture()
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_b} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_b.uid, agent_b.uid)
        end)

      transact(fn repo ->
        MissionStore.create_mission(repo, company_b.uid, %{
          uid: "mission-comp-b-001",
          creator_principal_uid: agent_b.uid,
          content: "Company B mission",
          assigned_agent_uid: agent_b.uid
        })
      end)

      missions_a = MissionStore.list_company_missions(Repo, company_a.uid)
      assert length(missions_a) == 1
      assert hd(missions_a).uid == "mission-comp-a-001"

      missions_b = MissionStore.list_company_missions(Repo, company_b.uid)
      assert length(missions_b) == 1
      assert hd(missions_b).uid == "mission-comp-b-001"
    end
  end

  describe "Agent Library projection" do
    test "Agent-targeted Mission updates MISSION.md projection" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
        end)

      new_content = "Project-aligned mission content"

      assert {:ok, {mission, revision}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-proj-001",
                   creator_principal_uid: agent.uid,
                   content: new_content,
                   assigned_agent_uid: agent.uid
                 })
               end)

      # Verify Agent Library has been updated
      {:ok, documents} = Ankole.AIAgent.Library.list_agent_documents(agent.uid)
      assert documents["mission"]["content"] == new_content
      assert documents["mission"]["content_hash"] == Ankole.AIAgent.Library.SourceReader.hash(new_content)
    end

    test "Unit-targeted Mission does not touch Agent Library" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)
      unit = create_unit!(company.uid)

      system = PrincipalsFixtures.system_fixture()

      assert {:ok, {mission, _revision}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company.uid, %{
                   uid: "mission-proj-002",
                   creator_principal_uid: system.uid,
                   content: "Unit mission content",
                   organizational_unit_uid: unit.uid
                 })
               end)

      # No Agent Library side effect expected (no Agent involved)
      assert mission.uid == "mission-proj-002"
    end
  end

  describe "one-current-effective-Agent invariant" do
    test "two different Missions cannot both be current for the same Agent" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_a} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_a.uid, agent.uid)
        end)

      # Do NOT add to company_b - that would violate one-company invariant

      # First Mission succeeds
      assert {:ok, {_m1, _r1}} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company_a.uid, %{
                   uid: "mission-compete-001",
                   creator_principal_uid: agent.uid,
                   content: "First mission",
                   assigned_agent_uid: agent.uid
                 })
               end)

      # Second Mission targeting same Agent fails due to one-current-per-agent constraint
      assert {:error, _} =
               transact(fn repo ->
                 MissionStore.create_mission(repo, company_b.uid, %{
                   uid: "mission-compete-002",
                   creator_principal_uid: agent.uid,
                   content: "Second mission",
                   assigned_agent_uid: agent.uid
                 })
               end)
    end
  end
end
