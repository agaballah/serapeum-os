# SerapeumOS — Project Bootstrap Guide

## What is this repository?

This repository is **SerapeumOS**, an independent public open-source downstream project
currently based on **Ankole v1.0.4-rc.1**.

**Locked foundation baseline:** `7434d934315881438d4788d41228ba31d2f26fbb`

**GitHub:** https://github.com/agaballah/serapeum-os

## Repository truth rule

**GitHub/repository content is the permanent authoritative source of truth for SerapeumOS.**

Chat history, model memory, Kilo history, or any individual AI session must NOT be
required to reconstruct the project. A fresh capable AI with zero prior conversation
history must be able to read this repository and reconstruct everything below.

If an important decision exists only in chat, it is not yet durable project truth.

## Mandatory reading order for a fresh Project Manager

Read these files in this exact order before any other action:

1. **AGENTS.md** — SerapeumOS project overlay and instruction precedence
2. **PROJECT_BOOTSTRAP.md** — this file
3. **PROJECT_STATE.md** — current project status and milestones
4. **docs/serapeumos/PROJECT_CONSTITUTION.md** — highest durable governance document
5. **docs/serapeumos/OWNER_CHARTER.md** — Owner authority and Gold Rules
6. **docs/serapeumos/PROJECT_MANAGER_CONTRACT.md** — Project Manager role contract
7. **docs/serapeumos/OWNER_COMMUNICATION_CONTRACT.md** — Owner interaction rules
8. **docs/serapeumos/DOCTRINE.md** — normative product doctrine
9. **docs/serapeumos/architecture/00_MASTER_ARCHITECTURE.md** — architecture index and crosswalk
10. **docs/serapeumos/architecture/01_HOST_INTEGRITY_AND_TCB.md** through `20_QUALIFICATION_RELEASE_GATES.md` — closed MA documents
11. **docs/serapeumos/DECISION_LOG.md** — chronological decision register (D-001 through D-266)
12. **docs/serapeumos/ROADMAP.md** — gate-level roadmap
13. **docs/serapeumos/agent/EXECUTION_AGENT_CONTRACT.md** — execution agent role contract
14. **docs/serapeumos/agent/EVIDENCE_AND_COMPLETION_CONTRACT.md** — evidence standards
15. **applicable AGENTS.md files** — before modifying any source code
16. **assigned task file** — the specific task specification governing current work

Every new Project Manager session must adopt:

- Project Constitution
- Project Manager Contract
- Owner Communication Contract
- Execution Agent Contract
- Evidence and Completion Contract

before managing the project.

## Authority precedence

1. **Explicit current Owner instruction**
2. **PROJECT_CONSTITUTION.md**
3. Current SerapeumOS governance and locked decisions:
   - OWNER_CHARTER.md
   - PROJECT_MANAGER_CONTRACT.md
   - OWNER_COMMUNICATION_CONTRACT.md
   - DOCTRINE.md
   - ARCHITECTURE_BASELINE.md (historical pre-MA baseline; cannot override closed MA architecture)
   - DECISION_LOG.md
   - Closed MA documents (`docs/serapeumos/architecture/01_*.md` through `20_*.md`)
4. **SerapeumOS root AGENTS overlay**
5. **Inherited Ankole AGENTS instructions** for inherited implementation areas
   where SerapeumOS has not explicitly superseded them

If two documents at the same precedence level materially conflict: STOP AND
ESCALATE TO PROJECT MANAGER / OWNER AS APPROPRIATE. Do not silently choose.

## Current status

See **PROJECT_STATE.md** for the current phase, completed gates, blockers, and next action.

## Before modifying source code

Always read the applicable `AGENTS.md` at the root and in the relevant subdirectory
before making any changes to source files.
