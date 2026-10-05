defmodule Ankole.W3.CapabilityLifecycleLockTest do
  @moduledoc """
  Two-connection proof for the Capability lifecycle transitions.

  Every lifecycle transition runs under the Capability row lock, so the first
  transaction to take the lock decides the legal next state and every later
  transaction reads the committed result and fails closed. The SQL sandbox
  gives one process one connection, so it cannot show that a second transaction
  blocks on the first transaction's lock. This module therefore leaves the
  sandbox with `unboxed_run` and drives two independent connections against one
  committed Capability row. Because those rows are committed for real, the
  module deletes every row it creates.

  Each case names the lock holder, the blocked operation, what the blocked
  operation observed after the commit, and the state that stayed in the
  database.
  """

  # Serial: this module commits rows outside the sandbox and coordinates two
  # blocking connections, so it cannot run concurrently with other tests.
  use Ankole.DataCase, async: false

  import Ankole.PrincipalsFixtures

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.CapabilityStore

  alias Ecto.Adapters.SQL.Sandbox

  @action "workspace:read"
  @resource "workspace:default"
  @risk_class "CONTROLLED"

  # ─── A: consume holds the lock, revoke waits ──────────────────────────────

  @tag ownership_timeout: 30_000

  test "A a consumer holding the lock makes the revoke wait, and the revoke loses" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    capability_uid = active_capability(fixture)

    consumer =
      lock_holder(fixture, capability_uid, fn tx, capability ->
        CapabilityService.consume_locked(tx, capability)
      end)

    assert_receive {:locked, consumer_pid}, 10_000

    revoker =
      competitor(:revoke, fn ->
        CapabilityService.revoke_capability(
          Repo,
          fixture.company_uid,
          capability_uid,
          fixture.revoker_uid
        )
      end)

    assert_receive {:attempting, :revoke, attempted_at}, 10_000

    # The revoke reached its lock query while the consumer still held the row,
    # so anything the revoke reports was read after the consumer released it.
    Process.sleep(300)
    refute_received {:completed, :revoke, _result, _waited}
    assert Process.alive?(revoker.pid)

    send(consumer_pid, :release)
    assert {:ok, {:ok, %Capability{status: :consumed}}} = Task.await(consumer, 15_000)

    assert_receive {:completed, :revoke, {:error, :already_consumed}, waited}, 15_000

    assert waited >= 250,
           "the revoke must have blocked on the consumer's row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:error, :already_consumed} = Task.await(revoker, 15_000)
    assert :consumed == persisted_status(fixture, capability_uid)
  end

  # ─── B: revoke holds the lock, consume waits ──────────────────────────────

  @tag ownership_timeout: 30_000

  test "B a revoke holding the lock makes the consumer wait, and the consumer sees revoked" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    capability_uid = active_capability(fixture)

    revoker =
      lock_holder(fixture, capability_uid, fn tx, capability ->
        CapabilityStore.revoke_locked(tx, capability)
      end)

    assert_receive {:locked, revoker_pid}, 10_000

    consumer =
      competitor(:consume, fn ->
        Repo.transact(fn tx ->
          with {:ok, locked} <-
                 CapabilityStore.fetch_capability_for_update(
                   tx,
                   fixture.company_uid,
                   capability_uid
                 ) do
            {:ok, CapabilityService.validate_prefetched_capability(tx, locked)}
          end
        end)
      end)

    assert_receive {:attempting, :consume, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :consume, _result, _waited}
    assert Process.alive?(consumer.pid)

    send(revoker_pid, :release)
    assert {:ok, {:ok, %Capability{status: :revoked}}} = Task.await(revoker, 15_000)

    assert_receive {:completed, :consume, {:ok, {:error, :revoked}}, waited}, 15_000

    assert waited >= 250,
           "the consumer must have blocked on the revoke's row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:ok, {:error, :revoked}} = Task.await(consumer, 15_000)
    assert :revoked == persisted_status(fixture, capability_uid)
  end

  # ─── C: consume holds the lock, expiry waits ──────────────────────────────

  @tag ownership_timeout: 30_000

  test "C a consumer holding the lock makes the expiry wait, and the expiry loses" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    capability_uid = active_capability(fixture)

    consumer =
      lock_holder(fixture, capability_uid, fn tx, capability ->
        CapabilityService.consume_locked(tx, capability)
      end)

    assert_receive {:locked, consumer_pid}, 10_000

    expiry =
      competitor(:expire, fn ->
        CapabilityService.expire_capability(Repo, fixture.company_uid, capability_uid)
      end)

    assert_receive {:attempting, :expire, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :expire, _result, _waited}
    assert Process.alive?(expiry.pid)

    send(consumer_pid, :release)
    assert {:ok, {:ok, %Capability{status: :consumed}}} = Task.await(consumer, 15_000)

    assert_receive {:completed, :expire, {:error, :already_consumed}, waited}, 15_000

    assert waited >= 250,
           "the expiry must have blocked on the consumer's row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:error, :already_consumed} = Task.await(expiry, 15_000)
    assert :consumed == persisted_status(fixture, capability_uid)
  end

  # ─── D: expiry holds the lock, consume waits ──────────────────────────────

  @tag ownership_timeout: 30_000

  test "D an expiry holding the lock makes the consumer wait, and the consumer sees expired" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    capability_uid = active_capability(fixture)

    expiry =
      lock_holder(fixture, capability_uid, fn tx, capability ->
        CapabilityStore.expire_locked(tx, capability)
      end)

    assert_receive {:locked, expiry_pid}, 10_000

    consumer =
      competitor(:consume, fn ->
        Repo.transact(fn tx ->
          with {:ok, locked} <-
                 CapabilityStore.fetch_capability_for_update(
                   tx,
                   fixture.company_uid,
                   capability_uid
                 ) do
            {:ok, CapabilityService.validate_prefetched_capability(tx, locked)}
          end
        end)
      end)

    assert_receive {:attempting, :consume, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :consume, _result, _waited}
    assert Process.alive?(consumer.pid)

    send(expiry_pid, :release)
    assert {:ok, {:ok, %Capability{status: :expired}}} = Task.await(expiry, 15_000)

    assert_receive {:completed, :consume, {:ok, {:error, :expired}}, waited}, 15_000

    assert waited >= 250,
           "the consumer must have blocked on the expiry's row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:ok, {:error, :expired}} = Task.await(consumer, 15_000)
    assert :expired == persisted_status(fixture, capability_uid)
  end

  # ─── E: child issuance holds the parent lock, revoke waits ────────────────

  @tag ownership_timeout: 30_000

  test "E child issuance holding the parent lock makes the revoke wait until the child commits" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    parent_uid = active_capability(fixture)
    child = child_attrs(fixture, parent_uid)

    issuer =
      lock_holder(fixture, parent_uid, fn tx, _parent ->
        CapabilityService.issue_capability(tx, child)
      end)

    assert_receive {:locked, issuer_pid}, 10_000

    revoker =
      competitor(:revoke, fn ->
        CapabilityService.revoke_capability(
          Repo,
          fixture.company_uid,
          parent_uid,
          fixture.revoker_uid
        )
      end)

    assert_receive {:attempting, :revoke, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :revoke, _result, _waited}
    assert Process.alive?(revoker.pid)

    send(issuer_pid, :release)
    assert {:ok, {:ok, %Capability{uid: child_uid}}} = Task.await(issuer, 15_000)

    assert_receive {:completed, :revoke, {:ok, %Capability{status: :revoked}}, waited}, 15_000

    assert waited >= 250,
           "the revoke must have blocked on the child issuance's parent lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:ok, %Capability{status: :revoked}} = Task.await(revoker, 15_000)
    assert :revoked == persisted_status(fixture, parent_uid)

    # The child exists and is itself active. Its authority is denied later, by
    # the existing ancestry rule, because its parent is revoked.
    assert :active == persisted_status(fixture, child_uid)

    assert {:error, :parent_capability_invalid} =
             Sandbox.unboxed_run(Repo, fn ->
               CapabilityService.validate_capability(Repo, fixture.company_uid, child_uid)
             end)
  end

  # ─── F: revoke holds the parent lock, child issuance waits ────────────────

  @tag ownership_timeout: 30_000

  test "F a revoke holding the parent lock makes child issuance wait, and no child is issued" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    parent_uid = active_capability(fixture)
    child = child_attrs(fixture, parent_uid)

    revoker =
      lock_holder(fixture, parent_uid, fn tx, capability ->
        CapabilityStore.revoke_locked(tx, capability)
      end)

    assert_receive {:locked, revoker_pid}, 10_000

    issuer =
      competitor(:issue, fn ->
        CapabilityService.issue_capability(Repo, child)
      end)

    assert_receive {:attempting, :issue, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :issue, _result, _waited}
    assert Process.alive?(issuer.pid)

    send(revoker_pid, :release)
    assert {:ok, {:ok, %Capability{status: :revoked}}} = Task.await(revoker, 15_000)

    assert_receive {:completed, :issue, {:error, :parent_capability_invalid}, waited}, 15_000

    assert waited >= 250,
           "the child issuance must have blocked on the revoke's row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:error, :parent_capability_invalid} = Task.await(issuer, 15_000)

    assert :revoked == persisted_status(fixture, parent_uid)
    assert nil == persisted_capability(fixture, child.uid)
  end

  # ─── G: consumption against child issuance, both orders ───────────────────

  test "G a child issued before its parent is consumed fails ancestry when used" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    parent_uid = active_capability(fixture)
    child = child_attrs(fixture, parent_uid)

    assert {:ok, %Capability{uid: child_uid}} =
             Sandbox.unboxed_run(Repo, fn ->
               CapabilityService.issue_capability(Repo, child)
             end)

    assert {:ok, %Capability{status: :consumed}} =
             Sandbox.unboxed_run(Repo, fn ->
               Repo.transact(fn tx ->
                 {:ok, locked} =
                   CapabilityStore.fetch_capability_for_update(
                     tx,
                     fixture.company_uid,
                     parent_uid
                   )

                 CapabilityService.consume_locked(tx, locked)
               end)
             end)

    # The child was issued first, so it exists, but its parent no longer carries
    # authority. The existing ancestry check denies it at use.
    assert :active == persisted_status(fixture, child_uid)
    assert :consumed == persisted_status(fixture, parent_uid)

    assert {:error, :parent_capability_invalid} =
             Sandbox.unboxed_run(Repo, fn ->
               CapabilityService.validate_capability(Repo, fixture.company_uid, child_uid)
             end)
  end

  test "G a parent consumed before its child is issued refuses the child" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    parent_uid = active_capability(fixture)
    child = child_attrs(fixture, parent_uid)

    assert {:ok, %Capability{status: :consumed}} =
             Sandbox.unboxed_run(Repo, fn ->
               Repo.transact(fn tx ->
                 {:ok, locked} =
                   CapabilityStore.fetch_capability_for_update(
                     tx,
                     fixture.company_uid,
                     parent_uid
                   )

                 CapabilityService.consume_locked(tx, locked)
               end)
             end)

    assert {:error, :parent_capability_invalid} =
             Sandbox.unboxed_run(Repo, fn ->
               CapabilityService.issue_capability(Repo, child)
             end)

    assert :consumed == persisted_status(fixture, parent_uid)
    assert nil == persisted_capability(fixture, child.uid)
  end

  # ─── H: two revocations race ──────────────────────────────────────────────

  @tag ownership_timeout: 30_000

  test "H two concurrent revocations produce one transition and one :already_revoked" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    capability_uid = active_capability(fixture)

    winner =
      lock_holder(fixture, capability_uid, fn tx, capability ->
        CapabilityStore.revoke_locked(tx, capability)
      end)

    assert_receive {:locked, winner_pid}, 10_000

    loser =
      competitor(:revoke, fn ->
        CapabilityService.revoke_capability(
          Repo,
          fixture.company_uid,
          capability_uid,
          fixture.revoker_uid
        )
      end)

    assert_receive {:attempting, :revoke, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :revoke, _result, _waited}
    assert Process.alive?(loser.pid)

    send(winner_pid, :release)
    assert {:ok, {:ok, %Capability{status: :revoked}}} = Task.await(winner, 15_000)

    assert_receive {:completed, :revoke, {:error, :already_revoked}, waited}, 15_000

    assert waited >= 250,
           "the losing revoke must have blocked on the winning row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:error, :already_revoked} = Task.await(loser, 15_000)
    assert :revoked == persisted_status(fixture, capability_uid)
  end

  # ─── I: two expiries race ────────────────────────────────────────────────

  @tag ownership_timeout: 30_000

  test "I two concurrent expiries produce one transition and one :already_expired" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)
    capability_uid = active_capability(fixture)

    winner =
      lock_holder(fixture, capability_uid, fn tx, capability ->
        CapabilityStore.expire_locked(tx, capability)
      end)

    assert_receive {:locked, winner_pid}, 10_000

    loser =
      competitor(:expire, fn ->
        CapabilityService.expire_capability(Repo, fixture.company_uid, capability_uid)
      end)

    assert_receive {:attempting, :expire, attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:completed, :expire, _result, _waited}
    assert Process.alive?(loser.pid)

    send(winner_pid, :release)
    assert {:ok, {:ok, %Capability{status: :expired}}} = Task.await(winner, 15_000)

    assert_receive {:completed, :expire, {:error, :already_expired}, waited}, 15_000

    assert waited >= 250,
           "the losing expiry must have blocked on the winning row lock, waited #{waited}ms"

    assert System.monotonic_time(:millisecond) - attempted_at >= 250
    assert {:error, :already_expired} = Task.await(loser, 15_000)
    assert :expired == persisted_status(fixture, capability_uid)
  end

  # ─── two-connection helpers ───────────────────────────────────────────────

  # T1 holds the Capability row lock in its own transaction until the test
  # releases it, then performs `action` on the locked row and commits.
  defp lock_holder(fixture, capability_uid, action) do
    parent = self()

    Task.async(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.transact(fn tx ->
          CapabilityStore.with_capability_lock(
            tx,
            fixture.company_uid,
            capability_uid,
            fn inner, capability ->
              send(parent, {:locked, self()})

              receive do
                :release -> :ok
              after
                15_000 -> :ok
              end

              {:ok, action.(inner, capability)}
            end
          )
        end)
      end)
    end)
  end

  # T2 runs `operation` on a genuinely independent connection. It announces that
  # it is about to reach the row lock, so the test can prove that it stayed
  # blocked while the lock holder was still active.
  defp competitor(label, operation) do
    parent = self()

    Task.async(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        started = System.monotonic_time(:millisecond)
        send(parent, {:attempting, label, started})

        result = operation.()

        send(parent, {:completed, label, result, System.monotonic_time(:millisecond) - started})

        result
      end)
    end)
  end

  # ─── committed fixtures and cleanup ───────────────────────────────────────

  defp committed_fixture do
    Sandbox.unboxed_run(Repo, fn ->
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture(uid: "w3-p8-lc-owner-#{suffix}")

      {:ok, company} =
        %Company{}
        |> Company.changeset(%{
          uid: "w3-p8-lc-company-#{suffix}",
          name: "w3-p8-lc-company-#{suffix}",
          display_name: "W3 P8 Lifecycle Lock Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner.uid
        })
        |> Repo.insert()

      %{principal: holder} = human_fixture(uid: "w3-p8-lc-holder-#{suffix}")
      %{principal: issuer} = human_fixture(uid: "w3-p8-lc-issuer-#{suffix}")

      for uid <- [owner.uid, holder.uid, issuer.uid] do
        {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
      end

      %{
        company_uid: company.uid,
        holder_uid: holder.uid,
        revoker_uid: issuer.uid,
        principal_uids: [owner.uid, holder.uid, issuer.uid]
      }
    end)
  end

  defp active_capability(fixture) do
    Sandbox.unboxed_run(Repo, fn ->
      {:ok, capability} =
        %Capability{}
        |> Capability.changeset(%{
          uid: "w3-p8-lc-cap-#{System.unique_integer([:positive])}",
          company_uid: fixture.company_uid,
          principal_uid: fixture.holder_uid,
          action: @action,
          resource: @resource,
          status: :active,
          risk_class: @risk_class,
          issued_at: ~U[2026-09-26T10:00:00Z],
          issued_by_principal_uid: fixture.revoker_uid,
          scope: %{},
          constraints: %{},
          metadata: %{}
        })
        |> Repo.insert()

      capability.uid
    end)
  end

  # A child that does not exceed its parent in any binding field, so attenuation
  # passes and the parent's state is the only reason an issuance can fail.
  defp child_attrs(fixture, parent_uid) do
    %{
      uid: "w3-p8-lc-child-#{System.unique_integer([:positive])}",
      company_uid: fixture.company_uid,
      principal_uid: fixture.holder_uid,
      action: @action,
      resource: @resource,
      risk_class: @risk_class,
      issued_at: ~U[2026-09-26T10:00:00Z],
      issued_by_principal_uid: fixture.revoker_uid,
      parent_capability_uid: parent_uid,
      scope: %{},
      constraints: %{}
    }
  end

  defp persisted_capability(fixture, capability_uid) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.get_by(Capability, uid: capability_uid, company_uid: fixture.company_uid)
    end)
  end

  defp persisted_status(fixture, capability_uid) do
    case persisted_capability(fixture, capability_uid) do
      %Capability{status: status} -> status
      nil -> nil
    end
  end

  defp cleanup(fixture) do
    Sandbox.unboxed_run(Repo, fn ->
      import Ecto.Query

      Capability
      |> where([capability], capability.company_uid == ^fixture.company_uid)
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
