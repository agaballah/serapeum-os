# MA-02 — Host Runtime Topology & Process Boundaries

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-02 defines the logical runtime topology of SerapeumOS: which runtime owns each responsibility, which processes are trusted or untrusted, how they communicate, and who controls startup, readiness, assignment, shutdown, and failure.

It does not select a hypervisor, VM image builder, socket technology, database packaging, model server, or installer.

---

## 2. Canonical runtime topology

### LOCKED

```text
OWNER
  │
  ▼
OWNER UX / DESKTOP HOST
  │
  ▼
TRUSTED SERAPEUMOS CONTROL PLANE
  │
  ├── Authoritative State Services ───► DATABASE / DURABLE STORES
  │
  ├── AuthZ / Capabilities / Action Assurance
  │
  ├── Runtime Controller
  │        └── Host Isolation / Resource Brokers
  │
  ├── Inference Gateway ──────────────► RESTRICTED LOCAL MODEL RUNTIME(S)
  │
  └── Agent Runtime Channel
           │
           ▼
      HARD AGENT APPLIANCE
           │
           └── Ankole Agent Computer Worker
                 ├── Agent turns/jobs
                 ├── tools/skills
                 ├── browser
                 ├── generated code
                 └── inner sandbox
```

The architecture has one trusted control authority and multiple replaceable compute runtimes.

---

## 3. Runtime ownership

### LOCKED

| Runtime | Trust | Owns |
|---|---|---|
| Owner UX / Desktop Host | Trusted presentation boundary | Owner interaction, status, approvals, local lifecycle controls |
| SerapeumOS Control Plane | **TCB** | authoritative orchestration, identity, policy, AuthZ, Action Assurance, durable-state commands, Agent assignment, runtime admission |
| Database / Durable Stores | **TCB** | authoritative durable state under trusted services |
| Host Runtime Controller / Brokers | **TCB** | create/start/stop/kill runtimes, resource and host-access mediation |
| Agent Appliance | Untrusted hostile-compute zone | one Agent principal's live execution at a time |
| Agent Computer Worker | Untrusted | turns, jobs, tools, browser, Worker-local state |
| Model Runtime | Restricted, non-authoritative | inference only |
| External research/tool endpoints | External/untrusted | data or bounded actions only through governed interfaces |

No runtime may acquire authority merely because it is local.

---

## 4. Control-plane rule

### LOCKED

The Control Plane is the authoritative runtime coordinator.

It decides:

- which Agent may execute;
- which appliance is assigned;
- whether a Worker is admitted;
- whether a turn/job may start;
- capability and policy context;
- when runtime state is stale;
- when execution must drain, stop, or be replaced.

Worker self-reported readiness, health, capacity, or completion is evidence, not authority.

The Control Plane validates it against durable state and current assignment.

---

## 5. Inherited Ankole runtime contract

### LOCKED

SerapeumOS preserves the useful Ankole split:

- Control Plane owns PostgreSQL state, actor/delivery fences, final commit authority, runtime credentials, recovery facts, and scheduling/orchestration.
- Agent Computer owns live execution and rebuildable Worker-local state.
- RuntimeFabric remains the logical Control Plane ↔ Worker protocol boundary.
- Worker readiness is sent only after local readiness checks.
- Worker heartbeat/capacity are replaceable liveness projections.
- Control-plane durable rows remain authoritative across process restart.

SerapeumOS extends this model; it does not create a second Agent execution control plane.

---

## 6. Agent Appliance assignment

### LOCKED

One hard Agent Appliance is assigned to **one Agent principal at a time**.

The inherited Agent Computer process may remain technically pool-scoped. SerapeumOS does **not** require Agent identity to become a static Worker environment variable.

Instead, the trusted Runtime Controller maintains an outer assignment:

```text
Appliance Instance
  ↔ Worker Incarnation
  ↔ Assigned Agent Principal
```

The Control Plane may dispatch only work belonging to that assigned Agent.

Different Agent principals cannot concurrently execute in the same hard appliance.

Reassignment requires the MA-01 stop/detach/sanitize/recreate sequence.

---

## 7. Worker incarnation and fencing

### LOCKED

A Worker process is disposable and identified by a runtime incarnation distinct from persistent Agent identity.

A replacement Worker does not inherit authority merely because it uses the same Worker name or appliance slot.

The runtime contract must fence stale/replaced Workers using current incarnation/route/lease evidence.

Old Worker messages must not revive or commit work after replacement.

Detailed persistence/retry fencing belongs to MA-12.

---

## 8. Readiness model

### LOCKED

There are separate readiness levels:

```text
HOST READY
→ CONTROL PLANE READY
→ REQUIRED DURABLE SERVICES READY
→ RUNTIME CONTROLLER READY
→ APPLIANCE READY
→ WORKER READY
→ AGENT ASSIGNMENT ADMITTED
→ EXECUTION READY
```

No later state may be inferred from an earlier one.

A process existing does not mean it is ready.

A Worker may enter the execution pool only after:

- its runtime contract validates;
- required filesystem/runtime dependencies validate;
- current incarnation authenticates;
- the Control Plane admits it;
- its Agent assignment is valid.

Failure is fail-closed.

---

## 9. Startup order

### LOCKED

Normal SerapeumOS startup follows dependency order:

1. trusted host shell/lifecycle supervisor;
2. authoritative durable stores;
3. trusted Control Plane and policy/security services;
4. runtime controller and host brokers;
5. inference runtime as required;
6. Agent Appliances on demand;
7. Agent Computer Worker;
8. Worker admission;
9. Owner-facing system reports fully operational.

Agent execution must not begin before trusted state, security, and runtime admission are ready.

The exact process manager/service mechanism is host-specific and belongs to MA-17/MA-18.

---

## 10. Shutdown order

### LOCKED

Normal shutdown reverses authority safely:

1. stop accepting new Agent work;
2. revoke/drain active dispatch;
3. allow bounded Worker drain where safe;
4. persist authoritative completion/recovery state;
5. stop/kill Agent Appliances;
6. stop model runtimes;
7. stop trusted service processes after durable state is safe;
8. release host resources.

Emergency shutdown may skip cooperative drain and force-kill untrusted runtimes.

The trusted system must remain able to reconstruct unfinished work from durable state.

---

## 11. Communication boundaries

### LOCKED

Only explicit logical channels exist.

| Channel | Purpose |
|---|---|
| Owner UX ↔ Control Plane | commands, approvals, status |
| Control Plane ↔ Durable Store | authoritative transactions |
| Control Plane ↔ Runtime Controller | lifecycle/resource commands |
| Control Plane ↔ Agent Worker | RuntimeFabric logical messages/files/RPC |
| Control Plane / Inference Gateway ↔ Model Runtime | inference |
| Trusted brokers ↔ host resources | governed host access |
| Governed egress ↔ external endpoints | explicitly permitted research/actions |

### LOCKED

No undocumented side channel may become required architecture.

Transport technology is replaceable. RuntimeFabric semantics are retained, but its physical transport may change by host/backend without changing domain behavior.

---

## 12. RuntimeFabric role

### LOCKED

RuntimeFabric is the logical Worker boundary for:

- Worker ready;
- heartbeat/capacity;
- turn start/control;
- mailbox updates;
- RPC;
- bounded file transfer;
- shutdown/drain signals;
- completion/failure messages.

It is **not**:

- authoritative database state;
- Agent identity authority;
- AuthZ authority;
- Action Assurance;
- host-resource authority.

Physical transport is intentionally deferred.

---

## 13. Model runtime topology

### LOCKED

Model runtime is separate from Agent identity and authoritative state.

Agent/model requests pass through the governed inference boundary. An Agent does not gain direct provider/runtime administration authority.

Model runtime may be shared across Agents if MA-07 proves isolation and routing safety because the model is not the hard Agent security boundary.

GPU allocation and model lifecycle belong to MA-07/MA-11.

---

## 14. Browser and tool execution

### LOCKED

Browser, generated code, shell/tool execution, and similar hostile workloads remain inside the assigned Agent execution boundary unless a later MA domain explicitly defines a trusted broker.

A browser must not become a trusted host-side process merely for convenience.

External access is separately governed by MA-08.

---

## 15. Host brokers

### LOCKED

Host access requiring greater authority than the Agent Appliance is implemented through narrow trusted brokers.

Brokers:

- expose typed operations, not general shell access;
- validate caller identity/capability;
- enforce exact scope;
- produce auditable results;
- do not expose host credentials to the Worker.

Broker APIs are defined by their owning domain. MA-02 locks only their placement outside hostile Agent execution.

---

## 16. Failure domains

### LOCKED

Failures are contained by runtime domain.

```text
Agent turn failure
    ↓ must not crash
Worker/appliance peers or trusted core

Worker failure
    ↓ must not corrupt
authoritative Company state

Appliance compromise/failure
    ↓ must not broaden
host authority

Model runtime failure
    ↓ must degrade/refuse
without becoming Agent identity/state failure

UX failure
    ↓ must not terminate
authoritative background state incorrectly

Control Plane failure
    ↓ recovery from durable state
without trusting Worker-local state as authority
```

Detailed retry/checkpoint behavior belongs to MA-12.

---

## 17. Scale and concurrency

### LOCKED

SerapeumOS architecture supports:

- multiple persistent Agents;
- multiple hard Agent Appliances;
- concurrent Agents when host resources permit;
- multiple same-Agent turns/jobs only within policy/resource constraints;
- local model runtimes shared or dedicated according to MA-07.

### LOCKED

Concurrency never changes authority boundaries.

If resources are insufficient, work waits, queues, or is refused. It does not spill into an unauthorized boundary.

---

## 18. Local-only topology

### LOCKED

Normal final-system operation must not require a remote control plane, hosted queue, hosted database, cloud worker, or cloud memory service.

All authoritative runtime coordination remains local.

Temporary NaraRouter development inference does not alter this topology.

---

## 19. Platform neutrality

### LOCKED

The logical topology is invariant across supported hosts:

```text
Trusted Control Plane
+ Host Runtime Controller/Brokers
+ Durable Stores
+ Restricted Model Runtime
+ Per-Agent Hard Appliance
```

Windows/Linux implementations may use different host-native lifecycle, IPC, storage, and virtualization mechanisms.

Those differences must remain below the logical runtime contracts.

---

## 20. Explicitly deferred decisions

The following do **not** block MA-02 closure:

| Decision | Owner |
|---|---|
| Company/department/role semantics | MA-03 |
| Agent/task lifecycle semantics | MA-04 |
| durable memory/provenance structures | MA-05 |
| capability schemas | MA-06 |
| model server/provider/routing | MA-07 |
| egress/browser/tool policy | MA-08 |
| database/artifact/file layout | MA-09 |
| secrets implementation | MA-10 |
| resource quotas | MA-11 |
| retry/checkpoint/crash semantics | MA-12 |
| host IPC / VM transport choice | MA-17 |
| process packaging/service installation | MA-18 |
| runtime artifact provenance | MA-19 |
| executable qualification | MA-20 |

---

## 21. Veto conditions

A runtime topology is invalid if it requires:

- a second independent Agent control plane;
- authoritative Company state inside the Worker;
- direct Worker database ownership;
- different Agent principals sharing one hard hostile-code boundary concurrently;
- Agent-controlled runtime admission;
- Agent-controlled host lifecycle;
- direct Agent administration of model infrastructure;
- cloud runtime coordination as a mandatory final dependency;
- inability to fence stale Worker incarnations;
- execution before security/durable services are ready;
- physical transport semantics leaking into Company/Agent architecture.

---

## 22. MA-02 closure decision

### CLOSED

The SerapeumOS runtime topology and process ownership model are architecture-complete.

The architecture locks:

- one trusted Control Plane;
- separate authoritative durable stores;
- trusted runtime controller/host brokers;
- restricted model runtime;
- one-Agent-at-a-time hard appliance assignment;
- inherited Agent Computer Worker for live execution;
- RuntimeFabric as the logical Worker boundary;
- controlled readiness/admission;
- replaceable Worker incarnations with fencing;
- ordered startup/shutdown;
- failure-domain separation;
- platform-neutral physical implementations.

No material MA-02 question remains inside this domain.

---

## 23. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-032 — Single trusted runtime control authority
SerapeumOS has one trusted Control Plane for runtime orchestration and authoritative execution decisions. Agent Computer remains execution, not control authority.

### D-033 — Runtime Controller owns hostile-compute lifecycle
Creation, assignment, admission, resource control, stop, kill, and replacement of Agent Appliances are controlled outside the Agent runtime.

### D-034 — Outer Agent assignment constrains inherited Worker pool
Ankole Worker may remain pool-scoped internally, but SerapeumOS admits work for only one Agent principal per hard appliance assignment at a time.

### D-035 — RuntimeFabric retained as logical Worker boundary
RuntimeFabric message/RPC/file semantics are reused. Its physical transport remains replaceable and is not product-domain architecture.

### D-036 — Readiness is explicit and layered
Process existence is not readiness. Agent execution starts only after durable services, security services, appliance, Worker, authentication, and assignment admission are valid.

### D-037 — Model runtime is separate non-authoritative compute
Model runtime may be shared or dedicated under MA-07, but it never becomes Agent identity, Company-state authority, or runtime orchestration authority.

---

## 24. Project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED
MA-02 — CLOSED

Current architecture domain:
MA-03 — Company Domain & Organizational Identity

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-03-CLOSE — architecture only
```

---

## 25. Next action

**MA-03-CLOSE — Company Domain & Organizational Identity**

Architecture only.
