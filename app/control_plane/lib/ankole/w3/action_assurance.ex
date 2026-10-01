defmodule Ankole.W3.ActionAssurance do
  @moduledoc """
  Action Assurance Core — the consequential action lifecycle per MA-06 §16.

  This module owns the assurance decision path from intent through
  normalized classification. It delegates risk classification to
  `RiskClassifier`, authorization to `W3AuthZ`, and capability validation
  to `CapabilityService`. Persistence to `ActionReceipt` is deferred until
  after explicit postcondition verification, per the locked lifecycle:

      INTENT → NORMALIZE → CLASSIFY → AUTHZ → PRECONDITIONS → APPROVAL
        → BROKER → VERIFICATION → RECEIPT

  The module does NOT:
  - execute actions or invoke brokers (P7)
  - create approval workflow records (P6)
  - integrate with W2 stores (P8)
  - implement scheduling or worker recovery logic

  Execution restrictions
  ----------------------
  Exact binding (B-4) proves that the `scope` and `constraints` maps passed
  here equal the Capability's stored maps. It does not prove that those maps
  restrict the operation, because the expected maps arrive as caller
  options. `RestrictionEvaluator` closes that gap and runs only after
  binding succeeds: a non-empty map would carry at least one key for which
  this system defines no predicate, so it is refused rather than ignored.

  A future recognized, state-dependent restriction cannot be decided here.
  It would have to be evaluated inside the P8 mutation transaction, after
  the relevant W2 target rows are locked and before the mutation applies,
  because the locked row is the only stable value to compare against.

  Receipt provenance
  ------------------
  `assure/7` returns a context sealed with a keyed digest over the fields the
  system established. `finalize_assurance/4` refuses any context that lacks
  a valid seal, so only a completed assurance can produce a receipt. A caller
  cannot hand-build a context and assert a decision, an Approval, or an
  outcome the system never made.

  Fields no stage establishes stay `nil`. `precondition_status` and
  `approval_independent` are `nil` unless a real check produced them, and the
  execution-stage fields remain the finalizer's assertion until B-7 supplies
  an observed value.

  Decision outcomes from `assure/6`:
  - `{:ok, assurance_context}` — chain passed; caller proceeds to broker
  - `{:error, reason}` — any stage failed; caller must not proceed

  Receipt creation only occurs via `finalize_assurance/4` after the
  caller has verified the postcondition.
  """

  import Ecto.Query

  alias Ankole.W3.ActionReceipt
  alias Ankole.W3.ApprovalStore
  alias Ankole.W3.AuthZ, as: W3AuthZ
  alias Ankole.W3.CapabilityService
  alias Ankole.W3.Resource
  alias Ankole.W3.RestrictionEvaluator
  alias Ankole.W3.RiskClassifier

  # ─── public API ──────────────────────────────────────────────────────────

  # The seal key is generated once at compile time. It is never persisted and
  # never leaves the process, so a caller cannot construct a valid seal without
  # first completing a real `assure/7` in this VM.
  @seal_key :crypto.strong_rand_bytes(32)

  # The context fields the system establishes. The seal covers exactly these,
  # so none of them can be altered between assurance and receipt. Execution
  # fields are excluded on purpose: B-7 fills those in from a real broker.
  @sealed_fields [
    :receipt_uid,
    :intent_action,
    :intent_resource,
    :principal_uid,
    :company_uid,
    :risk_class,
    :authz_decision,
    :approval_uid,
    :approval_independent,
    :capability_uid,
    :postcondition_expected
  ]

  @doc """
  Runs the Action Assurance decision chain for one proposed action.

  The caller supplies:
  - `company_uid` — the Company scope boundary
  - `principal_uid` — the requesting Principal
  - `action` — the action identifier (will be normalized)
  - `resource` — the exact resource target
  - `capability_uid` — an existing Capability to validate (nullable for
    ROUTINE actions where the architecture permits AuthZ-only paths)
  - `opts` — optional `:approval_uid`, `:postcondition_expected` map

  Returns `{:ok, assurance_context}` when the full chain passes, or
  `{:error, reason_atom}` at the first failing stage. No database
  persistence occurs during assurance.

  The returned context contains all fields needed for later receipt
  finalization. The caller must pass it unchanged to
  `finalize_assurance/4`.
  """
  @spec assure(
          Ecto.Repo.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t() | nil,
          keyword()
        ) :: {:ok, map()} | {:error, atom()}
def assure(repo, company_uid, principal_uid, action, resource, capability_uid \\ nil, opts \\ []) do
    approval_uid = Keyword.get(opts, :approval_uid)
    postcondition_expected = Keyword.get(opts, :postcondition_expected, %{})
    scope = Keyword.get(opts, :scope, %{})
    constraints = Keyword.get(opts, :constraints, %{})
    risk_context = Keyword.get(opts, :risk_context, %{})

    with {:ok, normalized_action} <- normalize_action(action),
         {:ok, normalized_resource} <- normalize_resource(resource),
         :ok <- check_resource_exact(normalized_resource),
         {:ok, risk_class} <- classify_risk(normalized_action, normalized_resource, risk_context),
         :ok <- check_not_prohibited(risk_class),
         {:ok, authz_decision} <- check_authz(repo, company_uid, principal_uid, normalized_action, normalized_resource),
         :ok <- check_capability(repo, company_uid, capability_uid, normalized_action, principal_uid, normalized_resource, risk_class, approval_uid, scope, constraints),
         :ok <- check_execution_restrictions(scope, constraints),
         :ok <- check_approval_requirement(risk_class, approval_uid),
         :ok <- check_approval_independence(repo, company_uid, approval_uid, principal_uid, normalized_action, normalized_resource, risk_class),
         {:ok, receipt_uid} <- generate_receipt_uid() do
      # `approval_independent` reports whether an Approval was actually
      # validated. Without one there is no independence to claim, so the field
      # stays nil rather than asserting `true` about a check that never ran.
      approval_independent = if is_nil(approval_uid), do: nil, else: true

      # No precondition is evaluated anywhere in W3, so nothing is claimed.
      context = %{
        receipt_uid: receipt_uid,
        intent_action: normalized_action,
        intent_resource: normalized_resource,
        principal_uid: principal_uid,
        company_uid: company_uid,
        risk_class: risk_class,
        authz_decision: authz_decision,
        precondition_status: nil,
        approval_uid: approval_uid,
        approval_independent: approval_independent,
        capability_uid: capability_uid,
        broker_name: nil,
        postcondition_expected: postcondition_expected
      }

      {:ok, Map.put(context, :seal, seal_context(context))}
    else
      {:error, :prohibited} -> {:error, :prohibited}
      {:error, :unknown_action} -> {:error, :unknown_action}
      {:error, :authz_denied} -> {:error, :authz_denied}
      {:error, :capability_invalid} -> {:error, :capability_invalid}
      {:error, :unsupported_restriction} -> {:error, :unsupported_restriction}
      {:error, :approval_required} -> {:error, :approval_required}
      {:error, :approval_invalid} -> {:error, :approval_invalid}
      {:error, :invalid_action} -> {:error, :invalid_action}
      {:error, :invalid_resource} -> {:error, :invalid_resource}
    end
  end

  @doc """
  Finalizes the assurance chain by persisting an ActionReceipt after
  postcondition verification.

  Per MA-06 §16 and P0 invariant #4, this MUST be called only after
  broker execution has completed and the postcondition has been verified.
  Creating a receipt before verification would violate the locked
  lifecycle.

  `assurance_context` must be the context returned by `assure/7`. The context
  carries a seal over the fields the system established, and this function
  refuses any context whose seal does not verify. A hand-built or edited
  context returns `{:error, :unverified_assurance_context}` and persists
  nothing, so a caller cannot assert an AuthZ decision, an Approval, or a
  Capability that no assurance produced.

  `verified?` and `result_output` remain the caller's assertion until B-7
  supplies values observed from a real broker. This function records them as
  given and timestamps `verified_at` only when `verified?` is true.

  Returns `{:ok, receipt}` on success. On failure it returns a typed reason:
  `:invalid_assurance_context`, `{:missing_context_field, field}`,
  `:unverified_assurance_context`, `:receipt_uid_conflict`,
  `:receipt_reference_invalid`, or `{:receipt_invalid, errors}`.
  """
  @spec finalize_assurance(Ecto.Repo.t(), map(), boolean(), map()) ::
          {:ok, ActionReceipt.t()} | {:error, term()}
  def finalize_assurance(repo, assurance_context, verified?, result_output \\ %{}) do
    with {:ok, attrs} <- build_receipt_attrs(assurance_context, verified?, result_output),
         {:ok, receipt} <- save_receipt(repo, attrs) do
      {:ok, receipt}
    end
  end

  @doc """
  Fetches one receipt by its stable UID.
  """
  @spec fetch_receipt(Ecto.Repo.t(), String.t()) :: ActionReceipt.t() | nil
  def fetch_receipt(repo, receipt_uid) do
    repo.get_by(ActionReceipt, receipt_uid: receipt_uid)
  end

  @doc """
  Lists receipts within one Company, ordered by creation time descending.
  """
  @spec list_company_receipts(Ecto.Repo.t(), String.t()) :: [ActionReceipt.t()]
  def list_company_receipts(repo, company_uid) do
    ActionReceipt
    |> where([r], r.company_uid == ^company_uid)
    |> order_by([r], desc: r.inserted_at)
    |> repo.all()
  end

  # ─── private helpers ────────────────────────────────────────────────────

  defp normalize_action(action) do
    case String.trim(action) do
      "" -> {:error, :invalid_action}
      a when is_binary(a) -> {:ok, String.downcase(a)}
      _ -> {:error, :invalid_action}
    end
  end

  defp normalize_resource(resource) do
    case String.trim(resource) do
      "" -> {:error, :invalid_resource}
      r when is_binary(r) -> {:ok, r}
      _ -> {:error, :invalid_resource}
    end
  end

  defp classify_risk(action, resource, context) do
    case RiskClassifier.classify(action, resource, context) do
      {:ok, class} -> {:ok, class}
      {:error, :unknown_action} -> {:error, :unknown_action}
    end
  end

  defp check_resource_exact(resource) do
    case Resource.normalize_exact(resource) do
      {:ok, normalized} ->
        if normalized == resource, do: :ok, else: {:error, :invalid_resource}
      {:error, _} ->
        {:error, :invalid_resource}
    end
  end

  defp check_not_prohibited("PROHIBITED"), do: {:error, :prohibited}
  defp check_not_prohibited(_), do: :ok

  # The recorded decision is the one the real AuthZ path returned. A denied
  # decision never reaches this stage, so the value persisted is always the
  # decision that was actually made rather than an assumed constant.
  defp check_authz(repo, company_uid, principal_uid, action, resource) do
    case W3AuthZ.authorize(repo, company_uid, principal_uid, resource, action, %{}) do
      :ok -> {:ok, authz_decision_allow()}
      _ -> {:error, :authz_denied}
    end
  end

  defp authz_decision_allow, do: "ALLOW"

  defp check_capability(_repo, _company_uid, nil, _action, _principal, _resource, _risk, _approval, _scope, _constraints), do: :ok

  defp check_capability(repo, company_uid, capability_uid, action, principal_uid, resource, risk_class, approval_uid, scope, constraints) do
    case CapabilityService.validate_capability(repo, company_uid, capability_uid, action: action, principal_uid: principal_uid, resource: resource, risk_class: risk_class, approval_uid: approval_uid, scope: scope, constraints: constraints) do
      :ok -> :ok
      {:error, _} -> {:error, :capability_invalid}
    end
  end

  defp check_execution_restrictions(scope, constraints) do
    case RestrictionEvaluator.evaluate(scope, constraints) do
      :ok -> :ok
      {:error, :unsupported_restriction} -> {:error, :unsupported_restriction}
    end
  end

  defp check_approval_requirement(risk_class, approval_uid) do
    if requires_approval?(risk_class) and is_nil(approval_uid) do
      {:error, :approval_required}
    else
      :ok
    end
  end

  defp requires_approval?("HIGH-IMPACT"), do: true
  defp requires_approval?(_), do: false

  defp check_approval_independence(_repo, _company_uid, nil, _principal_uid, _action, _resource, _risk), do: :ok

  defp check_approval_independence(repo, company_uid, approval_uid, principal_uid, action, resource, risk_class) do
    case ApprovalStore.validate_for_assurance(repo, company_uid, approval_uid, principal_uid, action, resource, risk_class) do
      :ok -> :ok
      {:error, _} -> {:error, :approval_invalid}
    end
  end

  defp generate_receipt_uid() do
    seed = "#{:crypto.strong_rand_bytes(16) |> Base.encode16()}-#{System.unique_integer([:positive])}"
    {:ok, seed}
  end

  # A keyed digest over exactly the fields the system established. The key
  # never leaves this module instance, so a seal cannot be produced outside a
  # completed assurance, and any edit to a sealed field invalidates it.
  defp seal_context(context) do
    sealed = Map.take(context, @sealed_fields)
    :crypto.mac(:hmac, :sha256, @seal_key, :erlang.term_to_binary(sealed))
  end

  defp context_sealed?(context) do
    case Map.fetch(context, :seal) do
      {:ok, seal} -> seal == seal_context(context)
      :error -> false
    end
  end

  # Safe access: a malformed or hand-built context returns a typed error
  # instead of raising. A missing field is a claim the caller cannot make, and
  # it fails closed.
  defp build_receipt_attrs(context, verified?, result_output) when is_map(context) do
    with {:ok, attrs} <- required_attrs(context),
         true <- context_sealed?(context) do
      {:ok,
       Map.merge(attrs, %{
         broker_name: Map.get(context, :broker_name),
         postcondition_verified: verified?,
         # `verified_at` must timestamp an observed verification. Claiming a
         # verification time while recording failure would misdate the event.
         verified_at: if(verified?, do: DateTime.utc_now(), else: nil),
         result_output: result_output,
         execution_failed: !verified?
       })}
    else
      false -> {:error, :unverified_assurance_context}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_receipt_attrs(_context, _verified?, _result_output), do: {:error, :invalid_assurance_context}

  defp required_attrs(context) do
    [
      :receipt_uid,
      :intent_action,
      :intent_resource,
      :principal_uid,
      :company_uid,
      :risk_class,
      :authz_decision,
      :precondition_status,
      :approval_uid,
      :approval_independent,
      :capability_uid,
      :postcondition_expected
    ]
    |> Enum.reduce_while({:ok, %{}}, fn key, {:ok, acc} ->
      case Map.fetch(context, key) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        :error -> {:halt, {:error, {:missing_context_field, key}}}
      end
    end)
  end

  # Persistence failures are typed by cause. Collapsing a duplicate identity, a
  # dangling reference, and an invalid field into one atom would hide which
  # invariant broke.
  defp save_receipt(repo, attrs) do
    %ActionReceipt{}
    |> ActionReceipt.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, receipt} ->
        {:ok, receipt}

      {:error, changeset} ->
        {:error, receipt_insert_error(changeset)}
    end
  end

  defp receipt_insert_error(changeset) do
    cond do
      duplicate_receipt?(changeset) -> :receipt_uid_conflict
      dangling_reference?(changeset) -> :receipt_reference_invalid
      true -> {:receipt_invalid, errors_on(changeset)}
    end
  end

  defp duplicate_receipt?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:receipt_uid, {_message, opts}} ->
        Keyword.get(opts, :constraint) == :unique

      _other ->
        false
    end)
  end

  defp dangling_reference?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {field, {_message, opts}}
      when field in [:principal_uid, :company_uid, :capability_uid, :approval_uid] ->
        Keyword.get(opts, :constraint) == :foreign_key

      _other ->
        false
    end)
  end

  defp errors_on(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {field, {message, _opts}} -> {field, message} end)
  end
end