defmodule Ankole.W3.Resource do
  @moduledoc """
  Canonical W2 resource serializer and exact-resource normalizer.

  ## Contract

  `build/3` constructs a deterministic, Company-scoped resource string from an
  action name and an explicit map of target UIDs. The shape is fixed by
  action — the caller passes only the identifiers that appear in the path.

  `normalize_exact/1` validates and trims an already-concrete resource string
  (for receipts, approvals, and Capability rows that store a resolved target).
  It does not parse or interpret AuthZ grant patterns; callers should use it
  only for exact-match resources.

  Both functions are side-effect free and require no database access.
  """

  @prefix "w2:v1/"
  @max_bytes 512
  @glob_chars ~r/[\*\?\[\]\{\}]/

  # Required target keys per action. Actions not listed here accept any targets
  # map (create-action collections have none). Missing required keys fail
  # closed with :missing_target rather than falling through to :unknown_action.
  @required_targets %{
    "create_revision" => [:mission_uid],
    "create_result" => [:task_uid],
    "create_review" => [:task_uid, :result_uid],
    "create_child_task" => [:task_uid],
    "create_delegation" => [:task_uid],
    "transition_task" => [:task_uid],
    "assign_agent" => [:task_uid],
    "cancel_task" => [:task_uid],
    "fail_task" => [:task_uid],
    "set_child_policy" => [:task_uid],
    "set_dependency" => [:task_uid, :depends_on_task_uid],
    "remove_dependency" => [:task_uid, :depends_on_task_uid],
    "invalidate_review" => [:review_uid]
  }

  # ─── public API ──────────────────────────────────────────────────────────

  @doc """
  Builds a canonical W2 resource for one action.

  `targets` must be a non-empty map whose keys match the action's required
  targets. Missing required keys return `{:error, :missing_target}`. Extra
  keys are silently ignored.

  Returns `{:ok, canonical_resource}` on success or `{:error, reason}` on
  failure. No database access.
  """
  @spec build(String.t(), String.t(), map()) :: {:ok, String.t()} | {:error, atom()}
  def build(action, company_uid, targets) when is_binary(company_uid) and is_map(targets) do
    with :ok <- validate_company_uid(company_uid),
         {:ok, encoded_company} <- encode_segment(company_uid),
         :ok <- validate_targets(action, targets) do
      do_build(action, encoded_company, targets)
    end
  end

  @doc """
  Normalizes a concrete exact resource string.

  Trims outer whitespace, rejects blanks and glob characters, and enforces
  the 512-byte limit. Does NOT lowercase or restructure the value — the
  caller must supply the canonical form. Intended for exact-match storage
  (receipts, approvals, stored capabilities), not for grant-pattern parsing.
  """
  @spec normalize_exact(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def normalize_exact(resource) when is_binary(resource) do
    trimmed = String.trim(resource)

    if trimmed == "" do
      {:error, :blank}
    else
      case byte_size(trimmed) > @max_bytes do
        true -> {:error, :too_long}
        false ->
          case Regex.match?(@glob_chars, trimmed) do
            true -> {:error, :glob_not_allowed}
            false -> {:ok, trimmed}
          end
      end
    end
  end

  def normalize_exact(_other), do: {:error, :not_binary}

  # ─── action-specific builders ───────────────────────────────────────────

  defp do_build("create_task", company, _) do
    resource(@prefix <> "company/" <> company <> "/tasks")
  end

  defp do_build("create_goal", company, _) do
    resource(@prefix <> "company/" <> company <> "/goals")
  end

  defp do_build("create_mission", company, _) do
    resource(@prefix <> "company/" <> company <> "/missions")
  end

  defp do_build("create_revision", company, %{mission_uid: mission_uid}) do
    with {:ok, m} <- encode_segment(mission_uid) do
      resource(@prefix <> "company/" <> company <> "/missions/" <> m <> "/revisions")
    end
  end

  defp do_build("create_result", company, %{task_uid: task_uid}) do
    with {:ok, t} <- encode_segment(task_uid) do
      resource(@prefix <> "company/" <> company <> "/tasks/" <> t <> "/results")
    end
  end

  defp do_build("create_review", company, %{task_uid: task_uid, result_uid: result_uid}) do
    with {:ok, t} <- encode_segment(task_uid),
         {:ok, r} <- encode_segment(result_uid) do
      resource(@prefix <> "company/" <> company <> "/tasks/" <> t <> "/results/" <> r <> "/reviews")
    end
  end

  defp do_build("create_child_task", company, %{task_uid: task_uid}) do
    with {:ok, t} <- encode_segment(task_uid) do
      resource(@prefix <> "company/" <> company <> "/tasks/" <> t <> "/children")
    end
  end

  defp do_build("create_delegation", company, %{task_uid: task_uid}) do
    with {:ok, t} <- encode_segment(task_uid) do
      resource(@prefix <> "company/" <> company <> "/tasks/" <> t <> "/delegations")
    end
  end

  defp do_build(action, company, %{task_uid: task_uid})
       when action in ~w(transition_task assign_agent cancel_task fail_task set_child_policy) do
    with {:ok, t} <- encode_segment(task_uid) do
      resource(@prefix <> "company/" <> company <> "/tasks/" <> t)
    end
  end

  defp do_build("set_dependency", company, %{task_uid: task_uid, depends_on_task_uid: dep_uid}) do
    with {:ok, t} <- encode_segment(task_uid),
         {:ok, d} <- encode_segment(dep_uid) do
      resource(@prefix <> "company/" <> company <> "/tasks/" <> t <> "/dependencies/" <> d)
    end
  end

  defp do_build("remove_dependency", company, %{task_uid: task_uid, depends_on_task_uid: dep_uid}) do
    do_build("set_dependency", company, %{task_uid: task_uid, depends_on_task_uid: dep_uid})
  end

  defp do_build("invalidate_review", company, %{review_uid: review_uid}) do
    with {:ok, v} <- encode_segment(review_uid) do
      resource(@prefix <> "company/" <> company <> "/reviews/" <> v)
    end
  end

  defp do_build(_action, _company, _targets) do
    {:error, :unknown_action}
  end

  # ─── private helpers ────────────────────────────────────────────────────

  defp validate_targets(action, targets) do
    case Map.get(@required_targets, action) do
      nil -> :ok
      required ->
        if Enum.all?(required, &(Map.has_key?(targets, &1))) do
          :ok
        else
          {:error, :missing_target}
        end
    end
  end

  defp validate_company_uid(""), do: {:error, :blank_company}
  defp validate_company_uid(_uid), do: :ok

  defp resource(path) do
    case byte_size(path) > @max_bytes do
      true -> {:error, :too_long}
      false -> {:ok, path}
    end
  end

  # Percent-encodes a UID segment per RFC 3986 section 2.1.
  # Unreserved: A-Z a-z 0-9 - . _ ~
  # All other bytes are emitted as %HH with uppercase hex.
  defp encode_segment(nil), do: {:error, :missing_target}
  defp encode_segment("") , do: {:error, :missing_target}
  defp encode_segment(binary) when is_binary(binary) do
    encoded =
      binary
      |> :binary.bin_to_list()
      |> Enum.map(&encode_byte/1)
      |> :erlang.iolist_to_binary()

    case byte_size(encoded) == 0 do
      true -> {:error, :missing_target}
      false -> {:ok, encoded}
    end
  end

  # Reject any non-string target UID (integer, atom, map, etc.) rather than
  # crashing with a FunctionClauseError. The caller must pass string UIDs.
  defp encode_segment(_other), do: {:error, :missing_target}

  defp encode_byte(byte) when byte in ?A..?Z or byte in ?a..?z or byte in ?0..?9, do: [byte]
  defp encode_byte(?-) , do: [?-]
  defp encode_byte(?.) , do: [?.]
  defp encode_byte(?_) , do: [?_]
  defp encode_byte(byte) when byte == ?~, do: [?~]
  defp encode_byte(byte), do: ["%" <> pad_hex(byte)]

  defp pad_hex(byte) when byte < 16, do: "0" <> Integer.to_string(byte, 16)
  defp pad_hex(byte), do: Integer.to_string(byte, 16)
end
