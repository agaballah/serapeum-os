# MA-13 — Backup / Restore / Quarantine / Disaster Recovery

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-13 defines how SerapeumOS protects and reconstructs durable Company state after loss, corruption, compromise, storage failure, catastrophic update failure, or host replacement.

It governs:

- backup scope;
- backup-set consistency;
- backup manifests and integrity;
- recovery-key separation;
- restore authority;
- restore staging and validation;
- quarantine;
- corruption handling;
- disaster-recovery states;
- promotion back to active operation.

MA-13 does not define normal process retry/restart, detailed retention periods, host-specific backup tools, installer migration mechanics, or numerical RPO/RTO targets.

---

## 2. Boundary with MA-12

### LOCKED

MA-12 and MA-13 solve different failure classes.

### MA-12 — Operational recovery

Recovers from normal runtime/process failures using the **current live authoritative state**.

Examples:

- Worker crash;
- model runtime crash;
- stale lease;
- lost wakeup;
- interrupted Task;
- ordinary host reboot.

### MA-13 — Catastrophic recovery

Recovers when current live authoritative state is unavailable, corrupted, compromised, or intentionally rolled back.

Examples:

- disk loss;
- PostgreSQL corruption;
- Artifact Store loss;
- ransomware;
- unrecoverable installation failure;
- catastrophic update/migration failure;
- host replacement.

### LOCKED

A normal runtime crash must not cause backup rollback while healthy current authoritative state exists.

---

## 3. Existing foundation storage facts

### REPOSITORY FACT

The inherited Ankole deployment model separates:

- Control Plane ownership of durable state;
- PostgreSQL durable state;
- persistent `/agents` Agent Home storage;
- Worker runtime execution.

### LOCKED

SerapeumOS backup architecture therefore protects these persistent classes according to their authority established by MA-09.

A backup is not valid merely because directories were copied.

---

## 4. Recovery objective

### LOCKED

> The goal of recovery is to restore the newest **trusted, self-consistent, verifiable state that policy allows**, not to recover the maximum number of bytes at any cost.

Recovery correctness outranks recency.

A newer corrupted/inconsistent backup is not preferred over an older verified consistent recovery point.

---

## 5. Backup classes

### LOCKED

SerapeumOS defines these conceptual backup classes:

| Class | Content | Recovery importance |
|---|---|---|
| **B0 — Authoritative Database** | PostgreSQL authoritative relational state | mandatory |
| **B1 — Managed Artifacts** | MA-09 immutable Artifact Store payloads | mandatory for referenced durable artifacts |
| **B2 — Agent Workspaces** | protected `/agents/<agent_uid>` continuity state | protected continuity data |
| **B3 — Configuration / Reconstruction Metadata** | qualified configuration, manifests, schema/product versions, non-secret reconstruction state | mandatory as required |
| **B4 — Recovery/Cryptographic Metadata** | key versions, recovery-key references, encrypted recovery metadata | mandatory where required |
| **B5 — Audit / Receipt State** | protected audit/receipts when physically separate from B0/B1 | mandatory according to MA-14 policy |

---

## 6. State normally excluded from backup authority

### LOCKED

The following are normally rebuilt rather than treated as authoritative backup content:

- embeddings;
- search indexes;
- retrieval chunks where derivable;
- caches;
- model context packs;
- temporary previews;
- ephemeral runtime files;
- active process memory;
- Worker/appliance instances;
- active runtime leases;
- temporary runtime credentials;
- disposable `/tmp`/runtime state.

They may be included for convenience, but restore correctness must not depend on them where they are defined as rebuildable.

---

## 7. Model/runtime assets

### LOCKED

Local model artifacts, runtime binaries, VM/appliance images, and extension packages are **qualified installation/supply-chain assets**, not Company authoritative truth.

They may be included in an offline recovery package for convenience and reproducibility.

Their integrity and provenance are governed by MA-18/MA-19.

A Company-data backup remains conceptually distinct from an installation/runtime distribution backup.

---

## 8. Backup set

### LOCKED

A **Backup Set** is a named, immutable recovery point consisting of:

```text
Backup Manifest
+ B0 Database snapshot/backup
+ required B1 Artifact payloads
+ protected B2 Workspace snapshot(s)
+ required B3 reconstruction metadata
+ required B4 recovery metadata
+ required B5 audit/receipt material
```

A Backup Set has one stable recovery-point identity.

---

## 9. Backup manifest

### LOCKED

Every Backup Set requires a manifest containing enough information to verify and reconstruct the set.

It must be able to record:

- backup-set identity;
- creation time;
- installation identity;
- Company scope(s);
- SerapeumOS product/schema version;
- database backup identity/version;
- Artifact Store snapshot/generation information;
- Workspace snapshot information;
- backup component inventory;
- per-component integrity digest(s);
- backup format/version;
- encryption/key version references;
- completion state;
- validation state;
- parent/base backup where incremental methods are used.

Exact format is implementation design.

---

## 10. Backup completion state

### LOCKED

A Backup Set is not usable merely because backup creation started.

Conceptual states:

```text
CREATING
→ VERIFYING
→ COMPLETE
→ VERIFIED

or

FAILED
QUARANTINED
SUPERSEDED
```

Only a complete, policy-valid backup can become an approved recovery point.

---

## 11. Database + Artifact Store consistency

### LOCKED

The authoritative relationship between PostgreSQL metadata and MA-09 Artifact payloads must be recoverable to a self-consistent state.

A recovery point must not produce:

```text
live DB reference
→ missing or wrong Artifact bytes
```

### LOCKED

Backup construction must use a coordinated method such as:

- consistent DB snapshot plus matching immutable Artifact generation;
- transactionally recorded backup generation/epoch;
- database backup followed by verified inclusion of all referenced immutable payloads;
- another implementation that proves equivalent consistency.

MA-13 locks the consistency requirement, not one backup tool.

---

## 12. Artifact immutability simplifies recovery

### LOCKED

Because committed MA-09 Artifact payloads are immutable, backup systems may safely reuse/deduplicate previously backed-up identical content.

However:

- metadata/provenance relationships remain part of the recovery point;
- content deduplication must not merge distinct Artifact identities;
- missing referenced content invalidates the affected recovery point.

---

## 13. Workspace consistency

### LOCKED

`/agents` is durable but non-authoritative.

Therefore Workspace backup must preserve continuity data, but Workspace state cannot override restored authoritative PostgreSQL/Artifact state.

### LOCKED

A Workspace snapshot should record its relationship to the Backup Set/recovery time.

After restore:

- authoritative DB projections win;
- projected `SOUL.md`, `MISSION.md`, `DESIGN.md` may be regenerated;
- inconsistent/suspect Workspace content is quarantined or selectively reconciled;
- Workspace files never rewrite authoritative truth automatically.

---

## 14. Backup quiescence

### LOCKED

Backup may use either:

- bounded write quiescence;
- storage-native consistent snapshots;
- online transactional snapshot techniques;
- immutable-generation techniques.

The architecture does **not** require shutting down the whole Company for every backup.

### LOCKED

If consistency cannot be proven online, the trusted system must quiesce the affected mutation paths rather than create an untrustworthy recovery point.

---

## 15. Incremental backups

### LOCKED

Full and incremental/differential backup strategies are both permitted.

Incremental recovery chains must be:

- integrity verifiable;
- complete;
- dependency traceable;
- test-restorable.

A missing chain component invalidates that recovery path.

The product must not present an incomplete chain as a valid recovery point.

---

## 16. Backup integrity

### LOCKED

Backup components and manifests use strong cryptographic integrity verification.

At minimum:

- component size/inventory;
- strong digest;
- manifest integrity relationship.

Where authenticity against hostile tampering is required, signing/MAC mechanisms may be added under MA-10/MA-19.

### LOCKED

Integrity failure moves the affected backup into quarantine/rejection.

---

## 17. Backup immutability

### LOCKED

Completed Backup Sets are treated as immutable.

Correction creates a new Backup Set or explicitly supersedes the bad set.

A backup must not be silently edited after verification while retaining the same trusted recovery identity.

---

## 18. Backup authority

### LOCKED

Backup creation, retention, deletion, and restore are trusted operations.

Agents may:

- request;
- recommend;
- report;
- assist with analysis.

Agents cannot directly:

- alter verified backup contents;
- delete protected recovery points;
- restore arbitrary state over the live Company;
- access recovery keys;
- mark an unverified backup trusted.

---

## 19. Backup isolation

### LOCKED

Authoritative backups are outside normal Agent write authority.

They are not mounted read-write into hostile Agent Appliances.

If backup content needs inspection, access occurs through a trusted recovery/quarantine workflow.

This prevents a compromised Agent from corrupting both live state and recovery state.

---

## 20. Local / offline recovery doctrine

### LOCKED

SerapeumOS disaster recovery does not require cloud storage or a hosted backup service.

Supported recovery architecture must permit local/offline backups.

Potential targets may include:

- local secondary storage;
- external/removable storage;
- Owner-controlled network storage;
- another qualified local target.

Exact supported targets belong to MA-17/MA-18.

### LOCKED

Optional Owner-selected cloud storage may only exist later as a replaceable external integration if consistent with Owner policy; it cannot become required architecture.

---

## 21. Backup target trust

### LOCKED

Backup destination is treated separately from backup content integrity.

A target may be:

- online;
- offline;
- removable;
- read-only/immutable;
- physically separate.

### LOCKED

SerapeumOS should support at least one recovery mode whose trusted backup is not continuously writable by the normal live system.

This protects against ransomware, operator error, and live-system compromise.

Exact medium is not locked.

---

## 22. Backup encryption

### LOCKED

Backups containing sensitive Company data or encrypted credential material must support encryption at rest according to policy.

Backups moved outside the protected installation storage boundary require qualified encryption unless policy explicitly permits otherwise.

Exact cipher/container/tooling is implementation choice subject to MA-10/MA-19.

---

## 23. Root/recovery key separation

### LOCKED

The MA-10 installation root secret must **not** be stored in plaintext inside the same Backup Set that contains the encrypted data it protects.

Conceptually:

```text
Backup Set
        +
separately protected Recovery Key/Material
        =
recoverable protected installation
```

### LOCKED

Backup data and recovery-key material are separate trust channels.

Compromise of only the backup medium should not automatically expose protected credential plaintext.

---

## 24. Recovery-key design

### LOCKED

SerapeumOS must define a recoverable root-key strategy before release.

It may use:

- wrapped recovery key;
- Owner-held recovery material;
- host-bound key plus exportable recovery wrapping;
- another qualified local method.

Exact design is MA-10/MA-17/MA-18 implementation work.

### LOCKED

No hidden vendor/cloud escrow is permitted as a required recovery dependency.

---

## 25. Recovery-key loss

### LOCKED

If required recovery key material is lost, SerapeumOS must not fabricate it.

Affected encrypted secrets/integrations may become unrecoverable and require re-authentication/replacement.

The system should recover unrelated Company state where technically possible and safe.

Root-key loss is an explicit DR condition.

---

## 26. Restore is high-impact trusted operation

### LOCKED

Restore is not normal Agent work.

Restore authority belongs to the trusted Owner/operator recovery path and is governed by MA-06.

An Agent cannot autonomously roll the Company back to a backup.

---

## 27. Restore defaults to isolation

### LOCKED

A backup is restored into an **isolated recovery/staging environment** before it becomes active Company state.

Canonical flow:

```text
select recovery point
→ verify manifest/integrity
→ restore into isolated target
→ validate DB/schema/artifacts/workspaces
→ invalidate stale runtime authority
→ reconcile non-terminal execution
→ rebuild derived state
→ qualification checks
→ READY_FOR_PROMOTION
→ explicit trusted promotion
→ ACTIVE
```

### LOCKED

Direct destructive overwrite of the only live copy is not the default restore architecture.

---

## 28. Restore validation

### LOCKED

Before promotion, restore validation must include, as applicable:

- Backup Manifest validity;
- component digests;
- database readability/integrity;
- schema/product compatibility;
- Company/Principal identity consistency;
- required Artifact presence;
- Artifact digest validation;
- Workspace containment;
- configuration integrity;
- secret/key accessibility where required;
- audit/receipt integrity;
- recovery of required projections;
- absence of unresolved structural corruption.

---

## 29. Restored identity

### LOCKED

Restore preserves stable durable identities.

Examples:

- Company UID;
- Principal UID;
- Agent UID;
- Task UID;
- Artifact UID;
- provenance relationships.

Restore does not recreate the Company as a “new” Company merely because it runs on a replacement host.

---

## 30. Restored runtime authority is invalid

### LOCKED

Restore does **not** reactivate runtime security state from the backup.

The following are invalidated/reconstructed:

- Worker/appliance credentials;
- runtime sessions;
- active leases;
- resource reservations;
- Worker assignments;
- stale capabilities where policy requires fresh validation;
- local IPC/runtime tokens.

### LOCKED

New runtime incarnations obtain fresh MA-10 credentials and pass MA-02 admission again.

---

## 31. Non-terminal work after restore

### LOCKED

Tasks/workflows/jobs that were non-terminal at the recovery point do not automatically resume consequential execution.

After restore they enter MA-12 reconciliation.

The system must determine:

- whether the attempt can safely resume;
- whether a new attempt is required;
- whether external side effects might already have occurred;
- whether approval/capability state is still valid;
- whether Owner intervention is required.

---

## 32. External-world divergence

### LOCKED

Rolling internal state back does not roll back the external world.

External systems may contain actions that occurred after the selected backup point.

Therefore restore must explicitly reconcile affected:

- messages;
- remote records;
- published files;
- external tool actions;
- other consequential side effects.

### LOCKED

SerapeumOS must never assume:

```text
restored internal state
=
external world also restored
```

---

## 33. Restore point age

### LOCKED

Recovery UX and logic must expose the age/time of the selected recovery point.

An older restore point means possible loss of later internal state and possible external-world divergence.

### LOCKED

Selecting an older recovery point is an explicit trusted rollback decision, not an automatic convenience.

---

## 34. Anti-rollback / downgrade protection

### LOCKED

A valid old backup is not automatically safe to activate under current software/security state.

Restore must validate:

- backup schema version;
- product version;
- security migration state;
- compatibility path.

### LOCKED

Silent downgrade to an older vulnerable or incompatible product/schema state is prohibited.

Necessary version/migration handling belongs to MA-18.

---

## 35. Restore compatibility

### LOCKED

Conceptually:

- current software may restore a compatible older backup through an approved migration path;
- incompatible/too-new backup into older software is rejected;
- unsupported downgrade is rejected;
- migration modifies the isolated restored copy before promotion.

Restore must not mutate the only known-good backup set in place.

---

## 36. Restore scopes

### LOCKED

The architecture permits future support for scoped recovery, such as:

- full installation;
- one Company;
- selected Artifact;
- selected Agent Workspace;
- configuration component.

### LOCKED

A scoped restore may only be supported if identity, provenance, cross-reference, and authorization integrity can be preserved.

Unsupported scoped recovery must fail/refuse rather than perform unsafe partial merges.

The exact v1 supported restore scopes remain implementation/product policy.

---

## 37. Quarantine is first-class state

### LOCKED

**Quarantine** means:

> Preserve suspect data for inspection/recovery while preventing it from participating in normal trusted operation.

Quarantine is neither:

- deletion;
- acceptance;
- normal archive;
- ordinary inactive state.

---

## 38. Quarantine targets

### LOCKED

The system may quarantine:

- corrupt/suspect Artifact;
- suspect Workspace;
- invalid Backup Set;
- restored Company copy;
- compromised extension/package;
- malicious imported file;
- recovery output;
- forensic evidence.

Each quarantined object preserves its original identity/provenance where safe.

---

## 39. Quarantine access

### LOCKED

Normal Agents do not receive automatic read/write access to quarantine.

Inspection occurs through trusted recovery/security tooling or a specially bounded analysis path.

### LOCKED

Quarantined content cannot become executable merely because an Agent asks to inspect it.

Executable suspect content remains non-executable/read-only unless separately authorized and isolated.

---

## 40. Release from quarantine

### LOCKED

Release requires trusted validation.

Conceptual flow:

```text
QUARANTINED
→ inspect/validate
→ CLEAN / RECOVERABLE / REJECTED

CLEAN
→ trusted release/promotion

RECOVERABLE
→ repaired/copied into new validated object

REJECTED
→ retained or deleted under policy
```

### LOCKED

A repaired object normally receives new integrity/version evidence rather than silently changing the quarantined bytes in place.

---

## 41. Database corruption

### LOCKED

Suspected authoritative database corruption causes controlled stop/recovery.

SerapeumOS must not:

- let Agents “repair” authoritative DB state directly;
- infer missing Company truth from prompts;
- silently rebuild authoritative records from Workspace files.

Recovery sources are:

- verified live DB recovery mechanisms;
- verified backup;
- explicit trusted reconstruction from evidence where separately governed.

---

## 42. Artifact corruption

### LOCKED

If a committed Artifact payload fails integrity validation:

- mark affected Artifact unavailable/suspect;
- quarantine the corrupt payload;
- recover the exact expected bytes from a verified recovery source where available;
- verify digest before returning it to service.

### LOCKED

Different replacement bytes cannot retain the same immutable content identity.

---

## 43. Workspace corruption

### LOCKED

Workspace corruption is handled differently because Workspace is non-authoritative.

The system may:

- preserve/quarantine suspect Workspace;
- restore a prior Workspace snapshot;
- regenerate authoritative projections;
- selectively recover valid working files.

Workspace recovery cannot overwrite newer authoritative Company/Task/Brain truth.

---

## 44. Derived-state corruption

### LOCKED

Corrupt rebuildable state is discarded and rebuilt.

Examples:

- embeddings;
- search indexes;
- caches;
- generated projections.

Backup restore is not required merely to repair rebuildable derived state when authoritative inputs remain healthy.

---

## 45. Disaster triggers

### LOCKED

A DR path may be triggered by:

- host loss;
- storage-device failure;
- PostgreSQL unrecoverable corruption;
- Artifact Store loss/corruption;
- ransomware/malware compromise;
- root/recovery-key problem;
- catastrophic update/migration;
- destructive operator error;
- other loss of trusted authoritative state.

Triggering DR does not automatically select a recovery point.

---

## 46. DR lifecycle

### LOCKED

Conceptual disaster-recovery states:

```text
NORMAL
→ DEGRADED
→ RECOVERY_REQUIRED
→ RECOVERY_ISOLATED
→ RESTORING
→ VALIDATING
→ READY_FOR_PROMOTION
→ ACTIVE
```

Alternative terminal/blocked states:

```text
QUARANTINED
FAILED
BLOCKED
```

### LOCKED

Normal autonomous Agent execution remains disabled while the recovered Company is in `RECOVERY_ISOLATED`, `RESTORING`, or `VALIDATING`.

---

## 47. Promotion gate

### LOCKED

A restored Company may return to ACTIVE only after required validation passes.

Promotion requires confidence that:

- authoritative storage is self-consistent;
- required recovery keys/services work;
- runtime authority has been refreshed;
- non-terminal work is reconciled appropriately;
- quarantined blockers are resolved or explicitly isolated;
- software/schema compatibility is valid;
- critical audit/recovery evidence is intact.

---

## 48. Failed restore

### LOCKED

A failed restore does not silently become the new live system.

The failed recovery copy remains isolated or is discarded while preserving diagnostic evidence.

Where another verified recovery point exists, recovery may be retried from that point.

---

## 49. Disaster recovery to replacement host

### LOCKED

SerapeumOS architecture supports restoring Company state to a different qualified local host.

Company identity must not depend on:

- machine name;
- Windows SID;
- drive letter;
- exact filesystem path;
- one host's runtime instance IDs.

Host-specific key/storage adaptation belongs to MA-17/MA-18.

---

## 50. Platform neutrality

### LOCKED

Backup data formats and recovery semantics should remain platform-neutral above the host-adapter boundary.

A Company backup should not become inherently Windows-only or Linux-only because one supported host produced it.

Host-specific filesystem metadata may be recorded where useful but cannot be the sole identity of Company data.

---

## 51. Backup scheduling

### LOCKED

SerapeumOS must support scheduled/periodic backup according to product policy.

Exact cadence is not fixed by MA-13.

Cadence must reflect:

- acceptable data-loss window;
- workload;
- storage cost;
- backup target;
- release qualification.

Numerical targets belong to `PREREQUISITES.md`, product policy, and MA-20.

---

## 52. RPO and RTO

### LOCKED

SerapeumOS will define explicit release-level:

- **RPO** — acceptable maximum recoverable data-loss window;
- **RTO** — acceptable recovery-time target.

### LOCKED

MA-13 does not invent numbers before implementation/qualification evidence exists.

Final values must be measured and qualified under MA-20.

---

## 53. Backup verification

### LOCKED

Backup creation is incomplete as a recovery assurance process until integrity verification has run.

Verification checks at least:

- manifest completeness;
- component availability;
- component digest(s);
- required dependency chain;
- basic format readability.

### LOCKED

A backup whose verification was not performed must not be presented as equivalent to a verified recovery point.

---

## 54. Restore testing

### LOCKED

Release-quality disaster recovery requires periodic **test restore** into an isolated environment.

A test restore verifies more than backup-file existence.

It must demonstrate that the backup can actually reconstruct a valid system state.

### LOCKED

“No restore test performed” is a DR qualification gap.

Exact frequency and test matrix belong to MA-20.

---

## 55. Recovery evidence

### LOCKED

Backup/restore operations generate durable evidence sufficient to reconstruct:

- who initiated the operation;
- selected recovery point;
- source Backup Set;
- integrity results;
- restore target;
- compatibility/migration steps;
- validation outcomes;
- quarantined items;
- promotion decision;
- final recovery state.

MA-14 owns audit retention/presentation.

---

## 56. Backup deletion

### LOCKED

Protected Backup Sets cannot be deleted casually.

Deletion is governed according to:

- retention policy;
- Owner authority;
- legal/privacy requirements;
- minimum recovery-point requirements;
- immutable/offline target semantics.

### LOCKED

A compromised Agent cannot delete recovery points to hide damage.

---

## 57. Privacy / erasure interaction

### LOCKED

Backups may retain historical data after deletion from active state.

MA-14 must define how privacy erasure/retention obligations propagate into backup policy without destroying required recovery integrity.

MA-13 locks only that backup retention and privacy deletion must be designed together.

---

## 58. Supply-chain interaction

### LOCKED

Backup/restore tooling, compression/encryption libraries, filesystem snapshot tools, and recovery packages are subject to MA-19 provenance and qualification.

A recovery emergency does not justify executing unknown/unverified backup tooling inside the trusted recovery boundary.

---

## 59. System Evolution boundary

### LOCKED

MA-15 may analyze recovery history and propose:

- improved backup frequency;
- improved checkpoint layout;
- safer recovery workflows;
- better corruption detection.

It cannot:

- delete backup sets;
- change root recovery keys;
- auto-promote quarantined recovery state;
- weaken validation requirements

without the governing trusted approval path.

---

## 60. Veto conditions

An MA-13 implementation is invalid if it:

- treats copied files as a valid backup without consistency/integrity evidence;
- restores DB metadata that references missing/wrong Artifact bytes;
- treats `/agents` Workspace as authority over restored PostgreSQL state;
- includes plaintext root/recovery key beside the protected backup;
- requires cloud storage for recovery;
- gives Agents write access to protected backups;
- directly overwrites the only live copy as the default restore path;
- restores stale Worker credentials, leases, assignments, or runtime tokens;
- automatically resumes high-impact in-flight actions after restore without MA-12 reconciliation;
- assumes external-world effects roll back with internal state;
- silently activates an incompatible/older vulnerable schema/software state;
- executes quarantined content as normal Agent code;
- silently replaces corrupt immutable Artifact bytes under the same identity;
- treats an untested backup as proven recoverable;
- silently runs partially recovered Company state as normal ACTIVE operation.

---

## 61. MA-13 closure decision

### CLOSED

MA-13 is architecture-complete.

Locked:

- backup/DR separated from MA-12 operational recovery;
- explicit backup classes B0–B5;
- immutable manifest-driven Backup Sets;
- PostgreSQL + Artifact Store recovery consistency;
- protected but non-authoritative Workspace backup;
- derived state rebuild rather than authority;
- backup isolation from Agents;
- local/offline cloud-independent recovery;
- backup integrity and encryption;
- recovery-key separation;
- trusted high-impact restore;
- isolated restore before promotion;
- fresh runtime authority after restore;
- reconciliation of non-terminal/external effects;
- first-class quarantine;
- explicit corruption handling by state class;
- DR lifecycle and promotion gate;
- platform-neutral replacement-host recovery;
- RPO/RTO deferred to evidence-based qualification;
- mandatory verification and test-restore principle.

No material MA-13 architecture question remains inside this domain.

---

## 62. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-131 — Backup Sets cover all authoritative recovery classes
A valid recovery point includes PostgreSQL authoritative state, required managed Artifacts, protected Agent Workspace continuity, required reconstruction/recovery metadata, and protected audit/receipt state where separate.

### D-132 — Backup validity is manifest- and integrity-based
A backup is a verifiable immutable Backup Set, not merely a filesystem copy.

### D-133 — PostgreSQL and Artifact recovery must be self-consistent
A recovery point cannot activate with live authoritative references to missing or wrong Artifact content.

### D-134 — Workspace recovery never overrides authoritative truth
`/agents` is backed up for continuity but restored PostgreSQL/domain authority wins and runtime projections may be regenerated.

### D-135 — Restore occurs in isolation before promotion
Backup restore defaults to a quarantined/staging recovery environment and becomes ACTIVE only after validation and trusted promotion.

### D-136 — Restored runtime authority is invalidated
Worker credentials, runtime sessions, leases, assignments, reservations, and stale runtime authority are not resurrected from backups.

### D-137 — Recovery keys are separate from protected Backup Sets
The root/recovery secret is not stored plaintext beside the encrypted data it protects; backup data and recovery-key material use separate trust channels.

### D-138 — Quarantine is first-class recovery state
Suspect Artifacts, Workspaces, Backup Sets, recovery copies, and executable content remain preserved but outside normal trusted operation until validated.

### D-139 — Disaster recovery is local, portable, and cloud-independent
SerapeumOS supports offline/local recovery and replacement qualified hosts without requiring hosted backup infrastructure.

### D-140 — Verified backup and test restore are required for DR confidence
Backup-file existence alone is insufficient; integrity verification and isolated restore testing are required for release-quality disaster recovery.

---

## 63. Project-state transition

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

Current architecture domain:
MA-14 — Observability / Audit / Receipts / Privacy

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Repository persistence:
PENDING

Next action:
MA-14-CLOSE — architecture only
```

---

## 64. Next action

**MA-14-CLOSE — Observability / Audit / Receipts / Privacy**

Architecture only.
