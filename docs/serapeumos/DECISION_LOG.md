# Decision Log

Chronological register of locked project decisions. Each entry is ordered by
project sequence ID. Dates are recorded where historically exact; otherwise
sequence ID is the primary ordering key.

---

## D-001 — 100% Open Source and 100% Local target

- **Status:** LOCKED
- **Decision:** The final SerapeumOS system must be 100% open source and 100% local.
  No proprietary cloud infrastructure may be a required final dependency.
- **Reason:** The product vision requires full data sovereignty and elimination
  of mandatory cloud dependencies.
- **Supersession:** Only an explicit Owner-approved constitutional change may
  supersede this decision.

---

## D-002 — NaraRouter is temporary inference only

- **Status:** LOCKED
- **Decision:** NaraRouter is permitted temporarily during development and
  validation. It must remain replaceable by local AI.
- **Reason:** Temporary inference capability is needed during bootstrap while
  local inference stacks are being qualified.
- **Supersession:** None. NaraRouter is explicitly temporary by definition.

---

## D-003 — System capabilities model

- **Status:** LOCKED
- **Decision:** SerapeumOS capabilities = Function / Learn / Research / Evolve,
  with cross-cutting rails Observe/Evaluate and Govern/Protect.
- **Reason:** This model captures the full adaptive loop required for an
  autonomous digital organization.
- **Supersession:** Only via constitutional change.

---

## D-004 — Learning scope includes failure, success, and strategy

- **Status:** LOCKED
- **Decision:** System learning must include failures, successes, repeated
  patterns, corrections, outcomes, and strategy performance. It must also
  identify successful strategies and determine what worked, under which
  conditions, whether it generalizes, and when it should be revalidated.
- **Reason:** Limiting learning to "lessons learned from failures" misses
  positive pattern recognition and strategy adoption.
- **Supersession:** Only via constitutional change.

---

## D-005 — Gate 1 PASS

- **Status:** LOCKED
- **Decision:** Most hard infrastructure already exists across open source
  projects. No single known OSS project implements the complete SerapeumOS
  target.
- **Reason:** Gate 1 question: "Has somebody already built most of this?"
- **Supersession:** N/A — gate result.

---

## D-006 — Gate 2 PASS

- **Status:** LOCKED
- **Decision:** Existing OSS should be reused aggressively instead of rebuilding.
- **Reason:** Gate 2 question: "Should existing OSS be reused instead of
  rebuilding everything?"
- **Supersession:** N/A — gate result.

---

## D-007 — Foundation Composition PASS — Ankole selected

- **Status:** LOCKED
- **Decision:** Ankole v1.0.4-rc.1 is selected as the primary low-level
  foundation for SerapeumOS.
- **Reason:** Ankole provides the required identity, AuthZ, Brain, jobs,
  workflow, scheduling, and runtime infrastructure.
- **Supersession:** Only via an explicit Owner-approved foundation change.

---

## D-008 — Cyber AI Team and Paperclip are references, not runtimes

- **Status:** LOCKED
- **Decision:** Cyber AI Team and Paperclip are reference/architectural
  adaptation sources. They are NOT parallel control planes or second runtimes.
- **Reason:** Running two control planes would duplicate identity, AuthZ,
  and execution infrastructure, violating the low-diff principle.
- **Supersession:** Only via constitutional change.

---

## D-009 — SerapeumOS directly owns four differentiated domains

- **Status:** LOCKED
- **Decision:** SerapeumOS directly owns its differentiated product/governance
  domains: Company Domain, System Evolution, Action Assurance, and Owner
  Governance.
- **Reason:** These four layers express the product differentiation and
  are not provided by Ankole in the required form. Other capabilities may come
  from Ankole or from other supporting OSS components selected through bounded
  integrations; not every non-SerapeumOS capability must come from Ankole.
- **Supersession:** Only via architectural decision gate.

---

## D-010 — Product name

- **Status:** LOCKED
- **Decision:** Product name is SerapeumOS.
- **Reason:** Selected by the Owner.
- **Supersession:** Only via explicit Owner decision.

---

## D-011 — Public repository

- **Status:** LOCKED
- **Decision:** Public repository is agaballah/serapeum-os on GitHub.
- **Reason:** Owner's GitHub account is agaballah.
- **Supersession:** Only via explicit Owner decision.

---

## D-012 — Independent downstream, not GitHub fork

- **Status:** LOCKED
- **Decision:** SerapeumOS is an independent downstream repository that
  preserves complete Ankole Git ancestry. It is NOT a GitHub fork.
- **Reason:** An independent repository gives SerapeumOS full governance
  autonomy while preserving provenance.
- **Supersession:** Only via constitutional change.

---

## D-013 — Qualified foundation commit

- **Status:** LOCKED
- **Decision:** Qualified foundation = Ankole v1.0.4-rc.1 at exact commit
  7434d934315881438d4788d41228ba31d2f26fbb.
- **Reason:** This is the architecture-qualified baseline commit selected
  by the foundation qualification process.
- **Supersession:** Only via an explicit foundation requalification decision.

---

## D-014 — GitHub/repository as permanent project memory

- **Status:** LOCKED
- **Decision:** GitHub/repository content is the permanent authoritative
  source of truth for SerapeumOS. Chat history and model memory are
  ephemeral.
- **Reason:** A fresh capable AI with zero prior conversation history must
  be able to reconstruct the project solely from the repository.
- **Supersession:** Only via constitutional change.

---

## D-015 — Current development workspace

- **Status:** LOCKED
- **Decision:** Current development workspace is D:\SerapeumOS on Windows
  using VS Code + Kilo. No WSL or Docker requirement is locked at this phase.
- **Reason:** Direct Windows development matches the existing workflow.
  Toolchains are installed only when an approved task proves they are required.
- **Supersession:** Can be changed by the Project Manager without Owner
  approval, as long as the change does not violate Gold Rule #1.

---

## D-016 — SerapeumOS governance precedence over inherited repository rules

- **Status:** LOCKED
- **Decision:** SerapeumOS governance controls SerapeumOS project/repository
  management. Inherited Ankole engineering instructions remain applicable to
  inherited Ankole implementation areas except where explicitly superseded by
  SerapeumOS governance.
  Ankole-specific changelog/version/release requirements do not automatically
  apply to SerapeumOS-only governance/project-memory commits.
- **Reason:** SerapeumOS is an independent downstream product. Automatically
  applying upstream Ankole repository-release semantics to all SerapeumOS
  commits would incorrectly make SerapeumOS governance changes look like
  Ankole product releases and creates conflicting authority.
- **Supersession:** Only through an explicit Owner-approved repository-governance
  decision.
