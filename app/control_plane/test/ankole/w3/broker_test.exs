defmodule Ankole.W3.BrokerTest do
  use Ankole.DataCase, async: false

  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.ActionAssurance
  alias Ankole.W3.ApprovalStore
  alias Ankole.W3.Broker.Mock
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityStore

  import Ankole.PrincipalsFixtures

  # ─── module-level setup ────────────────────────────────────────────────

  setup_all do
    Mock.start_link()
    on_exit(fn -> Mock.stop() end)
  end

  setup do
    Mock.reset()
    :ok
  end

  # ─── fixtures ────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(
        Map.merge(%{
          uid: "w3-p7-company-#{suffix}",
          name: "w3-p7-company-#{suffix}",
          display_name: "W3 P7 Test Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner_uid
        }, attrs)
      )
      |> Repo.insert()

    company
  end

  defp grant_fixture(principal_uid, company_uid, resource_pattern, action) do
    {:ok, _grant} =
      AuthZ.upsert_permission_grant(%{
        principal_uid: principal_uid,
        company_uid: company_uid,
        resource_pattern: resource_pattern,
        action: action,
        condition: "true"
      })
  end

  defp capability_fixture(company_uid, principal_uid, issuer_uid, attrs) do
    suffix = System.unique_integer([:positive])

    {:ok, cap} =
      %Capability{}
      |> Capability.changeset(
        Map.merge(%{
          uid: "w3-p7-cap-#{suffix}",
          company_uid: company_uid,
          principal_uid: principal_uid,
          action: "list_company_tasks",
          resource: "workspace:default",
          status: :active,
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-27T10:00:00Z],
          issued_by_principal_uid: issuer_uid,
          scope: %{},
          constraints: %{},
          metadata: %{}
        }, attrs)
      )
      |> Repo.insert()

    cap
  end

  defp approval_fixture(company_uid, requester_uid, action, resource, risk_class) do
    suffix = System.unique_integer([:positive])

    {:ok, approval} =
      ApprovalStore.create_approval(Repo, %{
        uid: "w3-p7-apr-#{suffix}",
        company_uid: company_uid,
        requester_uid: requester_uid,
        action: action,
        resource: resource,
        risk_class: risk_class
      })

    approval
  end

  # ─── T.1: successful execution ───────────────────────────────────────────

  describe "successful execution" do
    test "T.1 executes with valid authority and returns deterministic result" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t1-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t1-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t1-cap"})

      assert {:ok, result} =
               Mock.execute(
                 Repo,
                 company.uid,
                 holder.uid,
                 "list_company_tasks",
                 "workspace:default",
                 "w3-p7-t1-cap",
                 nil,
                 %{},
                 nil
               )

      assert result.success == true
      assert is_binary(result.execution_uid)
      assert result.side_effects == []
    end
  end

  # ─── T.2–T.4: missing / invalid authority ─────────────────────────────

  describe "missing or invalid authority" do
    test "T.2 returns authority_missing when capability_uid is nil" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t2-h")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)

      assert {:error, :authority_missing} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", nil, nil, %{}, nil)
    end

    test "T.3 returns authority_missing when capability_uid is empty string" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t3-h")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)

      assert {:error, :authority_missing} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "", nil, %{}, nil)
    end

    test "T.4 returns authority_invalid for nonexistent capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t4-h")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)

      assert {:error, :authority_invalid} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "nonexistent-capability", nil, %{}, nil)
    end
  end

  # ─── T.5: expired ───────────────────────────────────────────────────────

  describe "expired authority" do
    test "T.5 returns authority_expired for expired capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t5-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t5-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      past = DateTime.add(DateTime.utc_now(), -86400, :second)
      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t5-cap", expires_at: past})
      CapabilityStore.expire_capability(Repo, company.uid, cap.uid)

      assert {:error, :authority_expired} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", cap.uid, nil, %{}, nil)
    end
  end

  # ─── T.6: revoked ───────────────────────────────────────────────────────

  describe "revoked authority" do
    test "T.6 returns authority_revoked for revoked capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t6-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t6-i")

      assert       {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t6-cap"})
      CapabilityStore.revoke_capability(Repo, company.uid, cap.uid, holder.uid)

      assert {:error, :authority_revoked} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", cap.uid, nil, %{}, nil)
    end
  end

  # ─── T.8: wrong action ──────────────────────────────────────────────────

  describe "action mismatch" do
    test "T.8 returns authority_action_mismatch when action differs from capability" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t8-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t8-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t8-cap", action: "list_company_tasks"})

      assert {:error, :authority_action_mismatch} =
               Mock.execute(Repo, company.uid, holder.uid, "cancel_task", "workspace:default", "w3-p7-t8-cap", nil, %{}, nil)
    end
  end

  # ─── T.9: wrong resource ────────────────────────────────────────────────

  describe "resource mismatch" do
    test "T.9 returns authority_resource_mismatch when resource differs" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t9-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t9-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t9-cap", resource: "workspace:specific"})

      assert {:error, :authority_resource_mismatch} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-t9-cap", nil, %{}, nil)
    end
  end

  # ─── T.10: scope exceeded ───────────────────────────────────────────────

  describe "scope constraints" do
    test "T.10 returns scope_exceeded when params lack required constraint key" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t10-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t10-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t10-cap", constraints: %{target_id: "x"}})

      assert {:error, :scope_exceeded} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-t10-cap", nil, %{other_key: "value"}, nil)
    end
  end

  # ─── T.11: TOCTOU ───────────────────────────────────────────────────────

  describe "TOCTOU protection" do
    test "T.11a rejects when target state has changed" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t11a-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t11a-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t11a-cap"})
      Mock.set_target_state(company.uid, "workspace:default", %{version: 1})

      assert {:error, :target_state_changed} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-t11a-cap", nil, %{}, %{version: 2})
    end

    test "T.11b allows when target state matches" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t11b-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t11b-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t11b-cap"})
      Mock.set_target_state(company.uid, "workspace:default", %{version: 1})

      assert {:ok, result} =
               Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-t11b-cap", nil, %{}, %{version: 1})

      assert result.success == true
    end
  end

  # ─── T.12: cross-company ────────────────────────────────────────────────

  describe "cross-company isolation" do
    test "T.12a rejects principal not in target company" do
      %{principal: owner_b} = human_fixture()
      company_b = company_fixture(owner_b.uid)
      %{principal: outsider} = human_fixture(uid: "w3-p7-t12-out")

      assert {:error, :principal_not_in_company} =
               Mock.execute(Repo, company_b.uid, outsider.uid, "list_company_tasks", "workspace:default", nil, nil, %{}, nil)
    end

    test "T.12b rejects nil company_uid" do
      %{principal: holder} = human_fixture(uid: "w3-p7-t12b-h")

      assert {:error, :company_scope_mismatch} =
               Mock.execute(Repo, nil, holder.uid, "list_company_tasks", "workspace:default", nil, nil, %{}, nil)
    end
  end

  # ─── T.14: HIGH-IMPACT approval ────────────────────────────────────────

  describe "HIGH-IMPACT approval binding" do
    test "T.14 rejects when no approval provided for high-impact action" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t14-h")
      %{principal: approver} = human_fixture(uid: "w3-p7-t14-a")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, approver.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      approval = approval_fixture(company.uid, holder.uid, "cancel_task", "workspace:default", "HIGH-IMPACT")
      ApprovalStore.approve_approval(Repo, company.uid, approval.uid, approver.uid)

      _cap = capability_fixture(company.uid, holder.uid, approver.uid, %{uid: "w3-p7-t14-cap", action: "cancel_task", risk_class: "HIGH-IMPACT"})

      # No approval param passed → approval_required for HIGH-IMPACT capability
      assert {:error, :approval_required} =
               Mock.execute(Repo, company.uid, holder.uid, "cancel_task", "workspace:default", "w3-p7-t14-cap", nil, %{}, nil)
    end

    test "T.14b accepts with valid independent approval" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t14b-h")
      %{principal: approver} = human_fixture(uid: "w3-p7-t14b-a")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, approver.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "cancel_task")

      approval = approval_fixture(company.uid, holder.uid, "cancel_task", "workspace:default", "HIGH-IMPACT")
      ApprovalStore.approve_approval(Repo, company.uid, approval.uid, approver.uid)

      _cap = capability_fixture(company.uid, holder.uid, approver.uid, %{uid: "w3-p7-t14b-cap", action: "cancel_task", risk_class: "HIGH-IMPACT", approval_uid: approval.uid})

      assert {:ok, result} =
               Mock.execute(Repo, company.uid, holder.uid, "cancel_task", "workspace:default", "w3-p7-t14b-cap", approval.uid, %{}, nil)

      assert result.success == true
    end
  end

  # ─── T.15: replay ───────────────────────────────────────────────────────

  describe "replay detection" do
    test "T.15 resolves cached execution by execution_uid" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-t15-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-t15-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-t15-cap"})

      {:ok, result} =
        Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-t15-cap", nil, %{}, nil)

      assert {:ok, cached} = Mock.resolve(result.execution_uid)
      assert cached.execution_uid == result.execution_uid
      assert cached.success == true
    end
  end

  # ─── R.1: receipt handoff integration ──────────────────────────────────

  describe "receipt handoff" do
    test "R.1 full flow assure → broker → finalize persists receipt with broker_name" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      %{principal: holder} = human_fixture(uid: "w3-p7-r1-h")
      %{principal: issuer} = human_fixture(uid: "w3-p7-r1-i")

      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, holder.uid)
      assert {:ok, _} = MembershipStore.add_member(Repo, company.uid, issuer.uid)
      grant_fixture(holder.uid, company.uid, "workspace:**", "list_company_tasks")

      _cap = capability_fixture(company.uid, holder.uid, issuer.uid, %{uid: "w3-p7-r1-cap"})

      {:ok, context} =
        ActionAssurance.assure(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-r1-cap")

      {:ok, result} =
        Mock.execute(Repo, company.uid, holder.uid, "list_company_tasks", "workspace:default", "w3-p7-r1-cap", nil, %{}, nil)

      context_with_broker = Map.put(context, :broker_name, "mock")

      assert {:ok, receipt} =
               ActionAssurance.finalize_assurance(Repo, context_with_broker, result.success, result.output)

      assert receipt.broker_name == "mock"
      assert receipt.capability_uid == "w3-p7-r1-cap"
      assert receipt.intent_action == "list_company_tasks"
      # Broker success is execution evidence, not proof of a postcondition.
      # No postcondition was declared, so none was verified.
      assert is_nil(receipt.postcondition_verified)
      assert receipt.result_output == result.output
      # No execution failure was established, so neither success nor failure
      # is claimed.
      assert is_nil(receipt.execution_failed)
      assert is_nil(receipt.verified_at)
    end
  end

  # ─── B.1–B.4: boundary audit ────────────────────────────────────────────

  describe "boundary audit" do
    test "B.1 broker source has no W2 store references" do
      source = File.read!("lib/ankole/w3/broker/mock.ex")
      refute String.contains?(source, "TaskStore")
      refute String.contains?(source, "MissionStore")
      refute String.contains?(source, "GoalStore")
      refute String.contains?(source, "WorkHierarchy")
    end

    test "B.2 broker source has no scheduler references" do
      source = File.read!("lib/ankole/w3/broker/mock.ex")
      refute String.contains?(source, "Oban")
      refute String.contains?(source, "Scheduler")
      refute String.contains?(source, "Worker.Recovery")
    end

    test "B.3 broker source has no MA-12 fencing references" do
      source = File.read!("lib/ankole/w3/broker/mock.ex")
      refute String.downcase(source) |> String.contains?("fencing")
      refute String.downcase(source) |> String.contains?("checkpoint")
    end

    test "B.4 broker source has no host isolation references" do
      source = File.read!("lib/ankole/w3/broker/mock.ex")
      refute String.contains?(source, "host_admin")
      refute String.contains?(source, "sandbox")
      refute String.contains?(source, "system_shell")
    end
  end
end
