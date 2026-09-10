# MA-20 — Qualification / Release Gates

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED  
**Executable Qualification:** NOT RUN  
**Runtime prototypes:** PAUSED  
**Repository persistence:** PENDING

---

## 1. Purpose

MA-20 defines the architecture by which SerapeumOS proves that an exact candidate is fit for an exact supported production context before MA-19 Release Authorization and MA-18 activation.

It governs:

- qualification authority and evidence ownership;
- exact candidate/evidence binding;
- release-gate taxonomy and ordering;
- test/evaluation taxonomy;
- adversarial and negative-path qualification;
- isolation, AuthZ, secret, storage, audit, privacy and Company-separation qualification;
- fault injection, crash recovery and ambiguous-outcome qualification;
- backup/restore and disaster-recovery qualification;
- install/update/migration/rollback/repair/uninstall qualification;
- host/platform/backend/storage matrix qualification;
- model/runtime/profile and trusted-extension qualification;
- resource stress, performance-regression and long-duration/endurance qualification;
- clean-machine and hidden-dependency qualification;
- test fixture/harness provenance and evidence quality;
- flaky-test, rerun, exception and waiver semantics;
- release vetoes, readiness verdicts and qualification staleness;
- requalification triggers and impact-scoped qualification;
- emergency-release minimum gates;
- post-release evidence and qualification revocation;
- handoff to MA-19 Release Authorization and MA-18 lifecycle activation.

MA-20 does **not** implement tests, select concrete test frameworks, execute the qualification suite, choose final backend package versions, or declare the unimplemented product releasable.

---

## 2. Governing principle

### LOCKED

> **A candidate is release-qualified only when the required evidence proves the required properties for the exact candidate bytes, exact declared state transition, and exact supported environment class. Absence of observed failure is not proof of qualification.**

---

## 3. Architecture closure is not product qualification

### LOCKED

Closing MA-20 means the qualification/release-gate architecture is complete.

It does **not** mean:

- SerapeumOS implementation exists;
- the first production host matrix has been executed;
- QEMU/WHPX or any other backend has passed production qualification;
- any model/runtime profile has passed production qualification;
- installer/update/migration/rollback behavior has been proven;
- a production Release Envelope exists;
- the product is ready to ship.

Actual qualification occurs only after implementation under the master roadmap.

### LOCKED

No release-readiness language may collapse these states:

```text
ARCHITECTURE QUALIFICATION CONTRACT CLOSED
                ≠
IMPLEMENTATION COMPLETE
                ≠
QUALIFICATION EXECUTED
                ≠
RELEASE QUALIFIED
                ≠
RELEASE AUTHORIZED
                ≠
ACTIVATED IN PRODUCTION
```

---

## 4. Relationship to MA-01 → MA-19

### LOCKED

MA-20 does not redesign prior architecture. It proves implementations against the already locked contracts.

In particular:

- MA-01 defines hostile-workload containment and TCB security invariants;
- MA-02 defines runtime/process ownership and fencing;
- MA-03/04 define Company/Agent/Task identity and accountability;
- MA-05 defines evidence/truth/provenance semantics;
- MA-06 defines AuthZ, capabilities and Action Assurance;
- MA-07 defines model/runtime routing and qualification boundaries;
- MA-08 defines tool/plugin/MCP/browser trust boundaries;
- MA-09 defines durable-state/artifact/publication semantics;
- MA-10 defines secret/credential/principal protections;
- MA-11 defines resource-governance invariants;
- MA-12 defines retry/checkpoint/cancellation/recovery semantics;
- MA-13 defines backup/restore/DR semantics;
- MA-14 defines audit/observability/privacy guarantees;
- MA-15 defines governed system evolution and change classes;
- MA-16 defines security/permissions/recovery UX truthfulness;
- MA-17 defines the Host Compatibility Contract and first host families;
- MA-18 defines install/update/migration/rollback lifecycle semantics;
- MA-19 defines exact software identity, provenance and Release Envelope semantics.

MA-20 is the executable-proof contract across those domains.

---

## 5. Qualification proves bounded claims

### LOCKED

Qualification claims are always bounded by a declared scope.

A passing result proves only the tested/covered claim for the bound candidate and qualification scope. It never proves that software is universally safe or bug-free.

### LOCKED

A qualification claim must identify at least:

```text
candidate identity/digests
release/build provenance identity
qualification policy version
architecture contract/version set
host compatibility profile/family
backend/storage/runtime profile
persistent-state vector or migration edge where applicable
resource envelope
suite/harness/fixture identities
required gate set
executed evidence
exceptions
verdict
staleness/requalification conditions
```

---

## 6. Exact-candidate binding

### LOCKED

MA-20 evidence binds to the exact candidate artifact/release-envelope subject digests supplied by MA-19.

A passing report cannot be reused for:

- different executable bytes;
- a repackaged payload whose signed subject bytes differ;
- a changed dependency graph;
- a different appliance image;
- a different trusted plugin/helper;
- a materially different host/backend/storage combination;
- an unqualified migration edge;
- a materially changed model/runtime profile where that profile is part of the claim.

### LOCKED

Any post-qualification modification to a bound payload byte invalidates the qualification binding for that payload and requires new candidate identity plus applicable requalification.

---

## 7. Qualification Authority

### LOCKED

SerapeumOS recognizes a logical **Qualification Authority** responsible for producing a durable qualification verdict from evidence under a versioned Qualification Policy.

The Qualification Authority is distinct from:

- candidate generation;
- ordinary build execution;
- MA-19 Build Provenance Authority;
- MA-19 Release Authorization;
- Agent/model self-evaluation;
- MA-18 lifecycle activation.

### LOCKED

The Qualification Authority may be implemented by local automated tooling plus required human/PM review. It does not require a cloud service.

### LOCKED

No Agent/model/candidate generator may self-declare its output release-qualified.

---

## 8. Qualification Policy

### LOCKED

Qualification is governed by a durable, versioned **Qualification Policy**.

Conceptually it contains:

```text
qualification_policy_id/version
applicable architecture versions
release/change classes
required gate graph
required test families
matrix rules
minimum evidence quality
coverage/resource/performance/endurance thresholds where applicable
fuzz/stress budgets where applicable
review independence rules
exception rules
hard veto classes
requalification triggers
retention rules
```

### LOCKED

Numeric thresholds and exact tool selections may evolve beneath this architecture through versioned policy and evidence. Their absence from MA-20 text is not an unresolved architecture gap.

### LOCKED

A threshold may not be changed retroactively to convert a failed candidate into a pass without recording a new policy version, rationale, authority and requalification impact.

---

## 9. Qualification evidence states

### LOCKED

Required evidence uses explicit states such as:

```text
NOT_RUN
PASS
FAIL
INCONCLUSIVE
BLOCKED
NOT_APPLICABLE_WITH_RATIONALE
STALE
```

`INCONCLUSIVE`, `NOT_RUN`, `BLOCKED`, and `STALE` are not pass.

### LOCKED

`NOT_APPLICABLE_WITH_RATIONALE` is permitted only when the Qualification Policy proves that the test family does not apply to the bound candidate/scope. It cannot be used as a convenience skip.

---

## 10. Evidence immutability and failure history

### LOCKED

Qualification preserves the history of failures, reruns, environmental invalidations, accepted exceptions and final outcomes.

A later passing rerun does not erase an earlier failure.

### LOCKED

Test evidence is append-oriented/versioned and linked by correlation/causation identifiers sufficient to reconstruct:

```text
candidate
→ environment
→ action/test
→ raw result
→ triage
→ rerun/remediation
→ final verdict
```

---

## 11. Qualification evidence bundle

### LOCKED

Each production qualification produces a durable **Qualification Evidence Bundle**.

It binds at least:

- candidate/release subject digests;
- MA-19 provenance/SBOM/material references;
- architecture/qualification-policy versions;
- tested matrix rows;
- test-suite/harness/fixture versions and digests;
- environment/host-profile evidence;
- test execution records;
- static-analysis and build verification summaries;
- security/adversarial evidence;
- fault/recovery evidence;
- migration/rollback evidence where applicable;
- resource/performance/endurance summaries where applicable;
- coverage/measurement summaries where meaningful;
- known failures and rerun history;
- approved bounded exceptions;
- reviewer/authority evidence;
- verdict and scope;
- staleness triggers.

### LOCKED

The Evidence Bundle is local/offline verifiable and must not require a hosted dashboard to establish release status.

---

## 12. Evidence source integrity

### LOCKED

MA-19 provenance rules apply to qualification tools whose output can decide release acceptance.

Qualification records the exact identities/versions of material:

- test runners;
- harnesses;
- fuzzers;
- scanners;
- reference fixtures;
- mock/simulation components;
- destructive-test orchestration;
- benchmark workloads;
- qualification scripts.

### LOCKED

Changing a qualification tool may change evidence semantics and therefore triggers impact review before older/newer results are compared as equivalent.

---

## 13. Test fixture governance

### LOCKED

Fixtures that decide release acceptance are versioned, provenance-recorded and protected from silent candidate-driven modification.

### LOCKED

Security/reliability fixture families include representative:

- valid inputs;
- malformed inputs;
- adversarial inputs;
- historical regressions;
- corrupted state/artifacts;
- path/Unicode/case edge cases;
- concurrency races;
- resource-pressure scenarios;
- crash/restart cut points;
- migration/rollback source states;
- cross-Company isolation cases.

### LOCKED

Production qualification does not require private real Company data. Synthetic/minimized fixtures are preferred unless a separately governed reason exists.

---

## 14. Candidate-generation/evaluation separation

### LOCKED

Where practical, holdout/adversarial qualification cases are protected from the candidate-generation loop.

### LOCKED

For material SE-2 and all SE-3/SE-4 changes, independent review/evaluation requirements from MA-15 cannot be satisfied solely by the model/Agent/process that generated the candidate.

### LOCKED

Contaminated or candidate-visible evaluation cases remain useful diagnostic evidence but cannot be represented as independent holdout qualification.

---

## 15. Qualification gate graph

### LOCKED

Production release qualification is a directed gate graph, not a single test command.

The minimum conceptual gates are:

```text
QG-0  Candidate Identity / MA-19 Admission
QG-1  Build / Static / Deterministic Baseline
QG-2  Unit / Component / Contract Qualification
QG-3  Integration / System / End-to-End Qualification
QG-4  Security / Adversarial / Isolation Qualification
QG-5  Storage / Fault / Recovery / DR Qualification
QG-6  Install / Update / Migration / Rollback Qualification
QG-7  Resource / Performance / Endurance Qualification
QG-8  Host / Backend / Clean-Machine Matrix Qualification
QG-9  Evidence Review / Release-Qualification Verdict
```

Exact execution order may parallelize independent gates, but dependencies cannot be bypassed.

### LOCKED

QG-9 does not itself authorize release signing. It emits the MA-20 verdict consumed by MA-19 Release Authorization.

---

## 16. QG-0 — Candidate identity and supply-chain admission

### LOCKED

Qualification begins only after candidate identity is fixed and MA-19 reports the candidate/material set eligible for qualification.

Unknown composition blocks qualification.

### LOCKED

Qualification may use development/quarantined artifacts for exploratory testing, but only MA-19-admitted exact candidates can receive a production qualification verdict.

---

## 17. QG-1 — Build/static baseline

### LOCKED

Applicable release candidates undergo automated baseline checks appropriate to their languages/artifact classes, including where relevant:

- clean build success;
- compiler/type/static checks;
- dependency closure verification;
- secret-pattern checks;
- prohibited dynamic-loading/path-resolution checks;
- configuration/schema validation;
- deterministic/reproducibility checks claimed by MA-19;
- packaged-content manifest verification.

### LOCKED

Static-analysis findings are triaged; scanner silence is not proof of safety.

---

## 18. QG-2 — Unit/component/contract qualification

### LOCKED

Critical domain contracts receive direct tests at the narrowest practical level before full-system testing.

This includes, where applicable:

- Principal/Company/Agent identity invariants;
- AuthZ/capability attenuation/revocation;
- Action Assurance state transitions;
- durable Task/workflow transitions;
- evidence/provenance semantics;
- serialization/schema compatibility;
- storage/publication preconditions;
- audit/receipt rules;
- migration functions;
- broker boundary contracts;
- model/runtime adapter contracts.

### LOCKED

Code coverage is supporting evidence, not release authority by itself. Qualification Policy may set risk-based coverage floors, but a high coverage percentage cannot override missing security/reliability cases.

---

## 19. QG-3 — Integration/system/end-to-end qualification

### LOCKED

The exact packaged candidate is tested through production-equivalent process boundaries, not only through mocked unit interfaces.

### LOCKED

System qualification exercises at least:

- trusted startup/readiness ordering;
- Company creation/activation lifecycle;
- Agent provisioning/assignment/replacement;
- Task/delegation/review lifecycle;
- local model routing/fallback behavior;
- tool/plugin/MCP invocation paths;
- durable authoritative mutation through trusted services;
- user-resource publication through brokers;
- cancellation/retry/reconciliation paths;
- shutdown/restart/recovery;
- audit/receipt generation;
- security UX status truthfulness.

---

## 20. No mock-only security proof

### LOCKED

Mocks/simulators may support fast testing but cannot be the sole qualification proof for security properties enforced by real host/VMM/filesystem/service/key-provider mechanisms.

Real backend/system tests are required for the production matrix row that claims those guarantees.

---

## 21. QG-4 — Adversarial qualification

### LOCKED

Production qualification includes threat-model-driven adversarial testing of high-risk trust boundaries.

### LOCKED

The adversarial suite includes attempts, where applicable, to violate:

- Agent Appliance → host isolation;
- Agent → authoritative database isolation;
- Agent → other Agent boundary isolation;
- Company → other Company data isolation;
- untrusted workload → trusted control-plane IPC;
- Agent/tool → secret/key material isolation;
- Agent/tool → protected LAN/control-service network boundaries;
- Agent → host filesystem/resource publication constraints;
- untrusted plugin/MCP/browser → ambient host authority restrictions;
- stale Worker/token/capability fencing;
- approval/action-target binding;
- audit/receipt integrity;
- update/release trust metadata;
- path traversal/reparse/symlink/case/Unicode containment;
- dynamic-library/plugin substitution controls.

### LOCKED

Adversarial qualification tests enforcement, not a mathematical claim that exploitation is impossible.

---

## 22. Guest-root compromise assumption

### LOCKED

MA-01's hostile-workload assumption is executable qualification input:

> The Agent execution environment may be fully compromised up to guest-root level.

Qualification therefore includes scenarios in which the guest/Worker behaves maliciously rather than cooperatively.

### LOCKED

A backend cannot qualify merely because well-behaved Agent workloads remain contained.

---

## 23. Isolation escape / host-boundary tests

### LOCKED

For each FULL_LOCAL_AUTONOMY production backend matrix row, qualification must verify that the configured backend enforces the MA-01/MA-17 contract for:

- filesystem/mount isolation;
- control-channel access;
- network policy;
- device/GPU exposure policy;
- process/resource containment;
- force-stop/fencing;
- cross-Agent separation;
- host broker mediation.

### LOCKED

If hard outer-boundary enforcement cannot be proven for the row, the row cannot claim FULL_LOCAL_AUTONOMY; it may qualify only for a weaker explicitly named operating mode allowed by MA-17.

---

## 24. AuthZ and Action Assurance qualification

### LOCKED

MA-06 qualification includes negative-path proof that:

- default deny is enforced;
- organizational role alone does not grant ambient authority;
- Capabilities cannot broaden source authority;
- stale/revoked capabilities fail;
- high-impact actions require required approval;
- approval binds the intended action/target state;
- Agents cannot self-approve prohibited/high-risk effects;
- execution occurs through trusted brokers/services;
- success requires verified postcondition;
- constitutional prohibited actions remain unwaivable through ordinary approval.

---

## 25. Secret/credential qualification

### LOCKED

MA-10 qualification includes tests for:

- protected root-secret lifecycle;
- secret mediation/scope/expiry/revocation;
- no direct secret exposure to unauthorized Agent/model/tool contexts;
- redaction from logs/audit/support bundles;
- crash/dump/diagnostic policy behavior;
- missing/locked key behavior;
- rotation/recovery paths where implemented;
- no plaintext secret storage beside protected state.

### LOCKED

A release is vetoed if required production secrets are recoverable from ordinary untrusted workspace/log/telemetry paths contrary to MA-10.

---

## 26. Company isolation qualification

### LOCKED

Multi-Company configurations include explicit cross-Company negative tests for:

- database reads/writes;
- artifact retrieval/publication;
- knowledge/retrieval scope;
- audit/telemetry access;
- Agent/Task routing;
- secrets;
- tools/integrations;
- backup/restore scope.

Any unauthorized cross-Company disclosure or mutation is a hard release veto for the affected production scope.

---

## 27. Model/runtime qualification

### LOCKED

A discovered local model/runtime is not production-qualified merely because it loads or returns text.

Applicable model/profile qualification covers:

- artifact/runtime identity;
- required context/input/output contract;
- structured-output behavior where required;
- tool/function-call contract where applicable;
- refusal/failure behavior;
- no unapproved provider-hosted authority path;
- deterministic declared fallback behavior;
- local-only/no-cloud-final-runtime requirement;
- latency/resource envelope where required;
- safety/evidence behavior relevant to the profile.

### LOCKED

Model qualification does not make model output authoritative Company truth.

### LOCKED

A model/profile change may use impact-scoped qualification when core trusted bytes are unchanged, but the new exact model/runtime/profile cannot inherit a prior profile's passing evidence without declared equivalence and policy approval.

---

## 28. Tool/plugin/MCP qualification

### LOCKED

Trusted extensions and host-side helpers are qualified as executable code appropriate to their trust class.

Qualification verifies:

- registration/enablement separate from AuthZ;
- capability binding;
- sandbox/trust boundary;
- filesystem/network/secret scope;
- Action Assurance integration;
- update identity/provenance;
- failure containment;
- no ambient host privilege escalation.

### LOCKED

Untrusted Agent-local extension code does not require promotion into the trusted TCB, but the enclosing hostile-code boundary and brokers must be qualified against malicious extension behavior.

---

## 29. Browser/computer-use qualification

### LOCKED

Where browser/computer-use capability exists, qualification verifies that:

- browser content remains untrusted;
- downloaded content cannot self-promote into trusted execution;
- browser network authority matches policy;
- host UI automation, if present, uses separately qualified mediation;
- credentials/secrets are not exposed beyond authorized scope;
- external content cannot rewrite trusted instructions/policy.

---

## 30. QG-5 — Storage semantics qualification

### LOCKED

MA-17/MA-09 storage guarantees are qualified on the real filesystem/backend combination for the matrix row.

Tests include, where applicable:

- exclusive create;
- same-volume atomic replacement;
- no-replace semantics;
- durable flush behavior;
- directory/metadata durability;
- case/Unicode/path normalization;
- reparse/symlink/junction/mount containment;
- open-handle/descriptor identity checks;
- concurrent publication races;
- disk-full behavior;
- interrupted writes;
- corruption detection;
- publication receipt truthfulness.

### LOCKED

Atomic visibility, crash durability and content correctness are tested as separate properties.

---

## 31. Crash/power-loss qualification

### LOCKED

Consequential state transitions receive destructive fault-injection at architecture-defined cut points in disposable qualification environments.

Where applicable, inject:

- process kill;
- Worker/VMM kill;
- trusted-service crash;
- database interruption;
- host reboot/power-loss equivalent;
- disk-full/short-write conditions;
- lost/reordered wakeups;
- duplicate delivery/retry;
- network interruption for optional external effects;
- sleep/resume/session change.

### LOCKED

Qualification verifies after restart/reconciliation:

- no false success;
- no stale incarnation authority;
- no silent authoritative corruption;
- durable receipts/audit agree with known outcome;
- ambiguous external outcomes remain `UNKNOWN`/reconciled rather than invented;
- pending work is recovered/restarted according to MA-12.

---

## 32. False-success prohibition

### LOCKED

A consequential qualification scenario that reports success before the required postcondition is proven is a hard veto.

### LOCKED

Zero observed false-success events is required in the applicable release qualification evidence. One reproducible false-success defect keeps the affected gate failed until fixed and requalified.

---

## 33. Cancellation/retry/idempotency qualification

### LOCKED

Qualification covers:

- cancellation racing late completion;
- retry after unknown external outcome;
- duplicate operation keys;
- stale Worker result submission;
- checkpoint corruption;
- retry budget exhaustion;
- non-idempotent side-effect reconciliation.

The system must not turn process-level success/failure into incorrect Task/action truth.

---

## 34. Backup/restore qualification

### LOCKED

MA-13 backup claims are not release-qualified until restore has been exercised for the supported backup class/scope.

Applicable tests include:

- Backup Set integrity verification;
- encrypted recovery material handling;
- isolated restore;
- PostgreSQL/artifact consistency;
- Workspace non-authority;
- fresh runtime authority after restore;
- in-flight/external-effect reconciliation;
- corruption/quarantine behavior;
- promotion from isolated restore;
- partial-recovery refusal.

### LOCKED

An untested backup is not represented as proven recoverable.

---

## 35. RPO/RTO qualification

### LOCKED

When product policy declares RPO/RTO targets, MA-20 measures them under specified qualified workloads and recovery classes.

### LOCKED

RPO/RTO values are measured release/product policy values, not architecture promises invented without executable evidence.

---

## 36. Audit/observability/privacy qualification

### LOCKED

At minimum, MA-14 release qualification verifies:

- mandatory audit events for required transitions;
- crash/retry-safe receipt lifecycle;
- no success receipt before verified outcome;
- audit write protections;
- redaction/minimization of known secret classes;
- external telemetry disabled in final local-only default configuration;
- retention boundary enforcement;
- Company-scope isolation;
- observability degradation behavior;
- audit-store failure behavior;
- audit/receipt recovery under MA-13;
- tamper protection/detection;
- privacy-safe diagnostic bundle generation;
- mandatory audit/receipts are never sampled away.

### LOCKED

Required audit persistence failure causes the MA-14 fail-closed behavior to be tested directly for consequential actions.

---

## 37. Security/privacy diagnostic bundles

### LOCKED

Support/diagnostic bundle qualification uses seeded secret/private markers to verify that prohibited plaintext secret classes and unnecessary Company content are not silently exported.

A diagnostic path that bypasses the declared privacy policy is a release veto for that feature/scope.

---

## 38. QG-6 — First-install qualification

### LOCKED

Production release qualification includes **clean-machine installation** on each production host matrix family claimed for first install.

### LOCKED

Clean-machine qualification starts without developer build trees, developer Python/SDK environments, hidden package caches, undeclared runtimes, or prior SerapeumOS state unless the installation profile explicitly requires a declared host prerequisite.

### LOCKED

A clean-machine failure caused by an undeclared dependency blocks the affected release matrix row.

---

## 39. First-run/bootstrap qualification

### LOCKED

First-run qualification verifies:

- host capability probing;
- protected-root/service/account setup;
- root-secret/bootstrap handling;
- managed-state initialization;
- MA-19 trust-root/update metadata bootstrap;
- local-only startup;
- capability-derived product mode;
- accurate UX when prerequisites are missing/degraded/unknown.

---

## 40. Update-path qualification

### LOCKED

Every production-supported release transition has an explicit qualification edge.

A release cannot claim arbitrary upgrade from “any old version.”

### LOCKED

For each supported source → target transition, qualification covers:

- preflight;
- state-vector compatibility;
- required recovery anchor;
- quiescence/fencing;
- migration;
- activation;
- post-activation validation;
- commit/finalization;
- interruption/restart recovery;
- declared rollback class.

---

## 41. Migration qualification

### LOCKED

Each migration edge is tested from representative valid source states plus defined malformed/partial/corrupt boundary cases.

### LOCKED

Migration qualification verifies:

- preconditions;
- journal/checkpoint durability;
- transformation correctness;
- schema/data/artifact referential integrity;
- idempotent/restart-safe behavior where required;
- postconditions;
- backward-compatibility consequences;
- rollback/recovery classification;
- no silent data discard.

### LOCKED

Database major-version transitions are qualified as dedicated migrations, not assumed equivalent to ordinary executable replacement.

---

## 42. Rollback qualification

### LOCKED

The four MA-18 rollback classes are independently qualified where supported:

- RLB-1 activation rollback;
- RLB-2 reversible migration rollback;
- RLB-3 recovery-point rollback;
- RLB-4 forward-repair-only.

### LOCKED

Qualification must prove that the product refuses an invalid rollback rather than launching old code against an incompatible state vector.

### LOCKED

Automatic rollback is qualified only for explicitly predeclared safe rollback classes and cannot silently revert Company state with un-reconciled external effects.

---

## 43. Repair/reinstall/uninstall/purge qualification

### LOCKED

Maintenance qualification verifies that:

- repair restores trusted installation integrity without rewriting Company truth;
- missing root keys are not silently regenerated over encrypted state;
- reinstall does not overwrite ambiguous/existing managed state without the governed path;
- ordinary uninstall preserves durable Company state by default;
- destructive purge remains a separate high-risk operation;
- user-published external files are not treated as installation-owned cleanup targets.

---

## 44. QG-7 — Resource qualification

### LOCKED

Each production matrix row declares a **qualified host resource envelope** sufficient for the claimed product mode/workloads.

### LOCKED

Qualification stresses:

- CPU saturation;
- RAM pressure/OOM;
- disk capacity and I/O pressure;
- process/concurrency ceilings;
- Agent Appliance quotas;
- model residency/VRAM where applicable;
- queue/backpressure behavior;
- telemetry/diagnostic load;
- recovery reserve capacity.

### LOCKED

Resource scarcity may degrade/refuse work but must not weaken AuthZ, isolation, audit, recovery, secret handling or authoritative-state integrity.

---

## 45. Resource enforcement qualification

### LOCKED

A FULL_LOCAL_AUTONOMY backend qualifies only if required hard resource controls are enforced outside the untrusted process tree where MA-11 requires hard limits.

If a required hard limit cannot be enforced, the affected workload/mode is not qualified rather than silently using a soft best-effort limit.

---

## 46. Performance qualification

### LOCKED

Performance is evaluated under declared host/resource/workload profiles with versioned budgets.

### LOCKED

Qualification uses distribution/tail metrics where relevant; averages alone cannot hide unacceptable tail behavior.

### LOCKED

Performance regression is a release gate only where the Qualification Policy defines a budget or where degradation threatens security, reliability, resource availability or required product usability.

### LOCKED

A faster candidate never overrides a hard security/privacy/reliability failure.

---

## 47. Endurance / long-duration qualification

### LOCKED

Material production releases include long-duration/endurance qualification appropriate to the release risk surface.

Endurance exercises sustained and churn workloads such as:

- repeated Agent create/start/stop/replace cycles;
- long task queues;
- model load/unload/routing cycles;
- repeated publication/receipt/audit activity;
- backup cycles;
- restart/reconciliation cycles;
- storage growth/cleanup;
- optional network deny/recovery paths;
- sleep/resume where supported;
- repeated UI/control-plane interaction.

### LOCKED

The Qualification Policy defines minimum elapsed duration/workload counts per release class/profile. A failed endurance run cannot be shortened or reset to manufacture a pass.

### LOCKED

Endurance acceptance includes at least:

- zero architecture-invariant violations;
- zero unexplained trusted-plane crashes;
- zero authoritative corruption;
- zero false-success events;
- bounded resource growth/leak behavior within declared budgets;
- recoverable/reconciled transient failures.

---

## 48. Concurrency/race qualification

### LOCKED

High-risk concurrency paths receive race/interleaving qualification, including where applicable:

- task claim/lease/fencing;
- cancellation vs completion;
- capability revocation vs use;
- concurrent artifact publication;
- update/maintenance exclusivity;
- audit/receipt persistence;
- backup vs active writes;
- cleanup vs rollback retention;
- Agent assignment/replacement.

---

## 49. Fuzzing

### LOCKED

Fuzzing is required for security/reliability-sensitive parsers, serializers, protocol boundaries and untrusted-input processors where technically applicable.

### LOCKED

Fuzzing evidence records:

- harness identity;
- seed/corpus identity;
- run budget;
- crash/hang findings;
- deduplication/triage;
- regression cases promoted from confirmed defects.

### LOCKED

A fixed fuzz duration without findings does not prove the absence of vulnerabilities.

---

## 50. Historical regression cases

### LOCKED

Every confirmed material product defect that could recur should produce a durable regression case or stronger prevention mechanism where practical.

### LOCKED

Closed security/reliability defects are not removed from regression evidence merely because the original bug is old.

---

## 51. Security review and penetration/adversarial assessment

### LOCKED

Critical TCB, isolation, AuthZ, secret, update, storage and recovery changes require security-focused review appropriate to their impact in addition to ordinary automated tests.

### LOCKED

For material boundary changes, policy may require independent penetration/adversarial assessment. Manual review is structured evidence, not an undocumented confidence statement.

---

## 52. QG-8 — Host/platform qualification matrix

### LOCKED

Production support is expressed as explicit **Qualification Matrix Rows**, not generic OS marketing labels.

A row binds relevant dimensions such as:

```text
SerapeumOS release/candidate
product operating mode
host family/version/build class
CPU architecture/required virtualization capabilities
filesystem/storage topology
physical at-rest protection class
isolation backend + exact qualified version/build identity
privileged helper/driver identity where applicable
PostgreSQL/database-engine class/version
service/account/key-provider class
Agent Appliance image identity
local inference runtime/profile class where claimed
resource envelope
install/update/migration edge
qualification policy/evidence identity
```

### LOCKED

The matrix may define evidence-backed equivalence classes/ranges to avoid combinatorial explosion, but an equivalence class requires explicit rationale and cannot silently generalize from an unrelated tested point.

---

## 53. First production host family

### LOCKED

The first production qualification family remains MA-17's locked target:

- **Windows 11, x86-64**;
- locally attached fixed storage;
- qualified NTFS managed-state volume;
- required host secret/resource/isolation/service capabilities proven.

### LOCKED

QEMU/WHPX remains the primary Windows hostile-appliance qualification direction from MA-01/MA-17. The exact QEMU/backend build/version and host-build matrix row are implementation/actual-qualification selections, not architecture changes.

### LOCKED

Windows 11 support is not declared generically until actual matrix rows pass.

---

## 54. Linux qualification family

### LOCKED

Linux remains architecture-supported under MA-17.

The initial candidate family is:

- x86-64 Linux;
- KVM-capable host for hostile-Agent execution;
- qualified local ext4 or XFS managed-state storage;
- required service, IPC, resource, key and filesystem guarantees.

### LOCKED

Linux becomes production-supported only for specific/equivalent matrix rows that actually pass MA-20. Architectural support alone is not a release claim.

---

## 55. Non-baseline host families

### LOCKED

Windows ARM64, Linux ARM64, macOS, BSD/other hosts, ReFS as a general active-state baseline, network/cloud-sync active authoritative storage and other MA-17 non-baselines do not inherit qualification from Windows x86-64/NTFS or Linux x86-64/ext4/XFS.

They require new Host Compatibility Profiles and MA-20 matrix evidence before production support is claimed.

---

## 56. Host update staleness

### LOCKED

A material host change may stale qualification evidence.

Requalification/reprobe impact includes, where relevant:

- OS build/security update;
- kernel/hypervisor update;
- virtualization backend update;
- storage/filesystem driver/filter change;
- disk/controller/storage topology change;
- key-provider/security-subsystem change;
- privilege/service-account policy change;
- GPU/driver change where part of the claimed profile.

### LOCKED

SerapeumOS may define qualified host-version equivalence ranges only where evidence supports them. Unknown material host state fails closed to the applicable degraded mode until re-probed/requalified.

---

## 57. Clean-machine matrix qualification

### LOCKED

Each production first-install matrix family includes a clean-machine test image/host snapshot whose provenance/configuration is recorded.

### LOCKED

Qualification includes at least one path that does not reuse the developer's workstation state, local source checkout, build cache, developer PATH, or implicit credentials.

---

## 58. Minimum local-only qualification

### LOCKED

The final production candidate must prove core operation with external Internet/cloud services unavailable.

### LOCKED

Qualification verifies that NaraRouter, cloud CI, cloud signing, public package registries, hosted model APIs and external telemetry are not mandatory final runtime/release-verification dependencies.

---

## 59. Network-denial qualification

### LOCKED

For local-only production mode, denying external network access must not:

- weaken security controls;
- skip required local verification;
- disable authoritative state access;
- cause arbitrary provider fallback;
- corrupt queued work;
- falsely report external operations as successful.

Optional explicitly authorized integrations may become unavailable/degraded without invalidating the local core.

---

## 60. Release/change impact analysis

### LOCKED

Every candidate produces a **Qualification Impact Manifest** mapping changed materials/behavior to affected architecture domains, matrix rows, migration edges and required gates.

### LOCKED

Impact scope is based on effective behavior/dependency reachability, not only file count or diff size.

A one-line change to AuthZ, storage, isolation or release verification may require broader qualification than a large UI-only diff.

---

## 61. MA-15 change-class interaction

### LOCKED

MA-15 SE classes remain authoritative for evolution governance.

Qualification applies at least:

- **SE-0:** no production behavioral change; no executable release qualification unless packaged bytes/operational claims change;
- **SE-1:** bounded pre-authorized behavior may use policy-defined focused qualification;
- **SE-2:** affected-profile qualification plus independent review where MA-15 requires it;
- **SE-3:** full qualification of affected trusted-product/security surfaces; no autonomous promotion;
- **SE-4:** architecture/governance approval first, then qualification against the newly closed architecture; never autonomous.

### LOCKED

SE class never permits skipping a hard architecture veto.

---

## 62. Delta qualification

### LOCKED

SerapeumOS permits **delta/impact-scoped requalification** when prior evidence remains valid and unchanged dependencies/interfaces are demonstrably unaffected.

### LOCKED

Delta qualification requires:

- exact previous qualified baseline;
- exact diff/material changes;
- dependency/impact analysis;
- explicit retained-evidence justification;
- required regression subset;
- no stale affected evidence.

### LOCKED

“Small diff” alone is never sufficient justification for delta qualification.

---

## 63. Full requalification triggers

### LOCKED

Full or broad requalification is required when impact cannot be bounded safely or when foundational assumptions change, including material changes to:

- TCB/isolation backend;
- Principal/AuthZ/capability semantics;
- secret/root-key implementation;
- authoritative storage/database semantics;
- audit/receipt semantics;
- lifecycle activation/migration/rollback machinery;
- supply-chain trust/release-verification root;
- host compatibility contract;
- Agent Appliance base/kernel/runtime boundary;
- architecture/constitutional invariants.

---

## 64. Flaky tests

### LOCKED

A flaky required test is not treated as pass merely because one rerun succeeded.

### LOCKED

For each intermittent failure:

- preserve original failure evidence;
- classify environmental/test/product cause where possible;
- reproduce or bound the failure;
- fix the product/test/environment or record an eligible bounded exception;
- rerun the affected gate under controlled conditions.

### LOCKED

Unexplained flakiness in a hard security/reliability gate is `INCONCLUSIVE`/`FAIL`, not release-qualified.

---

## 65. Rerun discipline

### LOCKED

Reruns record reason, environment, seed/input identity and relationship to the prior run.

Automated “rerun until green” without retained failure history is prohibited for production qualification.

---

## 66. Randomized/probabilistic testing

### LOCKED

Randomized, fuzz, stress and concurrency tests record seeds/corpora/workload parameters sufficient for reproduction where technically possible.

### LOCKED

Qualification Policy defines repeat/budget requirements where statistical evidence is relevant; cherry-picking a favorable random run is prohibited.

---

## 67. Manual qualification evidence

### LOCKED

Manual tests/reviews may be required where automation is insufficient, but they produce structured evidence:

- test/review objective;
- candidate/environment identity;
- procedure;
- observed result;
- supporting artifact/log/screenshot where appropriate;
- reviewer identity/role;
- outcome/rationale.

Undocumented “looks good” is not release evidence.

---

## 68. Independent review

### LOCKED

Qualification Policy requires independent/higher-authority review for material security/TCB/release-trust changes and for exceptions that could materially affect release risk.

### LOCKED

Independence is organizational/logical: the reviewer cannot be satisfied solely by the same Agent/model/process that generated and self-scored the candidate.

---

## 69. Qualification exceptions

### LOCKED

Non-veto qualification deviations may be admitted only through an explicit bounded **Qualification Exception**.

It records:

```text
exception_id
failed/missing requirement
candidate/scope
risk rationale
why hard architecture invariants remain intact
compensating controls
approver(s)
expiry/review condition
affected matrix rows/features
follow-up obligation
```

### LOCKED

An exception does not rewrite the underlying test result from FAIL/NOT_RUN into PASS.

### LOCKED

Exceptions are visible in the final Qualification Evidence Bundle and Release Envelope.

---

## 70. Unwaivable hard vetoes

### LOCKED

Ordinary release approval/Owner convenience approval cannot waive a failure that defeats a locked architecture/security invariant.

Changing such an invariant requires MA-15 SE-4 architecture/governance change, new architecture closure as applicable, and requalification.

---

## 71. Hard release veto classes

### LOCKED

A production qualification verdict cannot be `QUALIFIED` for an affected scope when any of the following is true:

1. candidate bytes/material graph are unknown or do not match MA-19 identity;
2. a locked architecture/security invariant is violated;
3. a known unmitigated vulnerability materially defeats a locked security invariant;
4. hostile-Agent hard-boundary requirements are unproven for a claimed FULL_LOCAL_AUTONOMY row;
5. unauthorized cross-Company disclosure/mutation occurs;
6. unauthorized Agent/untrusted-code access to authoritative DB, root secrets or protected host authority occurs;
7. AuthZ/capability/approval bypass occurs;
8. a consequential action can report false success;
9. required audit/receipt persistence can be bypassed or silently omitted;
10. authoritative state can silently corrupt or use unverified corrupted bytes;
11. rollback/migration can launch incompatible code/state or silently lose protected Company data;
12. backup/restore claims rely on untested or inconsistent recovery behavior;
13. local-only production operation secretly requires an undeclared mandatory cloud/external service;
14. required resource isolation can fail open and weaken security/reliability guarantees;
15. required test/gate evidence is FAIL, INCONCLUSIVE, NOT_RUN, BLOCKED or STALE without an eligible non-veto exception;
16. qualification evidence is bound to different bytes/environment/transition than the release claim;
17. release/security-floor/anti-rollback verification can be bypassed;
18. a hard failure has been hidden by rerun, suppression or evidence deletion.

---

## 72. Release verdict states

### LOCKED

MA-20 produces explicit scoped verdicts such as:

```text
QUALIFIED
QUALIFIED_WITH_BOUNDED_EXCEPTION
NOT_QUALIFIED
INCONCLUSIVE
STALE
REVOKED
```

### LOCKED

The verdict is always scoped to candidate + qualification policy + matrix row(s) + state-transition claims.

There is no unscoped universal `SUPPORTED` verdict.

---

## 73. QUALIFIED_WITH_BOUNDED_EXCEPTION

### LOCKED

This verdict is permitted only where:

- the failed/deferred item is explicitly exception-eligible;
- no hard veto/invariant is violated;
- risk/compensating controls are recorded;
- authority requirements are met;
- scope and expiry are bounded;
- the exception is visible to MA-19 Release Authorization.

### LOCKED

Security-critical boundary failures are not made exception-eligible merely because release is urgent.

---

## 74. Release readiness is evidence, not a percentage

### LOCKED

SerapeumOS does not reduce release readiness to one scalar score that can trade hard failures against many passing tests.

Dashboards may summarize coverage/progress, but gate verdicts and vetoes remain explicit.

---

## 75. Release Qualification Receipt

### LOCKED

QG-9 emits a durable **Release Qualification Receipt** containing at least:

```text
qualification_receipt_id
candidate/release subject digests
qualification_policy_id/version
architecture contract versions
matrix rows / operating modes
migration/update edges covered
Evidence Bundle identity/digest
verdict
exceptions
review authority
issued_at evidence
staleness/requalification conditions
```

### LOCKED

The Receipt is the MA-20 object referenced by the MA-19 Release Envelope.

---

## 76. Release Authorization separation

### LOCKED

MA-20 qualification does not itself sign/authorize the production Release Envelope.

The sequence remains:

```text
MA-19 candidate/provenance admission
→ MA-20 exact-candidate qualification
→ MA-20 Release Qualification Receipt
→ MA-19 Release Authorization binds that evidence to exact payloads
→ MA-18 lifecycle admission/activation
```

### LOCKED

Release Authorization cannot reuse a passing MA-20 receipt for materially different bytes, state transitions or matrix rows.

---

## 77. Release channels

### LOCKED

Development, qualification/RC and production are separate states/channels.

### LOCKED

An RC may reuse its qualification evidence for production only if the production payload subject bytes and required policy/matrix claims are identical and no evidence has become stale. Rebuilding/repackaging changed subject bytes requires a new binding/requalification as applicable.

---

## 78. Emergency security releases

### LOCKED

Emergency status changes sequencing/priority, not trust authority.

An emergency release still requires:

- MA-19 identity/provenance;
- no architecture-invariant hard veto;
- minimum MA-20 qualification for the changed/affected risk surface;
- explicit impact analysis;
- MA-19 Release Authorization;
- MA-18 safe activation/recovery path.

### LOCKED

Policy may defer non-safety/non-security breadth only through a bounded visible emergency exception with follow-up obligation. It cannot defer the gates required to prove that the emergency fix itself does not violate locked security/recovery invariants.

---

## 79. Post-release monitoring does not rewrite qualification history

### LOCKED

A release may have been validly qualified at time T and later become unsafe because of new vulnerability/host/field evidence.

Qualification history remains immutable; current admissibility/support state may become `STALE` or `REVOKED`.

---

## 80. Qualification revocation/staleness triggers

### LOCKED

Material post-qualification evidence triggers impact review and may stale/revoke affected verdicts, including:

- newly confirmed architecture-breaking vulnerability;
- compromised release/signing/build root;
- materially changed host/backend behavior;
- field evidence contradicting a qualified guarantee;
- qualification-tool defect invalidating evidence;
- discovered hidden dependency/material mismatch;
- migration/recovery defect affecting supported edges;
- model/runtime regression affecting a qualified profile.

### LOCKED

MA-19 security-floor/revocation mechanisms may then block future installation/activation of an otherwise authentic old release.

---

## 81. Post-release defect handling

### LOCKED

Confirmed production defects are classified against the architecture/risk surface and feed:

```text
field evidence
→ incident/problem record
→ regression fixture/test
→ remediation candidate
→ MA-15 governed change
→ MA-19 provenance
→ MA-20 requalification
→ MA-18 controlled update
```

No field defect grants an Agent direct hot-patch authority over trusted production code.

---

## 82. Qualification retention

### LOCKED

Qualification evidence is retained long enough to reconstruct why a supported/retired release was admitted, rejected, excepted or revoked, subject to MA-13/MA-14 retention/privacy policy.

### LOCKED

Raw evidence containing sensitive data is minimized/redacted and does not become hidden Company knowledge.

---

## 83. Evidence privacy

### LOCKED

Qualification harnesses must not require secret leakage or uncontrolled copying of Company content into reports.

When production-like data is necessary, use synthetic/minimized/local datasets or separately governed sanitized captures.

---

## 84. Qualification resource isolation

### LOCKED

Destructive/adversarial/fuzz/stress qualification runs execute in disposable/local controlled environments appropriate to the risk; they do not use the Owner's only production Company state as a test fixture.

### LOCKED

Tests that intentionally corrupt disks/state, kill services or exercise malware-like payloads are fenced from production data and ordinary user assets.

---

## 85. Architecture-domain traceability

### LOCKED

The Qualification Policy maintains traceability from locked architecture requirements/vetoes to executable/manual evidence families.

### LOCKED

A requirement with no feasible verification method is surfaced as a design/qualification blocker rather than silently assumed true.

---

## 86. Requirement-to-test coverage is not code coverage

### LOCKED

SerapeumOS distinguishes:

- source/code coverage;
- architecture requirement coverage;
- threat-model coverage;
- matrix/environment coverage;
- migration-edge coverage;
- failure-mode coverage.

A release may have high code coverage and still fail qualification because a critical requirement/threat/matrix edge lacks evidence.

---

## 87. No test-to-implementation backdoor

### LOCKED

Qualification code/harnesses cannot become an alternate production authority path.

Test-only bypasses, debug backdoors, fixture keys and diagnostic interfaces must not remain enabled in production payloads unless they are explicitly governed production features.

---

## 88. Build-type equivalence

### LOCKED

Security/reliability qualification uses the actual production build configuration or an evidence-proven equivalent.

A debug/instrumented build may supplement diagnosis but cannot be the sole proof if instrumentation materially changes security, timing, memory layout, optimization, packaging or dependencies.

---

## 89. Reproducibility qualification

### LOCKED

When MA-19 claims reproducible/verifiable payload properties, MA-20 executes the corresponding reconstruction/comparison evidence under the declared scope.

### LOCKED

A failed reproducibility claim blocks describing the release as reproducible; it does not automatically prove maliciousness, but the discrepancy must be explained/resolved under MA-19 before production release if policy requires reproducibility for that artifact class.

---

## 90. Loaded-module/runtime composition qualification

### LOCKED

Trusted-process qualification verifies that runtime-loaded modules/helpers match admitted composition and cannot be silently substituted through ambient PATH/current-directory/plugin-directory resolution contrary to MA-19.

---

## 91. Architecture/security UX qualification

### LOCKED

MA-16 security UX is qualified for semantic truthfulness, including:

- unqualified/degraded host modes are labeled accurately;
- permissions/approvals describe material effect/target;
- failures/unknown outcomes are not rendered as success;
- recovery/rollback consequences are disclosed;
- update candidate is not called trusted before qualification/authorization;
- dangerous purge/restore actions are distinct from ordinary maintenance;
- local-only/cloud-independent status is not misrepresented.

---

## 92. Accessibility/localization and security meaning

### LOCKED

Where UI localization/accessibility is provided, security-critical meaning must remain materially equivalent across supported presentation modes.

A localization/accessibility defect that changes the meaning of a high-impact approval or recovery warning is release-significant.

---

## 93. Unsupported configurations

### LOCKED

Qualification defines explicit failure behavior for unsupported/unknown configurations.

The product must degrade/refuse according to MA-17 rather than silently claim production support.

### LOCKED

User override cannot convert an unqualified hard-security host/backend row into FULL_LOCAL_AUTONOMY support.

---

## 94. Minimum production release evidence

### LOCKED

A normal production release cannot enter MA-19 Release Authorization until applicable required gates are complete and the Qualification Evidence Bundle contains:

- exact candidate identity;
- MA-19 admission reference;
- all required gate verdicts;
- supported matrix rows/modes;
- migration/rollback edges claimed;
- hard-veto evaluation;
- open exception list;
- security/adversarial summary;
- reliability/recovery summary;
- resource/endurance summary where required;
- clean-machine evidence for claimed first-install families;
- reviewer/Qualification Authority verdict;
- staleness conditions.

---

## 95. No release by deadline pressure

### LOCKED

Schedule, sunk cost, demo success, user-visible feature importance, executive urgency or “almost all tests pass” cannot override a hard release veto.

---

## 96. Qualification failure behavior

### LOCKED

When a candidate fails qualification:

- production activation is blocked for the failed scope;
- evidence is preserved;
- failure is classified/triaged;
- candidate may return to development/remediation;
- a new/repaired candidate receives a new exact identity as required;
- affected qualification is rerun;
- no prior production baseline is silently destroyed.

---

## 97. Inconclusive behavior

### LOCKED

`INCONCLUSIVE` means the required property has not been proven.

It may trigger more instrumentation, a better fixture, additional environment control or a design change, but it cannot be treated as a pass for a required gate.

---

## 98. Release readiness dashboard semantics

### LOCKED

A release-readiness view may summarize:

- gates passed/failed/inconclusive/not run;
- matrix rows qualified;
- migration edges qualified;
- exceptions;
- stale evidence;
- unresolved defects;
- current release verdict.

### LOCKED

The dashboard derives from authoritative qualification records and does not itself become qualification authority.

---

## 99. Final Master Architecture interaction

### LOCKED

MA-20 closure completes the **MA-01 → MA-20 architecture-domain sequence** only.

It does not skip the master framework's remaining architecture gate steps:

```text
MA-20 closure
→ Final cross-domain consistency audit
→ Fresh-agent reconstruction validation
→ Final Master Architecture Gate PASS
→ Implementation task decomposition
→ Kilo execution-agent activation
→ Controlled implementation
→ Actual qualification
→ Release preparation
```

---

## 100. Final cross-domain consistency audit prerequisite

### LOCKED

After MA-20 is persisted, the next architecture action is a read-only cross-domain audit of MA-01→MA-20 for:

- contradictions;
- duplicated/competing authorities;
- unresolved ownership gaps;
- inconsistent state vocabulary;
- incompatible handoffs;
- missing architecture-to-qualification traceability;
- accidental cloud/proprietary production dependencies;
- weakened fail-closed behavior;
- inconsistent release/install/qualification sequencing.

No implementation begins merely because MA-20 itself is closed.

---

## 101. Fresh-agent reconstruction remains mandatory

### LOCKED

After the cross-domain audit and repository persistence, a fresh execution agent with no prior chat context must reconstruct the architecture/project state from repository content under the master framework.

Failure means documentation/architecture persistence must be repaired before implementation.

---

## 102. Concrete values intentionally below architecture

### LOCKED

The following are versioned implementation/qualification-policy values beneath the closed MA-20 architecture, not unresolved architecture questions:

| Value | Owner |
|---|---|
| exact Windows 11 builds supported | actual MA-20 qualification matrix |
| exact QEMU/WHPX build/version | implementation + MA-19 + actual MA-20 |
| exact Linux distro/kernel/KVM matrix | actual MA-20 qualification matrix |
| exact PostgreSQL version/build | implementation + MA-19 + actual MA-20 |
| exact ext4/XFS/NTFS host configuration ranges | actual MA-20 qualification matrix |
| exact model/runtime/profile list | MA-07 implementation + MA-19 + actual MA-20 |
| exact CPU/RAM/GPU/disk minimums | PREREQUISITES + Qualification Policy + evidence |
| exact stress/fuzz iteration budgets | Qualification Policy |
| exact soak/endurance durations | Qualification Policy |
| exact performance budgets | Qualification Policy/product policy |
| exact code/branch coverage thresholds | Qualification Policy by risk/component class |
| exact vulnerability severity SLA thresholds | MA-19 security policy + Qualification Policy |
| exact penetration-test cadence | Qualification Policy/release risk class |
| exact test frameworks/scanners/fuzzers | implementation + MA-19 provenance |
| exact evidence file/schema serialization | implementation |
| exact manual reviewer roster | project/release governance |
| exact evidence retention periods | MA-13/MA-14 product policy |

---

## 103. MA-20 veto conditions

An MA-20 implementation/qualification process is invalid if it:

- treats architecture closure as executable qualification;
- qualifies semantic version names instead of exact candidate bytes;
- lets candidate generators/Agents/models self-authorize production qualification;
- treats `INCONCLUSIVE`, `NOT_RUN`, `BLOCKED` or `STALE` as pass;
- deletes failing history after rerun;
- uses “rerun until green” as release policy;
- lets high aggregate pass counts override a hard veto;
- waives locked architecture/security invariants through ordinary approval;
- claims generic Windows/Linux support from one unbounded smoke test;
- uses mocks as sole proof of real host/VMM/filesystem security enforcement;
- claims hostile-code containment without malicious/guest-root scenarios;
- omits clean-machine install qualification for a claimed first-install family;
- claims migration/rollback support for untested source→target edges;
- treats untested backups as proven recoverable;
- treats code coverage as a substitute for threat/requirement/matrix coverage;
- treats fuzzing without findings as proof of safety;
- lets unqualified tool/harness changes silently alter pass semantics;
- permits a production payload to differ materially from the qualified payload;
- hides qualification exceptions from Release Authorization;
- allows emergency release status to bypass invariant-critical gates;
- requires cloud infrastructure for routine final qualification verification;
- uses private production Company state as the only destructive-test fixture;
- creates a test/debug backdoor that survives into production without governance;
- allows a material host change to retain qualification silently when evidence is stale;
- reports release readiness before MA-19 Release Authorization and MA-18 activation gates are separately satisfied.

---

## 104. MA-20 closure decision

### CLOSED

MA-20 is architecture-complete.

Locked:

- architecture closure explicitly separated from actual executable qualification;
- exact candidate + state transition + matrix-row qualification binding;
- logical Qualification Authority distinct from build/candidate/release/activation authorities;
- durable versioned Qualification Policy;
- explicit evidence states with inconclusive/not-run/stale not treated as pass;
- append-oriented failure/rerun history;
- durable Qualification Evidence Bundle;
- provenance/version identity for release-deciding qualification tooling/fixtures;
- candidate-generation/holdout/reviewer separation;
- QG-0→QG-9 release-gate graph;
- static/component/integration/system qualification taxonomy;
- threat-model-driven adversarial qualification;
- guest-root hostile-workload scenarios;
- hard-boundary/AuthZ/secret/Company-isolation qualification;
- model/runtime/tool/plugin/browser qualification by trust class;
- real storage atomicity/durability/path-semantics qualification;
- destructive crash/fault/power-loss qualification;
- hard false-success prohibition;
- retry/cancel/idempotency/reconciliation qualification;
- backup/restore/DR and measured RPO/RTO qualification;
- mandatory audit/privacy/redaction/fail-closed qualification;
- clean-machine/first-run/install/update/migration/rollback/repair/uninstall qualification;
- resource hard-limit/stress/performance/endurance/concurrency qualification;
- fuzzing and historical regression fixture governance;
- explicit host/backend/storage/resource Qualification Matrix;
- Windows 11 x86-64 + NTFS first production qualification family retained;
- Linux x86-64/KVM/ext4-or-XFS remains separate candidate family requiring actual evidence;
- non-baseline hosts do not inherit qualification;
- host-change staleness and reprobe/requalification;
- local-only/no-mandatory-cloud qualification;
- Qualification Impact Manifest and evidence-backed delta qualification;
- MA-15 SE-class interaction without weakening vetoes;
- flaky-test/rerun/randomized-test discipline;
- structured manual evidence and independent review;
- bounded visible exceptions only for non-veto requirements;
- unwaivable architecture/security vetoes;
- explicit scoped verdict states;
- Release Qualification Receipt consumed by MA-19;
- release authorization remains separate from qualification;
- emergency-release minimum gates;
- immutable qualification history plus post-release staleness/revocation;
- architecture requirement/threat/matrix/migration/failure-mode traceability;
- no scalar readiness score overriding hard gates;
- MA-20 closure followed by cross-domain consistency audit, fresh-agent reconstruction and Final Master Architecture Gate before implementation.

No material MA-20 architecture question remains inside this domain.

---

## 105. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-238 — Architecture closure and executable qualification are separate states
MA-20 closure completes the qualification architecture only; no product/backend/release is qualified until the implemented exact candidate later executes the required evidence suite.

### D-239 — Qualification binds exact candidate, transition and environment scope
A passing verdict is bound to exact candidate digests, Qualification Policy, matrix row/resource profile and migration/state-transition claims; it cannot be reused for materially different bytes or contexts.

### D-240 — Qualification Authority is independent of candidate/build/release authority
Agents/models/candidate generators and ordinary build processes cannot self-declare production qualification. MA-20 emits evidence; MA-19 Release Authorization remains separate.

### D-241 — Qualification Policy is durable and versioned
Required gates, matrices, thresholds, evidence quality, exceptions, vetoes and requalification triggers are versioned policy; threshold changes cannot retroactively manufacture a pass.

### D-242 — Inconclusive/not-run/stale evidence is not pass
Required evidence must be explicitly PASS or covered by a legitimate non-veto applicability/exception rule; uncertainty fails closed.

### D-243 — Failure and rerun history is preserved
Passing reruns do not erase earlier failures; rerun-until-green without retained evidence is prohibited.

### D-244 — Production qualification uses a QG-0→QG-9 gate graph
Candidate identity, static/component/system, adversarial, recovery, lifecycle, resource/endurance, host-matrix and final evidence-review gates are separate and ordered by dependency.

### D-245 — Real security mechanisms require real qualification
Mocks may supplement tests but cannot be the sole proof of VMM, filesystem, key-provider, service, storage or other real host-enforced security properties.

### D-246 — Hostile Agent qualification assumes guest-root compromise
FULL_LOCAL_AUTONOMY backend qualification includes malicious guest/Worker scenarios and must prove the MA-01/MA-17 containment contract, not merely cooperative workload operation.

### D-247 — False success is a hard release veto
A consequential action that can report success before its required postcondition is proven blocks the affected production qualification until fixed/requalified.

### D-248 — Storage guarantees are independently qualified
Atomic visibility, crash durability, content correctness, path containment and concurrency behavior are distinct tested properties on each claimed host/filesystem family.

### D-249 — Backup claims require restore proof
An untested Backup Set is not represented as proven recoverable; supported recovery paths are exercised in isolation with integrity/reconciliation evidence.

### D-250 — Update/migration/rollback support is edge-specific
Every claimed source→target transition and rollback class has explicit qualification evidence. There is no generic “upgrade/rollback from any version” claim.

### D-251 — Clean-machine qualification prevents hidden developer dependencies
Every claimed first-install production family is tested from a controlled clean host without undeclared developer state/caches/runtimes/credentials.

### D-252 — Resource scarcity must fail safe under stress
Stress/OOM/disk/concurrency/endurance qualification proves that scarcity cannot broaden authority, weaken isolation/audit/recovery, expose secrets or corrupt authoritative state.

### D-253 — Endurance is a release evidence class
Material releases execute policy-defined long-duration/churn workloads; zero architecture-invariant violations, false success, authoritative corruption and unexplained trusted-plane crashes are required for the applicable endurance gate.

### D-254 — Qualification Matrix rows define production support
Windows/Linux support is claimed only for evidence-backed host/backend/filesystem/resource/mode rows or justified equivalence classes; architecture support alone is not release support.

### D-255 — Windows 11 x86-64/NTFS is the first qualification family
The first production family remains Windows 11 x86-64 on qualified local fixed NTFS storage, with exact OS/backend versions selected and proven during actual qualification.

### D-256 — Linux remains separately qualified
Linux x86-64/KVM with qualified ext4/XFS remains architecture-supported but becomes production-supported only for matrix rows that independently pass MA-20.

### D-257 — Material host changes can stale qualification
OS/kernel/backend/storage/key-provider/driver and other material host changes trigger reprobe and impact-based requalification rather than inheriting support silently.

### D-258 — Final production qualification proves local-only operation
Core production operation and release verification must function without mandatory cloud inference, NaraRouter, public registries, hosted signing/transparency, external telemetry or other hidden cloud dependencies.

### D-259 — Delta qualification requires evidence-backed impact analysis
Prior evidence may be retained only when exact baseline/diff/dependency impact proves unaffected claims remain valid; diff size alone is not authority.

### D-260 — Flaky hard-gate behavior is not a pass
Unexplained intermittent failure in required security/reliability gates remains FAIL/INCONCLUSIVE until resolved or, only for non-veto items, covered by a bounded visible exception.

### D-261 — Qualification exceptions cannot waive constitutional/security invariants
Exceptions are scoped, justified, visible and expiring; hard architecture/security vetoes require architecture/governance change and requalification, not ordinary waiver.

### D-262 — Release readiness is multidimensional gate evidence
No scalar score or pass percentage can trade many successful tests against one hard veto.

### D-263 — MA-20 emits a Release Qualification Receipt
The Receipt binds exact candidate, policy, matrix rows, transition claims, Evidence Bundle, verdict, exceptions and staleness conditions and is referenced by MA-19 Release Authorization.

### D-264 — Post-release evidence may stale/revoke current qualification without rewriting history
A release can remain historically qualified at time T while new vulnerability/host/field evidence changes current admissibility/support and triggers security-floor/revocation action.

### D-265 — MA-20 closure does not start implementation automatically
After MA-20 persistence, the required next steps remain Final cross-domain consistency audit, fresh-agent reconstruction validation and Final Master Architecture Gate PASS before implementation decomposition/agent activation.

---

## 106. Project-state transition

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
MA-17 — CLOSED
MA-18 — CLOSED
MA-19 — CLOSED
MA-20 — CLOSED

Final Master Architecture sequence:
MA DOMAIN CLOSURE — COMPLETE
FINAL CROSS-DOMAIN CONSISTENCY AUDIT — NEXT
FRESH-AGENT RECONSTRUCTION VALIDATION — PENDING
FINAL MASTER ARCHITECTURE GATE — PENDING

Implementation:
NOT STARTED

Executable qualification:
NOT RUN

Runtime prototypes:
PAUSED

Repository persistence:
PENDING
```

---

## 107. Next action

**FINAL CROSS-DOMAIN CONSISTENCY AUDIT — MA-01 → MA-20**

Architecture/read-only.

No product implementation.
No runtime prototype.
No release qualification execution.

---

## Appendix A — Non-normative grounding

The MA-20 architecture is implementation-neutral but is grounded in established software-assurance practice:

- **NIST IR 8397 — Guidelines on Minimum Standards for Developer Verification of Software** recommends threat modeling, automated testing, static scanning, secret heuristics, built-in protections, black-box testing, structural/code-based testing, historical regression cases, fuzzing, web scanning where applicable, and verification of included code. MA-20 adopts these as evidence families without treating any one technique as sufficient proof.  
  https://csrc.nist.gov/pubs/ir/8397/final

- **NIST SP 800-218 — Secure Software Development Framework (SSDF) v1.1** remains the current final SSDF publication; a v1.2 revision is still draft as of this architecture closure. MA-20 uses SSDF principles for release verification, vulnerability handling and evidence discipline while not depending on a draft becoming final.  
  https://csrc.nist.gov/pubs/sp/800/218/final

- **OWASP ASVS 5.0.0** provides versioned verification requirements and illustrates the value of stable requirement identifiers and explicit verification claims. SerapeumOS is not limited to web applications, so ASVS is supporting security-verification grounding rather than the complete SerapeumOS qualification standard.  
  https://owasp.org/www-project-application-security-verification-standard/

- **SLSA v1.2 / MA-19 provenance** informs MA-20's exact-candidate evidence binding: executable qualification must apply to the same subject digests whose source/build provenance is admitted for release.  
  https://slsa.dev/spec/v1.2/

These references are grounding only. The normative SerapeumOS architecture is the LOCKED/CLOSED content above.
