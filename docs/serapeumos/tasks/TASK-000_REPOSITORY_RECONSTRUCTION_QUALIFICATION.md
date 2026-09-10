# TASK-000 — Fresh-Agent Repository Reconstruction Qualification

```
TASK-ID:
TASK-000

TITLE:
Fresh-Agent Repository Reconstruction Qualification

OBJECTIVE:
A fresh capable AI with zero prior SerapeumOS conversation context must
reconstruct the complete project from repository files alone and return enough
evidence for PM qualification. This validates that the repository is a durable
permanent memory where no important decision or instruction requires chat
history, model memory, or external context.

AUTHORITY:
- AGENTS.md (instruction precedence)
- PROJECT_BOOTSTRAP.md (mandatory reading order)
- PROJECT_STATE.md (current state)
- PROJECT_CONSTITUTION.md (governance)
- OWNER_CHARTER.md (Owner authority)
- PROJECT_MANAGER_CONTRACT.md (PM contract)
- OWNER_COMMUNICATION_CONTRACT.md (communication rules)
- DOCTRINE.md (normative doctrine)
- 00_MASTER_ARCHITECTURE.md (cross-domain architecture index)
- MA-01 through MA-20 (closed architecture domains)
- DECISION_LOG.md (decision register D-001 through D-266)
- ROADMAP.md (gate-level roadmap)
- PROJECT_RECONSTRUCTION_PROTOCOL.md (reconstruction standard)
- EXECUTION_AGENT_CONTRACT.md (execution agent role)
- EVIDENCE_AND_COMPLETION_CONTRACT.md (evidence standards)

PRECONDITIONS:
- Branch: main
- Base SHA: 8f00430fbd698ca2b701da683c503aae6643399f
- Working tree: clean
- Tools: any capable AI reader with file read access to repository path
- Repository path: D:\SerapeumOS

SCOPE:
- Allowed files: Read-only access to all files under D:\SerapeumOS\
- Allowed commands: File reads, git log/show/diff, hash computation, line counts
- Allowed outcomes: Return reconstruction report with evidence for each checklist
  area; report repository HEAD reconstructed; pass/fail verdict per checklist
  item

FORBIDDEN:
- Do not modify: any repository files, Git history, or working tree
- Do not: execute any code, run builds, create branches, make commits, or
  push to remote
- Do not claim: empirical qualification of any host, backend, or runtime
- Do not treat: inherited container/bubblewrap implementation as the final hard
  security boundary — document only what is locked by MA-01/MA-06
- Do not invent: new architecture decisions beyond what is documented in MA-01
  through MA-20

REQUIRED BEHAVIOUR:
- Follow the mandatory reading order from PROJECT_BOOTSTRAP.md exactly
- Reconstruct from repository truth alone — no chat history, no model memory
- Demonstrate understanding of every checklist area defined by
  PROJECT_RECONSTRUCTION_PROTOCOL.md
- Report explicit distinction between:
  * Inherited/current implementation facts (Ankole-derived)
  * LOCKED SerapeumOS architecture (MA-01→MA-20)
  * PROPOSED backend/implementation candidates (not yet selected)
  * Empirical qualification state (MA-20 evidence states)
- Report the repository HEAD SHA that was reconstructed
- Provide verifiable evidence for every factual claim (git diff, file reads,
  command outputs, hash computations)

ACCEPTANCE CRITERIA:
- [ ] Product identity correctly stated (name, repo, local path, Git relationship,
      foundation)
- [ ] Authority model correctly described (Owner > Constitution > governance docs
      > AGENTS overlay > inherited Ankole)
- [ ] Doctrine correctly stated (Gold Rule #1 with host-substrate distinction,
      NaraRouter limitation, platform-neutral core, Agent ≠ Model ≠ Worker
      ≠ Appliance ≠ Process, five state domains)
- [ ] Foundation correctly stated (Ankole v1.0.4-rc.1 at locked baseline commit
      7434d934315881438d4788d41228ba31d2f26fbb; production admission subject
      to MA-19 provenance and MA-20 qualification; first target Windows 11
      x86-64 NOT yet empirically qualified)
- [ ] Architecture correctly stated (MA-01 through MA-20 all CLOSED / PASS;
      Final Cross-Domain Consistency Audit COMPLETE — domain architecture
      consistency PASS; documentation-synchronization blockers handled through
      ARCH-SYNC-01 / repository persistence and accepted by PM; four
      SerapeumOS-owned domains)
- [ ] Current state correctly stated (phase, gate, blockers, next action,
      Implementation NOT STARTED, Runtime prototypes PAUSED)
- [ ] Repository-persistence status correctly stated (ARCH-SYNC-01 ACCEPTED,
      Repository Persistence / Verification PASS/ACCEPTED, Fresh-Agent
      Reconstruction Validation pending)
- [ ] Security principles correctly stated (compromised Agent runtime must not
      damage host/Company state; durable authoritative state cannot be mutated
      directly by untrusted Agents; security controls fail closed; one hard
      Agent Appliance boundary per Agent Principal)
- [ ] Task-execution rules correctly stated (agents receive tasks not architecture
      prompts; canonical task format; completion requirements)
- [ ] Distinction between inherited facts, LOCKED architecture, PROPOSED
      candidates, and empirical qualification state clearly maintained
- [ ] Explicit prohibition on treating inherited container/bubblewrap as final
      hard security boundary observed
- [ ] Reconstructed repository HEAD SHA reported and matches known HEAD

VALIDATION:
- git rev-parse HEAD (verify reconstructed HEAD)
- git log --oneline -5 (verify recent history)
- Count decision IDs in DECISION_LOG.md (must equal 266, zero gaps, zero
  duplicates, D-001 through D-266)
- Read each mandatory document from PROJECT_BOOTSTRAP.md reading order and
  verify content matches expected values

EVIDENCE:
- git rev-parse HEAD output
- git log --oneline -5 output
- Decision-ID count and sequence verification from DECISION_LOG.md
- Excerpts from each reconstructed checklist area demonstrating correct
  understanding
- Any discrepancies between reconstruction and repository truth

STOP / ESCALATE:
- If precondition fails (wrong branch, wrong base SHA, dirty working tree):
  STOP and report
- If architecture conflict found between reconstruction and documented
  MA documents: STOP and escalate
- If evidence cannot be collected for any checklist item: STOP and report
- If unexpected repository state: STOP and report
- If any inherited container/bubblewrap implementation is treated as the final
  hard security boundary: STOP and escalate

GIT HANDLING:
- Work branch: main
- Commit message: none (read-only task)
- Push authority: no
- Merge authority: no

FINAL REPORT:
- Files read in order
- Checklist areas addressed with evidence
- Discrepancies found (if any)
- Residual risks
- Verdict: PASS / FAIL / BLOCKED
- Reconstructed repository HEAD SHA
```
