defmodule Ankole.Company.MembershipStoreTest do
  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.Membership
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal

  import Ankole.PrincipalsFixtures

  describe "human membership" do
    test "first membership succeeds" do
      owner = human_fixture()
      human = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, membership} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, human.principal.uid)
               end)

      assert membership.company_uid == company.uid
      assert membership.principal_uid == human.principal.uid
      assert MembershipStore.member?(Ankole.Repo, company.uid, human.principal.uid)
    end

    test "same-pair add is idempotent" do
      owner = human_fixture()
      human = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, _created} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, human.principal.uid)
               end)

      assert {:ok, existing} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, human.principal.uid)
               end)

      assert existing.company_uid == company.uid
      assert existing.principal_uid == human.principal.uid
      assert MembershipStore.membership_count(Ankole.Repo, human.principal.uid) == 1
    end

    test "two different companies are representable for one human" do
      owner = human_fixture()
      human = human_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_a.uid, human.principal.uid)
               end)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_b.uid, human.principal.uid)
               end)

      assert Enum.sort(
               MembershipStore.company_uids_for_principal(Ankole.Repo, human.principal.uid)
             ) == Enum.sort([company_a.uid, company_b.uid])
    end

    test "removal succeeds" do
      owner = human_fixture()
      human = human_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, human.principal.uid)
               end)

      assert {:ok, :deleted} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company.uid, human.principal.uid)
               end)

      refute MembershipStore.member?(Ankole.Repo, company.uid, human.principal.uid)
    end
  end

  describe "system membership" do
    test "add is rejected fail closed and writes no row" do
      owner = human_fixture()
      system = system_principal_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:error, :system_principal_membership_denied} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, system.uid)
               end)

      assert MembershipStore.member?(Ankole.Repo, company.uid, system.uid) == false
    end

    test "an existing system membership row may be removed as cleanup" do
      system = system_principal_fixture()
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)

      {:ok, _} =
        Repo.insert(
          Membership.changeset(%Membership{}, %{
            company_uid: company.uid,
            principal_uid: system.uid
          })
        )

      assert {:ok, :deleted} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company.uid, system.uid)
               end)

      refute MembershipStore.member?(Ankole.Repo, company.uid, system.uid)
    end
  end

  describe "agent membership" do
    test "agent with no memberships can join a company" do
      owner = human_fixture()
      agent = agent_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, membership} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, agent.principal.uid)
               end)

      assert membership.principal_uid == agent.principal.uid
      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 1
    end

    test "same-company add is idempotent for an agent" do
      owner = human_fixture()
      agent = agent_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, agent.principal.uid)
               end)

      assert {:ok, existing} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, agent.principal.uid)
               end)

      assert existing.company_uid == company.uid
      assert existing.principal_uid == agent.principal.uid
      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 1
    end

    test "a second company is rejected for an agent" do
      owner = human_fixture()
      agent = agent_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_a.uid, agent.principal.uid)
               end)

      assert {:error, :agent_already_in_company} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_b.uid, agent.principal.uid)
               end)

      assert MembershipStore.company_uids_for_principal(Ankole.Repo, agent.principal.uid) == [
               company_a.uid
             ]
      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 1
    end

    test "corrupt multi-membership state rejects any add" do
      owner = human_fixture()
      agent = agent_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      for company <- [company_a, company_b] do
        {:ok, _} =
          Repo.insert(
            Membership.changeset(%Membership{}, %{
              company_uid: company.uid,
              principal_uid: agent.principal.uid
            })
          )
      end

      assert {:error, :agent_membership_invariant_violation} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_a.uid, agent.principal.uid)
               end)

      assert {:error, :agent_membership_invariant_violation} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_b.uid, agent.principal.uid)
               end)
    end

    test "removal of the sole agent membership is rejected and the row remains" do
      owner = human_fixture()
      agent = agent_fixture()
      company = company_fixture(owner.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, agent.principal.uid)
               end)

      assert {:error, :agent_requires_company} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company.uid, agent.principal.uid)
               end)

      assert MembershipStore.member?(Ankole.Repo, company.uid, agent.principal.uid)
      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 1
    end

    test "agent without a matching pair returns not_found on remove" do
      owner = human_fixture()
      agent = agent_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_a.uid, agent.principal.uid)
               end)

      assert {:error, :not_found} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company_b.uid, agent.principal.uid)
               end)

      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 1
    end

    test "corrupt multi-membership state rejects agent removal and leaves both rows" do
      owner = human_fixture()
      agent = agent_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      for company <- [company_a, company_b] do
        {:ok, _} =
          Repo.insert(
            Membership.changeset(%Membership{}, %{
              company_uid: company.uid,
              principal_uid: agent.principal.uid
            })
          )
      end

      assert {:error, :agent_membership_invariant_violation} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company_a.uid, agent.principal.uid)
               end)

      assert {:error, :agent_membership_invariant_violation} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company_b.uid, agent.principal.uid)
               end)

      assert MembershipStore.member?(Ankole.Repo, company_a.uid, agent.principal.uid)
      assert MembershipStore.member?(Ankole.Repo, company_b.uid, agent.principal.uid)
      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 2
    end
  end

  describe "concurrency" do
    test "concurrent agent adds to two companies leave exactly one membership" do
      owner = human_fixture()
      agent = agent_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)

      owner_pid = self()

      task_a =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Ankole.Repo, owner_pid, self())

          Repo.transact(fn repo ->
            MembershipStore.add_member(repo, company_a.uid, agent.principal.uid)
          end)
        end)

      task_b =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Ankole.Repo, owner_pid, self())

          Repo.transact(fn repo ->
            MembershipStore.add_member(repo, company_b.uid, agent.principal.uid)
          end)
        end)

      results = [Task.await(task_a), Task.await(task_b)]

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, _}, &1)) == 1
      assert MembershipStore.membership_count(Ankole.Repo, agent.principal.uid) == 1
    end
  end

  describe "queries" do
    test "member? reports absence and presence" do
      owner = human_fixture()
      human = human_fixture()
      company = company_fixture(owner.principal.uid)

      refute MembershipStore.member?(Ankole.Repo, company.uid, human.principal.uid)

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, human.principal.uid)
               end)

      assert MembershipStore.member?(Ankole.Repo, company.uid, human.principal.uid)
    end

    test "member_uids lists the members of one company" do
      owner = human_fixture()
      company = company_fixture(owner.principal.uid)
      member_a = human_fixture()
      member_b = human_fixture()

      for member <- [member_a, member_b] do
        assert {:ok, _} =
                 transact(fn repo ->
                   MembershipStore.add_member(repo, company.uid, member.principal.uid)
                 end)
      end

      assert Enum.sort(MembershipStore.member_uids(Ankole.Repo, company.uid)) ==
               Enum.sort([member_a.principal.uid, member_b.principal.uid])
    end

    test "company_uids_for_principal returns zero, one, and multiple values" do
      owner = human_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)
      human = human_fixture()

      assert MembershipStore.company_uids_for_principal(
               Ankole.Repo,
               human.principal.uid
             ) == []

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_a.uid, human.principal.uid)
               end)

      assert MembershipStore.company_uids_for_principal(Ankole.Repo, human.principal.uid) == [
               company_a.uid
             ]

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_b.uid, human.principal.uid)
               end)

      assert Enum.sort(MembershipStore.company_uids_for_principal(Ankole.Repo, human.principal.uid)) ==
               Enum.sort([company_a.uid, company_b.uid])
    end

    test "membership_count reports zero, one, and two" do
      owner = human_fixture()
      company_a = company_fixture(owner.principal.uid)
      company_b = company_fixture(owner.principal.uid)
      human = human_fixture()

      assert MembershipStore.membership_count(Ankole.Repo, human.principal.uid) == 0

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_a.uid, human.principal.uid)
               end)

      assert MembershipStore.membership_count(Ankole.Repo, human.principal.uid) == 1

      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company_b.uid, human.principal.uid)
               end)

      assert MembershipStore.membership_count(Ankole.Repo, human.principal.uid) == 2
    end
  end

  describe "layer boundary" do
    test "the store performs no company lifecycle authorization" do
      owner = human_fixture()
      human = human_fixture()
      company = company_fixture(owner.principal.uid, %{status: :suspended})

      # Absence-of-gating proof only: the layer is status-blind. Public
      # lifecycle policy is deferred to COMPANY-005 and future evidence.
      assert {:ok, _} =
               transact(fn repo ->
                 MembershipStore.add_member(repo, company.uid, human.principal.uid)
               end)

      assert {:ok, :deleted} =
               transact(fn repo ->
                 MembershipStore.remove_member(repo, company.uid, human.principal.uid)
               end)
    end

    test "the store source has no dependency on Ankole.AuthZ" do
      source =
        File.read!(
          Path.expand("../../../lib/ankole/company/membership_store.ex", __DIR__)
        )

      refute String.contains?(source, "Ankole.AuthZ")
    end
  end

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Enum.into(attrs, %{
          uid: "test-company-#{suffix}",
          name: "test-company-#{suffix}",
          display_name: "Test Company",
          status: :created,
          metadata: %{},
          owner_principal_uid: owner_uid
        })
      )
      |> Repo.insert()

    company
  end

  defp system_principal_fixture do
    uid = "system-service-#{System.unique_integer([:positive])}"

    {:ok, principal} =
      Principal.changeset(%Principal{}, %{
        uid: uid,
        type: :system,
        status: :active,
        display_name: "Service"
      })
      |> Repo.insert()

    principal
  end

  defp transact(fun) do
    Repo.transact(fn repo -> fun.(repo) end)
  end
end
