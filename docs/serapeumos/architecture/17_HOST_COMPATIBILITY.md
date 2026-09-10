# MA-17 — Host Compatibility / Storage Semantics

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED  
**Runtime prototypes:** PAUSED  
**Repository persistence:** PENDING

---

## 1. Purpose

MA-17 defines the host-platform compatibility contract for SerapeumOS and maps the platform-neutral architecture established by MA-01 through MA-16 onto qualified local operating systems and filesystems.

It governs:

- host capability discovery and qualification;
- filesystem/path semantics;
- case and Unicode differences;
- symlink/reparse/mount containment;
- target identity and stale-target detection;
- local publication atomicity and durability;
- file locking/concurrency behavior;
- managed storage placement;
- Agent workspace persistence below the hard-appliance boundary;
- host-local trusted IPC/lifecycle primitives;
- host root-secret protection capability;
- host resource-enforcement capability;
- sleep/resume/restart compatibility;
- compatibility/degraded-mode behavior;
- the boundary between architectural support and MA-20 release qualification.

MA-17 does **not** define installer sequencing, schema/data migration, update/rollback packaging, dependency provenance, SBOM/signing, or final executable qualification. Those belong to MA-18, MA-19, and MA-20.

---

## 2. Governing principle

### LOCKED

> **Host-specific behavior is an implementation fact, never domain authority.**

SerapeumOS core semantics remain independent of:

- drive letters;
- host path separators;
- filesystem case behavior;
- inode/file-index formats;
- service managers;
- VMM brands;
- OS credential-store brands;
- host lock APIs;
- specific filesystem names.

The core asks for capabilities and receives proven semantics through bounded host adapters.

---

## 3. Architecture boundary

### LOCKED

The logical system remains:

```text
SerapeumOS Core / Domain Services
        │
        ├── Host Compatibility Contract
        │      ├── Storage Adapter
        │      ├── Isolation Adapter
        │      ├── Lifecycle / IPC Adapter
        │      ├── Secret-Protection Adapter
        │      └── Resource Adapter
        │
        └── Qualified Host Implementation
               ├── Windows implementation
               └── Linux implementation
```

No Company, Agent, Task, Artifact, Claim, permission, approval, receipt, or workflow rule may branch on a host implementation detail except through an explicit capability result.

### LOCKED

A supported host is a **capability set**, not merely an OS name/version string.

The same OS release may be qualified for one SerapeumOS mode and unqualified for another depending on:

- virtualization availability;
- filesystem placement;
- secure root-key capability;
- host policy;
- disk space/resources;
- required kernel/OS features;
- administrative restrictions;
- current security posture.

---

## 4. Architectural support vs release qualification

### LOCKED

MA-17 locks the **compatibility contract**.

MA-20 proves specific host/version/backend combinations against that contract.

Therefore:

```text
Architecture-supported
    ≠ automatically release-qualified

Release-qualified
    = architecture contract satisfied
      + executable MA-20 evidence passed
```

### LOCKED

A host/backend must never be labeled production-supported merely because:

- it starts successfully;
- the VMM launches;
- PostgreSQL runs;
- a filesystem operation appears to work;
- a development prototype passed one smoke test.

Release support requires MA-20 evidence.

---

## 5. First qualification targets

### LOCKED

The first production qualification target is:

- **Windows 11, x86-64**, on a locally attached fixed disk using a qualified NTFS managed-state volume.

This is a release-target decision, not a Windows dependency in SerapeumOS core architecture.

### LOCKED

Linux remains an architecture-supported host family through the same compatibility contract.

The initial Linux qualification family is:

- x86-64 Linux;
- KVM-capable host where hostile-Agent execution is enabled;
- local ext4 or XFS managed-state volume;
- a host environment able to provide the required service, IPC, resource, key-protection, and filesystem guarantees.

Specific distributions, kernels, package versions, filesystems, and VMM implementations are MA-20 matrix entries rather than MA-17 doctrine.

### PROPOSED / NOT RELEASE-BASELINE

- Windows on ARM64;
- Linux ARM64;
- ReFS as a general active managed-state baseline;
- macOS host support;
- other Unix/BSD hosts.

They may be added later only through a new qualified Host Compatibility Profile without changing core semantics.

---

## 6. Host Compatibility Profile

### LOCKED

Every startup produces a trusted **Host Compatibility Profile** before untrusted work is admitted.

Conceptually it contains:

```text
HostCompatibilityProfile
  host_family
  host_version/build
  architecture
  boot/session identity

  isolation
    hard_appliance_supported
    backend_candidates
    backend_selected
    force_stop_supported
    network_isolation_supported
    device_isolation_supported

  storage
    managed_roots[]
    filesystem_type
    local_fixed_storage
    physical_at_rest_protection
    case_semantics
    unicode/path_semantics
    reparse_symlink_controls
    stable_open_handle_identity
    exclusive_create
    atomic_replace
    durable_flush
    directory_durability
    lock_capability

  secrets
    protected_root_secret_supported
    host_binding_characteristics

  lifecycle_ipc
    trusted_service_supervision
    local_authenticated_ipc
    appliance_control_channel

  resources
    cpu_limit
    memory_limit
    disk_quota_or_budget_enforcement
    process_tree_containment
    gpu_visibility/control

  recovery
    restart_reconciliation
    sleep_resume_detection

  qualification
    profile_version
    evidence_version
    qualification_status
    unsupported_reasons[]
```

Exact data structures belong to implementation.

The semantic fields above are architecture requirements.

---

## 7. Capability states

### LOCKED

A required host capability uses explicit states such as:

- `PROVEN_AVAILABLE`;
- `PROVEN_UNAVAILABLE`;
- `UNKNOWN`;
- `DEGRADED`;
- `STALE`.

`UNKNOWN` is not equivalent to available.

### LOCKED

Security-critical capability checks fail closed.

Examples:

- hard appliance isolation unknown → no hostile-Agent execution;
- managed filesystem semantics unknown → no authoritative store initialization there;
- root-secret protection unavailable → protected services unavailable;
- target atomicity unknown → no claim of atomic publication;
- resource hard limit unavailable → workload requiring that hard limit is not admitted.

---

## 8. Product operating modes derived from host capability

### LOCKED

SerapeumOS may operate in different **capability-derived modes** without changing authority semantics.

Minimum modes:

| Mode | Meaning |
|---|---|
| **FULL_LOCAL_AUTONOMY** | Host proves all required hard-Agent, storage, secret, lifecycle and resource capabilities for production Agent execution. |
| **TRUSTED_CORE_ONLY** | Owner Workspace/trusted services may operate, but hostile-Agent execution is disabled because the hard outer boundary is unavailable or unqualified. |
| **RECOVERY_ONLY** | Only trusted recovery/diagnostic operations are admitted because normal authoritative operation cannot be safely reconstructed. |
| **UNSUPPORTED** | Required baseline capabilities for even trusted durable operation are absent or unknown. |

### LOCKED

Degraded operation disables capabilities; it does not weaken safeguards.

---

## 9. Windows host mapping

### LOCKED

Windows is implemented through a bounded Windows Host Adapter.

The adapter may use host-native mechanisms such as:

- Windows Hypervisor Platform / Hyper-V-class virtualization primitives behind the selected VMM;
- Windows service supervision;
- access-controlled local IPC;
- handle-based filesystem operations;
- Windows file identifiers;
- reparse-point inspection;
- durable flush primitives;
- Windows ACL/DACL protection;
- Windows process/job or VMM resource controls;
- OS/TPM-backed key protection where qualified.

These names describe implementation families; they are not domain-level dependencies.

### LOCKED

**WSL2 remains rejected as the production outer hostile-Agent boundary.**

It may be used only for development/tooling or non-security-boundary compatibility tasks where no MA-01 guarantee depends on WSL2 isolation.

### PROPOSED / FIRST QUALIFICATION CANDIDATES

The MA-01 backend direction remains controlling for qualification order:

- QEMU/WHPX — primary Windows hostile-appliance candidate;
- full Hyper-V — conditional/reference Windows alternative.

Final backend support still requires MA-19 provenance and MA-20 executable qualification.

---

## 10. Linux host mapping

### LOCKED

Linux is implemented through a bounded Linux Host Adapter.

The adapter may use host-native mechanisms such as:

- KVM-backed VMM isolation;
- system service supervision;
- Unix-domain/local authenticated IPC;
- descriptor-relative filesystem resolution;
- mount/symlink containment;
- `rename`/`renameat2`-class atomic namespace operations;
- `fsync`-class durability operations;
- POSIX ownership/mode/ACL protection;
- cgroups-v2/VMM resource controls;
- kernel/TPM/OS-backed secret protection where qualified.

Exact implementations remain replaceable.

### PROPOSED / FIRST QUALIFICATION CANDIDATES

The MA-01 Linux backend candidates remain:

- Firecracker/KVM;
- Cloud Hypervisor/KVM;
- QEMU/KVM as compatibility/reference candidate.

Selection is evidence-driven in MA-19/MA-20 and may not weaken MA-01.

---

## 11. Managed storage root

### LOCKED

SerapeumOS-managed authoritative/runtime storage uses one or more **trusted managed roots** selected and owned by trusted installation/configuration logic.

A managed root is not:

- Agent-selectable;
- a live arbitrary Owner folder;
- a cloud-sync folder;
- a network share;
- a removable USB volume;
- a user-writable shared scratch folder.

### LOCKED

For the first Windows production qualification baseline, active managed state uses a **local fixed NTFS volume**.

### LOCKED

For Linux production qualification, active managed state uses a **local fixed qualified filesystem**, initially ext4 or XFS candidates.

### REJECTED

Active R0/R1/R2 storage on normal production hosts must not use as its baseline:

- FAT/FAT32;
- exFAT;
- SMB/NFS/network shares;
- cloud-synchronized folders;
- removable media;
- browser-managed storage;
- host folders whose ownership or path-resolution semantics cannot be strongly controlled.

These may still be Owner-controlled import/export/backup targets where the relevant MA-09/MA-13 rules and target capabilities permit.

---

## 12. Managed-root permissions

### LOCKED

Managed roots are protected from ordinary untrusted processes and Agents.

The trusted host implementation must establish least-privilege access such that:

- trusted storage/database services receive only required authority;
- Agent appliances do not obtain direct host paths to R0/R1;
- Agent workspace image containers are not exposed as arbitrary shared host folders;
- unrelated host users/processes are not intentionally granted write authority;
- inherited broad permissions are not silently accepted when they violate the required policy.

### LOCKED

The product must not require disabling host security software or globally weakening filesystem protections as a normal operating prerequisite.

---

## 13. Storage-class host mapping

### LOCKED

The MA-09 classes map as follows:

| Storage class | Host semantic requirement |
|---|---|
| **R0 Authoritative Relational State** | PostgreSQL-owned durable local storage; protected from Agent/direct user mutation; qualified durability. |
| **R1 Managed Artifact Store** | immutable payload storage under trusted root; verified write-then-commit semantics. |
| **R2 Agent Workspace** | per-Agent durable virtual block storage attached only to that Agent appliance; non-authoritative. |
| **R3 Derived State** | local rebuildable storage; may use weaker performance-oriented durability policy. |
| **R4 Ephemeral State** | disposable local runtime storage; no recovery promise. |
| **R5 Host/User Resources** | external resources accessed only through trusted broker/publication contracts. |
| **R6 Recovery State** | MA-13-governed backup/quarantine storage; target-specific qualification. |

---

## 14. Internal storage names are opaque

### LOCKED

SerapeumOS-controlled physical storage names use opaque, generated, collision-resistant identifiers rather than user names.

Examples include:

- Artifact UID/digest-derived object names;
- Agent UID-derived workspace identifiers;
- internal transaction IDs;
- trusted temporary object names.

This minimizes host portability risk from:

- reserved names;
- Unicode normalization;
- case behavior;
- path length;
- shell interpretation;
- user renaming.

### LOCKED

Human-readable filenames remain metadata/presentation, not internal object identity.

---

## 15. Core path representation

### LOCKED

Core services do not pass untrusted raw absolute host paths as authority.

The platform-neutral path model is conceptually:

```text
AuthorizedRootHandle
+ RelativePathSegments[]
+ operation intent
+ expected target state
```

The host adapter performs final resolution.

### LOCKED

A logical path is serialized independently of the host path separator.

A serialized logical path may use `/` as a canonical presentation separator, but the structured path segments — not the serialized string — are the security input.

---

## 16. Relative path rules

### LOCKED

Agent/tool-provided path components are treated as untrusted data.

Before use they must be validated for:

- empty/invalid components;
- `.` / `..` traversal semantics;
- absolute path forms;
- host namespace prefixes;
- separators embedded in a segment;
- NUL/control characters;
- reserved host names;
- trailing host-ambiguous characters;
- alternate data-stream syntax where relevant;
- path length constraints;
- case/normalization collisions;
- link/mount escape.

Invalid/ambiguous paths fail closed.

---

## 17. Unicode semantics

### LOCKED

SerapeumOS preserves the exact user-visible source filename as metadata where meaningful, while also computing a normalized comparison representation for safety checks.

### LOCKED

Canonical SerapeumOS text serialization uses UTF-8 and Unicode normalization suitable for deterministic comparison, with **NFC as the baseline normalization form** for generated logical names and manifests.

### LOCKED

Normalization must never silently rename an existing Owner resource during direct publication.

Instead:

- exact presentation name is retained;
- target-specific collision checks are performed;
- ambiguity blocks the operation or requires a distinct approved target.

---

## 18. Case semantics

### LOCKED

Case behavior is target-specific and must be discovered/represented by the host adapter.

SerapeumOS does not globally assume:

- Windows paths are always case-insensitive;
- Linux paths are always safely case-distinct in every mounted target.

### LOCKED

Durable identity never depends on filename case.

### LOCKED

Before multi-file publication, the broker detects collisions under the **actual target directory semantics**.

For portable export/package modes, SerapeumOS may apply a stricter cross-platform collision profile so a package cannot contain names likely to collapse when moved to another supported host.

---

## 19. Windows filename/path ambiguity

### LOCKED

The Windows adapter must reject or safely mediate path forms that can reinterpret Agent intent, including:

- DOS device names;
- drive-relative paths;
- UNC/device namespace injection where not explicitly authorized;
- alternate data-stream syntax;
- trailing period/space ambiguity;
- invalid/reserved characters;
- path traversal;
- unexpected reparse traversal.

### LOCKED

The architecture does not depend on legacy `MAX_PATH` behavior.

SerapeumOS-controlled internal paths are intentionally short; user-resource paths are handled through qualified handle/path mechanisms rather than by assuming a 260-character ceiling.

---

## 20. Symlink, junction, reparse and mount semantics

### LOCKED

Managed R0/R1 storage must not depend on symlink/reparse traversal for normal object resolution.

### LOCKED

Agent-supplied relative paths cannot use links to escape an authorized root.

The host adapter must perform containment using host-native safe resolution semantics, not string-prefix checks.

### LOCKED

For R5 Owner resources, a link/reparse/mount target may be used only when the trusted broker can:

1. resolve it safely;
2. prove the final target remains inside the authorized resource boundary or is itself explicitly authorized;
3. bind approval to the resolved target identity/state;
4. revalidate before mutation.

Otherwise the operation fails closed.

### LOCKED

Cross-filesystem/mount transitions are explicit target-boundary events, not invisible path traversal.

---

## 21. Open-handle target identity

### LOCKED

For consequential file operations, the strongest identity evidence comes from an opened object/parent handle plus host-native identity metadata, not from the path string alone.

### LOCKED

The identity evidence is **operation-scoped**, not a permanent SerapeumOS resource ID.

Host file identifiers/inodes can be reused or become invalid across replacement, restore, mount, or host changes.

Therefore they are never durable Company identity.

---

## 22. Windows target identity evidence

### LOCKED

Where available, the Windows adapter uses handle-derived volume + file identifier information as strong same-host object evidence.

For stale-target protection it may combine:

- volume identity;
- 128-bit file identifier where supported;
- file size;
- last-write metadata;
- relevant attributes;
- content digest when required;
- parent directory identity;
- open-handle continuity.

No single metadata field such as timestamp alone is sufficient for consequential overwrite approval.

---

## 23. Linux target identity evidence

### LOCKED

The Linux adapter uses descriptor-based resolution and live file metadata appropriate to the qualified filesystem.

It may combine:

- device/mount identity;
- inode/object identifier;
- size;
- change/modification metadata;
- content digest when required;
- parent directory descriptor/identity;
- open-descriptor continuity.

### LOCKED

`device + inode` is not durable SerapeumOS identity and is not trusted indefinitely after an object is closed/replaced.

---

## 24. Existing-target validation token

### LOCKED

Before a consequential replacement/update, the broker creates an internal **Target Validation Token** conceptually binding:

```text
authorized root/resource
resolved target object identity
resolved parent identity
normalized target name
observed existence/type
observed metadata
content digest where required
validation time/session
operation intent
```

The token is revalidated immediately before commit.

A material mismatch produces `CONFLICT`, not silent overwrite.

---

## 25. New-target validation

### LOCKED

Creating a target that did not exist during approval binds to:

- the resolved authorized parent;
- exact target name under target semantics;
- proof/expectation of absence;
- creation mode/policy.

Commit uses an exclusive no-follow/no-clobber creation primitive where the host can provide it.

If another object appears first, the result is conflict.

---

## 26. Path strings are never stale-target proof

### LOCKED

The following are insufficient by themselves to authorize overwrite:

- same path text;
- same filename;
- same last-modified timestamp;
- same size;
- UI showing the same file icon/name.

Consequential publication uses the stronger MA-09 + MA-17 validation contract.

---

## 27. Publication classes by target capability

### LOCKED

The Host Storage Adapter classifies publication targets by proven semantics.

Minimum classes:

| Class | Meaning |
|---|---|
| **STRONG_LOCAL** | Safe root resolution, stable operation-scoped identity, same-volume staging, durable flush and atomic replace/create semantics can be proven. |
| **VERIFIABLE_NONATOMIC** | Final bytes can be written and strongly verified, but atomic replacement/durability guarantees are weaker or unavailable. |
| **UNVERIFIABLE** | Identity, containment, or resulting bytes cannot be proven strongly enough for the requested operation. |

### LOCKED

`UNVERIFIABLE` targets cannot receive consequential governed publication.

`VERIFIABLE_NONATOMIC` targets require explicit non-atomic/recovery semantics and may be disallowed by risk policy.

---

## 28. Atomic local publication

### LOCKED

For `STRONG_LOCAL` targets, the normal single-file publication algorithm is semantically:

```text
immutable source Artifact
→ open/validate authorized parent and target
→ stage temporary sibling on same target filesystem/volume
→ write exact bytes
→ flush file content/required metadata
→ verify staged digest
→ revalidate target token
→ atomic create/replace through host-native primitive
→ perform required parent/directory durability step
→ reopen/verify resulting target
→ write durable receipt
```

The source Artifact digest and final target digest must match.

### LOCKED

Temporary staging for an atomic replace occurs on the same filesystem/volume as the final target.

Cross-volume copy+delete is not represented as atomic rename.

---

## 29. Windows atomic publication semantics

### LOCKED

The Windows adapter must use handle-aware same-volume replacement/rename primitives whose semantics are qualified for the target filesystem.

The architecture may be implemented using suitable Windows replacement/rename APIs but does not hard-code one function name into core logic.

### LOCKED

Where the platform cannot provide or prove the required atomic replacement behavior for a target, that target is not `STRONG_LOCAL`.

---

## 30. Linux atomic publication semantics

### LOCKED

The Linux adapter uses same-filesystem atomic namespace operations for qualified local filesystems.

For create-without-overwrite semantics, a no-replace primitive is used where qualified.

For replacement, namespace replacement must be atomic from concurrent pathname observers.

Durability after crash also requires the relevant flush ordering; atomic namespace visibility alone is not sufficient proof of persistence.

---

## 31. Durability levels

### LOCKED

SerapeumOS distinguishes:

- **visibility atomicity** — observers do not see an intermediate missing/partial target;
- **persistence durability** — acknowledged bytes/metadata survive the qualified crash/power-loss model;
- **application verification** — resulting bytes/state match intent.

These are separate guarantees.

### LOCKED

A successful write syscall or rename call is not, by itself, a complete publication receipt.

---

## 32. Managed Artifact Store durability

### LOCKED

R1 Artifact payload creation follows:

```text
trusted temporary object
→ complete write
→ durable flush according to store policy
→ strong digest verification
→ immutable final object placement
→ trusted metadata/database reference commit
```

### LOCKED

Artifact object paths are opaque physical details.

The authoritative Artifact identity remains the trusted Artifact record + immutable content identity, not the host pathname.

---

## 33. PostgreSQL host placement

### LOCKED

R0 PostgreSQL active data is placed only on a qualified local managed-state filesystem.

The PostgreSQL data directory:

- is not an Agent workspace;
- is not a cloud-sync folder;
- is not a normal network share baseline;
- is not user-editable project storage;
- is protected by host permissions;
- is backed up/restored only through MA-13-approved procedures.

### LOCKED

SerapeumOS relies on PostgreSQL's database durability/transaction model through a supported deployment configuration; Agents never manipulate its physical data files.

---

## 34. Agent workspace physical model

### LOCKED

R2 `/agents` persistence is provided as a **per-Agent managed virtual block volume**, not an arbitrary shared host-folder mount.

Conceptually:

```text
host-managed opaque workspace volume image
        ↓ attached only to Agent A appliance
Linux-native guest filesystem
        ↓
/agents/<Agent A>/...
```

### LOCKED

Different Agent principals do not concurrently share the same durable workspace volume.

### LOCKED

The workspace volume remains non-authoritative even though it survives appliance replacement/restart.

---

## 35. Agent workspace filesystem semantics

### LOCKED

The Agent appliance sees a stable Linux-style filesystem contract independent of whether the outer host is Windows or Linux.

The reference guest workspace filesystem is **ext4 or an equivalently qualified Linux-native filesystem**.

### LOCKED

The outer image/container format is replaceable implementation detail provided it preserves:

- per-Agent isolation;
- durable attach/detach;
- integrity checks/recovery;
- bounded size/resource governance;
- no arbitrary host mount authority;
- deterministic cleanup/reassignment rules.

### REJECTED

A host folder shared directly into the appliance as the normal durable `/agents` implementation is not accepted as the production baseline.

---

## 36. Workspace attachment identity

### LOCKED

A workspace volume is assigned by trusted identity, not by display name/path.

Attachment binds at minimum:

- Agent principal UID;
- workspace UID;
- expected volume identity/version;
- appliance incarnation;
- attachment mode;
- resource budget.

A mismatched workspace does not mount merely because its filename resembles the expected Agent name.

---

## 37. Workspace reassignment and sanitization

### LOCKED

Before a durable workspace can be attached to a different Agent principal, it must pass a trusted explicit reassignment/sanitization workflow.

Normal operation is one workspace identity → one Agent principal.

### LOCKED

Disposable appliance replacement does not imply workspace destruction.

Conversely, workspace survival never implies that compromised appliance runtime state is trusted.

---

## 38. Workspace corruption

### LOCKED

If the workspace filesystem/image cannot be safely attached or validated:

- the runtime remains unavailable for that workspace;
- the volume is quarantined/recovery-handled under MA-12/MA-13;
- SerapeumOS does not mount it read-write merely to “see if it works.”

Authoritative Company truth remains recoverable independently of workspace recovery.

---

## 39. File locking is not authority

### LOCKED

OS file locks are concurrency aids, not authorization boundaries and not durable identity.

SerapeumOS uses:

1. trusted logical ownership/lease/Action-Assurance state;
2. host-native open/share/lock controls where useful;
3. stale-target revalidation immediately before mutation;
4. post-write verification.

### LOCKED

An OS lock cannot replace digest/identity conflict detection.

---

## 40. Windows locking semantics

### LOCKED

The Windows adapter may use open sharing modes and byte/file locks to reduce concurrent modification during trusted operations.

However:

- lock success is not approval;
- mapped-file or external application behavior may differ;
- a closed/reopened target is revalidated;
- external modification after validation remains a conflict risk handled by the target token.

---

## 41. Linux locking semantics

### LOCKED

Linux advisory locks are treated as coordination between cooperating trusted processes, not enforcement against arbitrary actors with filesystem access.

Therefore SerapeumOS security does not depend on another process honoring a `flock`/`fcntl`-class lock.

Containment and permissions prevent untrusted Agent host access; stale-target validation handles Owner/external concurrency.

---

## 42. Filesystem watchers/events

### LOCKED

Filesystem notification/watch APIs are optimization signals only.

They are not authoritative evidence that:

- no change occurred;
- all events were delivered;
- a path still resolves to the same object;
- publication approval remains valid.

Consequential operations always revalidate state directly.

---

## 43. Timestamps

### LOCKED

Filesystem timestamps are evidence attributes, not identity and not trusted ordering authority.

SerapeumOS uses trusted database/audit event sequencing for domain order.

Filesystem times may assist conflict detection but never act alone.

---

## 44. Clock semantics

### LOCKED

Host wall-clock time is used for human/audit timestamps with explicit timezone/UTC representation.

Timeouts, leases, retry intervals and short-lived security windows use a monotonic clock where required so wall-clock adjustment does not silently extend authority.

### LOCKED

Material clock discontinuity may stale time-sensitive capabilities/approvals and trigger reconciliation rather than silently continuing.

---

## 45. Trusted local IPC

### LOCKED

Trusted control-plane IPC is host-local, authenticated and access-controlled.

Windows and Linux may use different native mechanisms.

The architecture requires:

- no unauthenticated public listener as the trusted control plane;
- peer identity/authorization validation;
- endpoint access restricted to intended trusted Principals/services;
- per-runtime credentials where runtime identity matters;
- restart-safe rebinding/revocation;
- auditability of consequential control operations.

---

## 46. Host ↔ Agent-appliance control channel

### LOCKED

The appliance control channel is separate from normal Agent internet/network egress.

It must provide:

- host-to-specific-appliance binding;
- per-runtime/incarnation authentication;
- replay/reuse resistance appropriate to the protocol;
- no ambient access to other Agents;
- revocation on runtime teardown;
- no dependence on an Agent-controlled credential file that grants broader authority.

### LOCKED

A non-routable VMM-scoped transport is preferred where the selected backend can prove it.

A network-style local transport is not accepted merely for convenience; it must prove equivalent isolation/authentication and remain below the host compatibility adapter.

Exact transport selection is implementation/backend qualification, not domain semantics.

---

## 47. Trusted service supervision

### LOCKED

Production trusted services run under host-native trusted supervision capable of:

- dependency-aware startup;
- bounded restart;
- least privilege;
- explicit stop/force-stop;
- crash status;
- controlled environment/configuration;
- no authority expansion on restart.

Exact Windows service and Linux service-manager packaging belongs to MA-18.

---

## 48. Startup compatibility gate

### LOCKED

Before untrusted execution, startup proves at minimum:

1. trusted configuration is loadable;
2. authoritative stores are available and consistent enough to start;
3. root-secret protection is available;
4. Host Compatibility Profile is current;
5. selected Agent isolation backend is qualified/available;
6. required resource enforcement is available;
7. trusted IPC/control channels are ready;
8. audit/receipt path is available;
9. prior unclean runtime state is reconciled.

Failure blocks the affected mode.

---

## 49. Physical at-rest storage protection

### LOCKED

The Host Compatibility Profile records whether active managed-state storage has qualified **physical at-rest protection** at the volume/block/storage layer.

This protection is defense-in-depth for broad Company, Artifact and Workspace data and is separate from MA-10 application-level encryption of reversible secrets.

### LOCKED

Where Owner/product policy requires physical at-rest protection, R0/R1/R2 may enter normal production service only when the host proves an acceptable encrypted-volume/block/storage mechanism.

The architecture does not hard-code one branded implementation. Windows may use a qualified native volume/device-encryption mechanism; Linux may use a qualified encrypted block/volume mechanism. Exact provisioning, recovery material and prerequisite handling belong to MA-18, with executable proof in MA-20.

### LOCKED

Physical volume encryption does **not** replace:

- MA-10 purpose-bound secret encryption;
- MA-13 backup encryption;
- filesystem permissions;
- Artifact digests/integrity;
- runtime isolation.

If physical-at-rest status is required but unknown/stale/unavailable, the affected production storage profile fails closed rather than silently claiming encrypted-at-rest protection.

---

## 50. Root-secret host capability

### LOCKED

Every production host profile must provide a qualified mechanism to protect the installation root secret without storing it as plaintext beside the database it protects.

The adapter may use host-native OS/TPM/key-store primitives.

### LOCKED

The architecture requires semantic properties, not one branded API:

- access restricted to the trusted SerapeumOS security context;
- no normal plaintext persistence;
- retrieval only when required;
- failure detectable;
- replacement/recovery path compatible with MA-10/MA-13;
- no silent plaintext fallback.

### LOCKED

A host lacking an acceptable protected-root-secret mechanism cannot enter normal protected production mode.

---

## 51. Runtime credential propagation

### LOCKED

Per-runtime credential issuance/revocation uses host mechanisms that can deliver bounded credentials without exposing the installation root secret to the Agent appliance.

After runtime teardown/revocation:

- stale endpoints are invalid;
- cached credentials cannot authorize a new appliance incarnation;
- restart does not silently resurrect old authority.

Exact token/certificate/transport format belongs to implementation under MA-10/MA-18.

---

## 52. Crash-dump and diagnostic protection

### LOCKED

The host adapter/configuration must prevent normal diagnostic behavior from intentionally serializing secret-bearing trusted-process memory into broadly accessible files.

Where a host cannot prevent a class of diagnostic dump safely, that risk is surfaced in qualification and access to resulting diagnostics is tightly controlled.

### LOCKED

SerapeumOS does not require disabling all host diagnostics; it requires secrets/privacy rules to remain true under the qualified diagnostic configuration.

---

## 53. Resource-enforcement host capability

### LOCKED

A host qualifies for a workload only if the resource limits required by MA-11 can be enforced outside the untrusted process tree.

Required classes include, where applicable:

- CPU admission/limit;
- memory ceiling/termination behavior;
- process-tree containment;
- workspace/disk budget;
- concurrent appliance count;
- network isolation/budget;
- GPU visibility/allocation policy;
- host reserve for trusted control/recovery.

### LOCKED

A missing hard limit does not become “best effort” when MA-11 requires hard containment.

The affected workload is refused or runs only in a mode whose policy does not require that capability.

---

## 54. GPU host compatibility

### LOCKED

Direct GPU exposure to hostile Agent appliances remains denied by default.

The host compatibility layer may expose GPU capability to the restricted model-runtime architecture under MA-07/MA-11.

### LOCKED

GPU vendor/API differences do not affect Agent authority or model identity semantics.

Missing GPU capability causes local inference capacity degradation/queuing, not a cloud fallback.

---

## 55. Disk space and storage pressure

### LOCKED

Managed storage adapters publish trusted capacity/free-space evidence to MA-11 resource governance.

Before large consequential writes, SerapeumOS reserves/checks sufficient headroom for:

- staged payload;
- final payload;
- required recovery copy/journal;
- database/artifact consistency overhead;
- trusted recovery reserve where policy requires it.

### LOCKED

Low disk does not justify bypassing recovery preparation, digest verification, or atomic staging.

---

## 56. Storage quotas

### LOCKED

The architecture requires enforceable storage budgets even if the first implementation uses trusted accounting plus host/VMM volume sizing rather than one universal filesystem quota API.

Agent workspace growth cannot consume unlimited host storage.

### LOCKED

If hard quota enforcement is unavailable for a specific store, admission and preallocation/reservation must conservatively prevent uncontrolled growth consistent with MA-11.

---

## 57. Backup target compatibility

### LOCKED

R6 backup targets are independently classified from active R0/R1/R2 storage.

An Owner may select a qualified:

- local fixed secondary volume;
- removable volume;
- Owner-controlled network target;
- other later adapter.

### LOCKED

Backup target suitability must consider:

- write/read verification;
- free space;
- naming/path constraints;
- durability expectations;
- encryption/key recovery compatibility;
- disconnect/interruption behavior;
- restore portability.

A target acceptable for backup is not automatically acceptable as active authoritative storage.

---

## 58. Cloud-synchronized folders

### LOCKED

A folder managed by a third-party/cloud synchronization client is not a qualified baseline for active SerapeumOS authoritative storage.

Reasons include external mutation, placeholder/virtualization behavior, availability, locking, sync races, and non-local data-boundary semantics.

### LOCKED

If the Owner explicitly publishes/backs up a file into such a folder later, SerapeumOS's receipt proves only the qualified **local target operation** unless an explicit external integration separately proves remote synchronization.

The UI must not represent “local file written” as “cloud sync completed.”

---

## 59. Network filesystems and remote shares

### LOCKED

SMB/NFS/other remote shares are not baseline active R0/R1/R2 storage.

For R5 publication or R6 backup they may be supported only through a target profile that proves the semantics needed by the requested action.

### LOCKED

Remote share behavior is not inferred from protocol name alone; server implementation, mount options, disconnection behavior and locking/durability semantics can differ.

Unknown target guarantees downgrade/refuse the operation rather than being assumed local-equivalent.

---

## 60. Removable storage

### LOCKED

Removable storage is not active managed-state baseline.

It may be used for Owner-controlled export/backup when:

- explicitly selected;
- target identity is bound;
- disconnect is treated as a first-class failure;
- write verification completes;
- no claim exceeds proven durability.

---

## 61. Multi-file publication

### LOCKED

General multi-file publication is not falsely represented as one filesystem transaction.

The trusted publication plan records:

- full intended set;
- per-target pre-state;
- per-file commit state;
- recovery state;
- verification state;
- final aggregate state.

### LOCKED

If a host-specific optimization can atomically publish a newly created directory/package as one namespace swap, it may be used only when its full semantics are qualified.

Otherwise partial completion remains visible/recoverable as MA-09 requires.

---

## 62. External application concurrency

### LOCKED

Owner applications may legitimately keep R5 targets open, locked, or modified.

SerapeumOS responds by:

- detecting access denial/share conflict;
- preserving the staged source;
- not forcing destructive takeover;
- revalidating before retry;
- returning conflict/blocked/uncertain state as appropriate.

### REJECTED

SerapeumOS must not require killing arbitrary Owner applications merely to complete a normal file publication.

---

## 63. Antivirus/indexer/filter interaction

### LOCKED

Host security/indexing/filter software may delay, scan or temporarily lock files.

The product must tolerate ordinary interference through bounded retry/failure reporting where safe.

### REJECTED

Production architecture cannot require blanket antivirus/EDR disablement, unrestricted exclusion of all SerapeumOS data, or global security weakening as a normal prerequisite.

Narrow vendor-specific compatibility guidance, if ever necessary, belongs to MA-18/MA-20 evidence and must not violate security doctrine.

---

## 64. Sleep, hibernate and resume

### LOCKED

Sleep/hibernate/resume is a host lifecycle event that may invalidate runtime assumptions.

After resume, trusted orchestration must reconcile as applicable:

- elapsed deadlines/leases;
- runtime process/appliance state;
- network state;
- mounted/attached storage;
- removable resources;
- model runtime state;
- capability expiry;
- host time discontinuity.

### LOCKED

An Agent does not retain authority merely because its process survived sleep.

Time-sensitive/revocable authority is re-evaluated under MA-06/MA-12 semantics.

---

## 65. Host reboot

### LOCKED

Host reboot creates a new trusted boot/session context.

On restart:

- no previous appliance incarnation is assumed live;
- ephemeral capability credentials are not blindly reused;
- attached workspaces are reconciled;
- incomplete publications/recovery journals are reconciled;
- database/artifact consistency is checked;
- paused/uncertain work remains explicit;
- new untrusted work waits until startup compatibility gate passes.

---

## 66. Host update/change detection

### LOCKED

Material host changes can stale qualification evidence.

Examples:

- OS build/kernel change;
- virtualization backend change;
- filesystem conversion/move;
- security-policy change;
- key-store reset;
- CPU virtualization capability change;
- storage driver/filter change material to qualification.

### LOCKED

The product records enough host-profile version evidence to determine when requalification/reprobe is required.

Release-wide compatibility policy belongs to MA-20.

---

## 67. Host resource identifiers are not portable backup identity

### LOCKED

Backups/restores never require the restored host to reproduce:

- the same drive letter;
- the same inode;
- the same Windows file ID;
- the same volume serial;
- the same service SID/account ID;
- the same VMM runtime ID.

Those are host operation evidence, not durable domain identity.

This preserves MA-13 restore portability.

---

## 68. Storage relocation

### LOCKED

Changing active managed storage roots is a trusted migration operation, not a live Agent configuration edit.

The operation must preserve:

- R0/R1 consistency;
- Artifact identity/digests;
- Agent workspace ownership;
- permissions;
- recovery ability;
- audit lineage.

Exact relocation/migration workflow belongs to MA-18.

---

## 69. Host capability publication to the product

### LOCKED

The Owner-facing product receives a safe, factual host capability summary from trusted services.

It may show:

- full/degraded/unsupported mode;
- active host profile;
- unavailable capabilities;
- storage target health;
- isolation availability;
- resource constraints;
- qualification freshness.

### LOCKED

The UI cannot override a failed host-compatibility gate through a generic “continue anyway” action.

This preserves MA-16.

---

## 70. Unknown and stale host evidence

### LOCKED

A compatibility probe result has freshness/provenance.

If material host state changes or evidence cannot be refreshed:

- affected capabilities become `STALE` or `UNKNOWN`;
- security-sensitive new work is blocked;
- current safe work is reconciled according to MA-12;
- the UX reports the specific unavailable guarantee.

---

## 71. Compatibility registry

### LOCKED

Qualified host profiles are versioned product data, not scattered conditionals throughout the codebase.

Conceptually a qualification record identifies:

```text
profile/version
host family/build range
architecture
filesystem class
VMM/backend family/version
required features
proven capabilities
known constraints
qualification evidence references
status
```

### LOCKED

A compatibility entry cannot override a constitutional/MA hard block.

It can only state whether a concrete implementation proves the already-locked contract.

---

## 72. Host adapter versioning

### LOCKED

Host adapters expose a versioned semantic contract.

A core service depends on semantic operations such as:

- `resolve_authorized_target`;
- `create_staged_file`;
- `durably_flush`;
- `atomic_replace_if_unchanged`;
- `verify_target`;
- `protect_root_secret`;
- `start_isolated_runtime`;
- `force_stop_runtime`;
- `apply_resource_limit`.

Exact API names are implementation detail.

### LOCKED

No domain service contains an ad hoc OS-specific bypass when an adapter lacks a capability.

Missing capability is explicit.

---

## 73. Compatibility fallbacks

### LOCKED

Fallback is allowed only when it preserves the same required semantics or explicitly enters a weaker product mode whose limitations are visible and policy-approved.

Examples:

- primary VMM unavailable → another MA-20-qualified backend may be selected;
- GPU unavailable → CPU/local lower-capacity inference if qualified;
- atomic publication unavailable → a policy-permitted journaled non-atomic publication class;
- hard Agent isolation unavailable → `TRUSTED_CORE_ONLY`, not container/prompt isolation pretending to be equivalent.

---

## 74. No ambient shell dependency

### LOCKED

Host compatibility does not require granting the Agent an ambient host shell.

Trusted host administration may invoke OS tools internally where appropriate, but:

- arguments are structured/validated;
- execution is trusted-service controlled;
- Agent text is not interpolated into privileged shell commands as authority;
- results are interpreted through trusted adapters.

---

## 75. Development compatibility is separate

### LOCKED

Developer convenience modes are not production qualification.

Examples that may exist for development only:

- WSL2 tooling;
- direct local process execution;
- loopback development endpoints;
- relaxed filesystem locations;
- test-only secret providers;
- non-production model/runtime shortcuts.

### LOCKED

Development mode must be visibly non-production and cannot silently become the release runtime path.

---

## 76. Host-specific configuration authority

### LOCKED

Only trusted product/installer/admin workflows can change material host settings such as:

- active managed root;
- selected qualified isolation backend;
- service identities;
- root-secret provider;
- resource-enforcement backend;
- recovery storage attachment.

Agents cannot self-modify these settings through generated configuration files.

---

## 77. Host compatibility and System Evolution

### LOCKED

System Evolution may propose a new host adapter/backend/profile, but it cannot self-promote a change that modifies:

- hard isolation guarantees;
- storage containment;
- publication semantics;
- root-secret protection;
- resource enforcement;
- host trust boundary.

Such changes require the applicable MA-15 governed evaluation plus MA-19 provenance and MA-20 qualification.

---

## 78. Host compatibility and supply chain

### LOCKED

A host technology being architecturally compatible does not make its binary/package provenance acceptable.

VMMs, drivers, service binaries, appliance images, filesystem tools and host-adapter dependencies remain subject to MA-19.

Open-source and local-only doctrine remains controlling for SerapeumOS-distributed dependencies.

---

## 79. Host compatibility and installer/update

### LOCKED

MA-18 must implement host prerequisite checks from the MA-17 capability contract rather than inventing separate installer-only requirements.

Installer/update logic may:

- detect missing host features;
- enable/install approved prerequisites with explicit Owner consent where appropriate;
- create protected managed roots;
- initialize root-secret protection;
- provision services;
- migrate storage safely.

It may not weaken MA-17 requirements to complete installation.

---

## 80. Host compatibility and release qualification

### LOCKED

MA-20 must prove each supported profile at minimum across:

- clean install/startup;
- hard Agent boundary;
- force-stop;
- network deny-by-default;
- path traversal/link escape;
- filename/case/Unicode collision;
- target identity/stale overwrite;
- atomic publication and crash recovery;
- disk-full behavior;
- service crash/restart;
- sleep/resume/reboot;
- workspace attach/detach/corruption;
- root-secret failure;
- resource limits;
- backup/restore interoperability;
- hostile/adversarial cases.

Thresholds/matrix evidence belong to MA-20.

---

## 81. Required host capability minimum

### LOCKED

A production profile supporting `FULL_LOCAL_AUTONOMY` must prove all of the following:

1. local trusted-service supervision;
2. protected managed storage root;
3. qualified authoritative DB storage;
4. immutable Artifact Store semantics;
5. per-Agent durable virtual workspace volume;
6. safe path containment;
7. case/Unicode collision handling;
8. symlink/reparse/mount escape prevention;
9. operation-scoped strong target identity;
10. exclusive create/conflict detection;
11. same-volume atomic replacement for `STRONG_LOCAL` publication;
12. durable flush capability;
13. post-write strong digest verification;
14. policy-required physical at-rest storage protection;
15. protected root-secret mechanism;
16. authenticated local trusted IPC;
17. per-runtime appliance control authentication;
18. hard hostile-Agent isolation;
19. independent host force-stop;
20. deny-by-default Agent networking;
21. resource-limit enforcement outside Agent control;
22. controlled workspace attach/detach;
23. crash/reboot reconciliation;
24. evidence-producing compatibility probes;
25. fail-closed behavior for unknown critical capabilities;
26. offline core operation.

---

## 82. Architecture-level veto conditions

An MA-17 implementation is invalid if it:

- makes Windows drive/path semantics part of Company/domain identity;
- treats OS name alone as proof of support;
- lets unknown host capabilities default to allowed;
- uses WSL2 as the production outer hostile-Agent boundary;
- falls back from missing VM isolation to ordinary host process/container execution while claiming equivalent security;
- stores active authoritative state in cloud-sync/network/removable storage as the normal baseline;
- uses FAT/exFAT as the production managed-state baseline;
- uses arbitrary shared host-folder mounts as normal Agent workspace storage;
- exposes PostgreSQL/Artifact Store host paths directly to Agents;
- treats a host path string as durable resource identity;
- permits `..`, symlink/reparse, mount, case or normalization escape from an authorized root;
- relies only on string-prefix checks for containment;
- uses timestamp/size alone as stale-target proof for consequential overwrite;
- claims cross-volume copy+delete is atomic rename;
- reports atomic publication where the target cannot prove it;
- reports success without post-write verification;
- treats OS file locks as AuthZ or as sufficient stale-target protection;
- assumes filesystem watcher completeness as authority;
- claims required physical at-rest protection when the managed volume/block layer is unprotected or unknown;
- silently falls back to plaintext root-secret storage;
- allows missing hard resource enforcement to become unlimited execution;
- requires disabling host security controls as a normal prerequisite;
- treats a development compatibility path as production qualification;
- silently cloud-bursts when local host capability is insufficient;
- makes host file IDs/inodes portable backup/domain identity;
- allows an Agent to select/relocate managed roots or isolation backends;
- lets a UI “continue anyway” bypass failed host security gates.

---

## 83. Explicitly deferred decisions

The following do **not** block MA-17 closure because their governing semantics are now locked:

| Decision | Owner |
|---|---|
| exact Windows VMM binary/backend version | MA-19 / MA-20 |
| exact Linux VMM binary/backend version | MA-19 / MA-20 |
| appliance image builder/packaging | MA-18 / MA-19 |
| exact workspace image container format | MA-18 / MA-20 |
| exact host↔appliance transport implementation | MA-18 / MA-20 |
| exact Windows root-key API/provider | MA-18 / MA-20 |
| exact Linux root-key API/provider | MA-18 / MA-20 |
| exact physical at-rest volume/block encryption implementation | MA-18 / MA-20 |
| specific supported Windows builds/editions | MA-20 |
| specific Linux distributions/kernels | MA-20 |
| minimum RAM/CPU/disk/VRAM numbers | MA-20, persisted in `PREREQUISITES.md` through MA-18 |
| installer path defaults/service identities | MA-18 |
| storage relocation/migration mechanics | MA-18 |
| dependency signatures/SBOM/vulnerability status | MA-19 |
| stress/adversarial/endurance thresholds | MA-20 |

These are implementation/qualification selections beneath the MA-17 contract, not open architecture questions.

---

## 84. MA-17 closure decision

### CLOSED

MA-17 is architecture-complete.

Locked:

- versioned Host Compatibility Profile and fail-closed capability states;
- separation between architecture support and release qualification;
- Windows 11 x86-64 as first qualification target without making core Windows-specific;
- Linux as a parallel architecture-supported host family pending MA-20 profile qualification;
- local fixed qualified filesystems for active managed state;
- NTFS as the first Windows managed-state baseline;
- ext4/XFS as initial Linux managed-state candidates;
- cloud-sync/network/removable filesystems excluded from active R0/R1/R2 baseline;
- structured relative-path contract rather than raw absolute path authority;
- Unicode NFC baseline for generated logical names/manifests;
- target-specific case/collision handling;
- safe symlink/reparse/mount containment;
- operation-scoped handle/object identity for consequential targets;
- stale-target validation tokens;
- exclusive create and conflict semantics;
- strong-local vs verifiable-nonatomic target classification;
- same-volume staged atomic publication where supported;
- durability distinguished from atomic visibility and final verification;
- per-Agent durable virtual block workspace storage with Linux-native guest semantics;
- file locks/watchers/timestamps demoted from authority to supporting evidence;
- local authenticated trusted IPC and per-runtime appliance control authentication;
- required physical at-rest storage-protection capability/policy semantics;
- required host root-secret protection semantics;
- required host resource-enforcement semantics;
- sleep/resume/reboot reconciliation;
- versioned compatibility registry and no unsafe fallback;
- explicit handoff to MA-18/19/20 for packaging, supply chain and executable qualification.

No material MA-17 architecture question remains inside this domain.

---

## 85. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-180 — Host capability, not OS name, defines compatibility
SerapeumOS qualifies a versioned Host Compatibility Profile. Unknown or stale security-critical capabilities fail closed.

### D-181 — Windows 11 x86-64 is the first production qualification target
Windows is the first release host target, while SerapeumOS core remains platform-neutral and Linux remains architecture-supported through the same contract.

### D-182 — Active managed state requires qualified local fixed storage
R0/R1/R2 do not use network shares, cloud-sync folders, removable media, FAT or exFAT as the normal production baseline. NTFS is the first Windows baseline; ext4/XFS are initial Linux candidates.

### D-183 — Core path authority is structured and root-relative
Raw absolute host paths are not authority. Trusted adapters resolve authorized roots plus validated relative path segments and target state.

### D-184 — Host path ambiguity fails closed
Traversal, case/Unicode collision, DOS/device namespace ambiguity, symlink/reparse/mount escape and other host-specific path reinterpretation are rejected or safely broker-resolved before use.

### D-185 — Host file identity is operation-scoped evidence, not durable domain identity
Handle-derived file IDs/inodes/volume metadata strengthen stale-target validation but never become Company/Artifact identity or portable backup identity.

### D-186 — Consequential publication uses staged same-volume commit semantics
Strong local publication stages and verifies exact bytes, revalidates the target, performs qualified same-volume atomic create/replace, applies durability steps, reopens/verifies, then receipts the result.

### D-187 — Atomic visibility, durability and verification are separate guarantees
SerapeumOS never equates a successful write/rename call with a fully verified durable publication.

### D-188 — Agent workspace persistence uses per-Agent virtual block storage
`/agents` is backed by a dedicated Agent-bound virtual block volume with Linux-native guest filesystem semantics; arbitrary shared host folders are not the production baseline.

### D-189 — File locks and filesystem events are advisory/supporting evidence
Locks/watchers/timestamps do not replace AuthZ, Action Assurance, object identity revalidation or content verification.

### D-190 — Root-secret and hard resource controls are host qualification requirements
Protected root-secret storage and externally enforced resource limits are required capabilities; missing controls disable the affected production mode rather than causing plaintext/unlimited fallback.

### D-191 — Host lifecycle changes require reconciliation
Sleep, resume, reboot and material host changes can stale runtime/capability assumptions and trigger trusted revalidation before new untrusted work.

### D-192 — Compatibility fallback may reduce capability, never safeguards
If a qualified backend/capability is unavailable, SerapeumOS may enter a clearly degraded trusted/recovery mode but cannot substitute a weaker boundary while claiming equivalent production security.

### D-193 — MA-20 owns executable platform qualification
MA-17 defines the host contract; MA-20 proves concrete OS/build/filesystem/VMM profiles. Starting successfully is not qualification.

### D-194 — Physical at-rest protection is an explicit host capability
Active managed storage records physical encrypted-at-rest status separately from application secret encryption. Where policy requires it, unproven/unavailable volume or block protection blocks the affected production storage profile.

---

## 86. Project-state transition

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

Current architecture domain:
MA-18 — Install / Update / Migration / Rollback

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Repository persistence:
PENDING

Next action:
MA-18-CLOSE — architecture only
```

---

## 87. Next action

**MA-18-CLOSE — Install / Update / Migration / Rollback**

Architecture only.

---

## Appendix A — Non-normative host semantic grounding

The MA-17 contract is intentionally stronger than any one operating-system API. Its host-specific mappings are grounded in current platform semantics including:

- Windows handle-based file identity using volume + file identifiers;
- Windows reserved-name/path namespace behavior and per-directory case sensitivity;
- Windows reparse-point semantics;
- Windows buffer flush and same-volume replacement semantics;
- Linux atomic rename namespace semantics;
- Linux `fsync` durability semantics;
- Linux descriptor-relative containment primitives such as `openat2` resolution constraints;
- the advisory nature of normal Linux file locks.

These references are implementation evidence, not replacements for MA-20 executable qualification.
