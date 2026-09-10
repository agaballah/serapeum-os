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
- Branch/reference under qualification = authoritative `main`
- Qualification snapshot must equal the authoritative `origin/main` selected by
  the PM immediately before the test
- Exact HEAD SHA is discovered and reported at runtime; do NOT hardcode a
  previous HEAD as a precondition — this task is committed inside the repository
  and its specification must remain valid across HEAD advances
- No tracked working-tree modifications may exist at start
- No staged modifications may exist at start
- Qualification HEAD must remain unchanged throughout the read-only qualification
- Untracked files do not automatically invalidate a checkout, but they are never
  repository authority and must never be read as evidence
- Tools: any capable AI reader with file read access to repository path
- Repository path:
  - the isolated qualification checkout selected by the PM for the current attempt;
  - the agent must operate only inside that supplied checkout;
  - the checkout HEAD must equal the PM-selected authoritative origin/main snapshot;
  - the runtime path must be reported in the final evidence.

SCOPE:
- Allowed files: Read-only access to Git-tracked repository files ONLY. Derive
  the authoritative file list via `git ls-files` (or equivalent read-only Git
  tree inspection) at the selected qualification HEAD; do not scan the
  filesystem for arbitrary files
- Allowed commands: File reads from git-ls-files output, git log/show/diff,
  hash computation, line counts
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
- Do not characterize inherited Ankole bubblewrap/container mechanisms as
  "development/tooling only" unless an authoritative source specifically says so;
  MA-01 treats inherited bubblewrap as an inner defense-in-depth mechanism while
  the locked outer boundary is the hard Agent Appliance boundary defined by MA-01
- Do not select or prescribe a specific hypervisor/backend for the hard Agent
  Appliance boundary
- Do not invent: new architecture decisions beyond what is documented in MA-01
  through MA-20
- Do not read: untracked files as repository authority; untracked files are NOT
  part of Git-tracked repository truth
- Do not inspect or use: `_archsync_input/` — this is non-authoritative local
  reference material and MUST NOT be consulted during TASK-000 reconstruction
- Do not perform: broad workspace scanning that includes untracked files; limit
  all reads to the Git-tracked tree only

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
- [ ] Authority model correctly described (explicit current Owner instruction = highest authority;
      PROJECT_CONSTITUTION = highest durable authority below Owner; Project Manager = sole
      technical manager/architect accountable to Owner; execution/coding/research agents =
      bounded workers, not architectural authority; governance/document instruction precedence
      correctly reconstructed)
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
- If precondition fails (wrong selected branch/reference/snapshot, tracked
  modifications present, staged modifications present, HEAD changed during
  qualification): STOP and report
- If architecture conflict found between reconstruction and documented MA
  documents: STOP and escalate
- If evidence cannot be collected for any checklist item: STOP and report
- If unexpected repository state: STOP and report
- If any inherited container/bubblewrap implementation is treated as the final
  hard security boundary: STOP and escalate
- If untracked files are read or `_archsync_input/` is inspected: STOP and
  escalate (contamination violation)

GIT HANDLING:
- Qualification reference = PM-selected snapshot of authoritative origin/main
- A detached isolated checkout is permitted
- Exact HEAD must equal the PM-selected origin/main snapshot
- No branch creation/switching is required by TASK-000
- Read-only task; no commit/push/merge authority

FINAL REPORT:
- Files read in order
- Checklist areas addressed with evidence
- Discrepancies found (if any)
- Residual risks
- Verdict: PASS / FAIL / BLOCKED
- Reconstructed repository HEAD SHA
```
