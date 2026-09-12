# TASK-008 — Repository Hygiene / Implementation-Readiness Audit

Status: AUTHORIZED — READ-ONLY AUDIT

Authority:
- Owner
- D-269
- PROJECT_MANAGER_CONTRACT.md — Repository-First Response Gate
- IMPLEMENTATION_DECOMPOSITION_BASELINE.md — Mandatory Pre-Implementation Hygiene Gate

Authorization-parent baseline:
78e68baabbeb9b00855dab6fd02139da0ba5da36

Audit execution baseline:

At the beginning of TASK-008 execution, the execution agent MUST verify the
current canonical `origin/main` / `main` HEAD.

That exact verified SHA becomes TASK-008_EXECUTION_BASELINE.

All isolated empirical hygiene/build/test work must be performed from a
disposable clone checked out at TASK-008_EXECUTION_BASELINE.

The audit must evaluate current repository truth at TASK-008_EXECUTION_BASELINE,
not the historical authorization-parent SHA.

The report must explicitly record:

- AUTHORIZATION_PARENT_BASELINE
- TASK-008_EXECUTION_BASELINE
- confirmation that execution baseline == canonical origin/main at audit start

If canonical main changes after TASK-008 execution begins:

- do NOT silently move the audit baseline;
- record repository drift;
- stop any conclusion that depends on the changed content;
- report the drift to the Project Manager for disposition.

Canonical D:\SerapeumOS remains read-only.

_archsync_input/ remains untouched and uninspected.

OBJECTIVE:

Determine whether the repository is sufficiently clean, truthful, reproducible,
navigable, attributable, and baseline-stable to begin SerapeumOS product
implementation.

The audit must discover and classify hygiene problems.
It must NOT fix them.

--------------------------------------------------
AUDIT SAFETY RULES
--------------------------------------------------

Canonical workspace:
D:\SerapeumOS

The audit is READ-ONLY with respect to canonical tracked content.

Do NOT:
- edit tracked files
- stage
- commit
- reset
- clean
- stash
- rebase
- delete
- rename
- move
- rewrite history
- install system-level software
- change dependency versions
- regenerate lockfiles
- modify architecture/governance
- inspect, modify, or delete _archsync_input/
- perform product implementation

Do not assume inherited Ankole material is obsolete merely because it is inherited.

Every cleanup candidate must be classified and evidenced first.

If empirical build/test execution would write generated/cache/build artifacts,
perform it only in an isolated disposable clone outside D:\SerapeumOS.

Preferred isolated audit workspace:

D:\SerapeumOS_HYGIENE_AUDIT

Create it from the exact authorized commit.

Do not copy canonical untracked files into it.

If a command requires downloading/installing additional system software or
otherwise exceeds ordinary existing project tooling, STOP that probe and record
BLOCKED + exact prerequisite.

Do not hide failures.
Do not rerun until green.

--------------------------------------------------
AUDIT COVERAGE
--------------------------------------------------

A. REPOSITORY TRUTH / DOCUMENTATION HYGIENE

Inspect:
- PROJECT_STATE
- ROADMAP
- task register
- decision log
- bootstrap/navigation docs
- root README
- root AGENTS and inherited AGENTS hierarchy
- active task references
- stale task/spec pointers
- obsolete phase wording
- contradictory status statements
- broken internal document links
- stale names/paths/version claims

Identify anything that could cause a fresh coding agent to act on stale truth.

--------------------------------------------------
B. ACTIVE / HISTORICAL / INHERITED CLASSIFICATION
--------------------------------------------------

Classify relevant repository areas/artifacts as one of:

ACTIVE_SERAPEUMOS
ACTIVE_INHERITED_REQUIRED
HISTORICAL_EVIDENCE
REFERENCE_ONLY
GENERATED_REBUILDABLE
STALE_CANDIDATE
UNKNOWN_REQUIRES_REVIEW

Do NOT classify something STALE_CANDIDATE without exact evidence.

Especially inspect whether inherited Ankole docs/config/examples/scripts could
mislead SerapeumOS implementation agents.

--------------------------------------------------
C. GENERATED / BUILD / RUNTIME CLUTTER
--------------------------------------------------

Audit:
- tracked generated outputs
- accidentally committed caches
- build outputs
- runtime data
- local databases
- logs
- coverage
- temporary files
- editor artifacts
- packaging artifacts
- large binary artifacts
- stale snapshots

Review .gitignore coverage.

Report tracked versus untracked separately.

Do not inspect _archsync_input/.

--------------------------------------------------
D. DEPENDENCY / BUILD / CONFIG HYGIENE
--------------------------------------------------

Audit:
- bun.lock consistency
- workspace configuration
- package manifests
- Elixir dependencies
- Rust dependencies
- duplicated/conflicting dependency declarations
- stale scripts
- impossible commands
- config inconsistencies
- environment assumptions
- hard-coded paths
- development-only dependencies accidentally implied as production requirements

Do not update dependencies.

--------------------------------------------------
E. BASELINE BUILD / TEST HEALTH
--------------------------------------------------

Determine the actual current validation surfaces from repository scripts/config.

Do not invent a global test count.

In isolated disposable clone only, execute the safest existing baseline checks
that can run using already-available tooling.

Examples only if actually defined/supported by repository:
- formatting/check commands
- lint
- type-check
- compilation
- bounded test suites
- Rust checks/tests
- Elixir compile/tests
- Bun/TypeScript validation

Do not blindly run every command.

Build a validation matrix:

CHECK
REPOSITORY COMMAND/SOURCE
EXECUTED?
RESULT
DURATION
BLOCKER
NOTES

Distinguish:
PASS
FAIL
BLOCKED
NOT_RUN_WITH_RATIONALE

A pre-existing failure is hygiene evidence, not permission to repair it.

--------------------------------------------------
F. LICENSING / ATTRIBUTION / UPSTREAM PROVENANCE
--------------------------------------------------

Audit:
- root LICENSE
- notices/attribution
- inherited Ankole licensing obligations
- dependency license/provenance metadata available in repo
- upstream remote/baseline references
- SerapeumOS downstream identity
- copied/reference architecture attribution where applicable

Do not make legal guarantees.

Classify:
CLEAR_FROM_REPO_EVIDENCE
MISSING_OR_INCOMPLETE
REQUIRES_LEGAL_REVIEW

--------------------------------------------------
G. NAMING / PATH CONSISTENCY
--------------------------------------------------

Audit current active code/docs for misleading:
- Ankole vs SerapeumOS naming
- old package/product identifiers
- stale repository URLs
- stale local paths
- obsolete branch names
- obsolete version identifiers
- references to non-existing paths

Do not propose cosmetic mass-renaming.

Only flag names that materially affect implementation/release correctness,
user-facing identity, packaging, provenance, or agent navigation.

--------------------------------------------------
H. BRANCH / WORKTREE / REPOSITORY STATE HYGIENE
--------------------------------------------------

Record canonical:
- HEAD
- branch
- origin/main
- remotes
- tracked modifications
- staged changes
- untracked top-level entries WITHOUT inspecting _archsync_input/
- branches relevant to current work
- tags
- submodules if any
- Git LFS usage if any

Identify stale assumptions or unexpected active state.

Do not delete branches.

--------------------------------------------------
I. ACTIVE VS HISTORICAL ARTIFACT SEPARATION
--------------------------------------------------

Check whether a fresh implementation agent can distinguish:
- controlling governance
- controlling architecture
- implementation baseline
- historical audits
- superseded evidence
- reference architecture/material
- generated outputs

Flag ambiguity that could lead to implementation against historical material.

--------------------------------------------------
J. IMPLEMENTATION-AGENT NAVIGATION / READINESS
--------------------------------------------------

Starting from repository root as a fresh Kilo/Codex agent:

Can the agent determine, without chat memory:
- what SerapeumOS is
- current phase
- current task
- authority hierarchy
- architecture reading order
- implementation baseline
- first blocked workstream
- hygiene gate requirement
- what must not be modified
- testing/build entry points
- inherited Ankole instruction precedence

Report all navigation failures or ambiguity.

--------------------------------------------------
K. SECURITY / SECRET HYGIENE — PASSIVE ONLY
--------------------------------------------------

Using safe repository inspection only, identify evidence of:
- committed credential-like files
- .env files
- private-key file names
- obvious hard-coded secret placeholders versus actual suspected secrets
- unsafe example credentials
- sensitive local paths

Do NOT print secret values.

If suspected real credential material is found:
report path/type/severity only and STOP further content exposure.

Do not access external secret stores.

--------------------------------------------------
FINDING FORMAT
--------------------------------------------------

Every finding must have stable ID:

HYGIENE-001, HYGIENE-002, ...

Fields:

- ID
- Area
- Severity:
  BLOCKER / HIGH / MEDIUM / LOW / INFO
- Classification:
  ACTIVE_REQUIRED
  SAFE_FIX_CANDIDATE
  SAFE_REMOVAL_CANDIDATE
  HISTORICAL_KEEP
  REFERENCE_KEEP
  GENERATED_REBUILDABLE
  UNKNOWN_REQUIRES_REVIEW
- Exact evidence
- Exact path(s)
- Why it matters before coding
- Recommended action
- Destructive risk
- Dependency / prerequisite
- Proposed later repair boundary
- Hygiene Gate impact:
  BLOCKS_GATE / DOES_NOT_BLOCK_GATE / REVIEW_REQUIRED

No repair is authorized by TASK-008.

--------------------------------------------------
REQUIRED SUMMARY
--------------------------------------------------

Return:

1. Executive verdict:
   HYGIENE_GATE_READY
   or
   HYGIENE_REPAIRS_REQUIRED
   or
   AUDIT_BLOCKED

This is an audit recommendation only.
PM makes the actual Hygiene Gate decision.

2. Repository-state baseline

3. Findings register

4. Build/test baseline matrix

5. Licensing/provenance assessment

6. Documentation/navigation assessment

7. Generated/clutter assessment

8. Naming/path assessment

9. Secret-hygiene assessment

10. Proposed bounded repair batches, if any

11. Explicit list:
   MUST FIX BEFORE CODING

12. Explicit list:
   CAN DEFER UNTIL LATER

13. No-change proof for canonical D:\SerapeumOS

14. Isolated audit workspace disposition

End exactly:

READY FOR PROJECT MANAGER HYGIENE AUDIT REVIEW
