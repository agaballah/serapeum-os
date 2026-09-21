# TASK-010 — W2 Work Hierarchy

```
TASK-ID:
TASK-010

TITLE:
W2 — Work Hierarchy

STATUS:
AUTHORIZED

PLANNING STATE:
PLANNING / ARCHITECTURE-DECOMPOSITION; IMPLEMENTATION NOT YET AUTHORIZED

OBJECTIVE:
Establish the SerapeumOS work hierarchy as Company → Goal → Mission → Task → execution, while preserving MA-04 architecture, the existing execution substrate, the MA-03 Company boundary, and the MA-06 authorization boundary. This record authorizes planning and architecture-decomposition work only; it does not authorize application source, migration, test, or closed-MA changes.

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
- Planning input baseline: befcb40f77e634333e7a5065b6010f3130326546
- Working tree: clean before this documentation reconciliation
- TASK-009 W1 Company Domain + Principal Integration: CLOSED / COMPLETE
- MA-04: CLOSED — ARCHITECTURE LOCKED
- W2 implementation: NOT STARTED
- PM decisions in the decision register below: all resolved
- Final W2 architecture/decomposition approval: GRANTED — P1–P7 package decomposition PM-LOCKED

SCOPE:
- Record the established MA-04 work-hierarchy findings.
- Record the existing execution substrate and the GAP-003 proposal.
- Record the W2/W3 boundary and the implementation gate.
- Record PM-locked P1–P7 package decomposition as the controlling W2 implementation sequence.
- Keep all unresolved engineering questions visible for execution-agent resolution.
- This planning record authorizes no application source, migration, test, or closed-MA change.

TASK-010 CONTROL STATE:
- TASK-010 remains AUTHORIZED with scope: PLANNING / ARCHITECTURE-DECOMPOSITION ONLY.
- W2 package decomposition is PM LOCKED.
- W2 implementation has NOT started.
- No implementation package is authorized by this documentation status alone.

FORBIDDEN:
- Do not create Goal, Mission, Task, or Work Hierarchy schemas or migrations.
- Do not implement Goal, Mission, Task, Store, or any Work Hierarchy code under this record.
- Do not implement W3 Authorization, Capability, Action Assurance, tool permissioning, execution authority, approval policy, resource authority, or authorization-derived reviewer powers.
- Do not treat existing Ankole delegation or BackgroundAgentJob behavior as a completed SerapeumOS Goal/Mission/Task hierarchy.
- Do not invent independent-review semantics from existing delegation.
- Do not lock WORK-001, WORK-002, or any other implementation package without PM approval.
- Do not modify docs/serapeumos/architecture/01_*.md through 20_*.md.
- Do not create a worktree, sibling clone, external workspace, or persistent artifact outside D:\SerapeumOS.
- Commit/push require explicit PM authorization.

REQUIRED BEHAVIOUR:
- Keep the canonical hierarchy Goal → Mission → Task → execution explicit.
- Keep Workflow, BackgroundAgentJob, Agent Call, and Actor Turn beneath Task as execution mechanisms.
- Keep Company scope and Principal identity distinct from authorization authority.
- Keep structural ownership/responsibility relationships separate from permission grants and capabilities.
- Keep formal reviewer independence as an MA-04 requirement without deriving reviewer powers from existing delegation.
- Keep engineering recommendations clearly marked as non-locked.
- Stop and escalate on any architecture contradiction or any attempt to turn an UNSPECIFIED item into an implementation decision.

INVESTIGATION FINDINGS:
1. EXPLICIT — MA-04 and D-046 lock Goal → Mission → Task → execution as the canonical work hierarchy.
2. EXPLICIT — Workflow, BackgroundAgentJob, Agent Call, and Actor Turn remain execution mechanisms beneath Task. A runtime success does not by itself complete a Task.
3. REPOSITORY FACT — no Goal, Mission, Task work-hierarchy implementation substrate was found; existing delegation/reviewer behavior is execution and authorization substrate, not a SerapeumOS hierarchy implementation.
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

============================================================
DOMAIN CONTRACTS (PM-LOCKED + ENGINEERING-RECOMMENDED)
============================================================

## Goal Contract

**Identifier type rule:** FK physical type MUST match the canonical referenced identifier type. Exact UUID/text representation is verified and locked during P1/P2/P3 engineering gates against actual repository schema.

**No invented status lifecycle.** No PROPOSED/ACTIVE/ARCHIVED enum.

- durable Goal identity
- Company scope (company_uid FK → companies.uid, NOT NULL)
- user-defined desired outcome/content (title, description)
- creation provenance (creator_principal_uid FK → principals.uid)
- timestamps (created_at, updated_at) per repository convention

No status column. No lifecycle transitions. Archival is operator action outside W2 scope.

| Field | Type | Constraint | Source |
|---|---|---|---|
| goal_uid | PK | autogenerate | W2 |
| company_uid | FK | NOT NULL, references companies(uid) ON DELETE RESTRICT | W2 |
| title | text | NOT NULL | User |
| description | text | NULL | User |
| creator_principal_uid | FK | NOT NULL, references principals(uid) ON DELETE RESTRICT | W2 |
| created_at | utc_datetime_usec | NOT NULL | Platform |
| updated_at | utc_datetime_usec | NOT NULL | Platform |

## Mission Contract

**No invented status lifecycle.** No ACTIVE/SUPERSEDED/ARCHIVED enum.

Canonical Mission semantics (MA-04 §12, D-053):
- durable Mission identity
- one or more Mission revisions under that identity
- exactly one current effective revision where applicable
- historical revisions preserved
- assignment to exactly ONE of: Agent Principal OR Organizational Unit (XOR invariant)
- runtime MISSION.md projection is derived, not authoritative

**Single authoritative payload store:**

For Agent-assigned Missions: reuse existing `agent_library_container_entries` (source_kind='mission'). The Agent Library IS the authoritative payload store — no duplication.

For Unit-assigned Missions: do NOT fabricate a representative Agent. Use a separate `unit_mission_payloads` table with the same schema shape as agent_library_container_entries (path, content, content_hash, metadata). Unit Mission runtime projection is resolved during P2 engineering review. It must consume authoritative Unit Mission state without fabricating Agent ownership or creating a second Mission authority.

**Mission identity/revision model:**

MISSION IDENTITY
    ↓
ONE OR MORE MISSION REVISIONS
    ↓
EXACTLY ONE CURRENT EFFECTIVE REVISION where applicable

Exact physical schema is P2 engineering-gate work.

**Mission summary table (lightweight indexing layer):**

| Field | Type | Constraint |
|---|---|---|
| mission_uid | PK | autogenerate |
| company_uid | FK | NOT NULL, references companies(uid) ON DELETE RESTRICT |
| goal_uid | FK | NULL, references goals(goal_uid) ON DELETE SET NULL |
| assigned_agent_uid | FK | NULL, references agents(uid) ON DELETE SET NULL |
| organizational_unit_uid | FK | NULL, references organizational_units(uid) ON DELETE SET NULL |
| CHECK | | exactly one of assigned_agent_uid / organizational_unit_uid is non-null |
| version | int | NOT NULL, monotonically increasing |
| current_revision | boolean | NOT NULL, exactly one TRUE per mission_uid (enforced by trigger) |
| created_at | utc_datetime_usec | NOT NULL |
| updated_at | utc_datetime_usec | NOT NULL |

**Payload storage:**
- Agent-assigned: `agent_library_container_entries(agent_uid=assigned_agent_uid, path='/MISSION.md', source_kind='mission', content, content_hash, metadata)`
- Unit-assigned: `unit_mission_payloads(mission_uid, path, content, content_hash, metadata)`

Revision tracking via version increment + current_revision flip (trigger-enforced). Old revisions retained in payload table with soft-delete pattern.

## Task Contract

**Accountable Agent is lifecycle-aware (D-049 correction):**

| State | accountable_agent_uid requirement |
|---|---|
| PROPOSED | absent allowed |
| READY | absent allowed |
| ASSIGNED | REQUIRED — exactly one Agent Principal |
| IN_PROGRESS | REQUIRED |
| WAITING | REQUIRED |
| REVIEW | REQUIRED |
| COMPLETED | preserved if present |
| FAILED | preserved if present |
| CANCELLED | preserved if present |

If a Task reaches CANCELLED before ever being assigned, do NOT fabricate an accountable Agent.
Terminal state preserves whatever accountability history actually existed.

Not a table-level NOT NULL — enforced by service-layer transition guard at ASSIGNED and above.

**Origin model (correction from simple requester_uid):**

Every Task preserves actual origin lineage via:
- creator Principal (creator_principal_uid)
- origin_kind
- origin reference
- requester/originating Principal where applicable

Do not use creator_principal_uid as an automatic substitute for requester.
Do not fabricate Principal requesters for non-Principal origins.

For OWNER_REQUEST, the Owner/requester relationship must be explicit.

origin_reference shape depends on origin_kind:
- OWNER_REQUEST: requester tracked explicitly via dedicated origin reference; creator_principal_uid remains the creating Principal
- COMPANY_GOAL: {"goal_uid": "..."}
- MISSION: {"mission_uid": "..."}
- DELEGATION: {"delegation_uid": "...", "source_task_uid": "..."}
- WORKFLOW: {"workflow_run_id": 123, "agent_call_id": 456}
- SYSTEM_EVOLUTION: {"evolution_change_uid": "..."}
- EXTERNAL_EVENT: {"event_id": "...", "source": "..."}

**Full Task schema:**

| Field | Type | Constraint |
|---|---|---|
| task_uid | PK | autogenerate |
| company_uid | FK | NOT NULL, companies.uid |
| mission_uid | FK | NULL, missions.mission_uid |
| goal_uid | FK | NULL, goals.goal_uid |
| parent_task_uid | FK | NULL, tasks.task_uid (self-ref, no transitive cycle) |
| accountable_agent_uid | FK | absent in PROPOSED/READY; exactly one Agent Principal in ASSIGNED+ |
| creator_principal_uid | FK | NOT NULL, principals.uid |
| origin_kind | text | NOT NULL, ENUM check constraint |
| origin_reference | jsonb | NULL |
| status | text | NOT NULL, CHECK against canonical states |
| objective_text | text | NOT NULL |
| scope_text | text | NOT NULL |
| required_outcome_text | text | NOT NULL |
| acceptance_criteria_text | text | NOT NULL |
| child_completion_policy | text | DEFAULT 'ALL_COMPLETED', CHECK IN ('ALL_COMPLETED','INDEPENDENT') |
| created_at | utc_datetime_usec | NOT NULL |
| updated_at | utc_datetime_usec | NOT NULL |
| cancelled_at | utc_datetime_usec | NULL |
| cancelled_by_uid | FK | NULL, principals.uid |
| cancellation_reason | text | NULL |

## Lifecycle Transition/Guard Matrix

Not a mandatory conveyor belt. Each transition has explicit guards.

| From → To | Guard |
|---|---|
| PROPOSED → READY | objective_text, scope_text, required_outcome_text, acceptance_criteria_text all non-blank |
| PROPOSED → CANCELLED | cancelled_by_uid NOT NULL, cancellation_reason NOT NULL |
| READY → ASSIGNED | accountable_agent_uid present and valid; agent.type = :agent; agent.status = :active; company_membership exists |
| READY → CANCELLED | cancelled_by_uid NOT NULL, cancellation_reason NOT NULL |
| ASSIGNED → IN_PROGRESS | — |
| ASSIGNED → WAITING | explicit waiting condition present |
| ASSIGNED → CANCELLED | cancelled_by_uid NOT NULL, cancellation_reason NOT NULL |
| IN_PROGRESS → COMPLETED | completion criteria satisfied; no currently applicable required formal review |
| IN_PROGRESS → REVIEW | at least one currently required formal review is applicable |
| IN_PROGRESS → CANCELLED | cancelled_by_uid NOT NULL, cancellation_reason NOT NULL |
| IN_PROGRESS → WAITING | explicit waiting condition present |
| WAITING → IN_PROGRESS | waiting condition cleared, dependency satisfied |
| WAITING → CANCELLED | cancelled_by_uid NOT NULL, cancellation_reason NOT NULL |
| REVIEW → COMPLETED | all currently applicable required formal reviews for the current result/revision are satisfied |
| REVIEW → IN_PROGRESS | required review outcome indicates return to work; reviewer rationale recorded |
| REVIEW → CANCELLED | cancelled_by_uid NOT NULL, cancellation_reason NOT NULL |
| eligible non-terminal state → FAILED | Task cannot complete under current constraints; failure reason recorded |

COMPLETED, FAILED, CANCELLED are terminal.

No arbitrary reopen/reset transitions. Only explicitly defined guarded transitions are permitted.

## Human Participation Contract

| Role | Human Principal Allowed? | Constraint |
|---|---|---|
| CREATOR | YES | Must have active Company membership |
| ACCOUNTABLE AGENT | NO | Agent Principal subtype only |
| REVIEWER | YES (where permitted by architecture) | Must have active Company membership; must differ from primary executor of reviewed result |
| DELEGATOR | YES | Must have active Company membership |

Membership ≠ authorization. Membership is organizational eligibility checked in W2. Authorization is W3.

## Agent Assignment + Transaction/Lock Order

**Assignment invariant:** `tasks.accountable_agent_uid` must reference an Agent Principal (`principals.type = :agent`) that is an active member of `tasks.company_uid`.

**Transaction safety:** Assignment/reassignment must prevent races with:
- Principal disable/retire
- Company membership removal/change
- Agent organizational corruption (multi-company)

**Organizational validation requirements:**
- Assignment must be transactionally safe
- Assignment must not race with relevant Principal/Company state changes
- W1 lock ordering must be preserved/reused where overlapping entities are locked
- Deadlock inversion is prohibited

Exact lock order and SQL are verified at P3 engineering gate.

## Delegation/Reassignment Contract

**Two distinct operations:**

A. **Child-work creation**: delegator creates a new Task as child of source Task
B. **Accountability reassignment**: delegator transfers accountable_agent_uid from one Agent to another

**Schema:** `delegation_records(delegation_uid PK, delegator_principal_uid FK, source_task_uid FK, delegatee_principal_uid FK NULL, resulting_child_task_uid FK NULL, previous_accountable_agent_uid FK NULL, new_accountable_agent_uid FK NULL, scope_description TEXT, created_at)`

- W2 records structural delegation only
- W3/MA-06 validates whether delegator had authority to delegate
- No capability attenuation in W2

## Child-Completion Contract

| Policy | Behavior |
|---|---|
| ALL_COMPLETED | Parent reaches COMPLETED only when ALL direct children are COMPLETED. CANCELLED does NOT satisfy. |
| INDEPENDENT | Parent completion structurally independent of children. |

- Policy mutable while parent non-terminal
- Every change logged to `task_child_policy_history`
- Immutable after terminal state
- CANCELLED children do NOT count toward ALL_COMPLETED

## Dependency Contract

**Table:** `task_dependencies(task_uid, depends_on_task_uid, dependency_type ENUM)`

| Type | Satisfied By |
|---|---|
| REQUIRES_COMPLETION (default) | Predecessor status = COMPLETED only |
| REQUIRES_RESULT | Predecessor has a QUALIFYING durable Task result |
| OPTIONAL | No blocking condition |

- Cycle detection: recursive CTE within same transaction as insert
- Parent-child hierarchy cycles prevented by application logic
- Dependencies affect lifecycle ELIGIBILITY, not runtime execution order
- NOT a scheduler

## Result/Executor-Lineage Contract

**Table:** `task_results(result_uid PK, task_uid FK, workflow_run_id bigint FK NULL, workflow_agent_call_id bigint FK NULL, background_agent_job_id bigint FK NULL, background_agent_job_turn_id uuid FK NULL, execution_attempt_ref text NULL, executor_principal_uids text[] NULL, result_metadata jsonb NULL, acceptance_state ENUM NULL, failure_reason text NULL, created_at)`

- Reuses existing execution IDs: workflow_runs.id, workflow_agent_calls.id, background_agent_jobs.id, background_agent_job_turns.turn_id
- Multiple results per Task supported (multiple execution attempts)
- executor_principal_uids captures all Principals who materially executed
- result_metadata is structured JSON, not raw payload
- No artifact_uid FK (MA-09 not yet implemented; see Artifact Reference below)

## Formal-Review Independence Contract

**Table:** `review_records(review_uid PK, task_uid FK, reviewed_result_uid FK NULL, reviewer_principal_uid FK, criteria_text text, verdict ENUM, rationale_text text, created_at, invalidated_at TIMESTAMP NULL, invalidation_reason text NULL)`

**Verdicts (MA-04 §19):** APPROVED, CHANGES_REQUIRED, REJECTED, INCONCLUSIVE

**Independence invariant:**
reviewer_principal_uid MUST NOT appear in task_results.executor_principal_uids for the reviewed result.

If the same Principal materially executed/contributed to the reviewed revision, they cannot satisfy formal independence.

**Invalidation:** A materially changed result requires review applicability to be reassessed. Prior approval does not automatically approve the changed result. Exact invalidation/applicability representation is P6 engineering-gate work.

W3 owns whether reviewer_principal_uid had authorization. W2 only enforces structural independence.

## Artifact/Evidence Interface

**No MA-09 Artifact table exists.** W2 must NOT create a FK to it.

W2 preserves a durable produced-output reference/interface where available.
W2 does NOT own artifact bytes.
W2 does NOT invent an MA-09 FK before MA-09 exists.

Exact physical reference shape is resolved during P6 engineering review.

**Boundary:** W2 stores structured references and metadata. Full evidence payload, provenance chain, Fact/Take distinction → MA-05. Artifact bytes → MA-09. W2 never duplicates these.

## W2 Domain-History Authority

One coherent append-only event model. Each current-state mutation has a corresponding history row in the same transaction.

**Event tables:**
- `mission_revisions(mission_uid, version, created_at, created_by_uid, change_reason)`
- `task_lifecycle_events(task_uid, from_status, to_status, changed_at, changed_by_uid, metadata)`
- `task_assignment_history(task_uid, previous_agent_uid, new_agent_uid, changed_at, changed_by_uid, reason)`
- `delegation_events(delegation_uid, event_type, created_at, delegator_uid, metadata)`
- `review_events(review_uid, event_type, created_at, reviewer_uid, metadata)`
- `task_child_policy_history(task_uid, old_policy, new_policy, changed_at, changed_by_uid)`

**Atomicity:** Current-state mutation + history row inserted in same transaction.

**MA-14 remains separate:** MA-14 is system observability/audit. W2 domain history is organizational truth. They serve different purposes and are not interchangeable.

## Deferred Optional Fields

| Field | Classification | Rationale |
|---|---|---|
| priority | DEFER | MA-04 §13: "may be added by later domains" |
| due_date | DEFER | MA-04 §13: "may be added by later domains" |
| generic metadata JSONB | DEFER | Not required by MA-04; can be added via extension table later |

If metadata is retained for repository consistency, it is NON-AUTHORITATIVE descriptive data and cannot drive lifecycle, assignment, authorization, dependency semantics, or review authority.

## W2-Only Concurrency Model

**W2 implements only concurrency needed to preserve W2 invariants:**

- Row-level `SELECT ... FOR UPDATE` on Task rows during status transitions and assignment changes
- Advisory transaction locks (`pg_advisory_xact_lock`) for cross-row invariants (dependency cycle detection, current_revision enforcement)
- Transaction atomicity for current-state + history mutations
- Optimistic `version` column for read-heavy paths

**W2 does NOT implement:**
- General runtime fencing framework (MA-12)
- Crash-recovery framework (MA-12)
- Worker recovery (MA-12)
- Restart reconciliation framework (MA-12)

These belong to MA-12. W2 may reuse existing Ankole primitives where they fit (advisory locks, transaction semantics) but does not extend them.

============================================================
PM-RESOLVED DECISIONS
============================================================

### W2-D05 — Parent/child completion policy [LOCKED]
- Supported: ALL_COMPLETED (default), INDEPENDENT
- NOT supported: ANY_COMPLETED
- CANCELLED does NOT satisfy ALL_COMPLETED
- Policy mutable while parent non-terminal; immutable after terminal
- Every change logged to task_child_policy_history

### W2-D06 — Human assignment eligibility [LOCKED]
- For every W2 Company-scoped role permitting a Human Principal:
  - Human MUST have active Company membership (organizational eligibility)
  - Membership is NOT authorization
- Accountable Agent MUST be an Agent Principal (type=:agent)
- Humans participate as CREATOR, REVIEWER (where permitted), DELEGATOR — never as ACCOUNTABLE AGENT

### W2-D08 — System Principal participation [LOCKED]
- System Principal CANNOT be ACCOUNTABLE AGENT
- System Principal MAY be CREATOR, infrastructure actor, audit/provenance origin
- No business authority granted merely because System Principal exists

### W2-D09 — Assignment vocabulary [LOCKED]
- Three distinct roles: CREATOR, ACCOUNTABLE AGENT, REVIEWER
- ACCOUNTABLE AGENT: exactly one Agent Principal
- REVIEWER: must differ from PRIMARY EXECUTOR of reviewed result (not merely accountable_agent_uid)
- No contributor/observer/etc. unless MA-04 explicitly requires

### W2-D10 — Dependency semantics [LOCKED]
- REQUIRES_COMPLETION: satisfied ONLY by COMPLETED
- REQUIRES_RESULT: satisfied by non-null result_uid in task_results
- OPTIONAL: non-blocking
- Transactional DAG cycle detection required
- NOT a scheduler

### W2-D12 — Cancellation semantics [LOCKED]
- CANCELLED is terminal; cannot be reactivated
- Renewed work requires NEW Task
- Historical truth preserved (no physical deletion)

### W2-D15 — Review boundary [LOCKED]
- W2 stores: reviewer reference, verdict, rationale, linked result/revision
- W3 owns reviewer authorization
- Changed result invalidates prior review of earlier revision

============================================================
ENGINEERING DECISIONS
============================================================

ENGINEERING RECOMMENDATION — NOT PACKAGE-LOCKED:

| ID | Decision | Substrate | Recommendation | DB Constraint | Transaction | History | Concurrency | Tests | Uncertainty |
|---|---|---|---|---|---|---|---|---|---|
| D01 | Goal model | companies(uuid pk), principals(uid pk, type enum) | goals(goal_uid PK uuid, company_uid FK text, title text NOT NULL, description text, creator_principal_uid FK text, created_at, updated_at) | CHECK on company_uid FK; CHECK on creator FK | Single INSERT | created_at/updated_at | None | FK integrity, required fields | None |
| D02 | Mission model | agent_library_container_entries, organizational_units | missions summary + XOR constraint; Agent Library for Agent-assigned; unit_mission_payloads for Unit-assigned | CHECK: exactly one of assigned_agent_uid/organizational_unit_uid; trigger: one current_revision per mission_uid | INSERT into both tables in single tx | mission_revisions table | Advisory lock on mission_uid during revision | One-current-revision trigger, payload link integrity | Unit Mission runtime projection mechanism TBD |
| D03 | Task model | All above + companies, principals, agents, organizational_units, company_memberships | tasks(task_uid PK uuid, company_uid FK, mission_uid FK NULL, goal_uid FK NULL, parent_task_uid FK NULL, accountable_agent_uid FK→agents.uid NULL, creator_principal_uid FK, origin_kind ENUM, origin_reference JSONB, status ENUM, objective/scope/outcome/criteria text, child_completion_policy ENUM DEFAULT 'ALL_COMPLETED', cancelled_at NULL, cancelled_by_uid NULL, cancellation_reason NULL, created_at, updated_at) | CHECK on status values; CHECK cancelled_at/cancelled_by/cancellation_reason co-nullable; CHECK parent_task_uid != task_uid; FK accountable_agent_uid→agents.uid | Single INSERT; membership validation in service tx | task_lifecycle_events, task_assignment_history | SELECT FOR UPDATE on task row | FK constraints, CHECK constraints, membership validation, nullable lineage | None |
| D04 | Lifecycle | tasks.status column | Service-layer state machine; DB ENUM CHECK | CHECK constraint on status IN canonical states | Single UPDATE per transition | task_lifecycle_events | SELECT FOR UPDATE on task row | Valid/invalid transition tests, required-field-per-state | Sub-status in metadata JSONB |
| D07 | Same-Company enforcement | company_memberships(company_uid, principal_uid composite PK) | Service-layer JOIN validation | No DB FK (cross-table); enforced in service | Validation within same tx as Task INSERT/UPDATE | task_assignment_history | SELECT FOR UPDATE on memberships row | Cross-Company rejection, inactive Agent rejection | None |
| D11 | Result/evidence | workflow_runs, workflow_agent_calls, background_agent_jobs, background_agent_job_turns | task_results(result_uid PK, task_uid FK, workflow_run_id FK NULL, workflow_agent_call_id FK NULL, background_agent_job_id FK NULL, background_agent_job_turn_id FK NULL, execution_attempt_ref text NULL, executor_principal_uids text[] NULL, result_metadata JSONB NULL, acceptance_state ENUM NULL, failure_reason text NULL, created_at) | FKs to existing tables; CHECK on acceptance_state values | Single INSERT | None (results are append-only) | None | FK integrity, multi-result per Task | None |
| D13 | Store organization | Existing patterns: companies, principals, organizational_units, agent_library_container_entries | Separate tables per aggregate; module: work_hierarchy/ with submodules | Per-table constraints | Per-operation | Per-table event logs | Per-table locking | Integration tests | None |
| D14 | Locking/concurrency | Existing: agents lock pattern (SELECT FOR UPDATE), advisory locks | Pessimistic on Task rows during mutations; optimistic version for reads; advisory for cross-row invariants | version INT column on tasks | Per-transition transaction | N/A | SELECT FOR UPDATE, pg_advisory_xact_lock | Concurrent mutation protection, serialization correctness, lost-update prevention, transactional invariant tests | Performance under high concurrency TBD |

============================================================
PM PACKAGE LOCK
============================================================

PM has APPROVED the P1–P7 package decomposition.

The package map below is the controlling W2 implementation sequence.
No implementation package may be authorized without referencing this locked map.

============================================================
PACKAGE NAMES — FINAL
============================================================

P1 — Goal Foundation

P2 — Mission Identity, Target & Revision Foundation

P3 — Task Core: Identity, Origin, Lineage & Accountability

P4 — Task Lifecycle & Domain History

P5 — Delegation, Child Work & Dependencies

P6 — Task Results & Formal Review

P7 — W2 Concurrency, Integration & Qualification

============================================================
PACKAGE-LEVEL ENGINEERING REFINEMENT RULE
============================================================

LOCKED NOW (may not change):
- W2 domain semantics
- W2/W3 boundaries
- P1–P7 package boundaries
- package ordering
- product configurability rules
- architecture invariants

RESOLVED AT INDIVIDUAL PACKAGE ENGINEERING GATE (may refine how, not what):
- exact physical table details where not architecture-fixed
- exact index design
- exact SQL locking implementation
- exact Mission revision storage mechanics
- exact Task origin-reference representation
- exact result/executor relational representation
- exact lifecycle transition matrix consistent with MA-04

These implementation decisions may refine HOW the locked architecture is built.
They may NOT change WHAT the locked architecture means.

============================================================
UNIT MISSION RUNTIME PROJECTION — PACKAGE-LEVEL ENGINEERING ITEM
============================================================

The Unit Mission runtime projection mechanism is NOT a PM/product blocker
and does not block the package map.

P2 must establish ONE authoritative Mission identity/revision/target model.

A Unit-assigned Mission must remain a Unit Mission.

Do not fabricate Agent ownership.

Runtime projection for an Agent operating under a Unit Mission must consume
that authoritative state and must not create another Mission authority.

Exact projection mechanism is resolved during P2 engineering review.

============================================================
FINAL IMPLEMENTATION PACKAGE MAP
============================================================

## P1 — Goal Foundation
- **Schema:** goals table
- **Invariants:** Company scope, stable identity, creation provenance
- **API:** Goal.create, Goal.get, Goal.list_by_company
- **Transactions:** Single-row INSERT
- **Locking:** None required
- **History:** created_at/updated_at
- **Tests:** FK integrity, required fields, Company scope isolation
- **Exclusions:** No Mission, no Task, no lifecycle
- **Depends on:** —

## P2 — Mission Identity/Revision/Target Foundation
- **Schema:** missions, unit_mission_payloads (summary + payload for Unit-assigned); Agent Library reused for Agent-assigned
- **Invariants:** XOR target (Agent OR Unit), one-current-revision, Company scope
- **API:** Mission.create, Mission.get, Mission.revision, Mission.list_by_company
- **Transactions:** Insert summary + payload in single tx; trigger-enforced current_revision
- **Locking:** Advisory lock on mission_uid during revision
- **History:** mission_revisions table
- **Tests:** XOR invariant, one-current-revision trigger, payload link integrity, Unit vs Agent assignment
- **Exclusions:** No Task, no dependencies, no review
- **Depends on:** P1 (goal_uid FK)

## P3 — Task Core: Identity/Origin/Lineage/Accountability
- **Schema:** tasks, task_assignment_history
- **Invariants:** same-Company membership, origin_kind + origin_reference, parent-child lineage, accountability data structures
- **API:** Task.create, Task.get, Task.list_by_company, Task.list_by_mission, assignment eligibility validation primitives
- **Transactions:** INSERT with membership validation
- **Locking:** SELECT FOR UPDATE on task row where applicable
- **History:** task_assignment_history
- **Tests:** FK constraints, CHECK constraints, membership validation, nullable accountability in PROPOSED/READY
- **Exclusions:** No authoritative lifecycle transitions, no ASSIGNED transition execution, no dependencies, no review, no results
- **Depends on:** P1, P2

## P4 — Task Lifecycle & Domain History
- **Schema:** tasks (status ENUM + CHECK), task_lifecycle_events (append-only)
- **Invariants:** Canonical states, transition guards, CANCELLED terminal, WAITING requires reason, authoritative lifecycle transitions
- **API:** Task.transition, Task.assign (performs ASSIGNED transition), Task.cancel
- **Transactions:** Single-row UPDATE + history INSERT in same tx
- **Locking:** SELECT FOR UPDATE on task row
- **History:** task_lifecycle_events (created/owned by P4)
- **Tests:** Valid transition acceptance, invalid transition rejection, required-field-per-state, cancellation terminal, ASSIGNED transition
- **Exclusions:** No dependencies, no review, no results
- **Depends on:** P3

## P5 — Delegation + Child Lineage + Dependencies
- **Schema:** task_dependencies, delegation_records, task_child_policy_history, tasks (parent_task_uid, child_completion_policy columns)
- **Invariants:** DAG acyclic, typed deps, child_policy enforced, delegation traceable
- **API:** Task.create_child, Task.set_dependency, Task.set_child_policy, Delegation.create
- **Transactions:** INSERT with recursive CTE cycle detection; policy change + history in same tx
- **Locking:** SELECT FOR UPDATE on parent task row; advisory lock for cycle detection
- **History:** task_child_policy_history, delegation_events
- **Tests:** Cycle detection, policy enforcement, dependency type tests, delegation traceability
- **Exclusions:** No review, no results, no reliability
- **Depends on:** P3, P4

## P6 — Task Results & Formal Review
- **Schema:** task_results, review_records
- **Invariants:** Reviewer ≠ primary executor of reviewed result, verdict enum, result invalidation on revision change
- **API:** Task.record_result(...), Review.review_result(...)
- **Transactions:** Recording a new result may atomically update review applicability if needed. Review occurs against an existing result/revision.
- **Locking:** SELECT FOR UPDATE on task row during result creation
- **History:** review_events (append-only)
- **Tests:** Review independence (executor ≠ reviewer), verdict enum, invalidation tracking, multi-result per Task
- **Exclusions:** No authorization check, no artifact storage, no W3 integration
- **Depends on:** P3, P4

## P7 — W2 Concurrency, Integration & Qualification
- **Schema:** tasks (version column, indexes), migration rollback tests
- **Invariants:** Transaction correctness, concurrent mutation protection, cross-package integration, W2 integration qualification
- **API:** Internal only (infrastructure)
- **Transactions:** Per-transition atomicity
- **Locking:** SELECT FOR UPDATE + advisory locks
- **History:** N/A (infrastructure)
- **Tests:** Concurrent mutation protection, cross-package integration, end-to-end W2 flow, W2 integration qualification
- **Exclusions:** No general runtime fencing framework (MA-12), no Worker recovery, no crash-recovery framework, no restart reconciliation, no general MA-12 reliability framework
- **Depends on:** P1–P6

============================================================
HISTORICAL PRE-LOCK CANDIDATE — SUPERSEDED BY PM PACKAGE LOCK
============================================================

This section is retained for audit only. The P1–P7 map above is PM LOCKED.
This historical candidate table does not authorize or override the locked package map.

| Package | Scope | Schema | Invariants | Tests | Exclusions | Depends On |
|---|---|---|---|---|---|---|
| P1 | Goal foundation | goals | Company scope, stable identity | FK, required fields | No Mission/Task | — |
| P2 | Mission foundation | missions, unit_mission_payloads | XOR target, one-current-revision | Trigger, payload link | No Task | P1 |
| P3 | Task core | tasks, event tables | Accountability lifecycle-aware, membership | FK, CHECK, membership | No deps/review | P1, P2 |
| P4 | Lifecycle | tasks (status), lifecycle_events | Canonical states, guards | Transition matrix | No deps/review | P3 |
| P5 | Delegation+deps | task_dependencies, delegation_records, policy_history | DAG acyclic, policy enforced | Cycle detection, policy | No review/results | P3, P4 |
| P6 | Results+review | task_results, review_records | Reviewer independence, invalidation | Independence, verdict | No auth/artifacts | P3, P4 |
| P7 | W2 Concurrency, Integration & Qualification | tasks (version, indexes), fixtures | Transaction correctness, concurrent mutation protection, cross-package integration, W2 integration qualification | Concurrency, E2E W2 flow, W2 integration qualification | No general runtime fencing/Worker recovery/crash-recovery/restart reconciliation (MA-12) | P1–P6 |

============================================================
REQUIRED BEHAVIOUR AFTER PM DECISIONS:
- PM must approve the final decomposition before any implementation task is authorized.
- A later implementation task must reference the approved decisions and must not inherit unresolved items by implication.
- W3 remains a separate future wave unless a later explicit PM/Owner decision changes sequencing.

============================================================
ACCEPTANCE CRITERIA FOR THIS PLANNING RECORD:
- [x] TASK-010 exists in the existing task directory and uses the TASK-NNN_TITLE.md naming pattern.
- [x] Status is AUTHORIZED and explicitly says PLANNING / ARCHITECTURE-DECOMPOSITION; IMPLEMENTATION NOT YET AUTHORIZED.
- [x] MA-04 authority and relevant MA-03/05/06/09/12/14 boundaries are recorded.
- [x] The seven investigation findings are recorded.
- [x] The W2/W3 boundary is explicit.
- [x] All seven PM decisions are resolved and locked.
- [x] Engineering decisions are resolved with substrate-aware recommendations.
- [x] Candidate decomposition is marked DRAFT and contains no locked WORK package IDs.
- [x] Final P1–P7 package decomposition is PM-APPROVED and LOCKED.
- [x] P7 boundary corrected: W2 Concurrency, Integration & Qualification; MA-12 items excluded.
- [x] Unit Mission projection recorded as package-level engineering item (P2).
- [x] Package-level engineering refinement rule recorded.
- [ ] W2 implementation is authorized.

============================================================
VALIDATION:
- Read this task record and TASK_REGISTER.md.
- Search project-control documents for stale TASK-008 active-state claims.
- Run git diff --check.
- Run git status --short --branch.
- Confirm planning input baseline: befcb40f77e634333e7a5065b6010f3130326546.
- No runtime test is required for this documentation-only planning record.

============================================================
EVIDENCE:
- MA-04 sections 3, 12–18, 21–31, and 33–36.
- D-046, D-049, D-050, D-051, and D-052 in DECISION_LOG.md.
- GAP-003 in IMPLEMENTATION_DECOMPOSITION_BASELINE.md.
- Substrate inspection: companies (uuid pk, uid text, status enum), principals (uid pk, type enum :human/:agent/:system), agents (uid pk FK→principals), company_memberships (company_uid, principal_uid composite PK), organizational_units (uid pk, company_uid FK, parent_unit_uid FK), agent_library_container_entries (agent_uid FK, path, source_kind ENUM 'soul'|'mission'|'design'|'confidentiality_policy'), workflow_runs (bigint pk, agent_uid FK), workflow_agent_calls (bigint pk, run_id FK, agent_uid FK, call_seq), background_agent_jobs (bigint pk, agent_uid FK), background_agent_job_turns (uuid pk).
- Planning input baseline: befcb40f77e634333e7a5065b6010f3130326546; clean before this reconciliation.

============================================================
STOP / ESCALATE:
- If a PM decision is treated as resolved without an explicit PM/Owner record: STOP and report.
- If a candidate decomposition is presented as a locked implementation package: STOP and report.
- If W2 scope expands into W3 authorization or Action Assurance: STOP and report.
- If a closed MA document contains a factual contradiction: STOP and escalate without editing it.
- If repository state differs from the stated baseline: STOP and report.

============================================================
GIT HANDLING:
- Work branch: main
- Commit message: PM-controlled project-truth reconciliation
- Commit/push require explicit PM authorization.
- Merge authority: PM only

============================================================
FINAL REPORT:
- Files changed with purpose: project-control documentation only.
- Tests run: none; this is a documentation-only planning record.
- Evidence produced: task record, register entry, project-state update, roadmap update, decision-log assessment, substrate inspection, diff check, and repository state.
- Residual risks: W2 implementation remains blocked until PM explicitly authorizes an implementation package. Decomposition approval is already complete.
- Verdict: AUTHORIZED — PLANNING / ARCHITECTURE-DECOMPOSITION; IMPLEMENTATION NOT YET AUTHORIZED
```
