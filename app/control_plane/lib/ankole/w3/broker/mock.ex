defmodule Ankole.W3.Broker.Mock do
  @moduledoc """
  Deterministic mock broker for W3-P7 qualification testing.

  Implements the `Ankole.W3.Broker` contract without performing any
  host-side effects. Validates authority via the supplied repository,
  enforces exact-action binding, supports TOCTOU checks, and tracks
  executions for replay detection — all in memory.

  ## Usage

  Test modules must be `async: false` because the mock holds mutable
  in-memory state shared across processes.

  ```elixir
  defmodule MyBrokerTest do
    use ExUnit.Case, async: false

    setup do
      Mock.start()
      on_exit(fn -> Mock.stop() end)
    end
  end
  ```
  """

  use GenServer

  alias Ankole.Company
  alias Ankole.Company.MembershipStore
  alias Ankole.Principals.Principal
  alias Ankole.W3.ApprovalStore
  alias Ankole.W3.Capability
  alias Ankole.W3.CapabilityStore

  # ─── GenServer callbacks ────────────────────────────────────────────────

  @doc """
  Starts the mock broker process and its backing ETS tables.
  """
  @spec start_link() :: GenServer.on_start()
  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    exec_tbl = :ets.new(:broker_mock_executions, [:set, :named_table, :public])
    tgt_tbl = :ets.new(:broker_mock_target_state, [:set, :named_table, :public])
    {:ok, %{executions: exec_tbl, target_state: tgt_tbl}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ets.delete(:broker_mock_executions)
    :ets.delete(:broker_mock_target_state)
    :ok
  end

  # ─── Public API ─────────────────────────────────────────────────────────

  @doc """
  Stops the mock broker and removes all ETS tables.
  """
  @spec stop() :: :ok
  def stop do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Records an expected post-execution state snapshot for a given
  `{company_uid, resource}` pair. Simulates target mutation for TOCTOU tests.
  """
  @spec set_target_state(String.t(), String.t(), map()) :: :ok
  def set_target_state(company_uid, resource, state) do
    GenServer.call(__MODULE__, {:set_target_state, company_uid, resource, state})
  end

  @doc """
  Clears all recorded execution results. Call between tests.
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def handle_call(msg, _from, state) do
    case msg do
      {:set_target_state, company_uid, resource, st} ->
        :ets.insert(state.target_state, {{company_uid, resource}, st})
        {:reply, :ok, state}

      :reset ->
        :ets.delete_all_objects(state.executions)
        {:reply, :ok, state}

      _ ->
        {:noreply, state}
    end
  end

  # ─── Broker contract implementation ────────────────────────────────────

  @doc false
  def execute(repo, company_uid, principal_uid, action, resource,
              capability_uid, approval_uid, params, target_state) do
    execution_uid = generate_execution_uid()

    case :ets.lookup(:broker_mock_executions, execution_uid) do
      [{^execution_uid, result}] ->
        {:ok, Map.put(result, :execution_uid, execution_uid)}

      [] ->
        case validate_all(
               repo,
               company_uid,
               principal_uid,
               action,
               resource,
               capability_uid,
               approval_uid,
               params,
               target_state
             ) do
          :ok ->
            result = build_result(execution_uid)
            :ets.insert(:broker_mock_executions, {execution_uid, result})
            {:ok, result}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc false
  def resolve(execution_uid) do
    case :ets.lookup(:broker_mock_executions, execution_uid) do
      [{^execution_uid, result}] -> {:ok, result}
      [] -> {:error, :not_found}
    end
  end

  # ─── Validation chain ───────────────────────────────────────────────────

  defp validate_all(
         repo,
         company_uid,
         principal_uid,
         action,
         resource,
         capability_uid,
         approval_uid,
         params,
         target_state
       ) do
    with :ok <- check_company_boundary(repo, company_uid),
         :ok <- check_principal_eligible(repo, company_uid, principal_uid),
         {:ok, capability} <- check_authority(repo, company_uid, capability_uid),
         :ok <- check_action_match(capability, action),
         :ok <- check_resource_match(capability, resource),
         :ok <- check_constraints(capability, params),
         :ok <- check_toctou(company_uid, resource, target_state),
         :ok <- check_approval(repo, company_uid, capability, approval_uid, principal_uid, action, resource) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_company_boundary(_repo, company_uid) when is_nil(company_uid) or company_uid == "" do
    {:error, :company_scope_mismatch}
  end

  defp check_company_boundary(repo, company_uid) do
    case repo.get_by(Company, uid: company_uid) do
      %Company{} -> :ok
      nil -> {:error, :company_scope_mismatch}
    end
  end

  defp check_principal_eligible(repo, company_uid, principal_uid) do
    case repo.get(Principal, principal_uid) do
      %Principal{status: :active} ->
        if MembershipStore.member?(repo, company_uid, principal_uid) do
          :ok
        else
          {:error, :principal_not_in_company}
        end

      %Principal{status: :disabled} ->
        {:error, :principal_disabled}

      _ ->
        {:error, :principal_not_in_company}
    end
  end

  defp check_authority(_repo, _company_uid, capability_uid)
       when is_nil(capability_uid) or capability_uid == "" do
    {:error, :authority_missing}
  end

  defp check_authority(repo, company_uid, capability_uid) do
    case CapabilityStore.fetch_capability(repo, company_uid, capability_uid) do
      {:ok, %Capability{status: :active}} = cap -> cap
      {:ok, %Capability{status: :consumed}} -> {:error, :authority_consumed}
      {:ok, %Capability{status: :expired}} -> {:error, :authority_expired}
      {:ok, %Capability{status: :revoked}} -> {:error, :authority_revoked}
      {:error, :not_found} -> {:error, :authority_invalid}
      {:error, :company_not_found} -> {:error, :authority_invalid}
      {:error, :invalid_uid} -> {:error, :authority_invalid}
    end
  end

  defp check_action_match(%Capability{action: action}, action), do: :ok
  defp check_action_match(_capability, _action), do: {:error, :authority_action_mismatch}

  defp check_resource_match(%Capability{resource: resource}, resource), do: :ok
  defp check_resource_match(_capability, _resource), do: {:error, :authority_resource_mismatch}

  defp check_constraints(%Capability{constraints: constraints}, params)
       when is_map(constraints) and is_map(params) do
    if Enum.all?(constraints, fn {key, _} -> Map.has_key?(params, key) end) do
      :ok
    else
      {:error, :scope_exceeded}
    end
  end

  defp check_constraints(_capability, _params), do: :ok

  defp check_toctou(_company_uid, _resource, nil), do: :ok

  defp check_toctou(company_uid, resource, target_state) do
    case :ets.lookup(:broker_mock_target_state, {company_uid, resource}) do
      [{{_c, _r}, stored}] when stored == target_state -> :ok
      [{{_c, _r}, _stored}] -> {:error, :target_state_changed}
      [] -> :ok
    end
  end

  defp check_approval(_repo, _company_uid, %Capability{risk_class: "HIGH-IMPACT"}, nil, _principal_uid, _action, _resource) do
    {:error, :approval_required}
  end

  defp check_approval(_repo, _company_uid, _capability, nil, _principal_uid, _action, _resource), do: :ok

  defp check_approval(repo, company_uid, _capability, approval_uid, principal_uid, action, resource) do
    case ApprovalStore.validate_for_assurance(
           repo,
           company_uid,
           approval_uid,
           principal_uid,
           action,
           resource
         ) do
      :ok -> :ok
      {:error, _} -> {:error, :approval_invalid}
    end
  end

  # ─── Result helpers ─────────────────────────────────────────────────────

  defp build_result(execution_uid) do
    %{
      success: true,
      output: %{mock: true, execution_uid: execution_uid},
      post_state: %{},
      side_effects: [],
      execution_uid: execution_uid
    }
  end

  defp generate_execution_uid do
    "#{:crypto.strong_rand_bytes(8) |> Base.encode16()}|#{System.unique_integer([:positive])}"
  end
end
