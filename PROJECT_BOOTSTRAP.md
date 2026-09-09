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
3. **docs/serapeumos/OWNER_CHARTER.md** — Owner authority and Gold Rules
4. **docs/serapeumos/PROJECT_MANAGER_CONTRACT.md** — Project Manager role contract
5. **docs/serapeumos/ARCHITECTURE_BASELINE.md** — approved pre-implementation architecture
6. **docs/serapeumos/DECISION_LOG.md** — chronological decision register
7. **docs/serapeumos/ROADMAP.md** — gate-level roadmap
8. **applicable AGENTS.md files** — before modifying any source code

## Authority precedence

1. **Owner** — final authority over product direction, Constitution, Gold Rules, and
   high-impact approvals.
2. **Project Manager** — sole technical manager/architect accountable to the Owner.
   Responsible for architecture, planning, delegation, and maintaining project truth.
3. **Execution Agents** — Kilo, Codex, and other coding agents execute bounded tasks.
   They are NOT architectural authority. They must read this bootstrap guide before work.

If SerapeumOS governance and inherited Ankole instructions appear to conflict,
STOP and report the conflict. Do not silently choose.

## Current status

See **PROJECT_STATE.md** for the current phase, completed gates, blockers, and next action.

## Before modifying source code

Always read the applicable `AGENTS.md` at the root and in the relevant subdirectory
before making any changes to source files.
