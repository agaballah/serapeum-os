defmodule Ankole.Company.AgentCompanyStoreTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.AgentCompanyStore
  alias Ankole.Company.Membership
  alias Ankole.Company.MembershipStore

  import Ankole.PrincipalsFixtures

  describe "bind_agent_to_company" do
    setup do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})
      agent = agent_fixture(%{owner_principal_uid: owner.principal.uid})
      %{owner: owner, company: company, agent: agent}
    end

    test "valid binding succeeds", %{company: company, agent: agent} do
      assert {:ok, membership} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      assert membership.company_uid == company.uid
      assert membership.principal_uid == agent.principal.uid
      assert MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end

    test "same-company bind is idempotent", %{company: company, agent: agent} do
      assert {:ok, _} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      assert {:ok, existing} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      assert existing.company_uid == company.uid
      assert existing.principal_uid == agent.principal.uid
      assert MembershipStore.membership_count(Repo, agent.principal.uid) == 1
    end

    test "second company is rejected", %{company: company, agent: agent} do
      company_b = company_fixture(company.owner_principal_uid, %{status: :active})

      assert {:ok, _} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      assert {:error, :agent_already_in_company} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company_b.uid)

      assert MembershipStore.company_uids_for_principal(Repo, agent.principal.uid) == [
               company.uid
             ]
    end

    test "corrupt multi-membership state rejects bind", %{agent: agent, owner: owner} do
      company_a = company_fixture(owner.principal.uid, %{status: :active})
      company_b = company_fixture(owner.principal.uid, %{status: :active})

      for company <- [company_a, company_b] do
        Repo.insert(
          Membership.changeset(%Membership{}, %{
            company_uid: company.uid,
            principal_uid: agent.principal.uid
          })
        )
      end

      before_count = MembershipStore.membership_count(Repo, agent.principal.uid)
      assert before_count == 2

      assert {:error, :agent_membership_invariant_violation} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company_a.uid)

      after_count = MembershipStore.membership_count(Repo, agent.principal.uid)
      assert after_count == 2
    end
  end

  describe "company status" do
    setup do
      owner = human_fixture()
      company_created = company_fixture(owner.principal.uid, %{status: :created})
      company_suspended = company_fixture(owner.principal.uid, %{status: :suspended})
      company_archived = company_fixture(owner.principal.uid, %{status: :archived})
      agent = agent_fixture(%{owner_principal_uid: owner.principal.uid})

      %{
        owner: owner,
        company_created: company_created,
        company_suspended: company_suspended,
        company_archived: company_archived,
        agent: agent
      }
    end

    test "active company is accepted", %{agent: agent, owner: owner} do
      company = company_fixture(owner.principal.uid, %{status: :active})

      assert {:ok, _} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)
    end

    test "created company is rejected", %{company_created: company, agent: agent} do
      assert {:error, {:company_not_active, :created}} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end

    test "suspended company is rejected", %{company_suspended: company, agent: agent} do
      assert {:error, {:company_not_active, :suspended}} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end

    test "archived company is rejected", %{company_archived: company, agent: agent} do
      assert {:error, {:company_not_active, :archived}} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end
  end

  describe "agent type" do
    setup do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})
      %{owner: owner, company: company}
    end

    test "human principal is rejected", %{company: company, owner: owner} do
      assert {:error, {:principal_not_agent, :human}} =
               AgentCompanyStore.bind_agent_to_company(Repo, owner.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, owner.principal.uid)
    end

    test "system principal is rejected", %{company: company} do
      system = system_fixture()

      assert {:error, {:principal_not_agent, :system}} =
               AgentCompanyStore.bind_agent_to_company(Repo, system.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, system.uid)
    end

    test "unknown principal is rejected", %{company: company} do
      assert {:error, :not_found} =
               AgentCompanyStore.bind_agent_to_company(Repo, "nonexistent-principal", company.uid)
    end
  end

  describe "owner alignment" do
    setup do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})
      agent = agent_fixture(%{owner_principal_uid: owner.principal.uid})
      %{company: company, agent: agent}
    end

    test "matching owner succeeds", %{company: company, agent: agent} do
      assert {:ok, _} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)
    end

    test "mismatched owner is rejected", %{company: company} do
      owner_b = human_fixture()
      agent = agent_fixture(%{owner_principal_uid: owner_b.principal.uid})

      assert {:error, :agent_owner_company_owner_mismatch} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end
  end

  describe "unknown company" do
    setup do
      owner = human_fixture()
      agent = agent_fixture(%{owner_principal_uid: owner.principal.uid})
      %{agent: agent}
    end

    test "unknown company is rejected", %{agent: agent} do
      assert {:error, :company_not_found} =
               transact(fn repo ->
                 AgentCompanyStore.bind_agent_to_company(repo, agent.principal.uid, "nonexistent-company")
               end)
    end
  end

  describe "concurrency" do
    setup do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :active})
      agent = agent_fixture(%{owner_principal_uid: owner.principal.uid})
      %{company: company, agent: agent}
    end

    test "concurrent binds to same company leave exactly one membership", %{company: company, agent: agent} do
      owner_pid = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, owner_pid, self())

          AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, owner_pid, self())

          AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)
        end)

      results = [Task.await(task_a), Task.await(task_b)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 2
      assert MembershipStore.membership_count(Repo, agent.principal.uid) == 1
    end

    test "concurrent binds to different companies leave exactly one membership", %{company: company, agent: agent} do
      company_a = company_fixture(company.owner_principal_uid, %{status: :active})
      company_b = company_fixture(company.owner_principal_uid, %{status: :active})

      owner_pid = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, owner_pid, self())

          AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company_a.uid)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, owner_pid, self())

          AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company_b.uid)
        end)

      results = [Task.await(task_a), Task.await(task_b)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, _}, &1)) == 1
      assert MembershipStore.membership_count(Repo, agent.principal.uid) == 1
    end
  end

  describe "rollback" do
    setup do
      owner = human_fixture()
      company_active = company_fixture(owner.principal.uid, %{status: :active})
      company_created = company_fixture(owner.principal.uid, %{status: :created})
      agent = agent_fixture(%{owner_principal_uid: owner.principal.uid})
      %{owner: owner, company_active: company_active, company_created: company_created, agent: agent}
    end

    test "inactive company creates no membership", %{company_created: company, agent: agent} do
      assert {:error, {:company_not_active, :created}} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end

    test "non-agent principal creates no membership", %{company_active: company, owner: owner} do
      assert {:error, {:principal_not_agent, :human}} =
               AgentCompanyStore.bind_agent_to_company(Repo, owner.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, owner.principal.uid)
    end

    test "owner mismatch creates no membership", %{agent: agent} do
      other_owner = human_fixture()
      company = company_fixture(other_owner.principal.uid, %{status: :active})

      assert {:error, :agent_owner_company_owner_mismatch} =
               AgentCompanyStore.bind_agent_to_company(Repo, agent.principal.uid, company.uid)

      refute MembershipStore.member?(Repo, company.uid, agent.principal.uid)
    end
  end

  describe "boundary" do
    test "the store source has no dependency on Ankole.AuthZ" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/agent_company_store.ex", __DIR__)
        )

      refute String.contains?(source, "Ankole.AuthZ")
    end

    test "the store source has no OrganizationalUnitStore composition" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/agent_company_store.ex", __DIR__)
        )

      refute String.contains?(source, "OrganizationalUnitStore")
    end

    test "the store source has no Company lifecycle mutation" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/agent_company_store.ex", __DIR__)
        )

      refute String.contains?(source, "suspend_company")
      refute String.contains?(source, "reactivate_company")
      refute String.contains?(source, "archive_company")
      refute String.contains?(source, "bootstrap_company")
    end

    test "the store source has no Principal mutation" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/agent_company_store.ex", __DIR__)
        )

      mutation_patterns = [
        "Principals.Principal.changeset",
        "Principals.insert",
        "Principals.update",
        "Principals.delete",
        "Repo.insert.*Principal",
        "Repo.update.*Principal",
        "Repo.delete.*Principal"
      ]

      Enum.each(mutation_patterns, fn pattern ->
        refute Regex.match?(~r/#{pattern}/, source), "Found Principal mutation: #{pattern}"
      end)
    end

    test "the store source has no Agent creation" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/agent_company_store.ex", __DIR__)
        )

      refute String.contains?(source, "create_agent")
    end
  end

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    defaults = %{
      uid: "test-company-#{suffix}",
      name: "test-company-#{suffix}",
      display_name: "Test Company",
      status: :created,
      metadata: %{},
      owner_principal_uid: owner_uid
    }

    {:ok, company} =
      %Company{}
      |> Company.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    company
  end

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end
end
