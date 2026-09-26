defmodule Ankole.W3.AuthZ do
  @moduledoc """
  Company-scoped authorization boundary for SerapeumOS.

  This module wraps the existing Ankole AuthZ engine with explicit Company
  context enforcement. It answers the question:

      "Is this Principal, within this Company, authorized to perform this
       action on this resource?"

  The underlying Ankole AuthZ decision engine remains authoritative for its
  existing permission evaluation. This layer adds the missing Company boundary
  that Ankole AuthZ does not natively provide.

  ## Design

  - **No schema changes** to Ankole AuthZ tables.
  - **No replacement** of the Ankole AuthZ decision engine.
  - **Fail-closed**: missing, nil, invalid, or ambiguous Company context
    produces a deny result.
  - **Cross-Company isolation**: a grant valid in Company A does not grant
    authority in Company B.

  ## Decision flow

      1. Validate Company exists.
      2. Validate Principal exists and is active.
      3. Validate Principal belongs to the Company.
      4. Delegate to Ankole.AuthZ.authorize/4.
      5. Return the decision.

  ## Integration note

  W2 ReviewRecord verdicts are NOT authorization decisions. This module
  evaluates only AuthZ grants and Company membership — it has no knowledge
  of review outcomes.
  """

  alias Ankole.AuthZ
  alias Ankole.Company.MembershipStore
  alias Ankole.Company.Store
  alias Ankole.Principals

  @type decision_result :: :ok | {:error, term()}

  @doc """
  Authorizes one exact action on one concrete resource within a Company.

  Returns `:ok` when the Principal is an active member of the Company and
  the underlying Ankole AuthZ engine permits the action. Returns an error
  tuple otherwise, including when the Company does not exist, the Principal
  does not exist or is disabled, or the Principal is not a member of the
  Company.
  """
  @spec authorize(String.t(), String.t(), String.t(), String.t(), map()) :: decision_result()
  def authorize(company_uid, principal_uid, resource, action, context \\ %{}) do
    with :ok <- validate_company(company_uid),
         :ok <- validate_principal(principal_uid),
         :ok <- validate_membership(company_uid, principal_uid),
         :ok <- AuthZ.authorize(principal_uid, resource, action, context) do
      :ok
    else
      {:error, :company_not_found} -> {:error, :company_scope_mismatch}
      {:error, :principal_not_found} -> {:error, :principal_not_found}
      {:error, :principal_disabled} -> {:error, :principal_disabled}
      {:error, :not_member} -> {:error, :company_scope_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns true when the Principal is authorized within the Company.
  """
  @spec allowed?(String.t(), String.t(), String.t(), String.t(), map()) :: boolean()
  def allowed?(company_uid, principal_uid, resource, action, context \\ %{}) do
    case authorize(company_uid, principal_uid, resource, action, context) do
      :ok -> true
      _ -> false
    end
  end

  @doc """
  Builds the explicit kernel snapshot for one authorization request, with
  Company membership pre-validation.

  Returns `:ok` only when the Principal is an active member of the Company.
  """
  @spec build_snapshot(String.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def build_snapshot(company_uid, principal_uid, resource, action, context \\ %{}) do
    with :ok <- validate_company(company_uid),
         :ok <- validate_principal(principal_uid),
         :ok <- validate_membership(company_uid, principal_uid) do
      AuthZ.build_authorization_snapshot(principal_uid, resource, action, context)
    else
      {:error, :company_not_found} -> {:error, :company_scope_mismatch}
      {:error, :principal_not_found} -> {:error, :principal_not_found}
      {:error, :principal_disabled} -> {:error, :principal_disabled}
      {:error, :not_member} -> {:error, :company_scope_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  # ─── Internal validation ────────────────────────────────────────────────

  defp validate_company(nil), do: {:error, :company_scope_mismatch}
  defp validate_company(""), do: {:error, :company_scope_mismatch}

  defp validate_company(company_uid) when is_binary(company_uid) do
    case Store.fetch_company(Ankole.Repo, company_uid) do
      %{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp validate_company(_), do: {:error, :company_scope_mismatch}

  defp validate_principal(nil), do: {:error, :principal_not_found}
  defp validate_principal(""), do: {:error, :principal_not_found}

  defp validate_principal(principal_uid) when is_binary(principal_uid) do
    case Principals.get_principal(principal_uid) do
      {:ok, %Principals.Principal{status: :active}} -> :ok
      {:ok, %Principals.Principal{status: :disabled}} -> {:error, :principal_disabled}
      {:ok, _} -> {:error, :principal_not_found}
      {:error, _} -> {:error, :principal_not_found}
    end
  end

  defp validate_principal(_), do: {:error, :principal_not_found}

  defp validate_membership(company_uid, principal_uid) do
    if MembershipStore.member?(Ankole.Repo, company_uid, principal_uid) do
      :ok
    else
      {:error, :not_member}
    end
  end
end
