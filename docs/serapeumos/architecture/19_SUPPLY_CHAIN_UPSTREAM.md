# MA-19 — Supply Chain / Upstream / Dependency Provenance

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED  
**Runtime prototypes:** PAUSED  
**Repository persistence:** PENDING

---

## 1. Purpose

MA-19 defines how SerapeumOS decides whether source code, dependencies, build tools, binary artifacts, appliance images, models, extensions, and release packages are acceptable members of the trusted software supply chain.

It governs:

- canonical upstream identity and source lineage;
- exact source/dependency pinning;
- direct and transitive dependency closure;
- OSS/local doctrine enforcement;
- license identification, compatibility, and obligation tracking;
- build-material provenance and build-environment identity;
- reproducibility/verifiability expectations;
- SBOM and build-material inventory semantics;
- cryptographic release provenance and signing-role separation;
- release metadata, anti-rollback, revocation, and offline verification;
- vulnerability intake, affectedness, remediation, and security-floor escalation;
- Ankole foundation intake and future upstream movement;
- supply-chain treatment of VMMs, drivers, guest images, runtimes, tools, plugins, MCP servers, models, and generated code;
- dependency/update mirrors, caches, registries, and offline repositories;
- exact handoff to MA-18 lifecycle admission and MA-20 executable qualification.

MA-19 does **not** define installer transaction mechanics, persistent-state migration semantics, concrete test thresholds, the final supported host matrix, cryptographic implementation APIs, or exact build/packaging tools. Those remain owned by MA-18, MA-20, MA-10, and implementation beneath this architecture.

---

## 2. Governing principle

### LOCKED

> **No software becomes trusted because it came from an official-looking source, has a familiar name, has a valid hash, has a signature, passed one scanner, or successfully executed.**

Trust requires a reconstructable chain from declared source/materials through a controlled build to the exact release bytes, plus policy admission and MA-20 qualification.

---

## 3. Core supply-chain invariant

### LOCKED

SerapeumOS separates:

```text
source identity
    ≠ source integrity
    ≠ dependency admissibility
    ≠ build provenance
    ≠ release authorization
    ≠ vulnerability status
    ≠ executable qualification
    ≠ installation authority
```

A valid signature proves only the statement bound by that signature. It does not prove safety, license compatibility, architectural compatibility, or operational fitness.

---

## 4. Relationship to prior architecture

### LOCKED

MA-19 preserves all previously closed invariants, especially:

- final SerapeumOS is local-first and has no mandatory cloud control plane;
- SerapeumOS-controlled required/distributed production components above the host boundary obey the OSS/local doctrine;
- NaraRouter is development/validation-only and is not a production dependency;
- Ankole v1.0.4-rc.1 at commit `7434d934315881438d4788d41228ba31d2f26fbb` remains the locked low-level foundation identity from the master framework;
- Agents, models, generated code, downloads, plugins, browsers, and external content are untrusted;
- MA-18 owns staging/activation/migration/rollback after MA-19 admission;
- MA-20 proves the exact candidate on exact supported environments.

MA-19 cannot weaken these contracts by classifying a component as “third-party” or “prerequisite.”

---

## 5. Supply-chain trust boundary

### LOCKED

The conceptual boundary is:

```text
Untrusted upstream / mirror / media / package registry
                    │
                    ▼
          Intake + Quarantine
                    │
                    ▼
       Supply-Chain Registry
   source / license / security / digest
                    │
                    ▼
        Admitted Build Materials
                    │
                    ▼
      Controlled Local Build Plane
                    │
            signed provenance
                    ▼
          Candidate Artifacts
                    │
       SBOM / manifest / attestations
                    ▼
          MA-20 Qualification
                    │
                    ▼
       Release Authorization Envelope
                    │
                    ▼
        MA-18 Lifecycle Admission
```

No upstream endpoint, registry, build worker, CI job, Agent, model, or package manager directly activates trusted production code.

---

## 6. Supply-Chain Registry

### LOCKED

SerapeumOS requires a durable, versioned **Supply-Chain Registry** for every material component that can affect a production release.

Conceptually, a component record includes:

```text
component_id
component_class
canonical_name
canonical_upstream
source_revision
source_snapshot_digest
package/version identifiers
binary/source artifact digests
license identity/evidence
relationship/dependency edges
build/runtime/test/distribution scope
trust-domain placement
local patches/fork lineage
vulnerability state/evidence
admission state
admission policy version
first_seen / last_reviewed evidence
release memberships
supersession/revocation state
```

Exact schema is implementation design.

---

## 7. Component classes

### LOCKED

The Registry distinguishes at least:

| Class | Examples | Supply-chain treatment |
|---|---|---|
| **Product Source** | SerapeumOS source, inherited Ankole source | source lineage + release provenance |
| **Runtime Dependency** | libraries, interpreters, native DLLs, packages | full runtime/distribution inventory |
| **Build Dependency** | compiler, linker, packager, code generator | build-material provenance |
| **Host Adapter Dependency** | VMM client, filesystem helper, service helper | MA-17 + MA-19 + MA-20 |
| **Privileged/Kernel Component** | driver, hypervisor helper | highest supply-chain scrutiny |
| **Appliance/Guest Material** | kernel, guest OS packages, image builder input | complete image provenance |
| **Extension** | plugin, trusted adapter, Agent-local tool/MCP | class-specific MA-08 trust treatment |
| **Model Artifact** | bundled local model/tokenizer/config | artifact/license/provenance treatment |
| **Generated Source/Asset** | model/codegen output committed to product | generator lineage + normal source review |
| **Host Substrate** | OS-provided capability below product boundary | host-profile evidence; not silently reclassified as bundled OSS |

---

## 8. Admission states

### LOCKED

Every material component has an explicit supply-chain state such as:

```text
DISCOVERED
QUARANTINED
UNDER_REVIEW
ADMITTED_FOR_DEVELOPMENT
ADMITTED_FOR_BUILD
ADMITTED_FOR_DISTRIBUTION
BLOCKED
REVOKED
SUPERSEDED
```

A component admitted for development is not thereby admitted into a trusted production release.

---

## 9. Canonical upstream identity

### LOCKED

Every third-party component has a canonical upstream identity sufficient to distinguish it from forks, mirrors, packages with the same display name, and dependency-confusion lookalikes.

Canonical identity is based on structured provenance such as:

- project/repository identity;
- package ecosystem and namespace where applicable;
- source revision;
- upstream release identity;
- independently computed content digest.

Display names and URLs alone are not identity.

---

## 10. Source revision is necessary but not sufficient

### LOCKED

A Git commit/tag/version is lineage evidence, not sole integrity authority.

For production source snapshots, SerapeumOS binds the source revision to an independently computed modern cryptographic digest of the exact admitted source tree/archive.

### LOCKED

A legacy Git SHA-1 commit identifier may remain a lineage locator, including the currently locked Ankole commit, but it is not the sole release-content integrity check.

Production manifests use a policy-approved strong digest; SHA-256 or stronger is the minimum baseline unless cryptographic policy is superseded by a future approved stronger suite.

---

## 11. Mutable references are non-authoritative

### LOCKED

The following cannot identify a production dependency by themselves:

- `latest`;
- default branch name;
- unpinned branch;
- mutable tag;
- package range such as `>=x`;
- floating container tag;
- registry “recommended” version;
- website download filename.

Production materials resolve to exact immutable identities before build admission.

---

## 12. Mirrors and caches

### LOCKED

A mirror/cache improves availability; it does not become provenance authority.

Bytes from:

- public mirrors;
- internal mirrors;
- USB/offline media;
- local package caches;
- future network repositories

are accepted only when their exact identity is bound to already trusted/admitted metadata.

---

## 13. Transport security is not package authority

### LOCKED

TLS/HTTPS, authenticated package registries, Git hosting authentication, and signed download links are transport/source signals only.

MA-19 never substitutes “downloaded securely” for content provenance and policy admission.

---

## 14. Dependency closure

### LOCKED

Production admission covers the complete dependency closure that materially affects the release, including:

- direct dependencies;
- transitive dependencies;
- native/FFI libraries;
- interpreter/runtime packages;
- build plugins;
- package-manager scripts/hooks;
- code generators;
- linker/runtime redistributables;
- guest/appliance packages;
- embedded assets that execute or alter trusted behavior.

Unknown transitive dependencies are a release blocker.

---

## 15. Exact dependency resolution

### LOCKED

Trusted release builds resolve dependencies from exact, reviewed material sets.

Production build resolution must not depend on ambient network state or the current contents of a public package index.

### LOCKED

Lockfiles are useful evidence but are not enough when they omit:

- artifact digests;
- transitive/native dependencies;
- build-time executable hooks;
- source lineage;
- platform-specific resolution.

The final admitted material graph is authoritative over a package-manager lockfile.

---

## 16. Dependency confusion and namespace substitution

### LOCKED

Build intake must prevent dependency-confusion and namespace substitution by binding each dependency to its intended source/namespace and exact digest.

There is no production resolver fallback from an approved internal/vendored component to an unapproved public package with the same name.

---

## 17. Package-manager lifecycle scripts

### LOCKED

Install/build/post-install hooks supplied by dependencies are executable code.

They are not run merely to inspect a candidate package.

If required for the controlled build, they are included in the build-material and execution provenance and execute only inside the bounded build environment.

---

## 18. Vendoring and forks

### LOCKED

Vendored or forked third-party code preserves upstream lineage.

A fork record binds:

```text
upstream source/revision
local fork revision
patch-series identity/digest
reason for divergence
security/license status
merge/rebase history where applicable
release memberships
```

A local fork does not erase upstream provenance or vulnerability inheritance.

---

## 19. Low-diff Ankole rule

### LOCKED

The existing low-diff Ankole doctrine is preserved.

SerapeumOS should extend above or through explicit adapters/contracts rather than unnecessarily forking core Ankole behavior.

Where Ankole code must be patched, the patch set is explicit, reviewable, reproducible, and separately identified from the upstream baseline.

---

## 20. Ankole v1 foundation intake

### LOCKED

The architecture-locked foundation identity is:

```text
Ankole version: v1.0.4-rc.1
revision:       7434d934315881438d4788d41228ba31d2f26fbb
```

This identifies the intended baseline, but MA-19 requires a production **Ankole Intake Receipt** before release admission.

The receipt must bind at minimum:

- canonical upstream repository/project identity;
- exact revision;
- independent source-tree/archive digest;
- license text/identity and evidence;
- dependency/material inventory;
- local patch delta, if any;
- vulnerability review snapshot;
- reviewer/admission record;
- source-bundle location.

Missing concrete receipt fields block production release but do **not** reopen the MA-19 architecture contract.

---

## 21. Future Ankole upstream movement

### LOCKED

Any change from the locked Ankole foundation revision is a new upstream-intake event.

It requires:

```text
new upstream snapshot
→ provenance/license/security review
→ SerapeumOS delta-impact review
→ MA-15 governed change path
→ controlled build
→ MA-20 qualification
→ MA-18 update lifecycle
```

“Newer upstream” is not automatic authority.

---

## 22. Open-source production rule

### LOCKED

SerapeumOS-owned, required, bundled, distributed, or managed production software above the host boundary must satisfy the project's OSS/local doctrine.

For software, “source-available” but non-open-source licensing does not satisfy this rule.

### LOCKED

A required proprietary remote service, proprietary runtime library, closed binary blob, license server, cloud control plane, or closed mandatory plugin cannot become part of the production architecture above the host boundary.

---

## 23. Host substrate distinction

### LOCKED

Host-provided facilities below the SerapeumOS product boundary—such as operating-system services or host virtualization facilities qualified by MA-17—are recorded as host capability dependencies, not falsely represented as SerapeumOS-owned OSS.

This distinction cannot be abused to ship or manage a closed third-party product component while calling it a “host prerequisite.”

---

## 24. Build-system locality

### LOCKED

The final release process must not require a proprietary cloud build service, proprietary hosted package registry, hosted signing service, or SaaS-only release authority.

A release can be built, verified, signed, and packaged using local/offline-controlled infrastructure.

Optional external development services may provide supplemental evidence but are not release authority.

---

## 25. NaraRouter boundary

### LOCKED

NaraRouter may appear only as temporary development/validation provenance where applicable.

It must not appear as:

- a required runtime dependency;
- a required release-build service;
- a signing authority;
- an update authority;
- a production SBOM runtime component;
- a rebuild prerequisite.

If model-generated code developed with NaraRouter enters source, that code follows the same review/build/qualification path as any other untrusted candidate source.

---

## 26. License identity

### LOCKED

Every distributed third-party software component has a determined license identity supported by retained evidence.

Standard license identifiers are used where practical, but a package manager's declared license string is not accepted as conclusive without inspecting the corresponding source/license evidence when material.

---

## 27. Open-source license gate

### LOCKED

Distributed required software must use licensing that qualifies as open source under the project's governing OSS policy.

For ordinary software dependencies, OSI-approved licenses are the default admissible reference set.

A non-OSI or ambiguous “source available” license requires explicit policy/legal classification and cannot be silently treated as open source.

---

## 28. License compatibility

### LOCKED

A license being open source does not automatically make it compatible with SerapeumOS distribution.

Admission also checks applicable obligations and compatibility, including where relevant:

- attribution/notice;
- source availability;
- modification notices;
- reciprocal/copyleft obligations;
- relinking/object-file obligations;
- patent clauses;
- trademark restrictions;
- redistribution terms.

Exact legal interpretation remains qualified human/legal work, not model authority.

---

## 29. License obligations are release artifacts

### LOCKED

Each production release carries or references a version-bound **License Compliance Bundle** sufficient to identify:

- included third-party components;
- their licenses;
- required notices/attributions;
- source-offer/source-bundle obligations where applicable;
- known exceptional obligations and their fulfillment evidence.

License compliance is bound to the exact release, not maintained as a generic timeless document.

---

## 30. Corresponding source

### LOCKED

Every SerapeumOS production release has a corresponding source/provenance package sufficient to reconstruct which source and build materials produced that release.

The runtime installer need not embed every source file, but the release must have a durable, exact, locally retainable source bundle/reference set that satisfies the governing licenses and the project's reproducibility objectives.

---

## 31. Non-code assets and model licenses

### LOCKED

Non-code assets, datasets, model weights, tokenizers, fonts, icons, and documentation are separately classified because software-license taxonomies may not apply directly.

Bundled required assets must still have explicit redistribution/local-use rights and provenance.

A model or asset with incompatible redistribution/use restrictions cannot become a required bundled production component.

---

## 32. User-supplied optional artifacts

### LOCKED

A user-supplied local model, tool, Skill, MCP server, or other optional artifact is not automatically part of the SerapeumOS release supply chain.

It is treated as external/untrusted input under MA-07/08 and may require local qualification before use.

Its presence cannot contaminate the provenance claim of the signed SerapeumOS base release.

---

## 33. Vulnerability evidence sources

### LOCKED

Vulnerability management consumes multiple evidence classes, such as:

- upstream project/security advisories;
- CVE/CNA records;
- OSV/ecosystem advisories;
- NVD or equivalent enrichment;
- CISA KEV exploitation evidence;
- distro/package-maintainer advisories;
- repository/security notices;
- internal analysis/qualification findings.

No single scanner/database is infallible authority.

---

## 34. Vulnerability finding vs affectedness

### LOCKED

A vulnerability match is evidence requiring component-specific determination.

SerapeumOS tracks whether a release/component is:

```text
UNKNOWN
NOT_AFFECTED
AFFECTED
MITIGATED
PATCHED
ACCEPTED_EXCEPTION
REVOKED
```

where the determination is bound to exact source/version/patch/build context and supporting evidence.

---

## 35. Vulnerability identity mapping

### LOCKED

Vulnerability tooling must map findings to the actual component lineage, not merely filename/version text.

Vendored code, backports, local patches, forks, statically linked libraries, embedded copies, and distro-patched versions require explicit mapping so false negatives/positives are not silently accepted.

---

## 36. Exploitation evidence is a prioritization input

### LOCKED

Known exploitation, reachable attack surface, privilege, trust-domain placement, and impact materially affect security priority.

A vulnerability in the trusted Maintenance Plane, TCB, host boundary, parser, updater, or hostile-workload boundary receives stricter treatment than an unreachable optional development-only dependency.

---

## 37. Release security veto

### LOCKED

A production candidate with a known unmitigated vulnerability that materially defeats a locked security invariant is not releasable merely because its version is current or its tests pass.

Exact severity/priority thresholds are MA-20 release-policy values, but **architecture/security-invariant defeat is a hard veto class**.

---

## 38. Vulnerability exceptions

### LOCKED

Where a vulnerability is accepted temporarily, the exception is explicit and version-bound, with:

- exact affected component/release;
- evidence and rationale;
- compensating controls;
- owner/reviewer authority;
- expiry/review condition;
- remediation target;
- distribution/user-notification consequence where applicable.

An exception never becomes a silent permanent allowlist entry.

---

## 39. Post-release vulnerability response

### LOCKED

Discovery of a material vulnerability after release may:

- revoke the affected release/component;
- raise the MA-18 security/downgrade floor;
- block repair/reinstall of affected bytes;
- require emergency update/recovery guidance;
- invalidate previous “recommended” status without erasing historical provenance.

A previously valid signature remains historically valid but does not override a later trusted revocation/security-floor decision.

---

## 40. Offline vulnerability/security metadata

### LOCKED

Because SerapeumOS is local-first, security advisory/revocation updates must be importable as signed offline metadata.

Network connectivity is optional transport, not security authority.

The local installation persists the highest accepted security/revocation state so an older offline bundle cannot silently lower it.

---

## 41. Dependency maintenance status

### LOCKED

Upstream maintenance health, release activity, maintainer continuity, issue responsiveness, and ecosystem adoption are risk evidence, not trust authority.

An abandoned but safely vendored/patched dependency may be admissible; an actively maintained dependency may still be inadmissible due to license, provenance, vulnerability, or architectural risk.

---

## 42. Build-material inventory

### LOCKED

The build system records all material inputs capable of affecting output, including:

- source snapshot(s);
- dependency archives/binaries;
- compiler/linker/interpreter;
- code generators;
- build scripts;
- package manager/resolver;
- base image/guest builder inputs;
- environment/configuration parameters that affect output;
- local patch sets.

This **Build Materials Inventory** complements, but is not identical to, the runtime/distribution SBOM.

---

## 43. Build bootstrap boundary

### LOCKED

MA-19 does not pretend to solve infinite compiler/bootstrap recursion.

A production build starts from an explicitly declared, versioned **Build Bootstrap Set** containing the minimum trusted build OS/toolchain substrate.

The bootstrap set is itself provenance-recorded and MA-20-qualified.

Claims stop at this stated bootstrap boundary rather than implying mathematical proof of every ancestor compiler.

---

## 44. Controlled release-build environment

### LOCKED

Production release builds execute in a clean, controlled build environment separated from ordinary developer workstation state.

The environment must not silently inherit:

- ambient PATH tools;
- undeclared SDKs;
- user-site packages;
- network-resolved dependencies;
- mutable caches without digest validation;
- personal credentials;
- developer-local source modifications outside the declared snapshot.

---

## 45. Network-disabled build phase

### LOCKED

After required materials are admitted and staged, the authoritative release-build phase is network-disabled by default.

If a future build step genuinely requires network access, that step is outside the canonical hermetic build boundary until its fetched material is separately captured, admitted, and replayable offline.

No release can depend on “whatever the network returned during build.”

---

## 46. Local artifact/material cache

### LOCKED

SerapeumOS may maintain a content-addressed local material cache/repository for admitted build inputs.

Cache identity is digest-based; cache pathname or package-manager metadata alone is not authority.

Corrupt/mismatched objects are quarantined and never repaired by silently fetching mutable replacements during the release build.

---

## 47. Build environment identity

### LOCKED

Every candidate build records a versioned **Build Environment Identity** sufficient to reproduce/compare the build, including relevant:

- build OS/image identity;
- architecture;
- toolchain identities/digests;
- build configuration/profile;
- dependency/material-set identity;
- build recipe version;
- source snapshot;
- declared environment parameters.

Ephemeral hostnames, timestamps, or workspace paths are not primary build identity.

---

## 48. Build provenance

### LOCKED

Every production candidate carries verifiable build provenance binding:

```text
subject artifact digest(s)
source snapshot
build-material set
build recipe/type
builder identity
build environment identity
invocation/configuration
relevant start/end evidence
provenance schema/version
```

The provenance must be integrity-protected and verifiable independently of the build worker's local filesystem.

---

## 49. Provenance is about the exact bytes

### LOCKED

Build provenance binds the exact candidate artifact digest(s) later qualified and released.

Rebuilding “the same version” and then signing different bytes is not equivalent provenance.

---

## 50. Builder identity

### LOCKED

A builder identity represents a controlled build environment/role, not an individual developer account.

Ordinary Agents, model runtimes, untrusted plugins, and developer shells cannot impersonate the release builder.

---

## 51. Reproducibility objective

### LOCKED

Trusted core, Maintenance Plane, and appliance payloads are designed for reproducible/verifiable builds.

Where deterministic tooling permits it, independently rebuilt canonical payloads should be bit-identical.

Where signing timestamps, packaging metadata, or a platform envelope introduce legitimate nondeterminism, the deterministic payload and nondeterministic envelope are separated so the exact difference is explainable and testable.

### LOCKED

No artifact is described as “reproducible” until MA-20 demonstrates the applicable reproduction property.

---

## 52. Reproducibility is not provenance

### LOCKED

Two attackers can reproducibly build malicious source.

Therefore reproducibility strengthens evidence but does not replace:

- trusted source selection;
- dependency admission;
- license/security review;
- release authorization;
- MA-20 qualification.

---

## 53. Generated code and generated assets

### LOCKED

Generated source/assets committed or embedded in trusted production are treated as supply-chain materials.

The release record preserves, where material:

- generator/tool identity;
- generator version/digest;
- source/template/input identities;
- generation recipe;
- resulting generated-content digest.

Model/Agent generation does not bypass normal review and qualification.

---

## 54. Release-signing role separation

### LOCKED

SerapeumOS defines separate logical authorities for:

1. **Supply-Chain Root Authority** — authorizes trusted release-signing identities and trust-root rotation;
2. **Build Provenance Authority** — attests what controlled builder produced which exact bytes;
3. **Release Authorization Authority** — authorizes a qualified candidate for distribution/MA-18 admission;
4. **Security Revocation Authority** — publishes trusted revocation/security-floor metadata.

One physical implementation may host multiple roles only where MA-10/20 proves adequate separation; the logical authorities remain distinct.

---

## 55. Build worker cannot self-release

### LOCKED

A build worker cannot unilaterally convert its own output into an authorized SerapeumOS release.

Possession of build-provenance authority does not grant Release Authorization or Root Authority.

---

## 56. Root authority

### LOCKED

Supply-Chain Root Authority is the long-lived trust anchor for SerapeumOS release metadata.

It is kept offline from routine builds/releases whenever feasible and is invoked only for bounded root/role changes, recovery, or equivalent high-risk operations.

### LOCKED

Material root trust changes require dual control: no single ordinary developer/build Agent/process may silently replace the root trust set.

Exact threshold/key-storage technology is implementation beneath MA-10 and MA-20.

---

## 57. Release authorization

### LOCKED

Release Authorization signs/binds an exact **Release Envelope**, not a filename or semantic version string.

Authorization occurs only after required supply-chain checks and MA-20 qualification evidence are bound to the same candidate digests.

---

## 58. Security revocation authority

### LOCKED

Security revocation metadata is separately versioned and can invalidate/retire otherwise authentic releases or keys.

Revocation cannot rewrite history: prior release provenance remains retained, while current admission policy changes.

---

## 59. Key isolation

### LOCKED

Private release/root/revocation keys are MA-10 `S-SIGNING` secrets.

They are never exposed to Agents, models, ordinary build scripts, package-manager hooks, or release payloads.

Signing occurs through bounded trusted services/ceremonies.

---

## 60. Cryptographic agility

### LOCKED

Release/provenance metadata carries a versioned cryptographic-suite identifier.

The architecture supports algorithm/key migration without changing Company identity or release semantics.

Deprecated algorithms can be removed through a signed trust-root/security-floor transition.

Exact algorithms and key-provider APIs are implementation/MA-20 selections consistent with the minimum strong-digest rule above.

---

## 61. Host-native code signing is supplemental

### LOCKED

Windows Authenticode, package-manager signatures, distro signatures, or analogous host-native signing may be used for host UX/platform integration.

They are supplemental evidence and do not replace the SerapeumOS Release Envelope and root-of-trust chain.

---

## 62. No mandatory external signing/transparency service

### LOCKED

No public transparency log, cloud identity provider, hosted certificate authority, or keyless-signing service is required to verify or produce a SerapeumOS release.

Such systems may provide optional corroborating evidence during development, but the complete production trust path remains locally verifiable.

---

## 63. Release Envelope

### LOCKED

Every production Release Generation has an integrity-bound **Release Envelope** conceptually containing/referencing:

```text
release_id / product generation
exact payload manifest + digests
source snapshot identity
build provenance
Build Materials Inventory
runtime/distribution SBOM
license compliance bundle
vulnerability/security assessment snapshot
MA-17 host compatibility contract reference
MA-18 release compatibility/migration contract
MA-20 qualification evidence identity
security/downgrade floor
release sequence/catalog generation
signing/trust metadata
```

The envelope is the supply-chain identity presented to MA-18.

---

## 64. Release payload manifest

### LOCKED

The payload manifest enumerates every file/object that is part of the trusted Release Generation or its required signed companion assets.

It binds logical role/path, byte size, and strong digest.

Extra undeclared executable content is not silently admitted.

---

## 65. SBOM semantics

### LOCKED

A production release includes a machine-readable SBOM using a recognized interoperable standard.

The architecture does not lock SerapeumOS permanently to one SBOM serialization/version; the release records the format/schema version used.

### LOCKED

The SBOM is an inventory/provenance artifact, not the sole admission database.

The Supply-Chain Registry remains richer where build-only, patch, trust, policy, or review state exceeds SBOM fields.

---

## 66. SBOM scope

### LOCKED

The release SBOM covers the complete distributed/runtime software composition that materially executes or is shipped with the product, including where applicable:

- SerapeumOS components;
- Ankole foundation components;
- bundled interpreters/runtimes;
- native libraries;
- appliance/guest components;
- bundled trusted extensions;
- redistributed command-line tools/helpers.

Build-only dependencies are captured in Build Materials Inventory/provenance even when omitted from the runtime SBOM.

---

## 67. SBOM completeness and uncertainty

### LOCKED

SBOM generation combines declared package metadata with build/package inspection sufficient to detect undeclared embedded/native material.

Where component identity is uncertain, the release records that uncertainty; it does not silently omit the component.

Unknown executable composition blocks trusted release admission until classified.

---

## 68. SBOM generated at build/release time

### LOCKED

SBOM/provenance are generated from the exact admitted build/release materials, not reconstructed months later from a dependency file that may have drifted.

Every material component change produces updated provenance/SBOM state.

---

## 69. Release/source bundle pairing

### LOCKED

Binary release, source bundle, SBOM, license bundle, provenance, and qualification evidence are mutually bound by exact identifiers/digests.

A source bundle from one release cannot be presented as provenance for another because filenames/versions look similar.

---

## 70. Mix-and-match defense

### LOCKED

Release metadata prevents valid signed pieces from different generations being combined into an unapproved release.

The signed Release Envelope binds the complete coherent manifest/set.

---

## 71. Wrong-software defense

### LOCKED

Release metadata binds product identity, target architecture/platform class, generation, compatibility contract, and payload digest.

A valid SerapeumOS artifact intended for another component/channel/host class is not accepted merely because its signature is valid.

---

## 72. Release sequence and catalog generation

### LOCKED

Every authorized release/security catalog transition has monotonic trusted sequence/generation metadata independent of filenames and wall-clock modification times.

Clients persist enough prior admitted state to detect rollback of release/security metadata.

---

## 73. Offline-first update trust

### LOCKED

An offline release package contains all metadata necessary to authenticate:

- root/role chain applicable to the package;
- exact release envelope;
- coherent payload manifest;
- release/security sequence;
- applicable revocation information packaged with that release set.

No network lookup is required to verify package authenticity.

---

## 74. Offline freshness limits

### LOCKED

Offline authenticity does not prove that the package is globally newest.

If the installation has no newer locally trusted security metadata and cannot obtain current metadata, the UX/reporting must distinguish:

- **AUTHENTIC / ADMISSIBLE UNDER KNOWN LOCAL STATE**
from
- **CONFIRMED CURRENT/LATEST**.

SerapeumOS never claims freshness it cannot prove.

---

## 75. Time semantics

### LOCKED

Wall-clock timestamps and certificate timestamps may be supporting evidence but are not the sole anti-rollback mechanism.

Persisted trusted sequence/security-floor state controls downgrade detection when trusted online time is unavailable.

Expiration may supplement sequence rules where trustworthy time exists.

---

## 76. First-install trust bootstrap

### LOCKED

The first installer/bootstrap carries or is paired with a SerapeumOS public root-trust identity/fingerprint sufficient to verify the first Release Envelope.

A new root cannot be trusted merely because the same untrusted package says it is the root.

### LOCKED

Where the Owner verifies the root fingerprint through an independent source/channel, that is stronger first-install evidence. If package and fingerprint came from one medium/source, SerapeumOS must not falsely claim independent corroboration.

---

## 77. Root rotation

### LOCKED

Routine root rotation is accepted only through metadata authorized by the previously trusted root authority according to the active root policy.

If root compromise is suspected and the old root cannot safely authorize rotation, the system enters an explicit high-risk root-recovery/bootstrap procedure rather than silently accepting a newly bundled key.

---

## 78. Key compromise response

### LOCKED

Supply-chain key compromise can trigger:

- signer revocation;
- security metadata generation increase;
- release re-authorization/rebuild where necessary;
- MA-18 security-floor change;
- recovery guidance for installations unable to establish a valid trust chain.

Historical signatures remain evidence of what was signed; they cease to grant current admission when revoked.

---

## 79. Intake quarantine

### LOCKED

New upstream/dependency artifacts enter a non-executable quarantine before admission.

Quarantine inspection is bounded and treats archive names, metadata, manifests, scripts, and nested content as untrusted data.

Archive traversal, decompression bombs, malformed packages, and parser resource abuse remain subject to MA-11/12/17 controls.

---

## 80. No dynamic public dependency install in production

### LOCKED

A production SerapeumOS installation does not resolve/import trusted dependencies directly from public package registries at runtime or during ordinary update.

Required product dependencies arrive as part of an admitted Release Envelope or an explicitly defined MA-18 prerequisite whose provenance is separately admitted.

---

## 81. Development dependencies

### LOCKED

Development/test tooling may have broader membership than runtime distribution, but it remains supply-chain tracked when it can affect:

- generated source;
- test/qualification truth;
- packaging;
- release artifacts;
- security conclusions.

A compromised test/build tool cannot be dismissed because it is “dev-only.”

---

## 82. Test fixtures and qualification tools

### LOCKED

MA-20 fixtures, harnesses, scanners, fuzzers, parsers, and reference artifacts have provenance/version identity where their output can decide release acceptance.

A qualification tool update may change evidence and therefore is tracked as a supply-chain change.

---

## 83. Binary-only upstream artifacts

### LOCKED

A binary-only third-party component above the SerapeumOS-controlled production boundary cannot satisfy the final OSS doctrine merely because its checksum/signature is known.

If its function is required, SerapeumOS must use an acceptable open-source replacement, move the function below a legitimate host-substrate boundary, or change the architecture through an explicit master-architecture decision.

---

## 84. Prebuilt binaries from open-source projects

### LOCKED

Prebuilt binaries from an open-source upstream may be used only when their source lineage and artifact provenance are acceptable under policy.

For highest-trust components, locally controlled rebuild from admitted source is preferred and may be required by MA-20.

A public upstream binary is not automatically trusted merely because the upstream source is open.

---

## 85. Native libraries and dynamic loading

### LOCKED

Trusted SerapeumOS binaries may load only declared/qualified product libraries plus explicitly modeled host-system libraries from the MA-17 host contract.

Ambient PATH/current-directory/plugin-directory resolution cannot silently substitute an untracked library into the trusted process.

Exact loaded-module verification belongs to MA-20 implementation tests.

---

## 86. VMMs, drivers, and privileged helpers

### LOCKED

A VMM/backend/driver/helper qualifies only if:

- its host role is permitted by MA-17;
- its provenance/source/license satisfy MA-19 where SerapeumOS distributes/manages it;
- its exact binary/version is qualified by MA-20.

Architectural compatibility never substitutes for binary supply-chain admission.

---

## 87. Appliance image provenance

### LOCKED

Every Agent Appliance image is a first-class signed release artifact.

Its provenance covers:

- guest base/root filesystem identity;
- kernel/boot components;
- installed packages and versions;
- SerapeumOS/Ankole Worker payloads;
- configuration baked into the image;
- image builder/toolchain;
- source/material set;
- final image digest.

A VM image is not an opaque trusted blob.

---

## 88. Appliance runtime mutation

### LOCKED

Production appliance images are immutable release assets except for explicitly designated runtime/workspace state.

Agents do not permanently `apt install`, `pip install`, or otherwise mutate the trusted appliance base and then cause that mutated machine to become a new trusted golden image.

New trusted image composition goes through MA-19/20 release flow.

---

## 89. Trusted extensions/plugins

### LOCKED

A trusted plugin/adapter update is a new executable supply-chain event.

It requires source/dependency/license/provenance/security review, qualification, and governed MA-18 installation/update.

Plugins cannot carry hidden self-updaters that bypass the product release path.

---

## 90. Agent-local untrusted extensions

### LOCKED

Agent-local untrusted Skills/tools/MCP servers may use a lighter admission policy appropriate to their MA-08 trust class, but:

- their origin/version/digest is still attributable;
- they remain inside the hostile Agent boundary;
- they cannot become trusted control-plane dependencies through repeated use;
- promotion to trusted status requires full MA-19/20 treatment.

---

## 91. Model artifacts

### LOCKED

Bundled/managed production model artifacts are content-addressed and provenance-recorded with, where applicable:

- model identity/version;
- exact weight digest;
- tokenizer/config/template digests;
- license/use/redistribution evidence;
- source/provider lineage;
- local runtime compatibility;
- MA-07/20 qualification status.

Model names alone are not sufficient identity.

---

## 92. External/local model acquisition

### LOCKED

User-acquired local models remain external artifacts until locally registered and qualified under MA-07/19/20 policy.

A model hub/download source is transport/evidence, not authority.

No model auto-update may silently change Agent behavior under the same model binding.

---

## 93. Source repository provenance

### LOCKED

The authoritative release source snapshot is bound to repository history plus an exact tree/archive digest and release-source authorization evidence.

Individual developer commit signatures may be useful evidence, but are not required to be the sole release trust mechanism and do not replace final release authorization.

Repository branch protection or hosted forge controls are not mandatory cloud dependencies.

---

## 94. Repository as project memory

### LOCKED

Supply-chain policy, component inventory definitions, source/dependency lock data, license evidence, release recipes, and provenance schemas are persisted as repository/project artifacts where appropriate.

Chat history is not the authoritative supply-chain record.

---

## 95. Release branch/tag semantics

### LOCKED

A release tag/version is a human/navigation label for a source snapshot/release record.

The exact source digest and signed Release Envelope remain authoritative if a tag is later moved, deleted, or recreated.

---

## 96. Release ceremony sequence

### LOCKED

The canonical production release sequence is:

```text
freeze exact source snapshot
→ resolve admitted dependency/material graph
→ controlled offline build
→ generate payload manifest + SBOM + license/provenance artifacts
→ sign build provenance
→ MA-19 supply-chain policy verification
→ MA-20 exact-candidate qualification
→ assemble final Release Envelope
→ Release Authorization binds exact qualified digests
→ MA-18 may stage/install/update
```

A change to any signed payload byte after qualification requires a new candidate/requalification as applicable.

---

## 97. Qualification evidence binding

### LOCKED

MA-20 qualification results identify the exact candidate artifact/release-envelope digest they tested.

A release signer cannot reuse a passing qualification report for different bytes, dependency graph, host-target build, or migration edge.

---

## 98. Emergency security releases

### LOCKED

Emergency releases may shorten scheduling/review latency but cannot bypass:

- source/dependency identity;
- build provenance;
- release authorization;
- architecture-invariant security vetoes;
- minimum MA-20 qualification required for the changed risk surface;
- MA-18 safe activation/recovery semantics.

“Emergency” changes sequencing, not authority.

---

## 99. Release channel separation

### LOCKED

Development/nightly/candidate/production artifacts are distinct release classes.

A development artifact cannot become production solely by renaming/copying it.

Production requires its own authorized Release Envelope and qualification state.

---

## 100. Local repository/update catalog

### LOCKED

A local/offline update repository may store multiple authorized release envelopes and security metadata.

The repository is an availability/distribution structure; individual packages remain independently verifiable.

Corruption of the repository index cannot grant authority to unauthorized payloads.

---

## 101. Network update discovery

### LOCKED

A future network updater may discover/download signed catalogs/packages, but:

- the network service is optional;
- it cannot sign or authorize releases merely by hosting them;
- failures degrade to offline/manual acquisition;
- transport compromise cannot bypass local signature/sequence/digest checks.

---

## 102. Freeze/rollback/mix-and-match attack resistance

### LOCKED

The update metadata model must resist at minimum:

- arbitrary software substitution;
- rollback to older security state;
- indefinite stale/freeze presentation when freshness can be determined;
- mix-and-match of otherwise valid release pieces;
- wrong-target software installation;
- malicious/partial mirrors.

The exact metadata format may follow or adapt a TUF-like model, but the security properties are architectural requirements.

---

## 103. Security metadata retention

### LOCKED

The installation retains the minimum trusted root/release/security metadata required to verify future packages and detect downgrade/revocation.

Cleanup/rollback cannot delete the only copy of the highest trusted security-floor state while claiming equivalent protection.

---

## 104. Supply-chain audit events

### LOCKED

Material events produce MA-14 audit evidence, including:

- component admission/block/revocation;
- source/upstream change;
- license classification change;
- vulnerability affectedness/exception decision;
- build-material set creation;
- build provenance issuance;
- root/signer rotation;
- release authorization/revocation;
- offline security-metadata import.

Audit records reference digests/IDs rather than embedding unnecessary secrets/source payloads.

---

## 105. Provenance privacy

### LOCKED

Provenance must not leak:

- signing private keys;
- API tokens;
- developer secrets;
- private prompts;
- unnecessary usernames/home paths;
- sensitive Company/customer data.

Build metadata is normalized to the minimum information needed for reproducibility, verification, and accountability.

---

## 106. Retention

### LOCKED

Release provenance, SBOM, license bundle, source bundle/reference set, build-material inventory, qualification identity, and signature/revocation metadata are retained for at least the support/recovery lifetime of the corresponding release and longer where required for audit/license obligations.

Deleting a retired binary does not automatically delete its provenance history.

---

## 107. Recovery of supply-chain metadata

### LOCKED

Supply-chain trust metadata needed to authenticate supported releases is part of protected backup/recovery scope under MA-13.

Restore cannot roll the installation back to an older trusted-root/security-floor state without explicit recovery semantics that detect the downgrade.

---

## 108. No self-authorized Agent dependency promotion

### LOCKED

An Agent may research, recommend, fetch into untrusted quarantine where authorized, or propose a dependency.

It cannot:

- mark its proposal admitted;
- alter trusted dependency locks;
- sign build provenance;
- authorize a release;
- waive a license/security blocker;
- raise its own extension to trusted-control-plane status.

---

## 109. AI recommendations are evidence, not authority

### LOCKED

Models may summarize licenses/advisories, identify likely vulnerable dependencies, suggest upgrades, or compare upstreams.

Their output remains untrusted analysis until verified against authoritative project/source/legal/security evidence.

A model hallucination cannot create supply-chain truth.

---

## 110. Scanner/tool independence

### LOCKED

A vulnerability/SBOM/license scanner is itself a supply-chain component and evidence producer.

Passing one tool does not prove completeness.

Critical release conclusions must remain reconstructable from retained source/material evidence rather than a proprietary scanner dashboard.

---

## 111. Unknown provenance fails closed

### LOCKED

For trusted production components, materially unknown source, license, dependency composition, artifact identity, or release provenance causes admission failure/quarantine.

The system does not classify “unknown” as “probably safe.”

---

## 112. Unknown vulnerability state is not zero risk

### LOCKED

Absence of a CVE/advisory match is not evidence that a component is vulnerability-free.

The release record distinguishes “no known applicable vulnerability found under current evidence” from “proven secure.”

---

## 113. Supply-chain exception governance

### LOCKED

Any temporary exception to normal MA-19 policy is explicit, narrow, time/condition-bounded, auditable, and cannot contradict Gold Rule #1 or a locked security invariant without reopening the governing architecture domain.

An Owner approval cannot silently redefine “open source,” remove provenance requirements, or authorize a known architecture-breaking dependency.

---

## 114. MA-18 integration contract

### LOCKED

MA-19 produces a structured release-admission verdict consumed by the MA-18 Maintenance Plane.

Conceptually:

```text
release_envelope_digest
supply_chain_policy_version
source_provenance_status
material_graph_status
license_status
vulnerability_status
signature/root_status
revocation/security_floor
sbom/provenance references
verdict = ADMISSIBLE | BLOCKED | REVOKED
reason_codes
```

MA-18 never replaces this verdict with filename/hash-only checks.

---

## 115. MA-20 integration contract

### LOCKED

MA-19 proves **what the candidate is and how it was produced/admitted**.

MA-20 proves **what those exact bytes actually do on qualified targets under required tests**.

Neither substitutes for the other.

---

## 116. MA-15 integration contract

### LOCKED

A system-evolution proposal that changes trusted code, dependency, build system, release policy, or upstream foundation becomes a governed candidate.

It cannot self-promote; it must re-enter MA-19 and MA-20 before MA-18 activation.

---

## 117. MA-08 extension integration contract

### LOCKED

Supply-chain rigor is proportional to extension trust class:

- trusted built-in/plugin/control-plane extension → full MA-19/20;
- Agent-local untrusted extension → attributable source/digest + MA-08 sandbox policy;
- promotion between classes → new full admission event.

---

## 118. Architecture-rejected approaches

### REJECTED

The following are not acceptable production supply-chain designs:

- `pip/npm/cargo/... install latest` during release or runtime;
- trusting a package because it came from the project's website/GitHub page;
- trusting a standalone checksum published beside the same compromised download;
- trusting a valid signature without product/target/sequence/revocation context;
- mutable tags/branches as final dependency identity;
- transitive dependency discovery only after deployment;
- proprietary mandatory runtime/plugin/cloud dependency above host boundary;
- binary-only required blob represented as “open source” without corresponding source/license basis;
- self-updating trusted plugin or Agent-generated hot patch;
- build from a dirty developer workstation as the canonical release build;
- release build with unrestricted network dependency resolution;
- unsigned/unbound SBOM generated separately from release bytes;
- scanner pass treated as proof of safety/license compliance;
- old authentic vulnerable release allowed to bypass a raised security floor;
- signing and release authorization controlled entirely by the same untrusted build job;
- public transparency/cloud signing service as a mandatory trust dependency;
- opaque golden VM image with unknown internal package provenance.

---

## 119. Explicitly deferred implementation selections

The following do **not** block MA-19 closure because the governing semantics are locked:

| Selection | Owner |
|---|---|
| exact SBOM format/version (e.g. SPDX/CycloneDX profile) | Implementation + MA-20 |
| exact provenance/attestation serialization (e.g. in-toto/SLSA predicate profile) | Implementation + MA-20 |
| exact package-manager lock tooling | Implementation |
| exact local artifact repository/cache implementation | Implementation |
| exact build sandbox/container/VM technology | Implementation + MA-17/20 |
| exact reproducible-build tooling | Implementation + MA-20 |
| exact signing algorithm/key format/provider | MA-10 + Implementation + MA-20 |
| exact offline-root threshold/key custody mechanism | Governance + MA-10/20 |
| exact host-native code-signing certificate strategy | Implementation + MA-20 |
| exact update metadata wire/storage format | Implementation + MA-20 |
| exact vulnerability databases/scanners | Implementation; policy requires multi-source evidence |
| exact vulnerability severity thresholds/SLAs | MA-20 release policy |
| exact license allowlist/compatibility matrix | Product/legal policy beneath OSS invariant |
| exact source-bundle archive format | Implementation |
| exact canonical Ankole upstream URL/license file hashes | Ankole Intake Receipt before production qualification |
| exact Windows VMM/backend binary choice | MA-20 from MA-17 candidates |
| exact Linux VMM/backend binary choice | MA-20 from MA-17 candidates |
| exact appliance base distro/kernel/package versions | Implementation + MA-20 |
| exact compiler/linker/bootstrap toolchain versions | Implementation + MA-20 |
| exact retention periods for retired release provenance | MA-13/14 product policy |

These are executable/product-policy values beneath the closed MA-19 trust architecture.

---

## 120. MA-19 closure decision

### CLOSED

MA-19 is architecture-complete.

Locked:

- canonical source/upstream identity distinct from transport/location;
- exact immutable source/dependency binding with strong independent digests;
- mutable tag/branch/`latest` references rejected as production authority;
- complete direct/transitive/build/native/appliance dependency closure;
- dependency-confusion prevention and no public-registry runtime resolution;
- vendored/fork lineage and explicit patch-series provenance;
- low-diff Ankole policy plus a required Ankole Intake Receipt for the locked foundation revision;
- explicit governed intake for all future Ankole upstream movement;
- OSS/local doctrine as an admission gate for SerapeumOS-controlled required/distributed production components above host boundary;
- host-substrate distinction without prerequisite laundering;
- NaraRouter excluded from final build/runtime/signing/update authority;
- license identity, compatibility, obligations, notices, and corresponding-source tracking;
- separate treatment for non-code/model licenses and user-supplied artifacts;
- multi-source vulnerability evidence with exact affectedness state;
- architecture-invariant vulnerability veto class, bounded exceptions, and post-release revocation;
- signed offline security/revocation imports and persisted security floors;
- full Build Materials Inventory and explicit Build Bootstrap Set;
- clean controlled network-disabled canonical release builds;
- content-addressed admitted material cache;
- versioned build-environment identity and verifiable exact-byte build provenance;
- reproducible/verifiable payload objective with honest nondeterminism boundaries;
- generated-code provenance without AI authority;
- logical separation of Root, Build Provenance, Release Authorization, and Security Revocation authorities;
- offline root trust, dual-control root changes, MA-10 signing-key isolation, and crypto agility;
- host-native signing/transparency services treated as supplemental, never mandatory authority;
- signed Release Envelope binding manifest, source, build provenance, SBOM, licenses, vulnerabilities, compatibility, MA-20 evidence, and security floor;
- machine-readable release SBOM plus richer Supply-Chain Registry;
- coherent binary/source/SBOM/license/provenance/qualification pairing;
- rollback/mix-and-match/wrong-software defenses with monotonic release/security metadata;
- first-install root bootstrap and explicit offline freshness limitations;
- key-compromise/revocation semantics;
- quarantine/non-execution for new upstream artifacts;
- explicit provenance for VMMs, drivers, appliance images, models, trusted plugins, and qualification tools;
- immutable appliance base rule;
- repository persistence for supply-chain project memory;
- exact release ceremony ordering so qualification and authorization bind the same bytes;
- no Agent/model self-promotion or supply-chain waiver authority;
- structured MA-19 verdict consumed by MA-18;
- explicit separation of MA-19 provenance proof from MA-20 executable qualification.

No material MA-19 architecture question remains inside this domain.

---

## 121. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-215 — Supply-chain trust is a reconstructable chain, not a source reputation check
Trusted production software requires canonical source/material identity, controlled build provenance, release authorization, policy admission, and MA-20 qualification.

### D-216 — Production materials are immutable and independently digested
Mutable branches/tags/version ranges/`latest` are non-authoritative; exact source and dependency snapshots are bound to strong content digests. Legacy Git commit IDs remain lineage locators only.

### D-217 — Complete dependency closure is mandatory
Direct, transitive, native, build-time executable, appliance, runtime, and other material dependencies are included in the admitted graph; unknown executable composition blocks release.

### D-218 — OSS/local doctrine is a production admission gate
Required/bundled/distributed SerapeumOS-controlled production software above the host boundary must be open source and locally operable; mandatory proprietary/cloud dependencies are inadmissible.

### D-219 — Host substrate cannot be used to launder closed product dependencies
OS-provided capabilities are modeled as host substrate under MA-17, but a SerapeumOS-distributed/managed closed component cannot be relabeled as a host prerequisite to bypass Gold Rule #1.

### D-220 — Ankole foundation requires exact intake provenance
The locked Ankole v1.0.4-rc.1 commit remains the baseline, but production admission requires an intake receipt binding canonical upstream, independent tree digest, license, dependencies, patches, vulnerability state, and source bundle.

### D-221 — Ankole upstream changes are governed supply-chain events
Moving away from the locked Ankole revision requires new provenance/security/license intake, MA-15 change governance, MA-20 qualification, and MA-18 deployment.

### D-222 — License compliance is release-bound evidence
Every production release binds component license identities, obligations/notices, and corresponding-source/source-bundle evidence; open-source status alone does not prove redistribution compatibility.

### D-223 — Vulnerability status is exact-component affectedness, not scanner output
Findings from multiple advisory sources are mapped to exact source/version/patch context and tracked as unknown/not-affected/affected/mitigated/patched/exception/revoked.

### D-224 — Security-invariant defeat is a release veto class
A known unmitigated vulnerability that defeats a locked security invariant cannot be waived merely because a build is current or functional; post-release findings may raise the MA-18 security floor.

### D-225 — Canonical production release builds are controlled and network-disabled
All materials are admitted first; the authoritative build consumes only declared local inputs in a clean environment and does not resolve mutable network dependencies.

### D-226 — Build provenance binds exact bytes to exact source/materials/environment
Every candidate has verifiable provenance identifying subject digests, source snapshot, material graph, builder, recipe, and build environment.

### D-227 — Reproducibility strengthens but does not replace trust
Canonical payloads are designed for reproducible/verifiable builds; nondeterministic packaging/signing envelopes are isolated and explained. Reproducibility does not override source/license/security/qualification gates.

### D-228 — Build authority and release authority are distinct
The Build Provenance Authority cannot self-authorize its own output. Root, build provenance, release authorization, and security revocation are separate logical authorities.

### D-229 — Supply-chain root is locally verifiable and not cloud-dependent
Routine production verification/signing must not require a hosted transparency log, cloud CA, keyless identity service, or proprietary signing service. Root changes are offline/high-risk and dual-controlled.

### D-230 — Release Envelope is the signed supply-chain identity
The Release Envelope binds exact payload manifest, source, build provenance, material graph, SBOM, license/vulnerability evidence, compatibility contracts, MA-20 qualification identity, and security floor.

### D-231 — SBOM is mandatory but not the sole supply-chain database
Every production release includes a machine-readable interoperable SBOM; the richer Supply-Chain Registry and Build Materials Inventory retain policy/provenance detail outside normal SBOM scope.

### D-232 — Offline updates preserve authenticity and anti-rollback semantics
Offline packages contain sufficient trust/release/security metadata for local verification, while persisted sequence/security-floor state prevents silent downgrade. Offline authenticity never falsely claims global freshness.

### D-233 — Signed old software can still be inadmissible
Revocation/security-floor metadata can block a historically authentic release or signer; signatures preserve provenance history but do not override current security policy.

### D-234 — No production dynamic public-registry dependency installation
Trusted runtime/update paths consume admitted Release Envelopes or separately admitted prerequisites; public registries never directly extend trusted production state.

### D-235 — Appliance images and privileged helpers are transparent supply-chain artifacts
VMMs/drivers/helpers and Agent Appliance images have explicit source/material/license/provenance and exact digests; opaque golden images are not trusted production foundations.

### D-236 — AI/Agent output cannot grant supply-chain trust
Agents/models may propose or analyze dependencies but cannot admit them, sign provenance/releases, waive blockers, or promote generated code into trusted production.

### D-237 — MA-19 and MA-20 prove different facts
MA-19 establishes exact identity, lineage, materials, licensing, vulnerability state, and release authorization; MA-20 establishes executable behavior/fitness of those exact bytes. MA-18 activates only after both gates pass.

---

## 122. Project-state transition

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

Current architecture domain:
MA-20 — Qualification / Release Gates

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Repository persistence:
PENDING

Next action:
MA-20-CLOSE — architecture only
```

---

## 123. Next action

**MA-20-CLOSE — Qualification / Release Gates**

Architecture only.

---

## Appendix A — Non-normative grounding

The MA-19 contract is intentionally implementation-neutral but is grounded in established software supply-chain practices:

- **NIST SP 800-218 (SSDF) 1.1** requires organizations to collect, safeguard, maintain, and share provenance data for software release components, including SBOM information, and protect its integrity. A draft SSDF 1.2 revision exists, but MA-19 does not depend on a draft becoming final.  
  https://csrc.nist.gov/pubs/sp/800/218/final

- **SLSA v1.2** is the current approved SLSA specification and defines Source and Build tracks plus provenance/attestation concepts for tracing artifacts to their source/build process. MA-19 adopts the security properties rather than mandating a single SLSA level/tool implementation.  
  https://slsa.dev/spec/v1.2/

- **The Update Framework (TUF)** documents update-system threats including arbitrary software, rollback, freeze, mix-and-match, wrong-software, and malicious-mirror attacks. MA-19 requires defenses against these classes while leaving exact metadata format as implementation design.  
  https://theupdateframework.io/docs/security/

- **CISA 2025 SBOM Minimum Elements** reinforces machine-readable component transparency and current minimum SBOM expectations.  
  https://www.cisa.gov/sites/default/files/2025-08/2025_CISA_SBOM_Minimum_Elements.pdf

- **SPDX 3.0.1** is a current standardized SBOM/provenance data specification. MA-19 permits a recognized interoperable SBOM standard and does not hard-code a permanent serialization choice.  
  https://spdx.github.io/spdx-spec/

- **OpenChain ISO/IEC 5230:2020** defines key requirements for an open-source license compliance program, while **ISO/IEC 18974:2023** addresses open-source security assurance. These support MA-19's separation of license compliance, vulnerability assurance, and release evidence.  
  https://openchainproject.org/license-compliance  
  https://openchainproject.org/security-assurance

- **CISA Known Exploited Vulnerabilities (KEV)** is a high-value exploitation-evidence input for vulnerability prioritization; MA-19 treats it as evidence within a multi-source affectedness process rather than a sole release authority.  
  https://www.cisa.gov/known-exploited-vulnerabilities-catalog

These references are grounding only. The normative SerapeumOS architecture is the LOCKED/CLOSED content above.
