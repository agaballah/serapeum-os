# SerapeumOS — Master Architecture

This is the cross-domain master index for the closed MA-01 → MA-20 architecture.
It synthesizes all twenty domains and maps the orthogonal state classifications
so a fresh agent does not mistake them for competing state machines.

## Closed architecture register

| MA | Domain | Status | Key locked outcomes |
|---|---|---|---|
| MA-01 | Host Integrity, Isolation & TCB | CLOSED | One-Agent-per-hard-boundary; trusted core owns identity/AuthZ/ActionAssurance/policy/state/audit/recovery/host-resource mediation; no arbitrary host mounts; agent network deny-by-default; QEMU/WHPX primary candidate; WSL2 rejected as production boundary |
| MA-02 | Runtime Topology & Process Boundaries | CLOSED | Trusted/untrusted process separation; lifecycle ownership; control channels; startup/shutdown/failure ownership |
| MA-03 | Company Domain | CLOSED | Company aggregate; Owner/hierarchy/departments; goals/missions; organizational identity and lifecycle |
| MA-04 | Agents / Roles / Missions / Tasks | CLOSED | Persistent Agent identity; role authority; task/workflow model; delegation; reviewer model; lifecycle transitions |
| MA-05 | Memory / Knowledge / Provenance | CLOSED | Memory classes; claims/evidence; confidence; contradiction; supersession; retrieval; retention; provenance |
| MA-06 | AuthZ / Capabilities / Action Assurance | CLOSED | Permission model; capability schema; risk classes; approvals; exact action binding; receipts; revocation |
| MA-07 | Models / Inference / Routing | CLOSED | Provider abstraction; local inference contract; model selection; routing; fallback; regression; model identity separation |
| MA-08 | Tools / Skills / Plugins / MCP / Research | CLOSED | Registration; capability binding; sandboxing; trust levels; external research controls; installation; lifecycle |
| MA-09 | Storage / Database / Artifacts | CLOSED | Authoritative stores; schema ownership; artifacts; transactions; user-file publication; data lifecycle |
| MA-10 | Secrets / Credentials / Principals | CLOSED | Secret storage; mediation; scope; injection; expiry; revocation; redaction; audit |
| MA-11 | Resource Governance | CLOSED | CPU/RAM/GPU/disk/network budgets; quotas; fairness; admission control; runaway containment |
| MA-12 | Reliability / Recovery | CLOSED | Checkpoints; retries; idempotency; cancellation; crash recovery; fencing; failure semantics |
| MA-13 | Backup / Restore / DR | CLOSED | Backup scope; encryption; restore ordering; quarantine; corruption response; disaster recovery |
| MA-14 | Observability / Audit / Privacy | CLOSED | Logs; traces; metrics; receipts; audit immutability; privacy boundaries; retention |
| MA-15 | System Evolution | CLOSED | Experience capture; evaluation; strategy candidates; experiments; promotion; rollback; poisoning defenses |
| MA-16 | Product UX / Permissions UX | CLOSED | Owner console; Agent/company views; approvals; security prompts; failures; explainability; recovery UX |
| MA-17 | Host Compatibility | CLOSED | Platform contract; filesystem semantics; path/case/locking differences; required host capabilities; qualification contract |
| MA-18 | Install / Update / Migration / Rollback | CLOSED | First-run; prerequisites; packaging; migration; rollback; repair; uninstall |
| MA-19 | Supply Chain / Upstream | CLOSED | Dependency provenance; signatures; SBOM; licenses; vulnerability management; Ankole intake; release provenance |
| MA-20 | Qualification / Release Gates | CLOSED | Test taxonomy; adversarial qualification; long-duration tests; platform matrix; release vetoes; readiness evidence |

## Orthogonal state-classification crosswalk

The architecture uses several intentional classification systems. They are
**orthogonal views**, not competing state machines. A single entity may carry
one label from each system simultaneously.

| Classification system | Source MA | Range | Purpose |
|---|---|---|---|
| `S*` security/storage-boundary classes | MA-01 | S0–S6 | Trust domain depth and isolation strength |
| `R*` storage ownership classes | MA-09 | R0–R6 | Data ownership and mutability authority |
| `L*` reliability/execution levels | MA-12 | L0–L5 | Crash-recovery and fencing guarantees |
| `SE-*` System Evolution change classes | MA-15 | SE-0 through SE-4 | Permitted evolution modification scope |
| Qualification evidence states | MA-20 | NOT_RUN, PASS, FAIL, INCONCLUSIVE, BLOCKED, NOT_APPLICABLE_WITH_RATIONALE, STALE | Empirical readiness level per evidence requirement |

A fresh agent reads each classification in context; no single axis dominates.

## Current architecture state

- **MA-01 → MA-20:** COMPLETE / PASS
- **Final Cross-Domain Consistency Audit:** COMPLETE — MA-01→MA-20 domain architecture consistency PASS; documentation-synchronization blockers identified by the audit were handled through ARCH-SYNC-01 / repository persistence and remain subject to current PM verification
- **Final Master Architecture Gate:** PENDING — Repository Persistence / Verification awaiting PM acceptance; Fresh-Agent Reconstruction Validation next prerequisite after persistence verification
- **Implementation:** NOT STARTED
- **Runtime prototypes:** PAUSED

## Foundation

- **Selected foundation:** Ankole v1.0.4-rc.1
- **Locked baseline commit:** `7434d934315881438d4788d41228ba31d2f26fbb`
- **Production admission:** Subject to MA-19 provenance and applicable MA-20 qualification
- **First qualification target/family:** Windows 11 x86-64 (NOT yet empirically qualified)

## SerapeumOS-owned differentiated domains

1. **Company Domain** — organizational structure, roles, goals, tasks
2. **System Evolution** — learning, research, strategy evaluation, safe evolution
3. **Action Assurance** — governed lifecycle enforcement across the full action chain
4. **Owner Governance** — constitutional rules and high-impact decision gates

## Authority precedence

1. Explicit current Owner instruction
2. `PROJECT_CONSTITUTION.md`
3. Current SerapeumOS governance and locked decisions:
   - `OWNER_CHARTER.md`
   - `PROJECT_MANAGER_CONTRACT.md`
   - `OWNER_COMMUNICATION_CONTRACT.md`
   - `DOCTRINE.md`
   - `ARCHITECTURE_BASELINE.md` — historical pre-MA baseline; cannot override closed MA architecture
   - `DECISION_LOG.md`
   - Closed MA documents (`architecture/01_*.md` through `20_*.md`)
4. Root `AGENTS.md` overlay
5. Applicable inherited Ankole `AGENTS.md` instructions

If two documents at the same precedence level materially conflict: STOP AND
ESCALATE TO PROJECT MANAGER / OWNER AS APPROPRIATE.

## Status vocabulary

| State | Meaning |
|---|---|
| LOCKED | Approved architecture/doctrine; implementation must follow it |
| PROPOSED | Candidate direction; cannot control implementation yet |
| UNRESOLVED | Open architecture question; implementation depending on it is blocked |
| REJECTED | Explicitly excluded direction |
| SUPERSEDED | Formerly valid decision replaced by a newer locked decision |
| CLOSED | All material architecture questions are LOCKED or explicitly deferred below architecture to governed implementation, backend selection, policy or executable qualification without changing the locked architecture semantics |

An MA domain may be CLOSED when all material architecture questions are either:
1. LOCKED; or
2. explicitly deferred below architecture to governed implementation, backend selection, policy or executable qualification without changing the locked architecture semantics.

A PROPOSED implementation/backend/qualification candidate inside a CLOSED MA is not automatically "historical." It may remain a current non-architecture-blocking candidate.

UNRESOLVED architecture that would change semantics still blocks architecture closure.

## Required artifacts per domain

Each MA document records, at minimum:

- Purpose and governing principle
- Locked decisions (with status)
- Proposed candidates (if any)
- Unresolved questions (if any)
- Cross-domain references
- Closure evidence

See individual MA documents for domain-specific artifact requirements.

## Implementation prohibition

No product implementation begins until the Final Master Architecture Gate
passes. ARCH-SYNC-01 documentation synchronization is a prerequisite for
that gate, not implementation.
