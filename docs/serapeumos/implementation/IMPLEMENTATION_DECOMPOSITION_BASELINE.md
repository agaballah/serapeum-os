# SerapeumOS — Implementation Decomposition Baseline

## Authority / Basis

- **Final Master Architecture Gate:** PASS / ACCEPTED
- **MA-01→MA-20:** Architecture locked, CLOSED / PASS
- **TASK-006 Repository Mapping:** PASS / ACCEPTED
- **Repository Evidence Baseline SHA:** `c778a9678360cb85f038c80a3fa2a418ae6eadd9`
- **Decision Record:** D-268

---

## Classification Baseline

Preserved from accepted TASK-006 Part-A classification:

| MA | Primary Classification |
|----|----------------------|
| MA-01 | EXTEND_EXISTING (TCB hardening); PROPOSED_BACKEND_NOT_SELECTED (backend selection) |
| MA-02 | REUSE_AS_IS |
| MA-03 | NEW_SERAPEUMOS_COMPONENT_REQUIRED |
| MA-04 | EXTEND_EXISTING |
| MA-05 | EXTEND_EXISTING |
| MA-06 | EXTEND_EXISTING |
| MA-07 | REUSE_AS_IS |
| MA-08 | REUSE_AS_IS |
| MA-09 | EXTEND_EXISTING |
| MA-10 | EXTEND_EXISTING |
| MA-11 | NEW_SERAPEUMOS_COMPONENT_REQUIRED |
| MA-12 | EXTEND_EXISTING |
| MA-13 | NEW_SERAPEUMOS_COMPONENT_REQUIRED |
| MA-14 | EXTEND_EXISTING |
| MA-15 | EXTEND_EXISTING |
| MA-16 | EXTEND_EXISTING |
| MA-17 | EXTEND_EXISTING (contract) + PROPOSED_BACKEND_NOT_SELECTED (backend) + QUALIFICATION_OR_POLICY_LATER (empirical) |
| MA-18 | NEW_SERAPEUMOS_COMPONENT_REQUIRED |
| MA-19 | NEW_SERAPEUMOS_COMPONENT_REQUIRED |
| MA-20 | NEW_SERAPEUMOS_COMPONENT_REQUIRED (framework); QUALIFICATION_OR_POLICY_LATER (empirical execution) |

---

## Capability Dependency Model

### COMPANY / AUTHORITY

```
Principal identity substrate (REUSE_AS_IS)
    ↓
Company identity + Company membership (NEW component)
    ↕ COORDINATED_INTERFACE_DEPENDENCY
AuthZ/Capability/AA contract (EXTEND_EXISTING)
    ↓
Goal→Mission→Task hierarchy (EXTEND_EXISTING)
    consumes: Company scope + AuthZ primitives
```

**Note:** Base AuthZ/Capability primitives do NOT hard-depend on MA-04 completion. MA-04 task/reviewer integration is a later coordinated integration.

### SECURITY BOUNDARY

```
Hard Agent boundary contract (EXTEND_EXISTING) — independent of Company state
    ↓
Host broker contract (EXTEND_EXISTING)
    ↓
Resource Governor / host-controlled resource enforcement (NEW component)
```

Backend selection remains: **PROPOSED_BACKEND_NOT_SELECTED**

### STORAGE

```
Authoritative storage semantics (REUSE_AS_IS)
    ↓
Agent Home projection (REUSE_AS_IS)
    ↓
User-file Publication gate (EXTEND_EXISTING)
```

### RELIABILITY

```
Goal/Mission/Task execution semantics (EXTEND_EXISTING)
    ↓
Reliability / fencing / idempotency (EXTEND_EXISTING)
    ↑
MA-13 Backup/Restore depends on:
  - stable MA-09 storage semantics
  - MA-12 reliability/reconciliation semantics
```

### INSTALL / SUPPLY CHAIN

```
Release Envelope / package contract (NEW component)
    ↕ COORDINATED_INTERFACE_DEPENDENCY
Install/update state machine (NEW component)

Provenance/SBOM/signing tooling depends on defined Release Envelope/package contract
(NOT dependent on completed MA-18 activation)
```

### QUALIFICATION

```
Qualification/evidence framework (NEW component) — established early during controlled implementation
    ↓
Per-workstream qualification tests (QUALIFICATION_OR_POLICY_LATER)
    ↓
Final empirical MA-20 qualification execution (QUALIFICATION_OR_POLICY_LATER, release-gated)
```

---

## Gap Register (Stable, with PM Corrections)

| GAP-ID | MA | Locked Required Behavior | Exact Existing Repo Substrate | Missing Capability | Classification | PROPOSED Owning Area | Blocking Prerequisites | Security/State Implications | Proposed Decomposition Boundary |
|--------|----|------------------------|------------------------------|-------------------|----------------|---------------------|---------------------|----------------------------|------------------------------|
| GAP-001a | MA-01 | Hard Agent Appliance boundary; one Principal per boundary; broker-mediated host authority | RuntimeFabric in `app/kernel/src/runtime_fabric/`; WSL2 dev boundary only | Hard boundary enforcement code; guest/host transition contract | EXTEND_EXISTING | `app/kernel/src/runtime_fabric/` (PROPOSED) | None (independent of Company) | CRITICAL — defines trusted/untrusted perimeter | Isolated TCB ticket |
| GAP-001b | MA-01 | VMM/hypervisor selection | None selected; candidates: QEMU/WHPX/Hyper-V/Cloud Hypervisor | Final backend selection decision | PROPOSED_BACKEND_NOT_SELECTED | — (architecture decision) | MA-17 platform compatibility | Determines boundary details but not existence | Architecture decision ticket |
| GAP-002 | MA-03 | Company aggregate: identity, owner, membership, organizational units/lifecycle, explicit Company scope | **None found.** Zero results for Company schema/struct/table/`company_uid`/`tenant_id`/`org_id` | Complete Company aggregate; Principal reuse as substrate only | NEW_SERAPEUMOS_COMPONENT_REQUIRED | `app/control_plane/lib/ankole/company/` (PROPOSED) | Principal identity (REUSE) | CRITICAL — foundation for all authority scoping | Single coherent workstream |
| GAP-003 | MA-04 | Canonical Goal→Mission→Task; delegation; independent reviewer | BackgroundAgentJob (Job/Turn/TurnItem); no Goal/Task/Delegation/Reviewer schemas | DB-backed hierarchy; delegation; reviewer gate | EXTEND_EXISTING | `app/control_plane/lib/ankole/work_hierarchy/` (PROPOSED) | MA-03 Company; MA-06 AuthZ primitives | HIGH — authority bypass via task manipulation | Schema → validation → integration |
| GAP-004 | MA-06 | Three-layer separation: AuthZ ≠ Capability ≠ Action Assurance | AuthZ in kernel; no separate Capability module; AA partial | Capability issuance/revocation; AA lifecycle; layer separation | EXTEND_EXISTING | `app/kernel/src/authz/`, `app/control_plane/lib/ankole/authz/` | MA-03 Company (scoping) | CRITICAL — permission escalation risk | Capability module → AA lifecycle → validation |
| GAP-005 | MA-09 | Durable≠authoritative; /agents/ non-authoritative; user-file publication | Artifacts with payload exclusion; Agent Home projection rebuildable | Code enforcement; `/agents/` labeling; publication gate | EXTEND_EXISTING | `app/control_plane/lib/ankole/ai_gateway/artifacts/` | MA-03 Company | MEDIUM — data integrity confusion | Small scoped change |
| GAP-006 | MA-10 | Secret plaintext prohibition; broker-mediated access | Argon2id; AEAD; credential pools; some direct paths may exist | Comprehensive audit; broker mediation for all paths | EXTEND_EXISTING | `app/control_plane/lib/ankole/principals/` | MA-06 AuthZ | HIGH — credential leakage | Audit-first decomposition |
| GAP-007 | MA-11 | Trusted Resource Governor; hierarchical budgets; admission; preemption | Scattered references only; no Governor module | Full Resource Governor component | NEW_SERAPEUMOS_COMPONENT_REQUIRED | `app/control_plane/lib/ankole/resource_governor/` (PROPOSED) | MA-01 hard boundary | HIGH — host starvation/DOS risk | Single coherent component |
| GAP-008 | MA-12 | L0-L5 reliability; idempotency; crash recovery | Recovery policy; fence tests; no L0-L5 framework | L0-L5 levels; idempotency contracts; ambiguous-outcome handling | EXTEND_EXISTING | `app/agent_computer/src/core/codex-runner/job/recovery-policy.ts` | MA-04 Work Hierarchy | MEDIUM — duplicate effects / lost work | Level-by-level decomposition |
| GAP-009 | MA-13 | Backup/restore with quarantine and corruption response | **No code.** Website docs only | Full DR implementation | NEW_SERAPEUMOS_COMPONENT_REQUIRED | New module(s) (PROPOSED) | MA-09 stable storage; MA-12 reliability | MEDIUM — data loss without DR | Depends on MA-09 + MA-12 |
| GAP-010 | MA-14 | Four information classes; audit immutability; privacy | Structured logging; partial audit trail | Four-class separation; audit immutability; privacy boundaries | EXTEND_EXISTING | `app/agent_computer/src/observability/` | MA-06 AuthZ; MA-12 reliability | MEDIUM — compliance/audit risk | By information class |
| GAP-011 | MA-15 | Promotion path; poisoning defenses; evolution authority | Skill lessons with lease; eval framework; no promotion gate | Promotion gate; poisoning detection; autonomy boundaries | EXTEND_EXISTING | `app/control_plane/lib/ankole/brain/skill_lessons.ex` | MA-04; MA-05 | MEDIUM — authority drift | Single coherent component |
| GAP-012 | MA-16 | Product UX; Owner/Agent view separation | Console webapps; approval flows partial | Complete view separation; security prompt design | EXTEND_EXISTING | `app/webapps/console/` | MA-04; MA-06 | LOW — UX-specific | UI component by component |
| GAP-013 | MA-17 | Platform-neutral contract; Windows 11 x86-64 first; Linux family; ARM64 deferred | Windows-first; Linux partial; deploy manifests (24 files) | Platform contract code; qualification packages; ARM64 policy | EXTEND_EXISTING + PROPOSED_BACKEND_NOT_SELECTED + QUALIFICATION_OR_POLICY_LATER | `app/kernel/src/`, `tools/deploy/` | MA-01 TCB | MEDIUM — deployment uncertainty | Three-phase: contract → selection → empirical |
| GAP-014a | MA-18 | Install/update/rollback lifecycle; anti-downgrade | Deploy manifests (24 files); `rel/overlays/bin/*`; no update pipeline | Complete lifecycle; rollback; repair; anti-downgrade | NEW_SERAPEUMOS_COMPONENT_REQUIRED | `tools/deploy/`, `app/control_plane/rel/` | MA-09; MA-17; MA-19 Release Envelope | HIGH — state corruption on failure | (a) install state machine, (b) rollback, (c) migration validation |
| GAP-014b | MA-19 (package) | Release Envelope / package contract | Not present as formal artifact | Signed release envelope definition; package interface | NEW_SERAPEUMOS_COMPONENT_REQUIRED | `tools/deploy/` area (PROPOSED) | MA-18 install state machine | HIGH — trust chain at package boundary | Small focused component |
| GAP-014c | MA-19 (provenance) | Supply chain provenance; SBOM; signing; vulnerability intake | `bun.lock` only; no SBOM/signing/provenance | Provenance tracking; SBOM; signing; vulnerability intake | NEW_SERAPEUMOS_COMPONENT_REQUIRED | New tooling in `tools/` (PROPOSED) | MA-19 package contract; MA-18 install | HIGH — trust chain integrity | Decomposable by provenance layer |
| GAP-015a | MA-20 (framework) | Qualification/evidence framework; test taxonomy; adversarial qualification; release vetoes | Test infrastructure exists; e2e harnesses; no formal gates | Qualification policy; taxonomy; adversarial framework; readiness evidence | NEW_SERAPEUMOS_COMPONENT_REQUIRED | `tools/e2e/`, `tools/eval/`, policy docs (PROPOSED) | Available early | HIGH — no evidence standard | Framework first, then per-workstream tests |
| GAP-015b | MA-20 (empirical) | Final empirical MA-20 qualification execution | — | Run all per-target qualification suites; produce Qualification Receipt | QUALIFICATION_OR_POLICY_LATER | `tools/e2e/`, `tools/eval/` | GAP-015a complete; all gaps resolved | HIGH — unqualified release risk | Late-stage; release time only |

---

## High-Risk Delta Register

| Delta | MAs | Risk | Failure Consequence | Required Review Strength | Minimum Evidence Before Merge |
|-------|-----|------|--------------------|------------------------|------------------------------|
| Trusted/Untrusted Boundary | MA-01 | CRITICAL | Full host compromise; untrusted Agent gains host authority | Independent security review; formal verification preferred; adversary testing | Kernel TCB hardened; isolation tests pass; broker mediation verified |
| Company Authoritative State | MA-03 | CRITICAL | No authority scoping; all higher MAs undefined | Schema review; data model validation; multi-tenant isolation testing | Company aggregate implemented; membership invariants tested; single-Company constraint validated |
| AuthZ Policy Substrate | MA-06 | CRITICAL | Permission evaluation incorrect = unauthorized access | AuthZ logic review; test coverage for all grant types; negative-path testing | Three-layer separation enforced; permission evaluation tests pass |
| Capability Issuance/Revocation | MA-06 | CRITICAL | Stale capabilities = persistent unauthorized access | Capability lifecycle review; revocation propagation testing | Capability issuance/revocation complete; revocation tested across all scopes |
| Action Assurance Lifecycle | MA-06 | HIGH | Consequential actions without approval; receipts lost | AA lifecycle review; approval-gate testing; receipt integrity validation | AA lifecycle complete; approval-bypass prevention tested; receipt immutability verified |
| Secrets | MA-10 | CRITICAL | Credential leakage to untrusted Agent state | Secret audit; leakage testing; log-redaction validation | All credential paths brokered; plaintext prohibition enforced; leakage tests pass |
| Agent Appliance (Hard Boundary) | MA-01, MA-17 | CRITICAL | Guest compromise escapes to host; multi-Principal boundary sharing | Hypervisor security audit (post-selection); escape testing; isolation benchmarking | TCB hardened; one-Principal-per-boundary enforced; isolation verified |
| Host Brokers | MA-01, MA-06 | HIGH | Untrusted Agent directly accesses host resources | Broker mediation audit; boundary-crossing tests; authority-boundary validation | All host resource access mediated; broker tests cover all resource types |
| Durable/Authoritative Boundary | MA-09 | MEDIUM | Corrupted Company truth from durable-but-non-authoritative source | Data integrity testing; projection rebuild validation; corruption resilience | Enforcement in code; `/agents/` labeled non-authoritative; projection tests pass |
| User-File Publication | MA-09 | MEDIUM | Untrusted Agent publishes files without approval; path traversal | Publication gate review; path sanitization testing; authorization check validation | Publication gate implemented; path traversal tests pass; authorization enforced |
| Resource Governor | MA-11 | HIGH | Host starvation; Agent workloads consume all resources; host instability | Resource stress testing; fairness validation; preemption testing | Governor module complete; stress tests pass; no host degradation under load |
| Goal/Mission/Task + Delegation/Reviewer | MA-04 | HIGH | Authority bypass via task manipulation; delegated actions lack review | Hierarchy validation; delegation chain testing; reviewer independence validation | Canonical hierarchy implemented; delegation and reviewer gates tested; invariants hold |
| Reliability/Fencing/Idempotency | MA-12 | MEDIUM | Duplicate consequential effects; stale completions accepted; work lost on crash | Crash reconstruction testing; idempotency verification; fence validation | L0-L5 levels implemented; crash recovery tested; no duplicate effects observed |
| Audit/Receipts | MA-14 | MEDIUM | Undetectable unauthorized actions; compliance failure; audit trail tampering | Audit immutability testing; four-class separation validation; tamper detection | Four-class separation enforced; audit immutability verified; privacy boundaries tested |
| Backup/Restore | MA-13 | MEDIUM | Permanent data loss; unrecoverable corruption; no disaster recovery path | Restore validation; quarantine testing; corruption-response validation | Backup/restore implemented; restore tests pass; quarantine mechanism verified |
| System Evolution | MA-15 | MEDIUM | Autonomous improvement weakens security posture; poisoned lessons promote incorrectly | Promotion gate review; poisoning detection validation; autonomous-boundary testing | Promotion gate implemented; poisoning tests pass; evolution authority separated |
| Install/Update/Rollback | MA-18 | HIGH | State corruption on update failure; downgrade possible; no repair path | Migration testing; rollback validation; anti-downgrade enforcement; crash-reboot recovery | Complete lifecycle implemented; rollback tested; anti-downgrade enforced; migration integrity verified |
| Supply-Chain Provenance | MA-19 | HIGH | Untrusted binary admitted; dependency compromise undetected; trust chain broken | Dependency audit; SBOM completeness check; build reproducibility verification | Provenance tracking complete; SBOM generated; signing verified; vulnerability intake active |
| Qualification/Evidence Framework | MA-20 | HIGH | No standardized evidence; inconsistent qualification; release vetoes absent | Framework design review; taxonomy completeness check; waiver governance audit | Framework implemented; test taxonomy defined; release veto mechanism in place |
| Final MA-20 Qualification | MA-20 | HIGH | Unqualified candidate released; production fitness unproven | Full qualification suite execution; adversary testing; readiness evidence review | All per-target qualification suites pass; adversary tests pass; readiness evidence produced |

---

## First Implementation Workstream — PM LOCK

**Status:** SELECTED BY PM / NOT YET STARTED

**Workstream:** COMPANY DOMAIN FOUNDATION + PRINCIPAL IDENTITY INTEGRATION

**Purpose:** Implement MA-03 Company organizational identity on top of existing Ankole Principal identity substrate without altering Principal identity semantics.

**Explicit Exclusions from this workstream:**
- Rust TCB hardening (GAP-001a)
- VMM/backend selection (GAP-001b)
- MA-06 full AuthZ/Capability/AA implementation (GAP-004)
- MA-04 Goal/Mission/Task implementation (GAP-003)
- MA-17 host qualification (GAP-013)
- Install/update (GAP-014a)
- Supply-chain (GAP-014b/c)
- MA-20 empirical qualification (GAP-015b)

**This workstream WILL later be decomposed by PM into smaller implementation tickets.**

No coding task is authorized by this document itself.

---

## Locked Release Sequence

Preserved exactly:

```
MA-19 candidate/provenance admission
    ↓
MA-20 exact-candidate qualification
    ↓
MA-20 Qualification Receipt
    ↓
MA-19 Release Authorization
    ↓
MA-18 activation
```

---

## Mandatory Pre-Implementation Hygiene Gate

The selected first implementation workstream remains:

**Company Domain Foundation + Principal Identity Integration**

Status: **SELECTED / BLOCKED FROM CODING PENDING HYGIENE GATE**

Mandatory sequence before any product implementation:

1. Repository-First governance transition (TASK-007)
2. Repository Hygiene / Implementation-Readiness Audit (TASK-008)
3. Bounded hygiene repairs if required
4. Repository Hygiene Gate review
5. Hygiene Gate PASS / ACCEPTED
6. First bounded product-code implementation task

Hygiene must establish a trustworthy implementation baseline covering at least:

- repository/documentation truth hygiene
- stale/obsolete inherited material classification
- generated/build/runtime clutter
- dependency/build/config consistency
- current baseline build/test health
- licensing/attribution/upstream provenance hygiene
- repository naming/path consistency
- active vs historical/reference artifact separation
- worktree/branch assumptions
- implementation-agent navigation/readiness

Do NOT delete or clean anything in this task. Do NOT treat inherited Ankole
content as removable merely because it is inherited. Every later cleanup
candidate must first be classified and evidenced.

---

*Document created: 2026-09-12*
*Basis: TASK-006 PASS / ACCEPTED; D-268; D-269*
