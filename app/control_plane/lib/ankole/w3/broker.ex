defmodule Ankole.W3.Broker do
  @moduledoc """
  Broker contract for trusted execution per MA-06 §27.

  Privileged host/external actions execute through trusted brokers/services.
  The broker receives validated trusted execution authority and exact action
  parameters. The Agent does not receive host administrator credentials,
  long-lived API secrets, database credentials, or unrestricted shell
  authority simply because the action was approved.

  This module defines the contract interface. Real broker implementations
  (file-system writes, network API calls, database mutations) belong to
  later domains (MA-01, MA-08, MA-09, MA-17). P7 ships a deterministic
  mock implementation for qualification testing only.

  ## Contract

  A broker must:
  - Independently validate authority before execution (not trust the caller)
  - Reject stale, expired, revoked, consumed, or mismatched authority
  - Enforce Company boundary and Principal eligibility at execution time
  - Support idempotent replay via execution_uid
  - Return structured results sufficient for postcondition verification
  - Never silently succeed — every failure path returns an explicit error

  ## Decision Flow

      Caller has completed Action Assurance (P5/P6)
          ↓
      Call Broker.execute(...)
          ↓
      [authority validation → scope check → TOCTOU → execution → result]
          ↓
      {:ok, result} | {:error, reason}
          ↓
      Caller verifies postconditions, calls ActionAssurance.finalize_assurance
  """

  @doc """
  Executes a pre-authorized action through the trusted broker.

  The broker independently validates all authority and state checks.
  It does not trust that P5 already performed these checks — it
  re-validates at execution time per MA-06 §22 (time-of-check /
  time-of-use).

  Returns `{:ok, result}` on success or `{:error, reason}` on the
  first failing check. No silent success.

  The `target_state` parameter enables TOCTOU protection: if the
  observed state changed since the assurance decision, the broker
  rejects the execution.
  """
  @spec execute(
          Ecto.Repo.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil,
          map(),
          map() | nil
        ) :: {:ok, map()} | {:error, atom()}
  def execute(_repo, _company_uid, _principal_uid, _action, _resource,
              _capability_uid, _approval_uid, _params, _target_state) do
    raise "Broker.execute/9 must be implemented by a concrete broker strategy"
  end

  @doc """
  Resolves a previously recorded execution by its `execution_uid`.

  Used for idempotent replay detection. Returns the cached result
  if one exists; `{:error, :not_found}` otherwise.
  """
  @spec resolve(String.t()) :: {:ok, map()} | {:error, :not_found}
  def resolve(_execution_uid) do
    raise "Broker.resolve/1 must be implemented by a concrete broker strategy"
  end
end
