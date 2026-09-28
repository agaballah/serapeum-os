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
  alias Ankole.W3.RiskClassifier

  # ─── public API ──────────────────────────────────────────────────────────

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

    with {:ok, normalized_action} <- normalize_action(action),
         {:ok, normalized_resource} <- normalize_resource(resource),
         {:ok, risk_class} <- classify_risk(normalized_action, normalized_resource),
         :ok <- check_not_prohibited(risk_class),
         :ok <- check_authz(repo, company_uid, principal_uid, normalized_action, normalized_resource),
         :ok <- check_capability(repo, company_uid, capability_uid, normalized_action),
         :ok <- check_approval_requirement(risk_class, approval_uid),
          :ok <- check_approval_independence(repo, company_uid, approval_uid, principal_uid, normalized_action, normalized_resource),
         {:ok, receipt_uid} <- generate_receipt_uid() do
      {:ok, %{
        receipt_uid: receipt_uid,
        intent_action: normalized_action,
        intent_resource: normalized_resource,
        principal_uid: principal_uid,
        company_uid: company_uid,
        risk_class: risk_class,
        authz_decision: "ALLOW",
        precondition_status: "met",
        approval_uid: approval_uid,
        approval_independent: true,
        capability_uid: capability_uid,
        broker_name: nil,
        postcondition_expected: postcondition_expected
      }}
    else
      {:error, :prohibited} -> {:error, :prohibited}
      {:error, :unknown_action} -> {:error, :unknown_action}
      {:error, :authz_denied} -> {:error, :authz_denied}
      {:error, :capability_invalid} -> {:error, :capability_invalid}
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

  Returns `{:ok, receipt}` on success or `{:error, reason}` on failure.
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

  defp classify_risk(action, resource) do
    case RiskClassifier.classify(action, resource) do
      {:ok, class} -> {:ok, class}
      {:error, :unknown_action} -> {:error, :unknown_action}
    end
  end

  defp check_not_prohibited("PROHIBITED"), do: {:error, :prohibited}
  defp check_not_prohibited(_), do: :ok

  defp check_authz(repo, company_uid, principal_uid, action, resource) do
    case W3AuthZ.authorize(repo, company_uid, principal_uid, resource, action, %{}) do
      :ok -> :ok
      _ -> {:error, :authz_denied}
    end
  end

  defp check_capability(_repo, _company_uid, nil, _action), do: :ok

  defp check_capability(repo, company_uid, capability_uid, action) do
    case CapabilityService.validate_capability(repo, company_uid, capability_uid, action: action) do
      :ok -> :ok
      {:error, _} -> {:error, :capability_invalid}
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

  defp check_approval_independence(_repo, _company_uid, nil, _principal_uid, _action, _resource), do: :ok

  defp check_approval_independence(repo, company_uid, approval_uid, principal_uid, action, resource) do
    case ApprovalStore.validate_for_assurance(repo, company_uid, approval_uid, principal_uid, action, resource) do
      :ok -> :ok
      {:error, _} -> {:error, :approval_invalid}
    end
  end

  defp generate_receipt_uid() do
    seed = "#{:crypto.strong_rand_bytes(16) |> Base.encode16()}-#{System.unique_integer([:positive])}"
    {:ok, seed}
  end

  defp build_receipt_attrs(%{} = context, verified?, result_output) do
    {:ok, %{
      receipt_uid: context.receipt_uid,
      intent_action: context.intent_action,
      intent_resource: context.intent_resource,
      principal_uid: context.principal_uid,
      company_uid: context.company_uid,
      risk_class: context.risk_class,
      authz_decision: context.authz_decision,
      precondition_status: context.precondition_status,
      approval_uid: context.approval_uid,
      approval_independent: context.approval_independent,
      capability_uid: context.capability_uid,
      broker_name: context.broker_name,
      postcondition_expected: context.postcondition_expected,
      postcondition_verified: verified?,
      verified_at: DateTime.utc_now(),
      result_output: result_output,
      execution_failed: !verified?
    }}
  end

  defp save_receipt(repo, attrs) do
    %ActionReceipt{}
    |> ActionReceipt.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, receipt} -> {:ok, receipt}
      {:error, _} -> {:error, :receipt_save_failed}
    end
  end
end