defmodule Ankole.W3.CapabilityStore do
  @moduledoc """
  Persistence and Company-scoped query operations for Capability rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Every write path validates the Company boundary before touching
  the database, so a Capability cannot be created, fetched, or listed outside
  its owning Company.

  This layer performs no authorization evaluation. It does not issue
  capabilities automatically, does not process expiry or revocation, and has
  no dependency on W2 review records or any later W3 package.
  """

  import Ecto.Query

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.PrincipalKey
  alias Ankole.Principals.Principal
  alias Ankole.W3.Capability

  @doc """
  Creates one durable Capability inside the caller's Company.

  The Principal must be an active member of the Company. The issuer must be
  an active member of the Company. All three references are validated before
  the insert so a cross-Company write fails closed before any row is touched.

  `issued_at` is caller-supplied and immutable. `scope`, `constraints`, and
  `metadata` default to empty maps. `expires_at`, `revoked_at`,
  `parent_capability_uid`, and `approval_uid` are nullable.
  """
  @spec create_capability(Ecto.Repo.t(), map()) ::
          {:ok, Capability.t()} | {:error, term()}
  def create_capability(repo, attrs) do
    with {:ok, company_uid} <- fetch_attr(attrs, :company_uid),
         :ok <- ensure_company_exists(repo, company_uid),
         {:ok, principal_uid} <- fetch_normalized_principal(repo, attrs, :principal_uid),
         :ok <- ensure_member(repo, company_uid, principal_uid),
         {:ok, issuer_uid} <- fetch_normalized_principal(repo, attrs, :issued_by_principal_uid),
         :ok <- ensure_member(repo, company_uid, issuer_uid),
         {:ok, normalized_uid} <- fetch_normalized_uid(attrs),
         :ok <- ensure_unique_uid(repo, normalized_uid) do
      merged =
        attrs
        |> Map.put(:company_uid, company_uid)
        |> Map.put(:principal_uid, principal_uid)
        |> Map.put(:issued_by_principal_uid, issuer_uid)
        |> Map.put(:uid, normalized_uid)
        |> Map.put_new(:scope, %{})
        |> Map.put_new(:constraints, %{})
        |> Map.put_new(:metadata, %{})
        |> Map.delete(:id)

      %Capability{}
      |> Capability.changeset(merged)
      |> repo.insert()
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :missing_required_attribute}
    end
  end

  @doc """
  Fetches one Capability by stable UID within the caller's Company.

  A Capability belonging to another Company is not found. A missing UID is
  not found. This is the single read path for stable-identity lookup.
  """
  @spec fetch_capability(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Capability.t()} | {:error, term()}
  def fetch_capability(repo, company_uid, capability_uid) do
    with :ok <- ensure_company_exists(repo, company_uid),
         {:ok, normalized_uid} <- PrincipalKey.normalize(capability_uid) do
      case repo.one(
             from capability in Capability,
               where:
                 capability.uid == ^normalized_uid and
                   capability.company_uid == ^company_uid
           ) do
        %Capability{} = capability -> {:ok, capability}
        nil -> {:error, :not_found}
      end
    end
  end

  @doc """
  Lists the Capabilities issued to one Principal inside one Company.
  """
  @spec list_principal_capabilities(Ecto.Repo.t(), String.t(), String.t()) ::
          [Capability.t()]
  def list_principal_capabilities(repo, company_uid, principal_uid) do
    with {:ok, normalized_uid} <- PrincipalKey.normalize(principal_uid) do
      Capability
      |> where([capability], capability.company_uid == ^company_uid)
      |> where([capability], capability.principal_uid == ^normalized_uid)
      |> order_by([capability], asc: capability.inserted_at)
      |> repo.all()
    else
      {:error, _} -> []
    end
  end

  @doc """
  Lists every Capability inside one Company.
  """
  @spec list_company_capabilities(Ecto.Repo.t(), String.t()) :: [Capability.t()]
  def list_company_capabilities(repo, company_uid) do
    Capability
    |> where([capability], capability.company_uid == ^company_uid)
    |> order_by([capability], asc: capability.inserted_at)
    |> repo.all()
  end

  @doc """
  Reports whether one Capability exists inside one Company.
  """
  @spec capability?(Ecto.Repo.t(), String.t(), String.t()) :: boolean()
  def capability?(repo, company_uid, capability_uid) do
    case fetch_capability(repo, company_uid, capability_uid) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # ─── private helpers ────────────────────────────────────────────────────

  defp ensure_company_exists(repo, company_uid) do
    case repo.get_by(Company, uid: company_uid) do
      %Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp fetch_normalized_principal(repo, attrs, key) do
    with {:ok, raw} <- fetch_attr(attrs, key),
         {:ok, normalized} <- PrincipalKey.normalize(raw) do
      case repo.get(Principal, normalized) do
        %Principal{status: :active} -> {:ok, normalized}
        %Principal{status: :disabled} -> {:error, :principal_disabled}
        nil -> {:error, :principal_not_found}
      end
    end
  end

  defp ensure_member(repo, company_uid, principal_uid) do
    if MembershipStore.member?(repo, company_uid, principal_uid) do
      :ok
    else
      {:error, :principal_not_in_company}
    end
  end

  defp fetch_normalized_uid(attrs) do
    with {:ok, raw} <- fetch_attr(attrs, :uid),
         {:ok, normalized} <- PrincipalKey.normalize(raw) do
      {:ok, normalized}
    end
  end

  defp ensure_unique_uid(repo, uid) do
    case repo.get_by(Capability, uid: uid) do
      nil -> :ok
      %Capability{} -> {:error, {:duplicate, :uid}}
    end
  end

  defp fetch_attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(attrs, Atom.to_string(key))
    end
  end
end