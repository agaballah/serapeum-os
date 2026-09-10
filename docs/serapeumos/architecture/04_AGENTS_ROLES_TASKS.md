# MA-04 — Agents / Roles / Missions / Tasks / Workflow State

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-04 defines how SerapeumOS represents AI colleagues and work:

- persistent Agent identity and lifecycle;
- organizational role classes;
- missions;
- tasks;
- delegation;
- review;
- workflow state;
- mapping from Company work to inherited Ankole execution primitives.

MA-04 defines organizational and execution semantics only. Permissions, capabilities, memory, storage schema, resource quotas, and recovery mechanics belong to later MA domains.

---

## 2. Existing foundation

### REPOSITORY FACT

Ankole already provides:

- durable Agent Principals;
- Agent `role` metadata;
- human Agent owner;
- PostgreSQL-backed Agent library documents including `SOUL`, `MISSION`, and `DESIGN`;
- `/agents/<agent_uid>/MISSION.md` and related files as runtime projections;
- durable `Workflow` runs and Agent calls;
- durable `BackgroundAgentJob` work items;
- Actor sessions, events, turns, retries, fencing, and completion;
- Worker execution separated from authoritative PostgreSQL state.

### LOCKED

SerapeumOS reuses these execution foundations.

It does not create a second turn engine, second job engine, or second workflow engine merely to represent Company work.

---

## 3. Canonical work hierarchy

### LOCKED

SerapeumOS uses this conceptual hierarchy:

```text
COMPANY GOAL
    ↓
AGENT / UNIT MISSION
    ↓
TASK
    ↓
optional WORKFLOW / delegated SUBTASKS
    ↓
JOB / AGENT CALL
    ↓
ACTOR TURN(S)
```

Each layer has a different meaning.

- **Goal** — desired Company outcome.
- **Mission** — durable mandate/responsibility.
- **Task** — bounded accountable unit of work.
- **Workflow** — orchestration of work.
- **Job / Agent Call** — executable work item.
- **Turn** — one execution attempt/interchange.

These concepts must not be conflated.

---

## 4. Agent identity

### LOCKED

An Agent is a persistent organizational Principal.

Agent identity survives:

- model changes;
- role changes;
- mission revisions;
- runtime replacement;
- Worker replacement;
- appliance replacement;
- task completion;
- restart.

```text
Agent ≠ Model ≠ Role ≠ Mission ≠ Task ≠ Worker ≠ Runtime
```

The stable Ankole Agent Principal UID remains the canonical Agent identity.

---

## 5. Agent lifecycle

### LOCKED

The conceptual Agent lifecycle is:

```text
CREATED
→ ACTIVE
↔ PAUSED
→ RETIRED
```

Semantics:

- **CREATED** — Agent identity exists but is not yet permitted normal autonomous work.
- **ACTIVE** — eligible for assignment and execution subject to policy.
- **PAUSED** — identity/history remain intact; new autonomous work is blocked.
- **RETIRED** — permanently removed from normal assignment while historical identity remains preserved.

### LOCKED

Retirement does not rewrite historical ownership, tasks, decisions, evidence, or memory lineage.

Hard deletion is not normal lifecycle behavior.

Exact database mapping may reuse/extend Ankole active/disabled Principal state.

---

## 6. Organizational role classes

### LOCKED

The primary AI organizational role classes are:

```text
AI SUPERVISOR
AI MANAGER
AI SPECIALIST
AI REVIEWER
```

The Company Owner is a human authority, not an AI role class.

### LOCKED

Each active Agent has one primary organizational role class at a time.

Changing role class does not change Agent identity.

A role may also carry a human-readable domain title such as:

- Finance Manager;
- Research Specialist;
- Code Reviewer;
- Operations Supervisor.

The title is descriptive. The role class controls organizational semantics.

---

## 7. Primary AI Supervisor

### LOCKED

Each active Company has one designated **Primary AI Supervisor**.

The Primary AI Supervisor is the top AI operational coordinator beneath the human Company Owner.

It may:

- coordinate Company AI work;
- route goals into missions/tasks;
- delegate within granted authority;
- monitor work state;
- escalate to the Owner.

It may not:

- replace the Owner;
- grant itself permissions;
- approve actions reserved for the Owner;
- rewrite governance.

A future deputy/acting mechanism may exist, but only one Primary AI Supervisor is authoritative at a time.

---

## 8. AI Manager

### LOCKED

An AI Manager is accountable for a bounded organizational unit, workstream, or functional responsibility.

It may:

- decompose assigned objectives;
- create/delegate tasks within scope;
- coordinate Specialists;
- request Reviewers;
- monitor task state;
- escalate blockers.

Manager authority is bounded by Company structure and MA-06 AuthZ.

---

## 9. AI Specialist

### LOCKED

An AI Specialist is primarily an execution role.

It may:

- perform assigned tasks;
- use allowed tools/skills;
- create bounded subtasks when explicitly permitted;
- report results, uncertainty, blockers, and evidence.

A Specialist cannot gain managerial or review authority merely by creating work.

---

## 10. AI Reviewer

### LOCKED

An AI Reviewer is an assurance role.

It evaluates work against explicit criteria such as:

- correctness;
- completeness;
- evidence;
- policy;
- architecture;
- quality;
- safety.

### LOCKED

A formal review gate must use a **different Principal** from the primary executor of the reviewed work.

Self-review may be used as an internal quality check but cannot satisfy a formal independent-review requirement.

If a Reviewer materially changes the work rather than only reviewing it, that Reviewer becomes a contributor/executor for that revision and another independent review is required where formal independence is mandated.

### LOCKED

Reviewer approval is not equivalent to:

- AuthZ;
- Owner approval;
- Action Assurance approval.

Those remain separate.

---

## 11. Role hierarchy vs authority

### LOCKED

Organizational hierarchy governs responsibility and routing.

It does not automatically grant technical permission.

Conceptually:

```text
OWNER
  ↓
PRIMARY AI SUPERVISOR
  ↓
AI MANAGER(S)
  ↓
AI SPECIALIST(S)

AI REVIEWER(S)
  └── independent assurance assignments across the structure
```

Reviewers belong to the Company organization but need not sit beneath the executor they review.

Exact permission enforcement belongs to MA-06.

---

## 12. Mission

### LOCKED

A Mission is a durable, versioned mandate assigned to an Agent or organizational unit.

A Mission describes:

- why the Agent/unit exists in this context;
- responsibility;
- scope;
- expected outcomes;
- boundaries;
- escalation expectations;
- relationship to Company goals.

A Mission is not a to-do item.

A Mission may produce many Tasks over time.

### LOCKED

Each active Agent has one current effective Mission revision.

Mission changes are governed revisions; old revisions remain historically traceable.

### LOCKED

The existing Ankole Agent `MISSION` document is a compatible semantic/runtime surface.

The authoritative Mission concept must have one trusted source of truth. `/agents/<agent>/MISSION.md` remains a runtime projection, never an independent authority.

Implementation may reuse/extend the existing PostgreSQL-backed Agent Library mission state rather than duplicating it.

---

## 13. Task

### LOCKED

A **Task** is the canonical SerapeumOS bounded unit of accountable work.

Every Task must resolve to:

- Company;
- objective;
- origin/requester;
- accountable Agent;
- scope;
- required outcome;
- acceptance criteria or completion condition;
- lifecycle state;
- lineage to Goal/Mission/parent Task where applicable.

Additional fields such as priority, due date, dependencies, required review, risk class, and resources may be added by later domains.

### LOCKED

Every Task has exactly one **accountable Agent** at a time.

Other Agents may contribute, but accountability cannot be ambiguous.

Reassignment must be explicit and historically traceable.

---

## 14. Task lifecycle

### LOCKED

The canonical Task lifecycle semantics are:

```text
PROPOSED
→ READY
→ ASSIGNED
→ IN_PROGRESS
→ WAITING
→ REVIEW
→ COMPLETED

Terminal alternatives:
FAILED
CANCELLED
```

Not every Task must visit every non-terminal state.

### LOCKED

- **PROPOSED** — candidate work, not yet committed.
- **READY** — valid work ready for assignment/execution.
- **ASSIGNED** — accountable Agent selected.
- **IN_PROGRESS** — active execution.
- **WAITING** — cannot proceed until a typed dependency, human input, resource, event, or condition is satisfied.
- **REVIEW** — execution result is awaiting required quality/review gate.
- **COMPLETED** — completion criteria satisfied and required review/acceptance passed.
- **FAILED** — task cannot complete under current execution/constraints.
- **CANCELLED** — intentionally terminated.

Waiting must carry a reason; it cannot be an unexplained limbo state.

Implementation may add sub-status detail while preserving these semantics.

---

## 15. Completion is not execution success

### LOCKED

A successful Worker turn, Agent Call, background job, or workflow run does not automatically mean the Company Task is complete.

Task completion requires its own acceptance criteria to be satisfied.

Likewise, a failed execution attempt does not automatically mean the Task is permanently failed if policy permits retry or alternate execution.

---

## 16. Task origin and lineage

### LOCKED

A Task may originate from:

- explicit Owner request;
- Company goal;
- active Mission;
- Supervisor/Manager delegation;
- approved workflow;
- approved System Evolution change;
- external event admitted through governed channels.

Every Task preserves origin lineage.

An Agent cannot fabricate an authoritative Owner request or Company goal.

---

## 17. Delegation

### LOCKED

Delegation creates explicit child work or reassigns accountability; it does not create invisible work.

Required principles:

1. delegation is traceable;
2. parent/child lineage is durable;
3. delegated scope cannot exceed parent authority;
4. delegated capability must be equal or narrower than the delegator's permitted scope;
5. delegation does not silently transfer parent accountability;
6. delegation depth/concurrency are bounded by policy/resources;
7. Agents cannot delegate around review, approval, or governance gates.

Exact capability attenuation belongs to MA-06.

---

## 18. Subtasks

### LOCKED

A Task may be decomposed into Subtasks.

Each Subtask is itself a Task with:

- its own accountable Agent;
- lifecycle;
- acceptance criteria;
- parent Task reference.

Parent completion depends on its declared child-completion policy.

A Subtask is not merely an untracked prompt sent to another Agent.

---

## 19. Review

### LOCKED

A Task may define a formal review requirement.

Canonical review outcomes are:

```text
APPROVED
CHANGES_REQUIRED
REJECTED
INCONCLUSIVE
```

### LOCKED

Formal review produces durable review evidence linked to:

- reviewed Task;
- reviewed result/revision;
- Reviewer Principal;
- criteria;
- verdict;
- rationale/evidence.

A later changed result invalidates review of the earlier revision unless policy explicitly determines the change is non-material.

---

## 20. Owner interaction and escalation

### LOCKED

The Owner can direct the Company and may address any Agent where product UX permits.

Normal autonomous work routing should use the organizational structure rather than require the Owner to micro-manage every Agent.

Agents must escalate when:

- required authority is absent;
- required Owner decision is needed;
- mission/task is contradictory;
- evidence is insufficient for a required decision;
- a safety/governance boundary would otherwise be crossed;
- a task cannot proceed without changing architecture/policy.

Escalation is a valid work outcome, not a failure to be hidden.

---

## 21. Workflow

### LOCKED

A Workflow is a durable orchestration of tasks/steps, dependencies, branching, and Agent calls.

A Workflow is not the Company Task itself.

A Task may:

- execute directly;
- own one Workflow run;
- create child Tasks;
- use a combination of these.

### LOCKED

SerapeumOS should reuse the inherited Ankole Workflow engine where its semantics fit.

Current Ankole Workflow run lifecycle:

```text
running → completed | failed | cancelled
```

Current Agent Call lifecycle:

```text
queued → running ↔ sleeping → succeeded | failed | cancelled
```

These remain execution-level states beneath the SerapeumOS Task state.

---

## 22. Background Agent Job

### LOCKED

Ankole `BackgroundAgentJob` remains an execution mechanism for durable long-running Agent work.

Its current states include:

```text
queued
running
waiting_on_user
succeeded
failed
stopped
```

These do not become the canonical SerapeumOS Task lifecycle.

A Company Task may use one or more BackgroundAgentJobs as execution attempts/continuations while retaining one authoritative Task identity and state.

---

## 23. Actor turn

### LOCKED

An Actor turn is the smallest live Agent execution interaction/attempt in this model.

A Turn:

- belongs to execution history;
- may succeed, fail, retry, or be superseded;
- does not own Mission;
- does not own Task identity;
- does not own organizational authority.

Task/Workflow truth remains in the trusted control plane.

---

## 24. Task execution mapping

### LOCKED

Conceptually:

```text
SerapeumOS Task
   │
   ├── Direct Agent execution
   │      └── Actor Turn(s)
   │
   ├── Background work
   │      └── BackgroundAgentJob
   │             └── Turn(s)
   │
   └── Structured orchestration
          └── Workflow Run
                 └── Agent Calls
                        └── Turn(s)
```

The execution mechanism may change without changing Task identity.

---

## 25. Task result

### LOCKED

A Task result is durable execution/output evidence associated with the Task.

It must preserve enough information to distinguish:

- produced output;
- evidence/source lineage;
- executor(s);
- relevant execution attempt;
- review state;
- acceptance state;
- failure/uncertainty where applicable.

Detailed provenance semantics belong to MA-05 and storage layout to MA-09.

---

## 26. Retry and continuation

### LOCKED

Retry creates a new execution attempt against the same logical Task unless the work itself has been materially redefined.

Materially redefining objective/scope creates a new Task revision or new Task according to policy.

Retry must not erase failed-attempt history.

Detailed idempotency, fencing, retry limits, and recovery belong to MA-12.

---

## 27. Cancellation and stop

### LOCKED

Task cancellation is an authoritative control-plane decision.

Stopping one Worker/Turn is not automatically equivalent to cancelling the Task.

The system must distinguish:

- runtime interruption;
- execution-attempt failure;
- Task pause/wait;
- Task cancellation.

This prevents infrastructure events from silently rewriting business work state.

---

## 28. Mission/role/task mutation authority

### LOCKED

Agents may propose changes to:

- role;
- mission;
- task scope;
- task assignment;
- review plan.

They cannot directly make authoritative changes that exceed their organizational/governed authority.

No Agent may self-promote from Specialist to Manager/Supervisor, rewrite its authoritative Mission, or mark its own formally reviewed work approved without trusted-domain validation.

---

## 29. Model changes

### LOCKED

Model selection may vary by Agent, Task, Workflow step, or execution attempt without changing:

- Agent identity;
- role;
- Mission;
- Task ownership.

Model assignment belongs to MA-07.

---

## 30. Concurrency

### LOCKED

One Agent may have multiple queued Tasks.

Concurrent execution is allowed only when:

- Agent/runtime policy allows it;
- MA-01/MA-02 isolation remains valid;
- MA-11 resources permit it;
- task ordering/dependency rules permit it.

Concurrency never changes accountability.

---

## 31. Historical truth

### LOCKED

Role, Mission, task assignment, delegation, review, and lifecycle changes preserve history.

The system must be able to answer:

- who was responsible;
- under what Mission;
- in which role;
- who delegated the work;
- which Agent executed it;
- who reviewed it;
- what state transitions occurred.

Current state does not overwrite historical organizational truth.

---

## 32. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| Company structure | MA-03 |
| evidence/memory/provenance | MA-05 |
| permissions/capabilities/approvals | MA-06 |
| models | MA-07 |
| tools/skills | MA-08 |
| physical schema/storage | MA-09 |
| secrets | MA-10 |
| quotas/concurrency budgets | MA-11 |
| retries/idempotency/recovery | MA-12 |
| observability/audit implementation | MA-14 |
| evolution-generated tasks | MA-15 |
| work-management UX | MA-16 |

These deferrals do not block MA-04 closure.

---

## 33. Veto conditions

An MA-04 implementation is invalid if it:

- treats model identity as Agent identity;
- treats Worker/VM identity as Agent identity;
- creates a second competing Agent identity model;
- uses prompts as the only Task record;
- treats Workflow/Job/Turn as the sole Company Task identity;
- allows Tasks without an accountable Agent;
- permits invisible/untraceable delegation;
- lets delegated authority exceed parent authority;
- permits formal self-review;
- lets Agents self-promote or rewrite authoritative Missions without governance;
- marks Task complete solely because an execution process exited successfully;
- erases earlier role/mission/task/review history when current state changes.

---

## 34. MA-04 closure decision

### CLOSED

MA-04 is architecture-complete.

Locked:

- persistent Agent identity;
- Agent lifecycle;
- Supervisor / Manager / Specialist / Reviewer role classes;
- one Primary AI Supervisor per active Company;
- durable versioned Mission;
- canonical SerapeumOS Task;
- one accountable Agent per Task;
- Task lifecycle;
- explicit delegation/subtask lineage;
- independent formal review;
- Task completion separate from runtime success;
- reuse of Ankole Workflow, BackgroundAgentJob, and Actor turns as execution mechanisms;
- historical work/accountability preservation.

No material MA-04 architecture question remains inside this domain.

---

## 35. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-045 — Agent identity is independent from role, mission, model and runtime
The Ankole Agent Principal remains the stable Agent identity across role, Mission, model, Worker, appliance, and task changes.

### D-046 — Canonical work hierarchy
SerapeumOS uses Goal → Mission → Task → execution. Workflow, BackgroundAgentJob, Agent Call and Actor Turn are execution mechanisms beneath the canonical Task.

### D-047 — Primary AI role classes
The organizational AI role classes are Supervisor, Manager, Specialist, and Reviewer. Each active Agent has one primary role class at a time.

### D-048 — One Primary AI Supervisor
Each active Company has one designated Primary AI Supervisor beneath the human Company Owner.

### D-049 — One accountable Agent per Task
Every committed Task has exactly one accountable Agent at a time; contributions and delegation do not make accountability ambiguous.

### D-050 — Formal review requires independent Principal
A formal review gate cannot be satisfied by the primary executor of the reviewed revision.

### D-051 — Delegation is explicit and authority-attenuating
Delegated work has durable lineage and may not exceed the authority/scope from which it was delegated.

### D-052 — Runtime success is not Task completion
Workflow, Job, Agent Call, or Turn success is execution evidence; canonical Task completion requires Task acceptance criteria and required review.

### D-053 — MISSION.md is projection, not authority
The Agent Mission is trusted durable semantic state; Worker-visible `MISSION.md` is a projection of that state.

---

## 36. Project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED
MA-02 — CLOSED
MA-03 — CLOSED
MA-04 — CLOSED

Current architecture domain:
MA-05 — Memory / Knowledge / Provenance / Epistemic Governance

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-05-CLOSE — architecture only
```

---

## 37. Next action

**MA-05-CLOSE — Memory / Knowledge / Provenance / Epistemic Governance**

Architecture only.
