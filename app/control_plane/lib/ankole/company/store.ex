defmodule Ankole.Company.Store do
  @moduledoc """
  Persistence and query operations for Company rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Domain-changing operations acquire the Company row lock inside
  that transaction. This layer performs no bootstrap/activation logic.
  """

  import Ecto.Query

  alias Ankole.Company

  @doc """
  Creates a durable Company in :created status.

  The Company is non-operational. Caller-supplied status is ignored and
  forced to :created. No owner membership, Unit, Agent, or AuthZ side
  effects are created.
  """
  @spec create_company(Ecto.Repo.t(), map()) ::
          {:ok, Company.t()} | {:error, Ecto.Changeset.t()}
  def create_company(repo, attrs) do
    attrs
    |> Map.put(:status, :created)
    |> Map.delete(:id)
    |> then(fn merged ->
      Company.changeset(%Company{}, merged)
      |> repo.insert()
    end)
  end

  @doc """
  Fetches one Company by stable UID.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_company(Ecto.Repo.t(), String.t()) :: Company.t() | nil
  def fetch_company(repo, company_uid) do
    repo.get_by(Company, uid: company_uid)
  end

  @doc """
  Updates mutable Company fields.

  Authorized mutable fields: name, display_name, metadata.
  Immutable fields (uid, owner_principal_uid, status) are rejected explicitly.
  """
  @spec update_company(Ecto.Repo.t(), String.t(), map()) ::
          {:ok, Company.t()} | {:error, term()}
  def update_company(repo, company_uid, attrs) do
    with {:ok, company} <- fetch_company_for_update(repo, company_uid),
         :ok <- reject_immutable_fields(attrs) do
      attrs
      |> Map.delete(:id)
      |> Map.delete(:uid)
      |> Map.delete(:owner_principal_uid)
      |> Map.delete(:status)
      |> then(fn filtered ->
        Company.changeset(company, filtered)
        |> repo.update()
      end)
    end
  end

  @doc """
  Transitions Company from :active to :suspended.

  Rejects all other source states including :created.
  """
  @spec suspend_company(Ecto.Repo.t(), String.t()) ::
          {:ok, Company.t()} | {:error, term()}
  def suspend_company(repo, company_uid) do
    transition_company(repo, company_uid, :suspended, [:active])
  end

  @doc """
  Transitions Company from :suspended to :active.

  Rejects all other source states including :created.
  """
  @spec reactivate_company(Ecto.Repo.t(), String.t()) ::
          {:ok, Company.t()} | {:error, term()}
  def reactivate_company(repo, company_uid) do
    transition_company(repo, company_uid, :active, [:suspended])
  end

  @doc """
  Transitions Company to :archived.

  Allowed source states: :active, :suspended.
  :archived is terminal. :created is rejected.
  """
  @spec archive_company(Ecto.Repo.t(), String.t()) ::
          {:ok, Company.t()} | {:error, term()}
  def archive_company(repo, company_uid) do
    transition_company(repo, company_uid, :archived, [:active, :suspended])
  end

  defp fetch_company_for_update(repo, company_uid) do
    case repo.one(
           from company in Company,
             where: company.uid == ^company_uid,
             lock: "FOR UPDATE"
         ) do
      %Company{} = company -> {:ok, company}
      nil -> {:error, :not_found}
    end
  end

  defp reject_immutable_fields(attrs) do
    immutable_fields = [:uid, :owner_principal_uid, :status]
    attempted = Enum.filter(immutable_fields, &Map.has_key?(attrs, &1))

    if attempted == [] do
      :ok
    else
      {:error, {:immutable_fields, attempted}}
    end
  end

  defp transition_company(repo, company_uid, target_status, allowed_source_statuses) do
    with {:ok, %Company{status: current_status} = company} <- fetch_company_for_update(repo, company_uid),
         :ok <- validate_transition(current_status, target_status, allowed_source_statuses) do
      Company.changeset(company, %{status: target_status})
      |> repo.update()
    end
  end

  defp validate_transition(current, target, allowed) do
    if current in allowed do
      :ok
    else
      {:error, {:invalid_transition, from: current, to: target}}
    end
  end
end