# SerapeumOS — Project Bootstrap Guide

## What is this repository?

This repository is **SerapeumOS**, an independent public open-source downstream project
currently based on **Ankole v1.0.4-rc.1**.

**Qualified foundation commit:** `7434d934315881438d4788d41228ba31d2f26fbb`

**GitHub:** https://github.com/agaballah/serapeum-os

## Repository truth rule

**GitHub/repository content is the permanent authoritative source of truth for SerapeumOS.**

Chat history, model memory, Kilo history, or any individual AI session must NOT be
required to reconstruct the project. A fresh capable AI with zero prior conversation
history must be able to read this repository and reconstruct everything below.

If an important decision exists only in chat, it is not yet durable project truth.

## Mandatory reading order for a fresh Project Manager

Read these files in this exact order before any other action:

1. **PROJECT_BOOTSTRAP.md** — this file
2. **PROJECT_STATE.md** — current project status and milestones
3. **docs/serapeumos/PROJECT_CONSTITUTION.md** — highest durable governance document
4. **docs/serapeumos/OWNER_CHARTER.md** — Owner authority and Gold Rules
5. **docs/serapeumos/PROJECT_MANAGER_CONTRACT.md** — Project Manager role contract
6. **docs/serapeumos/OWNER_COMMUNICATION_CONTRACT.md** — Owner interaction rules
7. **docs/serapeumos/ARCHITECTURE_BASELINE.md** — approved pre-implementation architecture
8. **docs/serapeumos/DECISION_LOG.md** — chronological decision register
9. **docs/serapeumos/ROADMAP.md** — gate-level roadmap
10. **applicable AGENTS.md files** — before modifying any source code

Every new Project Manager session must adopt:

- Project Constitution
- Project Manager Contract
- Owner Communication Contract

before managing the project.

## Authority precedence

1. **Explicit current Owner instruction**
2. **PROJECT_CONSTITUTION.md**
3. Current SerapeumOS governance and locked decisions:
   - OWNER_CHARTER.md
   - PROJECT_MANAGER_CONTRACT.md
   - OWNER_COMMUNICATION_CONTRACT.md
   - ARCHITECTURE_BASELINE.md
   - DECISION_LOG.md
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
