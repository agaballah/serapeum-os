defmodule Ankole.W3.P8TransactionContractTest do
  @moduledoc """
  A-7 transaction contract proof for the authoritative controlled-action route.

  The A-7 semantic lock approved one execution order:

      assure/7
        -> Repo.transact
          -> fetch_capability_for_update
          -> validate_prefetched_capability
          -> validate_exact_binding
          -> W2 mutation
          -> consume_locked
          -> finalize_assurance receipt
          -> commit

  This module proves that order is implementable with existing repository
  primitives, and that it upholds the SerapeumOS truth guarantee: a reported
  success means the domain mutation, the authority consumption, and the receipt
  all committed together, and no failure leaves a burned Capability or a
  misleading partial success behind.

  This is a proof harness, not production wiring. `Ankole.W3.P8ControlledAction`
  is untouched and stays fail-closed (`ready?/0` is still `false`), because A-7
  is not the gate that completes the execution pipeline. Nothing here is
  reachable from a production caller.
  """

  use Ankole.DataCase, async: true

  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Repo
  alias Ankole.W3.ActionAssurance
  alias Ankole.W3.ActionReceipt
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.CapabilityStore
  alias Ankole.WorkHierarchy.TaskStore

  import Ankole.PrincipalsFixtures

  @action "create_task"
  @resource "workspace:default"
  @risk_class "CONTROLLED"

  # A-3 permits a nil Capability only on ROUTINE actions.
  @read_action "list_company_tasks"

  # The committed order. A future change that moves consumption ahead of the
  # mutation changes this list and fails the ordering tests below, which is the
  # point of pinning it here rather than only in prose.
  @approved_order [:assure, :lock, :revalidate, :binding, :mutate, :consume, :receipt]

  # ─── fixtures ─────────────────────────────────────────────────────────────

  defp company_fixture(owner_uid) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(%{
        uid: "a7-company-#{suffix}",
        name: "a7-company-#{suffix}",
        display_name: "A7 Contract Test Company",
        status: :active,
        metadata: %{},
        owner_principal_uid: owner_uid
      })
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

  defp capability_fixture(company_uid, principal_uid, issuer_uid) do
    suffix = System.unique_integer([:positive])

    {:ok, capability} =
      %Capability{}
      |> Capability.changeset(%{
        uid: "a7-cap-#{suffix}",
        company_uid: company_uid,
        principal_uid: principal_uid,
        action: @action,
        resource: @resource,
        status: :active,
        risk_class: @risk_class,
        issued_at: ~U[2026-09-26T10:00:00Z],
        issued_by_principal_uid: issuer_uid,
        scope: %{},
        constraints: %{},
        metadata: %{}
      })
      |> Repo.insert()

    capability
  end

  defp task_attrs(uid, creator_uid) do
    %{
      uid: uid,
      creator_principal_uid: creator_uid,
      origin_kind: "OWNER_REQUEST",
      objective_text: "Objective.",
      scope_text: "Scope.",
      required_outcome_text: "Outcome.",
      acceptance_criteria_text: "Criteria."
    }
  end

  defp controlled_context do
    suffix = System.unique_integer([:positive])
    %{principal: owner} = human_fixture()
    company = company_fixture(owner.uid)
    %{principal: holder} = human_fixture()
    %{principal: issuer} = human_fixture()

    for uid <- [owner.uid, holder.uid, issuer.uid] do
      {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
    end

    grant_fixture(holder.uid, company.uid, "workspace:**", @action)

    capability = capability_fixture(company.uid, holder.uid, issuer.uid)

    %{
      company: company,
      owner: owner,
      principal: holder,
      issuer: issuer,
      capability: capability,
      capability_uid: capability.uid,
      action: @action,
      task_uid: "a7-task-#{suffix}"
    }
  end

  # A-3 makes a nil Capability legal only for ROUTINE actions. This branch
  # therefore assures a permitted ROUTINE read while the transaction body still
  # performs a real W2 write, so the proof stays the one it always was: that the
  # lock, revalidation, and consumption steps are skipped and that a write plus
  # its receipt still commit together, or not at all. It is not a claim that a
  # nil-Capability mutation is reachable; under Policy B it is not.
  defp capability_less_context(context) do
    suffix = System.unique_integer([:positive])

    grant_fixture(
      context.principal.uid,
      context.company.uid,
      "workspace:**",
      @read_action
    )

    Map.merge(context, %{
      capability: nil,
      capability_uid: nil,
      action: @read_action,
      task_uid: "a7-task-#{suffix}"
    })
  end

  # ─── the approved contract, expressed once ─────────────────────────────────

  # `opts` injects a failure at exactly one step so each rollback case can be
  # proven without altering the order every other test depends on. `:mutate`,
  # `:consume`, and `:receipt` each default to the real repository call.
  defp controlled_action(context, opts \\ []) do
    company_uid = context.company.uid
    principal_uid = context.principal.uid
    capability_uid = context.capability_uid
    binding = binding_expectation(context)

    assure_opts =
      Keyword.put_new(opts, :scope, %{})
      |> Keyword.put_new(:constraints, %{})

    reset_trace()

    case ActionAssurance.assure(
           Repo,
           company_uid,
           principal_uid,
           context.action,
           @resource,
           capability_uid,
           assure_opts
         ) do
      {:ok, context_map} ->
        trace(:assure)

        result =
          Repo.transact(fn tx ->
            with {:ok, locked} <- lock_step(tx, company_uid, capability_uid),
                 :ok <- revalidate_step(tx, locked, binding),
                 {:ok, mutation} <- mutate_step(tx, context, opts),
                 {:ok, consumed} <- consume_step(tx, locked, opts),
                 {:ok, receipt} <- receipt_step(tx, context_map, opts) do
              {:ok, %{mutation: mutation, consumed: consumed, receipt: receipt}}
            end
          end)

        {result, trace_order()}

      {:error, reason} ->
        {{:error, {:assurance_refused, reason}}, trace_order()}
    end
  end

  defp lock_step(_tx, _company_uid, nil) do
    trace(:lock)
    {:ok, nil}
  end

  defp lock_step(tx, company_uid, capability_uid) do
    trace(:lock)
    CapabilityStore.fetch_capability_for_update(tx, company_uid, capability_uid)
  end

  defp revalidate_step(_tx, nil, _binding) do
    trace(:revalidate)
    :ok
  end

  defp revalidate_step(tx, locked, binding) do
    trace(:revalidate)

    with :ok <- CapabilityService.validate_prefetched_capability(tx, locked),
         :ok <- CapabilityService.validate_exact_binding(locked, binding) do
      trace(:binding)
      :ok
    end
  end

  defp mutate_step(tx, context, opts) do
    trace(:mutate)

    mutate =
      Keyword.get(opts, :mutate, fn tx, context, _opts ->
        TaskStore.create_task(
          tx,
          context.company.uid,
          task_attrs(context.task_uid, context.principal.uid)
        )
      end)

    mutate.(tx, context, opts)
  end

  defp consume_step(_tx, nil, _opts) do
    trace(:consume)
    {:ok, nil}
  end

  defp consume_step(tx, locked, opts) do
    trace(:consume)

    consume =
      Keyword.get(opts, :consume, fn tx, locked, _opts ->
        CapabilityService.consume_locked(tx, locked)
      end)

    consume.(tx, locked, opts)
  end

  defp receipt_step(tx, context, opts) do
    trace(:receipt)

    receipt =
      Keyword.get(opts, :receipt, fn tx, context, _opts ->
        ActionAssurance.finalize_assurance(tx, context, false, %{})
      end)

    receipt.(tx, context, opts)
  end

  defp binding_expectation(context) do
    [
      principal_uid: context.principal.uid,
      action: @action,
      resource: @resource,
      risk_class: @risk_class,
      approval_uid: nil,
      scope: %{},
      constraints: %{}
    ]
  end

  defp reset_trace, do: Process.put(:a7_trace, [])

  defp trace(step), do: Process.put(:a7_trace, [step | Process.get(:a7_trace, [])])

  defp trace_order, do: Process.get(:a7_trace, []) |> Enum.reverse()

  # ─── assertions ───────────────────────────────────────────────────────────

  defp company_receipts(company_uid) do
    ActionReceipt
    |> where([receipt], receipt.company_uid == ^company_uid)
    |> Repo.all()
  end

  defp company_capabilities(company_uid) do
    CapabilityStore.list_company_capabilities(Repo, company_uid)
  end

  # ─── A7-1: atomic success ─────────────────────────────────────────────────

  test "A7-1 one transaction commits the mutation, the consumption, and the receipt together" do
    context = controlled_context()

    assert {{:ok, %{mutation: mutation, consumed: consumed, receipt: receipt}}, order} =
             controlled_action(context)

    assert order == @approved_order
    assert mutation.status == "PROPOSED"
    assert consumed.status == :consumed

    # Read back from outside the transaction. Nothing is visible unless all
    # three effects committed together.
    assert %Ankole.WorkHierarchy.Task{} =
             TaskStore.fetch_task(Repo, context.company.uid, context.task_uid)

    assert %Capability{status: :consumed} = Repo.get_by(Capability, uid: context.capability_uid)
    assert %ActionReceipt{capability_uid: capability_uid} = ActionAssurance.fetch_receipt(Repo, receipt.receipt_uid)
    assert capability_uid == context.capability_uid
    assert [_only_receipt] = company_receipts(context.company.uid)
  end

  # ─── A7-2: mutation failure ───────────────────────────────────────────────

  test "A7-2 a failed mutation commits nothing and leaves the Capability active" do
    context = controlled_context()

    # A Task already holds this UID, so the insert inside the transaction trips
    # the unique index after assurance has already succeeded.
    {:ok, _existing} =
      Repo.transact(fn tx ->
        TaskStore.create_task(tx, context.company.uid, task_attrs(context.task_uid, context.principal.uid))
      end)

    assert {{:error, %Ecto.Changeset{}}, order} = controlled_action(context)

    # The mutation failed, so the steps after it were never reached. Reaching
    # neither consumption nor the receipt is what keeps the Capability intact.
    assert order == [:assure, :lock, :revalidate, :binding, :mutate]

    # The pre-existing Task is untouched and no second one exists.
    assert [_only_task] = list_tasks(context.company.uid)
    assert %Capability{status: :active} = Repo.get_by(Capability, uid: context.capability_uid)
    assert company_receipts(context.company.uid) == []
  end

  # ─── A7-3: receipt failure ────────────────────────────────────────────────

  test "A7-3 a failed receipt rolls back both the mutation and the consumption" do
    context = controlled_context()

    # A non-empty postcondition has no interpretation in this repository, so
    # `finalize_assurance/4` refuses it with an existing typed error instead of
    # inserting a receipt that claims nothing was evaluated.
    postcondition = %{"task_status" => "COMPLETED"}

    assert {{:error, :unsupported_postcondition}, order} =
             controlled_action(context, postcondition_expected: postcondition)

    assert order == @approved_order
    assert nil == TaskStore.fetch_task(Repo, context.company.uid, context.task_uid)
    assert %Capability{status: :active} = Repo.get_by(Capability, uid: context.capability_uid)
    assert company_receipts(context.company.uid) == []
  end

  # ─── A7-4: consumption failure ────────────────────────────────────────────

  test "A7-4 a failed consumption rolls the completed mutation back" do
    context = controlled_context()

    consume =
      fn tx, _locked, _opts ->
        # The W2 mutation has already succeeded in this transaction. A real
        # lifecycle transition then makes the Capability unusable, which is the
        # guard `consume_locked/2` enforces on the row it is handed.
        {:ok, _revoked} =
          CapabilityStore.revoke_capability(
            tx,
            context.company.uid,
            context.capability_uid,
            context.owner.uid
          )

        {:ok, truth} =
          CapabilityStore.fetch_capability(tx, context.company.uid, context.capability_uid)

        CapabilityService.consume_locked(tx, truth)
      end

    assert {{:error, :revoked}, order} = controlled_action(context, consume: consume)

    # Consumption refused, so the receipt was never attempted.
    assert order == [:assure, :lock, :revalidate, :binding, :mutate, :consume]

    assert nil == TaskStore.fetch_task(Repo, context.company.uid, context.task_uid)
    # The injected revocation was itself rolled back, so the Capability is not
    # merely un-consumed but exactly as it was before the attempt.
    assert %Capability{status: :active} = Repo.get_by(Capability, uid: context.capability_uid)
    assert company_receipts(context.company.uid) == []
  end

  # ─── A7-5: rollback does not burn the Capability ──────────────────────────

  test "A7-5 a rollback after consumption restores the Capability to active and reusable" do
    context = controlled_context()

    abort = fn _tx, _context, _opts -> {:error, :rolled_back} end

    assert {{:error, :rolled_back}, order} = controlled_action(context, receipt: abort)
    assert order == @approved_order

    assert nil == TaskStore.fetch_task(Repo, context.company.uid, context.task_uid)
    assert %Capability{status: :active} = Repo.get_by(Capability, uid: context.capability_uid)
    assert company_receipts(context.company.uid) == []

    # The row is still consumable, which proves the rollback released both the
    # update and the row lock.
    assert {:ok, %Capability{status: :consumed}} =
             Repo.transact(fn tx ->
               {:ok, locked} =
                 CapabilityStore.fetch_capability_for_update(tx, context.company.uid, context.capability_uid)

               CapabilityService.consume_locked(tx, locked)
             end)
  end

  # ─── A7-9: order pinning ──────────────────────────────────────────────────

  test "A7-9 the committed order locks, revalidates, binds, mutates, consumes, then receipts" do
    context = controlled_context()

    assert {{:ok, _result}, order} = controlled_action(context)

    assert order == @approved_order

    consume_index = Enum.find_index(order, &(&1 == :consume))
    mutate_index = Enum.find_index(order, &(&1 == :mutate))
    receipt_index = Enum.find_index(order, &(&1 == :receipt))

    # Consumption must never precede the mutation it pays for, and the receipt
    # is the last durable write before commit.
    assert mutate_index < consume_index
    assert consume_index < receipt_index
    assert Enum.find_index(order, &(&1 == :lock)) < Enum.find_index(order, &(&1 == :mutate))
  end

  # ─── A7-7: capability-less branch ─────────────────────────────────────────

  describe "capability-less branch (Policy B permits nil on ROUTINE only)" do
    test "A7-7a the mutation and the receipt still commit together" do
      context = capability_less_context(controlled_context())

      assert {{:ok, %{mutation: mutation, receipt: receipt}}, order} = controlled_action(context)

      # The order is unchanged. The lock, revalidation, and consumption
      # positions are still visited but perform no work, because there is no
      # Capability row to lock, revalidate, or consume. `validate_exact_binding`
      # is Capability-only, so it is the one step that disappears entirely.
      assert order == [:assure, :lock, :revalidate, :mutate, :consume, :receipt]
      assert mutation.status == "PROPOSED"

      assert %Ankole.WorkHierarchy.Task{} =
               TaskStore.fetch_task(Repo, context.company.uid, context.task_uid)

      assert [_only_receipt] = company_receipts(context.company.uid)
      assert [%ActionReceipt{capability_uid: nil}] = company_receipts(context.company.uid)
      assert %ActionReceipt{} = ActionAssurance.fetch_receipt(Repo, receipt.receipt_uid)

      # A-3: the nil Capability was legal here only because the assured action
      # is ROUTINE. The receipt must record that truth, not a CONTROLLED claim.
      persisted = ActionAssurance.fetch_receipt(Repo, receipt.receipt_uid)
      assert persisted.intent_action == @read_action
      assert persisted.risk_class == "ROUTINE"
      assert persisted.capability_uid == nil
    end

    test "A7-7b a failed receipt still rolls the mutation back" do
      context = capability_less_context(controlled_context())
      postcondition = %{"task_status" => "COMPLETED"}

      assert {{:error, :unsupported_postcondition}, _order} =
               controlled_action(context, postcondition_expected: postcondition)

      assert nil == TaskStore.fetch_task(Repo, context.company.uid, context.task_uid)
      assert company_receipts(context.company.uid) == []
    end

    test "A7-7c no Capability row is created or touched" do
      context = capability_less_context(controlled_context())

      before = company_capabilities(context.company.uid)
      assert {{:ok, _result}, _order} = controlled_action(context)

      assert company_capabilities(context.company.uid) == before
    end
  end

  # ─── A7-8: nested transaction poisoning ───────────────────────────────────

  test "A7-8 an inner transaction error cannot be swallowed into an outer success" do
    context = controlled_context()

    outer =
      Repo.transact(fn tx ->
        {:ok, locked} =
          CapabilityStore.fetch_capability_for_update(tx, context.company.uid, context.capability_uid)

        {:ok, _consumed} = CapabilityService.consume_locked(tx, locked)

        # The orchestrator ignores the inner failure and reports success anyway.
        inner = Repo.transact(fn _inner_tx -> {:error, :inner_failed} end)
        send(self(), {:inner_result, inner})

        {:ok, :outer_reported_success}
      end)

    assert_received {:inner_result, {:error, :inner_failed}}

    # Nesting creates no savepoint, so the inner rollback poisons the enclosing
    # transaction. The outer body returned `{:ok, _}`, so this must not commit.
    assert outer == {:error, :rollback}

    assert %Capability{status: :active} = Repo.get_by(Capability, uid: context.capability_uid)
    assert company_receipts(context.company.uid) == []
  end

  defp list_tasks(company_uid), do: TaskStore.list_company_tasks(Repo, company_uid)
end

defmodule Ankole.W3.P8TransactionContractConcurrencyTest do
  @moduledoc """
  A-7 concurrent replay proof, in the B5-T8 two-connection pattern.

  The sandbox gives one process one connection, so it cannot show that a second
  transaction blocks on the first transaction's `FOR UPDATE` lock. This module
  therefore leaves the sandbox with `unboxed_run` and drives two independent
  connections against one committed Capability row. Because those rows are
  committed for real, the module deletes every row it creates.
  """

  use Ankole.DataCase, async: false

  import Ankole.PrincipalsFixtures

  alias Ankole.AuthZ
  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.Repo
  alias Ankole.W3.ActionAssurance
  alias Ankole.W3.ActionReceipt
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.CapabilityStore
  alias Ankole.WorkHierarchy.TaskStore

  alias Ecto.Adapters.SQL.Sandbox

  @action "create_task"
  @resource "workspace:default"
  @risk_class "CONTROLLED"

  # Serial: this module commits rows outside the sandbox and coordinates two
  # blocking connections, so it cannot run concurrently with other tests.
  @tag ownership_timeout: 30_000

  test "A7-6a when Tx A commits, Tx B blocks, then refuses as already_consumed" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)

    parent = self()
    context_a = assure(fixture)
    context_b = assure(fixture)
    binding = binding_expectation(fixture)

    tx_a =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(tx_a_body(fixture, binding, context_a, parent, :commit))
        end)
      end)

    assert_receive {:tx_a_locked, tx_a_pid}, 10_000

    tx_b =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(tx_b_body(fixture, binding, context_b, parent))
        end)
      end)

    assert_receive {:tx_b_attempting_lock, attempted_at}, 10_000

    # Tx B has reached the lock query while Tx A still holds the lock, so any
    # state it reports must have been read after Tx A released the lock.
    Process.sleep(300)
    refute_received {:tx_b_observed, _status, _waited}
    assert Process.alive?(tx_b.pid)

    send(tx_a_pid, :go)
    assert {:ok, :committed} = Task.await(tx_a, 15_000)

    assert_receive {:tx_b_observed, :consumed, waited}, 15_000
    assert waited >= 250, "Tx B must have blocked on Tx A's row lock, waited #{waited}ms"
    assert System.monotonic_time(:millisecond) - attempted_at >= 250

    assert {:error, :already_consumed} = Task.await(tx_b, 15_000)

    # Exactly one execution committed, and Tx B left no mutation and no receipt.
    Sandbox.unboxed_run(Repo, fn ->
      assert %Capability{status: :consumed} =
               Repo.get_by!(Capability, uid: fixture.capability_uid)

      assert %Ankole.WorkHierarchy.Task{} =
               TaskStore.fetch_task(Repo, fixture.company_uid, fixture.task_a_uid)

      assert nil == TaskStore.fetch_task(Repo, fixture.company_uid, fixture.task_b_uid)

      receipts = receipts_for(fixture.company_uid)
      assert length(receipts) == 1
      assert hd(receipts).receipt_uid == context_a.receipt_uid
    end)
  end

  @tag ownership_timeout: 30_000

  test "A7-6b when Tx A rolls back, Tx B unblocks on the restored row and may commit" do
    fixture = committed_fixture()
    on_exit(fn -> cleanup(fixture) end)

    parent = self()
    context_a = assure(fixture)
    context_b = assure(fixture)
    binding = binding_expectation(fixture)

    tx_a =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(tx_a_body(fixture, binding, context_a, parent, :rollback))
        end)
      end)

    assert_receive {:tx_a_locked, tx_a_pid}, 10_000

    tx_b =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.transact(tx_b_body(fixture, binding, context_b, parent))
        end)
      end)

    assert_receive {:tx_b_attempting_lock, _attempted_at}, 10_000

    Process.sleep(300)
    refute_received {:tx_b_observed, _status, _waited}
    assert Process.alive?(tx_b.pid)

    send(tx_a_pid, :go)
    assert {:error, :tx_a_aborted} = Task.await(tx_a, 15_000)

    # The rollback discarded Tx A's consumed row version, so Tx B blocks and
    # then finds the Capability active again.
    assert_receive {:tx_b_observed, :active, waited}, 15_000
    assert waited >= 250, "Tx B must have blocked on Tx A's row lock, waited #{waited}ms"

    assert {:ok, :committed} = Task.await(tx_b, 15_000)

    Sandbox.unboxed_run(Repo, fn ->
      assert %Capability{status: :consumed} =
               Repo.get_by!(Capability, uid: fixture.capability_uid)

      # Tx A's mutation and receipt are gone; only Tx B's survive.
      assert nil == TaskStore.fetch_task(Repo, fixture.company_uid, fixture.task_a_uid)

      assert %Ankole.WorkHierarchy.Task{} =
               TaskStore.fetch_task(Repo, fixture.company_uid, fixture.task_b_uid)

      receipts = receipts_for(fixture.company_uid)
      assert length(receipts) == 1
      assert hd(receipts).receipt_uid == context_b.receipt_uid
    end)
  end

  # ─── transaction bodies ───────────────────────────────────────────────────

  # Tx A pauses while holding the Capability lock so Tx B must block, then
  # either commits the whole action or rolls the whole action back.
  defp tx_a_body(fixture, binding, context, parent, mode) do
    fn tx ->
      with {:ok, locked} <-
             CapabilityStore.fetch_capability_for_update(tx, fixture.company_uid, fixture.capability_uid) do
        send(parent, {:tx_a_locked, self()})

        receive do
          :go -> :ok
        after
          15_000 -> :ok
        end

        with :ok <- CapabilityService.validate_prefetched_capability(tx, locked),
             :ok <- CapabilityService.validate_exact_binding(locked, binding),
             {:ok, _mutation} <-
               TaskStore.create_task(tx, fixture.company_uid, task_attrs(fixture.task_a_uid, fixture.creator_uid)),
             {:ok, _consumed} <- CapabilityService.consume_locked(tx, locked) do
          if mode == :commit do
            {:ok, _receipt} = ActionAssurance.finalize_assurance(tx, context, false, %{})
            {:ok, :committed}
          else
            Repo.rollback(:tx_a_aborted)
          end
        end
      end
    end
  end

  # Tx B runs the same approved order. Under `READ COMMITTED` its blocked
  # `SELECT ... FOR UPDATE` re-reads whichever row version Tx A committed.
  defp tx_b_body(fixture, binding, context, parent) do
    fn tx ->
      send(parent, {:tx_b_attempting_lock, System.monotonic_time(:millisecond)})
      started = System.monotonic_time(:millisecond)

      with {:ok, locked_b} <-
             CapabilityStore.fetch_capability_for_update(tx, fixture.company_uid, fixture.capability_uid) do
        waited = System.monotonic_time(:millisecond) - started
        send(parent, {:tx_b_observed, locked_b.status, waited})

        with :ok <- CapabilityService.validate_prefetched_capability(tx, locked_b),
             :ok <- CapabilityService.validate_exact_binding(locked_b, binding),
             {:ok, _mutation} <-
               TaskStore.create_task(tx, fixture.company_uid, task_attrs(fixture.task_b_uid, fixture.creator_uid)),
             {:ok, _consumed} <- CapabilityService.consume_locked(tx, locked_b),
             {:ok, _receipt} <- ActionAssurance.finalize_assurance(tx, context, false, %{}) do
          {:ok, :committed}
        end
      end
    end
  end

  # ─── committed fixtures and cleanup ───────────────────────────────────────

  defp committed_fixture do
    Sandbox.unboxed_run(Repo, fn ->
      suffix = System.unique_integer([:positive])
      %{principal: owner} = human_fixture()
      %{principal: holder} = human_fixture()
      %{principal: issuer} = human_fixture()

      {:ok, company} =
        %Company{}
        |> Company.changeset(%{
          uid: "a7-conc-company-#{suffix}",
          name: "a7-conc-company-#{suffix}",
          display_name: "A7 Concurrency Company",
          status: :active,
          metadata: %{},
          owner_principal_uid: owner.uid
        })
        |> Repo.insert()

      for uid <- [owner.uid, holder.uid, issuer.uid] do
        {:ok, _membership} = MembershipStore.add_member(Repo, company.uid, uid)
      end

      {:ok, _grant} =
        AuthZ.upsert_permission_grant(%{
          principal_uid: holder.uid,
          company_uid: company.uid,
          resource_pattern: "workspace:**",
          action: @action,
          condition: "true"
        })

      {:ok, capability} =
        %Capability{}
        |> Capability.changeset(%{
          uid: "a7-conc-cap-#{suffix}",
          company_uid: company.uid,
          principal_uid: holder.uid,
          action: @action,
          resource: @resource,
          status: :active,
          risk_class: @risk_class,
          issued_at: ~U[2026-09-26T10:00:00Z],
          issued_by_principal_uid: issuer.uid,
          scope: %{},
          constraints: %{},
          metadata: %{}
        })
        |> Repo.insert()

      %{
        company_uid: company.uid,
        capability_uid: capability.uid,
        creator_uid: holder.uid,
        principal_uid: holder.uid,
        task_a_uid: "a7-conc-task-a-#{suffix}",
        task_b_uid: "a7-conc-task-b-#{suffix}",
        principal_uids: [owner.uid, holder.uid, issuer.uid]
      }
    end)
  end

  defp cleanup(fixture) do
    Sandbox.unboxed_run(Repo, fn ->
      ActionReceipt
      |> where([receipt], receipt.company_uid == ^fixture.company_uid)
      |> Repo.delete_all()

      for uid <- [fixture.task_a_uid, fixture.task_b_uid] do
        Ankole.WorkHierarchy.Task
        |> where([task], task.uid == ^uid)
        |> Repo.delete_all()
      end

      Capability
      |> where([capability], capability.uid == ^fixture.capability_uid)
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

  defp assure(fixture) do
    {:ok, context} =
      ActionAssurance.assure(
        Repo,
        fixture.company_uid,
        fixture.principal_uid,
        @action,
        @resource,
        fixture.capability_uid
      )

    context
  end

  defp binding_expectation(fixture) do
    [
      principal_uid: fixture.principal_uid,
      action: @action,
      resource: @resource,
      risk_class: @risk_class,
      approval_uid: nil,
      scope: %{},
      constraints: %{}
    ]
  end

  defp task_attrs(uid, creator_uid) do
    %{
      uid: uid,
      creator_principal_uid: creator_uid,
      origin_kind: "OWNER_REQUEST",
      objective_text: "Objective.",
      scope_text: "Scope.",
      required_outcome_text: "Outcome.",
      acceptance_criteria_text: "Criteria."
    }
  end

  defp receipts_for(company_uid) do
    ActionReceipt
    |> where([receipt], receipt.company_uid == ^company_uid)
    |> Repo.all()
  end
end