defmodule Ankole.W3.RiskClassifier do
  @moduledoc """
  Deterministic risk classification for Company-scoped actions.

  Per MA-06 §15, actions are classified by consequence, not by the
  Principal who proposes them. An Agent cannot lower the risk
  classification of its own proposed action.

  This module owns only the classification decision. It performs no
  database writes, calls no AuthZ, and integrates with no W2 store.
  Classification is pure and deterministic: the same inputs always
  produce the same output.

  ## Canonical classes (LOCKED by MA-06 §15)

  | Class | Meaning |
  |-------|---------|
  | `ROUTINE` | Low-impact, bounded, normally reversible / read-only |
  | `CONTROLLED` | State-changing but bounded and recoverable |
  | `HIGH-IMPACT` | External, destructive, security-sensitive, financially/materially consequential, or difficult to reverse |
  | `PROHIBITED` | Violates Constitution / security invariants or is not supported safely |

  ## Classification rule

  `classify/3` looks up the action in the catalog and returns the
  assigned class. If the action is unknown it returns `{:error, :unknown_action}` —
  it never silently defaults to a lower-risk class.

  ## Self-classification guard

  `validate_no_self_downgrade/5` checks that a Principal has not proposed
  a risk class lower than what the catalog assigns. An Agent may always
  propose a *higher* class (conservative choice); it may never propose a
  *lower* one.
  """

  # ─── canonical class constants ──────────────────────────────────────────

  @canonical_classes ~w(ROUTINE CONTROLLED HIGH-IMPACT PROHIBITED)

  @severity %{
    "ROUTINE" => 0,
    "CONTROLLED" => 1,
    "HIGH-IMPACT" => 2,
    "PROHIBITED" => 3
  }

  # ─── action catalog (W3-P0 lock report §7 minimal mapping) ──────────────
  # Extensible: add entries here as new operations are classified.

  @catalog %{
    # Read/list operations — ROUTINE
    {"list_company_tasks", nil} => "ROUTINE",
    {"list_mission_tasks", nil} => "ROUTINE",
    {"list_dependencies", nil} => "ROUTINE",
    {"list_children", nil} => "ROUTINE",
    {"fetch_delegation", nil} => "ROUTINE",
    {"fetch_result", nil} => "ROUTINE",
    {"fetch_current_result", nil} => "ROUTINE",
    {"list_task_results", nil} => "ROUTINE",
    {"list_company_results", nil} => "ROUTINE",
    {"fetch_review", nil} => "ROUTINE",
    {"list_task_reviews", nil} => "ROUTINE",
    {"list_result_reviews", nil} => "ROUTINE",
    {"validate_assignment_eligibility", nil} => "ROUTINE",
    # Task creation — CONTROLLED
    {"create_task", nil} => "CONTROLLED",
    # Task transitions — non-terminal = CONTROLLED
    {"transition_task", "PROPOSED"} => "CONTROLLED",
    {"transition_task", "IN_PROGRESS"} => "CONTROLLED",
    {"transition_task", "BLOCKED"} => "CONTROLLED",
    # Task cancellation / failure — HIGH-IMPACT
    {"cancel_task", nil} => "HIGH-IMPACT",
    {"fail_task", nil} => "HIGH-IMPACT",
    # Agent assignment — HIGH-IMPACT (changes accountability)
    {"assign_agent", nil} => "HIGH-IMPACT",
    # Result creation — CONTROLLED
    {"create_result", nil} => "CONTROLLED",
    # Review invalidation — CONTROLLED
    {"invalidate_review", nil} => "CONTROLLED",
    # Dependencies — CONTROLLED
    {"set_dependency", nil} => "CONTROLLED",
    {"remove_dependency", nil} => "CONTROLLED",
    # Child task / delegation — CONTROLLED
    {"create_child_task", nil} => "CONTROLLED",
    {"create_delegation", nil} => "CONTROLLED",
    # Child policy change — HIGH-IMPACT (affects all children)
    {"set_child_policy", nil} => "HIGH-IMPACT"
  }

  # ─── public API ─────────────────────────────────────────────────────────

  @doc """
  Returns the four canonical risk classes in ascending severity order.
  """
  @spec canonical_classes() :: [String.t()]
  def canonical_classes, do: @canonical_classes

  @doc """
  Returns true when `class` is one of the four canonical risk classes.
  """
  @spec valid_class?(String.t()) :: boolean()
  def valid_class?(class) do
    class in @canonical_classes
  end

  @doc """
  Classifies an action into one of the four canonical risk classes.

  Classification is determined solely by the action (and optionally
  resource and context). The Principal requesting classification does
  not influence the result — classification is by consequence, not by
  requester.

  Known actions return `{:ok, class}`. Unknown actions return
  `{:error, :unknown_action}` so that the caller can decide how to
  proceed (typically deny). No silent fallback to a lower-risk class.
  """
  @spec classify(String.t(), String.t() | nil, map()) ::
          {:ok, String.t()} | {:error, atom()}
  def classify(action, resource \\ nil, _context \\ %{}) do
    case Map.get(@catalog, {action, resource}) || Map.get(@catalog, action) do
      nil -> {:error, :unknown_action}
      class when class in @canonical_classes -> {:ok, class}
    end
  end

  @doc """
  Returns true when the given action is classified as PROHIBITED.

  Prohibited actions are always denied regardless of AuthZ decision,
  approval status, or capability validity.
  """
  @spec prohibited?(String.t(), String.t() | nil, map()) :: boolean()
  def prohibited?(action, resource \\ nil, context \\ %{}) do
    case classify(action, resource, context) do
      {:ok, "PROHIBITED"} -> true
      _ -> false
    end
  end

  @doc """
  Validates that a Principal has not proposed a risk class lower than
  what the catalog assigns for the same action.

  Per MA-06 §15, an Agent cannot lower the risk classification of its
  own proposed action. This function allows the caller to enforce that
  invariant before issuing a Capability or proceeding through
  Action Assurance.

  Returns `:ok` when the proposed class is equal to or higher (more
  restrictive) than the catalog class. Returns `{:error, :self_downgrade}`
  when the proposed class is lower. Returns `{:error, :unknown_action}`
  when the catalog has no entry for the action.

  A proposed class outside the canonical set is rejected with
  `{:error, :invalid_proposed_class}`.
  """
  @spec validate_no_self_downgrade(String.t(), String.t(), String.t() | nil, map()) ::
          :ok | {:error, atom()}
  def validate_no_self_downgrade(_proposed_by, proposed_class, action, resource \\ nil, context \\ %{}) do
    unless valid_class?(proposed_class) do
      {:error, :invalid_proposed_class}
    else
      with {:ok, catalog_class} <- classify(action, resource, context) do
        if @severity[proposed_class] >= @severity[catalog_class] do
          :ok
        else
          {:error, :self_downgrade}
        end
      end
    end
  end

  @doc """
  Compares two canonical risk classes and returns the more severe one.
  Useful for attenuation: a delegated capability must not exceed the
  parent's effective authority, which includes its risk class.
  """
  @spec max_severity(String.t(), String.t()) :: String.t()
  def max_severity(a, b) do
    case {@severity[a], @severity[b]} do
      {nil, _} -> b
      {_, nil} -> a
      {sa, sb} when sa >= sb -> a
      _ -> b
    end
  end
end