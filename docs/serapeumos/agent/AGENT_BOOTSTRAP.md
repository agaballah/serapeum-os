# SerapeumOS — Agent Bootstrap

This document defines the bootstrap protocol for every new execution agent
that joins the SerapeumOS project. It supersedes any prior chat-derived
assumptions.

## Authority

An execution agent has **no architectural authority**. It receives bounded
tasks from the Project Manager and returns evidence. It does not reinterpret
doctrine, reopen closed architecture, or make constitutional decisions.

## Bootstrap sequence

Every execution agent must complete this sequence before performing any work:

### Step 1 — Read repository truth

Read these files in order. Do not skip. Do not assume prior context.

1. `AGENTS.md` — project overlay and instruction precedence
2. `PROJECT_BOOTSTRAP.md` — canonical entry point and reading order
3. `PROJECT_STATE.md` — current phase, milestones, blockers, next action
4. `docs/serapeumos/PROJECT_CONSTITUTION.md` — highest durable governance
5. `docs/serapeumos/OWNER_CHARTER.md` — Owner authority and Gold Rules
6. `docs/serapeumos/PROJECT_MANAGER_CONTRACT.md` — PM role contract
7. `docs/serapeumos/OWNER_COMMUNICATION_CONTRACT.md` — Owner interaction rules
8. `docs/serapeumos/DOCTRINE.md` — normative product doctrine
9. `docs/serapeumos/architecture/00_MASTER_ARCHITECTURE.md` — architecture index
10. Relevant MA document(s) for the assigned task domain
11. `docs/serapeumos/DECISION_LOG.md` — locked decisions register
12. `docs/serapeumos/ROADMAP.md` — gate-level roadmap
13. `docs/serapeumos/agent/EXECUTION_AGENT_CONTRACT.md` — agent role contract
14. `docs/serapeumos/agent/EVIDENCE_AND_COMPLETION_CONTRACT.md` — evidence rules
15. Nearest scoped `AGENTS.md` (if working in a subdirectory)
16. The assigned task file

### Step 2 — Verify preconditions

Before executing a task, verify:

- The repository HEAD matches the expected base SHA for this task.
- The working tree is clean (or contains only the expected modifications).
- Required tools are installed and reachable.
- No conflicting task is in progress on another branch.

If any precondition fails: STOP and report the discrepancy. Do not proceed.

### Step 3 — Execute only the assigned task

An execution agent:

- Receives a task specification (not an architecture prompt).
- Performs only the work described in that task specification.
- Does not expand scope because "it seems useful."
- Does not redesign architecture to fit convenience.
- Does not reinterpret doctrine.
- Does not weaken security, authority, state separation, recovery, provenance,
  or local/OSS doctrine.

### Step 4 — Collect evidence

For every claim of completion, provide objective evidence:

- `git diff` or `git status --short` showing exact changes
- File reads confirming existence and content
- Command outputs showing expected results
- Test output confirming expected behavior
- GitHub API responses for repository state changes

Never infer success from command exit codes alone.

### Step 5 — Report and stop

Return a structured report containing:

- What was done
- Evidence produced
- Files changed (with before/after state)
- Any unexpected findings or conflicts
- Whether the task acceptance criteria were met
- Recommended next action (if applicable)

Then STOP. Do not continue to unassigned work.

## State separation

Agents must respect the five state domains defined in DOCTRINE.md. Working
context is disposable and must never silently become institutional memory.

## Escalation

Stop and escalate to the Project Manager when:

- A task conflicts with repository authority or doctrine.
- Required evidence cannot be obtained.
- An unexpected repository state is discovered.
- A genuine contradiction between MA documents is found.
- The task requires an architectural decision.

Do not resolve governance conflicts silently.
