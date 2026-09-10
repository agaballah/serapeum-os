# MA-11 — Resource Governance

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

## 1. Purpose

MA-11 defines how SerapeumOS governs finite local-machine resources while preserving host stability, trusted-control availability, Agent isolation, predictable admission, fairness, recoverability, and bounded consumption.

It governs CPU, RAM, GPU/VRAM, disk capacity/I/O, network consumption, process/concurrency limits, Agent Appliance capacity, browser/MCP/tool process capacity, model residency, execution leases, admission, throttling, preemption, and reclamation.

It does not define retry/checkpoint mechanics, exact host thresholds, model qualification, or host-specific enforcement APIs.

## 2. Governing principle

### LOCKED

> Resource scarcity may queue, throttle, degrade, preempt, pause, or refuse work, but it must never broaden authority, weaken isolation, corrupt authoritative state, disable audit/recovery, or silently delete protected durable data.

Host stability and trusted recovery/control capacity take precedence over maximizing Agent throughput.

## 3. Trusted Resource Governor

### LOCKED

SerapeumOS has a trusted **Resource Governor** operating with the Control Plane / Host Runtime Controller.

It owns resource-policy evaluation, admission, reservation, allocation, enforcement coordination, release/reclamation, and pressure response.

Agents, models, Workers, guest processes, browsers, Skills, plugins, and MCP servers do not control authoritative host allocation.

## 4. Resource state is trusted host evidence

### LOCKED

Resource decisions use measurements from trusted host/runtime adapters where practical, including RAM, CPU pressure, disk headroom, GPU/VRAM, model residency, appliance/process/browser counts, and related host capacity.

Agent or Worker self-reported capacity may support a decision but is not authoritative resource truth.

## 5. Resource governance is not AuthZ

### LOCKED

AuthZ answers **whether the Principal may perform the action**. Resource Governance answers **whether the system can safely allocate local capacity now**.

```text
AuthZ ALLOW
    +
Resource Admission PASS
    =
eligible to execute
```

A resource allocation does not grant permission. Permission does not guarantee immediate resource availability.

## 6. Resource lease is not MA-06 Capability

### LOCKED

A **Capability** represents bounded authority. A **Resource Lease/Reservation** represents bounded capacity.

```text
Capability → what operation is permitted
Resource Lease → how much local capacity may be consumed
```

One cannot substitute for the other.

## 7. Governed resource classes

### LOCKED

Resource Governance covers at least:

- CPU cores/time;
- physical/committed RAM;
- GPU compute and VRAM;
- local model residency;
- durable and ephemeral disk;
- disk I/O;
- network bandwidth/connections;
- process/thread/PID counts;
- Agent Appliance count;
- Agent, Task, job and turn concurrency;
- browser sessions;
- MCP/tool subprocesses;
- artifact/file transfer/output bounds;
- execution wall-clock/resource lease duration.

Additional resource classes may be added without architecture change.

## 8. Hierarchical budgeting

### LOCKED

```text
HOST PHYSICAL CAPACITY
        ↓
SERAPEUMOS SAFETY ENVELOPE
        ↓
COMPANY BUDGET
        ↓
AGENT BUDGET
        ↓
TASK / EXECUTION RESERVATION
        ↓
RUNTIME ENFORCEMENT
```

Even if the first release supports one active Company, Company scope remains explicit.

A child budget cannot exceed its governing parent envelope.

## 9. Ceiling vs reservation

### LOCKED

A resource budget/ceiling defines maximum permitted consumption. A reservation/lease represents capacity admitted for a particular execution.

A configured ceiling is not a guarantee that resources are currently available.

## 10. Hard and soft controls

### LOCKED

SerapeumOS may use hard limits for security/stability, soft quotas for fairness/expected consumption, and priority policy for contention.

Hard limits cannot be bypassed because work has high business priority.

Exact numeric values are configuration/qualification data, not MA-11 constants.

## 11. Host safety reserve

### LOCKED

SerapeumOS preserves headroom for:

- Control Plane;
- PostgreSQL/WAL durability;
- audit/receipts;
- runtime kill/control paths;
- Owner controls;
- recovery operations;
- essential host services.

Untrusted compute is throttled/preempted before trusted safety/recovery capacity is intentionally exhausted.

The system must retain enough control capacity to stop the workload causing pressure.

## 12. Admission control

### LOCKED

Resource-heavy execution is admitted before launch.

Admission applies, where relevant, to Agent Appliance creation, Agent/Task/job/workflow execution, model loading, GPU/VRAM allocation, browsers, MCP/tool subprocesses, and large artifact/import/output operations.

```text
request
→ determine required envelope
→ evaluate current resource state
→ reserve capacity
→ admit execution
→ monitor
→ release/reclaim
```

## 13. No unsafe spillover

### LOCKED

When capacity is insufficient, SerapeumOS may queue, wait, throttle, reduce concurrency, select an explicitly qualified lower-resource path, or refuse.

It may not:

- run outside the qualified isolation boundary;
- share hostile boundaries between different Agents;
- use an unauthorized machine/service;
- silently move execution to cloud infrastructure;
- silently switch to an unqualified model.

## 14. Priority classes

### LOCKED

| Priority | Meaning |
|---|---|
| **P0 — SAFETY / RECOVERY** | Control-plane survival, kill/recovery, critical integrity operations |
| **P1 — OWNER INTERACTIVE / CONTROL** | direct Owner interaction and control operations |
| **P2 — COMMITTED COMPANY WORK** | normal active Company Tasks |
| **P3 — BACKGROUND / LEARNING / EVOLUTION** | low-urgency consolidation, learning, System Evolution, maintenance |

Exact scheduler weights are implementation policy.

Priority changes scheduling, not authority. P0/P1 still cannot bypass AuthZ or constitutional controls.

## 15. Fairness and starvation

### LOCKED

One Agent, Task, background process, or model workload must not indefinitely monopolize shared resources.

Fair-share behavior is required. Implementation may use weighted fairness, bounded concurrency, aging, round-robin, or per-Agent quotas.

Background P3 workloads are the first candidates for delay under pressure. Safety/recovery work may supersede ordinary fairness when necessary.

## 16. Preemption

### LOCKED

The trusted Resource Governor may preempt lower-priority work for host stability, Owner control, recovery, or higher-priority admitted work.

Preferred order:

1. cooperative throttle/drain/pause where safe;
2. checkpoint where supported;
3. stop/release;
4. force-kill untrusted runtime if required.

Infrastructure preemption is **not Task cancellation**. MA-04 Task state and MA-12 recovery semantics remain separate.

## 17. Pressure response ladder

### LOCKED

```text
1. stop/reduce new P3 admission
2. reduce background concurrency
3. release optional browser/tool/MCP processes
4. unload/reduce optional model residency
5. pause/preempt lower-priority Agent work
6. refuse new nonessential work
7. preserve P0/P1 trusted control and recovery capacity
```

Exact thresholds belong to MA-17/MA-20 qualification.

## 18. Memory pressure / OOM

### LOCKED

Agent/Worker memory exhaustion must not destabilize the trusted Control Plane or database where host isolation can prevent it.

The hostile Agent Appliance is expendable and may be terminated/recovered under MA-12.

SerapeumOS does not assume unlimited swap or overcommit.

## 19. CPU governance

### LOCKED

Agent, tool, browser, and inference workloads receive bounded CPU access under host policy.

An Agent cannot raise its own CPU allocation.

CPU contention may reduce throughput but cannot disable trusted kill/recovery control.

## 20. GPU / VRAM governance

### LOCKED

GPU/VRAM resources are governed through the inference/runtime path. The Agent Appliance receives no direct GPU authority by default.

Qualified model bindings should have known/observed resource envelopes sufficient for admission planning.

If required VRAM is unavailable, the system may wait, unload a lower-priority model, use an explicitly qualified alternative, use a qualified CPU path, or refuse. It must not silently load an unqualified substitute.

## 21. Shared model residency

### LOCKED

Local model runtimes may share model residency across Agents where MA-07 isolation/correctness are qualified.

Shared compute does not imply shared Agent identity, context, memory, or authority.

## 22. Agent Appliance resources

### LOCKED

Each hard Agent Appliance receives an externally enforced resource envelope where the selected host backend supports it, including applicable CPU, RAM, disk, process, network, and execution-time constraints.

Inner guest/process limits are defense in depth. The trusted outer host boundary remains authoritative.

Resource pressure can never justify running different Agent Principals concurrently in the same hard hostile-code boundary.

## 23. Concurrency governance

### LOCKED

Concurrency is bounded at multiple levels, including Company, Agent, Appliance, Task, job/workflow, browser, tool/MCP subprocess, and model inference.

An Agent cannot create unlimited parallel work merely because individual operations are authorized.

## 24. Network resource governance

### LOCKED

MA-06/MA-08 determine whether network access is permitted. MA-11 governs consumption such as bandwidth, connections, concurrency, and request rate.

A network resource budget does not grant network authority. Exhaustion must not cause fallback to an ungoverned route.

## 25. Disk capacity governance

### LOCKED

SerapeumOS preserves disk headroom for PostgreSQL/WAL, audit/receipts, Artifact Store consistency, recovery operations, and safe staging.

Cleanup order under pressure is:

```text
ephemeral state
→ rebuildable caches/projections
→ safely collectible unreferenced artifacts
→ pause/refuse new work
```

Protected authoritative state is not silently deleted to make room.

## 26. Authoritative-data protection

### LOCKED

Resource pressure must not automatically delete R0 relational truth, protected R1 artifacts, required audit/recovery state, or policy-protected R2 Agent workspace merely to continue new workload execution.

The correct response is to pause/refuse new work before risking integrity.

## 27. Storage quotas

### LOCKED

SerapeumOS may apply quotas at installation, Company, Agent, workspace, and artifact-class levels.

Quota exhaustion is explicit. The system must not hide it by silently deleting protected data.

Exact limits are configuration/qualification values.

## 28. Existing bounded implementation patterns

### REPOSITORY FACT

Current Ankole already demonstrates bounded resource patterns in subsystems such as Worker file transfers, AIGateway artifacts, browser runtime activity, and MCP configuration/resource counts.

### LOCKED

SerapeumOS retains the architectural requirement that operational resource consumption is bounded.

Existing numeric foundation values are implementation facts, not permanent MA-11 constants.

## 29. Browser / tool / MCP limits

### LOCKED

Browser sessions, tool subprocesses, MCP servers, and extension-driven subprocesses remain finite and attributable.

Extensions cannot remove Resource Governor limits.

## 30. Execution-time leases

### LOCKED

Long-running execution may receive bounded wall-clock/resource leases.

A lease may expire, be renewed by trusted policy, be revoked, or be shortened under pressure.

An Agent cannot indefinitely self-renew its own resource lease.

Lease expiry affects the execution attempt/runtime; it does not automatically cancel the MA-04 Task.

## 31. Reservation reclamation

### LOCKED

Reservations are finite and recoverable.

Capacity is reclaimed when execution completes, runtime dies, Worker is replaced, Task is cancelled, lease expires, or admission rolls back.

A stale runtime cannot retain capacity indefinitely.

Detailed crash fencing belongs to MA-12.

## 32. Resource accounting

### LOCKED

Usage should be attributable, where practical, to Company, Agent, Task/execution, runtime/appliance, model/inference operation, and tool/browser/MCP process.

Trusted host/runtime measurements are the source for enforcement/accounting. Agent-reported usage is not authoritative.

MA-14 owns durable observability/retention.

## 33. Resource policy authority

### LOCKED

Resource budgets/policies are controlled by trusted product defaults, Owner/authorized operator configuration, and qualified host policy.

Agents may report pressure, request resources, and recommend changes. They cannot directly increase their own ceilings.

## 34. System Evolution boundary

### LOCKED

MA-15 System Evolution may recommend changed quotas, scheduling, or model/resource profiles.

It cannot autonomously expand its own or another Agent's authoritative resource envelope without the governing promotion/approval process.

## 35. Overcommit

### LOCKED

Controlled overcommit may be used only where host qualification demonstrates safe behavior.

Hard security/stability guarantees cannot depend on optimistic untrusted self-reporting.

Memory and VRAM admission should be conservative where exhaustion could destabilize the host or inference runtime.

## 36. Local-only rule / no cloud bursting

### LOCKED

Resource scarcity does not create an automatic cloud-burst path.

Final SerapeumOS does not silently use cloud workers, hosted inference, cloud object storage, or remote execution infrastructure.

Temporary NaraRouter use during development/validation does not establish cloud-burst architecture.

## 37. Degraded operation

### LOCKED

SerapeumOS may remain operational in degraded local mode when hardware cannot support full parallel capacity.

Examples include fewer simultaneous Agents, reduced background work, fewer resident models, serialized browser workloads, and queued heavy Tasks.

Reduced capacity is preferable to weakened safety.

## 38. Minimum supported host

### LOCKED

SerapeumOS will define a minimum qualified host resource envelope.

Actual values belong to `PREREQUISITES.md`, MA-17 host qualification, and MA-20 release qualification.

They are not hardcoded into MA-11.

## 39. Failure behavior

### LOCKED

Resource-governance failure must fail safely.

Examples:

- cannot measure critical host resource → conservative admission/refusal;
- cannot enforce required hard limit → backend not qualified for that workload;
- reservation inconsistent → reconcile before new admission;
- Resource Governor unavailable → no new untrusted high-cost work.

The system must not default to unlimited execution.

## 40. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| authority/capabilities | MA-06 |
| model qualification/fallback | MA-07 |
| tool/network permission | MA-08 |
| storage architecture | MA-09 |
| checkpoint/retry/cancellation | MA-12 |
| recovery cleanup | MA-13 |
| accounting retention | MA-14 |
| autonomous tuning proposals | MA-15 |
| resource UX | MA-16 |
| host enforcement APIs/limits | MA-17 |
| prerequisites/installation | MA-18 |
| backend supply chain | MA-19 |
| thresholds/stress qualification | MA-20 |

These deferrals do not block MA-11 closure.

## 41. Veto conditions

An MA-11 implementation is invalid if it:

- lets an Agent increase its own authoritative resource ceiling;
- treats resource allocation as permission;
- treats AuthZ permission as guaranteed capacity;
- weakens isolation/security under pressure;
- makes different Agents share one hard hostile boundary because capacity is scarce;
- automatically cloud-bursts;
- silently falls back to an unqualified model;
- lets untrusted workload starve trusted kill/recovery capacity;
- silently deletes authoritative/protected data to continue new work;
- permits priority to bypass AuthZ;
- assumes unlimited RAM/swap/disk/GPU;
- has no bounded concurrency/resource policy;
- lets stale/dead runtimes retain reservations indefinitely;
- fails open when required resource enforcement is unavailable.

## 42. MA-11 closure decision

### CLOSED

MA-11 is architecture-complete.

Locked:

- trusted Resource Governor;
- resource governance separate from AuthZ/Capabilities;
- hierarchical host→Company→Agent→Task budgeting;
- hard ceilings vs reservations;
- trusted host safety reserve;
- admission before expensive execution;
- explicit priority/fairness;
- controlled preemption/degradation;
- externally enforced Agent Appliance envelopes;
- GPU/VRAM controlled by inference/runtime governance;
- bounded concurrency/network/storage/tool/browser resources;
- explicit disk-pressure protection;
- trusted accounting;
- finite reclaimable leases;
- no Agent self-expansion;
- no automatic cloud bursting;
- fail-safe resource-governance behavior.

No material MA-11 architecture question remains inside this domain.

## 43. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-111 — Trusted Resource Governor owns allocation
Resource admission, reservation, enforcement coordination, pressure response, and reclamation are trusted control functions outside Agent authority.

### D-112 — Resource budgets are hierarchical
Capacity is governed through Host Safety Envelope → Company → Agent → Task/Execution ceilings and reservations.

### D-113 — Trusted host safety reserve is mandatory
Control Plane, database, audit, Owner control, kill, and recovery capacity are protected before maximizing untrusted throughput.

### D-114 — Expensive work requires resource admission
Agent Appliances, model loads, Agent/Task execution, browsers/tools, and large artifact operations are admitted against current local capacity.

### D-115 — Resource lease is not authorization
A resource lease grants capacity only; MA-06 Capability/AuthZ determines authority.

### D-116 — Priority, fairness and preemption are explicit
Safety/recovery and Owner control outrank ordinary/background work; preemption affects execution, not Task authority.

### D-117 — GPU/VRAM remain inference-runtime resources
The Agent Appliance receives no direct GPU authority by default; model residency is governed through qualified inference/resource policy.

### D-118 — Resource pressure cannot weaken integrity
Scarcity may delay/refuse work but cannot weaken isolation, bypass security, use unqualified fallbacks, or silently delete protected authoritative state.

### D-119 — Resource accounting and reclamation are trusted
Usage/reservations are attributable and stale/dead execution cannot hold capacity indefinitely.

### D-120 — No self-expansion or automatic cloud bursting
Agents cannot raise their own authoritative resource ceilings, and local shortages never silently move final SerapeumOS work to cloud infrastructure.

## 44. Project-state transition

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

Current architecture domain:
MA-12 — Reliability / Checkpoint / Idempotency / Cancellation / Crash Recovery

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-12-CLOSE — architecture only
```

## 45. Next action

**MA-12-CLOSE — Reliability / Checkpoint / Idempotency / Cancellation / Crash Recovery**

Architecture only.
