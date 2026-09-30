defmodule Ankole.W3.RestrictionEvaluator do
  @moduledoc """
  Fail-closed execution gate for Capability `scope` and `constraints`.

  ## Why this module exists

  B-4 proved that the `scope` and `constraints` maps presented for assurance
  are exactly the maps the Capability was issued with. B-15 proved that a
  child Capability cannot alter them. Neither proves that those maps restrict
  the operation being authorized.

  Exact map equality alone cannot answer that question. The expected maps
  reach B-4 as caller-declared options, so a caller that replays the
  Capability's own maps satisfies the comparison without proving anything
  about the real operation. This module is the gate that closes that gap.

  ## What counts as supported today

  Only one pair of values is supported:

      scope = %{}
      constraints = %{}

  An empty pair means the operation carries no additional restriction beyond
  the controls that already govern a Capability: Company boundary, Principal
  binding, exact action, canonical Resource identity, recomputed risk class,
  AuthZ, Approval, and Capability lifecycle.

  An empty pair is not a gap in authority. Canonical Resource identity already
  binds the target of every action whose target exists. Collection actions
  (`create_task`, `create_goal`, `create_mission`) are deliberately
  represented by their Company collection Resource, and B-16 does not add a
  second, weaker copy of target identity through `scope`.

  ## What is not supported today

  Any other value. A non-empty map carries at least one key, and the
  repository defines no predicate for any key. There are zero recognized
  execution-restriction keys, so every non-empty map is uninterpretable and
  is refused rather than ignored.

  This is a deliberate fail-closed decision, not a gap that issuance papers
  over. Issuance still accepts non-empty maps, so an existing row keeps its
  provenance and remains auditable. What changes is that such a Capability
  can no longer complete assurance, because the system cannot prove what its
  restrictions require.

  Refusing is the only safe reading. Silently ignoring a key that names a
  restriction an operator believes is enforced is worse than refusing the
  operation outright, and imposing a meaning the repository never defined
  would invent an authorization contract.

  ## Deliberately not interpreted

  No key receives meaning here. The module does not special-case
  `task_uid`, `mission_uid`, `max_duration`, `target_id`, `actors`, `limits`,
  or any `allowed_*` or `max_*` name, and it defines no numeric, list,
  nested-map, prefix, or allowlist semantics. It contains no dynamic
  evaluation, no atom conversion, no caller-selected dispatch, and no
  expression language. Recognizing a key would require this module to own the
  operation field it compares against, and no such contract exists.

  ## Where a real predicate must eventually run

  Exact map equality does not establish that a restriction holds. A
  recognized restriction would have to be compared against the actual
  operation, and the operation's target row only has a stable, lockable
  value inside the transaction that mutates it.

  So any future recognized, state-dependent restriction must be evaluated
  inside the future P8 mutation transaction, after the relevant W2 target
  rows are locked and before the mutation is applied. Evaluating it earlier,
  against an unlocked or caller-supplied value, would be a time-of-check
  race rather than a restriction. This module owns no repository and takes
  no locks, so it cannot and does not perform that evaluation; it only
  refuses what it cannot yet interpret.
  """

  @typedoc """
  One execution restriction decision.

  `:ok` means the Capability carries no additional restriction. Any other
  outcome is `{:error, :unsupported_restriction}`, because the module
  interprets no key and therefore cannot prove what a non-empty map requires.
  """
  @type decision :: :ok | {:error, :unsupported_restriction}

  @doc """
  Decides whether `scope` and `constraints` carry a restriction this system
  can support at execution time.

  Returns `:ok` only when both arguments are empty maps. Every other input,
  including a non-map or a malformed value, returns
  `{:error, :unsupported_restriction}`.

  The function is pure. It performs no database access, takes no locks, and
  mutates nothing, so the caller keeps full control of transaction scope.
  """
  @spec evaluate(term(), term()) :: decision()
  def evaluate(scope, constraints) do
    if empty_map?(scope) and empty_map?(constraints) do
      :ok
    else
      {:error, :unsupported_restriction}
    end
  end

  defp empty_map?(value) when is_map(value), do: map_size(value) == 0
  defp empty_map?(_value), do: false
end