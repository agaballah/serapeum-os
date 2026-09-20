# TASK-010 — W2 Work Hierarchy

```
TASK-ID:
TASK-010

TITLE:
W2 — Work Hierarchy

STATUS:
PROPOSED

PLANNING STATE:
PLANNING / ARCHITECTURE-DECOMPOSITION; NOT IMPLEMENTATION

OBJECTIVE:
Establish the SerapeumOS work hierarchy as Company → Goal → Mission → Task → execution, while preserving MA-04 architecture, the existing execution substrate, the MA-03 Company boundary, and the MA-06 authorization boundary. This record formalizes the planning and decomposition gate; it does not authorize implementation.

AUTHORITY:
- MA-04 — Agents / Roles / Missions / Tasks / Workflow State
- D-046 — Canonical work hierarchy
- D-049 — One accountable Agent per Task
- D-050 — Formal review requires independent Principal
- D-051 — Delegation is explicit and authority-attenuating
- D-052 — Runtime success is not Task completion
- MA-03 — Company Domain & Organizational Identity
- MA-05 — Memory / Knowledge / Provenance / Epistemic Governance
- MA-06 — AuthZ / Capabilities / Action Assurance
- MA-09 — Storage / Database / Artifact Store / User-File Publication
- MA-12 — Reliability / Checkpoint / Idempotency / Cancellation / Crash Recovery
- MA-14 — Observability / Audit / Receipts / Privacy
- GAP-003 in IMPLEMENTATION_DECOMPOSITION_BASELINE.md — proposed Work Hierarchy substrate and candidate boundary, not implementation authority

PRECONDITIONS:
- Branch: main
- Authoritative baseline: HEAD == origin/main == 9ef52e86f544abf1ff4dff6238b55e72f8856636
- Working tree: clean before this documentation reconciliation; only intentional tracked documentation diffs are permitted
- TASK-009 W1 Company Domain + Principal Integration: CLOSED / COMPLETE
- MA-04: CLOSED — ARCHITECTURE LOCKED
- W2 implementation: NOT STARTED
- PM decisions in the decision register below: unresolved
- Final W2 architecture/decomposition approval: not yet granted

SCOPE:
- Record the established MA-04 work-hierarchy findings.
- Record the existing execution substrate and the GAP-003 proposal.
- Record the W2/W3 boundary and the implementation gate.
- Preserve candidate decomposition ideas as DRAFT only.
- Keep all unresolved architecture/application questions visible for PM decision.
- This planning record authorizes no application source, migration, test, or closed-MA change.

FORBIDDEN:
- Do not create Goal, Mission, Task, or Work Hierarchy schemas or migrations.
- Do not implement Goal, Mission, Task, Store, or any Work Hierarchy code under this record.
- Do not implement W3 Authorization, Capability, Action Assurance, tool permissioning, execution authority, approval policy, resource authority, or authorization-derived reviewer powers.
- Do not treat existing Ankole delegation or BackgroundAgentJob behavior as a completed SerapeumOS Goal/Mission/Task hierarchy.
- Do not invent independent-review semantics from existing delegation.
- Do not lock WORK-001, WORK-002, or any other implementation package while the decision register is unresolved.
- Do not modify docs/serapeumos/architecture/01_*.md through 20_*.md.
- Do not create a worktree, sibling clone, external workspace, or persistent artifact outside D:\SerapeumOS.
- Do not commit or push this reconciliation.

REQUIRED BEHAVIOUR:
- Keep the canonical hierarchy Goal → Mission → Task → execution explicit.
- Keep Workflow, BackgroundAgentJob, Agent Call, and Actor Turn beneath Task as execution mechanisms.
- Keep Company scope and Principal identity distinct from authorization authority.
- Keep structural ownership/responsibility relationships separate from permission grants and capabilities.
- Keep formal reviewer independence as an MA-04 requirement without deriving reviewer powers from existing delegation.
- Mark all candidate packages as DRAFT and identify the PM decisions that block package locking.
- Stop and escalate on any architecture contradiction or any attempt to turn an UNSPECIFIED item into an implementation decision.

INVESTIGATION FINDINGS:
1. EXPLICIT — MA-04 and D-046 lock Goal → Mission → Task → execution as the canonical work hierarchy.
2. EXPLICIT — Workflow, BackgroundAgentJob, Agent Call, and Actor Turn remain execution mechanisms beneath Task. A runtime success does not by itself complete a Task.
3. REPOSITORY FACT — no Goal, Mission, or Task work-hierarchy implementation substrate was found; existing delegation/reviewer behavior is execution and authorization substrate, not a SerapeumOS hierarchy implementation.
4. PROPOSED — GAP-003 proposes app/control_plane/lib/ankole/work_hierarchy/ with a candidate Schema → validation → integration boundary. This is not an approved implementation package.
5. BOUNDARY — existing Ankole delegation/job behavior is execution and authorization substrate, not an implemented SerapeumOS work hierarchy.
6. BOUNDARY — independent formal review requires a different Principal from the primary executor. That requirement must not be invented from or reduced to existing delegation behavior.
7. BOUNDARY — W2 must not absorb W3 capability, authorization, Action Assurance, or permission semantics.

W2 / W3 BOUNDARY:
W2 MAY establish:
- work identity;
- Goal → Mission → Task hierarchy;
- Company relationship and Company scope;
- organizational assignment;
- Task lifecycle;
- structural ownership and responsibility relationships;
- structural parent/child lineage and accountability references.

W2 MUST NOT implement:
- permission grants;
- capability issuance or revocation;
- delegated authorization;
- Action Assurance;
- tool permissioning;
- execution authority;
- approval policy;
- resource authority;
- authorization-derived reviewer powers.

A structural foreign key or reference is permitted only where canonical architecture explicitly requires it to represent identity, scope, lineage, or accountability. Such a reference does not grant authority.

PM DECISIONS REQUIRED BEFORE IMPLEMENTATION:
The following items are UNSPECIFIED or require PM application decisions. MA-04 remains closed; this register does not reopen it.

| ID | Decision required | Current evidence | Classification | Status |
|---|---|---|---|---|
| W2-D01 | Exact Goal schema and identifier shape | MA-04 defines Goal as a desired Company outcome; no schema exists | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D02 | Exact Mission schema, revision model, and authoritative storage surface | MA-04 defines a durable versioned Mission and permits reuse of the Agent Library surface; physical schema is unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D03 | Exact Task schema and required fields | MA-04 lists required Task semantics; physical schema and service contract are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D04 | Exact lifecycle-state storage and transition rules | MA-04 locks conceptual Task states; validation, guards, and sub-status rules are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D05 | Parent/child lifecycle constraints and child-completion policy | MA-04 requires durable child lineage and a declared child-completion policy; exact constraints are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D06 | Human assignment membership rule | MA-03 permits explicit human Company membership and possible multi-Company participation; assignment eligibility is unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D07 | Agent same-Company assignment invariant and violation handling | MA-03 locks one Company organizational identity per SerapeumOS Agent; validation, recovery, and exceptional migration behavior are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D08 | System Principal participation | MA-03 keeps System Principals as installation/service identities unless explicitly given narrow Company scope; participation rules are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D09 | Assignment meaning: ownership vs responsibility vs execution vs review | MA-04 locks one accountable Agent and separate reviewer semantics; the complete assignment vocabulary is unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D10 | Task dependencies and DAG semantics | MA-04 names typed dependencies and child-completion policy; cycle, parallelism, and failure propagation rules are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D11 | Result and evidence reference shape | MA-04, MA-05, MA-09, and MA-14 require durable results, provenance, artifacts, receipts, and correlation; physical references are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D12 | Archive, cancellation, retention, and reactivation semantics | MA-04 distinguishes cancellation from runtime interruption and preserves history; archive and retention policy are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D13 | Public Store and context shape | No canonical public Store/context contract is present | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D14 | Locking, transaction, fencing, and concurrency requirements | MA-04 permits bounded concurrency and MA-12 requires durable-before-runtime and fencing; exact locking strategy is unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |
| W2-D15 | Formal review record and independence enforcement shape | MA-04 requires a different Principal for formal review; record schema and enforcement path are unspecified | PM_DECISION_REQUIRED | UNSPECIFIED — PM DECISION REQUIRED |

CANDIDATE DECOMPOSITION — DRAFT / NOT LOCKED:
These are candidate areas for PM planning only. They are not implementation packages and do not authorize source changes.

| Candidate area | Purpose | Blocking decisions |
|---|---|---|
| Domain model and PostgreSQL schema | Represent Goal, Mission, Task, lineage, Company scope, and stable identities | W2-D01, W2-D02, W2-D03, W2-D07 |
| Lifecycle and invariant validation | Enforce Task states, transitions, accountability, hierarchy, and child-completion rules | W2-D04, W2-D05, W2-D09, W2-D10 |
| Company and Principal integration | Connect work records to Company membership and stable Principal identities without granting permission | W2-D06, W2-D07, W2-D08, W2-D09 |
| Execution mapping | Map Task work to Workflow, BackgroundAgentJob, Agent Call, and Actor Turn while preserving Task identity | W2-D04, W2-D10, W2-D11, W2-D14 |
| Review, result, provenance, and audit integration | Link results, evidence, review records, artifacts, receipts, and correlation identifiers | W2-D11, W2-D12, W2-D15 |
| Reliability and concurrency integration | Apply durable intent, attempts, fencing, cancellation, and reconciliation rules | W2-D05, W2-D10, W2-D12, W2-D14 |
| Qualification and migration candidates | Define tests, data migration, recovery, and release evidence after the domain contract is approved | All unresolved decisions above |

REQUIRED BEHAVIOUR AFTER PM DECISIONS:
- PM must resolve each decision or explicitly record a PM-approved deferral before locking packages; any unresolved material decision remains a package-lock blocker.
- PM must approve the final decomposition before any implementation task is authorized.
- A later implementation task must reference the approved decisions and must not inherit unresolved items by implication.
- W3 remains a separate future wave unless a later explicit PM/Owner decision changes sequencing.

ACCEPTANCE CRITERIA FOR THIS PLANNING RECORD:
- [x] TASK-010 exists in the existing task directory and uses the TASK-NNN_TITLE.md naming pattern.
- [x] Status is PROPOSED and explicitly says PLANNING / ARCHITECTURE-DECOMPOSITION; NOT IMPLEMENTATION.
- [x] MA-04 authority and relevant MA-03/05/06/09/12/14 boundaries are recorded.
- [x] The seven investigation findings are recorded.
- [x] The W2/W3 boundary is explicit.
- [x] The PM decision register contains every required unresolved question.
- [x] Candidate decomposition is marked DRAFT and contains no locked WORK package IDs.
- [ ] PM decisions are resolved.
- [ ] Final decomposition is approved.
- [ ] W2 implementation is authorized.

VALIDATION:
- Read this task record and TASK_REGISTER.md.
- Search project-control documents for stale TASK-008 active-state claims.
- Run git diff --check.
- Run git status --short --branch.
- Confirm HEAD == origin/main == 9ef52e86f544abf1ff4dff6238b55e72f8856636.
- No runtime test is required for this documentation-only planning record.

EVIDENCE:
- MA-04 sections 3, 12–18, 21–31, and 33–36.
- D-046, D-049, D-050, D-051, and D-052 in DECISION_LOG.md.
- GAP-003 in IMPLEMENTATION_DECOMPOSITION_BASELINE.md.
- Repository search result: no Goal/Mission/Task implementation substrate found.
- Git state: main; HEAD == origin/main == 9ef52e86f544abf1ff4dff6238b55e72f8856636; clean before this reconciliation.

STOP / ESCALATE:
- If a PM decision is treated as resolved without an explicit PM/Owner record: STOP and report.
- If a candidate decomposition is presented as a locked implementation package: STOP and report.
- If W2 scope expands into W3 authorization or Action Assurance: STOP and report.
- If a closed MA document contains a factual contradiction: STOP and escalate without editing it.
- If repository state differs from the stated baseline: STOP and report.

GIT HANDLING:
- Work branch: main
- Commit message: PM-controlled project-truth reconciliation
- Commit authority for this reconciliation: none; do not commit yet
- Push authority: none
- Merge authority: PM only

FINAL REPORT:
- Files changed with purpose: project-control documentation only.
- Tests run: none; this is a documentation-only planning record.
- Evidence produced: task record, register entry, project-state update, roadmap update, decision-log assessment, stale-state search, diff check, and repository state.
- Residual risks: W2 implementation remains blocked until PM decisions and decomposition approval are recorded.
- Verdict: PROPOSED / PLANNING / ARCHITECTURE-DECOMPOSITION; NOT IMPLEMENTATION
```
