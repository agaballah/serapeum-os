# Architecture Baseline — HISTORICAL PRE-MA BASELINE

> This document records the historical pre-MA baseline architecture.
> It remains useful provenance and history, but it is no longer the current
> normative master architecture.
>
> Current architecture authority is:
> - `00_MASTER_ARCHITECTURE.md` — cross-domain architecture index
> - Closed MA-01 → MA-20 documents (`docs/serapeumos/architecture/01_*.md` through `20_*.md`)
> - Current governance and locked decision records (`DECISION_LOG.md`, `PROJECT_MANAGER_CONTRACT.md`, etc.)
>
> Do not treat this document as the active architecture source for new decisions.

## Core mental model

```
OWNER
  |
AI SUPERVISOR
  |
AI MANAGERS
  |
AI SPECIALISTS
  |
AI REVIEWERS
```

All agents use shared company infrastructure rather than one giant shared context.

## Fundamental adaptive capabilities

| Capability | Description |
|---|---|
| FUNCTION | Execute tasks, run workflows, produce outputs |
| LEARN | Acquire knowledge from failures, successes, and patterns |
| RESEARCH | Monitor external environment for relevant changes |
| EVOLVE | Safely apply learned strategies and corrections |

## Cross-cutting rails

| Rail | Description |
|---|---|
| OBSERVE / EVALUATE | Continuous monitoring of outcomes and environment |
| GOVERN / PROTECT | Authorization, security, and compliance enforcement |

## Durable substrate

| Substrate | Description |
|---|---|
| MEMORY | Persistent storage of organizational and epistemic truth |
| PROVENANCE | Audit trails linking claims to their sources and evidence |

## The Private Digital Company

SerapeumOS operates a Private Digital Company on top of the adaptive system above.
The Company has:

- An Owner with final authority.
- AI roles (Supervisor, Managers, Specialists, Reviewers) with bounded responsibilities.
- Shared infrastructure for identity, context, tools, and durable state.
- Task and workflow mechanisms aligned to organizational goals.

## State separation

SerapeumOS architecture preserves five distinct state domains:

1. **Organizational Truth** — Company structure, Owner, roles, goals, missions,
   tasks, budgets, approvals.
2. **Execution Truth** — workflow state, retries, waits, crashes, cancellation,
   completion.
3. **Epistemic Truth** — sources, evidence, claims, confidence, contradictions,
   verification, decisions and supersession.
4. **Working Context** — prompts, retrieved context, tool output, disposable
   scratch context.
5. **System Evolution Truth** — experiences, lessons, strategies, experiments,
   benchmarks, environmental observations, regression signals.

Working Agent context is disposable. It is not institutional memory.

## System Evolution

System Evolution continuously improves bounded operating strategies through:

```
FUNCTION
  -> OBSERVE OUTCOMES
  -> INTERNAL LEARNING (+ EXTERNAL RESEARCH)
  -> STRATEGY CANDIDATES
  -> EXPERIMENT / EVALUATE
  -> EVOLVE SAFELY
  -> FUNCTION BETTER
  -> repeat
```

Self-improvement boundary: evolution may optimize strategy selection, Agent
composition, model mapping, review depth, retrieval strategy, tool sequencing,
retry policy, and resource budgets. It must NOT autonomously modify the Project
Constitution, Owner authority, authorization architecture, security architecture,
repository governance, core source architecture, or database schema.

## Action Assurance vs AuthZ

- **AuthZ** (Authorization) — determines whether a Principal/Agent is permitted
  to perform a class of action. Owned by Ankole's Principal/AuthZ subsystem.
  AuthZ answers: *Is this Principal/Agent permitted to perform this class of action?*

- **Action Assurance** — a SerapeumOS-owned governed lifecycle layer that wraps
  around AuthZ. It does NOT replace or duplicate AuthZ. AuthZ remains the
  permission-enforcement authority.

  Action Assurance answers these questions in order:

  1. *Is this exact proposed action sufficiently supported by evidence?*
  2. *Is it appropriately risk-classified?*
  3. *Does it require review, and has that review been completed?*
  4. *Has it been approved where approval is required?*
  5. *Does the execution match the approved proposal and its parameters exactly?*
  6. *What execution receipt or outcome was produced?*

  The governed lifecycle is:

  ```
  Action Proposal
    → evidence
    → risk classification
    → required review
    → approval where required
    → exact action/parameter binding
    → execution
    → execution receipt / outcome
  ```

  Action Assurance is NOT a second AuthZ engine. It enforces the governed
  lifecycle around actions that AuthZ has already permitted.

  Action Assurance sits above AuthZ and adds lifecycle governance that AuthZ
  alone does not provide.

## Foundation: Ankole

Ankole v1.0.4-rc.1 (`7434d934315881438d4788d41228ba31d2f26fbb`) is the approved
low-level foundation. It provides:

- Principal / Agent identity
- AuthZ (authorization)
- Brain (shared knowledge)
- Durable Jobs and scheduling
- Workflow engine
- Runtime recovery
- AIGateway
- Agent Computer (execution runtime)
- Generic execution infrastructure

SerapeumOS directly owns its differentiated product/governance domains:

- **Company Domain** — organizational structure, roles, goals, tasks.
- **System Evolution** — learning, research, strategy evaluation, safe evolution.
- **Action Assurance** — governed lifecycle enforcement across the full action chain.
- **Owner Governance** — constitutional rules and high-impact decision gates.

Ankole remains the primary low-level foundation for the capabilities selected
during the Foundation Composition Gate.

Other supporting OSS components may be reused through bounded integrations
where selected by architecture.

SerapeumOS must not rebuild an existing correct Ankole capability without an
evidenced architectural reason.

## Reference architectures (not parallel runtimes)

| Project | Role | Not |
|---|---|---|
| Cyber AI Team | Reference / architectural adaptation | A second runtime or control plane |
| Paperclip | Reference / architectural adaptation | A second runtime or control plane |

## Inference boundary

- **Development:** NaraRouter is permitted temporarily during development and
  validation.
- **Final system:** NaraRouter must be replaceable by local AI without redesigning
  Company, Agents, Brain, Tasks, Governance, System Evolution, or Action Assurance.
- **Gold Rule:** No other cloud inference provider becomes a required final
  dependency.

## Supporting OSS candidates (architectural selections, not installed dependencies)

These are architectural selections made during the Foundation Composition Gate.
They are NOT added as dependencies in this bootstrap phase.

| Candidate | Purpose |
|---|---|
| Inspect AI | Evaluation framework |
| OSV-Scanner | Vulnerability intelligence |
| Trivy | Security, SBOM, and license intelligence |
| iron-proxy | Controlled egress proxy |
| OpenTelemetry | Telemetry and observability |
| age | Local encryption at rest |

## Low-diff independent downstream rule

Local modifications must remain LOW-DIFF relative to upstream Ankole.
Project-owned domains should be isolated from upstream internals wherever practical.
Do not create duplicate infrastructure when Ankole already correctly owns the
capability.

Upstream changes must eventually pass controlled intake/revalidation rather than
being merged automatically.
