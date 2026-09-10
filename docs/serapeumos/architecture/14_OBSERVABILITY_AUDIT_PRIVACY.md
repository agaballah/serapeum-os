# MA-14 — Observability / Audit / Receipts / Privacy

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-14 defines how SerapeumOS makes system behavior observable and accountable without creating an uncontrolled surveillance or telemetry system.

It governs:

- operational observability;
- structured logs, metrics, and traces;
- durable audit history;
- action receipts and execution proof;
- event correlation;
- Owner visibility;
- privacy boundaries;
- sensitive-data minimization and redaction;
- retention and deletion architecture;
- export and diagnostic handling;
- audit integrity and recovery interaction.

MA-14 does not define product-screen layouts, detailed legal compliance for a specific jurisdiction, exact retention durations, or implementation libraries.

---

## 2. Four different information classes

### LOCKED

SerapeumOS must distinguish four information classes:

| Class | Purpose | Authority |
|---|---|---|
| **Operational Observability** | diagnose health, latency, failures, resource behavior | non-authoritative operational evidence |
| **Audit Record** | reconstruct accountable security/governance/state-changing events | durable authoritative history |
| **Action Receipt** | prove lifecycle/outcome of a governed or consequential action | durable authoritative evidence |
| **Diagnostic Content** | optional detailed payload/body/content capture for debugging | sensitive, minimized, non-authoritative |

These classes may share correlation identifiers but are not interchangeable.

---

## 3. Existing foundation facts

### REPOSITORY FACT

Inherited Ankole already includes:

- structured logging with stable event names and structured fields;
- optional OpenTelemetry tracing;
- turn/session/principal correlation attributes;
- Worker trace forwarding;
- content sanitization/redaction for known credential fields and inline data;
- size-based omission for oversized trace content;
- optional trace export that can be disabled.

### REPOSITORY FACT

Inherited runtime events are wakeup/deadline mechanisms; PostgreSQL rows remain durable source of truth.

### LOCKED

SerapeumOS reuses useful logging/tracing infrastructure where qualified, but neither application logs, runtime wakeups, nor OTLP traces become the authoritative audit ledger.

---

## 4. Core doctrine

### LOCKED

> Observability explains how the system behaved.  
> Audit establishes what accountable event occurred.  
> Receipts establish what governed action was requested, authorized, attempted, and verified.  
> None of them may silently become a second copy of all Company content.

---

## 5. Observability is not authority

### LOCKED

Logs, metrics, traces, spans, dashboards, runtime events, and monitoring caches are operational evidence.

They cannot:

- authorize an action;
- establish Company truth;
- override durable Task/Workflow state;
- override AuthZ;
- prove an action completed merely because a log line says so;
- become the only record of a high-impact action.

Loss of telemetry may reduce diagnosability but must not silently corrupt authoritative Company state.

---

## 6. Audit is durable Organizational/Security history

### LOCKED

Security- and governance-relevant actions produce durable audit records through the trusted Control Plane/domain path.

Audit records are authoritative for:

- who/what initiated a governed event;
- which Company/principal/object was affected;
- which trusted authority admitted/denied it;
- what state transition occurred;
- when the trusted system recorded it;
- what receipt/evidence links support it.

---

## 7. Receipt definition

### LOCKED

An **Action Receipt** is a durable record of a consequential action lifecycle.

A receipt may represent:

```text
REQUESTED
→ AUTHORIZED / DENIED
→ PREPARED
→ EXECUTION_STARTED
→ EXECUTION_REPORTED
→ VERIFIED / FAILED / UNKNOWN
```

Exact state names may differ by action type.

### LOCKED

A model assertion such as “done” is not a receipt.

A Worker log line is not a receipt.

A receipt is produced/accepted by the trusted action-governance path defined by MA-06.

---

## 8. Receipt minimum identity

### LOCKED

A consequential-action receipt must be able to bind, as applicable:

- receipt UID;
- Company UID;
- initiating Principal UID;
- responsible Agent UID;
- Task/Mission/Workflow reference;
- action/capability class;
- authorization/capability reference;
- Action Assurance decision/reference;
- target resource identity;
- request time;
- trusted admission time;
- execution attempt/incarnation identity;
- terminal outcome;
- verification status;
- evidence/artifact references;
- error/denial class;
- correlation/causation references.

Exact schema belongs to implementation.

---

## 9. Evidence by reference, not uncontrolled duplication

### LOCKED

Receipts and audit records should reference large/sensitive evidence through MA-09 Artifact/provenance identities rather than duplicate entire payloads into audit tables.

Example:

```text
receipt
→ output_artifact_uid
→ immutable Artifact + provenance
```

not:

```text
receipt
→ uncontrolled copy of full file/body/chat transcript
```

---

## 10. Stable correlation model

### LOCKED

SerapeumOS uses stable correlation identifiers across observability, audit, Tasks, Workers, actions, and receipts where applicable.

Conceptual identifiers include:

- Company UID;
- Principal/Agent UID;
- Task/Workflow UID;
- actor/event UID;
- action/receipt UID;
- Worker incarnation;
- appliance assignment;
- model request/generation correlation;
- Artifact UID;
- external-operation idempotency/reference key.

### LOCKED

Correlation does not mean all stores may see all fields.

Privacy filtering still applies per store.

---

## 11. Causation chain

### LOCKED

Where materially relevant, durable records preserve causation:

```text
Owner goal
→ Mission
→ Task
→ Agent attempt
→ capability request
→ authorization
→ Action Assurance decision
→ execution
→ external/internal result
→ verification
→ receipt
```

This enables reconstruction of “why did this happen?” rather than only “what timestamp exists?”

---

## 12. Actor attribution

### LOCKED

Audit attribution uses durable Principal/Agent identity, never merely:

- model name;
- Worker ID;
- process ID;
- username string;
- display name;
- prompt text.

Runtime incarnation/model/process may be recorded as execution context but not substituted for accountable Agent/Principal identity.

---

## 13. Trusted timestamping

### LOCKED

Authoritative audit/receipt time comes from the trusted Control Plane/storage path.

Agent- or Worker-supplied timestamps may be captured as evidence but are not the sole authoritative event time.

### LOCKED

Clock anomalies must be visible rather than silently reordered into false chronology.

Exact clock synchronization mechanism is implementation/host qualification.

---

## 14. Append-oriented audit history

### LOCKED

Material audit history is append-oriented.

Corrections do not silently rewrite history.

Conceptually:

```text
original event
→ correction/supersession event
```

rather than replacing the original record invisibly.

---

## 15. Audit integrity

### LOCKED

The audit system must detect unauthorized alteration or missing protected records to the degree required by the threat model.

Qualified implementation may use:

- immutable/append-only database rules;
- hash chaining;
- signed checkpoints;
- protected snapshots;
- write-once segments;
- equivalent mechanisms.

### LOCKED

The architectural requirement is **tamper evidence/protection**, not one specific cryptographic format.

---

## 16. Audit write authority

### LOCKED

Normal Agents cannot directly insert, rewrite, delete, or mark trusted audit records.

They may emit claims/evidence to the trusted Control Plane.

Only trusted services may commit authoritative audit/receipt state.

---

## 17. Fail-closed audit requirement

### LOCKED

For actions whose governance requires a durable audit/receipt record, the trusted system must not deliberately execute them if required audit persistence cannot be established.

Conceptually:

```text
cannot create required trusted audit anchor
→ deny/defer consequential action
```

### LOCKED

Low-impact ordinary operations may continue under a degraded observability condition if policy allows.

This distinction prevents a logging outage from unnecessarily killing all product behavior while preserving governance guarantees.

---

## 18. Receipt before/after relationship

### LOCKED

For governed consequential actions, trusted state must establish an action identity and authorization/audit anchor **before** external side-effect execution.

Terminal success is recorded only after outcome verification sufficient for that action class.

This supports MA-12 reconciliation after crashes.

---

## 19. Unknown outcome is first-class

### LOCKED

When SerapeumOS cannot determine whether an external side effect occurred, the receipt state must be `UNKNOWN`/equivalent.

It must not fabricate success or failure.

Unknown outcomes trigger MA-12 reconciliation and, where material, Owner attention.

---

## 20. Denials are auditable

### LOCKED

Material AuthZ/Action-Assurance denials are auditable.

The record should capture:

- actor;
- requested action class;
- affected target identity;
- denial policy/reason class;
- trusted decision time.

### LOCKED

Do not log the denied secret/plaintext request payload merely because a denial occurred.

---

## 21. Approval events are auditable

### LOCKED

High-impact Owner approvals/denials are durable governance events.

Audit must distinguish:

- who requested;
- who approved/denied;
- what exact action envelope was approved;
- approval scope;
- expiry/reuse constraints where applicable;
- resulting execution receipt.

Approval evidence must not be reduced to “user clicked yes.”

---

## 22. Administrative/security events

### LOCKED

The following categories require durable audit where applicable:

- Company Owner transfer;
- Company lifecycle changes;
- Principal/member/Agent creation, disabling, removal;
- organizational authority changes;
- AuthZ policy/capability changes;
- secret/credential lifecycle operations without secret plaintext;
- plugin/tool/skill trust changes;
- extension installation/update/removal;
- model/runtime policy changes where security/reliability relevant;
- backup/restore/quarantine/promotion operations;
- migration/update/rollback operations;
- audit/privacy policy changes;
- System Evolution proposal/approval/application;
- global pause/kill and recovery;
- consequential Agent actions.

---

## 23. Read-access auditing

### LOCKED

Not every ordinary read requires permanent high-volume audit.

However access to specially protected classes must be auditable according to policy.

Examples:

- secrets;
- quarantine;
- sensitive audit export;
- recovery material;
- high-sensitivity Company objects;
- protected external credential use.

Exact read-audit matrix belongs to MA-20/product policy.

---

## 24. Operational logging

### LOCKED

Operational logs use structured events.

Preferred event shape includes:

- stable event name;
- severity;
- trusted timestamp;
- subsystem;
- correlation IDs;
- bounded structured fields;
- error class/status;
- no unnecessary content.

Free-form human messages may exist but are not the primary machine contract.

---

## 25. Metrics

### LOCKED

Metrics are aggregate operational signals.

They should favor:

- counters;
- gauges;
- histograms;
- bounded dimensions.

### LOCKED

Metrics must not use high-cardinality personal/content fields such as:

- raw prompts;
- emails;
- file names where sensitive;
- full paths;
- message bodies;
- secret identifiers;
- arbitrary user text.

---

## 26. Tracing

### LOCKED

Tracing may connect:

- Owner/UI request;
- Control Plane operation;
- Task/Turn;
- Worker execution;
- model invocation;
- tool/action path;
- external operation.

Tracing is diagnostic, not authoritative audit.

### LOCKED

Tracing failure must not change normal product semantics unless a separate security/audit requirement itself failed.

---

## 27. Trace content minimization

### LOCKED

Trace payload capture must be minimized.

Default architecture favors metadata and identifiers over full prompt/output/tool bodies.

Where detailed content tracing is enabled for debugging:

- it is explicit;
- bounded;
- redacted;
- retention-limited;
- visible to the Owner/operator;
- never required for normal product correctness.

---

## 28. Existing Ankole trace redaction

### REPOSITORY FACT

Inherited trace sanitization already removes known credential fields such as access tokens, API keys, authorization fields, refresh tokens, secret keys, encrypted-content/function-argument fields, headers/metadata keys, and replaces inline data with omission markers.

### LOCKED

SerapeumOS retains or strengthens this behavior.

### LOCKED

A key-name redaction list is defense-in-depth, not sufficient privacy architecture by itself.

Sensitive data minimization must occur **before** telemetry emission whenever possible.

---

## 29. Secrets never belong in logs/traces

### LOCKED

The following must not be intentionally written into logs, traces, metrics, audit records, receipts, crash reports, or diagnostic bundles:

- passwords;
- API keys;
- bearer/session tokens;
- refresh tokens;
- private keys;
- recovery secrets;
- plaintext credential payloads;
- raw MA-10 secret values.

Where identity is necessary, use stable non-secret references.

---

## 30. Sensitive paths and host information

### LOCKED

Host paths, usernames, machine identifiers, IP addresses, device details, and file names may themselves reveal personal or confidential information.

Capture them only when operationally necessary and according to privacy policy.

Prefer normalized/logical resource identities over raw absolute paths.

---

## 31. Privacy principle

### LOCKED

> Collect the minimum information necessary for product function, accountability, security, and qualified diagnostics; keep each class only as long as its purpose requires; do not silently repurpose operational data into Company knowledge.

---

## 32. Privacy is not memory

### LOCKED

Logs, traces, audit records, and receipts do not automatically become Agent memory or Brain knowledge.

MA-05 governs knowledge admission.

An Agent may not learn private historical telemetry merely because the telemetry exists.

---

## 33. Privacy is scoped

### LOCKED

Observability/audit access follows Company and Principal scope.

A future multi-Company installation must prevent one Company's telemetry, audit history, receipts, or diagnostic data from leaking into another Company's views or Agent context.

Shared infrastructure metrics may be installation-scoped only when Company content/identity is not exposed improperly.

---

## 34. Owner visibility

### LOCKED

The Company Owner must have understandable access to material autonomous activity.

At minimum the product architecture must be able to answer:

- what happened;
- which Agent acted;
- under which Task/Mission;
- what authority permitted it;
- what resource was affected;
- whether it succeeded, failed, was denied, or is unknown;
- what evidence/receipt exists;
- whether human approval was involved.

Exact UX belongs to MA-16.

---

## 35. No hidden autonomy

### LOCKED

Consequential autonomous actions cannot intentionally bypass the audit/receipt path to remain invisible to the Owner.

A tool/plugin/runtime that cannot participate in the required accountability contract cannot be granted that action class.

---

## 36. Internal reasoning privacy

### LOCKED

SerapeumOS does not require storage of a model's hidden chain-of-thought/internal reasoning.

Accountability relies on:

- task/mission context;
- explicit decision/result summaries;
- policy decisions;
- action requests;
- tool calls;
- receipts;
- evidence;
- state transitions.

### LOCKED

Models may produce concise explicit rationale when required, but raw hidden reasoning is not an audit prerequisite.

---

## 37. Prompt/output retention

### LOCKED

Prompt and model-output retention must be purpose-specific.

Possible classifications:

- authoritative Company conversation/content;
- Task execution evidence;
- ephemeral Working Context;
- optional diagnostic trace content.

### LOCKED

The same text must not be retained indefinitely in all four stores by default.

MA-05/MA-09 determine when content becomes durable Company knowledge/evidence.

---

## 38. Local-first telemetry

### LOCKED

Final SerapeumOS operation requires no hosted telemetry, crash reporting, analytics, observability SaaS, or vendor monitoring service.

Operational observability must have a fully local path.

### LOCKED

No mandatory telemetry export to OpenAI, NaraRouter, Langfuse, LangSmith, an OTLP collector, or any other external provider is permitted.

---

## 39. External telemetry export

### LOCKED

Any future external observability export is:

- optional;
- explicitly configured by Owner/operator;
- disabled by default unless Owner policy changes;
- clearly identifies destination and data classes;
- replaceable;
- never a correctness dependency.

### LOCKED

Temporary NaraRouter inference allowance does not create permission to export SerapeumOS telemetry to NaraRouter or another cloud service.

---

## 40. Existing Ankole external observability

### REPOSITORY FACT

Inherited Ankole supports optional OTLP trace export and configuration for semantic providers including OpenTelemetry/Langfuse/LangSmith, with tracing disabled by configuration default.

### LOCKED

SerapeumOS may retain this infrastructure only as an optional adapter surface.

It cannot become mandatory product telemetry.

---

## 41. Diagnostic mode

### LOCKED

A higher-detail diagnostic mode may exist, but must be:

- explicit;
- time-bounded or clearly persistent by Owner choice;
- visibly indicated;
- privacy-scoped;
- easy to disable;
- unable to disable core secret-redaction rules.

Diagnostic mode does not authorize credential/plaintext-secret capture.

---

## 42. Crash diagnostics

### LOCKED

Crash reports and support bundles are local artifacts by default.

They should contain:

- product/build/version;
- component failure state;
- sanitized stack/error information;
- bounded operational context;
- relevant correlation IDs.

They should not automatically contain full Company content.

External sharing requires explicit Owner action.

---

## 43. Privacy classification

### LOCKED

Telemetry/audit fields must support conceptual sensitivity classification, for example:

- PUBLIC/TECHNICAL;
- COMPANY-CONFIDENTIAL;
- PERSONAL;
- SECRET/PROHIBITED-FROM-TELEMETRY.

Exact labels may differ.

### LOCKED

`SECRET/PROHIBITED-FROM-TELEMETRY` values are not merely hidden in UI; they must be excluded/redacted from telemetry persistence.

---

## 44. Retention classes

### LOCKED

Different data classes require independent retention policies.

Conceptually:

| Class | Typical policy direction |
|---|---|
| volatile metrics | short/rolling |
| operational logs | bounded/rolling |
| detailed traces | short/optional |
| diagnostic payloads | shortest/explicit |
| durable audit | longer/protected |
| action receipts | tied to accountable Company history |
| security/recovery events | protected according to policy |

Exact periods are product/qualification decisions, not MA-14 architecture.

---

## 45. Retention cannot be one global TTL

### LOCKED

A single “delete logs after N days” setting is insufficient because:

- audit;
- receipts;
- traces;
- metrics;
- support bundles;
- Company content

serve different purposes and have different authority.

---

## 46. Privacy deletion versus audit integrity

### LOCKED

Privacy erasure must not require falsifying accountable history.

Where deletion of personal/content data is required while audit continuity must remain, architecture may preserve a minimal non-sensitive audit skeleton such as:

- event class;
- pseudonymous/stable internal reference where permitted;
- timestamp;
- outcome;
- integrity linkage.

Sensitive payload may be:

- deleted;
- cryptographically erased;
- detached;
- redacted through a governed supersession record.

### LOCKED

Exact legal retention/erasure behavior is jurisdiction/product-policy work, not assumed by MA-14.

---

## 47. No silent audit rewrite for privacy

### LOCKED

Privacy deletion does not silently modify historical audit records in place while pretending no change occurred.

Any governed redaction/erasure that affects protected audit evidence must itself be auditable.

---

## 48. Backup interaction

### LOCKED

MA-13 backup retention and MA-14 privacy retention must be coordinated.

Deletion from active storage may not immediately remove copies from historical backups.

The system must document that behavior and provide a policy for eventual backup expiry/erasure consistent with recovery integrity.

---

## 49. Quarantine privacy

### LOCKED

Quarantined data may contain sensitive content.

Quarantine is not exempt from:

- access control;
- retention policy;
- encryption;
- audit;
- privacy handling.

Quarantine inspection is specially controlled and auditable.

---

## 50. Export of audit/diagnostics

### LOCKED

Exporting audit history or diagnostic bundles is a governed data-publication operation.

The export process must:

- define scope;
- apply access control;
- identify included data classes;
- apply redaction where configured;
- produce an Artifact/receipt when material;
- never silently upload externally.

---

## 51. Audit search/indexes

### LOCKED

Search/indexes over audit data are derived state.

They may be rebuilt and cannot become a less-protected duplicate of sensitive audit payload.

Access controls must apply through search results as well as direct record access.

---

## 52. Observability resource governance

### LOCKED

Telemetry cannot consume unbounded disk/RAM/CPU.

MA-11 budgets apply to:

- log volume;
- trace volume;
- metric cardinality;
- support bundles;
- audit indexing.

### LOCKED

When operational telemetry budgets are exceeded, the system may sample/drop lower-value telemetry according to policy.

Required audit/receipt events cannot be silently sampled away.

---

## 53. Sampling

### LOCKED

Sampling is permitted for non-authoritative observability.

Sampling is not permitted as a reason to omit mandatory governance/security audit or Action Assurance receipts.

---

## 54. Log/trace loss

### LOCKED

Loss of some diagnostic logs/traces may be tolerated and visibly reported as an observability degradation.

Loss/inability to persist mandatory audit/receipt data is a governance failure and may block affected consequential operations.

---

## 55. Alerting

### LOCKED

Alerts are derived notifications from trusted state/observability.

An alert is not itself authoritative truth.

Critical classes should include, as applicable:

- audit persistence failure;
- secret leakage detection;
- repeated AuthZ/Action Assurance denial patterns;
- Worker/appliance compromise signals;
- backup/restore failures;
- resource exhaustion threatening trusted services;
- audit-integrity failure;
- unexplained receipt `UNKNOWN` outcomes.

Exact thresholds belong to MA-20.

---

## 56. Security event separation

### LOCKED

Security-relevant events should be distinguishable from ordinary application diagnostics.

This supports:

- protected retention;
- higher-integrity storage;
- Owner/security views;
- release qualification.

One physical storage engine may hold multiple classes if logical protections remain clear.

---

## 57. Model observability

### LOCKED

Model observability may record metadata such as:

- model/runtime identity;
- request class;
- duration;
- token/resource usage where available;
- retry/fallback;
- failure class;
- routing decision;
- regression/evaluation reference.

### LOCKED

The model name is execution context, not Agent identity or authority.

---

## 58. Tool/action observability

### LOCKED

Tool invocations should expose enough metadata to diagnose:

- tool identity/version;
- calling Agent;
- Task/action correlation;
- start/end;
- outcome;
- resource class;
- governed capability/action reference where applicable.

Full arguments/results are not automatically telemetry.

Consequential results belong in receipts/evidence under MA-06/MA-09.

---

## 59. Host/runtime observability

### LOCKED

Trusted host/runtime telemetry may include:

- appliance/Worker lifecycle;
- current assignment identity;
- readiness;
- crash/restart;
- resource pressure;
- lease/staleness;
- broker failures;
- model-runtime health.

Agents cannot falsify trusted host-level telemetry simply by emitting similarly named log events.

Trusted-source identity must be preserved.

---

## 60. Source trust

### LOCKED

Every important telemetry/audit class must distinguish its source:

- trusted Control Plane;
- trusted host broker/runtime controller;
- Worker;
- Agent;
- model;
- tool/plugin;
- external provider.

An untrusted source's statement is evidence/claim, not trusted fact merely because it entered the logging pipeline.

---

## 61. Audit availability in disaster recovery

### LOCKED

Protected audit/receipt state is part of the MA-13 recovery set where physically required.

After restore:

- restored audit history remains historical;
- the recovery/restore itself creates new audit records;
- stale runtime receipts are not reactivated as live authority;
- integrity checks are performed before promotion where applicable.

---

## 62. System Evolution use of observability

### LOCKED

MA-15 may consume sanitized, policy-authorized observability/audit summaries for evaluation.

It cannot silently ingest all private logs/traces into long-term learning.

Any transition from telemetry to durable epistemic/learning state must pass MA-05/MA-15 governance.

---

## 63. Owner analytics

### LOCKED

SerapeumOS may derive Company-level analytics from authoritative/audited state, such as:

- Task completion;
- Agent workload;
- failure rates;
- action denials;
- model/runtime efficiency;
- approval burden.

Derived dashboards must preserve the underlying authority distinction and privacy scope.

A chart is not the source of truth.

---

## 64. Product analytics

### LOCKED

SerapeumOS does not require vendor-facing product analytics/behavior tracking.

If future maintainers add optional product analytics:

- it must be separately governed from Company observability;
- optional and transparent;
- privacy-minimized;
- disabled by default unless Owner explicitly chooses otherwise;
- never include Company content/secrets by default.

---

## 65. No dark telemetry

### LOCKED

The product must not intentionally maintain hidden telemetry channels that bypass configured privacy/observability policy.

Network egress relevant to telemetry must be visible under MA-08/MA-16 governance.

---

## 66. Release qualification

### LOCKED

MA-20 must test at least:

- mandatory audit events are emitted for required transitions;
- receipt lifecycle is crash/retry safe;
- no success receipt before verified outcome;
- audit write protections;
- redaction/minimization of known secret classes;
- external telemetry disabled in local-only default configuration;
- retention boundaries;
- Company-scope isolation;
- observability degradation behavior;
- audit-store failure behavior;
- audit/receipt recovery under MA-13;
- tamper-detection/protection mechanisms;
- privacy-safe diagnostic bundle generation.

---

## 67. Veto conditions

An MA-14 implementation is invalid if it:

- uses ordinary logs as the sole record of high-impact actions;
- treats traces as authoritative Company truth;
- lets Agents write trusted audit records directly;
- marks actions successful from model/Worker claims alone;
- omits mandatory audit/receipts through telemetry sampling;
- stores plaintext secrets in logs, traces, metrics, receipts, support bundles, or audit records;
- exports telemetry externally by default or as a required product dependency;
- duplicates complete Company content into telemetry without explicit purpose;
- gives one Company access to another Company's audit/telemetry;
- stores hidden chain-of-thought as an audit requirement;
- silently rewrites audit history;
- allows privacy deletion to falsify history without an auditable redaction/erasure event;
- lets operational telemetry exhaust resources needed by trusted services;
- silently executes consequential actions when required audit persistence is unavailable;
- treats an alert/dashboard as authoritative truth;
- allows an untrusted Agent/tool to impersonate trusted host/control-plane telemetry.

---

## 68. MA-14 closure decision

### CLOSED

MA-14 is architecture-complete.

Locked:

- explicit separation of observability, audit, receipts, and diagnostic content;
- logs/traces remain non-authoritative;
- durable trusted audit for governance/security events;
- first-class Action Receipts linked to MA-06;
- stable correlation and causation chains;
- Principal/Agent accountability independent of model/Worker identity;
- append-oriented/tamper-protected audit history;
- required audit persistence fail-closed for consequential operations;
- unknown external outcomes represented honestly;
- metadata-first observability and content minimization;
- no plaintext secrets in observability/audit;
- no hidden-chain-of-thought requirement;
- local-only observability path;
- external telemetry optional and disabled by default;
- privacy scoping and Company isolation;
- independent retention classes;
- governed privacy erasure without falsifying history;
- resource-bounded telemetry;
- mandatory audit/receipts never sampled away;
- recovery integration with MA-13;
- MA-20 adversarial/privacy qualification requirements.

No material MA-14 architecture question remains inside this domain.

---

## 69. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-141 — Observability, audit, receipts, and diagnostic content are separate classes
Operational telemetry is not authoritative audit or Action Assurance evidence.

### D-142 — High-impact accountability is committed by trusted services
Agents, Workers, models, and tools may emit evidence but cannot directly create trusted audit history.

### D-143 — Consequential actions require durable Action Receipts
Receipt state binds request, authority, attempt, outcome, verification, and evidence; model/Worker claims alone cannot prove completion.

### D-144 — Mandatory audit is append-oriented and tamper-protected
Material governance/security history is not silently rewritten; corrections and privacy redactions are themselves governed events.

### D-145 — Telemetry is metadata-first and secret-free
Sensitive content is minimized before emission and plaintext credentials/recovery secrets are prohibited from telemetry/audit stores.

### D-146 — SerapeumOS has no mandatory external telemetry
Local observability is sufficient for final operation; OTLP/SaaS/product analytics export is optional, explicit, and replaceable.

### D-147 — Detailed diagnostic content is optional and bounded
Prompt/output/body tracing is not required for correctness and, when enabled, is explicit, redacted, scoped, and retention-limited.

### D-148 — Privacy retention does not falsify accountable history
Data erasure may remove/detach sensitive payload while preserving a minimal policy-permitted audit skeleton and an auditable erasure/redaction event.

### D-149 — Required audit/receipts cannot be sampled away
Sampling/drop policies apply only to non-authoritative observability; inability to persist required audit may block the affected consequential action.

### D-150 — Telemetry never becomes Agent memory automatically
Any movement from observability/audit into durable knowledge or System Evolution learning requires MA-05/MA-15 governance.

---

## 70. Project-state transition

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
MA-13 — CLOSED
MA-14 — CLOSED

Current architecture domain:
MA-15 — System Evolution / Evaluation / Poisoning

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Repository persistence:
PENDING

Next action:
MA-15-CLOSE — architecture only
```

---

## 71. Next action

**MA-15-CLOSE — System Evolution / Evaluation / Poisoning**

Architecture only.
