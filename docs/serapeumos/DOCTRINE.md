# SerapeumOS — Doctrine

This document contains the durable, normative product doctrine for SerapeumOS.
It is derived from the Owner Charter, Project Constitution, and the closed
MA-01 → MA-20 architecture. It is not a specification, experiment log, or
implementation plan.

## Product identity

SerapeumOS is a **local-first, open-source operating system for autonomous
digital organizations**.

The core mental model is a Private Digital Company:

```
OWNER
  ↓
AI SUPERVISOR
  ↓
AI MANAGERS
  ↓
AI SPECIALISTS
  ↓
AI REVIEWERS
```

Agents are persistent organizational identities. Models are replaceable
intelligence. Therefore:

```
Agent ≠ Model ≠ Worker ≠ Appliance ≠ Process
```

## Gold Rule #1

SerapeumOS-owned, required, distributed, and managed production components
**above the host substrate** must be:

1. **100% OPEN SOURCE** — no proprietary code locks or license restrictions on
   the final product.
2. **100% LOCAL** — no mandatory cloud infrastructure in the final product.

The **host operating system / native host substrate** is an external
prerequisite and does not itself have to be open source. Windows may therefore
remain a supported host target even though it is proprietary.

NaraRouter is the only temporary external inference dependency permitted during
development and validation. It must remain replaceable by local AI without
redesigning Company, Agents, Brain, Tasks, Governance, System Evolution, or
Action Assurance. It is **not** a final production dependency.

Internet access for research does **not** equal cloud dependency.

No other cloud service, hosted database, proprietary control plane, hosted
queue, SaaS memory, or mandatory Internet service may become a required final
dependency without an explicit Owner-approved constitutional change.

## Platform neutrality

SerapeumOS core architecture is **host-platform neutral**. Host-specific
security, runtime, and virtualization mechanisms sit behind bounded adapters
and brokers. The product must be operable on any host that satisfies the
prerequisites documented in `PREREQUISITES.md`.

Windows is the **first production qualification target/family**, not yet
empirically release-qualified. Qualification evidence belongs to MA-20.

## Adaptive capabilities

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

## Agent ≠ Model

Agent identity is persistent organizational identity. A model is replaceable
intelligence, not identity or authority. Swapping the underlying model must not
alter Agent identity, authorization, Company state, or durable output.

## State separation

Five distinct state domains must remain orthogonal and must not silently
promote content across domains:

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

## Foundation relationship

SerapeumOS is an **independent public downstream** of Ankole. It is NOT a
GitHub fork.

**Ankole v1.0.4-rc.1** at commit
`7434d934315881438d4788d41228ba31d2f26fbb` is the **architecture-selected,
locked foundation baseline**. Production admission remains subject to
MA-19 provenance verification and applicable MA-20 executable qualification.

SerapeumOS directly owns its differentiated domains:

- **Company Domain** — organizational structure, roles, goals, tasks.
- **System Evolution** — learning, research, strategy evaluation, safe evolution.
- **Action Assurance** — governed lifecycle enforcement across the full action chain.
- **Owner Governance** — constitutional rules and high-impact decision gates.

Reuse proven OSS instead of rebuilding correct generic infrastructure. Do not
duplicate a correct Ankole capability without an evidenced architectural reason.
Maintain LOW-DIFF relative to upstream Ankole.

## AuthZ vs Action Assurance

- **AuthZ** determines whether a Principal/Agent is permitted to perform a class
  of action. Owned by Ankole's Principal/AuthZ subsystem. AuthZ is the
  permission-enforcement authority.
- **Action Assurance** governs the full lifecycle around actions that AuthZ has
  permitted: evidence → risk classification → review → approval → exact action/
  parameter binding → execution → receipt/outcome. Action Assurance is NOT a
  second AuthZ engine.

## System Evolution safety boundary

System Evolution may optimize bounded operating strategies (strategy selection,
Agent composition, model mapping, review depth, retrieval strategy, tool
sequencing, retry policy, resource budgets).

It must NOT autonomously modify:

- This Constitution or Doctrine;
- Owner authority;
- Authorization architecture;
- Security architecture;
- Repository governance;
- Core source architecture;
- Database schema.

Architecture improvement proposals must become governed engineering proposals.

## Failure and host-safety principle

A model, Agent, task, Worker, prompt, generated program, browser workload,
plugin, tool, or other untrusted execution component may fail or become
compromised, but it must **not silently gain authority over the host or durable
Company state**.

Failure must remain bounded, observable, recoverable, and unable to broaden
authority. Durable authoritative state cannot be mutated directly by an
untrusted Agent.

Security and audit controls fail closed.

## Repository-as-project-memory

Repository content is the permanent authoritative SerapeumOS project memory.
Chat history, model memory, and isolated sessions are ephemeral. A fresh
capable AI with zero prior conversation history must be able to reconstruct
the project solely from the repository.

Important decisions must be written into the repository before they become
durable project truth.
