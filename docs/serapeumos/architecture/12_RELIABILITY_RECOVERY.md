# MA-12 — Reliability / Checkpoint / Idempotency / Cancellation / Crash Recovery

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-12 defines how SerapeumOS remains correct when processes, Workers, Agent Appliances, models, tools, networks, or the host fail.

It governs:

- durable execution intent;
- execution attempts;
- checkpoints;
- leases and liveness;
- fencing;
- idempotency;
- retries;
- cancellation;
- interruption;
- stale/late completion;
- crash recovery;
- ambiguous side effects;
- reconciliation;
- restart semantics.

MA-12 does not define backup/disaster recovery, audit retention, host-specific restart mechanisms, or numeric qualification thresholds. Those belong to later MA domains.

---

## 2. Governing reliability principle

### LOCKED

> Runtime state is expendable. Committed trusted state is authoritative.

A process, Worker, appliance, model call, browser, tool, or host may fail.

Failure must not silently:

- duplicate consequential effects;
- resurrect cancelled work;
- accept stale Worker output;
- mark incomplete work complete;
- lose committed Company truth;
- broaden authority;
- overwrite newer state.

---

## 3. Existing Ankole reliability substrate

### REPOSITORY FACT

The inherited foundation already provides useful reliability primitives:

- PostgreSQL-backed durable execution state;
- runtime notifications/wakeups derived from committed PostgreSQL rows;
- Worker/session assignments treated as rebuildable placement hints;
- Worker readiness/liveness and capacity state;
- actor activation leases;
- full turn references and route/revision fencing;
- transactional turn admission;
- accepted vs completed turn separation;
- retryable turn errors and bounded dead-letter behavior;
- bounded BackgroundAgentJob attempt/failure counters;
- durable workflow/job/turn records;
- durable Outbox intents with idempotency keys;
- outbox recovery/reconciliation after ambiguous in-flight delivery;
- explicit stopped/failure paths.

### LOCKED

SerapeumOS reuses these primitives rather than creating a second reliability engine.

SerapeumOS adds Company Task semantics, Action Assurance, appliance isolation, and stronger reliability doctrine above them.

---

## 4. Reliability state hierarchy

### LOCKED

SerapeumOS distinguishes:

| Level | Meaning | Authority |
|---|---|---|
| **L0 — Task Intent** | committed Company work objective and lifecycle | authoritative |
| **L1 — Execution Attempt** | one admitted attempt to perform Task work | authoritative execution truth |
| **L2 — Durable Checkpoint** | committed recoverable progress for an attempt | authoritative only for what it explicitly records |
| **L3 — Runtime Working State** | model context, Worker-local thread, process state | non-authoritative |
| **L4 — Side-Effect Intent** | durable intent to perform external/consequential action | authoritative intent |
| **L5 — Side-Effect Receipt** | verified/reconciled result of action | authoritative execution evidence |

### LOCKED

Loss of L3 may reduce continuity/efficiency, but must not invalidate L0/L1/L2/L4/L5.

---

## 5. Task identity vs execution attempt

### LOCKED

A Task is the durable unit of accountable work from MA-04.

An **Execution Attempt** is one concrete attempt to advance that Task.

```text
Task
 ├── Attempt 1
 ├── Attempt 2
 └── Attempt 3
```

A retry normally creates or advances an execution-attempt identity without changing Task identity.

### LOCKED

Attempt history is preserved.

A later successful attempt does not erase earlier failed/interrupted attempts.

---

## 6. Attempt identity

### LOCKED

Every execution attempt must be durably identifiable.

It must resolve to:

- Task;
- accountable Agent;
- Company;
- attempt number/identity;
- admitted model/profile binding where applicable;
- relevant runtime/appliance assignment;
- start/admission state;
- terminal/interruption state.

Exact schema belongs to implementation.

---

## 7. Durable-before-runtime rule

### LOCKED

Where an execution decision matters to recovery, durable trusted state is committed **before** untrusted runtime work depends on it.

Examples:

- Task assignment;
- execution-attempt admission;
- model binding;
- Worker/appliance assignment;
- side-effect intent;
- cancellation request;
- approval state.

### LOCKED

A runtime-only decision is not sufficient evidence after crash.

---

## 8. Commit-after-notify rule

### LOCKED

Notifications, wakeups, timers, and in-memory scheduler signals are accelerators, not authority.

The canonical pattern is:

```text
commit durable state
→ emit/derive wakeup
→ runtime reacts
```

If the wakeup is lost, restart/reconciliation must be able to rediscover the durable work.

This preserves the current Ankole RuntimeEvents doctrine.

---

## 9. Leases are liveness, not truth

### LOCKED

Worker, activation, resource, and execution leases represent bounded liveness/ownership expectations.

A lease:

- may expire;
- may be renewed;
- may be revoked;
- is not proof of completion;
- is not durable business truth.

### LOCKED

Lease expiry means the system must reassess/recover ownership.

It must not automatically mean:

- Task failed;
- Task completed;
- external action did not occur.

---

## 10. Fencing

### LOCKED

Every runtime capable of committing execution results must be fenced against stale ownership.

Fencing must use enough current identity/revision evidence to distinguish the active execution from:

- an old Worker;
- an old appliance;
- an old activation;
- an old route;
- an old attempt;
- a superseded Task assignment.

### LOCKED

Late messages from stale runtime incarnations are rejected rather than merged optimistically.

---

## 11. Existing turn fences

### LOCKED

SerapeumOS retains the inherited Ankole pattern of full turn/activation/route/revision validation.

The exact fields may evolve, but final semantics require:

```text
current Agent/session
+ current attempt/activation
+ current Worker/runtime incarnation
+ current revision/epoch
+ valid route/assignment
```

before a runtime write may affect authoritative execution state.

---

## 12. Worker assignment

### LOCKED

Worker/appliance placement is recoverable runtime state, not Company truth.

If an assigned Worker disappears:

- its assignment may be released;
- a new eligible runtime may be assigned;
- authoritative Task/attempt state remains.

### LOCKED

Worker-local context that cannot be reconstructed is treated as lost working context, not lost authoritative truth.

---

## 13. Resume vs restart

### LOCKED

SerapeumOS distinguishes:

### Resume

Continue the same execution attempt from a durable checkpoint whose continuation semantics are valid.

### Restart

Start a new execution attempt from authoritative Task inputs/state.

### LOCKED

The system must not claim “resume” when only a best-effort reconstruction is possible.

If Worker-local/model-local context is lost and no semantically sufficient checkpoint exists, the correct behavior is a new attempt/restart.

---

## 14. Checkpoint purpose

### LOCKED

A checkpoint exists to reduce lost work while preserving correctness.

A checkpoint is not simply “whatever was in memory.”

A valid durable checkpoint must be:

- attributable to Task/attempt;
- versioned/fenced;
- committed through trusted state;
- internally valid;
- safe to re-read after restart.

---

## 15. Checkpoint classes

### LOCKED

SerapeumOS recognizes conceptual checkpoint classes:

### C0 — Control checkpoint

Durable Task/attempt/lifecycle state.

### C1 — Work-product checkpoint

Committed immutable Artifact(s) representing partial work.

### C2 — Execution continuation checkpoint

Structured state sufficient to continue the same attempt safely.

### C3 — Presentation/UI checkpoint

Recoverable partial presentation state; not Task completion.

### C4 — External-action checkpoint

Durable Action Assurance/outbox state describing what external effect is pending/in-flight/reconciled.

---

## 16. Working context is not checkpoint by default

### LOCKED

Model context, Worker-local Codex thread, browser memory, shell state, process memory, and temporary filesystem state are Working Context.

They are not durable checkpoints unless explicitly serialized and validated into an approved checkpoint form.

### LOCKED

Loss of Working Context may require restart.

The system must not silently infer missing context.

---

## 17. Checkpoint frequency

### LOCKED

Checkpoint frequency is based on:

- cost of recomputation;
- external consequence;
- execution duration;
- artifact size;
- reliability requirements;
- resource pressure.

It is not required after every token/tool call.

Exact cadence is task/runtime policy and MA-20 qualification data.

---

## 18. Checkpoint consistency

### LOCKED

A checkpoint may only claim the state it atomically/consistently commits.

If a checkpoint references Artifacts, those Artifacts must already be committed/verified under MA-09 before the checkpoint becomes live.

A partial checkpoint must remain identifiable as partial.

---

## 19. Idempotency doctrine

### LOCKED

SerapeumOS assumes retries can happen.

Therefore repeatable operations must either:

1. be naturally idempotent;
2. use an explicit idempotency key;
3. detect prior completion;
4. reconcile ambiguous prior execution before repeating.

### LOCKED

“Retry and hope” is not an acceptable consequential-action strategy.

---

## 20. Idempotency key

### LOCKED

An idempotency key binds to one logical operation/intent.

It must be stable across retries of that same logical operation and different for materially different operations.

Conceptually it may include/reference:

- Company;
- Task;
- action/operation identity;
- target;
- logical intent/revision.

Exact encoding is implementation design.

---

## 21. Database idempotency

### LOCKED

Trusted relational mutations should use transaction/uniqueness/state-transition techniques so duplicate delivery/retry cannot create duplicate authoritative outcomes.

Examples include:

- unique constraints;
- compare-and-set/revision checks;
- transactional status transitions;
- upsert-by-stable-key.

---

## 22. External side effects

### LOCKED

SerapeumOS does **not** claim universal exactly-once delivery for external systems.

For external side effects, the architecture targets:

- durable intent;
- idempotent request where supported;
- bounded dispatch;
- provider reconciliation where possible;
- durable receipt/outcome;
- explicit ambiguity when exact outcome cannot be proven.

### LOCKED

If an external provider does not support idempotency or reliable reconciliation, SerapeumOS must surface residual duplication/uncertainty risk rather than pretending exactly-once semantics.

---

## 23. Outbox pattern

### LOCKED

Consequential/provider-visible side effects should use the durable-intent pattern where appropriate:

```text
trusted transaction commits side-effect intent
→ wakeup/dispatcher claims intent
→ external operation occurs
→ response/reconciliation captured
→ durable terminal receipt/state
```

### LOCKED

The current Ankole Outbox pattern is retained as the preferred foundation for asynchronous external messaging/provider effects.

Its durable `outbound_key`/idempotency contract is aligned with MA-12.

---

## 24. In-flight ambiguity

### LOCKED

A crash may occur after an external operation was sent but before SerapeumOS committed the result.

This state is:

```text
IN_FLIGHT / OUTCOME_UNKNOWN
```

not automatically failed and not automatically successful.

### LOCKED

Recovery first reconciles the provider/target where possible.

Only if policy says retry is safe may the system repeat the operation.

---

## 25. Action Assurance interaction

### LOCKED

MA-06 Action Assurance remains authoritative for consequential actions.

A retry of an exact approved action may reuse approval only if:

- the action identity is unchanged;
- target/preconditions remain valid;
- approval has not expired/revoked;
- MA-06 policy permits retry.

Otherwise the action re-enters assurance.

---

## 26. Publication idempotency

### LOCKED

MA-09 publication uses exact source Artifact + exact target + observed target state.

After crash, publication recovery must determine whether the intended bytes were actually published before attempting replacement again.

A digest-matching verified target may establish successful completion.

A changed/ambiguous target requires reconciliation/reapproval policy.

---

## 27. Retry classes

### LOCKED

Failures are classified before retry.

Conceptual classes:

| Class | Meaning |
|---|---|
| **TRANSIENT** | likely safe to retry after bounded delay |
| **RESOURCE/BACKPRESSURE** | wait/requeue without treating work itself as failed |
| **DEPENDENCY_UNAVAILABLE** | wait/fallback/fail according to policy |
| **DETERMINISTIC INPUT/LOGIC FAILURE** | retry normally useless until something changes |
| **AUTHORITY/POLICY FAILURE** | do not retry until authority/state changes |
| **AMBIGUOUS SIDE EFFECT** | reconcile before retry |
| **CORRUPTION/SECURITY FAILURE** | stop/quarantine/escalate |

An Agent cannot relabel a failure merely to obtain more retries.

---

## 28. Retry budget

### LOCKED

Retries are finite.

Budgets may exist by:

- attempt;
- Task;
- provider/tool;
- failure class;
- time window.

The inherited bounded Ankole retry/dead-letter patterns are retained.

Exact counts/delays are implementation/qualification data.

---

## 29. Backoff

### LOCKED

Retryable external/runtime failures use bounded backoff appropriate to the dependency.

Backoff prevents tight failure loops and resource starvation.

Backoff cannot become unbounded limbo; terminal/escalation policy must exist.

---

## 30. Retry model binding

### LOCKED

MA-07 model-binding rules apply.

A retry of the same admitted attempt does not silently switch to a materially different model/runtime binding.

A changed binding creates/re-admits a new execution attempt where required.

---

## 31. Task cancellation

### LOCKED

Task cancellation is authoritative Task state from MA-04.

It is not equivalent to killing a Worker process.

Canonical cancellation propagation:

```text
record CANCEL_REQUESTED / authoritative cancel intent
→ stop new child/subtask admission
→ revoke Task-scoped capabilities where applicable
→ signal active execution to stop
→ bounded cooperative drain
→ force-stop runtime if necessary
→ fence late results
→ reconcile any in-flight side effects
→ commit terminal Task cancellation when safe
```

Exact intermediate status names are implementation design.

---

## 32. Cancellation race

### LOCKED

Completion and cancellation may race.

The trusted control plane resolves the race through transactional/revision ordering.

There must be one authoritative terminal outcome for the Task revision.

### LOCKED

A stale Worker cannot overwrite a committed cancellation with late success.

Likewise, a cancellation arriving after already committed valid completion cannot rewrite history as if the work never completed.

---

## 33. Side effects before cancellation

### LOCKED

Cancellation does not erase side effects that already occurred.

If an external action completed before cancellation:

- its receipt/history remains;
- compensation/undo may be initiated if available and separately authorized;
- the system must not represent the world as though the action never happened.

---

## 34. Cancellation vs pause/wait

### LOCKED

SerapeumOS distinguishes:

- **WAITING** — Task remains active but blocked on dependency;
- **PAUSED/INTERRUPTED EXECUTION** — runtime stopped without cancelling Task;
- **CANCELLED** — authoritative decision to terminate the Task;
- **FAILED** — Task cannot satisfy completion under current contract.

Infrastructure failure must not silently become Task cancellation.

---

## 35. Owner/global stop

### LOCKED

MA-01 global stop can force execution halt independently of Agent cooperation.

Global stop may:

- revoke runtime authority;
- stop new admissions;
- kill appliances;
- freeze external dispatch where safely possible.

### LOCKED

Global stop is not permission to corrupt durable state.

Recovery resumes from trusted committed state.

---

## 36. Crash domains

### LOCKED

SerapeumOS handles failure independently across:

- Agent turn;
- Worker process;
- Agent Appliance;
- model runtime;
- tool/browser/MCP process;
- Control Plane process;
- PostgreSQL connection/process;
- host reboot/power interruption.

The failure of one domain must not automatically imply loss of another domain's durable truth.

---

## 37. Control Plane restart

### LOCKED

After Control Plane restart:

1. reconnect/validate PostgreSQL;
2. reconstruct authoritative runtime state from durable rows;
3. rebuild timers/wakeups/deadlines;
4. identify stale runtime leases/assignments;
5. reconcile in-flight work;
6. resume/requeue eligible work;
7. remain fail-closed where state is ambiguous.

### LOCKED

In-memory scheduler state is not required to reconstruct committed work.

---

## 38. Worker crash

### LOCKED

When a Worker/Agent Appliance disappears:

- its active runtime incarnation becomes stale;
- assignments are released/reconciled;
- late messages are fenced;
- Task/attempt state is inspected;
- valid checkpoints determine resume eligibility;
- otherwise a new attempt may restart work;
- external side effects are reconciled before retry.

---

## 39. Model runtime crash

### LOCKED

A model runtime crash is an inference dependency failure, not an Agent identity failure.

Recovery follows MA-07:

- restart same qualified runtime/binding where possible;
- retry within budget;
- use only approved fallback;
- otherwise wait/fail.

No authority changes.

---

## 40. Host reboot / power loss

### LOCKED

After host restart, SerapeumOS must be able to reconstruct authoritative Company and execution state without relying on surviving process memory.

Runtime processes/appliances may be recreated.

Any work that was executing at power loss enters recovery/reconciliation before further consequential effects.

### LOCKED

Automatic restart must not automatically resume high-impact external effects unless their exact action/reconciliation state permits it.

---

## 41. Recovery coordinator

### LOCKED

Recovery is a trusted control-plane responsibility.

A Recovery Coordinator function/process may exist to:

- scan non-terminal durable state;
- detect expired leases;
- reconcile runtime ownership;
- identify orphan/in-flight actions;
- requeue eligible work;
- mark irrecoverable/ambiguous work;
- escalate to Owner when needed.

### LOCKED

Recovery decisions do not depend on Agent self-report alone.

---

## 42. Orphan state

### LOCKED

SerapeumOS recognizes orphan/reconciliation conditions such as:

- attempt says running but no valid runtime exists;
- runtime exists but assignment is stale;
- side-effect intent is in-flight after crash;
- temporary Artifact exists without live DB reference;
- DB reference expects missing Artifact;
- Task waits on a vanished dependency.

Each class has an explicit recovery path.

Silent orphan accumulation is not acceptable.

---

## 43. Dead-letter / terminal infrastructure failure

### LOCKED

Repeated recoverable failures eventually terminate or escalate.

Dead-lettering means:

- automated retry budget exhausted;
- durable failure evidence exists;
- the system stops looping;
- Owner/Manager may inspect/retry under a new decision.

It does not mean the failed output becomes accepted.

---

## 44. Compensation

### LOCKED

Where an external or internal side effect supports compensation/undo, compensation is a **new governed action**.

It requires:

- authority;
- exact target/action;
- Action Assurance according to risk;
- receipt.

Rollback is not assumed universally possible.

---

## 45. Partial workflows

### LOCKED

A Workflow with multiple completed steps does not automatically rollback all prior steps when a later step fails.

The Workflow/Task contract must distinguish:

- retryable step;
- compensatable step;
- irreversible completed step;
- terminal partial result.

The system must expose partial completion honestly.

---

## 46. Exactly-once terminology

### LOCKED

SerapeumOS may claim **exactly-once authoritative commit** only where its own transactional constraints actually guarantee it.

For remote/external effects, the product must use precise terms such as:

- idempotent;
- deduplicated;
- at-most-once requested;
- at-least-once attempted;
- reconciled;
- outcome unknown.

It must not market universal exactly-once external execution.

---

## 47. Completion rule

### LOCKED

A Task is complete only when:

- required work-product state is committed;
- acceptance criteria are satisfied;
- required review is complete;
- required consequential actions have known acceptable outcomes;
- no mandatory unresolved recovery ambiguity remains.

A Worker returning success is insufficient by itself.

---

## 48. Failure transparency

### LOCKED

The system must represent uncertainty explicitly.

Possible result states include:

- succeeded;
- failed;
- cancelled;
- waiting;
- interrupted;
- retrying;
- outcome unknown;
- reconciliation required.

SerapeumOS must not convert “unknown after crash” into success or failure without evidence.

---

## 49. Recovery and Epistemic Truth

### LOCKED

Recovery state is Execution Truth.

A model's inference about what “probably happened” cannot resolve an ambiguous execution outcome.

Resolution requires trusted evidence such as:

- committed DB state;
- verified Artifact;
- external provider query;
- target digest/state;
- action receipt;
- trusted system observation.

---

## 50. Resource pressure interaction

### LOCKED

MA-11 preemption may interrupt execution.

Preemption:

- preserves Task identity;
- records interruption;
- releases/reclaims resources;
- uses checkpoint/restart semantics;
- cannot skip reconciliation for consequential actions.

---

## 51. Secret/security interaction

### LOCKED

Runtime credential expiry/revocation from MA-10 may interrupt work.

Recovery creates a new runtime credential/incarnation rather than restoring stale authentication material.

A replaced runtime cannot reuse an invalidated security identity.

---

## 52. Artifact/storage interaction

### LOCKED

MA-09 immutable Artifacts are preferred checkpoint/output anchors.

A successful partial output may be committed as an Artifact without marking the Task complete.

Recovery can reference immutable prior work rather than trusting mutable workspace files.

---

## 53. Observability interaction

### LOCKED

Every material reliability transition must be auditable enough to reconstruct:

- attempt identity;
- prior state;
- failure/interruption reason;
- retry/recovery decision;
- Worker/runtime incarnation;
- checkpoint used;
- side-effect state;
- terminal outcome.

MA-14 owns retention/presentation.

---

## 54. System Evolution interaction

### LOCKED

MA-15 may learn from failures and propose:

- retry-policy changes;
- checkpoint changes;
- better failure classification;
- improved recovery strategy.

It cannot silently weaken fencing, increase retries without bounds, or auto-promote a new reliability policy.

---

## 55. Fail-closed conditions

### LOCKED

The system must stop/reconcile rather than continue when:

- active runtime ownership is ambiguous;
- required Artifact/checkpoint integrity fails;
- action outcome is ambiguous and unsafe to repeat;
- capability/approval validity is unknown;
- fencing state cannot be reconstructed;
- authoritative database state is inconsistent;
- required recovery evidence is missing.

---

## 56. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| Task lifecycle | MA-04 |
| Action Assurance/approval | MA-06 |
| model retry/fallback | MA-07 |
| tool/external action contracts | MA-08 |
| Artifact/publication integrity | MA-09 |
| runtime credentials | MA-10 |
| resource preemption | MA-11 |
| backup/restore/DR | MA-13 |
| audit/receipts/telemetry | MA-14 |
| adaptive reliability proposals | MA-15 |
| recovery/cancel UX | MA-16 |
| host restart/service mechanisms | MA-17 |
| migration/update rollback | MA-18 |
| supply-chain rollback | MA-19 |
| fault/adversarial/endurance thresholds | MA-20 |

These deferrals do not block MA-12 closure.

---

## 57. Veto conditions

An MA-12 implementation is invalid if it:

- treats runtime memory as authoritative truth;
- requires surviving Worker-local state to reconstruct committed work;
- accepts stale Worker output after assignment/attempt replacement;
- retries consequential actions without idempotency/reconciliation policy;
- claims universal exactly-once remote side effects;
- marks unknown external outcomes failed/successful without evidence;
- allows infinite retry loops;
- silently changes model binding on retry;
- treats Worker kill as Task cancellation;
- allows late success to overwrite committed cancellation;
- erases completed external effects when a Task is cancelled;
- claims resume when only restart/reconstruction is possible;
- automatically resumes high-impact effects after host crash without reconciliation;
- lets lost wakeups lose committed work;
- silently accepts corrupted checkpoints;
- reports Task completion solely from process success.

---

## 58. MA-12 closure decision

### CLOSED

MA-12 is architecture-complete.

Locked:

- trusted durable state over runtime state;
- Task vs execution-attempt separation;
- durable-before-runtime and commit-after-notify patterns;
- leases as liveness only;
- runtime fencing;
- explicit resume vs restart;
- durable checkpoint classes;
- Working Context non-authority;
- idempotency and stable operation keys;
- durable Outbox/reconciliation for external effects;
- no universal exactly-once external claim;
- bounded failure-classified retries;
- authoritative cancellation with late-result fencing;
- explicit in-flight ambiguity;
- trusted crash-recovery coordinator semantics;
- host/Worker/model crash reconstruction;
- transparent partial/unknown outcomes;
- compensation as separate governed action.

No material MA-12 architecture question remains inside this domain.

---

## 59. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-121 — Committed trusted state outranks runtime state
Process/Worker/appliance/model context is expendable; PostgreSQL and committed Artifacts/receipts remain recovery authority.

### D-122 — Task and execution attempt are separate
Retries/restarts preserve one Task identity while retaining distinct attempt history and accountability.

### D-123 — Wakeups are not authority
Durable state commits before runtime notification; lost wakeups must be reconstructable from committed rows.

### D-124 — Runtime commits are fenced
Stale Worker/appliance/activation/attempt results cannot mutate current execution truth after ownership changes.

### D-125 — Resume requires a valid durable checkpoint
Loss of Worker/model-local context without a sufficient checkpoint causes restart/new attempt, not false continuation.

### D-126 — Retries require idempotency or reconciliation
Consequential operations must be naturally idempotent, keyed/deduplicated, previously-completed-aware, or reconciled before repeat.

### D-127 — External exactly-once is not assumed
SerapeumOS uses durable intent, provider idempotency where available, reconciliation, and explicit unknown outcomes rather than universal exactly-once claims.

### D-128 — Outbox is the preferred asynchronous side-effect pattern
Durable external-action intent commits before dispatch; delivery/reconciliation then produces terminal evidence.

### D-129 — Cancellation is authoritative work state, not process death
Cancellation propagates through capability revocation, runtime stop, late-result fencing, and side-effect reconciliation while preserving history.

### D-130 — Crash recovery is trusted and evidence-driven
Recovery reconstructs from durable state, reconciles expired/stale runtime ownership and ambiguous actions, and fails closed where evidence is insufficient.

---

## 60. Project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED
MA-02 — CLOSED
MA-03 — CLOSED
MA-04 — CLOSED
MA-05 — CLOSED
MA-06 — CLOSED
MA-07 — CLOSED
MA-08 — CLOSED
MA-09 — CLOSED
MA-10 — CLOSED
MA-11 — CLOSED
MA-12 — CLOSED

Current architecture domain:
MA-13 — Backup / Restore / Quarantine / Disaster Recovery

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-13-CLOSE — architecture only
```

---

## 61. Next action

**MA-13-CLOSE — Backup / Restore / Quarantine / Disaster Recovery**

Architecture only.
