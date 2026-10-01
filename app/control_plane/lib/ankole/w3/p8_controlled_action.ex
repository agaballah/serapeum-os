defmodule Ankole.W3.P8ControlledAction do
  @moduledoc """
  The authoritative production boundary for controlled W2 mutations.

  ## Ownership contract

  This module is the **sole supported production boundary** for controlled W2
  mutations. If SerapeumOS performs a controlled W2 mutation in production, the
  mutation must be reached through this boundary.

  Production code that calls `Ankole.WorkHierarchy.TaskStore`,
  `Ankole.WorkHierarchy.MissionStore`, `Ankole.WorkHierarchy.ResultStore`,
  `Ankole.WorkHierarchy.ReviewStore`, or `Ankole.WorkHierarchy.GoalStore`
  mutation functions directly is prohibited. The repository architecture guard
  in `test/ankole/w3/p8_boundary_test.exs` fails qualification when a checked-in
  production source outside this module does so.

  The five W2 store modules remain the domain mutation implementation layer.
  They are the persistence and invariant-owning code beneath this boundary, and
  their low-level domain tests remain valid. W2 does not depend on W3.

  ## Dependency direction

      Product / Application code
          |
          v
      Ankole.W3.P8ControlledAction
          |
          v
      Ankole.WorkHierarchy domain stores

  The dependency runs one way only. W2 must not reference W3, ActionAssurance,
  Capability, Approval, or ActionReceipt.

  ## A-6 establishes ownership only

  This module currently owns the route but does **not** execute it. It is
  deliberately non-operational.

  - It performs no W2 mutation.
  - It calls no W2 mutation function.
  - It does not open a transaction.
  - It does not consume a Capability.
  - It does not write an ActionReceipt.
  - It defines no actor binding.
  - It performs no Broker execution.

  A partially implemented official mutation path is forbidden, so this module
  exposes no provisional mutation entry points. No such API exists yet by
  design, and none should be added before the gates below complete the route.

  Callers must **not** interpret the existence of this module as permission to
  execute W2 mutations. Until the pipeline is complete, controlled W2 mutation
  has no production route at all, which is the correct fail-closed state.

  ## Deferred gates

  Later gates add, in dependency order:

  - A-7: transaction ordering and Capability-consumption ordering.
  - B-5 residual: production wiring of `CapabilityService.consume_locked/2`.
  - A-3: whether CONTROLLED actions require a Capability.
  - B-14: mandatory actor attribution.
  - A-8: authenticated-principal to W2 actor equality.
  - Broker: trusted execution and post-state observation.
  - Postconditions: a positive postcondition predicate language.
  """

  @doc """
  Returns whether the controlled-mutation pipeline is executable.

  Always returns `false` at this gate. A-6 establishes ownership of the
  authoritative route; it does not activate it. Later gates flip this only when
  assurance, execution, transaction, consumption, and receipt orchestration
  are all implemented.

  This function is the single machine-readable marker of the fail-closed state.
  """
  @spec ready?() :: boolean()
  def ready?, do: false
end