defmodule Ankole.WorkHierarchy.AgentOnboardingTest do
  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.Principals
  alias Ankole.PrincipalsFixtures
  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.MissionStore

  @moduledoc """
  Tests for atomic Agent onboarding through MissionStore.
  """

  defp transact(fun), do: Repo.transact(fn repo -> fun.(repo) end)

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    defaults = %{
      uid: "onboard-company-#{suffix}",
      name: "onboard-company-#{suffix}",
      display_name: "Onboarding Test Company",
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

  describe "atomic onboarding" do
    test "creates Agent + binds to Company + creates first Mission atomically" do
      owner = human_owner_fixture()
      company = company_fixture(owner.uid)

      assert {:ok, result} =
               transact(fn repo ->
                 # Simulate onboarding: create Agent, bind to company, create Mission
                 {:ok, %{principal: agent}} = Principals.create_agent_in_tx(repo, %{
                   uid: "onboard-agent-001",
                   display_name: "Onboarded Agent",
                   role: "Research Analyst",
                   owner_principal_uid: owner.uid
                 })

                  {:ok, _membership} = Ankole.Company.AgentCompanyStore.bind_agent_to_company_in_tx(
                          repo,
                          agent.uid,
                          company.uid
                        )

                 {:ok, {_mission, _revision}} = MissionStore.create_mission(repo, company.uid, %{
                   uid: "onboard-mission-001",
                   creator_principal_uid: agent.uid,
                   content: "Onboarded mission mandate.",
                   assigned_agent_uid: agent.uid
                 })

                 :ok = Ankole.AIAgent.Library.update_mission_projection_in_tx(
                         repo,
                         agent.uid,
                         "Onboarded mission mandate."
                       )

                 :ok = Ankole.RuntimeEvents.notify_agent_home_projection(repo, agent.uid)

                 {:ok, %{agent: agent, company: company}}
               end)

      assert result.agent.uid == "onboard-agent-001"

      # Verify Agent is active and has a current Mission
      {:ok, %{principal: agent}} = Principals.get_agent("onboard-agent-001")
      assert agent.status == :active

      current_mission =
        MissionStore.fetch_current_revision(Repo, company.uid, "onboard-mission-001")

      assert current_mission != nil
      assert current_mission.assigned_agent_uid == agent.uid
    end
  end

  defp human_owner_fixture do
    %{principal: principal} = PrincipalsFixtures.human_fixture()
    principal
  end
end
