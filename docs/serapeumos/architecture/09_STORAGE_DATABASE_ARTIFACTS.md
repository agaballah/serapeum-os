# MA-09 — Storage / Database / Artifact Store / User-File Publication

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-09 defines where SerapeumOS durable state lives, which storage is authoritative, how files/artifacts are identified, how Agent workspace continuity differs from Company truth, and how data crosses between SerapeumOS-managed storage and Owner/user files.

It governs:

- authoritative relational state;
- artifact/content storage;
- Agent workspace persistence;
- derived/rebuildable storage;
- file import;
- controlled user-file publication;
- storage identity and integrity;
- cross-store consistency;
- retention/deletion boundaries.

MA-09 does not define backup policy, encryption/key management, host-specific filesystem mechanics, installer paths, or storage quotas. Those belong to later domains.

---

## 2. Governing principle

### LOCKED

> **Durability does not imply authority.**

SerapeumOS distinguishes authoritative state from durable working files.

For example:

```text
PostgreSQL Company / Task / Brain state
        = authoritative domain state

Managed immutable artifact
        = authoritative artifact payload/reference

/agents/<agent>/...
        = durable Agent continuity, but non-authoritative Company truth

retrieval indexes / caches
        = rebuildable projections

Owner host file
        = external user resource, not Agent-owned storage
```

---

## 3. Canonical storage classes

### LOCKED

SerapeumOS uses these logical storage classes:

| Class | Purpose | Authority |
|---|---|---|
| **R0 — Authoritative Relational State** | Company, Principal relations, Agents, Tasks, workflows, AuthZ, epistemic metadata, configuration, durable execution state | **Authoritative** |
| **R1 — Managed Artifact Store** | immutable imported/generated files, evidence payloads, accepted outputs and durable binary/content artifacts | **Authoritative for artifact bytes** |
| **R2 — Agent Workspace (`/agents`)** | persistent Agent continuity, working copies, sessions/jobs, runtime projections | Durable but **non-authoritative** |
| **R3 — Derived/Rebuildable State** | indexes, embeddings, caches, projections, model context, runtime materializations | Non-authoritative |
| **R4 — Ephemeral Runtime State** | temporary files, process state, `/tmp`, disposable appliance state | Disposable |
| **R5 — Host/User Resources** | Owner files/folders and other user-controlled resources outside managed SerapeumOS state | External |
| **R6 — Recovery State** | backups, restore manifests, quarantine/recovery copies | Governed by MA-13 |

---

## 4. PostgreSQL remains the authoritative structured-state database

### LOCKED

SerapeumOS retains the inherited Ankole PostgreSQL control-plane database as the primary authoritative relational store.

This preserves the qualified foundation rather than inventing a second state engine.

PostgreSQL owns structured durable records for domains including:

- Company identity and organization;
- Principals and Agent identity;
- roles/missions/tasks and workflow state;
- AuthZ/grants;
- capabilities/approval state where persisted;
- Brain Objects/Claims/provenance metadata;
- execution/job/turn state;
- model/provider/profile configuration;
- extension registry/configuration;
- artifact metadata/references;
- audit/receipt metadata where appropriate.

### LOCKED

Untrusted Agent runtimes never receive PostgreSQL credentials or direct database mutation authority.

All mutations go through trusted domain services.

---

## 5. Domain ownership of relational state

### LOCKED

A shared PostgreSQL database does not mean shared domain authority.

Each architectural domain owns its records and mutation rules.

A subsystem may read/reference another domain's stable identity where allowed, but cannot bypass that domain's service contract to redefine its truth.

### LOCKED

Cross-domain mutations that require atomic consistency must occur through trusted orchestration/transactions, not independent Agent writes.

---

## 6. Company scope

### LOCKED

Company-owned relational and artifact records must resolve unambiguously to `company_uid`.

No durable Company-owned record may depend solely on a process-global “current Company” assumption.

Principal-scoped records that belong to a Company must also resolve to that Company through stable trusted relations.

This remains true even if the first product release exposes only one active Company per installation.

---

## 7. Stable identity

### LOCKED

Durable storage references use stable internal identities, not mutable presentation values.

Examples:

```text
company_uid
principal_uid
task_uid
artifact_uid
source_uid
```

are identity.

Examples such as:

```text
company name
Agent display name
filename
filesystem path
email address
model alias
```

are not durable identity keys.

---

## 8. Managed Artifact Store

### LOCKED

General durable file/content payloads are stored through a **SerapeumOS-managed Artifact Store**, separate from normal relational rows.

The Artifact Store is used for content such as:

- imported user-file snapshots;
- source evidence payloads;
- generated reports/documents/images;
- accepted Task outputs;
- tool-produced durable artifacts;
- exported packages;
- other potentially large immutable content.

### LOCKED

PostgreSQL stores artifact metadata, ownership/scope, provenance, lifecycle and references.

The payload store owns artifact bytes.

---

## 9. Existing AIGateway binary compatibility exception

### REPOSITORY FACT

Ankole currently stores some bounded AIGateway uploaded/generated-image payloads directly in PostgreSQL with SHA-256, byte size, Principal scope and expiration rules.

### LOCKED

This existing bounded subsystem may remain compatible during SerapeumOS evolution.

However:

> **It does not define the general SerapeumOS artifact architecture.**

New general-purpose large-file/document storage must use the managed Artifact Store rather than expanding arbitrary PostgreSQL BLOB usage.

A later implementation task may migrate existing AIGateway artifacts if justified, but MA-09 does not require immediate foundation churn.

---

## 10. Artifact immutability

### LOCKED

A durable Artifact payload is immutable.

Changing content creates a new Artifact identity/version.

Mutable metadata may describe state around an Artifact, but the bytes represented by a content identity do not change in place.

This provides:

- reproducibility;
- provenance;
- reliable receipts;
- rollback;
- deduplication where used;
- corruption detection.

---

## 11. Artifact integrity

### LOCKED

Every managed Artifact records integrity evidence including at least:

- byte length;
- strong cryptographic digest;
- media/content type where known.

SHA-256 is the baseline digest because the inherited foundation already uses it successfully; a stronger/additional digest may be introduced later without changing architecture.

### LOCKED

Artifact reads used for consequential operations may revalidate integrity according to policy.

A payload whose digest/size no longer matches is corrupt and must not silently be used as valid.

---

## 12. Artifact identity vs content identity

### LOCKED

SerapeumOS distinguishes:

- **Artifact identity** — stable domain record representing a managed artifact/version;
- **Content digest** — identity/evidence for the exact bytes.

Different artifact records may intentionally reference identical bytes while preserving different provenance, ownership, retention or Task context.

Deduplication is an implementation optimization, not a semantic merge.

---

## 13. Artifact metadata

### LOCKED

A durable Artifact record must be able to preserve, as applicable:

- Artifact UID;
- Company scope;
- owning/creating Principal;
- Task/execution context;
- original source name;
- content type;
- byte size;
- digest;
- creation/import time;
- source/provenance reference;
- lifecycle/retention state;
- parent/previous Artifact where versioned;
- publication/import relations;
- sensitivity/classification metadata where later defined.

Exact physical schema is implementation design.

---

## 14. Artifact-store backend neutrality

### LOCKED

The Artifact Store is a logical service contract.

The initial implementation may use a managed local filesystem/content-addressed layout.

The Company/Task/Brain architecture must not depend on:

- Windows paths;
- Linux paths;
- NTFS-specific identifiers;
- one storage library.

The payload backend may change without changing domain identity/provenance.

---

## 15. Cross-store commit rule

### LOCKED

PostgreSQL remains the authority for whether an Artifact is committed/referenced.

Because relational metadata and filesystem/blob payloads do not share one native transaction, the architecture uses safe staged commit semantics.

Conceptually:

```text
write payload to staging
→ verify length/hash
→ atomically commit immutable payload where possible
→ commit PostgreSQL Artifact/reference row
→ expose as live
```

### LOCKED

A PostgreSQL live Artifact reference must never intentionally point to an absent/unverified payload.

A crash may leave an unreferenced payload orphan; that is preferable to a committed database reference to missing bytes.

Orphan cleanup is safe maintenance.

---

## 16. Artifact deletion

### LOCKED

Deletion follows reference/lifecycle rules.

Normal sequence:

```text
withdraw/expire logical references
→ mark Artifact eligible for collection
→ verify no protected live references/retention hold
→ remove payload
```

The system must not delete a payload merely because one Task/reference no longer needs it if another live reference still exists.

Detailed retention and legal/privacy holds belong to MA-14.

---

## 17. Agent workspace contract

### LOCKED

The MA-01 `/agents/<agent_uid>` contract remains the persistent Agent Workspace.

Conceptual structure includes inherited paths such as:

```text
/agents/<agent_uid>/
├── SOUL.md
├── MISSION.md
├── DESIGN.md
├── user-files/
├── installed-skills/
├── sessions/
└── jobs/
```

### LOCKED

The Workspace is durable continuity state but is not authoritative Company/Task/Brain truth.

---

## 18. Agent Home projections

### REPOSITORY FACT

Ankole already rebuilds `SOUL.md`, `MISSION.md`, and `DESIGN.md` one-way from PostgreSQL and treats Worker-side synchronization as a projection barrier.

### LOCKED

SerapeumOS retains this principle.

```text
PostgreSQL authoritative document state
          ↓
Agent Home projection
```

Editing a projected runtime file does not, by itself, change authoritative Agent doctrine/mission/design.

Authoritative changes require the owning trusted service.

---

## 19. Workspace working files

### LOCKED

Files produced or modified inside Agent session/job/workspace directories are working state until explicitly promoted.

They may be:

- useful;
- persistent across Agent continuity;
- referenced by execution.

But they do not automatically become:

- authoritative Task result;
- Company knowledge;
- managed Artifact;
- published Owner file.

Promotion is an explicit trusted operation.

---

## 20. `user-files` semantics

### LOCKED

`/agents/<agent>/user-files` is an Agent-visible managed working area.

It is **not** a direct mount of the Owner's host filesystem.

It may contain:

- controlled copies of imported Owner files;
- Agent-generated files awaiting promotion/publication;
- outbound attachment material;
- other Company-authorized working copies.

A path in `user-files` is not the identity of the original host resource.

---

## 21. Installed Skills projection

### LOCKED

The durable authority for which Skills/extensions are installed/enabled remains in trusted extension/configuration state.

`/agents/<agent>/installed-skills` is an Agent-runtime materialization/working representation.

Filesystem presence alone cannot silently enable a Skill or create authority.

This aligns MA-08 with MA-09.

---

## 22. Session and job workspaces

### LOCKED

Ankole's stable PostgreSQL-owned session/job workspace identities may be reused.

Session/job workspace directories support continuity and execution evidence.

Their files are non-authoritative until referenced/promoted by trusted state.

A deleted/recreated runtime can reattach or reconstruct the workspace relationship from PostgreSQL identity.

---

## 23. Worker file transfer lane

### REPOSITORY FACT

Ankole's Worker file lane is active-transfer state only; durable references belong in PostgreSQL.

Its control-plane `WorkerFiles` facade restricts roots and bounds individual transfers.

### LOCKED

SerapeumOS retains this separation:

```text
File transfer mechanism
    ≠
Durable file authority
```

A successful byte transfer does not itself create an authoritative Artifact or publication.

---

## 24. Derived/rebuildable storage

### LOCKED

The following remain rebuildable/non-authoritative:

- embeddings;
- Brain chunks;
- search indexes;
- caches;
- model-context packs;
- runtime materializations;
- generated Agent Home projections;
- temporary thumbnails/previews;
- process-local health state.

Their loss may reduce performance or temporary functionality, but must not erase authoritative Company knowledge/state.

---

## 25. Importing Owner/user files

### LOCKED

The default host-file ingestion path is **managed import**, not live mount.

Conceptually:

```text
Owner/user selects resource
→ trusted host broker validates access/identity
→ read bounded/authorized source
→ create immutable managed Artifact snapshot
→ record original-source provenance
→ expose controlled working copy/reference to assigned Agent
```

### LOCKED

The imported snapshot and the original user resource are different objects.

Subsequent changes to either do not silently mutate the other.

---

## 26. Import provenance

### LOCKED

A managed import must preserve enough source evidence to identify, where available:

- original resource locator/path;
- observed modification/version metadata;
- observed byte size;
- captured content hash;
- import timestamp;
- importing Principal;
- Company/Task;
- source Artifact relationship.

Sensitive host paths may be protected from unnecessary model disclosure while remaining available to trusted provenance/audit services.

---

## 27. Live/read-only host resources

### LOCKED

MA-01's access order remains:

1. managed copy/import — preferred;
2. governed read-only live link — exceptional;
3. controlled live writable resource — exceptional/high impact.

### LOCKED

A live host resource is never exposed as an arbitrary Agent filesystem mount.

If supported, access occurs through a trusted resource broker with MA-06 authorization and host-specific MA-17 protections.

---

## 28. Publishing to Owner/user files

### LOCKED

Writing from SerapeumOS-managed state to an Owner/user resource is **Publication**, not ordinary Agent file I/O.

Canonical publication flow:

```text
select committed Artifact/output
→ identify target resource
→ observe target existence/version/state
→ construct exact publication proposal
→ MA-06 AuthZ / Action Assurance
→ re-check target state
→ prepare recovery/backup where policy requires
→ controlled trusted write/replace
→ verify resulting bytes/state
→ record receipt
```

The Agent itself does not perform arbitrary host writes.

---

## 29. Publication source

### LOCKED

Publication must use a stable staged/committed source.

A mutable arbitrary workspace path is not sufficient for a consequential publication.

Before publication, the intended output should be promoted/frozen as a managed Artifact or equivalently immutable publication payload.

This guarantees that approval refers to the same bytes that are executed.

---

## 30. Publication target identity

### LOCKED

Publication approval binds to the exact target.

A path string alone may be insufficient where host semantics allow ambiguity or replacement.

The trusted host adapter must use the strongest practical target identity/version evidence available on that platform.

Host-specific mechanisms belong to MA-17.

---

## 31. Conflict detection

### LOCKED

If a target that existed during validation changes materially before publication, SerapeumOS must not silently overwrite it under stale approval.

The action must:

- stop as conflict; or
- return through the required re-validation/approval policy.

Relevant comparison may use:

- file identity;
- size;
- timestamps;
- content digest;
- other platform-stable metadata.

Exact host algorithm belongs to MA-17.

---

## 32. Existing target vs new target

### LOCKED

Publication distinguishes:

- creating a new resource;
- replacing an existing resource;
- updating a governed live resource.

These have different risk/recovery semantics.

Replacing existing Owner data is more consequential than creating a new file and requires policy appropriate to the risk.

---

## 33. Atomic publication

### LOCKED

Publication should be atomic from the Owner's perspective wherever the host filesystem supports a safe atomic replacement pattern.

Conceptually:

```text
write verified temporary sibling
→ flush/validate
→ atomic replace/rename
```

Where true atomicity cannot be provided, the adapter must use an explicit journal/recovery procedure and cannot claim atomic success.

Exact filesystem mechanics belong to MA-17.

---

## 34. Multi-file publication

### LOCKED

Publishing a set/package of files is one governed publication plan.

The system must record:

- intended file set;
- target set;
- per-file state;
- completion state.

If the host cannot provide one atomic transaction, partial execution must be visible and recoverable.

SerapeumOS must never report the overall publication as fully successful when only part of the set was written.

---

## 35. Publication verification

### LOCKED

Publication success requires post-write verification appropriate to the action.

At minimum for normal file output:

- target exists;
- size matches;
- strong digest matches intended payload.

Additional application/file-format validation may be required for higher-assurance outputs.

A write syscall returning success is not sufficient proof of final publication.

---

## 36. Publication receipt

### LOCKED

The receipt must be able to bind:

- publishing Principal/Agent;
- Company/Task;
- source Artifact/digest;
- exact target;
- prior observed target state;
- approval/capability;
- publication time;
- resulting digest/state;
- verification outcome;
- recovery/backup reference where applicable.

Receipt/audit storage policy belongs to MA-14.

---

## 37. Publication recovery

### LOCKED

When policy requires protection of an existing target, recovery preparation occurs before destructive replacement.

Recovery may use:

- prior-content Artifact snapshot;
- backup copy;
- versioned user-resource mechanism;
- another MA-13-approved method.

The exact recovery policy belongs to MA-13.

### LOCKED

If recovery preparation required by policy fails, destructive publication does not proceed.

---

## 38. File names and paths

### LOCKED

Names/paths are presentation/location metadata, not trusted identity.

All Agent-provided filenames/relative paths must be normalized and contained within approved roots.

Traversal, symlink/reparse-point escape, case/normalization collision, and host-path ambiguity must fail closed.

Platform-specific path semantics belong to MA-17.

---

## 39. No direct physical disk authority

### LOCKED

The Worker/Agent receives mounted filesystems/approved roots, not arbitrary raw block devices.

The Agent cannot mount additional host storage, inspect unrelated disks, or attach arbitrary storage devices.

This preserves MA-01.

---

## 40. Database/artifact consistency

### LOCKED

Authoritative relational state must never infer artifact existence merely from a path.

A live artifact reference resolves through the Artifact service/metadata and validates expected storage state.

### LOCKED

Database backups and Artifact Store backups must be coordinated so restoration can produce a self-consistent point/state.

Exact backup/restore ordering belongs to MA-13.

---

## 41. Storage corruption

### LOCKED

Corruption is represented explicitly.

The system must not silently regenerate or replace an authoritative Artifact with different bytes and retain the same identity.

Depending on state class:

- authoritative relational corruption → recovery/quarantine;
- Artifact corruption → quarantine/recovery;
- derived state corruption → rebuild;
- workspace corruption → recover/reconstruct where possible.

Detailed response belongs to MA-13.

---

## 42. Retention

### LOCKED

Storage lifecycle is reference- and policy-aware.

An Artifact may not be garbage-collected while protected by:

- active domain references;
- required provenance;
- audit/receipt retention;
- backup/recovery requirements;
- explicit hold.

Detailed retention periods/privacy erasure belong to MA-14.

---

## 43. Storage locality

### LOCKED

Normal production state is stored locally under SerapeumOS-managed storage.

No mandatory cloud database, object store, sync service, or remote filesystem is part of final architecture.

Optional Owner-controlled export/backup targets may be added later through governed adapters.

---

## 44. Host portability

### LOCKED

Company/domain semantics do not depend on Windows drive letters, NTFS, Unix inode values, or a specific home directory.

Host adapters translate the platform-neutral storage contracts to supported local filesystem/storage semantics.

MA-17 qualifies those mappings.

---

## 45. Database migration authority

### LOCKED

Schema migrations are trusted product operations.

Agents cannot perform production database migrations merely because they can generate SQL/code.

Migration compatibility, rollback and installer sequencing belong to MA-18.

---

## 46. Veto conditions

An MA-09 implementation is invalid if it:

- makes `/agents` authoritative Company truth;
- lets Worker-local files replace authoritative PostgreSQL state;
- gives Agents direct DB credentials;
- uses arbitrary host folder mounts as the normal Agent file model;
- treats host path as durable resource identity;
- expands PostgreSQL into an unbounded general-purpose binary store;
- allows mutable artifact bytes under the same content identity;
- commits database references to absent/unverified Artifact payloads;
- treats imported user files as live mutable aliases by default;
- publishes directly from uncommitted mutable workspace state for consequential writes;
- overwrites changed Owner files under stale approval;
- reports publication success without post-write verification;
- silently hides partial multi-file publication;
- deletes referenced artifacts without lifecycle/retention checks;
- makes cloud storage mandatory.

---

## 47. MA-09 closure decision

### CLOSED

MA-09 is architecture-complete.

Locked:

- PostgreSQL as authoritative structured control-plane database;
- domain-owned trusted mutations;
- explicit Company scope;
- separate managed Artifact Store for general durable payloads;
- immutable artifact/version semantics with SHA-256 baseline integrity;
- safe cross-store staged commit;
- `/agents` durable but non-authoritative;
- one-way Agent Home projections;
- session/job/workspace continuity below authoritative state;
- managed user-file import by default;
- no arbitrary host mounts;
- publication as a trusted MA-06-governed operation;
- immutable staged publication source;
- target revalidation/conflict detection;
- atomic/recoverable publication semantics;
- post-write verification and receipts;
- derived-state rebuildability;
- local/platform-neutral storage contract.

No material MA-09 architecture question remains inside this domain.

---

## 48. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-091 — PostgreSQL remains authoritative structured state
SerapeumOS reuses Ankole PostgreSQL for Company, Agent, Task, AuthZ, epistemic and other structured durable control-plane truth.

### D-092 — General durable payloads use a managed Artifact Store
PostgreSQL holds Artifact metadata/references; general document/file payloads use a separate local managed Artifact Store.

### D-093 — Artifacts are immutable
Changing payload bytes creates a new Artifact/version. SHA-256 is the baseline content-integrity digest.

### D-094 — Database reference commit is artifact authority
Artifact payloads are staged/verified before database references become live; orphan payload is preferable to a live DB reference to missing bytes.

### D-095 — `/agents` is durable non-authoritative continuity
Agent Home, session/job workspaces and `user-files` are persistent Agent working state but cannot override Company/Task/Brain authoritative state.

### D-096 — Agent Home domain files are one-way projections
`SOUL.md`, `MISSION.md`, and `DESIGN.md` are rebuilt from trusted PostgreSQL state; filesystem edits alone do not mutate authority.

### D-097 — User files are imported as managed snapshots by default
Owner resources are copied into controlled immutable Artifact state before Agent processing; live host mounts are exceptional and brokered.

### D-098 — User-file writes are Publication
Publishing to Owner resources requires immutable source, exact target, AuthZ/Action Assurance, stale-target recheck, trusted write, verification and receipt.

### D-099 — Publication conflicts fail closed
A materially changed target invalidates stale publication assumptions; SerapeumOS does not silently overwrite under stale approval.

### D-100 — General storage remains local and platform-neutral
Final operation requires no cloud DB/object store and domain semantics do not depend on host-specific path/filesystem identity.

---

## 49. Project-state transition

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

Current architecture domain:
MA-10 — Secrets / Credentials / Security Principals

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-10-CLOSE — architecture only
```

---

## 50. Next action

**MA-10-CLOSE — Secrets / Credentials / Security Principals**

Architecture only.
