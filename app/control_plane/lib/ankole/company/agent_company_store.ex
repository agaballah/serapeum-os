defmodule Ankole.Company.AgentCompanyStore do
  @moduledoc """
  Orchestrates Agent-to-Company binding.

  Composes MembershipStore.add_member/3 with Agent-specific preconditions:
  - Company must exist and be :active
  - Principal must exist and be type :agent
  - Agent owner_principal_uid must equal Company owner_principal_uid
  """

  import Ecto.Query

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Agent
  alias Ankole.Principals.Principal

  @doc """
  Binds an existing Agent Principal to exactly one active Company.

  Returns {:ok, Membership.t()} or {:error, term()}.
  """
  @spec bind_agent_to_company(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Ankole.Company.Membership.t()} | {:error, term()}
  def bind_agent_to_company(repo, agent_uid, company_uid) do
    repo.transact(fn tx_repo ->
      do_bind_agent_to_company(tx_repo, agent_uid, company_uid)
    end)
  end

  @doc """
  Binds an existing Agent Principal to exactly one active Company within a
  caller-owned transaction.

  Use this variant when composing multiple operations (e.g. Agent creation +
  Company binding + Mission assignment) inside a single `Repo.transact` callback.
  """
  @spec bind_agent_to_company_in_tx(Ecto.Repo.t(), String.t(), String.t()) ::
          {:ok, Ankole.Company.Membership.t()} | {:error, term()}
  def bind_agent_to_company_in_tx(repo, agent_uid, company_uid) do
    do_bind_agent_to_company(repo, agent_uid, company_uid)
  end

  defp do_bind_agent_to_company(repo, agent_uid, company_uid) do
    with {:ok, company} <- fetch_company_for_update(repo, company_uid),
         :ok <- validate_company_active(company),
         {:ok, agent_principal} <- fetch_principal_for_update(repo, agent_uid),
         :ok <- validate_agent_type(agent_principal),
         {:ok, agent} <- fetch_agent(repo, agent_principal.uid),
         :ok <- validate_owner_alignment(agent, company),
         {:ok, membership} <- MembershipStore.add_member(repo, company_uid, agent_principal.uid) do
      {:ok, membership}
    end
  end

  defp fetch_company_for_update(repo, company_uid) do
    case repo.one(
           from company in Company,
             where: company.uid == ^company_uid,
             lock: "FOR UPDATE"
         ) do
      %Company{} = company -> {:ok, company}
      nil -> {:error, :company_not_found}
    end
  end

  defp validate_company_active(%Company{status: :active}), do: :ok
  defp validate_company_active(%Company{status: status}), do: {:error, {:company_not_active, status}}

  defp fetch_principal_for_update(repo, principal_uid) do
    with {:ok, normalized_uid} <- Ankole.Principals.normalize_uid(principal_uid) do
      case repo.one(
             from principal in Principal,
               where: principal.uid == ^normalized_uid,
               lock: "FOR UPDATE"
           ) do
        %Principal{} = principal -> {:ok, principal}
        nil -> {:error, :not_found}
      end
    end
  end

  defp validate_agent_type(%Principal{type: :agent}), do: :ok
  defp validate_agent_type(%Principal{type: type}), do: {:error, {:principal_not_agent, type}}

  defp fetch_agent(repo, principal_uid) do
    case repo.get(Agent, principal_uid) do
      %Agent{} = agent -> {:ok, agent}
      nil -> {:error, :not_found}
    end
  end

  defp validate_owner_alignment(%Agent{owner_principal_uid: agent_owner}, %Company{owner_principal_uid: company_owner}) do
    if agent_owner == company_owner do
      :ok
    else
      {:error, :agent_owner_company_owner_mismatch}
    end
  end
end
