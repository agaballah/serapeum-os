# SerapeumOS — Project Reconstruction Protocol

This document defines the protocol for reconstructing project understanding
from repository truth alone. It is the standard against which Fresh-Agent
Reconstruction Validation is measured.

## Principle

A fresh capable AI with **zero prior SerapeumOS conversation history** must be
able to reconstruct the complete project from repository files alone.

If reconstruction requires chat history, model memory, or external context,
the repository governance has failed and must be repaired.

## Reconstruction checklist

A successful reconstruction must demonstrate understanding of:

### Product identity
- Product name: SerapeumOS
- Public repository: agaballah/serapeum-os
- Local path: read from PROJECT_STATE.md
- Git relationship: independent downstream, not a GitHub fork
- Product definition: read from PROJECT_BOOTSTRAP.md or PROJECT_CONSTITUTION.md

### Authority model
- Owner has final authority over doctrine, Constitution, Gold Rules, and
  high-impact approvals
- Project Manager is sole technical manager/architect accountable to Owner
- Execution agents are bounded workers, not architectural authority
- Instruction precedence order (Constitution > governance docs > AGENTS overlay >
  inherited Ankole instructions)

### Doctrine
- Gold Rule #1: SerapeumOS-owned components above host substrate must be 100%
  open source and 100% local; host OS is an external prerequisite
- NaraRouter is temporary development/validation inference only
- Platform-neutral core; host specifics behind adapters/brokers
- Agent ≠ Model ≠ Worker ≠ Appliance ≠ Process
- Five state domains remain separate; working context is disposable

### Foundation
- Selected foundation: Ankole v1.0.4-rc.1
- Locked baseline: `7434d934315881438d4788d41228ba31d2f26fbb`
- Production admission subject to MA-19 provenance and MA-20 qualification
- First qualification target/family: Windows 11 x86-64 (not yet empirically qualified)

### Architecture
- MA-01 through MA-20 are CLOSED / PASS
- Final Cross-Domain Consistency Audit is COMPLETE / PASS
- Four SerapeumOS-owned domains: Company, System Evolution, Action Assurance,
  Owner Governance
- Action Assurance vs AuthZ boundary is understood
- System Evolution safety boundary is understood

### Current state
- Current phase: read from PROJECT_STATE.md
- Current gate: read from PROJECT_STATE.md or ROADMAP.md
- Blockers: read from PROJECT_STATE.md
- Exact next action: read from PROJECT_STATE.md or ROADMAP.md
- Implementation: NOT STARTED until Final Master Architecture Gate passes
- Runtime prototypes: PAUSED until architecture gate authorizes empirical qualification

### Repository persistence status
- ARCH-SYNC-01 persistence state: read from PROJECT_STATE.md
- Repository persistence / verification state: read from PROJECT_STATE.md or ROADMAP.md
- Fresh-Agent Reconstruction Validation state: read from PROJECT_STATE.md or ROADMAP.md

### Security principles
- A compromised Agent runtime must not silently damage the host or Company state
- Durable authoritative state cannot be mutated directly by untrusted Agents
- Security and audit controls fail closed
- One hard Agent Appliance boundary is assigned to one Agent Principal at a time. The implementation/backend remains replaceable.

### Task execution rules
- Agents receive tasks, not architecture prompts
- Canonical task format includes: OBJECTIVE, AUTHORITY, PRECONDITIONS, SCOPE,
  FORBIDDEN, ACCEPTANCE CRITERIA, VALIDATION, EVIDENCE, STOP/ESCALATE, GIT HANDLING
- Completion requires: behavior implemented, architecture preserved, tests run,
  evidence verified, repository inspected, no scope expansion, evidence returned,
  PM acceptance

## Verification method

To validate reconstruction:

1. Start a fresh agent session with no prior SerapeumOS context.
2. Provide only the repository path and the instruction: "Read the repository
   and reconstruct the project."
3. Evaluate the output against the checklist above.
4. Record PASS or FAIL with specific gaps.

## Repair trigger

If reconstruction fails on any checklist item, the responsible document(s)
must be repaired before proceeding to the Final Master Architecture Gate.

## Reconstruction sequence

The required project sequence is:

1. ARCH-SYNC-01 — documentation/governance synchronization
2. Repository Persistence / Verification — confirm document-graph integrity,
   decision-ID continuity, reading-order resolution, and cross-file consistency
3. Fresh-Agent Reconstruction Validation — verify a new AI can reconstruct
   the project solely from repository files
4. Final Master Architecture / Design Gate — full gate review and PASS
5. Implementation Decomposition — decompose architecture into bounded tasks

The protocol must not instruct the agent to skip Repository Persistence /
Verification. Fresh-Agent Reconstruction Validation is not the immediate next
step after ARCH-SYNC-01 until repository persistence/verification passes.
