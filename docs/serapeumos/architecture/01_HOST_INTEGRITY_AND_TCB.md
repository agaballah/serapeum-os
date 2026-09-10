# MA-01 — Host Integrity, Isolation & Trusted Computing Base

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-01 defines the security boundary between SerapeumOS trusted authority and untrusted Agent execution.

It answers:

> What must remain trusted, what may be compromised, what authority may cross the boundary, and what guarantees every supported host/runtime backend must enforce?

MA-01 deliberately does **not** select the final hypervisor, appliance builder, transport, storage format, installer, or qualification implementation. Those choices belong to later MA domains.

---

## 2. Governing safety principle

### LOCKED

> A model, Agent, task, Worker, prompt, generated program, browser workload, plugin, tool, or other untrusted execution component may fail or become compromised, but it must not silently gain authority over the host or durable Company state.

Failure must remain bounded, observable, recoverable, and unable to broaden authority.

---

## 3. Threat model

### LOCKED

The architecture assumes that any of the following can be wrong, malicious, compromised, or adversarial:

- LLM output;
- Agent reasoning;
- generated code;
- shell commands;
- browser content;
- downloaded files;
- Skills/plugins/MCP integrations;
- external research content;
- Worker-local processes;
- inner sandbox;
- guest-root inside the Agent execution appliance.

MA-01 therefore does **not** treat prompt policy, cooperative Agent behavior, or inner sandboxing as the primary security boundary.

### LOCKED

The architecture must remain safe even if the untrusted Agent execution environment is fully compromised up to guest-root level.

A vulnerability in the selected VMM/hypervisor remains an infrastructure risk and is handled through MA-17, MA-19, and MA-20 qualification and vulnerability management.

---

## 4. Trust domains

### LOCKED

SerapeumOS has the following security domains:

```text
OWNER / USER
    │
    ▼
TRUSTED SERAPEUMOS CONTROL PLANE
    │
    ├── Identity / Principal authority
    ├── AuthZ
    ├── Capability issuance
    ├── Action Assurance
    ├── Policy
    ├── Authoritative state services
    ├── Audit / receipts
    ├── Secret mediation
    ├── Host-resource brokers
    ├── Recovery / global stop
    │
    ├────────────── restricted model interface ──────────────► MODEL RUNTIME
    │
    └──────────── bounded Agent execution interface ────────► AGENT APPLIANCE
                                                                  │
                                                                  └── Agent Computer
                                                                      ├── model loop
                                                                      ├── tools
                                                                      ├── browser
                                                                      ├── generated code
                                                                      └── inner sandbox
```

The trusted control plane is the security authority.

The Agent Appliance is a hostile-compute zone.

The model runtime is a separate restricted compute zone and is not an authority domain.

---

## 5. Trusted Computing Base

### LOCKED

The SerapeumOS TCB contains only components that must hold authority for one or more of:

- Principal and Agent identity;
- authorization;
- capability issuance and revocation;
- policy enforcement;
- Action Assurance;
- authoritative organizational-state mutation;
- durable execution-state mutation;
- authoritative evidence/provenance mutation;
- secret mediation;
- host-resource access;
- user-file publication;
- immutable or append-governed audit/receipt creation;
- lifecycle control;
- recovery;
- global pause/kill.

### LOCKED

Models, Agent reasoning, generated programs, browser processes, plugins, downloaded content, and ordinary Worker processes are not part of the TCB.

### LOCKED

The TCB must be kept smaller than the total product runtime. Convenience is not sufficient reason to move a component into the TCB.

---

## 6. Authority model across the boundary

### LOCKED

An untrusted Agent never receives ambient authority.

All host or authoritative-system actions require an explicit bounded capability or a typed proposal mediated by the trusted control plane.

A capability must be bound to, at minimum:

- Principal;
- resource;
- operation;
- scope;
- mission/task context where applicable;
- risk class;
- constraints;
- issuance time;
- expiry where applicable;
- revocation state;
- approval binding where applicable.

Exact schema belongs to MA-06.

### LOCKED

An Agent cannot:

- mint its own capabilities;
- expand an issued capability;
- extend its expiry;
- change its risk class;
- approve its own governed action;
- bypass Action Assurance;
- mutate policy;
- mutate the audit authority;
- directly grant itself host-resource access.

---

## 7. Authoritative state boundary

### LOCKED

Untrusted Agent execution does not directly own authoritative Company state.

The required mutation path is:

```text
Agent proposal / typed request
        ↓
Trusted service
        ↓
AuthZ / capability validation
        ↓
Action Assurance where applicable
        ↓
domain validation
        ↓
transaction / authoritative mutation
        ↓
receipt / resulting state
```

### LOCKED

Agents do not receive raw authoritative database credentials.

The inherited Ankole Worker contract already supports this separation: the Worker owns live execution and rebuildable Worker-local state, while the control plane owns PostgreSQL state, final commit authority, runtime credentials, and recovery facts.

---

## 8. Agent identity and hard execution boundary

### LOCKED

Agent identity is organizational identity. It is independent from:

- model;
- process;
- Worker;
- container;
- VM;
- host;
- runtime restart.

### LOCKED

One hard Agent Appliance boundary is assigned to **one Agent principal at a time**.

Same-Agent sessions/jobs may share the assigned appliance and Agent workspace according to MA-04/MA-09 rules.

Different Agent principals must not concurrently share the same hostile-code outer boundary.

### LOCKED

The outer hard boundary, not the inner sandbox, is the security boundary between mutually hostile Agent principals.

The inherited Ankole bubblewrap layer remains useful defense in depth but is not accepted as the sole cross-Agent hard boundary.

---

## 9. Appliance lifecycle and reassignment

### LOCKED

A hard Agent Appliance is disposable compute.

Persistent Agent workspace is attached separately from disposable runtime state.

Conceptual lifecycle:

```text
ABSENT
→ PROVISIONING
→ BOOTING
→ READY
→ ASSIGNED
→ ACTIVE / IDLE
→ STOPPING
→ DESTROYED / SANITIZED
```

### LOCKED

`READY` must be fail-closed. A runtime that cannot prove required identity/configuration must not become available to an Agent.

### LOCKED

Reassignment from Agent A to Agent B requires:

1. stop A execution;
2. detach A persistent workspace;
3. destroy or sanitize disposable runtime state;
4. establish a clean appliance instance;
5. attach B workspace;
6. establish B assignment.

No cross-Agent residual runtime state may be relied upon as safe.

### LOCKED

A compromised appliance is replaced rather than repaired in place.

---

## 10. State classes inside the boundary

### LOCKED

MA-01 uses these security-oriented state classes:

| Class | Meaning | Security treatment |
|---|---|---|
| S0 | Immutable appliance/runtime artifacts | Verified, replaceable |
| S1 | Ephemeral runtime state | Disposable |
| S2 | Rebuildable Worker-local state | Disposable/reconstructable |
| S3 | Persistent Agent workspace | Durable but non-authoritative |
| S4 | Authoritative organizational/execution/epistemic state | Trusted control plane only |
| S5 | Host-user resources | Outside Agent authority; broker mediated |
| S6 | Recovery/audit state | Trusted, protected from Agent mutation |

The exact storage implementation belongs to MA-09 and MA-13.

---

## 11. `/agents` contract

### LOCKED

The inherited Ankole `/agents/<agent-key>` workspace remains the durable Agent workspace concept.

It may contain:

- SOUL/MISSION/DESIGN projections;
- user-files;
- installed skills;
- session workspaces;
- job workspaces.

### LOCKED

`/agents` is durable continuity state but is **not authoritative Company truth**.

Authoritative Company/Agent facts remain controlled by trusted domain services.

### LOCKED

The Agent runtime receives only the workspace assigned to its current Agent principal.

The host must not expose arbitrary host folders merely to implement `/agents`.

Exact persistent disk/filesystem format belongs to MA-09 and MA-17.

---

## 12. Host filesystem and user resources

### LOCKED

The hostile Agent runtime does not receive arbitrary host filesystem mounts.

Preferred resource-access order:

1. managed copy/import into controlled SerapeumOS storage;
2. read-only governed resource link where technically justified;
3. controlled live host resource only as an explicit exception.

### LOCKED

Publication back to user/host resources is a governed action, not ordinary Agent file access.

Required conceptual publication lifecycle:

```text
observe target version/state
→ prepare proposal
→ validate
→ AuthZ / Action Assurance
→ re-check target state
→ backup/recovery preparation where required
→ controlled publication
→ post-write validation
→ receipt
→ undo/recovery path where applicable
```

Exact publication service belongs to MA-06 and MA-09.

---

## 13. Host execution and device authority

### LOCKED

The Agent does not receive ambient host shell authority.

### LOCKED

No direct host process execution is exposed to the Agent except through explicitly governed brokers.

### LOCKED

No physical host device passthrough is granted by default.

This includes:

- GPU;
- USB devices;
- physical disks;
- host credential stores;
- clipboard bridges;
- arbitrary sockets.

Exceptions require explicit architecture and capability treatment in the owning MA domain.

---

## 14. Model runtime boundary

### LOCKED

Models are replaceable inference providers, not security principals and not Agent identities.

### LOCKED

Model runtime is separate from authoritative Company state.

The normal model interface is inference-only.

The model runtime does not receive:

- database authority;
- host-user filesystem authority;
- secret-store authority;
- governance authority;
- capability issuance authority.

Model provider/routing details belong to MA-07.

---

## 15. Network boundary

### LOCKED

Agent runtime networking is deny-by-default.

No Internet, LAN, host-service, or peer-Agent reachability exists merely because the runtime starts.

### LOCKED

Network access is explicit, scoped, revocable, observable, and tied to a permitted purpose.

### LOCKED

Direct inbound LAN exposure of:

- Agent runtime;
- model runtime;
- authoritative database;
- privileged broker services

is prohibited by default.

Exact network topology and transport belong to MA-02 and MA-08.

---

## 16. Secret boundary

### LOCKED

Long-lived secrets remain outside the untrusted Agent runtime.

### LOCKED

Where an Agent action requires a credential, a trusted broker supplies the narrowest practical credential form or performs the privileged action on the Agent's behalf.

### LOCKED

Runtime credentials must be:

- purpose-bound;
- short-lived where practical;
- revocable;
- excluded from ordinary child-process environments where practical;
- absent from prompts and durable Agent memory unless explicitly designed as a safe opaque reference.

Secret-store technology belongs to MA-10.

---

## 17. Resource governance

### LOCKED

Host resource budgets are authoritative outside the Agent runtime.

An Agent cannot increase its own:

- CPU;
- RAM;
- disk;
- GPU;
- network;
- process;
- concurrency

limits.

### LOCKED

Resource exhaustion must not expand authority or corrupt durable Company state.

Detailed budgets/admission/fairness belong to MA-11.

---

## 18. Global control and recovery

### LOCKED

The trusted host/control plane must retain independent ability to:

- pause an Agent;
- stop an Agent;
- terminate its runtime;
- revoke capabilities;
- disconnect network authority;
- detach workspace authority;
- prevent further authoritative commits.

This control must not depend on Agent cooperation.

### LOCKED

Crash/restart must not broaden authority.

If required security state cannot be reconstructed after a crash, the runtime remains unavailable.

Detailed recovery semantics belong to MA-12 and MA-13.

---

## 19. Multi-user / multi-company isolation principle

### LOCKED

User, Company, and Agent identities are separate scopes.

No runtime assignment or broker may infer access merely from being on the same host.

Any future multi-user or multi-company host mode must preserve Principal-scoped authority and storage isolation.

Exact tenancy/domain model belongs to MA-03, MA-04, and MA-09.

---

## 20. Platform-neutral security contract

### LOCKED

SerapeumOS core defines required security guarantees independently of host OS.

Each supported host implementation must map those guarantees to host-native mechanisms through bounded adapters/brokers.

Conceptually:

```text
SerapeumOS security contract
        ↓
Host isolation adapter
Host resource brokers
Host lifecycle adapter
        ↓
Qualified host implementation
```

### LOCKED

A backend is acceptable only if it can enforce the MA-01 contract. Feature popularity, convenience, or development availability is not sufficient.

---

## 21. Backend status

### REJECTED

**WSL2 as the production outer hostile-Agent hard boundary.**

It may still be used for development, tooling, or compatibility if later architecture permits.

### PROPOSED / QUALIFICATION CANDIDATES

Windows:

- QEMU/WHPX — primary candidate.
- Full Hyper-V — reference/conditional alternative.

Linux:

- Firecracker/KVM — candidate.
- Cloud Hypervisor/KVM — candidate.
- QEMU/KVM — compatibility/reference candidate.

Agent appliance construction:

- minimal immutable Linux appliance;
- LinuxKit is one qualification candidate.

### LOCKED

These product names are **not part of the SerapeumOS core architecture contract**.

The final selected backend may change without redesigning Company, Agent, state, AuthZ, Action Assurance, memory, or workflow architecture.

Final backend qualification belongs to MA-17/MA-18/MA-19/MA-20.

---

## 22. Explicitly deferred ownership

The following are not open MA-01 design gaps. They are intentionally owned elsewhere:

| Question | Owning domain |
|---|---|
| Exact process topology and control transport | MA-02 |
| Company/user/Agent tenancy semantics | MA-03 / MA-04 |
| Capability schema and Action Assurance details | MA-06 |
| Model-provider runtime architecture | MA-07 |
| Tool/browser/research egress | MA-08 |
| `/agents` disk/filesystem format and artifact publication | MA-09 |
| Secret-store implementation | MA-10 |
| Resource budget policy | MA-11 |
| Crash/checkpoint/retry details | MA-12 |
| Backup/restore/quarantine | MA-13 |
| Audit/telemetry/privacy implementation | MA-14 |
| Host backend/OS qualification | MA-17 |
| Installer/appliance/update packaging | MA-18 |
| VMM/image supply chain | MA-19 |
| Adversarial/backend/release qualification | MA-20 |

These deferrals do not prevent MA-01 architecture closure.

---

## 23. MA-01 mandatory host guarantees

Every supported production host/backend must be able to prove:

1. no ambient user-file authority;
2. no ambient host-application/process authority;
3. no ambient device authority;
4. no ambient credential authority;
5. no admin/root authority over the host by default;
6. no self-expansion of permission;
7. hostile-code/process-tree containment;
8. hard cross-Agent isolation;
9. deny-by-default network;
10. restricted model boundary;
11. secret mediation;
12. exact/revocable capability mediation;
13. no direct database authority from Agent runtime;
14. governed user-file publication;
15. independent host force-stop;
16. protected governance/policy/audit;
17. no ambient host shell;
18. browser/download containment;
19. user/Company/Agent scope isolation;
20. offline core operation;
21. fail-closed startup;
22. crash cannot broaden authority;
23. workspace detachment/sanitized reassignment;
24. resource limits outside Agent control;
25. replaceable compromised runtime;
26. evidence-producing lifecycle;
27. same security contract across supported platforms.

MA-20 owns the executable proof suite.

---

## 24. MA-01 veto conditions

A runtime/backend cannot qualify if it requires any of the following as a normal production condition:

- trusting prompts as the primary security boundary;
- unrestricted host process execution;
- arbitrary host-folder mounts;
- direct Agent database credentials;
- direct long-lived secret access;
- unrestricted Agent networking;
- shared hostile-code outer boundary between different Agents;
- Agent-controlled resource-limit expansion;
- inability for the trusted host to force-stop execution;
- fail-open startup;
- weakening host security merely to make the runtime operate;
- treating the model as identity or authorization authority;
- making durable Company state authoritative inside disposable Agent runtime.

---

## 25. MA-01 closure decision

### CLOSED

MA-01 is architecture-complete.

The security guarantees, trust boundaries, TCB ownership, Agent hard-boundary contract, host-resource rules, state classification, network/secret posture, lifecycle principles, and backend-neutral qualification requirements are locked.

No material MA-01 design question remains that must be answered inside MA-01.

Backend/tool choices remain intentionally deferred to their owning later architecture domains and may not override this contract.

---

## 26. Decisions to persist

When repository write access is available, append locked decisions equivalent to:

### D-025 — Platform-neutral host security contract
The SerapeumOS security guarantee is defined independently of host OS. Each supported platform must prove an implementation that enforces the same contract.

### D-026 — Hostile Agent runtime outside TCB
Agent reasoning, generated code, browser, tools, plugins and Worker-local execution are untrusted and cannot directly own authoritative Company state or host authority.

### D-027 — One Agent principal per hard appliance boundary
One hard Agent execution boundary is assigned to one Agent principal at a time. Different Agent principals do not concurrently share the same outer hostile-code boundary.

### D-028 — Durable Agent workspace is non-authoritative
`/agents` provides durable Agent continuity but is not authoritative Company truth.

### D-029 — Broker-mediated host authority
Host files, host execution, devices, secrets, networking and publication are broker/capability mediated and deny-by-default.

### D-030 — WSL2 rejected as production outer Agent boundary
WSL2 may be used for development/tooling but is not accepted as the production hard boundary between hostile Agent principals.

### D-031 — Backend implementation is replaceable
Hypervisor, appliance builder and host-specific isolation technology are replaceable implementations of the MA-01 contract, not SerapeumOS product architecture.

---

## 27. Required project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED

Current architecture domain:
MA-02 — Host Runtime Topology & Process Boundaries

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-02-CLOSE — architecture only
```

---

## 28. Next action

**MA-02-CLOSE — Host Runtime Topology & Process Boundaries**

Architecture only.

Do not build.
Do not prototype.
Do not install.
Do not select implementation tooling unless MA-02 requires a product-neutral contract decision.
