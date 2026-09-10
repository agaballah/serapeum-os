# MA-06 — AuthZ / Capabilities / Action Assurance

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-06 defines how SerapeumOS decides:

1. **whether a Principal is permitted to do something**;
2. **what exact authority an untrusted runtime may exercise**;
3. **how consequential actions are checked, approved, executed, verified, and recorded**.

These are separate layers:

```text
AuthZ
  ↓
Capability
  ↓
Action Assurance
  ↓
Trusted execution/broker
```

They must never collapse into one another.

---

## 2. Existing Ankole AuthZ foundation

### REPOSITORY FACT

Ankole already provides:

- durable Principals;
- static and computed Principal groups;
- Principal/group permission grants;
- grants defined by:
  - resource pattern;
  - action;
  - condition;
- current-state authorization snapshots;
- deterministic authorization evaluation in the native kernel;
- built-in administrator/root bootstrap semantics.

### LOCKED

SerapeumOS reuses the Ankole AuthZ engine as the baseline permission-decision substrate.

It does not create a parallel generic RBAC engine unless a proven gap requires extension.

---

## 3. Three distinct concepts

### LOCKED

### AuthZ

AuthZ answers:

> **May this Principal perform this class of action on this resource under the current context?**

It is durable permission policy.

### Capability

A Capability answers:

> **What exact bounded authority has been delegated to this runtime/task right now?**

It is temporary delegated authority, not durable entitlement.

### Action Assurance

Action Assurance answers:

> **Even if the action is permitted, is this exact proposed action safe, sufficiently approved, still valid, and correctly completed?**

It governs consequential action lifecycle.

---

## 4. Organizational role is not permission

### LOCKED

Organizational roles from MA-04 do not automatically grant technical access.

For example:

```text
AI Manager
```

does not inherently mean:

```text
can_write_any_file
can_modify_any_agent
can_publish_external_message
```

Role may inform policy/group membership, but AuthZ remains the permission authority.

---

## 5. AuthZ model

### LOCKED

Authorization is Principal-centric and resource/action based.

Conceptually:

```text
Principal
+ Company scope
+ Groups
+ Grants
+ Resource
+ Action
+ Current context
        ↓
ALLOW / DENY
```

### LOCKED

Default posture is **deny unless permitted**.

Absence of a grant is not permission.

Invalid or incomplete authorization state fails closed.

---

## 6. Company scope

### LOCKED

Every Company-owned authorization decision is Company-scoped.

A grant valid in Company A does not grant authority in Company B.

The AuthZ request must resolve unambiguously to:

- Principal;
- Company;
- resource;
- action;
- relevant context.

Cross-Company authority requires an explicit separately governed design.

---

## 7. Principal status

### LOCKED

A disabled, retired, suspended, or otherwise ineligible Principal cannot continue exercising ordinary granted authority merely because an old grant exists.

Principal state participates in authorization.

Runtime-held authority must be revocable when Principal eligibility changes.

---

## 8. Permission grants

### LOCKED

Permission grants remain durable policy.

They may be attached to:

- a Principal;
- a Principal group.

A grant defines:

- resource scope;
- allowed action;
- conditional constraints.

### LOCKED

Broad wildcard authority must be minimized and explicitly justified.

The system should prefer the narrowest stable grant model that supports the intended organizational responsibility.

---

## 9. Computed groups

### LOCKED

Computed groups may be used for dynamic permission grouping where membership is derived from current trusted state.

Computed membership is evaluated at authorization time.

A cached old membership must not remain authority after the underlying trusted state changes.

---

## 10. Capability model

### LOCKED

Untrusted Agent runtimes do not receive durable grants directly as ambient execution authority.

Instead, trusted services issue bounded **Capabilities** for concrete work.

A Capability must bind, at minimum:

- Principal identity;
- Company identity;
- resource;
- operation/action;
- scope;
- originating Task/Mission context where applicable;
- constraints;
- risk class;
- issuance time;
- expiry or bounded lifetime;
- revocation state;
- unique identity/non-replay material;
- approval binding where required.

Exact serialization/token technology is implementation design.

---

## 11. Capability is not a bearer superpower

### LOCKED

Possession of a capability representation is insufficient by itself.

Use of a Capability must also validate that:

- the Principal is still valid;
- Company/task assignment is still valid;
- the Capability is unexpired;
- it is not revoked;
- requested resource/action matches exactly;
- constraints still hold;
- required approval binding still applies;
- the action has not already been consumed where single-use semantics apply.

### LOCKED

Capabilities fail closed.

Malformed, stale, replayed, over-broad, or mismatched capabilities are denied.

---

## 12. Capability attenuation

### LOCKED

Delegation may only narrow authority.

A delegated capability may have:

- narrower resource;
- fewer actions;
- tighter constraints;
- shorter lifetime;
- lower resource budget;
- narrower Task scope.

It may never exceed the delegator's effective authority.

This enforces the MA-04 delegation rule.

---

## 13. Capability lifecycle

### LOCKED

Conceptual lifecycle:

```text
REQUESTED
→ AUTHORIZED
→ ISSUED
→ ACTIVE
→ CONSUMED / EXPIRED / REVOKED
```

Not every Capability must be single-use, but high-impact actions should prefer exact or single-use authority where practical.

Capability history must be auditable without exposing secrets.

---

## 14. Revocation

### LOCKED

Trusted control must be able to revoke authority independently of Agent cooperation.

Revocation may be triggered by:

- Principal disable/pause/retirement;
- Company suspension;
- Task cancellation/reassignment;
- permission change;
- policy change;
- Owner/global stop;
- runtime compromise;
- security event;
- Capability expiry.

A runtime must not continue a privileged action using authority known to be revoked.

Exact distributed revocation mechanics belong to implementation.

---

## 15. Risk classification

### LOCKED

Actions are classified by consequence, not by which Agent requested them.

The architecture uses these semantic classes:

| Class | Meaning |
|---|---|
| **ROUTINE** | low-impact, bounded, normally reversible/read-only |
| **CONTROLLED** | state-changing but bounded and recoverable |
| **HIGH-IMPACT** | external, destructive, security-sensitive, financially/materially consequential, or difficult to reverse |
| **PROHIBITED** | violates Constitution/security invariants or is not supported safely |

Exact thresholds and action catalogs are implementation/policy data.

### LOCKED

An Agent cannot lower the risk classification of its own proposed action.

---

## 16. Action Assurance

### LOCKED

Action Assurance is a SerapeumOS-owned differentiator.

It wraps consequential actions around AuthZ.

Canonical lifecycle:

```text
INTENT
  ↓
NORMALIZE EXACT ACTION
  ↓
RISK CLASSIFY
  ↓
AUTHZ
  ↓
VALIDATE PRECONDITIONS / TARGET STATE
  ↓
REQUIRED APPROVAL(S)
  ↓
ISSUE EXACT EXECUTION AUTHORITY
  ↓
EXECUTE THROUGH TRUSTED SERVICE/BROKER
  ↓
VERIFY RESULT / POSTCONDITIONS
  ↓
RECEIPT
  ↓
UNDO / RECOVERY PATH WHERE APPLICABLE
```

---

## 17. Authorization is not approval

### LOCKED

An AuthZ decision of `ALLOW` means the Principal is eligible to request/perform the action class.

It does **not** mean:

- the exact target is correct;
- the action is still safe;
- human approval is unnecessary;
- irreversible impact is acceptable;
- the action has actually succeeded.

Action Assurance owns those later checks.

---

## 18. Approval

### LOCKED

Approval is explicit consent for a particular governed action or bounded class of actions.

Approval must bind sufficiently to prevent “approve one thing, execute another.”

For high-impact actions, approval should bind to:

- action;
- resource/target;
- important parameters;
- Principal/requester;
- Company;
- relevant Task;
- risk/impact summary;
- validity window or state version where required.

### LOCKED

A formal Reviewer verdict from MA-04 is not Action Assurance approval.

Review evaluates work quality.

Approval authorizes a consequential action.

---

## 19. Human Owner authority

### LOCKED

The Company Owner is the highest product-level human authority within the Company.

However, Owner authority does not turn constitutional safety invariants into optional checks.

The Owner may approve high-impact actions where policy permits.

The Owner cannot authorize the system to silently bypass:

- TCB integrity;
- audit integrity;
- cross-Company isolation;
- capability validation;
- prohibited-action rules;
- other constitutional invariants.

---

## 20. Agent self-approval

### LOCKED

An Agent cannot satisfy an approval requirement for its own high-impact action merely because:

- it is the Supervisor;
- it is a Manager;
- it generated the action;
- it reviewed its own reasoning.

Where policy requires independent or human approval, that requirement must be satisfied by the required independent Principal.

---

## 21. Exact-action binding

### LOCKED

Consequential authority must bind to the normalized action, not a vague natural-language instruction.

Example:

```text
"update my file"
```

must become something equivalent to:

```text
operation: replace_file
resource: <stable target identity>
expected_version: <observed version>
new_artifact_hash: <hash>
```

before execution authority is granted.

Exact resource schemas belong to the owning MA domain.

---

## 22. Time-of-check / time-of-use

### LOCKED

For mutable targets, Action Assurance must revalidate relevant state immediately before execution when stale-state risk matters.

Examples include:

- file version;
- current permission;
- account state;
- active Task;
- target existence;
- current approval validity.

If the relevant target changed after approval/validation, the action must stop or re-enter assurance.

---

## 23. User-file publication

### LOCKED

Publishing from controlled SerapeumOS state to a user-owned resource is a governed action.

The MA-01 lifecycle is retained:

```text
observe current state
→ prepare change
→ AuthZ
→ Action Assurance
→ re-check current state
→ recovery preparation if required
→ publish
→ verify
→ receipt
```

An Agent does not directly write arbitrary host files.

---

## 24. External actions

### LOCKED

External side effects such as:

- sending messages;
- submitting forms;
- changing remote records;
- purchases/financial actions;
- external account changes;
- publishing content

must pass through Action Assurance according to risk class.

The tool/plugin mechanism belongs to MA-08.

MA-06 controls authority and assurance semantics.

---

## 25. Authoritative-state mutation

### LOCKED

Company-domain, Task, memory, policy, or other authoritative mutation occurs through trusted domain services.

Agents submit typed proposals/commands.

They do not receive direct database mutation authority.

AuthZ and Action Assurance requirements apply according to the action's risk.

---

## 26. Read actions

### LOCKED

Read-only does not automatically mean unrestricted.

Reads remain subject to:

- Company scope;
- Principal authorization;
- knowledge disclosure rules;
- secret/privacy boundaries.

Routine low-risk reads may not require full Action Assurance ceremony, but still require authorization.

---

## 27. Broker execution

### LOCKED

Privileged host/external actions execute through trusted brokers/services.

The broker receives validated trusted execution authority and exact action parameters.

The Agent does not receive:

- host administrator credentials;
- long-lived API secrets;
- database credentials;
- unrestricted shell authority

simply because the action was approved.

---

## 28. Receipts

### LOCKED

Consequential actions produce durable receipts sufficient to answer:

- who requested it;
- which Principal was accountable;
- which Company/Task;
- what exact action was authorized;
- what approval applied;
- what target/version was observed;
- what was executed;
- whether verification succeeded;
- what output/result occurred;
- whether recovery/undo information exists.

Audit storage details belong to MA-14.

---

## 29. Failure semantics

### LOCKED

If any required stage fails:

```text
AuthZ
Capability validation
risk classification
precondition check
approval
target re-check
execution
postcondition verification
receipt creation
```

the system must not silently report success.

Where execution occurred but verification/receipt failed, the state must be represented as uncertain/needs-reconciliation rather than guessed.

Detailed reconciliation belongs to MA-12/MA-14.

---

## 30. Prohibited actions

### LOCKED

Some actions are prohibited even with ordinary Owner approval if they violate constitutional architecture.

Examples include:

- silently disabling audit integrity;
- granting an Agent ambient host authority;
- bypassing Company isolation;
- making an Agent its own permission authority;
- exposing long-lived secrets without mediation;
- allowing untrusted runtime direct authoritative DB control.

Changing these rules requires an explicit constitutional/architecture change, not an Action Assurance approval.

---

## 31. Emergency / break-glass

### LOCKED

SerapeumOS may support a human break-glass path for recovery scenarios.

Break-glass:

- is human-only;
- is explicit;
- is time-bounded;
- is heavily audited;
- does not disable constitutional invariants;
- cannot become ordinary automation authority.

Exact mechanism belongs to MA-10/MA-13/MA-16.

---

## 32. Separation of policy layers

### LOCKED

```text
Company Organization
    ↓ informs
AuthZ policy

AuthZ
    ↓ permits
Capability issuance

Capability
    ↓ constrains
Runtime authority

Action Assurance
    ↓ governs
Exact consequential action

Broker/domain service
    ↓ executes
Mutation / external effect
```

No lower layer may redefine the authority of the layer above it.

---

## 33. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| Company/Agent roles | MA-03 / MA-04 |
| knowledge disclosure | MA-05 + MA-06 |
| model routing authority | MA-07 |
| tools/plugins/external actions | MA-08 |
| physical resource identifiers/storage | MA-09 |
| secret material/credentials | MA-10 |
| resource budgets | MA-11 |
| retries/reconciliation/idempotency | MA-12 |
| receipts/audit retention | MA-14 |
| approval/security UX | MA-16 |

These deferrals do not block MA-06 closure.

---

## 34. Veto conditions

An MA-06 implementation is invalid if it:

- treats organizational role as unrestricted permission;
- grants by default;
- gives Agents durable ambient host authority;
- allows a Capability to broaden its source authority;
- lets Agents mint/extend/reclassify their own capabilities;
- treats AuthZ `ALLOW` as automatic high-impact approval;
- lets approval cover materially different actions;
- allows high-impact Agent self-approval where independence is required;
- executes privileged actions outside trusted brokers/domain services;
- lets stale approvals/capabilities silently survive relevant target/policy changes;
- reports success when postcondition verification failed;
- allows ordinary approval to bypass constitutional safety invariants.

---

## 35. MA-06 closure decision

### CLOSED

MA-06 is architecture-complete.

Locked:

- Ankole AuthZ retained as baseline permission engine;
- default-deny Principal/resource/action/context authorization;
- Company-scoped permission;
- explicit bounded Capabilities;
- attenuation and revocation;
- semantic risk classes;
- Action Assurance lifecycle;
- authorization separate from approval;
- exact-action and target-state binding;
- trusted broker/domain-service execution;
- durable receipts;
- human Owner approval for governed high-impact actions;
- constitutional prohibited-action boundary.

No material MA-06 architecture question remains inside this domain.

---

## 36. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-063 — Ankole AuthZ remains the permission substrate
Principal/group grants over resource, action, and condition remain the baseline SerapeumOS authorization engine.

### D-064 — AuthZ, Capability, and Action Assurance are separate
AuthZ determines permission; Capabilities delegate bounded runtime authority; Action Assurance governs exact consequential action execution.

### D-065 — Default deny
Missing, invalid, stale, or ambiguous authority fails closed.

### D-066 — Capabilities are bounded and attenuating
Capabilities bind Principal, Company, resource, action, context, constraints, lifetime, risk, and approvals where required and cannot broaden delegated authority.

### D-067 — Authorization is not approval
An AuthZ allow decision does not itself satisfy high-impact action approval or correctness checks.

### D-068 — Action Assurance is the consequential-action lifecycle
Intent normalization, risk classification, authorization, precondition validation, approval, execution authority, trusted execution, postcondition verification, receipt, and recovery form the canonical assurance sequence.

### D-069 — Privileged effects execute through trusted brokers/services
Agents do not receive raw host, database, or long-lived credential authority merely because an action is approved.

### D-070 — Constitutional invariants cannot be bypassed by ordinary approval
Owner approval may authorize governed high-impact actions but cannot silently disable SerapeumOS constitutional security boundaries.

---

## 37. Project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED
MA-02 — CLOSED
MA-03 — CLOSED
MA-04 — CLOSED
MA-05 — CLOSED
MA-06 — CLOSED

Current architecture domain:
MA-07 — Models / Inference Runtime / Routing / Regression Control

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-07-CLOSE — architecture only
```

---

## 38. Next action

**MA-07-CLOSE — Models / Inference Runtime / Routing / Regression Control**

Architecture only.
