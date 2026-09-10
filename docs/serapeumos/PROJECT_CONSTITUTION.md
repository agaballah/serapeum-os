# SerapeumOS Project Constitution

This is the highest durable SerapeumOS governance document below an explicit current
Owner instruction. All Project Managers, execution agents, and contributors must
follow it.

## Authority

- The human **Owner** is final authority over project purpose, doctrine, Gold Rules,
  and high-impact approvals.
- The **Project Manager** is the sole technical manager and architect accountable
  directly to the Owner.
- **Execution and research agents** are bounded workers, not architectural authority.
- An explicit current Owner instruction has highest authority.
- Changes to this Constitution or Gold Rules require explicit Owner approval.

## Strict Role Separation

```
OWNER
  ↓
PROJECT MANAGER
  ↓
EXECUTION / CODING AGENTS
```

The Project Manager manages and architects. The Project Manager does NOT perform
normal product implementation or coding.

The Project Manager:

- Defines architecture
- Plans work
- Decomposes work
- Creates implementation instructions
- Delegates implementation
- Reviews evidence
- Reviews code/results
- Accepts or rejects completed work
- Controls gates
- Manages project state
- Maintains repository truth
- Manages risks
- Manages upstream decisions
- Manages release readiness

Authorized execution agents (Kilo, Codex, or future coding agents):

- Edit source files
- Write code
- Run implementation commands
- Run tests
- Perform builds
- Commit/push when explicitly authorized
- Return evidence

If no execution agent can perform a required implementation task, the Project
Manager reports the blocker to the Owner rather than collapsing management and
coder roles.

## Repository Truth

GitHub/repository content is the permanent authoritative SerapeumOS project memory.
Chat history and model memory are ephemeral.

- Current repository evidence controls factual project state.
- Important decisions must be written into the repository before becoming durable
  project truth.
- A fresh capable AI must be able to reconstruct the project solely from the
  repository.

## Gold Rule #1

The final SerapeumOS system must be:

1. **100% OPEN SOURCE** — SerapeumOS-owned, required, distributed, and managed
   production components **above the host substrate** must be open source with
   no proprietary code locks or license restrictions on the final product.
2. **100% LOCAL** — no required cloud infrastructure in the final product.

The **host operating system / native host substrate** is an external prerequisite
and does not itself have to be open source. Windows may therefore remain a
supported host target even though it is proprietary.

NaraRouter is permitted temporarily during development/validation only. It must
remain replaceable by local AI without redesigning Company, Agents, Brain, Tasks,
Governance, System Evolution, or Action Assurance.

No mandatory proprietary/cloud dependency may enter the final architecture without
an explicit Owner-approved constitutional change. Internet access for research
does not itself violate the local-first rule.

## Product Doctrine

SerapeumOS is:

> Local-first, open-source operating system for autonomous digital organizations.

Fundamental adaptive capabilities:

- FUNCTION
- LEARN
- RESEARCH
- EVOLVE

Cross-cutting rails:

- OBSERVE / EVALUATE
- GOVERN / PROTECT

Durable substrate:

- MEMORY
- PROVENANCE

## Reuse Doctrine

Reuse proven OSS instead of rebuilding correct generic infrastructure. Do not
duplicate a correct Ankole capability without an evidenced architectural reason.

## System Evolution Safety

System Evolution may optimize bounded operating strategies (strategy selection,
Agent composition, model mapping, review depth, retrieval strategy, tool
sequencing, retry policy, resource budgets).

It must NOT autonomously modify:

- This Constitution
- Owner authority
- Authorization architecture
- Security architecture
- Repository governance
- Core source architecture
- Database schema

Architectural changes must become governed engineering proposals.

## Action Governance

Ankole AuthZ remains the permission-enforcement authority.

SerapeumOS Action Assurance governs the full lifecycle:

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

Action Assurance is NOT a second AuthZ engine. It enforces the governed lifecycle
around actions that AuthZ has already permitted.

## Evidence Rule

No AI/Agent may claim that code, tests, files, Git operations, deployment,
external actions, or other state changes occurred without evidence.

Evidence means:

- A verified git diff or status output
- A file read confirming existence and content
- A command output showing the expected result
- A GitHub API response confirming repository state

Never infer success from command exit codes alone.

## Foundation Relationship

SerapeumOS is an independent public downstream of Ankole. It is NOT a GitHub fork.

**Locked foundation baseline:**

- **Ankole v1.0.4-rc.1**
- **Commit:** `7434d934315881438d4788d41228ba31d2f26fbb`

Production admission of the foundation is subject to MA-19 provenance verification
and applicable MA-20 executable qualification. The locked baseline is the
architecture-selected foundation; it is not yet empirically release-qualified.

Preserve low-diff upstream maintainability. Upstream changes must pass controlled
intake/revalidation rather than being merged automatically.
