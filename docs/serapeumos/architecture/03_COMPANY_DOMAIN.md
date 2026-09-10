# MA-03 — Company Domain & Organizational Identity

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-03 defines the SerapeumOS Company as the authoritative organizational aggregate.

It defines:

- Company identity;
- Company Owner;
- Company membership;
- organizational structure;
- Company-scoped identity;
- organizational lifecycle;
- boundaries between Company structure and Principal/AuthZ/Agent execution.

MA-03 does not define detailed Agent roles, missions, tasks, delegation, workflow state, or permissions. Those belong to MA-04 and MA-06.

---

## 2. Foundation identity model

### REPOSITORY FACT

Ankole already provides durable `Principal` identity for:

- human;
- agent;
- system.

An Agent is a Principal subtype and already contains:

- stable Principal UID;
- role text;
- human `owner_principal_uid`;
- creator Principal;
- status.

### LOCKED

SerapeumOS reuses Ankole Principal identity.

SerapeumOS does **not** create a second human identity system or a second Agent identity system.

---

## 3. Company is a separate domain concept

### LOCKED

A Company is not:

- a Principal;
- a Worker;
- an Agent;
- an installation;
- a model;
- a database;
- a host OS account.

A Company is a SerapeumOS-owned durable organizational aggregate.

Conceptually:

```text
Installation
   │
   └── Company
        ├── Company Owner → Human Principal
        ├── Organizational Units
        ├── Company Members → Principals
        ├── Company Roles / Assignments → MA-04
        ├── Goals / Missions → MA-04
        └── Company-owned durable state
```

---

## 4. Company identity

### LOCKED

Every Company has one immutable internal Company identity.

Company identity must:

- be stable across rename;
- be stable across host restart;
- be independent from filesystem path;
- be independent from Owner email/name;
- be independent from model/runtime;
- never be reused for a different Company.

Human-readable Company name/profile is mutable.

The exact identifier encoding belongs to implementation design.

---

## 5. Installation is not Company identity

### LOCKED

The architecture does not equate:

```text
SerapeumOS installation == Company
```

An initial product version may expose only one active Company per installation, but Company identity remains explicit in the domain model.

This prevents future multi-Company support from requiring a core data-model redesign.

### LOCKED

Company-scoped authoritative entities must carry or resolve unambiguously to Company scope.

No Company-owned fact may depend on an implicit "current global Company" assumption in durable storage.

---

## 6. Company Owner

### LOCKED

Every active Company has exactly one **Company Owner**.

The Company Owner must be an active human Principal.

The Company Owner is the highest product-level human authority inside that Company.

### LOCKED

Company Owner authority is not represented by an AI role.

An Agent cannot become Company Owner.

A model cannot become Company Owner.

A system Principal cannot become Company Owner.

### LOCKED

Owner transfer is a high-impact governed operation.

It requires explicit human authorization and must preserve:

- Company identity;
- Agent identities;
- organizational history;
- audit/provenance;
- authoritative state.

Exact transfer mechanics belong to MA-06/MA-09/MA-14.

---

## 7. Alignment with inherited Agent ownership

### LOCKED

For SerapeumOS Company Agents, the inherited Ankole `owner_principal_uid` must align with the active Company Owner.

This preserves the existing Principal/Agent ownership boundary instead of creating competing ownership semantics.

### LOCKED

A Company Owner transfer must update or migrate affected Agent ownership consistently under trusted control.

An Agent cannot independently change its Owner.

---

## 8. Company membership

### LOCKED

Company membership is separate from Principal identity.

A Principal can exist without being a member of a Company.

Membership answers:

> Is this Principal part of this Company?

It does not answer:

> What may this Principal do?

Permission remains AuthZ/MA-06.

### LOCKED

Company members can include:

- human Principals;
- Agent Principals.

System Principals remain installation/service identities unless explicitly given a narrowly defined Company scope.

---

## 9. Agent-to-Company ownership

### LOCKED

A SerapeumOS Agent Principal belongs to exactly one Company organizational identity.

An Agent is not silently shared between Companies.

Its:

- memory;
- workspace;
- history;
- missions;
- organizational relationships

remain bound to that Company context.

### LOCKED

Directly "moving" an Agent identity to another Company is not a normal operation.

If future product requirements need migration or cloning, it must be a governed export/import or identity-transition design that preserves provenance and prevents memory/authority leakage.

Human Principals may participate in more than one Company if a future product mode allows it, but each membership remains explicit.

---

## 10. Organizational units

### LOCKED

A Company may contain durable Organizational Units.

Examples include:

- division;
- department;
- team;
- project group;
- functional group.

These names are presentation/business semantics, not separate security primitives.

### LOCKED

Organizational Units form a Company-scoped acyclic hierarchy beneath the Company root.

Each Unit has:

- stable identity;
- mutable name/profile;
- Company scope;
- lifecycle state;
- optional parent Unit.

A Unit cannot belong to two Companies.

A Unit hierarchy cannot contain cycles.

---

## 11. Organizational roles are not Principal types

### LOCKED

The canonical SerapeumOS organization doctrine is:

```text
COMPANY OWNER
    ↓
AI SUPERVISOR
    ↓
AI MANAGERS
    ↓
AI SPECIALISTS
    ↓
AI REVIEWERS
```

These are organizational role classes.

They are **not** new Principal types.

Ankole remains:

```text
human | agent | system
```

Detailed role definitions, cardinality, delegation, reviewer independence, missions, and task responsibility belong to MA-04.

---

## 12. Organizational hierarchy is not authorization

### LOCKED

Reporting structure does not automatically grant technical permission.

For example:

```text
Manager → Specialist
```

does not mean the Manager receives unrestricted access to everything owned by the Specialist.

Organizational hierarchy governs:

- responsibility;
- supervision;
- delegation;
- escalation;
- work routing.

AuthZ governs permission.

Action Assurance governs high-impact action lifecycle.

This separation is mandatory.

---

## 13. Company organizational truth

### LOCKED

The Company Domain is authoritative for:

- Company identity;
- Company profile/purpose;
- Company Owner;
- Company membership;
- Organizational Units;
- organizational placement/structure;
- Company lifecycle;
- references to Company-level goals/objectives.

MA-04 owns the detailed role, mission, task, delegation, and workflow execution model.

### LOCKED

Company structure is durable Organizational Truth.

It must not be inferred from:

- prompts;
- conversation context;
- Worker processes;
- model output;
- folder layout;
- current task routing.

---

## 14. Principal identity vs organizational identity

### LOCKED

Principal identity and organizational placement are independent.

A person or Agent keeps the same Principal identity when:

- display name changes;
- role changes;
- team changes;
- Manager changes;
- mission changes;
- model changes;
- runtime changes.

This is a core invariant.

---

## 15. Agent ≠ role ≠ model

### LOCKED

```text
Agent Principal
≠ Organizational Role
≠ Model
≠ Worker
≠ Appliance
```

An Agent may change role without changing identity.

An Agent may change model without changing identity.

An Agent may move between Units inside its Company without changing identity.

A Worker/appliance may be replaced without changing Agent identity.

---

## 16. Company lifecycle

### LOCKED

The conceptual Company lifecycle supports:

```text
CREATED
→ ACTIVE
→ SUSPENDED
→ ACTIVE

ACTIVE / SUSPENDED
→ ARCHIVED
```

Exact status names may differ in implementation, but these semantics are required.

### LOCKED

- **CREATED** — identity exists but Company is not yet operational.
- **ACTIVE** — normal Company operation permitted.
- **SUSPENDED** — new autonomous execution is blocked while durable state remains intact.
- **ARCHIVED** — Company is no longer operational but historical state remains preserved.

### LOCKED

Ordinary Company deletion must not erase audit/history by default.

Permanent erasure, if supported, is a separate explicit data-destruction workflow governed by MA-09/MA-13/MA-14.

---

## 17. Member and Unit lifecycle

### LOCKED

Removing a Principal from a Company or archiving a Unit does not rewrite historical events.

Historical records continue to reference the original stable identities.

Identity values are not reused.

Detailed Agent enable/disable/retirement semantics belong to MA-04.

---

## 18. Company bootstrap

### LOCKED

A new Company becomes operational only after, at minimum:

1. Company identity exists;
2. active human Company Owner exists;
3. Company ownership binding is valid;
4. required Company governance state exists;
5. organizational state passes validation.

Agent creation and role assignment may follow according to MA-04.

### LOCKED

The system must not silently create autonomous AI authority merely because a Company record exists.

---

## 19. Company-level goals

### LOCKED

A Company may own durable top-level goals/objectives as Organizational Truth.

Those goals express what the Company is trying to achieve.

MA-04 defines how goals become:

- missions;
- assignments;
- tasks;
- workflows;
- Agent responsibilities.

A task result cannot silently rewrite the Company goal that authorized it.

---

## 20. Cross-Company isolation

### LOCKED

All Company-owned state is explicitly Company-scoped.

A Principal's membership in one Company does not imply access to another Company.

Agent memory, workspaces, tasks, organizational relationships, and Company-owned evidence cannot cross Company scope without an explicit governed operation.

### LOCKED

If multiple Companies are supported on one host, shared infrastructure may be reused, but authoritative Company state and Agent identity scope remain isolated.

---

## 21. System Principals

### LOCKED

System Principals represent trusted installation/service identities, not employees.

They do not appear in the organizational hierarchy by default.

They may act only under their technical service authority.

A system service cannot gain Company Owner authority through organizational placement.

---

## 22. External identities

### LOCKED

External identity bindings remain mappings to human Principals.

Company identity is local SerapeumOS identity and is not derived from:

- email provider;
- chat platform;
- external directory;
- OAuth subject;
- cloud tenant.

Loss or change of an external identity must not change Company identity.

---

## 23. Canonical references

### LOCKED

Company-domain relationships reference stable identities, not mutable display strings.

Use conceptual references equivalent to:

```text
company_uid
principal_uid
unit_uid
```

not:

```text
company_name
person_email
agent_display_name
team_name
```

as durable identity keys.

Exact schema is MA-09 implementation design.

---

## 24. Mutation authority

### LOCKED

Company organizational state is mutated only through trusted Company-domain services.

Agents may propose organizational changes.

They may not directly:

- change Company Owner;
- create hidden members;
- rehome Agents;
- rewrite Company history;
- assign themselves roles;
- change Company lifecycle;
- bypass governance.

AuthZ and Action Assurance apply according to MA-06.

---

## 25. Company Domain boundaries

### LOCKED

MA-03 does not absorb unrelated concerns.

| Concern | Owning domain |
|---|---|
| Principal authentication | Ankole foundation / MA-10 |
| Agent roles and missions | MA-04 |
| memory/evidence semantics | MA-05 |
| permissions/capabilities | MA-06 |
| model assignment | MA-07 |
| tools/skills | MA-08 |
| physical schema/storage | MA-09 |
| runtime resource limits | MA-11 |
| audit history | MA-14 |
| Company UX | MA-16 |

---

## 26. Veto conditions

A Company-domain implementation is invalid if it:

- creates a second Principal identity system;
- uses model identity as Agent identity;
- uses role strings as the sole durable Agent identity;
- makes Company name/email/path the immutable identity;
- conflates installation and Company in durable architecture;
- allows an Agent to belong to multiple Companies simultaneously;
- allows organizational hierarchy to bypass AuthZ;
- lets an Agent self-assign organizational authority;
- permits non-human Company Owner;
- silently rewrites history when structure changes;
- derives Company truth from Worker-local state or prompts.

---

## 27. MA-03 closure decision

### CLOSED

MA-03 is architecture-complete.

The following are locked:

- Company as explicit SerapeumOS aggregate;
- reuse of Ankole Principal identity;
- one human Company Owner;
- alignment of Company Owner with inherited Agent ownership;
- explicit Company membership;
- one Company identity per Agent;
- stable Organizational Units;
- organizational hierarchy separate from AuthZ;
- role classes separate from Principal types;
- Company lifecycle;
- Company-scoped durable Organizational Truth;
- explicit cross-Company isolation;
- stable identity references.

Detailed roles, missions, tasks, delegation, and Agent lifecycle now belong to MA-04.

---

## 28. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-038 — Company is an explicit SerapeumOS aggregate
Company identity is durable and distinct from installation, Principal, runtime, model, and host.

### D-039 — Reuse Ankole Principal identity
Humans, Agents, and system subjects continue to use Ankole Principal identity. SerapeumOS adds Company semantics above it rather than duplicating identity.

### D-040 — One human Company Owner
Every active Company has exactly one human Company Owner. AI/system principals cannot hold Company Owner authority.

### D-041 — Company Agents are single-Company identities
A SerapeumOS Agent belongs to exactly one Company organizational identity. Cross-Company rehoming is not a normal operation.

### D-042 — Organization does not imply authorization
Hierarchy, reporting, role, and placement govern organizational responsibility but do not bypass AuthZ or Action Assurance.

### D-043 — Installation and Company remain distinct
Even if the initial product exposes one Company per installation, durable architecture keeps explicit Company scope.

### D-044 — Organizational roles are not Principal types
Supervisor, Manager, Specialist, and Reviewer are Company role classes assigned to Agent Principals; they do not extend the Principal type system.

---

## 29. Project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED
MA-02 — CLOSED
MA-03 — CLOSED

Current architecture domain:
MA-04 — Agents / Roles / Missions / Tasks / Workflow State

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-04-CLOSE — architecture only
```

---

## 30. Next action

**MA-04-CLOSE — Agents / Roles / Missions / Tasks / Workflow State**

Architecture only.
