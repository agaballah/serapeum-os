# MA-16 — Product UX / Permissions / Security UX

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED  
**Runtime prototypes:** PAUSED

---

## 1. Purpose

MA-16 defines the human-facing product contract for SerapeumOS.

It governs how the Owner and other authorized human Principals:

- understand Company state;
- supervise Agents;
- understand Tasks and work;
- grant/revoke authority;
- approve consequential actions;
- manage secrets and external connections;
- see security posture;
- stop/pause activity;
- inspect evidence, receipts, failures, and uncertainty.

This document locks **UX semantics and trust boundaries**, not a specific frontend framework, visual theme, or final pixel layout.

---

## 2. Governing UX principle

### LOCKED

> **SerapeumOS must make autonomy easy to supervise and difficult to misunderstand.**

The product should be calm, minimal, and operational.

Security must be visible when it matters without forcing the Owner to operate a low-level security console for ordinary work.

---

## 3. Product UX is not a security boundary

### LOCKED

The UI:

- explains;
- requests;
- previews;
- confirms;
- displays authoritative state.

The UI does **not** become the authority for:

- authentication;
- AuthZ;
- capability issuance;
- Action Assurance;
- secret access;
- durable-state mutation;
- audit truth.

Trusted backend/domain services enforce those controls even if the UI is bypassed, stale, compromised, or incorrectly implemented.

---

## 4. SerapeumOS product shell vs inherited Ankole Console

### REPOSITORY FACT

The inherited Ankole webapps already contain:

- authentication/setup surfaces;
- a Console;
- Principal/group management;
- permission-grant editing;
- Agent management;
- jobs/schedules;
- Brain/knowledge views;
- provider/model settings;
- observability settings;
- worker/runtime views.

### REPOSITORY FACT

The inherited permission editor exposes technical grant fields such as:

- `resource_pattern`;
- `action`;
- `condition`;
- description.

### REPOSITORY FACT

The inherited encrypted-value UI supports a separately authorized reveal operation for a stored secret and locally re-masks revealed values after a timeout/window blur.

### LOCKED

These are reusable **foundation/admin surfaces**, not the final SerapeumOS Owner UX contract.

SerapeumOS adds a product-level Owner experience above them.

Where inherited behavior conflicts with a SerapeumOS MA lock, the SerapeumOS architecture controls.

---

## 5. Primary human experience

### LOCKED

The default experience is an **Owner Workspace**, not a developer/admin console.

It presents the Company as an operating organization:

```text
COMPANY
├── Goals / Priorities
├── Work / Tasks
├── Agents / Organization
├── Knowledge / Evidence
├── Approvals
├── Activity / Receipts
└── Security / Settings
```

Exact navigation labels and grouping may change during product design while preserving these capabilities.

---

## 6. Advanced Administration

### LOCKED

Low-level configuration and diagnostics may exist in a separate **Advanced Administration** surface.

Examples:

- raw permission expressions;
- provider internals;
- runtime/worker diagnostics;
- detailed audit records;
- technical storage/runtime settings.

### LOCKED

Advanced mode:

- is deliberate;
- is not the default Owner workflow;
- does not grant additional authority merely because it is visible;
- cannot bypass AuthZ or Action Assurance;
- cannot weaken constitutional hard blocks through a “continue anyway” control.

Hidden UI is not a security mechanism.

---

## 7. Minimalism and progressive disclosure

### LOCKED

The default UI shows the smallest information set needed to make the current decision correctly.

Technical detail remains available by drill-down.

Pattern:

```text
summary
→ consequence / current state
→ evidence / permissions / technical details
```

The product must avoid permanent walls of:

- raw JSON;
- internal IDs;
- CEL/policy expressions;
- model traces;
- debug logs.

Those remain inspectable where useful.

---

## 8. Trust state must be factual

### LOCKED

Security/health indicators derive from trusted control-plane state and verified evidence, not Agent/model self-report.

If status is:

- stale;
- unavailable;
- partially verified;
- uncertain

the UI shows that explicitly.

Unknown is never rendered as healthy merely because no error was observed.

---

## 9. No single deceptive “secure” score

### LOCKED

SerapeumOS does not reduce security posture to one reassuring scalar score.

The Security surface reports relevant components separately, for example:

- Agent isolation;
- runtime readiness;
- active permissions;
- temporary capabilities;
- secrets/credentials;
- external connectivity;
- plugins/tools;
- blocked/uncertain actions;
- audit integrity;
- update/supply-chain state when applicable.

A high-level summary may exist, but it cannot hide component failures.

---

## 10. Human identity context

### LOCKED

The UI always knows which authenticated human Principal is operating.

Security-sensitive screens/actions make the acting Principal clear.

Company role/title and technical authority remain distinct.

A human-readable role label does not imply a permission.

---

## 11. Agent identity UX

### LOCKED

Each Agent is presented as a persistent organizational identity.

The Agent view must distinguish:

- Agent identity;
- organizational role class/title;
- Mission;
- accountable Tasks;
- current lifecycle state;
- granted permissions/capabilities;
- current runtime/model binding;
- recent activity/review state.

### LOCKED

Model selection is subordinate metadata.

Changing a model must not visually imply that the Agent itself was replaced.

---

## 12. Organization UX

### LOCKED

The organization view distinguishes:

- Company membership;
- reporting/organizational hierarchy;
- role;
- technical permissions.

This prevents the false mental model:

> “Manager role = admin permission.”

Hierarchy remains responsibility/routing; MA-06 remains permission authority.

---

## 13. Task UX

### LOCKED

A Task view must make clear:

- objective;
- origin;
- accountable Agent;
- Goal/Mission lineage where applicable;
- current Task state;
- acceptance criteria;
- dependencies/waiting reason;
- execution status;
- review status;
- approval blockers;
- outputs/evidence;
- failure/uncertainty.

### LOCKED

A successful Worker/job/turn must not be visually represented as completed Company work until the Task acceptance state is actually satisfied.

---

## 14. Work state semantics

### LOCKED

User-facing work states preserve MA-04 semantics:

```text
PROPOSED
READY
ASSIGNED
IN_PROGRESS
WAITING
REVIEW
COMPLETED
FAILED
CANCELLED
```

Implementation may use friendlier display text, but it cannot merge materially distinct states in a way that misleads the Owner.

In particular:

- WAITING must say what it is waiting for;
- REVIEW is not COMPLETED;
- runtime interruption is not necessarily Task failure;
- Task cancellation is not the same as killing one Worker process.

---

## 15. First-class approval inbox

### LOCKED

Actions requiring Owner/human approval appear in a dedicated approval queue.

The Owner must not have to discover approval requests by reading Agent chat.

Approval requests are durable control-plane objects, not conversational suggestions.

---

## 16. Approval card contract

### LOCKED

Before a governed consequential action, the approval surface shows enough information to understand the exact decision.

As applicable:

- requesting Agent/Principal;
- originating Task;
- intended action;
- exact target;
- why the action is requested;
- material payload/content preview;
- local vs external boundary;
- data that will leave the machine;
- expected side effect;
- reversibility;
- risk explanation;
- approval expiry/validity;
- current relevant target state.

Technical details may be expandable.

---

## 17. Approval is not AuthZ

### LOCKED

The UI preserves the MA-06 distinction:

```text
permission to attempt ≠ approval to execute
```

An `ALLOW` AuthZ result does not become “Owner approved.”

Likewise:

- review approval ≠ Action Assurance approval;
- Owner approval ≠ constitutional permission to perform a prohibited action.

The product must not collapse these concepts into one generic green “Approved” state.

---

## 18. Approval binding

### LOCKED

Approval binds to the exact normalized action and target state required by MA-06.

If a material input changes after approval, the UI must not silently reuse the previous approval.

It must show that the prior approval is no longer valid and request a new governed decision where required.

---

## 19. Approval outcomes

### LOCKED

Normal approval UX provides explicit outcomes such as:

- Approve;
- Deny;
- Cancel/dismiss without approval.

Closing the dialog or navigating away is not approval.

Expired approval is not approval.

Timeout is not approval.

---

## 20. No “Always allow” inside an action confirmation

### LOCKED

A one-time consequential-action approval cannot silently turn into a permanent permission grant.

If the Owner wants persistent delegation, the product takes them through a separate permission-management flow showing the broader scope.

This prevents approval fatigue from becoming privilege escalation.

---

## 21. Permission UX model

### LOCKED

Normal permission management is expressed in human concepts:

```text
WHO
can do WHAT
to WHICH SCOPE
under WHICH CONDITIONS
for HOW LONG
```

Examples of UX concepts:

- Agent/Principal;
- tool/action category;
- resource/project/company scope;
- local/external destination;
- conditions;
- expiry or Task-bound scope.

The implementation may compile this into lower-level MA-06 grants/capabilities.

---

## 22. Raw policy expressions

### LOCKED

Raw resource patterns, low-level action names, and policy expressions may remain accessible in Advanced Administration.

They are not required for normal Owner permission management.

When an advanced expression is edited, the product should provide a human-readable interpretation where technically possible.

The interpretation is explanatory only; the trusted policy engine remains authoritative.

---

## 23. Effective-access view

### LOCKED

For a Principal/Agent, the product must be able to explain effective access sufficiently for human governance.

The view distinguishes, as applicable:

- direct grant;
- group-derived grant;
- temporary capability;
- scope/condition;
- expiry/revocation;
- denial/blocking reason.

The Owner should not need to manually reconstruct effective authority from multiple tables.

---

## 24. Capability UX

### LOCKED

Temporary capabilities are visibly temporary.

The UI exposes, as applicable:

- holder;
- purpose;
- permitted action/scope;
- Task/action binding;
- expiry;
- issuing authority;
- revocation state.

A capability is not displayed as a permanent role.

---

## 25. Revocation UX

### LOCKED

The Owner can revoke eligible:

- permission grants;
- temporary capabilities;
- external connections;
- Agent operational eligibility;
- credentials/secrets through their owning broker workflow.

Revocation surfaces must state expected consequence.

Revocation does not rewrite history; past actions remain in Activity/Audit.

---

## 26. Safe defaults

### LOCKED

Default interaction behavior is conservative:

- destructive/consequential actions are not primary accidental clicks;
- closing confirmation does not approve;
- permission forms do not default to broad wildcard authority;
- external access is not silently enabled;
- unknown security state does not imply permission;
- unavailable authorization/approval services fail closed.

---

## 27. Risk communication

### LOCKED

Risk UX is specific, not theatrical.

Warnings should explain:

1. what will happen;
2. what or who is affected;
3. whether data leaves the machine;
4. whether the action is reversible;
5. why approval is required.

Generic repeated warnings are minimized to avoid habituation.

---

## 28. Security state cannot rely on color

### LOCKED

Meaning is communicated through:

- text;
- labels;
- icons where useful;
- structure.

Color may reinforce meaning but cannot be the only carrier.

This applies especially to:

- blocked;
- warning;
- uncertain;
- approved;
- revoked;
- failed.

---

## 29. Hard block UX

### LOCKED

When an action is prohibited by constitutional/security policy, the UI states that it is **blocked**.

It does not offer a misleading:

- “Ignore”;
- “Force”;
- “Continue anyway”

control unless the underlying architecture explicitly defines a lawful higher-authority override for that specific rule.

Owner authority does not mean the UI may bypass constitutional invariants.

---

## 30. Step-up authentication

### LOCKED

Sensitive human operations may require fresh trusted authentication according to policy.

Examples may include:

- changing high-impact permissions;
- ownership/governance actions;
- credential replacement/revocation;
- security-control changes;
- high-impact approval.

### LOCKED

Authentication, authorization, and approval remain separate:

```text
Who are you?
→ Are you permitted?
→ Is this action approved?
```

The exact platform-specific authentication mechanism belongs to later host/product implementation.

---

## 31. Secret UX

### LOCKED

MA-10 controls.

Normal SerapeumOS product UX:

- explains why a credential is needed;
- identifies intended scope/destination;
- accepts replacement/new secret through trusted UI;
- never stores it in Agent-visible state;
- never shows it in logs/prompts/artifacts;
- shows safe metadata/status;
- permits replace/revoke/delete where applicable.

### LOCKED

Stored secret plaintext is **not redisplayed** in normal SerapeumOS product UX after storage.

The inherited Ankole secret-reveal UI therefore cannot define final SerapeumOS behavior where it conflicts with MA-10.

---

## 32. Secret failure UX

### LOCKED

If the trusted secret/root mechanism is unavailable:

- the UI reports the credential as unavailable/locked;
- affected operations remain blocked;
- there is no fallback to plaintext storage;
- the product does not claim a secret can be recovered if it cannot.

Potentially destructive credential reset/replacement clearly states consequences before execution.

---

## 33. External-boundary UX

### LOCKED

Whenever an action crosses the local-machine boundary in a material way, the product makes that boundary visible.

Relevant UX may show:

- destination/provider;
- category of data leaving;
- purpose;
- requesting Agent/Task;
- applicable permission/approval.

“Local-first” must not become an excuse to hide the moment data leaves local control.

---

## 34. Offline/local posture

### LOCKED

The final product core remains usable without mandatory cloud control-plane, hosted identity, hosted memory, or hosted evaluation.

The UX does not imply that an internet connection is required for Company truth or core control.

Optional external providers/tools are presented as optional connections.

NaraRouter remains a temporary development exception and is not a final product UX dependency.

---

## 35. Emergency control

### LOCKED

The Owner has trusted emergency controls that do not depend on cooperation from an Agent.

At minimum the product architecture supports:

- pause all autonomous Agent execution;
- pause/suspend an Agent;
- stop/cancel eligible execution;
- revoke temporary authority;
- inspect what remains active.

### LOCKED

The UI must distinguish:

- pausing admission/execution;
- cancelling a Task;
- terminating a Worker/appliance.

They are not semantically identical.

---

## 36. Global pause visibility

### LOCKED

A global autonomous-execution pause is visible from the main product shell and Security/Operations surfaces.

When active, the UI clearly states:

- new autonomous work is blocked/paused;
- what may still be running or reconciling;
- how to inspect remaining activity.

The pause cannot rely on Agents voluntarily obeying a chat instruction.

---

## 37. Uncertain external outcome UX

### LOCKED

MA-12 uncertainty must be visible.

If the system cannot prove whether an external side effect succeeded:

```text
UNCERTAIN
```

must remain distinct from:

- SUCCEEDED;
- FAILED.

The UI provides:

- last verified state;
- reconciliation status;
- evidence/receipt link;
- safe next action where available.

It must never show a false success merely to simplify the interface.

---

## 38. Receipts over toasts

### LOCKED

A transient success toast is not sufficient proof for consequential operations.

For material actions, the UX provides a durable receipt/history entry that can answer:

- who requested;
- who authorized/approved;
- what target/action;
- when;
- execution result;
- verification result;
- resulting state;
- uncertainty/failure if any.

---

## 39. Activity vs raw logs

### LOCKED

The Owner-facing **Activity** view is a human-readable operational history.

Raw technical logs remain a diagnostic layer.

The Owner should be able to reconstruct meaningful Company actions without reading runtime logs.

MA-14 remains the source for audit integrity/retention/privacy.

---

## 40. Explain “why allowed / why blocked”

### LOCKED

Where safe and practical, the product explains authorization decisions in human terms.

Examples:

- “This Agent has no permission to publish externally.”
- “This temporary capability expired.”
- “Owner approval is required.”
- “This action is blocked by Company policy.”

The explanation must not disclose:

- secret values;
- sensitive credential material;
- unnecessary internal security details that create new exposure.

---

## 41. Agent request UX

### LOCKED

When an Agent needs something it does not possess, it should create a structured request, not pressure the Owner conversationally.

Requests may concern:

- approval;
- additional permission;
- human decision;
- credential connection;
- missing information;
- blocked dependency.

The request is associated with the relevant Task/Agent and has a clear resolution state.

---

## 42. Permission escalation request

### LOCKED

An Agent may request broader authority but cannot apply it.

The Owner-facing request must explain:

- current missing authority;
- requested scope;
- purpose;
- duration/boundary;
- affected Task/work.

The system may suggest a narrower alternative where possible.

The default design preference is least authority.

---

## 43. Repeated approval pressure

### LOCKED

The product must avoid dark patterns and approval pressure.

It must not:

- repeatedly reopen a denied approval to wear down the Owner;
- make “Approve” materially easier than “Deny” for security-critical actions;
- imply the system is broken because the Owner refused authority;
- hide the ability to revoke prior delegation.

A denied action returns to a governed Task state such as blocked/waiting/failed according to MA-04/MA-12 policy.

---

## 44. Onboarding security semantics

### LOCKED

First-run product onboarding must establish, at the UX level:

- local human Owner identity;
- Company identity;
- local/security posture;
- storage location/availability;
- local inference/runtime readiness;
- optional external connections;
- default-deny authority posture.

### LOCKED

Onboarding must not silently:

- enable broad network access;
- install/activate external integrations without consent;
- grant Agents broad permissions;
- create hidden cloud dependencies.

Exact installer/update mechanics belong to MA-18.

---

## 45. Permissions during Agent creation

### LOCKED

Creating an Agent does not implicitly grant broad operational authority.

Agent creation UX separates:

- identity;
- role;
- Mission;
- tool/skill availability;
- permissions/capabilities.

The product may offer safe permission templates, but the effective scope must remain inspectable.

A role template is not technical authority by itself.

---

## 46. Model/provider UX

### LOCKED

Model/provider settings should communicate:

- local vs external provider;
- availability/readiness;
- model/profile assignment;
- resource implications where relevant;
- data-boundary consequences for external inference.

Provider/model failures do not alter Agent identity.

### LOCKED

Final product defaults favor qualified local inference.

Temporary development use of NaraRouter must not be encoded as a permanent normal-user dependency.

---

## 47. Tool / Skill / Plugin UX

### LOCKED

The product distinguishes:

- installed/available;
- enabled for Company/Agent;
- permissioned;
- externally connected;
- currently usable;
- blocked/quarantined.

“Installed” or “enabled” does not mean “authorized for every action.”

Tool/Skill/plugin UX remains subordinate to MA-06, MA-08, MA-10, MA-15, and MA-19.

---

## 48. System Evolution UX

### LOCKED

MA-15 evolution is visible enough for Owner governance.

The product can surface:

- candidate improvement;
- change class;
- evaluation result;
- contamination/quarantine status;
- requested approval where applicable;
- promoted version;
- rollback/supersession state.

SE-3/SE-4 changes are never presented as autonomously self-approved.

---

## 49. Backup/recovery UX

### LOCKED

Recovery operations explain:

- source recovery point;
- Company/state scope affected;
- expected rollback consequence;
- data that may be superseded;
- post-recovery verification state.

A restore action cannot be represented as equivalent to ordinary file copying.

Detailed backup/restore mechanics remain MA-13.

---

## 50. Update/security-change UX

### LOCKED

For trusted product updates, the Owner-facing UX distinguishes:

- update available;
- verified/qualified status;
- source/provenance status;
- migration implications;
- restart/downtime;
- rollback availability.

The UI must not describe an unverified candidate as a trusted update.

MA-18/MA-19/MA-20 own the underlying mechanisms.

---

## 51. Configuration changes

### LOCKED

Security-relevant configuration changes use explicit save/apply semantics.

Unsaved UI draft state is not authoritative configuration.

Where a change is consequential, the resulting authoritative mutation is auditable and may require step-up authentication/approval according to policy.

---

## 52. Stale UI / concurrency

### LOCKED

The product assumes UI data can become stale.

Before consequential mutations, trusted services re-check current authoritative state.

The UX must handle conflicts explicitly rather than silently overwriting newer authoritative changes.

For approval-sensitive changes, material target drift invalidates prior approval as defined by MA-06.

---

## 53. Duplicate click / retry behavior

### LOCKED

The UI must not turn repeated clicks, browser refreshes, or connection retries into duplicate external side effects.

Consequential action submission is tied to MA-12 idempotency/reconciliation semantics.

The UI may disable repeated submission for usability, but backend correctness cannot rely on that alone.

---

## 54. Accessibility

### LOCKED

Core Owner/security workflows must be accessible.

Architecture requires:

- keyboard-operable controls;
- meaningful labels;
- focus visibility;
- non-color-only status;
- readable contrast;
- scalable text/layout;
- screen-reader-compatible semantics for critical controls.

Accessibility cannot be deferred only to cosmetic polish because it affects security decision quality.

---

## 55. Localization

### LOCKED

Human-facing security semantics are localization-capable.

Localized wording must preserve security meaning.

Technical identifiers may remain untranslated where translation could create ambiguity.

The inherited Ankole i18n substrate may be reused where appropriate.

---

## 56. Confirmation language

### LOCKED

Consequential confirmation copy uses concrete verbs and targets.

Prefer:

> “Send this message to X”

over:

> “Proceed?”

Prefer:

> “Revoke Agent A’s publish permission”

over:

> “Confirm change”

The purpose is correct human decision-making, not ceremonial consent.

---

## 57. Destructive actions

### LOCKED

Irreversible/destructive actions receive stronger friction than reversible ordinary actions.

UX may require additional deliberate confirmation according to risk.

Architecture does not prescribe one universal mechanism such as typing a phrase; implementation may select suitable patterns.

No extra confirmation can override a hard policy prohibition.

---

## 58. Security-center minimum contract

### LOCKED

The final product has a consolidated Security/Control surface capable of exposing, directly or through drill-down:

- active Company/Owner identity;
- Agent execution pause state;
- security/runtime readiness;
- permissions/grants;
- temporary capabilities;
- pending approvals;
- secrets/credentials status;
- external providers/connections;
- enabled tools/Skills/plugins;
- blocked/quarantined items;
- recent security-significant receipts/events;
- backup/recovery status where available;
- update/supply-chain status where available.

Exact screen organization is deferred to product design.

---

## 59. Main dashboard minimum contract

### LOCKED

The default Company dashboard prioritizes:

- what needs Owner attention;
- active goals/work;
- Agent/work status;
- waiting/review/approval blockers;
- meaningful failures/uncertainty;
- system readiness issues that affect work.

It does not default to raw infrastructure telemetry.

---

## 60. Notification policy

### LOCKED

Notifications prioritize actionability.

High-value classes include:

- approval required;
- human input required;
- blocked Task;
- consequential failure/uncertain action;
- critical security/runtime condition;
- completed material work where Owner attention is appropriate.

Background healthy events should not create notification noise.

---

## 61. No chat-only governance

### LOCKED

Chat may explain or initiate governed workflows.

Chat alone is not sufficient for:

- durable permission grants;
- consequential approval;
- ownership transfer;
- secret management;
- architecture/governance mutation.

When chat triggers such a workflow, the product transitions into the structured authoritative surface.

---

## 62. AI-generated explanations

### LOCKED

A model may help explain:

- permission meaning;
- risk;
- audit history;
- Task state.

Such prose is advisory presentation.

The underlying structured trusted state remains visible/recoverable and controls the decision.

The model cannot alter the security meaning by paraphrasing it.

---

## 63. Privacy by presentation

### LOCKED

Owner-facing lists/cards avoid exposing more sensitive content than required.

Sensitive payloads may require deliberate drill-down.

Screenshots/shoulder-surfing risk should be considered for:

- secret metadata;
- private content previews;
- credentials;
- external destination information.

This is defense-in-depth, not a substitute for MA-10.

---

## 64. Failure behavior

### LOCKED

If the product UI fails or loses connectivity to trusted local services:

- no new consequential action is considered approved merely because a button was pressed;
- unclear state is shown as unavailable/uncertain;
- the system does not silently bypass security to remain responsive;
- authoritative execution continues or halts according to backend MA-12 policy, not browser/frontend assumption.

---

## 65. Product-mode security invariants

### LOCKED

The Owner UX must never create these false equivalences:

```text
ROLE = PERMISSION
MODEL = AGENT
RUN SUCCESS = TASK COMPLETE
REVIEW = ACTION APPROVAL
AUTHZ ALLOW = OWNER APPROVAL
ENABLED TOOL = AUTHORIZED ACTION
SECRET STORED = SECRET REVEALABLE
NO ERROR = SAFE
UNKNOWN = HEALTHY
OWNER CLICK = CONSTITUTIONAL OVERRIDE
```

---

## 66. Architecture-level UX vetoes

An MA-16 implementation is invalid if it:

- makes the raw inherited Console the only normal Owner experience;
- requires ordinary users to author raw permission policy expressions for routine delegation;
- allows UI state to become authorization authority;
- displays a role as if it grants permissions;
- hides the accountable Agent or Task behind a generic model/chat identity;
- uses chat as the sole approval/permission system;
- combines one-time approval with permanent “always allow” escalation;
- redisplays stored secret plaintext in normal SerapeumOS UX;
- shows unknown/stale security state as healthy;
- offers “continue anyway” against constitutional hard blocks;
- lets a transient toast stand as the only evidence of a consequential action;
- treats Worker/job success as Task completion;
- hides external data transfer;
- silently enables network/integrations or broad Agent authority;
- makes security meaning dependent only on color;
- relies on disabled buttons/client validation for security enforcement;
- lets repeated UI submission create duplicate external actions;
- creates a mandatory cloud UX dependency;
- prevents the Owner from issuing trusted pause/revocation controls independently of Agents.

---

## 67. MA-16 closure decision

### CLOSED

MA-16 is architecture-complete.

Locked:

- Owner Workspace as the primary product experience;
- Advanced Administration as secondary technical surface;
- progressive disclosure/minimal operational design;
- trusted-state-driven security UX;
- explicit Agent/role/Mission/Task/model separation;
- first-class Task and approval UX;
- approval distinct from AuthZ/review;
- exact-action approval binding;
- no embedded “Always allow” privilege escalation;
- human-readable permission model;
- effective-access and capability visibility;
- conservative defaults;
- explicit hard blocks;
- step-up authentication concept;
- MA-10-compliant non-reveal secret UX;
- visible local/external boundary;
- trusted emergency pause/revocation controls;
- explicit uncertain outcome state;
- durable receipts/activity;
- structured Agent escalation requests;
- safe onboarding semantics;
- explicit model/provider/tool boundary status;
- Security Center;
- accessible/localizable security semantics;
- chat cannot replace structured governance surfaces.

No material MA-16 architecture question remains inside this domain.

---

## 68. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-166 — Owner Workspace is the primary product UX
SerapeumOS presents the Company, work, Agents, approvals, activity, and security as an operational product; inherited technical Console surfaces remain secondary/admin substrate.

### D-167 — UX is explanatory, not authoritative
Authentication, AuthZ, capabilities, Action Assurance, secrets, and durable state remain enforced by trusted backend services.

### D-168 — Normal permissions use human-readable policy semantics
Routine delegation is expressed as Who / What / Scope / Conditions / Duration; raw resource/action/policy expressions are advanced administration.

### D-169 — Approval and permission are separate UX flows
A one-time action approval cannot silently create permanent authority; persistent delegation requires a separate permission flow.

### D-170 — Consequential approvals bind exact action and target state
Material changes after approval invalidate reuse and require governed re-evaluation.

### D-171 — Stored secret plaintext is not redisplayed in normal product UX
Secret management exposes safe metadata and replace/revoke/delete flows while preserving MA-10 non-disclosure.

### D-172 — Security status must expose unknown and stale states
No-error and unavailable evidence are not represented as healthy.

### D-173 — Owner has trusted emergency controls independent of Agents
Global pause, Agent pause/suspension, eligible execution stop, and authority revocation do not depend on Agent cooperation.

### D-174 — Uncertain external outcomes are first-class UX states
UNCERTAIN is never collapsed into success/failure until reconciliation proves the result.

### D-175 — Consequential actions produce durable receipts
Transient frontend notifications are insufficient evidence of trusted side effects.

### D-176 — External data-boundary crossings are visible
Destination, purpose, and material data leaving local control are surfaced where relevant.

### D-177 — Chat cannot be the sole governance surface
Durable permissions, consequential approvals, secret management, ownership, and governance changes use structured authoritative workflows.

### D-178 — Security UX uses progressive disclosure
Default views remain minimal and human-readable while technical evidence/details remain inspectable.

### D-179 — Product security semantics are accessible and localization-safe
Critical states and decisions cannot rely on color alone and must preserve meaning across supported localization/accessibility modes.

---

## 69. Project-state transition

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
MA-15 — CLOSED
MA-16 — CLOSED

Current architecture domain:
MA-17 — Host Compatibility / Storage Semantics

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Repository persistence:
PENDING

Next action:
MA-17-CLOSE — architecture only
```

---

## 70. Next action

**MA-17-CLOSE — Host Compatibility / Storage Semantics**

Architecture only.
