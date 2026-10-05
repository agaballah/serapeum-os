defmodule Ankole.W3.ApprovalLockTest do
  @moduledoc """
  Focused tests for the P8 Approval lock-then-validate primitives.

  `ApprovalStore.fetch_approval_for_update/3` takes the row lock and
  `ApprovalStore.validate_prefetched_approval/2` judges the row it is handed.
  Together they let one caller decide, inside one transaction, whether an
  Approval still carries authority. The caller reads the row once instead of
  reading it, then locking it, then reading it again.

  This module stays inside the SQL sandbox. The two-connection proof lives in
  `Ankole.W3.ApprovalLockConcurrencyTest`, because the sandbox gives one
  process one connection and therefore cannot show a second transaction
  waiting on a `SELECT ... FOR UPDATE` lock.
  """

  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.Approval
  alias Ankole.W3.ApprovalStore

  import Ankole.PrincipalsFixtures

  @action "cancel_task"
  @resource "workspace:default"
  @risk_class "HIGH-IMPACT"

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(%{
        uid: "w3-p8-lock-company-#{suffix}",
        name: "w3-p8-lock-company-#{suffix}",
        display_name: "W3 P8 Lock Company",
        status: :active,
        metadata: %{},
        owner_principal_uid: owner_uid
      })
      |> Repo.insert()

    company
  end

  defp request_fixture do
    %{principal: owner} = human_fixture()
    company = company_fixture(owner.uid)
    %{principal: requester} = human_fixture()
    %{principal: approver} = human_fixture()
    %{principal: revoker} = human_fixture()

    for uid <- [requester.uid, approver.uid, revoker.uid] do
      {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
    end

    %{company: company, requester: requester, approver: approver, revoker: revoker}
  end

  defp approval_fixture(context, attrs \\ %{}) do
    {:ok, approval} =
      ApprovalStore.create_approval(
        Repo,
        Map.merge(
          %{
            uid: "w3-p8-lock-approval-#{System.unique_integer([:positive])}",
            company_uid: context.company.uid,
            requester_uid: context.requester.uid,
            action: @action,
            resource: @resource,
            risk_class: @risk_class
          },
          attrs
        )
      )

    approval
  end

  defp approved_fixture(context, attrs \\ %{}) do
    approval = approval_fixture(context, attrs)

    {:ok, approved} =
      ApprovalStore.approve_approval(
        Repo,
        context.company.uid,
        approval.uid,
        context.approver.uid
      )

    approved
  end

  # The assurance expectation `validate_prefetched_approval/2` is given.
  defp expectation(context, approval, overrides \\ %{}) do
    Map.merge(
      %{
        company_uid: context.company.uid,
        requester_uid: approval.requester_uid,
        action: @action,
        resource: @resource,
        risk_class: @risk_class
      },
      overrides
    )
  end

  # ─── fetch_approval_for_update/3 ──────────────────────────────────────────

  describe "fetch_approval_for_update/3" do
    test "locks the approval that belongs to the company" do
      context = request_fixture()
      approval = approved_fixture(context)

      assert {:ok, locked} =
               Repo.transact(fn tx ->
                 ApprovalStore.fetch_approval_for_update(tx, context.company.uid, approval.uid)
               end)

      assert locked.uid == approval.uid
      assert locked.status == "approved"
      assert locked.approver_uid == context.approver.uid
    end

    test "fails closed for the approval of another company" do
      context = request_fixture()
      approval = approved_fixture(context)
      %{principal: other_owner} = human_fixture()
      other_company = company_fixture(other_owner.uid)

      # The row exists and is readable in its own company, so a miss here is
      # the company scope refusing it, not a missing Approval.
      assert {:error, :not_found} =
               ApprovalStore.fetch_approval_for_update(Repo, other_company.uid, approval.uid)

      # A company that does not exist keeps its own established error.
      assert {:error, :company_not_found} =
               ApprovalStore.fetch_approval_for_update(Repo, "w3-p8-absent-company", approval.uid)
    end

    test "fails closed for an approval that does not exist" do
      context = request_fixture()

      assert {:error, :not_found} =
               ApprovalStore.fetch_approval_for_update(
                 Repo,
                 context.company.uid,
                 "w3-p8-absent-approval-#{System.unique_integer([:positive])}"
               )
    end

    test "normalizes the approval UID as the unlocked fetch does" do
      context = request_fixture()
      approval = approved_fixture(context)

      assert {:ok, %Approval{uid: uid}} =
               ApprovalStore.fetch_approval_for_update(
                 Repo,
                 context.company.uid,
                 "  #{String.upcase(approval.uid)}  "
               )

      assert uid == approval.uid
    end

    test "leaves the transaction to its caller" do
      context = request_fixture()
      approval = approved_fixture(context)

      # The caller still owns the transaction and still holds the decision to
      # commit or roll back, so this function opened no transaction of its own.
      assert {:error, :caller_aborted} =
               Repo.transact(fn tx ->
                 {:ok, _locked} =
                   ApprovalStore.fetch_approval_for_update(tx, context.company.uid, approval.uid)

                 Repo.rollback(:caller_aborted)
               end)
    end
  end

  # ─── validate_prefetched_approval/2 ───────────────────────────────────────

  describe "validate_prefetched_approval/2" do
    test "accepts an approved approval that binds to the assurance context" do
      context = request_fixture()
      approval = approved_fixture(context)

      assert :ok ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval)
               )
    end

    test "refuses an approval that is still requested" do
      context = request_fixture()
      approval = approval_fixture(context)

      assert {:error, :approval_not_approved} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval)
               )
    end

    test "refuses a rejected approval" do
      context = request_fixture()
      approval = approval_fixture(context)

      {:ok, rejected} =
        ApprovalStore.reject_approval(
          Repo,
          context.company.uid,
          approval.uid,
          context.approver.uid
        )

      assert {:error, :approval_not_approved} ==
               ApprovalStore.validate_prefetched_approval(
                 rejected,
                 expectation(context, rejected)
               )
    end

    test "refuses a revoked approval" do
      context = request_fixture()
      approval = approved_fixture(context)

      {:ok, revoked} =
        ApprovalStore.revoke_approval(
          Repo,
          context.company.uid,
          approval.uid,
          context.revoker.uid
        )

      assert {:error, :approval_revoked} ==
               ApprovalStore.validate_prefetched_approval(
                 revoked,
                 expectation(context, revoked)
               )
    end

    test "refuses an approval whose expiry has passed" do
      context = request_fixture()

      approval =
        approved_fixture(context, %{
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })

      assert {:error, :approval_expired} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval)
               )
    end

    test "refuses an approval presented for another requester" do
      context = request_fixture()
      approval = approved_fixture(context)
      %{principal: imposter} = human_fixture()

      assert {:error, :approval_requester_mismatch} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval, %{requester_uid: imposter.uid})
               )
    end

    test "refuses an approval bound to another action" do
      context = request_fixture()
      approval = approved_fixture(context)

      assert {:error, :approval_action_mismatch} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval, %{action: "delete_task"})
               )
    end

    test "refuses an approval bound to another resource" do
      context = request_fixture()
      approval = approved_fixture(context)

      assert {:error, :approval_resource_mismatch} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval, %{resource: "workspace:other"})
               )
    end

    test "refuses an approval whose risk class is not the recomputed one" do
      context = request_fixture()
      approval = approved_fixture(context)

      assert {:error, :approval_risk_class_mismatch} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval, %{risk_class: "ROUTINE"})
               )
    end

    test "refuses an approval presented for another company" do
      context = request_fixture()
      approval = approved_fixture(context)
      %{principal: other_owner} = human_fixture()
      other_company = company_fixture(other_owner.uid)

      assert {:error, :approval_company_mismatch} ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval, %{company_uid: other_company.uid})
               )
    end

    test "refuses an approval that its own requester approved" do
      context = request_fixture()

      # `approve_approval/4` refuses this transition, so the row is written
      # directly. A prefetched row must still not count as independent
      # authority.
      {:ok, self_approved} =
        %Approval{}
        |> Approval.changeset(%{
          uid: "w3-p8-lock-self-approved-#{System.unique_integer([:positive])}",
          company_uid: context.company.uid,
          requester_uid: context.requester.uid,
          approver_uid: context.requester.uid,
          action: @action,
          resource: @resource,
          risk_class: @risk_class,
          status: "approved",
          approved_at: DateTime.utc_now()
        })
        |> Repo.insert()

      assert {:error, :approval_self_approval} ==
               ApprovalStore.validate_prefetched_approval(
                 self_approved,
                 expectation(context, self_approved)
               )
    end
  end

  # ─── no second read ───────────────────────────────────────────────────────

  describe "no second read" do
    test "issues no query of its own" do
      context = request_fixture()
      approval = approved_fixture(context)
      expected = expectation(context, approval)

      # This task owns no sandbox connection. A process without one raises
      # `DBConnection.OwnershipError` on its first query, so a clean result is
      # proof that validation read nothing.
      task = Task.async(fn -> ApprovalStore.validate_prefetched_approval(approval, expected) end)

      assert :ok == Task.await(task, 5_000)
    end

    test "judges the row it is handed, not the stored row" do
      context = request_fixture()
      approval = approved_fixture(context)

      {:ok, _revoked} =
        ApprovalStore.revoke_approval(
          Repo,
          context.company.uid,
          approval.uid,
          context.revoker.uid
        )

      # The stored row is revoked now, so a second read would refuse it. The
      # lock is what makes the handed row safe to judge.
      assert {:ok, %Approval{status: "revoked"}} =
               ApprovalStore.fetch_approval(Repo, context.company.uid, approval.uid)

      assert :ok ==
               ApprovalStore.validate_prefetched_approval(
                 approval,
                 expectation(context, approval)
               )
    end
  end
end

defmodule Ankole.W3.ApprovalLockConcurrencyTest do
  @moduledoc """
  Two-connection proof for the P8 Approval lock.

  The SQL sandbox gives one process one connection, so it cannot show that a
  second transaction waits for a `SELECT ... FOR UPDATE` lock. This module
  therefore leaves the sandbox with `unboxed_run/2` and drives two independent
  connections against one committed Approval row. Those rows are committed for
  real, so every row the module creates is deleted again.
  """

  use Ankole.DataCase, async: false

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.Approval
  alias Ankole.W3.ApprovalStore

  alias Ecto.Adapters.SQL.Sandbox

  import Ankole.PrincipalsFixtures

  @action "cancel_task"
  @resource "workspace:default"
  @risk_class "HIGH-IMPACT"

  # Serial: this module commits rows outside the sandbox and coordinates two
  # blocking connections, so it cannot run concurrently with other tests.
  @tag ownership_timeout: 30_000

  test "case A a validator that holds the lock makes the revoke wait, and the row ends revoked" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)

    parent = self()

    validator =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(fn tx ->
            with {:ok, locked} <-
                   ApprovalStore.fetch_approval_for_update(
                     tx,
                     fixture.company_uid,
                     fixture.approval_uid
                   ),
                 :ok <- ApprovalStore.validate_prefetched_approval(locked, fixture.expected) do
              send(parent, {:validator_locked, self()})

              receive do
                :commit -> :ok
              after
                15_000 -> :ok
              end

              {:ok, :validator_committed}
            end
          end)
        end)
      end)

    assert_receive {:validator_locked, validator_pid}, 10_000

    revoker =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          started = System.monotonic_time(:millisecond)
          send(parent, {:revoker_attempting, started})

          result =
            ApprovalStore.revoke_approval(
              Repo,
              fixture.company_uid,
              fixture.approval_uid,
              fixture.revoker_uid
            )

          send(parent, {:revoker_done, result, System.monotonic_time(:millisecond) - started})

          result
        end)
      end)

    assert_receive {:revoker_attempting, attempted_at}, 10_000

    # The revoke has reached its lock query while the validator still owns the
    # row, so anything the revoke reports was read after the validator
    # released the lock.
    Process.sleep(300)
    refute_received {:revoker_done, _result, _waited}
    assert Process.alive?(revoker.pid)

    send(validator_pid, :commit)
    assert {:ok, :validator_committed} = Task.await(validator, 15_000)

    assert_receive {:revoker_done, {:ok, %Approval{status: "revoked"}}, waited}, 15_000
    assert waited >= 250, "the revoke must have blocked on the validator lock, waited #{waited}ms"
    assert System.monotonic_time(:millisecond) - attempted_at >= 250

    assert {:ok, %Approval{status: "revoked"}} = Task.await(revoker, 15_000)

    Sandbox.unboxed_run(Repo, fn ->
      assert %Approval{status: "revoked"} = Repo.get_by(Approval, uid: fixture.approval_uid)
    end)
  end

  @tag ownership_timeout: 30_000

  test "case B an approval revoked before the validator locked it fails closed" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)

    assert {:ok, %Approval{status: "revoked"}} =
             Sandbox.unboxed_run(Repo, fn ->
               ApprovalStore.revoke_approval(
                 Repo,
                 fixture.company_uid,
                 fixture.approval_uid,
                 fixture.revoker_uid
               )
             end)

    assert {:ok, {:error, :approval_revoked}} =
             Sandbox.unboxed_run(Repo, fn ->
               Repo.transact(fn tx ->
                 with {:ok, locked} <-
                        ApprovalStore.fetch_approval_for_update(
                          tx,
                          fixture.company_uid,
                          fixture.approval_uid
                        ) do
                   assert locked.status == "revoked"

                   {:ok, ApprovalStore.validate_prefetched_approval(locked, fixture.expected)}
                 end
               end)
             end)
  end

  # ─── committed fixtures and cleanup ───────────────────────────────────────

  defp committed_fixture do
    Sandbox.unboxed_run(Repo, fn ->
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture()
      %{principal: requester} = human_fixture()
      %{principal: approver} = human_fixture()
      %{principal: revoker} = human_fixture()

      {:ok, company} =
        %Company{}
        |> Company.changeset(%{
          uid: "w3-p8-lock-conc-company-#{suffix}",
          name: "w3-p8-lock-conc-company-#{suffix}",
          display_name: "W3 P8 Lock Concurrency Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner.uid
        })
        |> Repo.insert()

      for uid <- [requester.uid, approver.uid, revoker.uid] do
        {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
      end

      {:ok, approval} =
        ApprovalStore.create_approval(Repo, %{
          uid: "w3-p8-lock-conc-approval-#{suffix}",
          company_uid: company.uid,
          requester_uid: requester.uid,
          action: @action,
          resource: @resource,
          risk_class: @risk_class
        })

      {:ok, approval} =
        ApprovalStore.approve_approval(Repo, company.uid, approval.uid, approver.uid)

      %{
        company_uid: company.uid,
        approval_uid: approval.uid,
        revoker_uid: revoker.uid,
        principal_uids: [owner.uid, requester.uid, approver.uid, revoker.uid],
        expected: %{
          company_uid: company.uid,
          requester_uid: approval.requester_uid,
          action: @action,
          resource: @resource,
          risk_class: @risk_class
        }
      }
    end)
  end

  defp cleanup(fixture) do
    Sandbox.unboxed_run(Repo, fn ->
      Approval
      |> where([approval], approval.company_uid == ^fixture.company_uid)
      |> Repo.delete_all()

      Ankole.Company.Membership
      |> where([membership], membership.company_uid == ^fixture.company_uid)
      |> Repo.delete_all()

      Company
      |> where([company], company.uid == ^fixture.company_uid)
      |> Repo.delete_all()

      slugs = Enum.map(fixture.principal_uids, &"people/#{&1}")

      Ankole.Brain.Schemas.Object
      |> where([object], object.slug in ^slugs)
      |> Repo.delete_all()

      Ankole.Principals.HumanUser
      |> where([human], human.principal_uid in ^fixture.principal_uids)
      |> Repo.delete_all()

      Principal
      |> where([principal], principal.uid in ^fixture.principal_uids)
      |> Repo.delete_all()
    end)
  end
end
