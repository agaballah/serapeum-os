defmodule Ankole.WorkHierarchy.GoalStoreTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.PrincipalsFixtures
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.GoalStore

  @moduledoc """
  Tests for Ankole.WorkHierarchy.GoalStore public API.
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

  describe "create_goal" do
    test "valid Human member creates Goal" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      assert {:ok, goal} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-human-001",
                   title: "Human Goal",
                   creator_principal_uid: human.uid
                 })
               end)

      assert goal.uid == "goal-human-001"
      assert goal.company_uid == company.uid
      assert goal.title == "Human Goal"
      assert goal.creator_principal_uid == human.uid
    end

    test "valid same-Company Agent creates Goal" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, agent.uid)
        end)

      assert {:ok, goal} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-agent-001",
                   title: "Agent Goal",
                   creator_principal_uid: agent.uid
                 })
               end)

      assert goal.uid == "goal-agent-001"
      assert goal.company_uid == company.uid
    end

    test "valid active System Principal creates Goal" do
      system = PrincipalsFixtures.system_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:ok, goal} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-system-001",
                   title: "System Goal",
                   creator_principal_uid: system.uid
                 })
               end)

      assert goal.uid == "goal-system-001"
      assert goal.company_uid == company.uid
    end

    test "nonexistent Company is rejected" do
      human = human_owner_fixture()

      assert {:error, :company_not_found} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, "nonexistent-company", %{
                   uid: "goal-fail-001",
                   title: "Fail Goal",
                   creator_principal_uid: human.uid
                 })
               end)
    end

    test "nonexistent creator is rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :creator_not_found} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-fail-002",
                   title: "Fail Goal",
                   creator_principal_uid: "nonexistent-principal"
                 })
               end)
    end

    test "disabled Human is rejected" do
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
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-fail-003",
                   title: "Fail Goal",
                   creator_principal_uid: disabled.uid
                 })
               end)
    end

    test "Human non-member is rejected" do
      human = human_owner_fixture()
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :creator_not_member} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-fail-004",
                   title: "Fail Goal",
                   creator_principal_uid: human.uid
                 })
               end)
    end

    test "disabled Agent is rejected" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()

      disabled_agent =
        agent
        |> Principal.changeset(%{status: :disabled})
        |> Repo.update()
        |> elem(1)

      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, {:creator_not_active, :disabled}} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-fail-005",
                   title: "Fail Goal",
                   creator_principal_uid: disabled_agent.uid
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
                 GoalStore.create_goal(repo, company_b.uid, %{
                   uid: "goal-fail-006",
                   title: "Fail Goal",
                   creator_principal_uid: agent.uid
                 })
               end)
    end

    test "corrupt Agent multi-Company membership fails closed" do
      %{principal: agent} = PrincipalsFixtures.agent_fixture()
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_a.uid, agent.uid)
        end)

      Repo.insert!(%Ankole.Company.Membership{
        company_uid: company_b.uid,
        principal_uid: agent.uid
      })

      assert {:error, :agent_membership_invariant_violation} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company_a.uid, %{
                   uid: "goal-fail-007",
                   title: "Fail Goal",
                   creator_principal_uid: agent.uid
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

      assert {:ok, _goal} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-dup-001",
                   title: "First Goal",
                   creator_principal_uid: human.uid
                 })
               end)

      assert {:error, _changeset} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-dup-001",
                   title: "Duplicate Goal",
                   creator_principal_uid: human.uid
                 })
               end)
    end

    test "company_uid in attrs cannot override function argument" do
      human = human_owner_fixture()
      company_a = company_fixture(human.uid)
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_a.uid, human.uid)
        end)

      assert {:ok, goal} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company_a.uid, %{
                   uid: "goal-auth-001",
                   title: "Auth Goal",
                   company_uid: company_b.uid,
                   creator_principal_uid: human.uid
                 })
               end)

      assert goal.company_uid == company_a.uid
    end

    test "nil creator UID is normalized to nil and rejected" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:error, :invalid_uid} =
               transact(fn repo ->
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-fail-008",
                   title: "Fail Goal",
                   creator_principal_uid: nil
                 })
               end)
    end

    test "disabled System is rejected" do
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
                 GoalStore.create_goal(repo, company.uid, %{
                   uid: "goal-fail-009",
                   title: "Fail Goal",
                   creator_principal_uid: disabled_system.uid
                 })
               end)
    end
  end

  describe "fetch_goal" do
    test "hit returns Goal" do
      human = human_owner_fixture()
      company = company_fixture(human.uid)

      {:ok, _membership} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company.uid, human.uid)
        end)

      {:ok, goal} =
        transact(fn repo ->
          GoalStore.create_goal(repo, company.uid, %{
            uid: "goal-fetch-001",
            title: "Fetch Goal",
            creator_principal_uid: human.uid
          })
        end)

      fetched = GoalStore.fetch_goal(Repo, company.uid, goal.uid)
      assert fetched.uid == goal.uid
      assert fetched.title == goal.title
    end

    test "miss returns nil" do
      result = GoalStore.fetch_goal(Repo, "nonexistent-company", "nonexistent-goal")
      assert result == nil
    end
  end

  describe "list_company_goals" do
    test "returns only goals for the Company" do
      human = human_owner_fixture()
      owner_a = human_owner_fixture()
      company_a = company_fixture(owner_a.uid)
      owner_b = human_owner_fixture()
      company_b = company_fixture(owner_b.uid)

      {:ok, _membership_a} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_a.uid, human.uid)
        end)

      {:ok, _membership_b} =
        transact(fn repo ->
          Ankole.Company.MembershipStore.add_member(repo, company_b.uid, human.uid)
        end)

      {:ok, goal_a} =
        transact(fn repo ->
          GoalStore.create_goal(repo, company_a.uid, %{
            uid: "goal-list-a-001",
            title: "Company A Goal",
            creator_principal_uid: human.uid
          })
        end)

      {:ok, _goal_b} =
        transact(fn repo ->
          GoalStore.create_goal(repo, company_b.uid, %{
            uid: "goal-list-b-001",
            title: "Company B Goal",
            creator_principal_uid: human.uid
          })
        end)

      goals_a = GoalStore.list_company_goals(Repo, company_a.uid)
      assert length(goals_a) == 1
      assert hd(goals_a).uid == goal_a.uid

      goals_b = GoalStore.list_company_goals(Repo, company_b.uid)
      assert length(goals_b) == 1
      refute hd(goals_b).uid == goal_a.uid
    end
  end
end
