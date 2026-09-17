defmodule Ankole.Company.OrganizationalUnitStore do
  @moduledoc """
  Persistence and query operations for Organizational Unit rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. COMPANY-004 is create-only with respect to hierarchy topology:
  `parent_unit_uid` is established at creation and is never mutated.
  """

  import Ecto.Query

  alias Ankole.Company
  alias Ankole.Company.OrganizationalUnit

  @doc """
  Creates one Organizational Unit under a Company.

  The `company_uid` argument is authoritative. A conflicting `company_uid`
  inside `attrs` is ignored.
  """
  @spec create_unit(Ecto.Repo.t(), String.t(), map()) ::
          {:ok, OrganizationalUnit.t()} | {:error, term()}
  def create_unit(repo, company_uid, attrs) do
    with :ok <- ensure_company_exists(repo, company_uid),
         :ok <- validate_hierarchy(repo, company_uid, attrs) do
      attrs
      |> Map.put(:company_uid, company_uid)
      |> Map.delete(:id)
      |> then(fn merged ->
        OrganizationalUnit.changeset(%OrganizationalUnit{}, merged)
        |> repo.insert()
      end)
    end
  end

  @doc """
  Fetches one Organizational Unit by stable UID.
  """
  @spec fetch_unit(Ecto.Repo.t(), String.t()) :: OrganizationalUnit.t() | nil
  def fetch_unit(repo, unit_uid) do
    case normalize_uid(unit_uid) do
      {:ok, uid} -> repo.get_by(OrganizationalUnit, uid: uid)
      {:error, _} -> nil
    end
  end

  @doc """
  Lists all Organizational Units belonging to one Company.
  """
  @spec list_company_units(Ecto.Repo.t(), String.t()) :: [OrganizationalUnit.t()]
  def list_company_units(repo, company_uid) do
    OrganizationalUnit
    |> where([unit], unit.company_uid == ^company_uid)
    |> repo.all()
  end

  @doc """
  Lists the direct children of one Organizational Unit.
  """
  @spec list_children(Ecto.Repo.t(), String.t()) :: [OrganizationalUnit.t()]
  def list_children(repo, unit_uid) do
    case normalize_uid(unit_uid) do
      {:ok, uid} ->
        OrganizationalUnit
        |> where([unit], unit.parent_unit_uid == ^uid)
        |> repo.all()

      {:error, _} ->
        []
    end
  end

  defp ensure_company_exists(repo, company_uid) do
    case repo.get_by(Company, uid: company_uid) do
      %Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp validate_hierarchy(repo, company_uid, attrs) do
    case Map.get(attrs, :parent_unit_uid) do
      nil ->
        :ok

      parent_uid ->
        with {:ok, normalized_parent} <- normalize_uid(parent_uid),
             {:ok, new_uid} <- normalize_uid(Map.get(attrs, :uid)) do
          if normalized_parent == new_uid do
            {:error, :self_parent_rejected}
          else
            case repo.get_by(OrganizationalUnit, uid: normalized_parent) do
              nil ->
                {:error, :parent_not_found}

              %OrganizationalUnit{company_uid: parent_company} ->
                if parent_company != company_uid do
                  {:error, :parent_company_mismatch}
                else
                  :ok
                end
            end
          end
        end
    end
  end

  defp normalize_uid(value) do
    case value do
      uid when is_binary(uid) ->
        normalized = String.trim(uid)
        if normalized == "", do: {:error, :blank_uid}, else: {:ok, normalized}

      _ ->
        {:error, :invalid_uid}
    end
  end
end
