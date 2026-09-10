# MA-18 — Install / Update / Migration / Rollback

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED  
**Runtime prototypes:** PAUSED  
**Repository persistence:** PENDING

---

## 1. Purpose

MA-18 defines the trusted lifecycle by which SerapeumOS is installed, initialized, updated, migrated, repaired, rolled back, reinstalled, and uninstalled without weakening the architecture closed in MA-01 through MA-17.

It governs:

- first installation and first-run boundaries;
- prerequisite admission and host preparation;
- installation identity and protected layout;
- trusted maintenance authority and privilege boundaries;
- immutable/versioned product generations;
- update intake, staging, activation, and finalization;
- persistent-state compatibility and migration;
- database/schema/engine migration semantics;
- Artifact Store, Agent Workspace, configuration, protocol, and cryptographic migration;
- managed-storage relocation;
- rollback classes and anti-downgrade rules;
- incomplete-update/crash/reboot recovery;
- repair, reinstall/adoption, uninstall, and destructive purge;
- lifecycle audit/receipt requirements;
- handoff to MA-19 supply-chain controls and MA-20 executable qualification.

MA-18 does **not** define dependency provenance, package signing roles, SBOM/license policy, vulnerability intake, exact release-test thresholds, or the final supported host/version matrix. Those belong to MA-19 and MA-20.

---

## 2. Governing principle

### LOCKED

> **Software generations are replaceable; installation identity and authoritative Company state are not.**

An update may replace trusted executable/runtime assets only through a governed lifecycle that preserves or explicitly migrates durable state.

No installer/updater may treat the installation directory as the product's single source of truth.

---

## 3. Core lifecycle invariant

### LOCKED

SerapeumOS separates:

```text
versioned trusted software generation
        ≠
installation identity
        ≠
authoritative persistent state
        ≠
recovery state
        ≠
Owner/user resources
```

Consequences:

- changing binaries does not create a new Company;
- changing a schema does not change Company/Agent identity;
- an uninstall does not silently erase Company state;
- restoring Company state does not silently downgrade executable code;
- an old executable cannot be launched against incompatible new persistent state merely because its files remain present.

---

## 4. Lifecycle architecture boundary

### LOCKED

The lifecycle architecture is conceptually:

```text
Owner / trusted administrative intent
            │
            ▼
Trusted Maintenance Plane
  ├── prerequisite / host-profile gate
  ├── release-admission gate
  ├── installation journal
  ├── migration orchestrator
  ├── generation staging / activation
  ├── repair / uninstall controller
  └── recovery handoff
            │
            ├────────► MA-17 Host Adapters
            ├────────► MA-19 Supply-Chain Verification
            ├────────► MA-20 Release Qualification Evidence
            ├────────► MA-13 Backup / Restore
            └────────► Trusted Runtime / Durable Stores
```

Untrusted Agents, models, generated code, extensions, browser workloads, and ordinary Workers are outside this maintenance authority.

---

## 5. Lifecycle operations are trusted operations

### LOCKED

The following are trusted installation-global operations:

- install;
- prerequisite provisioning that changes host state;
- service registration;
- root-secret bootstrap/rotation associated with installation state;
- product update;
- persistent-state migration;
- database-engine migration;
- managed-storage relocation;
- repair of trusted product assets;
- product rollback;
- uninstall;
- destructive purge.

Agents may discover or propose that an update is useful, but they cannot grant themselves maintenance authority or execute privileged lifecycle changes directly.

---

## 6. Maintenance authority

### LOCKED

SerapeumOS defines a trusted **Maintenance Principal / Maintenance Plane** distinct from ordinary Agent execution.

It receives only the host privileges necessary for the bounded lifecycle operation being performed.

### LOCKED

Normal day-to-day SerapeumOS UI/runtime processes do not remain permanently elevated merely because updates may eventually require elevation.

Privilege is obtained only through a trusted host mechanism for the specific maintenance transaction.

---

## 7. First-install trust root

### LOCKED

Before a SerapeumOS Company/Owner domain exists, first installation is authorized by:

1. the local human/administrator intentionally initiating installation;
2. host administrative authorization where required;
3. MA-19-qualified release/package provenance;
4. MA-17 host-capability checks.

After bootstrap, normal update/migration authority becomes subject to SerapeumOS Owner/governance and MA-06 Action Assurance in addition to host authorization.

### LOCKED

First-install privilege is not a permanent bypass of later SerapeumOS governance.

---

## 8. Installation identity

### LOCKED

Every initialized SerapeumOS installation has a stable internal `installation_uid`.

It survives:

- product updates;
- repair;
- supported reinstall/adoption;
- storage relocation;
- host replacement when recovered through MA-13.

A fresh destructive purge followed by a new initialization creates a new installation identity unless an explicit recovery/adoption path restores the prior identity.

### LOCKED

Host service IDs, drive letters, paths, file IDs, and OS machine identifiers are not the durable installation identity.

---

## 9. Installation lifecycle record

### LOCKED

Trusted durable state must be able to reconstruct an **Installation Lifecycle Record** conceptually containing:

```text
installation_uid
current_product_generation
last_known_good_generation
current_state_vector
last_known_good_state_vector
host_compatibility_profile/version
release/provenance evidence references
maintenance_transaction state
migration_journal state
rollback/security floor
managed-root identities
root-key hierarchy version references
service/runtime contract versions
last successful lifecycle verification
```

Exact schema is implementation design.

### LOCKED

Enough reconstruction metadata must exist outside any single fragile runtime process so an interrupted maintenance transaction can be recognized after restart.

---

## 10. Protected installation layout

### LOCKED

The installation layout separates at least:

| Logical area | Purpose | Mutability |
|---|---|---|
| **Code / Release Root** | versioned trusted executables, libraries, appliance/runtime assets | immutable per generation after staging |
| **Bootstrap / Maintenance Root** | minimum trusted lifecycle/activation components | tightly controlled |
| **Managed State Root** | MA-09 R0/R1/R2 and required reconstruction state | mutable only through owning trusted services |
| **Derived State Root** | R3 rebuildable projections/caches | rebuildable |
| **Staging / Quarantine Root** | candidate releases/migration staging | temporary, non-authoritative |
| **Recovery Root(s)** | MA-13 R6 recovery material | protected and independent according to policy |
| **Owner/User Resources** | R5 external files | outside installation ownership |

### LOCKED

Product code and authoritative mutable data are not intermingled in a way that requires overwriting live Company state to replace executable code.

---

## 11. Default host placement

### LOCKED

Default placement follows host conventions while preserving the logical separation above.

For the first Windows qualification family:

```text
protected machine code root:
  Program Files-class machine installation location

protected machine mutable/reconstruction state:
  ProgramData-class machine state location or Owner-selected qualified fixed NTFS managed root

Owner publications / ordinary user files:
  remain outside SerapeumOS managed-state roots unless explicitly imported/published
```

For Linux qualification families:

```text
protected application code:
  /opt or distribution-equivalent application root

machine mutable state:
  /var/lib or Owner-selected qualified managed root

minimal host configuration/bootstrap metadata:
  /etc or distribution-equivalent protected configuration root where applicable
```

Exact basename strings are implementation details, but these placement classes are locked.

### LOCKED

Changing a path default does not change durable Company or Artifact identity.

---

## 12. Service-principal model

### LOCKED

Production installation uses dedicated non-interactive trusted service identities with least privilege.

Conceptually distinct authority exists for:

- persistent trusted SerapeumOS core/service execution;
- database execution where separately hosted;
- maintenance/elevated lifecycle operations;
- hostile-appliance/VMM control where separately privileged.

### LOCKED

`LocalSystem`, root, or an interactive Owner account is **not** the default identity for every SerapeumOS service merely for convenience.

The exact Windows service-account mechanism and Linux account names are host implementation choices subject to MA-20 qualification.

---

## 13. Immutable release generations

### LOCKED

A trusted SerapeumOS software release is installed as an immutable **Release Generation**.

A generation contains the executable/runtime assets that must remain internally consistent for that release.

After staging and verification, its contents are not patched in place during normal update.

### LOCKED

An update normally creates a new generation beside the current generation, validates it, then changes trusted activation state.

The architecture does not depend on overwriting files belonging to a running process.

---

## 14. Delta updates do not change the authority model

### LOCKED

A future delta/differential update may reduce transfer/storage cost, but it is only a transport/reconstruction optimization.

Before activation, the Maintenance Plane must reconstruct and verify the complete target Release Generation against the accepted release identity.

### LOCKED

Applying byte patches directly to the currently active executable tree is not the normal production update model.

---

## 15. Stable activation boundary

### LOCKED

A small trusted activation/bootstrap mechanism selects which qualified Release Generation is active.

Conceptually:

```text
stable trusted bootstrap
      │
      └── active_generation = G_n
                │
                └── launch qualified product generation
```

Changing the selected generation must use MA-17-qualified atomic/durable host semantics appropriate to the activation record.

### LOCKED

The activation mechanism must never select a generation whose compatibility/admission gates are not satisfied.

Exact launcher/service implementation is host-specific and belongs to implementation/MA-20.

---

## 16. Bootstrap self-update

### LOCKED

The maintenance/bootstrap component may itself require replacement.

Its update must use a bounded two-stage host-native replacement/restart mechanism that ensures after interruption the host can determine one of:

- old bootstrap remains authoritative;
- new bootstrap is fully committed;
- maintenance recovery is required.

It must not leave an ambiguous half-replaced bootstrap while reporting installation success.

Exact host mechanism belongs to implementation and MA-20 qualification.

---

## 17. One scalar product version is insufficient

### LOCKED

Compatibility is determined from a versioned **Persistent State Vector**, not only from the visible product version.

Conceptually the vector contains, as applicable:

```text
product_generation_version
installation_layout_version
control_protocol_version
database_engine_version
database_schema_version
artifact_store_format_version
agent_workspace_format_version
configuration_schema_version
secret_key_hierarchy_version
audit_receipt_format_version
appliance_contract_version
host_compatibility_profile_version
extension_api/abi contract version(s)
```

Exact fields may evolve, but the multi-axis principle is locked.

---

## 18. Release Compatibility Contract

### LOCKED

Every admitted Release Generation must carry/resolve a trusted **Release Compatibility Contract** sufficient to determine:

- which source state vectors it can consume directly;
- which source state vectors have an approved migration path;
- target state vector after migration;
- required MA-17 host capabilities/profile freshness;
- required database/runtime/appliance compatibility;
- required migration steps and ordering;
- whether maintenance downtime/quiescence is required;
- whether host reboot is required;
- rollback class;
- minimum recovery prerequisites;
- required temporary disk/resource headroom;
- security/downgrade floor information supplied through MA-19 policy;
- MA-20 qualification evidence expected for the transition.

Cryptographic signing/provenance of this contract belongs to MA-19.

---

## 19. Compatibility is a graph, not an assumption

### LOCKED

A release may be activated only through an explicitly supported transition edge.

```text
state A ──qualified edge──► state B
```

The system does not infer that because:

```text
A → B is supported
B → C is supported
```

therefore:

```text
A → C
```

is automatically safe.

Skipping one or more releases is allowed only when a direct qualified transition or an explicitly composed migration sequence is declared and admitted.

---

## 20. Install/update lifecycle states

### LOCKED

The Maintenance Plane uses explicit durable lifecycle states.

A canonical update transaction is conceptually:

```text
CANDIDATE_RECEIVED
→ QUARANTINED
→ SUPPLY_CHAIN_VERIFIED
→ RELEASE_ADMISSIBLE
→ HOST_PREFLIGHT_PASSED
→ COMPATIBILITY_PLAN_READY
→ RECOVERY_READY
→ GENERATION_STAGED
→ QUIESCING
→ QUIESCED
→ MIGRATING
→ MIGRATION_VERIFIED
→ ACTIVATING
→ POST_ACTIVATION_VALIDATION
→ COMMITTED
→ FINALIZED
```

Failure branches include explicit states equivalent to:

```text
REJECTED
FAILED_BEFORE_MUTATION
FAILED_RECOVERABLE
ROLLBACK_ELIGIBLE
ROLLBACK_IN_PROGRESS
RECOVERY_REQUIRED
QUARANTINED_FAILURE
```

Exact names are implementation design; explicit durable phase semantics are architecture.

---

## 21. No success before finalization evidence

### LOCKED

“Installed”, “updated”, “migrated”, “rolled back”, “repaired”, or “uninstalled” is not reported as successful merely because a command exited zero.

Success requires the applicable:

- postconditions;
- state-vector verification;
- host/service readiness;
- integrity checks;
- audit/receipt persistence;
- rollback/recovery-state update;
- MA-20-defined release health checks.

This preserves MA-14 and the execution-evidence doctrine.

---

## 22. Global maintenance fence

### LOCKED

Only one installation-global maintenance transaction may hold mutation authority at a time.

A trusted **Maintenance Fence** prevents concurrent:

- update;
- schema migration;
- storage relocation;
- repair that changes trusted assets;
- rollback;
- uninstall/purge.

### LOCKED

The fence is not implemented solely as an advisory filesystem lock.

It requires trusted durable transaction state plus qualified host mutual-exclusion/process ownership semantics.

After crash, stale ownership is reconciled rather than permanently blocking the installation.

---

## 23. First-install preflight

### LOCKED

Before creating authoritative state, first installation verifies at minimum:

- supported host family/architecture;
- MA-17 capability profile status;
- qualified local fixed managed-storage target;
- required storage semantics;
- sufficient initial and recovery disk headroom;
- required hard isolation capability for the intended operating mode;
- protected root-secret capability;
- required physical at-rest protection policy status;
- trusted service/IPC capability;
- resource-enforcement capability;
- absence of conflicting/non-empty target state unless adoption/repair was explicitly selected;
- MA-19 release/package acceptance;
- MA-20 release qualification for the selected host profile.

### LOCKED

Unknown critical prerequisite state is not treated as passing.

---

## 24. Host prerequisite provisioning

### LOCKED

Installer/update prerequisite checks consume the MA-17 Host Compatibility Contract.

The Maintenance Plane may, with explicit trusted authorization where appropriate:

- enable an approved host feature;
- install an approved local prerequisite;
- create protected directories/volumes;
- register trusted services;
- configure required ACLs/permissions;
- request a host reboot.

### LOCKED

It may not:

- disable host security controls to force compatibility;
- substitute a weaker isolation/storage/key mechanism while claiming full production support;
- silently install unrelated software;
- invent installer-only security exceptions inconsistent with MA-17.

Dependency provenance/licensing remains MA-19.

---

## 25. Physical at-rest protection provisioning

### LOCKED

MA-18 owns lifecycle handling for the MA-17 physical at-rest protection requirement.

The installer must distinguish:

- protection already proven;
- protection available but Owner action/consent required;
- protection unavailable;
- protection unknown.

### LOCKED

Where policy requires protected-at-rest storage, installation may not mark the affected production storage profile ready until protection is proven.

### LOCKED

The product must not silently enable whole-volume encryption in a manner that hides recovery-key/recovery-impact consequences from the Owner.

Exact Windows/Linux mechanism is subject to MA-20 host qualification.

---

## 26. Installation root-secret bootstrap

### LOCKED

First installation initializes the MA-10 installation root-secret hierarchy through the qualified host protection adapter before secret-dependent production services become ready.

The root secret:

- is never distributed inside a release/update package;
- is not stored plaintext beside the database;
- is not exposed to Agents;
- is not recreated during ordinary update/repair merely because product binaries changed.

### LOCKED

If existing encrypted state is present but its root-secret hierarchy cannot be recovered, repair/reinstall must fail into recovery guidance rather than silently generating a replacement key and orphaning protected state.

---

## 27. Initial database and managed-store bootstrap

### LOCKED

Initial R0/R1/R2 structures are created only after host and key prerequisites pass.

Bootstrap establishes:

- authoritative database/storage identity;
- initial schema/state vector;
- Artifact Store root and integrity rules;
- Agent Workspace storage pool/container policy;
- reconstruction metadata;
- audit/receipt baseline;
- service ownership/permissions.

### LOCKED

Initialization is all-or-recoverable: a failed partial first install cannot be mistaken for an active production installation.

---

## 28. First run is not the privileged installer

### LOCKED

The privileged installer establishes machine/runtime prerequisites and protected storage.

Product first run handles product-domain onboarding such as Owner/Company bootstrap under MA-03/MA-16.

The normal product UI does not need broad machine-administrator privilege merely to complete organizational onboarding.

---

## 29. Production admission after install

### LOCKED

No untrusted Agent work is admitted immediately after file copy/installation.

The new installation enters trusted startup qualification and must prove:

- host profile current;
- trusted services ready;
- state vector coherent;
- root-secret access valid;
- database/store integrity valid;
- required audit path available;
- hard Agent boundary available for the selected mode;
- release qualification applicable.

Only then may the installation enter its allowed production mode.

---

## 30. Update acquisition is separate from update authority

### LOCKED

How an update package arrives does not grant it authority.

A candidate may arrive through:

- Owner-selected local file/media;
- locally managed repository/cache;
- future explicitly authorized network retrieval adapter.

Regardless of transport, candidate bytes remain untrusted until MA-19 verification and MA-18/20 admission complete.

### LOCKED

Normal SerapeumOS operation must not require a cloud update service.

Offline update/import remains a first-class architecture path.

---

## 31. Update staging and quarantine

### LOCKED

Candidate packages are copied/received into a bounded staging/quarantine area before execution or activation.

Staging must enforce:

- declared/limited size/resource consumption;
- path/filename containment;
- no execution during metadata/content inspection;
- digest/provenance verification through MA-19;
- complete component inventory;
- target-release identity binding.

A failed candidate remains non-authoritative and cannot alter the active generation.

---

## 32. Supply-chain gate is mandatory but owned by MA-19

### LOCKED

MA-18 consumes an explicit MA-19 verdict/evidence that the candidate release is acceptable for installation.

It does not replace MA-19 with a weaker check such as:

- matching filename;
- HTTPS transport alone;
- a single unchecked hash copied beside the package;
- “downloaded from official website” text;
- Owner familiarity with the source.

Exact signing roles, metadata, SBOM, license and vulnerability policy belong to MA-19.

---

## 33. Release qualification gate is mandatory but owned by MA-20

### LOCKED

A supply-chain-valid package is not automatically a release-qualified package for this installation.

MA-18 also requires applicable MA-20 evidence for:

- release identity;
- host profile;
- migration edge;
- storage/runtime combination;
- rollback/recovery semantics.

An unqualified candidate may be retained for development/evaluation but cannot be silently activated as production.

---

## 34. Update preflight

### LOCKED

Before mutation of active durable state, the update transaction determines:

- current installation/state vector;
- target release/state vector;
- supported migration path;
- host-profile compatibility and freshness;
- current health of R0/R1/R2/recovery metadata;
- key/secret accessibility;
- extension/runtime compatibility consequences;
- disk/resource headroom;
- required downtime;
- reboot requirement;
- recovery-anchor requirement;
- rollback class and rollback floor;
- pending/non-terminal operations that must be drained/reconciled;
- required Owner approval/policy.

If the complete transition cannot be planned, the update does not start mutation.

---

## 35. Disk/resource headroom

### LOCKED

An update/migration must account for temporary resource demand, including as applicable:

- staged release generation;
- database copy/upgrade target;
- pre-update recovery anchor;
- workspace conversion copies;
- Artifact Store metadata conversion;
- logs/journals/evidence;
- rollback-retained generation.

### LOCKED

If safe temporary capacity cannot be established, the update is refused before destructive migration rather than relying on “probably enough disk”.

Exact thresholds belong to MA-20/`PREREQUISITES.md`.

---

## 36. Quiescence and maintenance mode

### LOCKED

Persistent-state migrations that cannot prove safe concurrent old/new access require trusted quiescence.

Canonical flow:

```text
deny new untrusted work
→ drain/cancel according to MA-12
→ fence new consequential actions
→ reconcile outstanding side effects
→ checkpoint durable state
→ stop affected trusted writers
→ prove QUIESCED
→ migrate
```

### LOCKED

“Process stopped” alone is not proof that the installation is safely quiesced; durable execution and side-effect state must also be reconciled.

---

## 37. Online migration is opt-in by proof

### LOCKED

The architecture does not assume zero-downtime migration.

A migration may run while some services remain active only if its compatibility contract explicitly proves the affected old/new readers/writers can coexist without violating invariants.

Otherwise maintenance-mode quiescence is mandatory.

### LOCKED

A future expand/migrate/contract strategy is permitted, but every coexistence phase remains versioned and qualified.

---

## 38. Recovery anchor before consequential migration

### LOCKED

Before any update that can make existing authoritative/recovery-critical state incompatible with the current release, the system requires a **Pre-Update Recovery Anchor**.

This anchor must be independently verifiable and sufficient to execute the declared rollback/recovery plan.

It may be built from MA-13 Backup Set(s), qualified snapshots/clones, or another MA-13-compliant recovery mechanism.

### LOCKED

The old live data directory itself is not automatically a valid rollback anchor merely because it existed before migration.

---

## 39. Recovery-anchor independence

### LOCKED

A migration optimization must not silently destroy rollback independence.

Hard-link/shared-block/clone/swap techniques may be used only when their qualified semantics preserve the declared recovery guarantee.

If writes to the new target can mutate or invalidate the supposed old recovery copy, that copy cannot be the sole rollback anchor.

### LOCKED

Destructive performance optimization never outranks recoverability.

---

## 40. Migration authority

### LOCKED

All production persistent-state migrations are trusted product operations under the Maintenance Plane.

Agents cannot run production migrations merely because they generated:

- SQL;
- scripts;
- migration code;
- filesystem transforms;
- extension upgrade commands.

Generated migration logic becomes trusted only after normal repository review, MA-19 provenance/build control, MA-20 qualification, and MA-18 packaging/admission.

---

## 41. Migration step contract

### LOCKED

Every material migration step is versioned and declares at minimum:

```text
migration_step_id
source_state predicate
target_state result
owned state domain(s)
preconditions
required quiescence/coexistence mode
resource requirements
recovery-anchor requirement
reversibility class
idempotency/resume semantics
checkpoint/fence semantics
postconditions
verification evidence
failure state / next legal action
```

Exact representation is implementation design.

---

## 42. Migration journal

### LOCKED

Migration progress is durably journaled by trusted code.

After crash/reboot, startup can determine which steps are:

- not started;
- prepared;
- in progress with known checkpoint;
- committed;
- verified;
- failed before commit;
- ambiguous/recovery-required.

### LOCKED

A migration step must not be replayed blindly if replay could duplicate a consequential mutation.

It must be idempotent, resume-aware, fenced, or explicitly stop for recovery.

---

## 43. Schema migration semantics

### LOCKED

Database schema evolution uses explicit versioned migrations owned by the relevant trusted domain.

Schema migration must preserve:

- stable durable identities;
- domain authority boundaries;
- referential integrity;
- audit/provenance meaning;
- artifact identity;
- Company separation;
- migration history.

### LOCKED

A schema version is not advanced until the step's declared postconditions are proven.

---

## 44. Down-migrations are not assumed

### LOCKED

Every forward schema migration does **not** need an executable reverse SQL migration.

A migration's rollback class must explicitly be one of the conceptual classes:

- directly reversible;
- backward-compatible without state reversal;
- recoverable only from a pre-update recovery anchor;
- forward-repair only after commit.

### LOCKED

If reverse migration is not qualified, the updater must not improvise one during failure.

---

## 45. Database-engine major upgrades

### LOCKED

A database-engine major-version transition is a distinct trusted migration, not a normal binary replacement.

It must establish:

- old/new engine compatibility requirements;
- extension/module compatibility;
- data-format transition method;
- independent recovery anchor;
- shutdown/quiescence ordering;
- migration verification;
- post-upgrade integrity/readability;
- old-generation usability/rollback consequences.

### LOCKED

A destructive database-upgrade mode that renders the old cluster unusable may not be the sole rollback strategy.

Exact PostgreSQL upgrade mechanism is implementation/MA-20 territory.

---

## 46. Database startup compatibility

### LOCKED

A product generation must not start the authoritative database in write-capable production mode until it has proven the database engine/schema state is compatible with that generation.

Unsupported too-new or too-old state fails into maintenance/recovery rather than “trying anyway”.

---

## 47. Artifact Store migration

### LOCKED

Artifact Store format migrations preserve MA-09 immutable content identity.

Where raw artifact bytes remain semantically identical, migration should preserve their existing Artifact identity/digest relationships.

If migration materially changes payload bytes/content semantics, the result becomes a new Artifact/version according to MA-09 rather than silently rewriting bytes under the same identity.

### LOCKED

Rebuildable indexes/projections may be discarded and recreated rather than migrated as authoritative data.

---

## 48. Agent Workspace migration

### LOCKED

R2 Agent Workspace migration is governed separately from R0/R1 authoritative state.

A workspace-format transition must preserve:

- Agent workspace ownership binding;
- path containment;
- per-Agent isolation;
- durable continuity where supported;
- backup/recovery policy;
- attach/detach integrity.

### LOCKED

Workspace migration failure may degrade the affected Agent continuity, but it must not corrupt or redefine authoritative Company state.

The system may quarantine a damaged/incompatible workspace and reconstruct a clean workspace from authoritative inputs where policy permits.

---

## 49. Workspace container format

### LOCKED

Production R2 remains a per-Agent virtual block-storage container exposing qualified Linux-native guest filesystem semantics as established by MA-17.

The host container format may differ between qualified host implementations, but each format must support:

- exclusive Agent ownership/attachment;
- crash-safe detach/recovery semantics;
- bounded size/resource accounting;
- backup/restore integration;
- migration/version identification;
- corruption detection sufficient for MA-20 qualification.

Exact VHD/VHDX/QCOW/raw/container choice is an implementation/MA-20 selection and is not domain architecture.

---

## 50. Configuration migration

### LOCKED

Product configuration is treated as versioned trusted data, not as arbitrary mutable files mixed into the release generation.

Update semantics distinguish:

- immutable release defaults;
- installation configuration;
- Company/Owner policy;
- secret references;
- derived runtime configuration.

### LOCKED

A product update may introduce new defaults but cannot silently overwrite explicit Owner policy with a new default unless a separately governed compatibility/security rule requires it and the change is surfaced/audited.

---

## 51. Secret/key hierarchy migration

### LOCKED

Product update does not automatically rotate or replace the installation root secret.

If a release requires a key-hierarchy/cryptographic-state migration, it is a dedicated trusted migration under MA-10 with:

- old/new key version tracking;
- bounded transition state;
- recovery compatibility;
- no plaintext intermediate storage;
- explicit post-migration verification.

### LOCKED

Failure to access required old key material blocks migration; the updater does not reset credentials to make progress.

---

## 52. Protocol/IPC contract migration

### LOCKED

Trusted services, Agent Appliances, Workers, and model/runtime brokers communicate through versioned contracts.

An update may activate a mixed old/new process set only when the relevant protocol versions explicitly support coexistence.

Otherwise affected processes are quiesced and restarted as one compatible generation set.

### LOCKED

Unknown protocol compatibility fails closed.

---

## 53. Appliance/runtime asset migration

### LOCKED

Qualified appliance images, VMM/runtime helpers, and trusted sidecar assets are versioned Release Generation assets, not mutable Agent state.

An update can replace them without altering Agent identity.

### LOCKED

A new appliance image may attach an existing Agent workspace only after its appliance/workspace contract is compatible or the workspace has completed its declared migration.

---

## 54. Extensions / Skills / Plugins during core update

### LOCKED

Core update preflight evaluates installed trusted extension compatibility through MA-08 contracts.

An incompatible extension cannot be silently loaded into the new trusted generation.

Depending on extension criticality and policy, the update must either:

- block until a compatible qualified extension exists;
- disable/quarantine the optional incompatible extension with explicit Owner-visible consequence;
- migrate it through an approved path.

### LOCKED

A core update never grants a previously installed extension broader capabilities merely because its version changed.

Supply-chain qualification of extension updates belongs to MA-19.

---

## 55. Model assets are not authoritative migration blockers by default

### LOCKED

Local model files are qualified runtime assets, not Company truth.

A core product update may preserve existing model artifacts when compatible, reindex/re-register them where needed, or mark them incompatible/unavailable.

It must not delete large Owner-downloaded model assets merely because the product generation changed unless explicit lifecycle policy authorizes removal.

Model/provider compatibility remains governed by MA-07 and MA-20.

---

## 56. Managed-storage relocation

### LOCKED

Changing the active managed root is a trusted MA-18 migration.

Canonical semantics are:

```text
qualify destination under MA-17
→ compute capacity / protection requirements
→ establish maintenance fence
→ create recovery anchor as required
→ quiesce affected writers
→ copy/migrate R0/R1/R2 + reconstruction metadata
→ verify destination integrity/ownership/digests
→ atomically commit trusted root-selection metadata
→ restart/revalidate against destination
→ retain old source as protected rollback material until finalization policy permits cleanup
```

### LOCKED

An Agent cannot choose or relocate managed roots.

---

## 57. Cross-volume relocation is migration, not rename

### LOCKED

SerapeumOS never claims a cross-volume storage move is atomic merely because the source eventually disappears.

Cross-volume relocation uses copy/verify/cutover semantics with explicit rollback/recovery state.

This preserves MA-17 atomicity doctrine.

---

## 58. Activation

### LOCKED

After required persistent migrations verify successfully, the Maintenance Plane may select the new Release Generation for trusted startup.

Activation binds:

- exact release generation;
- resulting Persistent State Vector;
- host profile/evidence;
- migration transaction;
- release qualification/provenance references;
- rollback class.

### LOCKED

Activation is not yet final update success.

---

## 59. Post-activation validation

### LOCKED

The new generation starts first in a trusted **post-update validation state**.

Before full autonomy resumes it verifies, as applicable:

- trusted services/process topology;
- database engine/schema readability and invariants;
- Artifact Store consistency;
- Agent Workspace attachability/containment;
- secret/root-key access;
- audit/receipt persistence;
- host capability/profile freshness;
- hard isolation/runtime admission;
- protocol compatibility;
- required MA-20 release health criteria.

Untrusted Agent execution remains blocked until the relevant admission gate passes.

---

## 60. Update commit and finalization

### LOCKED

An update becomes **COMMITTED** only after the target generation and resulting state vector pass post-activation validation.

Finalization may then:

- mark the generation/state tuple as current qualified state;
- update last-known-good metadata;
- close the maintenance transaction;
- schedule rebuild of R3 derived state;
- release normal runtime admission;
- retain/remove old generation and pre-update recovery assets according to rollback/backup policy.

### LOCKED

Cleanup is after commit, not before rollback eligibility is established.

---

## 61. Last Known Good is a tuple

### LOCKED

`Last Known Good` is not merely an old version number.

It conceptually binds:

```text
release_generation
+ compatible persistent_state_vector
+ host_profile/qualification context
+ required reconstruction/key state
+ evidence that the tuple actually reached qualified service
```

### LOCKED

A previous generation whose schema compatibility is no longer satisfied is not a valid Last Known Good launch target even if its executable files remain intact.

---

## 62. Rollback taxonomy

### LOCKED

MA-18 distinguishes at least four rollback classes:

| Class | Meaning |
|---|---|
| **RLB-1 Activation rollback** | revert executable generation without reverting durable state because prior generation is still qualified against current state |
| **RLB-2 Reversible migration rollback** | execute a prequalified inverse/compensation path for a bounded state migration |
| **RLB-3 Recovery-point rollback** | restore a pre-update MA-13 recovery point in isolation and promote after validation/reconciliation |
| **RLB-4 Forward repair only** | state has crossed a commit point where neither older code nor reverse migration is safe; recovery uses forward repair or an explicit recovery-point restore |

The exact names are implementation design; the semantic distinction is locked.

---

## 63. Activation-only rollback

### LOCKED

Fast automatic rollback to the previous Release Generation is permitted only when the previous generation is still qualified for the **current** Persistent State Vector.

This normally applies to binary-only/backward-compatible updates or to migrations whose compatibility window intentionally supports both generations.

### LOCKED

The updater must not start an old generation against an incompatible new schema merely to regain UI availability.

---

## 64. Reversible migration rollback

### LOCKED

A migration may be reversed in place only if the exact inverse path is declared, tested, and qualified for that source/target pair.

Rollback must preserve:

- identity;
- audit/history;
- integrity;
- external-side-effect truth;
- migration receipts.

### LOCKED

Rollback does not erase evidence that the failed generation/migration was attempted.

---

## 65. Recovery-point rollback

### LOCKED

When persistent state is no longer backward-compatible and no safe inverse migration exists, rollback means MA-13 recovery:

```text
select pre-update recovery point
→ restore into isolated recovery target
→ validate under compatible/current software path
→ reconcile external-world divergence
→ explicit trusted promotion
→ ACTIVE
```

The only live copy is not destructively overwritten as the default recovery method.

---

## 66. Automatic rollback limits

### LOCKED

Automatic rollback may be pre-authorized only where:

- rollback class is explicitly known;
- target is a previously qualified tuple;
- trigger conditions are objective and predeclared;
- no hidden destructive data rollback occurs;
- audit/receipts remain available.

### LOCKED

Automatic rollback cannot:

- choose an unqualified release;
- lower a security/downgrade floor;
- restore an older Company recovery point without the governance required by MA-13;
- assume external side effects are undone;
- bypass failed audit/recovery prerequisites.

---

## 67. Anti-downgrade / security floor

### LOCKED

The installation stores a trusted local **minimum admissible security/release floor** derived from accepted MA-19/MA-20 release policy/evidence.

Ordinary update/rollback authority cannot silently lower that floor.

### LOCKED

An older release package that is cryptographically authentic may still be rejected because it is:

- below the current security floor;
- incompatible with the current state vector;
- no longer qualified for the host profile;
- missing a supported migration/restore path.

### LOCKED

Recovery of old Company data should, where supported, migrate the recovered data forward under an admissible current release rather than reactivate known-vulnerable software merely to match the backup's historical version.

---

## 68. Owner-requested downgrade is not automatically safe

### LOCKED

An Owner request to “go back to version X” is treated as a governed lifecycle request, not an instruction to bypass compatibility/security checks.

The system must identify whether the request requires:

- activation rollback only;
- qualified state migration;
- recovery-point restore;
- refusal because the target is below the security/compatibility floor.

Constitutional safety gates cannot be overridden by a generic confirmation dialog.

---

## 69. Version skipping

### LOCKED

The Maintenance Plane may skip intermediate releases only if the target Release Compatibility Contract declares a qualified path from the installed state.

Migration steps may internally traverse intermediate state versions without installing/running each historical product generation.

### LOCKED

Version-string arithmetic or semantic-version assumptions are not sufficient migration proof.

---

## 70. Failure before active-state mutation

### LOCKED

If failure occurs before the transaction mutates active persistent state or activation selection:

- active generation remains unchanged;
- staged candidate is marked failed/quarantined;
- no rollback is necessary;
- failure evidence is retained;
- normal runtime may resume if current state remains healthy.

---

## 71. Failure after quiescence but before migration commit

### LOCKED

The Maintenance Plane uses the migration journal and declared step semantics to determine whether it can:

- resume safely;
- retry an idempotent step;
- reverse a qualified step;
- discard an uncommitted staged target;
- require MA-13 recovery.

It does not guess based only on process exit code or file timestamps.

---

## 72. Failure during/after irreversible migration

### LOCKED

Once a migration crosses a declared irreversible commit point, the installation remains in maintenance/recovery state until one of the declared safe paths succeeds:

- forward completion;
- qualified forward repair;
- MA-13 recovery-point restore.

### LOCKED

The system does not start whichever binary happens to launch successfully against an ambiguous partially migrated state.

---

## 73. Failure after activation before finalization

### LOCKED

Post-activation failure is resolved according to rollback class.

Possible outcomes include:

- switch back to prior generation if current state remains backward-compatible;
- continue/repair the new generation if state has committed forward;
- enter isolated recovery if state must be restored.

The transaction remains auditable until a terminal lifecycle outcome exists.

---

## 74. Crash/reboot recovery

### LOCKED

Every lifecycle transaction is designed to survive process crash, host reboot, or power interruption.

On startup, the trusted bootstrap checks maintenance transaction state **before** admitting normal runtime.

If an incomplete transaction exists, it enters maintenance reconciliation.

### LOCKED

The bootstrap must distinguish:

- no maintenance in progress;
- safe old generation active;
- safe new generation committed;
- resumable staged/migration transaction;
- rollback eligible;
- recovery required;
- transaction state corrupted/unknown.

Unknown consequential maintenance state fails closed.

---

## 75. Planned reboot

### LOCKED

If a prerequisite/update requires host reboot, the transaction records a durable reboot checkpoint before requesting restart.

After reboot, SerapeumOS resumes **maintenance reconciliation**, not normal untrusted execution, until post-reboot prerequisites and transaction state are revalidated.

### LOCKED

A reboot cannot be used to erase or bypass the migration journal.

---

## 76. Host updates can stale product qualification

### LOCKED

A host OS/kernel/VMM/filesystem/security-policy change may invalidate the previous Host Compatibility Profile independently of SerapeumOS product version.

After material host change, MA-17 re-probe/requalification occurs before full autonomy resumes.

A SerapeumOS update cannot assume the host remained qualified across the reboot merely because the product update itself succeeded.

---

## 77. Repair semantics

### LOCKED

**Repair** restores the integrity of the currently selected qualified installation assets and reconstructable host registrations without redefining authoritative Company state.

Repair may:

- verify release-generation digests/manifests;
- replace missing/corrupt trusted binaries from the exact qualified release source;
- recreate service registrations/ACLs/derived bootstrap metadata;
- rebuild R3 derived state;
- re-run host capability probes;
- repair staged/activation metadata where authoritative evidence is sufficient.

### LOCKED

Repair does **not** silently:

- rewrite corrupted authoritative database rows;
- regenerate a missing root secret over encrypted state;
- roll Company state back;
- downgrade product generation;
- purge Agent workspaces;
- replace Owner files.

Authoritative data corruption is handed to MA-13 recovery.

---

## 78. Repair source

### LOCKED

Repair uses the same MA-19-qualified release identity as the generation being repaired, or performs a separately governed update to another qualified release.

It cannot fetch arbitrary “close enough” binaries or mix components from different release generations.

---

## 79. Reinstall / adoption

### LOCKED

Installing into a location where SerapeumOS managed state already exists is not automatically treated as a fresh install.

The Maintenance Plane must classify the target as:

- empty/new;
- valid existing installation eligible for repair/adoption;
- recoverable installation;
- incompatible/foreign state requiring migration/import;
- ambiguous/corrupted state requiring recovery;
- unsafe target.

### LOCKED

A fresh initializer must not overwrite a valid or ambiguous existing `installation_uid`, database, Artifact Store, workspace pool, or root-key metadata merely to complete setup.

---

## 80. Host replacement is install + restore, not binary copying

### LOCKED

Moving SerapeumOS to a replacement machine uses:

```text
qualified fresh installation
+ MA-13 restore/adoption of durable state
+ MA-17 host reprobe
+ MA-18 compatibility migration as required
```

Copying a prior host's installed executable tree is not the authoritative cross-host migration method.

Stable Company/Agent identities are restored from durable state, not inferred from copied host service IDs or paths.

---

## 81. Uninstall defaults to preserving durable state

### LOCKED

Normal **application uninstall** removes/disables SerapeumOS executable/runtime/service components while preserving recoverable Company-managed state unless the Owner explicitly selects a separate destructive purge operation.

The product must distinguish clearly between:

- remove application, keep data for reinstall/recovery;
- remove application and selected caches/runtime assets;
- permanently purge installation-managed state.

### LOCKED

A generic uninstall action cannot silently delete authoritative Company data.

---

## 82. Uninstall with preserved data

### LOCKED

When data is preserved, the uninstall path must also preserve enough compatible reconstruction/key metadata to avoid leaving encrypted data deceptively “present but unrecoverable”.

Where the host-protected root-secret mechanism depends on installed service identity or machine state, the uninstall flow must state and enforce the recovery consequence before removing that dependency.

### LOCKED

If preservation cannot be guaranteed, uninstall must block or require an explicit recovery/export transition rather than pretending data will remain usable.

---

## 83. Destructive purge is a separate high-risk action

### LOCKED

**Purge** destroys installation-managed durable state and is not an ordinary uninstall side effect.

It requires:

- explicit target installation identity;
- exact data classes to be destroyed;
- MA-06 high-impact Action Assurance;
- warning of backup/recovery consequences;
- service/runtime quiescence;
- audit/receipt where still possible;
- separate handling of external backup/export locations.

### LOCKED

Purge never silently deletes R5 Owner/user resources merely because SerapeumOS previously imported or published copies of them.

---

## 84. Secure-erasure claims

### LOCKED

SerapeumOS must not claim guaranteed physical secure erasure merely because files were deleted or overwritten.

Where cryptographic erasure is supported, destruction of the relevant protected encryption key material may be used as part of the purge design, but only when:

- key scope is correctly bounded;
- no required recovery copy still depends on that key;
- the consequence is explicitly authorized;
- evidence can be produced.

Exact media-erasure mechanism is host/implementation policy.

---

## 85. User resources and published outputs survive product lifecycle operations

### LOCKED

MA-09 R5 Owner/user resources remain outside installation ownership.

Install, update, repair, rollback, and ordinary uninstall do not mutate/delete those files except through their own separately authorized MA-06/MA-09 publication actions.

Lifecycle maintenance authority is not blanket authority over the Owner's filesystem.

---

## 86. Backup retention around updates

### LOCKED

A pre-update recovery anchor required for a migration is retained until at minimum:

- update reaches committed/qualified state;
- rollback policy no longer requires that anchor;
- recovery policy permits retirement;
- a suitable post-update recovery point exists where policy requires one.

### LOCKED

The updater cannot delete the only known-good recovery point merely to free space after a difficult update without explicit recovery policy authorization.

Exact retention duration belongs to MA-13/MA-14 policy.

---

## 87. Rolling internal state back does not roll back the external world

### LOCKED

Any rollback involving Company durable state inherits MA-13 external-divergence rules.

If actions were performed after the selected recovery point, restoration must reconcile possible:

- sent messages;
- published files;
- remote records;
- external tool effects;
- other consequential actions.

### LOCKED

The update UI/receipt must not imply that external actions disappeared because internal state was restored.

---

## 88. Pending work during update

### LOCKED

Installation-global update/migration admission evaluates non-terminal Tasks, Workflows, approvals, leases, and external side-effect attempts.

The Maintenance Plane may:

- drain safe work;
- checkpoint/cancel according to MA-12;
- block update until irreversible external activity settles;
- mark uncertain outcomes for later reconciliation.

### LOCKED

An update does not silently discard or restart consequential Agent work with the same authority after migration.

---

## 89. Runtime authority invalidation

### LOCKED

A material update/migration invalidates runtime authority that should not survive generation/state transition, including as applicable:

- Worker/appliance credentials;
- runtime sessions;
- leases;
- stale capabilities/approval bindings;
- process assignments;
- local IPC/session tokens.

Fresh runtime incarnations re-enter MA-02/MA-06/MA-10 admission after update.

Stable Agent organizational identity remains unchanged.

---

## 90. Audit and receipts

### LOCKED

Lifecycle actions produce durable MA-14 audit/receipt evidence.

Material records include, as applicable:

- installation/update transaction UID;
- initiating Principal/authority;
- source and target Release Generation;
- source/target Persistent State Vector;
- host profile/evidence reference;
- MA-19 provenance verdict reference;
- MA-20 qualification reference;
- recovery-anchor identity;
- migration steps/checkpoints;
- approval/policy binding;
- activation result;
- rollback/recovery result;
- verification evidence;
- terminal outcome.

### LOCKED

Logs are diagnostic support; they do not replace the authoritative maintenance receipt.

---

## 91. Audit failure during maintenance

### LOCKED

If a lifecycle phase requires durable audit/receipt persistence and that persistence cannot be established, the Maintenance Plane must not deliberately cross the next consequential commit boundary.

If audit persistence fails after an irreversible mutation already occurred, the installation enters recovery/repair state and preserves all remaining evidence; it does not falsely report success.

---

## 92. Update / recovery UX

### LOCKED

Before a consequential update, Owner-facing UX must be able to explain at minimum:

- current release/state;
- target release;
- whether persistent migration is required;
- expected downtime/reboot;
- backup/recovery-anchor status;
- rollback class/availability;
- incompatible extensions/runtime consequences;
- host/prerequisite changes;
- blockers and refusal reasons.

During update it exposes lifecycle phase rather than a vague spinner.

After update it distinguishes:

- installed/staged;
- activated;
- validating;
- committed;
- rollback/recovery required;
- fully finalized.

This preserves MA-16.

---

## 93. No “continue anyway” across hard gates

### LOCKED

The Owner may approve governed risk where architecture permits, but the UI cannot provide a generic override for:

- unverified release provenance;
- unqualified release/host combination;
- unsupported migration path;
- missing required recovery anchor;
- unknown critical host capability;
- incompatible persistent state;
- unavailable required root-key material;
- corrupted maintenance journal;
- security/downgrade floor violation.

---

## 94. Unattended update policy

### LOCKED

Unattended lifecycle actions are policy-controlled, not an unconditional default.

A future Owner policy may pre-authorize bounded update classes when:

- MA-19/MA-20 gates are satisfied;
- rollback class is known;
- downtime/reboot policy is satisfied;
- recovery prerequisites are automatically proven;
- no new broad host privilege/security consent is required.

### LOCKED

An update that changes authoritative persistent formats, root-key hierarchy, host security features, or requires destructive recovery semantics cannot become unattended merely because an Agent recommends urgency; it requires the governance class defined for that maintenance action.

---

## 95. Security emergency updates

### LOCKED

Security urgency does not permit bypassing provenance, compatibility, migration, audit, or host-safety gates.

If the current generation becomes disallowed by security policy before a qualified replacement can be installed, SerapeumOS may enter a reduced/degraded trusted mode or block affected risky features.

It does not silently install an unverified emergency binary.

---

## 96. Offline/local-first update doctrine

### LOCKED

SerapeumOS remains fully operable without a mandatory remote update control plane.

The architecture supports offline release import, verification, staging, installation, rollback, and recovery using locally available qualified packages/evidence.

### LOCKED

Optional future network update discovery/retrieval is an adapter/convenience layer; it cannot become product authority or a hard dependency.

---

## 97. Multi-Company installation behavior

### LOCKED

A product Release Generation and installation-global state vector normally apply to the whole local SerapeumOS installation.

A core update does not silently run different incompatible trusted-core product generations for different Companies inside the same installation.

Company-specific data migration may be staged/scoped internally where architecture permits, but activation must preserve cross-domain integrity for all hosted Companies.

---

## 98. Maintenance isolation from Agents

### LOCKED

During consequential maintenance:

- Agents cannot write R0/R1 through normal execution paths when those stores are fenced;
- Agent appliances cannot access maintenance staging/package roots;
- update/migration credentials are never injected into Agent runtimes;
- Agents cannot modify activation records, migration journals, release manifests, recovery anchors, or downgrade floors;
- maintenance network access, if any, is separate from Agent networking.

---

## 99. Portable/development execution

### REJECTED AS PRODUCTION-EQUIVALENT

A “portable folder” mode that bypasses trusted service installation, protected roots, root-secret protection, hard appliance isolation, or host capability qualification cannot claim `FULL_LOCAL_AUTONOMY` production equivalence.

### LOCKED

Development/recovery tooling may use simpler packaging where explicitly labeled and where no production-security claim is made.

Production distribution remains governed by the MA-18 contract regardless of convenience packaging.

---

## 100. Installation-state portability

### LOCKED

Release packages and Company recovery data are separate concepts.

A SerapeumOS installer/release package does not need to contain Company data.

A MA-13 Company backup does not need to contain every runtime binary/model/appliance asset to remain a valid Company recovery point, provided compatible qualified installation assets can be supplied separately.

This preserves local recovery reproducibility without conflating software distribution and Company truth.

---

## 101. Update package consistency

### LOCKED

A Release Generation is treated as one internally consistent release set.

The Maintenance Plane must reject mix-and-match combinations where executable/library/appliance/migration components do not belong to the same accepted release composition, unless the Release Compatibility Contract explicitly defines them as independent compatible components.

MA-19 provides cryptographic/provenance mechanisms; MA-18 enforces lifecycle composition.

---

## 102. Installation configuration drift

### LOCKED

Repair/update preflight detects material drift in trusted installation assets/configuration.

Unauthorized modification of trusted code, activation metadata, service definitions, or protected configuration is not silently normalized as “current configuration”.

Depending on evidence, the system:

- repairs from the exact qualified release;
- quarantines;
- requires Owner review;
- enters recovery.

---

## 103. Incomplete/corrupt maintenance metadata

### LOCKED

If the Maintenance Plane cannot prove which generation/state vector is authoritative because lifecycle metadata is corrupted or contradictory, it does not choose by:

- newest timestamp;
- highest version string alone;
- largest directory;
- whichever executable starts.

It enters recovery and reconstructs from trusted receipts, manifests, state metadata, and MA-13 recovery evidence.

---

## 104. Cleanup semantics

### LOCKED

Old Release Generations, staging files, migration scratch data, and obsolete recovery material are deleted only by trusted lifecycle cleanup after their retention dependencies are cleared.

Cleanup never races active rollback/recovery needs.

### LOCKED

Temporary update data that cannot be safely classified after crash is quarantined rather than automatically promoted or merged.

---

## 105. No secret alternate hot-update path

### LOCKED

All trusted product-code evolution uses MA-18 lifecycle controls.

There is no separate Agent/model/plugin/system-evolution channel that can replace trusted core code, migrations, or policy binaries while bypassing:

- MA-19 provenance;
- MA-20 qualification;
- MA-18 staging/activation/migration;
- MA-14 audit.

This preserves MA-15.

---

## 106. Release/update transport is non-authoritative

### LOCKED

Network mirrors, USB media, local folders, package caches, and future repository services are transports/sources, not install authority.

A source cannot force activation.

The Maintenance Plane decides admissibility from trusted metadata/evidence and local policy.

---

## 107. Time/freshness is not inferred from filenames

### LOCKED

A package named “latest”, a newer filesystem modification time, or a higher user-visible semantic version string is not sufficient anti-rollback/freshness evidence.

Trusted release/security metadata from MA-19 plus the local admitted-state history controls downgrade/freshness decisions.

---

## 108. Prerequisite documentation ownership

### LOCKED

MA-18 owns the structure of `PREREQUISITES.md` for install/update admission.

It must separate:

- architecture-required capabilities from MA-17;
- first supported host baseline(s);
- minimum hardware/storage thresholds proven by MA-20;
- optional accelerators/features;
- required host privileges/reboot implications;
- required local third-party components with MA-19 provenance references;
- degraded modes and what becomes unavailable.

### LOCKED

Numerical RAM/CPU/disk/VRAM minimums are MA-20 evidence outputs and are then persisted into `PREREQUISITES.md`; MA-18 does not invent them.

---

## 109. Appliance builder / image packaging handoff

### LOCKED

The Agent Appliance image is an immutable qualified Release Generation asset built through an MA-19-governed reproducible/provenanced path and qualified by MA-20.

MA-18 owns how the selected image generation is installed, retained, activated, rolled back, and associated with workspace/protocol compatibility.

Exact image builder remains a MA-19/implementation selection.

---

## 110. Root-key provider handoff

### LOCKED

MA-18 requires bootstrap, access, rotation-transition, uninstall-preservation, and recovery semantics for the installation root secret.

The exact host provider/API is selected beneath the MA-10/MA-17 contract and must be qualified in MA-20.

A provider may differ across Windows/Linux without changing Company/domain semantics.

---

## 111. Host↔appliance transport handoff

### LOCKED

MA-18 packages/provisions only a transport implementation compatible with the versioned trusted IPC/appliance contract.

The transport remains local, authenticated, capability-bounded, and non-authoritative for Company identity.

Exact Windows/Linux transport mechanism is implementation/MA-20 territory.

---

## 112. Lifecycle security invariants remain non-negotiable

### LOCKED

Install/update convenience cannot override any closed architecture invariant from MA-01 through MA-17.

Examples:

- no direct Agent DB credentials;
- no arbitrary host mounts into hostile Agent runtime;
- no plaintext root-secret fallback;
- no cloud control-plane dependency;
- no audit bypass;
- no unverified publication success;
- no weakening hard isolation because updater cannot provision it;
- no reclassification of R2 workspace as authoritative truth;
- no silent overwrite of changed Owner files;
- no security-control disablement as a normal install prerequisite.

---

## 113. Architecture-level veto conditions

An MA-18 implementation is invalid if it:

- updates trusted core code through an Agent/plugin/model-controlled channel;
- performs normal updates by patching running trusted binaries in place;
- treats release version alone as persistent-state compatibility proof;
- launches an old release against a too-new/incompatible schema because rollback was requested;
- mutates authoritative state before a required recovery anchor exists;
- treats the old mutable live database directory as automatically independent rollback protection;
- performs destructive database migration with no valid recovery path;
- silently skips unsupported migration edges;
- lets Agents execute production migrations directly;
- increments schema/version state before migration postconditions are proven;
- reports update success before post-activation validation;
- admits Agent work while consequential migration state is ambiguous;
- uses advisory file locks as the sole maintenance fence;
- interprets an interrupted transaction from timestamps/version strings alone;
- deletes the previous qualified generation/recovery anchor before rollback dependencies clear;
- silently lowers the security/downgrade floor;
- allows Owner “continue anyway” to bypass unverified provenance, incompatible state, missing root keys, or hard host gates;
- generates a new root secret over existing encrypted state during repair;
- treats repair as permission to rewrite Company truth;
- makes ordinary uninstall delete Company data by default;
- deletes Owner R5 resources during uninstall/purge without their own explicit target authorization;
- claims guaranteed secure erasure from normal file deletion;
- requires cloud connectivity to install/update/rollback/recover;
- mixes components from inconsistent release generations without an explicit compatibility contract;
- bypasses MA-19 or MA-20 because an update is urgent;
- reuses stale runtime credentials/leases across a material generation migration without revalidation;
- copies a prior host installation tree and treats host-specific IDs/paths as portable identity;
- treats “portable mode” as production-equivalent while bypassing the required trusted-service/security boundary.

---

## 114. Explicitly deferred decisions

The following do **not** block MA-18 closure because their governing semantics are now locked:

| Decision | Owner |
|---|---|
| exact Windows installer technology (MSI/MSIX/custom bootstrap/etc.) | Implementation + MA-20 |
| exact Linux package/service integration | Implementation + MA-20 |
| exact bootstrap executable/update mechanism | Implementation + MA-20 |
| exact package signature/trust-role format | MA-19 |
| exact SBOM/license/vulnerability policy | MA-19 |
| exact update repository/discovery protocol | MA-19 / future product policy |
| exact delta-patch algorithm | Implementation + MA-19/20 |
| exact PostgreSQL major-upgrade command/mode | Implementation + MA-20 |
| exact database migration framework/library | Implementation + MA-20 |
| exact Windows root-key provider/API | Implementation + MA-20 under MA-10/17 |
| exact Linux root-key provider/API | Implementation + MA-20 under MA-10/17 |
| exact Windows/Linux volume-encryption mechanism | Implementation + MA-20 |
| exact VHDX/QCOW/raw Agent workspace container choice | Implementation + MA-20 |
| exact host↔appliance IPC transport | Implementation + MA-20 |
| exact service account names/SIDs/UIDs | Implementation + MA-20 |
| exact release-generation directory basenames | Implementation |
| exact number/time retention of old generations | MA-13/14 product policy + implementation |
| exact supported source→target version matrix | MA-20 release evidence |
| exact update health thresholds/timeouts | MA-20 |
| exact RAM/CPU/disk/VRAM prerequisites | MA-20, then `PREREQUISITES.md` |
| exact reboot/elevation UI mechanics | Implementation + MA-16/20 |
| exact optional online update transport | Future governed adapter + MA-19/20 |

These are implementation, supply-chain, qualification, or product-policy selections beneath the closed MA-18 lifecycle contract.

---

## 115. MA-18 closure decision

### CLOSED

MA-18 is architecture-complete.

Locked:

- stable installation identity independent of software generation and host path;
- trusted Maintenance Plane and bounded privileged lifecycle authority;
- protected separation of code, mutable state, staging, recovery, and Owner resources;
- immutable/versioned Release Generations rather than normal in-place patching;
- trusted activation/bootstrap boundary;
- multi-axis Persistent State Vector;
- explicit Release Compatibility Contract and migration graph;
- durable install/update/migration transaction states;
- installation-global maintenance fencing and crash reconciliation;
- MA-17-derived prerequisite gate with no weaker installer exceptions;
- host-protected root-secret bootstrap/preservation semantics;
- physical-at-rest protection lifecycle gate;
- first-run separated from privileged machine installation;
- offline/local-first update acquisition and quarantined staging;
- mandatory MA-19 provenance gate and MA-20 qualification gate;
- preflight planning for compatibility, recovery, resources, downtime and reboot;
- quiescence as the default when concurrent-version safety is unproven;
- mandatory independent recovery anchor before incompatible consequential migration;
- versioned migration-step contracts and durable migration journal;
- explicit schema/database-engine migration semantics;
- Artifact Store identity-preserving migration;
- separately governed Agent Workspace migration and container compatibility;
- versioned configuration/key/protocol/appliance/extension compatibility;
- safe managed-storage relocation with verify/cutover/retention;
- post-activation validation before update commit;
- Last Known Good as generation + state-vector tuple;
- four rollback classes with no universal down-migration assumption;
- anti-downgrade/security floor enforcement;
- crash/reboot/incomplete-transaction maintenance recovery;
- repair limited to trusted installation assets/reconstructable state;
- reinstall/adoption protection against overwriting existing managed state;
- application uninstall preserving durable Company state by default;
- destructive purge as a separate high-risk governed action;
- no misleading secure-erasure claims;
- lifecycle audit/receipt requirements;
- no alternate hot-update path;
- explicit MA-19/MA-20 handoff for supply-chain and executable release proof.

No material MA-18 architecture question remains inside this domain.

---

## 116. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-195 — Installation identity survives software generation change
`installation_uid` and durable Company identity are independent of product binaries, host paths, service IDs, and normal updates.

### D-196 — Lifecycle mutation belongs to a trusted Maintenance Plane
Install, update, migration, storage relocation, repair, rollback, uninstall, and purge are trusted bounded maintenance operations; Agents cannot self-authorize them.

### D-197 — Production updates use immutable Release Generations
New trusted code is staged as a complete verified generation and activated through a trusted selector; normal update does not patch the running executable tree in place.

### D-198 — Compatibility is defined by a Persistent State Vector
Product version alone is insufficient. Database/schema/artifact/workspace/config/key/protocol/host contract versions are tracked independently and transitions must be explicitly supported.

### D-199 — Release transitions use an explicit compatibility graph
Version skipping and migration are allowed only through declared qualified source→target edges; no compatibility is inferred from version numbers alone.

### D-200 — Consequential migration requires recovery readiness
Before an update makes authoritative state backward-incompatible, an independent MA-13-compliant recovery anchor must exist and verify successfully.

### D-201 — Migration progress is durably journaled
Every material migration step has explicit source/target state, pre/postconditions, reversibility/resume semantics and verification evidence; crash recovery never blindly replays ambiguous mutations.

### D-202 — Database downgrade is not a generic rollback mechanism
Older product code may run only against a state vector it is qualified to consume. Otherwise rollback uses a qualified inverse migration or MA-13 recovery-point restore.

### D-203 — Last Known Good is a qualified tuple
LKG binds software generation, persistent state vector, host/qualification context and verification evidence; an old binary directory alone is not LKG.

### D-204 — Rollback classes are explicit
SerapeumOS distinguishes activation rollback, qualified reversible migration rollback, recovery-point rollback and forward-repair-only states; automatic rollback is limited to predeclared safe classes.

### D-205 — Security/downgrade floors cannot be silently lowered
Authentic old packages may still be inadmissible because of security floor, state incompatibility, or host qualification. Ordinary Owner approval does not bypass that floor.

### D-206 — Offline update is first-class
Release acquisition may be fully local/offline. Update transport is non-authoritative and no mandatory cloud updater/control plane is part of SerapeumOS.

### D-207 — Update success requires post-activation qualification
Staging or launching a new generation is not success. Trusted post-update validation must pass before commit/finalization and Agent admission.

### D-208 — Repair does not rewrite Company truth
Repair restores exact qualified installation assets and reconstructable host state; authoritative data corruption uses MA-13 recovery, and missing root-key material is never replaced over existing encrypted state.

### D-209 — Reinstall detects and protects existing installation state
A non-empty SerapeumOS managed root is classified for adoption/repair/recovery before initialization; fresh install never silently overwrites an existing installation identity or durable state.

### D-210 — Ordinary uninstall preserves durable Company state
Removing the application and destroying Company-managed state are separate lifecycle actions. Destructive purge requires explicit high-risk governance.

### D-211 — Lifecycle maintenance does not own Owner R5 resources
Install/update/rollback/uninstall/purge cannot treat external user files as installation-owned merely because SerapeumOS interacted with them.

### D-212 — Managed-root relocation is a verified migration
Storage relocation qualifies destination, fences/quiesces writers, migrates and verifies R0/R1/R2, atomically cuts over trusted root selection, and retains rollback material until policy permits cleanup.

### D-213 — Runtime authority is refreshed across material updates
Material generation/state transitions invalidate stale runtime sessions, leases, Worker/appliance credentials and affected approval/capability bindings; stable Agent organizational identity remains intact.

### D-214 — MA-19 and MA-20 are mandatory lifecycle gates
MA-18 controls lifecycle semantics, MA-19 proves software supply-chain acceptability, and MA-20 proves concrete executable host/release/migration behavior. No one gate substitutes for another.

---

## 117. Project-state transition

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

Current architecture domain:
MA-19 — Supply Chain / Upstream / Dependency Provenance

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Repository persistence:
PENDING

Next action:
MA-19-CLOSE — architecture only
```

---

## 118. Next action

**MA-19-CLOSE — Supply Chain / Upstream / Dependency Provenance**

Architecture only.

---

## Appendix A — Non-normative lifecycle grounding

The MA-18 contract intentionally sits above any one packaging technology. Its lifecycle principles are consistent with established update/migration guidance including:

- **NIST SP 800-40 Rev. 4 — Guide to Enterprise Patch Management Planning**: update/patch lifecycle includes identification, acquisition, installation and verification, with patching treated as controlled preventive maintenance.  
  https://csrc.nist.gov/pubs/sp/800/40/r4/final

- **The Update Framework (TUF) security model**: update systems must defend against arbitrary software installation, rollback, freeze, mix-and-match and wrong-software attacks; trusted update state must preserve integrity/freshness semantics. MA-19 owns the concrete cryptographic/provenance realization for SerapeumOS.  
  https://theupdateframework.io/docs/security/  
  https://theupdateframework.io/docs/metadata/

- **Microsoft Windows Installer rollback semantics** demonstrate the general lifecycle principle that failed installation requires an explicit rollback/recovery path rather than declaring partial mutation successful. MA-18 does not require Windows Installer specifically.  
  https://learn.microsoft.com/en-us/windows/win32/msi/rollback-installation

- **PostgreSQL pg_upgrade documentation** distinguishes major database-engine upgrade from ordinary minor update, performs compatibility checks, and documents migration modes with materially different old-cluster/rollback consequences. MA-18 therefore treats database major upgrade as a dedicated migration with an independent recovery anchor rather than as ordinary binary replacement.  
  https://www.postgresql.org/docs/current/pgupgrade.html

These references are grounding only. The normative SerapeumOS architecture is the LOCKED content above.
