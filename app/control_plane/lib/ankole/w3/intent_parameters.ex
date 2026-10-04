defmodule Ankole.W3.IntentParameters do
  @moduledoc """
  Canonical intent fingerprint for one assured action.

  ## What this module owns

  This module is the only place that decides which caller-controlled values
  describe a mutation, how each one is normalized into its effective form, and
  what bytes those effective values hash to. `Ankole.W3.ActionAssurance` calls
  it and seals the result, so no caller can present a digest it computed itself.

  ## The fingerprint

      preimage   = {domain_separator, schema_version, action, canonical_fields}
      serialized = :erlang.term_to_binary(preimage, [:deterministic])
      digest     = :crypto.hash(:sha256, serialized)
      persisted  = "v" <> Integer.to_string(schema_version) <> ":" <> lowercase_hex(digest)

  The canonical field list is sorted by key, so map iteration order never
  reaches the digest. Every value is type-tagged, so the string `"1"` and the
  integer `1` cannot produce the same preimage.

  ## What the fingerprint binds

  Every action binds its Company scope, every positional resource or target
  identifier, and every caller-controlled non-actor value. A Company UID or a
  Task UID that also appears inside `intent_resource` is still bound here:
  the resource string is one opaque rendering of the target, and this module
  exists so that the effective values behind it cannot change without changing
  the fingerprint.

  ## Effective intent, not request syntax

  The fingerprint binds the mutation the W2 store will actually apply, so each
  field declares how absence, `nil`, and the empty string relate for that one
  store function. There is no global rule, because W2 has no global rule:

  - An **insert** casts through `Ecto.Changeset`, which replaces an empty
    string with the schema default and drops a `nil` that equals the current
    value. So on an insert an absent key, `nil`, and `""` converge, and a
    field with a schema default receives that default.
  - A **direct put** (`Ecto.Changeset.put_change/3` in the Task transition
    path, `put_change_if_set` in the dependency path) bypasses that filtering,
    so `""` stays a real, distinct value there and `nil` means "leave alone".
  - A **required** field fails `Ecto.Changeset.validate_required/3` on `nil`
    and on `""`, because the changeset's empty values are `[""]`.
  - A field with a **deterministic default** resolves an absent key to that
    default, so absence and the default share one canonical value.
  - A field **derived from live state** that no pre-assurance reader can see
    canonicalizes to a typed sentinel naming the source, never to a fabricated
    value.

  One deliberate narrowing: a blank string is refused for every enumerated
  field, even where a store would substitute that column's schema default for
  one. A blank is not one of the declared values, and refusing it fails closed
  with a named reason instead of quietly recording a value the caller did not
  choose. This only ever rejects; it never conflates two inputs.

  A field written straight to the row is exempt from that rule, because there a
  blank really is stored as given and so really is a distinct value.

  ## Generated values

  A value the server creates after assurance, such as a generated review UID or
  a generated delegation UID, does not exist when this module runs. It is
  represented by a typed sentinel. A value the caller does supply is ordinary
  caller intent and is bound like any other value.

  ## Actor fields

  A genuine actor field names the Principal whose authority is being exercised.
  A-8 owns the equality between that field and the authenticated principal, so
  this module recognizes the field and excludes it from the fingerprint; it
  neither requires the field nor compares it, because that decision is A-8's.
  Every other Principal-valued field — an accountable Agent, a delegatee, a
  cancellation claimant, an executor — is ordinary caller-controlled data and
  is bound.

  ## Errors

  Every failure is `{:error, {:intent_parameters, reason}}`. Unknown keys,
  missing keys, malformed values, unsupported types, and metadata key
  collisions all fail closed. Nothing is silently dropped and nothing is
  silently overwritten.
  """

  alias Ankole.PrincipalKey

  @schema_version 1
  @domain_separator "serapeumos.p8.intent.v1"
  @hash_pattern ~r/^v[1-9][0-9]*:[0-9a-f]{64}$/

  @task_statuses ~w(PROPOSED READY ASSIGNED IN_PROGRESS WAITING REVIEW COMPLETED FAILED CANCELLED)
  @origin_kinds ~w(OWNER_REQUEST COMPANY_GOAL MISSION DELEGATION WORKFLOW SYSTEM_EVOLUTION EXTERNAL_EVENT)
  @child_policies ~w(ALL_COMPLETED INDEPENDENT)
  @verdicts ~w(APPROVED CHANGES_REQUIRED REJECTED INCONCLUSIVE)
  @dependency_types ~w(REQUIRES_COMPLETION REQUIRES_RESULT OPTIONAL)

  @typedoc """
  One sealed canonical intent.
  """
  defstruct [:action, :schema_version, :params_hash, :canonical_fields]

  @type t :: %__MODULE__{
          action: String.t(),
          schema_version: pos_integer(),
          params_hash: String.t(),
          canonical_fields: [canonical_field()]
        }

  @typedoc """
  One canonical field, as `{key, tagged_value}`.
  """
  @type canonical_field :: {binary(), tuple()}

  # ─── public API ──────────────────────────────────────────────────────────

  @doc """
  Returns the intent schema version this module produces.
  """
  @spec schema_version() :: pos_integer()
  def schema_version, do: @schema_version

  @doc """
  Returns the fixed domain separator mixed into every preimage.
  """
  @spec domain_separator() :: String.t()
  def domain_separator, do: @domain_separator

  @doc """
  Returns the regular expression every persisted fingerprint must match.
  """
  @spec hash_pattern() :: Regex.t()
  def hash_pattern, do: @hash_pattern

  @doc """
  Returns every action this module has a schema for, mutations and reads.
  """
  @spec actions() :: [String.t()]
  def actions, do: Map.keys(all_schemas())

  @doc """
  Returns every catalogued ROUTINE action with a schema.
  """
  @spec routine_actions() :: [String.t()]
  def routine_actions, do: Map.keys(routine_schemas())

  @doc """
  Returns the recognized actor keys for one action.

  Actor keys are declared input, so they are accepted, but they are excluded
  from the fingerprint. A-8 owns their equality with the authenticated
  principal.
  """
  @spec actor_keys(String.t()) :: {:ok, [atom()]} | {:error, term()}
  def actor_keys(action) when is_binary(action) do
    case Map.fetch(all_schemas(), action) do
      {:ok, schema} -> {:ok, schema.actors}
      :error -> {:error, {:intent_parameters, :unknown_action}}
    end
  end

  def actor_keys(_action), do: {:error, {:intent_parameters, :unknown_action}}

  @doc """
  Returns every declared key for one action, actors included.
  """
  @spec declared_keys(String.t()) :: {:ok, [atom()]} | {:error, term()}
  def declared_keys(action) when is_binary(action) do
    case Map.fetch(all_schemas(), action) do
      {:ok, schema} -> {:ok, schema.keys}
      :error -> {:error, {:intent_parameters, :unknown_action}}
    end
  end

  def declared_keys(_action), do: {:error, {:intent_parameters, :unknown_action}}

  @doc """
  Builds the canonical intent for one action from its complete input.

  `input` carries every argument the action declares, including actor fields.
  The caller supplies no subset and no digest: this function decides both what
  is hashed and what the hash is.

  Returns `{:ok, intent}` or `{:error, {:intent_parameters, reason}}`.
  """
  @spec build(String.t(), map()) :: {:ok, t()} | {:error, term()}
  def build(action, input) when is_binary(action) and is_map(input) do
    with {:ok, schema} <- fetch_schema(action),
         :ok <- check_keys(schema, input),
         {:ok, fields} <- canonical_fields(schema, input) do
      {:ok,
       %__MODULE__{
         action: action,
         schema_version: @schema_version,
         params_hash: fingerprint(action, fields),
         canonical_fields: fields
       }}
    end
  end

  def build(_action, _input), do: {:error, {:intent_parameters, :unknown_action}}

  @doc """
  Computes the persisted fingerprint for one action and canonical field list.
  """
  @spec fingerprint(String.t(), [canonical_field()]) :: String.t()
  def fingerprint(action, fields) when is_binary(action) and is_list(fields) do
    serialized =
      {@domain_separator, @schema_version, action, fields}
      |> :erlang.term_to_binary([:deterministic])

    "v#{@schema_version}:" <> Base.encode16(:crypto.hash(:sha256, serialized), case: :lower)
  end

  @doc """
  Returns the canonical value of one bound field, or `:not_canonicalized`.
  Actor keys and undeclared keys return `:not_canonicalized`, and so does any
  key this module did not bind.
  """
  @spec bound_value(t(), atom()) :: tuple() | :not_canonicalized
  def bound_value(%__MODULE__{canonical_fields: fields}, key) when is_atom(key) do
    case List.keyfind(fields, Atom.to_string(key), 0) do
      {_key, value} -> value
      nil -> :not_canonicalized
    end
  end

  # ─── schema registry ─────────────────────────────────────────────────────

  # One entry per action. `keys` is the complete accepted key set, `actors` the
  # subset excluded from the fingerprint, and `fields` the `{key, tag}` pairs
  # that are bound. A tag names the effective-value rule for that one field, so
  # `canonicalize/3` stays the single place a value shape is interpreted.

  defp schemas do
    Map.new([
      {"create_goal",
       %{
         keys: [:company_uid, :uid, :title, :description, :creator_principal_uid],
         actors: [:creator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:uid, :trimmed_required},
           {:title, :trimmed_required},
           {:description, :nullable}
         ]
       }},
      {"create_mission",
       %{
         keys: [
           :company_uid,
           :uid,
           :content,
           :goal_uid,
           :assigned_agent_uid,
           :organizational_unit_uid,
           :creator_principal_uid
         ],
         actors: [:creator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:uid, :trimmed_required},
           {:content, :trimmed_required},
           {:goal_uid, :nullable},
           {:assigned_agent_uid, :principal_nullable},
           {:organizational_unit_uid, :nullable}
         ]
       }},
      {"create_revision",
       %{
         keys: [
           :company_uid,
           :mission_uid,
           :content,
           :goal_uid,
           :assigned_agent_uid,
           :organizational_unit_uid,
           :creator_principal_uid
         ],
         actors: [:creator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:mission_uid, :resource},
           {:content, :trimmed_required},
           {:goal_uid, :nullable},
           {:assigned_agent_uid, :principal_nullable},
           {:organizational_unit_uid, :nullable}
         ]
       }},
      {"create_task",
       %{
         keys: [
           :company_uid,
           :uid,
           :status,
           :origin_kind,
           :origin_reference,
           :mission_uid,
           :goal_uid,
           :parent_task_uid,
           :accountable_agent_uid,
           :objective_text,
           :scope_text,
           :required_outcome_text,
           :acceptance_criteria_text,
           :child_completion_policy,
           :cancelled_at,
           :cancelled_by_uid,
           :cancellation_reason,
           :failure_reason,
           :creator_principal_uid
         ],
         actors: [:creator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:uid, :trimmed_required},
           # Absent resolves to the store's "PROPOSED"; nil and "" do not,
           # because the column has no default and `validate_required` rejects
           # both.
           {:status, {:enum_default, @task_statuses, "PROPOSED"}},
           {:origin_kind, {:enum_required, @origin_kinds}},
           {:origin_reference, :map_nullable},
           {:mission_uid, :nullable},
           {:goal_uid, :nullable},
           {:parent_task_uid, :nullable},
           {:accountable_agent_uid, :principal_nullable},
           {:objective_text, :text_required},
           {:scope_text, :text_required},
           {:required_outcome_text, :text_required},
           {:acceptance_criteria_text, :text_required},
           # The schema default supplies this value when the key is absent.
           {:child_completion_policy, {:enum_default, @child_policies, "ALL_COMPLETED"}},
           {:cancelled_at, :datetime_nullable},
           {:cancelled_by_uid, :principal_nullable},
           {:cancellation_reason, :nullable},
           {:failure_reason, :nullable}
         ]
       }},
      {"create_child_task",
       %{
         keys: [
           :company_uid,
           :parent_task_uid,
           :uid,
           :status,
           :origin_kind,
           :child_completion_policy,
           :mission_uid,
           :goal_uid,
           :accountable_agent_uid,
           :objective_text,
           :scope_text,
           :required_outcome_text,
           :acceptance_criteria_text,
           :cancelled_at,
           :cancelled_by_uid,
           :cancellation_reason,
           :failure_reason,
           :creator_principal_uid
         ],
         actors: [:creator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:parent_task_uid, :resource},
           {:uid, :trimmed_required},
           {:status, {:enum_default, @task_statuses, "PROPOSED"}},
           {:origin_kind, {:enum_default, @origin_kinds, "DELEGATION"}},
           {:child_completion_policy, :policy_inherited},
           {:mission_uid, :nullable},
           {:goal_uid, :nullable},
           {:accountable_agent_uid, :principal_nullable},
           {:objective_text, :text_required},
           {:scope_text, :text_required},
           {:required_outcome_text, :text_required},
           {:acceptance_criteria_text, :text_required},
           {:cancelled_at, :datetime_nullable},
           {:cancelled_by_uid, :principal_nullable},
           {:cancellation_reason, :nullable},
           {:failure_reason, :nullable}
         ]
       }},
      {"create_result",
       %{
         keys: [
           :company_uid,
           :task_uid,
           :result_uid,
           :workflow_run_id,
           :workflow_agent_call_id,
           :background_agent_job_id,
           :background_agent_job_turn_id,
           :execution_attempt_ref,
           :executor_principal_uids,
           :result_metadata,
           :acceptance_state,
           :failure_reason
         ],
         actors: [],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:result_uid, :trimmed_required},
           {:workflow_run_id, :integer_ref},
           {:workflow_agent_call_id, :integer_ref},
           {:background_agent_job_id, :integer_ref},
           {:background_agent_job_turn_id, :uuid_ref},
           {:execution_attempt_ref, :trimmed_nullable},
           {:executor_principal_uids, :executor_list},
           {:result_metadata, :map_nullable},
           {:acceptance_state, :trimmed_nullable},
           {:failure_reason, :trimmed_nullable}
         ]
       }},
      {"create_review",
       %{
         keys: [
           :company_uid,
           :task_uid,
           :result_uid,
           :review_uid,
           :criteria_text,
           :verdict,
           :rationale_text,
           :invalidated_at,
           :invalidation_reason,
           :reviewer_principal_uid
         ],
         actors: [:reviewer_principal_uid],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:result_uid, :resource},
           {:review_uid, :review_uid},
           {:criteria_text, :trimmed_required},
           {:verdict, {:enum_required, @verdicts}},
           {:rationale_text, :trimmed_required},
           {:invalidated_at, :datetime_nullable},
           {:invalidation_reason, :trimmed_nullable}
         ]
       }},
      {"invalidate_review",
       %{
         keys: [:company_uid, :review_uid, :reason, :invalidator_principal_uid],
         actors: [:invalidator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:review_uid, :resource},
           {:reason, :trimmed_required}
         ]
       }},
      {"transition_task",
       %{
         keys: [
           :company_uid,
           :task_uid,
           :to_status,
           :accountable_agent_uid,
           :cancelled_at,
           :cancelled_by_uid,
           :cancellation_reason,
           :failure_reason,
           :metadata,
           :changed_by_uid
         ],
         actors: [:changed_by_uid],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:to_status, {:enum_required, @task_statuses}},
           {:accountable_agent_uid, :principal_nullable},
           # These reach the row through `put_change/3`, so absent and `nil`
           # both leave the stored value alone and an empty string is real.
           {:cancelled_at, :direct_nullable},
           {:cancelled_by_uid, :principal_nullable},
           {:cancellation_reason, :direct_nullable},
           {:failure_reason, :direct_nullable},
           {:metadata, :map_nullable}
         ]
       }},
      {"assign_agent",
       %{
         keys: [:company_uid, :task_uid, :agent_uid, :changed_by_uid],
         actors: [:changed_by_uid],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:agent_uid, :principal_required}
         ]
       }},
      {"cancel_task",
       %{
         keys: [:company_uid, :task_uid, :cancellation_reason, :metadata, :cancelled_by_uid],
         actors: [:cancelled_by_uid],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:cancellation_reason, :raw_required},
           {:metadata, {:merged_metadata, "cancellation_reason", :cancellation_reason}}
         ]
       }},
      {"fail_task",
       %{
         keys: [:company_uid, :task_uid, :failure_reason, :metadata, :failed_by_uid],
         actors: [:failed_by_uid],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:failure_reason, :raw_required},
           {:metadata, {:merged_metadata, "failure_reason", :failure_reason}}
         ]
       }},
      {"set_dependency",
       %{
         keys: [:company_uid, :task_uid, :depends_on_task_uid, :dependency_type],
         actors: [],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:depends_on_task_uid, :resource},
           {:dependency_type, {:enum_default, @dependency_types, "REQUIRES_COMPLETION"}}
         ]
       }},
      {"remove_dependency",
       %{
         keys: [:company_uid, :task_uid, :depends_on_task_uid],
         actors: [],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:depends_on_task_uid, :resource}
         ]
       }},
      {"set_child_policy",
       %{
         keys: [:company_uid, :task_uid, :new_policy, :changed_by_uid],
         actors: [:changed_by_uid],
         fields: [
           {:company_uid, :company},
           {:task_uid, :resource},
           {:new_policy, {:enum_required, @child_policies}}
         ]
       }},
      {"create_delegation",
       %{
         keys: [
           :company_uid,
           :source_task_uid,
           :delegatee_principal_uid,
           :scope_description,
           :delegator_principal_uid
         ],
         actors: [:delegator_principal_uid],
         fields: [
           {:company_uid, :company},
           {:source_task_uid, :resource},
           {:delegatee_principal_uid, :principal_nullable},
           {:scope_description, :trimmed_required}
         ]
       }}
    ])
  end

  # Each catalogued ROUTINE read binds the Company scope plus whatever identity
  # its own W2 read function takes. Two of them take nothing else.
  defp routine_schemas do
    Map.new([
      {"list_company_tasks", [:company_uid]},
      {"list_company_results", [:company_uid]},
      {"list_mission_tasks", [:company_uid, :mission_uid]},
      {"list_dependencies", [:company_uid, :task_uid]},
      {"list_children", [:company_uid, :parent_task_uid]},
      {"fetch_delegation", [:company_uid, :delegation_uid]},
      {"fetch_result", [:company_uid, :result_uid]},
      {"fetch_current_result", [:company_uid, :task_uid]},
      {"list_task_results", [:company_uid, :task_uid]},
      {"list_task_reviews", [:company_uid, :task_uid]},
      {"list_result_reviews", [:company_uid, :result_uid]},
      {"fetch_review", [:company_uid, :review_uid]},
      {"validate_assignment_eligibility", [:company_uid, :task_uid, :agent_uid]},
      {"workspace_read", [:company_uid]}
    ])
  end

  # `workspace_read` is catalogued as ROUTINE but no W2 read function backs it,
  # so there is no identity argument to bind. Its schema is Company-scoped
  # only and stays that way until the Resource and W2 catalog gaps close. No
  # workspace argument is invented here.
  defp all_schemas do
    Map.merge(
      schemas(),
      Map.new(routine_schemas(), fn {action, keys} ->
        {action,
         %{
           keys: keys,
           actors: [],
           fields: Enum.map(keys, &{&1, routine_tag(&1)})
         }}
      end)
    )
  end

  defp routine_tag(:company_uid), do: :company
  defp routine_tag(:agent_uid), do: :principal_required
  defp routine_tag(_key), do: :resource

  # ─── schema plumbing ─────────────────────────────────────────────────────

  defp fetch_schema(action) do
    case Map.fetch(all_schemas(), action) do
      {:ok, schema} -> {:ok, schema}
      :error -> {:error, {:intent_parameters, :unknown_action}}
    end
  end

  # An undeclared key means the caller believes a value takes part in this
  # action when no schema says it does. Dropping it silently would bind a
  # fingerprint that does not describe what was asked for, so it fails closed.
  defp check_keys(%{keys: allowed}, input) do
    allowed_set = MapSet.new(allowed)

    case Enum.find(Map.keys(input), &(not MapSet.member?(allowed_set, &1))) do
      nil -> :ok
      key -> {:error, {:intent_parameters, {:unknown_parameter, key}}}
    end
  end

  defp canonical_fields(schema, input) do
    Enum.reduce_while(schema.fields, {:ok, []}, fn {key, tag}, {:ok, acc} ->
      case canonicalize(key, tag, input) do
        {:ok, value} -> {:cont, {:ok, acc ++ [{Atom.to_string(key), value}]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, fields} -> {:ok, Enum.sort(fields)}
      {:error, _reason} = error -> error
    end
  end

  # ─── per-field canonicalization ──────────────────────────────────────────

  # The Company scope is an ordinary text key with no normalization, so its
  # effective value is the supplied binary.
  defp canonicalize(_key, :company, input), do: required_string(input, :company_uid)

  # A positional resource or target identifier, always a plain text column with
  # no normalization.
  defp canonicalize(key, :resource, input), do: required_string(input, key)

  # Required and trimmed before storage, so the stored value is the trimmed one
  # and a blank value cannot satisfy the column.
  defp canonicalize(key, :trimmed_required, input) do
    with {:ok, value} <- required_binary(input, key) do
      case String.trim(value) do
        "" -> {:error, {:intent_parameters, :invalid_parameter}}
        trimmed -> {:ok, {:string, trimmed}}
      end
    end
  end

  # Required and stored verbatim. A blank value still fails the column's own
  # presence rule, so it cannot be a legal intent.
  defp canonicalize(key, :text_required, input) do
    with {:ok, value} <- required_binary(input, key) do
      if String.trim(value) == "",
        do: {:error, {:intent_parameters, :invalid_parameter}},
        else: {:ok, {:string, value}}
    end
  end

  # Required and written straight to the row, where an empty string is stored
  # as given. Absence and `nil` are the two forms that carry no value at all.
  defp canonicalize(key, :raw_required, input) do
    with {:ok, value} <- required_binary(input, key) do
      {:ok, {:string, value}}
    end
  end

  # Optional on an insert path: absent, `nil`, and `""` all persist as NULL, and
  # any other string is stored exactly as supplied.
  defp canonicalize(key, :nullable, input), do: nullable_string(input, key, & &1)

  # Optional and trimmed before storage, so a blank value persists as NULL.
  defp canonicalize(key, :trimmed_nullable, input) do
    nullable_string(input, key, fn value ->
      case String.trim(value) do
        "" -> nil
        trimmed -> trimmed
      end
    end)
  end

  # Optional on a direct-put path: absent and `nil` both leave the stored value
  # untouched, while an empty string is written as given.
  defp canonicalize(key, :direct_nullable, input) do
    case fetch(input, key) do
      :absent -> {:ok, {:null}}
      {:ok, value} when is_binary(value) -> {:ok, {:string, value}}
      {:ok, _other} -> {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  defp canonicalize(key, {:enum_required, allowed}, input) do
    with {:ok, value} <- required_binary(input, key) do
      if value in allowed,
        do: {:ok, {:string, value}},
        else: {:error, {:intent_parameters, :invalid_parameter}}
    end
  end

  # A deterministic default fills an absent key, so absence and the default
  # share one canonical value. `nil` and `""` are distinct failures: the
  # column is either NOT NULL in practice, or `validate_required` and
  # `validate_inclusion` refuse both.
  defp canonicalize(key, {:enum_default, allowed, default}, input) do
    case fetch_raw(input, key) do
      :absent ->
        {:ok, {:string, default}}

      {:ok, nil} ->
        {:error, {:intent_parameters, :invalid_parameter}}

      {:ok, value} when is_binary(value) ->
        if value in allowed,
          do: {:ok, {:string, value}},
          else: {:error, {:intent_parameters, :invalid_parameter}}

      {:ok, _other} ->
        {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  defp canonicalize(key, :principal_required, input) do
    with {:ok, value} <- required_binary(input, key) do
      case PrincipalKey.normalize(value) do
        {:ok, canonical} -> {:ok, {:string, canonical}}
        {:error, :invalid_uid} -> {:error, {:intent_parameters, :invalid_parameter}}
      end
    end
  end

  defp canonicalize(key, :principal_nullable, input) do
    case fetch(input, key) do
      :absent ->
        {:ok, {:null}}

      {:ok, value} when is_binary(value) ->
        # A binary always normalizes: the principal UID rule maps a blank UID
        # to no UID at all, which is the stored NULL.
        case PrincipalKey.normalize_optional(value) do
          {:ok, nil} -> {:ok, {:null}}
          {:ok, canonical} -> {:ok, {:string, canonical}}
        end

      {:ok, _other} ->
        {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  # `Ecto.Type.cast/2` is the same conversion the column applies, so the
  # canonical value is by construction the value the column will hold.
  defp canonicalize(key, :datetime_nullable, input) do
    case fetch(input, key) do
      :absent ->
        {:ok, {:null}}

      {:ok, %DateTime{} = value} ->
        {:ok, {:string, value |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601()}}

      {:ok, %NaiveDateTime{} = value} ->
        {:ok, {:string, NaiveDateTime.to_iso8601(value) <> "Z"}}

      {:ok, other} ->
        case Ecto.Type.cast(:utc_datetime_usec, other) do
          {:ok, %DateTime{} = cast} ->
            {:ok, {:string, DateTime.to_iso8601(cast)}}

          {:ok, %NaiveDateTime{} = cast} ->
            {:ok, {:string, NaiveDateTime.to_iso8601(cast) <> "Z"}}

          {:ok, _other} ->
            {:error, {:intent_parameters, :unsupported_type}}

          :error ->
            {:error, {:intent_parameters, :invalid_parameter}}
        end
    end
  end

  defp canonicalize(key, :map_nullable, input) do
    case fetch(input, key) do
      :absent -> {:ok, {:null}}
      {:ok, value} -> canonical_value(value, [])
    end
  end

  # An executor list keeps `nil` and `[]` apart, because W2 stores NULL for one
  # and an empty array for the other. Order and duplicates survive, because
  # reviewer independence is judged against the stored sequence.
  defp canonicalize(key, :executor_list, input) do
    case fetch(input, key) do
      :absent -> {:ok, {:null}}
      {:ok, list} when is_list(list) -> canonical_executor_list(list)
      {:ok, _other} -> {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  # W2 refuses a reference it cannot read as the column's own type, so a
  # malformed reference never degrades into a missing one.
  defp canonicalize(key, :integer_ref, input) do
    case fetch(input, key) do
      :absent -> {:ok, {:null}}
      {:ok, value} -> reference_integer(value)
    end
  end

  defp canonicalize(key, :uuid_ref, input) do
    case fetch(input, key) do
      :absent -> {:ok, {:null}}
      {:ok, value} -> reference_uuid(value)
    end
  end

  # W2 derives this value from the locked parent row, which no pre-assurance
  # reader can see. The fingerprint therefore binds the instruction, not a
  # value the system has not read yet. `nil` is a separate case: the column's
  # own default fills it instead, so it never reaches the parent.
  defp canonicalize(key, :policy_inherited, input) do
    case fetch_raw(input, key) do
      :absent ->
        {:ok, {:inherited, "parent_task_uid"}}

      {:ok, nil} ->
        {:error, {:intent_parameters, :invalid_parameter}}

      {:ok, value} when is_binary(value) ->
        if value in @child_policies,
          do: {:ok, {:string, value}},
          else: {:error, {:intent_parameters, :invalid_parameter}}

      {:ok, _other} ->
        {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  # W2 keeps a supplied identity and generates one otherwise. A supplied value
  # is caller intent and is bound; a generated one does not exist before
  # assurance, so it is represented by a sentinel rather than a fabricated UID.
  defp canonicalize(key, :review_uid, input) do
    case fetch_raw(input, key) do
      :absent ->
        {:ok, {:server_generated, "review_uid"}}

      {:ok, value} when is_binary(value) ->
        case String.trim(value) do
          "" -> {:error, {:intent_parameters, :invalid_parameter}}
          trimmed -> {:ok, {:caller_supplied, trimmed}}
        end

      {:ok, _other} ->
        {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  # W2 builds the lifecycle metadata by merging its derived key under the
  # caller's own map, so a caller value under the same key wins. The effective
  # value is the merged map, and a non-map is refused rather than discarded,
  # because W2 would raise on it.
  defp canonicalize(key, {:merged_metadata, derived_key, source_key}, input) do
    with {:ok, derived} <- required_binary(input, source_key) do
      case fetch(input, key) do
        :absent ->
          canonical_value(%{derived_key => derived}, [])

        {:ok, value} when is_map(value) and not is_struct(value) ->
          canonical_value(Map.merge(%{derived_key => derived}, value), [])

        {:ok, _other} ->
          {:error, {:intent_parameters, :unsupported_type}}
      end
    end
  end

  # ─── value helpers ───────────────────────────────────────────────────────

  defp canonical_executor_list(list) do
    if keyword_list?(list) do
      {:error, {:intent_parameters, :unsupported_type}}
    else
      Enum.reduce_while(list, {:ok, []}, fn uid, {:ok, acc} ->
        case PrincipalKey.normalize(uid) do
          {:ok, canonical} -> {:cont, {:ok, acc ++ [{:string, canonical}]}}
          {:error, :invalid_uid} -> {:halt, {:error, {:intent_parameters, :invalid_parameter}}}
        end
      end)
      |> case do
        {:ok, values} -> {:ok, {:list, values}}
        {:error, _reason} = error -> error
      end
    end
  end

  defp reference_integer(value) when is_integer(value) do
    if value > 0,
      do: {:ok, {:int, value}},
      else: {:error, {:intent_parameters, :invalid_parameter}}
  end

  defp reference_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, {:int, id}}
      _other -> {:error, {:intent_parameters, :invalid_parameter}}
    end
  end

  defp reference_integer(_value), do: {:error, {:intent_parameters, :unsupported_type}}

  defp reference_uuid(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, {:string, uuid}}
      :error -> {:error, {:intent_parameters, :invalid_parameter}}
    end
  end

  defp reference_uuid(_value), do: {:error, {:intent_parameters, :unsupported_type}}

  # Presence for fields where W2 treats an absent key and an explicit `nil` as
  # the same absence, which is every nullable column and every default.
  defp fetch(input, key) do
    case fetch_raw(input, key) do
      {:ok, nil} -> :absent
      other -> other
    end
  end

  # Presence for fields whose canonical value depends on `nil` being distinct
  # from absence: a defaulted or validated column refuses an explicit `nil`
  # where it would have supplied its own value for an absent key.
  defp fetch_raw(input, key) do
    case Map.fetch(input, key) do
      {:ok, value} -> {:ok, value}
      :error -> :absent
    end
  end

  defp required_binary(input, key) do
    case fetch(input, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      {:ok, _other} -> {:error, {:intent_parameters, :unsupported_type}}
      :absent -> {:error, {:intent_parameters, :missing_parameter}}
    end
  end

  # A required text identifier, bound under the same tag as every other string
  # so a bare binary can never be mistaken for a different canonical shape.
  defp required_string(input, key) do
    with {:ok, value} <- required_binary(input, key) do
      {:ok, {:string, value}}
    end
  end

  defp nullable_string(input, key, normalizer) do
    case fetch(input, key) do
      :absent ->
        {:ok, {:null}}

      {:ok, value} when is_binary(value) ->
        case normalizer.(value) do
          nil -> {:ok, {:null}}
          normalized -> {:ok, {:string, normalized}}
        end

      {:ok, _other} ->
        {:error, {:intent_parameters, :unsupported_type}}
    end
  end

  # ─── canonical value tree ────────────────────────────────────────────────

  @doc """
  Converts one raw value into its canonical tagged form.

  Maps are converted recursively. Two source keys that normalize to the same
  string key are a collision and fail closed rather than silently overwriting.
  """
  @spec canonical_value(term(), [binary()]) :: {:ok, tuple()} | {:error, term()}
  def canonical_value(value, path \\ [])

  def canonical_value(nil, _path), do: {:ok, {:null}}

  def canonical_value(value, _path) when is_boolean(value), do: {:ok, {:bool, value}}

  def canonical_value(value, _path) when is_integer(value), do: {:ok, {:int, value}}

  def canonical_value(value, _path) when is_float(value) do
    if finite?(value),
      do: {:ok, {:float, value}},
      else: {:error, {:intent_parameters, :unsupported_type}}
  end

  def canonical_value(value, _path) when is_binary(value), do: {:ok, {:string, value}}

  def canonical_value(value, path) when is_list(value) do
    if keyword_list?(value) do
      {:error, {:intent_parameters, :unsupported_type}}
    else
      Enum.reduce_while(value, {:ok, []}, fn element, {:ok, acc} ->
        case canonical_value(element, path) do
          {:ok, canonical} -> {:cont, {:ok, acc ++ [canonical]}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, values} -> {:ok, {:list, values}}
        {:error, _reason} = error -> error
      end
    end
  end

  def canonical_value(%_struct{}, _path), do: {:error, {:intent_parameters, :unsupported_type}}

  def canonical_value(value, path) when is_map(value) do
    Enum.reduce_while(value, {:ok, []}, fn {key, raw}, {:ok, acc} ->
      with {:ok, name} <- canonical_key(key),
           {:ok, canonical} <- canonical_value(raw, path ++ [name]) do
        if List.keymember?(acc, name, 0) do
          {:halt, {:error, {:intent_parameters, {:metadata_key_collision, path ++ [name]}}}}
        else
          {:cont, {:ok, acc ++ [{name, canonical}]}}
        end
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, pairs} -> {:ok, {:map, Enum.sort(pairs)}}
      {:error, _reason} = error -> error
    end
  end

  def canonical_value(_value, _path), do: {:error, {:intent_parameters, :unsupported_type}}

  # A keyword list is a second spelling of a map. The columns are jsonb, which
  # has one spelling, so the alternate form is refused instead of translated.
  defp keyword_list?([]), do: false

  defp keyword_list?(list) do
    Enum.all?(list, fn
      {key, _value} when is_atom(key) -> true
      _other -> false
    end)
  end

  defp canonical_key(key) when is_binary(key), do: {:ok, key}
  defp canonical_key(key) when is_atom(key), do: {:ok, Atom.to_string(key)}
  defp canonical_key(_key), do: {:error, {:intent_parameters, :unsupported_type}}

  # The largest finite double. A float outside this range is an infinity, and a
  # NaN compares false against every bound, so one pair of comparisons rejects
  # both without evaluating an arithmetic expression that could overflow.
  @max_finite_float 1.7976931348623157e308

  defp finite?(value) when is_float(value) do
    value >= -@max_finite_float and value <= @max_finite_float
  end
end
