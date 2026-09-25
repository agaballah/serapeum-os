defmodule Ankole.WorkHierarchy.MissionStore do
  @moduledoc """
  Persistence and query operations for Mission identity and revision rows.

  Functions take the `repo` of the surrounding `Ankole.Repo.transact/2`
  callback. Domain-changing operations acquire the Mission identity row lock
  inside that transaction and validate creator eligibility against the target
  Company. This layer performs no authorization checks beyond structural
  integrity.
  """

  import Ecto.Query

  alias Ankole.Principals
  alias Ankole.Principals.Principal
  alias Ankole.Principals.Agent
  alias Ankole.Company.Membership
  alias Ankole.WorkHierarchy.Mission
  alias Ankole.WorkHierarchy.MissionRevision

  @doc """
  Creates the first revision of a new Mission identity.

  `company_uid` is authoritative; any `company_uid` in `attrs` is ignored.
  The creator Principal is locked and validated before insert.
  """
  @spec create_mission(Ecto.Repo.t(), String.t(), map()) ::
          {:ok, {Mission.t(), MissionRevision.t()}} | {:error, term()}
  def create_mission(repo, company_uid, attrs) do
    attrs =
      attrs
      |> Map.delete(:id)
      |> Map.put(:company_uid, company_uid)

    with :ok <- validate_company_exists(repo, company_uid),
         {:ok, creator_uid} <- normalize_creator_uid(attrs[:creator_principal_uid]),
         {:ok, locked_creator} <- fetch_creator_for_update(repo, creator_uid),
         :ok <- validate_creator_eligible(repo, locked_creator, company_uid),
         {:ok, mission} <- insert_mission_identity(repo, company_uid, attrs, locked_creator),
         {:ok, revision} <- insert_first_revision(repo, mission.uid, attrs, locked_creator),
         :ok <- project_agent_mission_if_applicable(repo, revision) do
      {:ok, {mission, revision}}
    end
  end

  @doc """
  Fetches one Mission identity by stable UID within a Company.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_mission(Ecto.Repo.t(), String.t(), String.t()) :: Mission.t() | nil
  def fetch_mission(repo, company_uid, mission_uid) do
    repo.one(
      from m in Mission,
        where: m.company_uid == ^company_uid and m.uid == ^mission_uid
    )
  end

  @doc """
  Fetches the current revision for one Mission.

  Read-only lookup. No transaction or lock required.
  """
  @spec fetch_current_revision(Ecto.Repo.t(), String.t(), String.t()) ::
          MissionRevision.t() | nil
  def fetch_current_revision(repo, _company_uid, mission_uid) do
    repo.one(
      from r in MissionRevision,
        where: r.mission_uid == ^mission_uid and r.current_revision == true
    )
  end

  @doc """
  Lists all revisions for one Mission, ordered by revision number.

  Read-only query. No transaction or lock required.
  """
  @spec list_mission_revisions(Ecto.Repo.t(), String.t(), String.t()) :: [MissionRevision.t()]
  def list_mission_revisions(repo, _company_uid, mission_uid) do
    repo.all(
      from r in MissionRevision,
        where: r.mission_uid == ^mission_uid,
        order_by: [asc: r.revision_number]
    )
  end

  @doc """
  Creates a new revision for an existing Mission.

  Flips the previous current revision to false and inserts a new row as
  current. Returns the new revision only.
  """
  @spec create_revision(Ecto.Repo.t(), String.t(), String.t(), map()) ::
          {:ok, MissionRevision.t()} | {:error, term()}
  def create_revision(repo, company_uid, mission_uid, attrs) do
    with :ok <- validate_mission_exists(repo, company_uid, mission_uid),
          :ok <- acquire_mission_advisory_lock(repo, mission_uid),
          {:ok, mission} <- fetch_mission_for_update(repo, mission_uid),
          {:ok, creator_uid} <- normalize_creator_uid(attrs[:creator_principal_uid]),
          {:ok, locked_creator} <- fetch_creator_for_update(repo, creator_uid),
          :ok <- validate_creator_eligible(repo, locked_creator, company_uid),
          {:ok, next_number} <- compute_next_revision_number(repo, mission.uid),
          :ok <- demote_previous_current(repo, mission.uid),
          {:ok, revision} <- insert_revision(repo, mission_uid, attrs, locked_creator, next_number),
          :ok <- project_agent_mission_if_applicable(repo, revision) do
      {:ok, revision}
    end
  end

  @doc """
  Lists current Mission identities for one Company.

  Read-only query. No transaction or lock required.
  """
  @spec list_company_missions(Ecto.Repo.t(), String.t()) :: [Mission.t()]
  def list_company_missions(repo, company_uid) do
    repo.all(
      from m in Mission,
        where: m.company_uid == ^company_uid,
        order_by: [asc: m.uid]
    )
  end

  # ─── Validation helpers ───────────────────────────────────────────────────

  defp validate_company_exists(repo, company_uid) do
    case repo.get_by(Ankole.Company, uid: company_uid) do
      %Ankole.Company{} -> :ok
      nil -> {:error, :company_not_found}
    end
  end

  defp validate_mission_exists(repo, company_uid, mission_uid) do
    case repo.one(
           from m in Mission,
             where: m.company_uid == ^company_uid and m.uid == ^mission_uid,
             limit: 1
         ) do
      %Mission{} -> :ok
      nil -> {:error, :mission_not_found}
    end
  end

  defp normalize_creator_uid(uid) do
    Principals.normalize_uid(uid)
  end

  defp fetch_creator_for_update(repo, creator_uid) do
    case repo.one(
           from principal in Principal,
             where: principal.uid == ^creator_uid,
             lock: "FOR UPDATE"
         ) do
      %Principal{} = principal -> {:ok, principal}
      nil -> {:error, :creator_not_found}
    end
  end

  defp fetch_mission_for_update(repo, mission_uid) do
    case repo.one(
           from m in Mission,
             where: m.uid == ^mission_uid,
             lock: "FOR UPDATE"
         ) do
      %Mission{} = mission -> {:ok, mission}
      nil -> {:error, :mission_not_found}
    end
  end

  defp acquire_mission_advisory_lock(repo, mission_uid) do
    key = :erlang.crc32("mission:#{mission_uid}")

    case Ecto.Adapters.SQL.query(repo, "SELECT pg_advisory_xact_lock($1::bigint)", [key]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_creator_eligible(repo, %Principal{type: :human} = creator, company_uid) do
    with :ok <- validate_active(creator),
         :ok <- validate_member(repo, creator.uid, company_uid) do
      :ok
    end
  end

  defp validate_creator_eligible(repo, %Principal{type: :agent} = creator, company_uid) do
    with :ok <- validate_active(creator),
         :ok <- validate_agent_subtype_exists(repo, creator.uid),
         :ok <- validate_agent_company_membership(repo, creator.uid, company_uid) do
      :ok
    end
  end

  defp validate_creator_eligible(_repo, %Principal{type: :system} = creator, _company_uid) do
    validate_active(creator)
  end

  defp validate_creator_eligible(_repo, %Principal{type: type}, _company_uid) do
    {:error, {:invalid_creator_type, type}}
  end

  defp validate_active(%Principal{status: :active}), do: :ok
  defp validate_active(%Principal{status: status}), do: {:error, {:creator_not_active, status}}

  defp validate_member(repo, principal_uid, company_uid) do
    case repo.one(
           from m in Membership,
             where: m.company_uid == ^company_uid and m.principal_uid == ^principal_uid
         ) do
      %Membership{} -> :ok
      nil -> {:error, :creator_not_member}
    end
  end

  defp validate_agent_subtype_exists(repo, agent_uid) do
    case repo.get(Agent, agent_uid) do
      %Agent{} -> :ok
      nil -> {:error, :agent_subtype_missing}
    end
  end

  defp validate_agent_company_membership(repo, agent_uid, company_uid) do
    memberships =
      repo.all(
        from m in Membership,
          where: m.principal_uid == ^agent_uid
      )

    case memberships do
      [] -> {:error, :agent_not_in_company}
      [%{company_uid: ^company_uid}] -> :ok
      [_other] -> {:error, :agent_already_in_company}
      _corrupt -> {:error, :agent_membership_invariant_violation}
    end
  end

  # ─── Insert helpers ───────────────────────────────────────────────────────

  defp insert_mission_identity(repo, company_uid, attrs, creator) do
    mission_attrs =
      attrs
      |> Map.take([:uid])
      |> Map.put(:company_uid, company_uid)
      |> Map.put(:creator_principal_uid, creator.uid)

    %Mission{}
    |> Mission.changeset(mission_attrs)
    |> repo.insert()
  end

  defp insert_first_revision(repo, mission_uid, attrs, creator) do
    revision_attrs = build_revision_attrs(attrs, mission_uid, creator.uid, 1, true)

    %MissionRevision{}
    |> MissionRevision.changeset(revision_attrs)
    |> repo.insert()
  end

  defp compute_next_revision_number(repo, mission_uid) do
    query = from r in MissionRevision, where: r.mission_uid == ^mission_uid
    max_version = repo.aggregate(query, :max, :revision_number)
    next = if is_nil(max_version), do: 1, else: max_version + 1
    {:ok, next}
  end

  defp demote_previous_current(repo, mission_uid) do
    MissionRevision
    |> where([r], r.mission_uid == ^mission_uid and r.current_revision == true)
    |> repo.update_all(set: [current_revision: false])

    :ok
  end

  defp insert_revision(repo, mission_uid, attrs, creator, revision_number) do
    revision_attrs = build_revision_attrs(attrs, mission_uid, creator.uid, revision_number, true)

    result =
      %MissionRevision{}
      |> MissionRevision.changeset(revision_attrs)
      |> repo.insert()

    case result do
      {:error, %Ecto.Changeset{errors: errors}} ->
        if Enum.any?(errors, fn {_, {msg, _}} -> msg =~ "already been taken" end) do
          {:error, :revision_conflict}
        else
          {:error, result}
        end

      other ->
        other
    end
  end

  defp build_revision_attrs(attrs, mission_uid, creator_uid, revision_number, current) do
    attrs
    |> Map.delete(:id)
    |> Map.put(:mission_uid, mission_uid)
    |> Map.put(:revision_number, revision_number)
    |> Map.put(:current_revision, current)
    |> Map.put(:creator_principal_uid, creator_uid)
    |> maybe_compute_content_hash()
  end

  defp maybe_compute_content_hash(attrs) do
    case Map.fetch(attrs, :content) do
      {:ok, content} when is_binary(content) ->
        Map.put(attrs, :content_hash, Ankole.AIAgent.Library.SourceReader.hash(content))

      _ ->
        attrs
    end
  end

  defp project_agent_mission_if_applicable(repo, %MissionRevision{assigned_agent_uid: agent_uid, content: content}) do
    if is_binary(agent_uid) do
      Ankole.AIAgent.Library.update_mission_projection_in_tx(repo, agent_uid, content)
    end

    :ok
  end

  defp project_agent_mission_if_applicable(_repo, _revision), do: :ok
end
