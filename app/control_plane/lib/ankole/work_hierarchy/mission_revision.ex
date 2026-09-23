defmodule Ankole.WorkHierarchy.MissionRevision do
  @moduledoc """
  Immutable historical revision of a Mission mandate.

  Each row records one version of a Mission's authoritative content, its
  creator, and its current-target binding. Historical revisions are never
  modified after commit. The current effective revision carries
  `current_revision = true`; at most one exists per Mission identity and
  per Agent at any time.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ankole.Ecto.Changeset, only: [normalize_blank: 2]

  alias Ankole.Principals.Principal
  alias Ankole.WorkHierarchy.Mission
  alias Ankole.WorkHierarchy.Goal
  alias Ankole.Company.OrganizationalUnit

  @primary_key {:id, Ankole.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime_usec]

  schema "mission_revisions" do
    field :revision_number, :integer
    field :current_revision, :boolean
    field :content, :string
    field :content_hash, :string

    belongs_to :mission, Mission,
      foreign_key: :mission_uid,
      references: :uid,
      type: :string

    belongs_to :goal, Goal,
      foreign_key: :goal_uid,
      references: :uid,
      type: :string

    belongs_to :assigned_agent, Principal,
      foreign_key: :assigned_agent_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    belongs_to :unit, OrganizationalUnit,
      foreign_key: :organizational_unit_uid,
      references: :uid,
      type: :string

    belongs_to :creator, Principal,
      foreign_key: :creator_principal_uid,
      references: :uid,
      type: Ankole.Ecto.PrincipalKey

    timestamps()
  end

  @doc """
  Builds a changeset for MissionRevision rows.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [
      :mission_uid,
      :revision_number,
      :current_revision,
      :goal_uid,
      :assigned_agent_uid,
      :organizational_unit_uid,
      :creator_principal_uid,
      :content,
      :content_hash
    ])
    |> normalize_blank([:content])
    |> validate_required([
      :mission_uid,
      :revision_number,
      :current_revision,
      :creator_principal_uid,
      :content,
      :content_hash
    ])
    |> validate_number(:revision_number, greater_than_or_equal_to: 1)
    |> check_constraint(:content, name: :mission_revisions_content_present)
    |> xor_target_constraint()
    |> unique_constraint(:mission_uid_version, name: :mission_revisions_uid_version_index)
    |> unique_constraint(:mission_uid_current, name: :mission_revisions_one_current_per_mission)
    |> unique_constraint(:agent_uid_current,
      name: :mission_revisions_one_current_per_agent
    )
    |> foreign_key_constraint(:mission_uid)
    |> foreign_key_constraint(:goal_uid)
    |> foreign_key_constraint(:assigned_agent_uid)
    |> foreign_key_constraint(:organizational_unit_uid)
    |> foreign_key_constraint(:creator_principal_uid)
  end

  defp xor_target_constraint(changeset) do
    agent = get_field(changeset, :assigned_agent_uid)
    unit = get_field(changeset, :organizational_unit_uid)

    cond do
      is_nil(agent) and is_nil(unit) ->
        add_error(changeset, :target, "must target exactly one of Agent or Organizational Unit")

      not is_nil(agent) and not is_nil(unit) ->
        add_error(changeset, :target, "must target exactly one of Agent or Organizational Unit")

      true ->
        changeset
    end
  end
end
