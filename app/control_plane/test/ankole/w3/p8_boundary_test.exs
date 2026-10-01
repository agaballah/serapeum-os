defmodule Ankole.W3.P8BoundaryTest do
  use ExUnit.Case, async: true

  # ─── Protected W2 mutation catalog ───────────────────────────────────────
  #
  # These are the persistent W2 mutation functions established by the A-6
  # surface lock. Default-argument arities are listed explicitly so that both
  # the /5 and /6 forms of cancel_task, and both the /4 and /5 forms of
  # transition_task, are protected.
  #
  # W2 read APIs are deliberately absent from this map and are therefore never
  # prohibited.

  @protected %{
    "Ankole.WorkHierarchy.GoalStore" => %{create_goal: [3]},
    "Ankole.WorkHierarchy.MissionStore" => %{
      create_mission: [3],
      create_revision: [4]
    },
    "Ankole.WorkHierarchy.ResultStore" => %{create_result: [4]},
    "Ankole.WorkHierarchy.ReviewStore" => %{
      create_review: [6],
      invalidate_review: [4]
    },
    "Ankole.WorkHierarchy.TaskStore" => %{
      create_task: [3],
      transition_task: [4, 5],
      assign_agent: [5],
      cancel_task: [5, 6],
      fail_task: [5, 6],
      create_child_task: [4, 5],
      set_dependency: [5],
      remove_dependency: [4],
      set_child_policy: [5],
      create_delegation: [5, 6]
    }
  }

  # The P8 boundary module is the one production module permitted to reach the
  # protected surface, and even it does not yet do so.
  @p8_module "Ankole.W3.P8ControlledAction"

  # The five W2 store modules define the protected functions and contain
  # legitimate same-module delegates (assign_agent, cancel_task and fail_task
  # each call transition_task), so they are excluded from caller scanning.
  @store_files ~w(
    goal_store.ex
    mission_store.ex
    result_store.ex
    review_store.ex
    task_store.ex
  )

  @app_root Path.expand("../../..", __DIR__)
  @repo_root Path.expand("../../../..", __DIR__)

  @w3_concepts [
    "Ankole.W3",
    "ActionAssurance",
    "CapabilityService",
    "ApprovalStore",
    "ActionReceipt"
  ]

  # ─── Architecture guard ──────────────────────────────────────────────────

  describe "boundary: W2 mutations have one authoritative production route" do
    test "no checked-in production source outside P8 calls a protected W2 mutation" do
      violations = production_violations()

      assert violations == [],
             """
             Production code must reach controlled W2 mutations only through
             #{@p8_module}.

             Offending call(s):

             #{Enum.map_join(violations, "\n", &format_violation/1)}
             """
    end

    test "the P8 boundary module contains no protected W2 mutation call" do
      source = File.read!(p8_path())
      violations = source_violations(source, "lib/ankole/w3/p8_controlled_action.ex")

      assert violations == [],
             """
             A-6 establishes ownership of the authoritative route only. P8 must
             not execute the route yet, so it must contain no protected W2
             mutation call.

             #{Enum.map_join(violations, "\n", &format_violation/1)}
             """
    end

    test "the P8 boundary module is non-operational and fail-closed" do
      assert Code.ensure_loaded?(Ankole.W3.P8ControlledAction)
      assert Ankole.W3.P8ControlledAction.ready?() == false

      exported =
        Ankole.W3.P8ControlledAction.module_info(:exports)
        |> Enum.reject(fn {name, _arity} -> name in [:__info__, :module_info, :ready?] end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()

      assert exported == [],
             """
             P8 must expose no provisional mutation entry point until the
             pipeline is complete, but it exports: #{inspect(exported)}
             """
    end

    test "the P8 boundary module lives at the approved path" do
      assert p8_path() ==
               Path.join(@app_root, "lib/ankole/w3/p8_controlled_action.ex")

      assert File.exists?(p8_path())
      assert @p8_module == "Ankole.W3.P8ControlledAction"
    end

    test "every protected MFA exists, so the catalog cannot silently shrink" do
      missing =
        Enum.flat_map(@protected, fn {mod, funs} ->
          module = Module.concat([mod])
          # function_exported?/3 answers false for a module that is not yet
          # loaded, so the module must be loaded before it can be consulted.
          Code.ensure_loaded!(module)

          for {fun, arities} <- funs,
              arity <- arities,
              not function_exported?(module, fun, arity) do
            "#{mod}.#{fun}/#{arity}"
          end
        end)

      assert missing == [], "Protected MFAs that no longer exist: #{inspect(missing)}"
    end

    test "the catalog protects every persistent W2 mutation and no read API" do
      assert map_size(@protected) == 5

      protected_functions = Enum.flat_map(@protected, fn {_m, funs} -> Map.keys(funs) end)
      assert length(protected_functions) == 16

      # A W2 read API must never appear in the protected set.
      for read_api <- [
            :fetch_task,
            :list_company_tasks,
            :list_mission_tasks,
            :validate_assignment_eligibility,
            :list_dependencies,
            :list_children,
            :fetch_delegation,
            :fetch_result,
            :fetch_current_result,
            :list_task_results,
            :list_company_results,
            :fetch_review,
            :list_task_reviews,
            :list_result_reviews,
            :fetch_goal,
            :list_company_goals,
            :fetch_mission,
            :fetch_current_revision,
            :list_mission_revisions,
            :list_company_missions
          ] do
        refute read_api in protected_functions,
               "#{read_api} is a W2 read API and must not be protected"
      end
    end
  end

  # ─── Guard self-tests ────────────────────────────────────────────────────
  #
  # These prove the scanner detects each bypass form rather than assuming it
  # does. All fixtures are source strings inside this test process; no
  # persistent repository fixture file is created.

  describe "guard self-tests" do
    test "detects a fully qualified direct protected mutation call" do
      source = """
      defmodule Bad do
        def go(repo, company, attrs) do
          Ankole.WorkHierarchy.TaskStore.create_task(repo, company, attrs)
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).module == "Ankole.WorkHierarchy.TaskStore"
      assert hd(violations).function == :create_task
      assert hd(violations).arity == 3
    end

    test "detects a protected mutation called through a normal alias" do
      source = """
      defmodule Bad do
        alias Ankole.WorkHierarchy.TaskStore

        def go(repo, company, task, status) do
          TaskStore.transition_task(repo, company, task, status, %{})
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).module == "Ankole.WorkHierarchy.TaskStore"
      assert hd(violations).function == :transition_task
      assert hd(violations).arity == 5
    end

    test "detects a protected mutation called through an as: alias" do
      source = """
      defmodule Bad do
        alias Ankole.WorkHierarchy.GoalStore, as: Goals

        def go(repo, company, attrs) do
          Goals.create_goal(repo, company, attrs)
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).module == "Ankole.WorkHierarchy.GoalStore"
      assert hd(violations).function == :create_goal
    end

    test "detects an imported protected mutation called unqualified" do
      source = """
      defmodule Bad do
        import Ankole.WorkHierarchy.ResultStore, only: [create_result: 4]

        def go(repo, company, task, attrs) do
          create_result(repo, company, task, attrs)
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).function == :create_result
      assert hd(violations).arity == 4
    end

    test "detects a whole-module import of a protected mutation" do
      source = """
      defmodule Bad do
        import Ankole.WorkHierarchy.ReviewStore

        def go(repo, company, task, result, reviewer, attrs) do
          create_review(repo, company, task, result, reviewer, attrs)
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).module == "Ankole.WorkHierarchy.ReviewStore"
      assert hd(violations).function == :create_review
    end

    test "detects a static apply/3 targeting a protected store mutation" do
      source = """
      defmodule Bad do
        alias Ankole.WorkHierarchy.TaskStore

        def go(repo, company, task, status, opts) do
          apply(TaskStore, :transition_task, [repo, company, task, status, opts])
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).module == "Ankole.WorkHierarchy.TaskStore"
      assert hd(violations).function == :transition_task
      assert hd(violations).form == :apply
    end

    test "detects a fully qualified apply/3 with a literal protected store" do
      source = """
      defmodule Bad do
        def go(repo, company, attrs) do
          apply(Ankole.WorkHierarchy.TaskStore, :create_task, [repo, company, attrs])
        end
      end
      """

      violations = source_violations(source, "synthetic")

      assert length(violations) == 1
      assert hd(violations).function == :create_task
      assert hd(violations).form == :apply
    end

    test "accepts a clean production source" do
      source = """
      defmodule Good do
        alias Ankole.WorkHierarchy.TaskStore

        def read(repo, company, task) do
          TaskStore.fetch_task(repo, company, task)
        end

        def listed(repo, company) do
          TaskStore.list_company_tasks(repo, company)
        end

        def applicable(repo, company, task, uid) do
          TaskStore.validate_assignment_eligibility(repo, task, uid, company)
        end
      end
      """

      assert source_violations(source, "synthetic") == []
    end

    test "accepts a read of a W2 schema, which is not a mutation" do
      source = """
      defmodule Good do
        alias Ankole.WorkHierarchy.MissionRevision

        def any?(repo, agent) do
          Repo.exists?(from r in MissionRevision, where: r.assigned_agent_uid == ^agent)
        end
      end
      """

      assert source_violations(source, "synthetic") == []
    end

    test "an unparseable source is reported rather than silently passing" do
      violations = source_violations("defmodule Broken do", "synthetic")

      assert length(violations) == 1
      assert hd(violations).form == :parse_error
    end
  end

  # ─── Layering guard ──────────────────────────────────────────────────────

  describe "boundary: W2 does not depend on W3" do
    test "no W2 source references a W3 concept" do
      offenders =
        w2_files()
        |> Enum.flat_map(fn path ->
          source = File.read!(path)

          for concept <- @w3_concepts,
              String.contains?(source, concept),
              do: "#{Path.relative_to(path, @repo_root)} references #{concept}"
        end)

      assert offenders == [],
             """
             W2 must remain independent from W3. Offending source(s):

             #{Enum.join(offenders, "\n")}
             """
    end
  end

  # ─── Scan helpers ────────────────────────────────────────────────────────

  defp w2_files do
    Path.wildcard(Path.join(@app_root, "lib/ankole/work_hierarchy/*.ex"))
  end

  defp p8_path, do: Path.join(@app_root, "lib/ankole/w3/p8_controlled_action.ex")

  # Checked-in production Elixir sources: the core application library and
  # every shipped plugin library. mix.exs compiles both plugin trees into every
  # environment including :prod, so plugin code is production code.
  defp production_files do
    core = Path.wildcard(Path.join(@app_root, "lib/**/*.ex"))
    plugins = Path.wildcard(Path.join(@repo_root, "plugins/*/lib/**/*.ex"))
    internal_plugins = Path.wildcard(Path.join(@repo_root, "internals/plugins/*/lib/**/*.ex"))

    excluded =
      MapSet.new(
        Enum.map(@store_files, &Path.join(@app_root, "lib/ankole/work_hierarchy/#{&1}")) ++
          [p8_path()]
      )

    (core ++ plugins ++ internal_plugins)
    |> Enum.reject(&MapSet.member?(excluded, &1))
    |> Enum.sort()
  end

  defp production_violations do
    production_files()
    |> Enum.flat_map(fn path ->
      source = File.read!(path)

      source_violations(source, Path.relative_to(path, @repo_root))
    end)
  end

  defp format_violation(violation) do
    "#{violation.file}:#{violation.line || 0} — #{violation.module}.#{violation.function}/" <>
      "#{violation.arity} (#{violation.form})"
  end

  # ─── AST scanner ─────────────────────────────────────────────────────────
  #
  # Deterministic standard-library AST inspection. It resolves module
  # references through `alias` and `alias ... as:` declarations, honours
  # `import` for unqualified calls, and inspects `apply/3`. Deliberate
  # metaprogramming and hostile runtime code are out of scope; every static
  # spelling an ordinary production caller would write is covered.

  defp source_violations(source, file) do
    case Code.string_to_quoted(source) do
      {:ok, ast} ->
        aliases = collect_aliases(ast)
        imports = collect_imports(ast, aliases)

        ast
        |> collect_calls(aliases, imports)
        |> Enum.filter(&protected?/1)
        |> Enum.map(&Map.put(&1, :file, file))

      {:error, reason} ->
        [%{
          module: "(unparsed)",
          function: :none,
          arity: :unknown,
          form: :parse_error,
          line: nil,
          file: file,
          detail: reason
        }]
    end
  end

  # `alias A.B.C` compiles to {:alias, meta, [{:__aliases__, _, [:A, :B, :C]}]}.
  # `alias A.B.C, as: D` appends the option list, giving a two-element list.
  # `import` uses the same shape.
  defp alias_parts({:__aliases__, _, parts}), do: parts
  defp alias_parts(_other), do: nil

  defp alias_opts([_callee, opts]) when is_list(opts), do: opts
  defp alias_opts([_callee]), do: nil
  defp alias_opts(_other), do: nil

  # The `as:` short name when present, otherwise the final path segment.
  # Both forms are normalised to a string so that a lookup built from a
  # call-site alias reference always finds the recorded alias.
  defp alias_short_name(parts, opts) do
    case Keyword.fetch(opts || [], :as) do
      {:ok, {:__aliases__, _, as_parts}} -> Enum.join(as_parts, ".")
      _ -> parts |> List.last() |> to_string()
    end
  end

  defp collect_aliases(ast) do
    {_ast, aliases} =
      Macro.prewalk(ast, %{}, fn
        {:alias, _, whole} = node, acc when is_list(whole) ->
          case whole |> List.first() |> alias_parts() do
            nil ->
              {node, acc}

            parts ->
              short = alias_short_name(parts, alias_opts(whole))
              {node, Map.put(acc, short, Enum.join(parts, "."))}
          end

        node, acc ->
          {node, acc}
      end)

    aliases
  end

  defp collect_imports(ast, aliases) do
    {_ast, imports} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:import, _, whole} = node, acc when is_list(whole) ->
          case whole |> List.first() |> alias_parts() do
            nil ->
              {node, acc}

            parts ->
              module = resolve(Enum.join(parts, "."), aliases)

              entries =
                case Keyword.fetch(alias_opts(whole) || [], :only) do
                  {:ok, only} when is_list(only) ->
                    Enum.map(only, fn {name, arity} -> {module, name, arity} end)

                  _ ->
                    [{:all, module}]
                end

              {node, Enum.reduce(entries, acc, &MapSet.put(&2, &1))}
          end

        node, acc ->
          {node, acc}
      end)

    imports
  end

  defp collect_calls(ast, aliases, imports) do
    {_ast, calls} =
      Macro.prewalk(ast, [], fn node, acc ->
        case call_entry(node, aliases, imports) do
          :skip -> {node, acc}
          entry -> {node, [entry | acc]}
        end
      end)

    calls
  end

  defp call_entry({:apply, meta, [module_ast, fun, args_ast]}, aliases, _imports)
       when is_atom(fun) do
    case resolve_module(module_ast, aliases) do
      nil -> :skip
      module -> violation(module, fun, literal_arity(args_ast), :apply, meta)
    end
  end

  defp call_entry({{:., _, [module_ast, fun]}, meta, args}, aliases, _imports)
       when is_atom(fun) and is_list(args) do
    case resolve_module(module_ast, aliases) do
      nil -> :skip
      module -> violation(module, fun, length(args), :qualified_call, meta)
    end
  end

  # An unqualified local call, which is only a violation when that exact
  # function was imported from a protected store. AST special forms such as
  # `defmodule` and `def` are tuples of the same shape but are not calls, so
  # they are excluded by name.
  @ast_special_forms ~w(
    __MODULE__ __DIR__ __ENV__ __CALLER__ __STACKTRACE__
    def defp defmacro defmacrop defguard defguardp defdelegate defstruct
    defimpl defprotocol defoverridable defexception
    alias import require use
    module __block__ __aliases__ when with for cond case try receive quote unquote unquote_splicing
    fn do end super
    true false nil
  )a

  defp call_entry({fun, meta, args}, _aliases, imports)
       when is_atom(fun) and is_list(args) do
    arity = length(args)

    if fun in @ast_special_forms do
      :skip
    else
      case importing_module(imports, fun, arity) do
        nil -> :skip
        module -> violation(module, fun, arity, :imported_call, meta)
      end
    end
  end

  defp call_entry(_node, _aliases, _imports), do: :skip

  defp violation(module, fun, arity, form, meta) do
    %{
      module: module,
      function: fun,
      arity: arity,
      form: form,
      line: line_of(meta)
    }
  end

  defp resolve_module({:__aliases__, _, parts}, aliases) do
    joined = Enum.join(parts, ".")
    resolved = resolve(joined, aliases)

    if Map.has_key?(@protected, resolved), do: resolved, else: nil
  end

  defp resolve_module(_other, _aliases), do: nil

  defp resolve(name, aliases) do
    case Map.fetch(aliases, name) do
      {:ok, full} -> full
      :error -> name
    end
  end

  # Returns the protected store module that supplies `fun`/`arity` through an
# import, or nil. Returning the module (rather than a boolean) lets the
# violation carry the real store name, so it survives the protected?/1 filter.
  defp importing_module(imports, fun, arity) do
    Enum.find_value(imports, fn
      {:all, module} ->
        if @protected[module] && match_arity?(@protected[module], fun, arity), do: module

      {module, imported_fun, imported_arity} ->
        if @protected[module] && imported_fun == fun && imported_arity == arity, do: module

      _other ->
        nil
    end)
  end

  defp match_arity?(funs, fun, arity) do
    case funs[fun] do
      nil -> false
      arities -> arity in arities
    end
  end

  # A static argument list gives an exact arity. A non-literal list means the
  # arity is unknown, so any protected function name is treated as a
  # violation rather than being waved through.
  defp literal_arity(args_ast) when is_list(args_ast), do: length(args_ast)
  defp literal_arity(_other), do: :unknown

  defp protected?(violation) do
    case get_in(@protected, [violation.module, violation.function]) do
      nil -> false
      arities -> violation.arity == :unknown or violation.arity in arities
    end
  end

  defp line_of(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp line_of(_other), do: nil
end