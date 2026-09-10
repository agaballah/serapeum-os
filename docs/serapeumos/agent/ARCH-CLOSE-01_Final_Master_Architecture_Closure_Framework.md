# SerapeumOS — ARCH-CLOSE-01
## Final Master Architecture Closure Framework

Status: **COMPLETED / HISTORICAL**

This framework established the permanent structure used to close the complete
SerapeumOS architecture before implementation. Its sequential closure procedure
has already completed through MA-20.

Current phase: **FINAL MASTER ARCHITECTURE / DESIGN GATE**

Implementation: **NOT STARTED**

Runtime prototyping: **PAUSED until architecture gate authorizes empirical qualification**

---

## 1. Purpose

ARCH-CLOSE-01 establishes the permanent structure used to close the complete SerapeumOS architecture before implementation.

The objective is not to build the product. The objective is to make the repository sufficient for any fresh capable Project Manager or execution agent to reconstruct:

- product doctrine;
- authority;
- architecture;
- state;
- security rules;
- prerequisites;
- implementation boundaries;
- active phase;
- exact task contract.

After this framework is persisted, architecture closes sequentially through **MA-01 → MA-20**. Product implementation starts only after the Final Master Architecture gate passes.

---

## 2. Authority

Authority precedence remains:

1. Explicit current Owner instruction
2. `docs/serapeumos/PROJECT_CONSTITUTION.md`
3. Current SerapeumOS governance and locked decisions
4. Root `AGENTS.md`
5. Applicable inherited Ankole `AGENTS.md`

Repository truth controls factual project state. Chat/model memory is not durable project truth.

---

## 3. Status vocabulary

Every architecture statement must use one of these states when material:

- **LOCKED** — approved architecture/doctrine; implementation must follow it.
- **PROPOSED** — candidate direction; cannot control implementation yet.
- **UNRESOLVED** — open architecture question; implementation depending on it is blocked.
- **REJECTED** — explicitly excluded direction.
- **SUPERSEDED** — formerly valid decision replaced by a newer locked decision.

An MA domain may be marked **CLOSED** only when all material design questions in that domain are LOCKED or explicitly deferred to a later governed phase without blocking implementation.

---

## 4. Authoritative final document tree

```text
AGENTS.md
PROJECT_BOOTSTRAP.md
PROJECT_STATE.md

docs/serapeumos/
├── PROJECT_CONSTITUTION.md
├── OWNER_CHARTER.md
├── PROJECT_MANAGER_CONTRACT.md
├── OWNER_COMMUNICATION_CONTRACT.md
├── DOCTRINE.md
├── ARCHITECTURE_BASELINE.md
├── PREREQUISITES.md
├── DECISION_LOG.md
├── ROADMAP.md
│
├── architecture/
│   ├── 00_MASTER_ARCHITECTURE.md
│   ├── 01_HOST_INTEGRITY_AND_TCB.md
│   ├── 02_RUNTIME_TOPOLOGY.md
│   ├── 03_COMPANY_DOMAIN.md
│   ├── 04_AGENTS_ROLES_TASKS.md
│   ├── 05_MEMORY_KNOWLEDGE_PROVENANCE.md
│   ├── 06_AUTHZ_ACTION_ASSURANCE.md
│   ├── 07_MODELS_INFERENCE_ROUTING.md
│   ├── 08_TOOLS_SKILLS_PLUGINS_MCP.md
│   ├── 09_STORAGE_DATABASE_ARTIFACTS.md
│   ├── 10_SECRETS_CREDENTIALS.md
│   ├── 11_RESOURCE_GOVERNANCE.md
│   ├── 12_RELIABILITY_RECOVERY.md
│   ├── 13_BACKUP_RESTORE_DR.md
│   ├── 14_OBSERVABILITY_AUDIT_PRIVACY.md
│   ├── 15_SYSTEM_EVOLUTION.md
│   ├── 16_PRODUCT_UX_SECURITY_UX.md
│   ├── 17_HOST_COMPATIBILITY.md
│   ├── 18_INSTALL_UPDATE_ROLLBACK.md
│   ├── 19_SUPPLY_CHAIN_UPSTREAM.md
│   └── 20_QUALIFICATION_RELEASE_GATES.md
│
├── agent/
│   ├── AGENT_BOOTSTRAP.md
│   ├── PROJECT_RECONSTRUCTION_PROTOCOL.md
│   ├── EXECUTION_AGENT_CONTRACT.md
│   └── EVIDENCE_AND_COMPLETION_CONTRACT.md
│
└── tasks/
    ├── TASK_TEMPLATE.md
    └── TASK_REGISTER.md
```

No parallel architecture source should be created outside this tree without PM approval.

---

## 5. Master architecture invariants

The following are already LOCKED and apply across all MA domains:

1. SerapeumOS-owned, required, distributed, and managed production components
   above the host substrate are **100% open source** and **100% local**.
   The host operating system / native host substrate is an external prerequisite
   and does not itself have to be open source.
2. NaraRouter is temporary development/validation inference only and must be replaceable by local inference without architectural redesign.
3. SerapeumOS core is **host-platform neutral**. Windows is one supported host,
   not the product architecture.
4. Host-specific security/runtime mechanisms sit behind bounded adapters/brokers.
5. Ankole v1.0.4-rc.1 at `7434d934315881438d4788d41228ba31d2f26fbb` is the locked
   low-level foundation baseline.
6. SerapeumOS directly owns Company Domain, System Evolution, Action Assurance, and Owner Governance.
7. Agent identity is persistent organizational identity. A model is replaceable intelligence, not identity or authority.
8. Organizational Truth, Execution Truth, Epistemic Truth, Working Context, and System Evolution Truth are separate state domains.
9. Working context is disposable and is not institutional memory.
10. AuthZ remains permission authority. Action Assurance governs the lifecycle around authorized actions.
11. Agents, models, generated code, browser workloads, plugins, shells, and downloads are untrusted.
12. A model, Agent, task, Worker, prompt, generated code, or tool may fail, but it must not silently damage the host or durable Company state.
13. Durable authoritative state cannot be mutated directly by an untrusted Agent.
14. Security and audit controls fail closed.
15. Repository content is permanent project memory.

---

## 6. MA-01 → MA-20 closure register (historical initial plan)

| MA | Domain | What must be locked before closure | Initial status (historical) |
|---|---|---|
| MA-01 | Host Integrity, Isolation & TCB | trust domains, TCB, hard Agent boundary, host brokers, capabilities, host-resource publication, network/secrets isolation, platform qualification contract | PARTIALLY LOCKED → now CLOSED |
| MA-02 | Runtime Topology & Process Boundaries | trusted/untrusted processes, lifecycle ownership, control channels, process boundaries, startup/shutdown and failure ownership | OPEN → now CLOSED |
| MA-03 | Company Domain | Company aggregate, Owner, hierarchy, departments/teams, goals/missions, organizational identity and lifecycle | OPEN → now CLOSED |
| MA-04 | Agents / Roles / Missions / Tasks | persistent Agent identity, role authority, task/workflow model, delegation, reviewer model, lifecycle and state transitions | OPEN → now CLOSED |
| MA-05 | Memory / Knowledge / Provenance | memory classes, claims/evidence, confidence, contradiction, supersession, retrieval, retention and provenance | OPEN → now CLOSED |
| MA-06 | AuthZ / Capabilities / Action Assurance | permission model, capability schema, risk classes, approvals, exact action binding, receipts and revocation | OPEN → now CLOSED |
| MA-07 | Models / Inference / Routing | provider abstraction, local inference contract, model selection, routing, fallback, regression and model identity separation | OPEN → now CLOSED |
| MA-08 | Tools / Skills / Plugins / MCP / Research | registration, capability binding, sandboxing, trust levels, external research controls, installation and lifecycle | OPEN → now CLOSED |
| MA-09 | Storage / Database / Artifacts | authoritative stores, schema ownership, artifacts, transactions, user-file publication and data lifecycle | OPEN → now CLOSED |
| MA-10 | Secrets / Credentials / Principals | secret storage, mediation, scope, injection, expiry, revocation, redaction and audit | OPEN → now CLOSED |
| MA-11 | Resource Governance | CPU/RAM/GPU/disk/network budgets, quotas, fairness, admission control, runaway containment | OPEN → now CLOSED |
| MA-12 | Reliability / Recovery | checkpoints, retries, idempotency, cancellation, crash recovery, fencing and failure semantics | OPEN → now CLOSED |
| MA-13 | Backup / Restore / DR | backup scope, encryption, restore ordering, quarantine, corruption response and disaster recovery | OPEN → now CLOSED |
| MA-14 | Observability / Audit / Privacy | logs, traces, metrics, receipts, audit immutability, privacy boundaries and retention | OPEN → now CLOSED |
| MA-15 | System Evolution | experience capture, evaluation, strategy candidates, experiments, promotion, rollback and poisoning defenses | OPEN → now CLOSED |
| MA-16 | Product UX / Permissions UX | Owner console, Agent/company views, approvals, security prompts, failures, explainability and recovery UX | OPEN → now CLOSED |
| MA-17 | Host Compatibility | platform contract, filesystem semantics, path/case/locking differences, required host capabilities and qualification | OPEN → now CLOSED |
| MA-18 | Install / Update / Migration / Rollback | first-run, prerequisites, packaging, migration, rollback, repair and uninstall | OPEN → now CLOSED |
| MA-19 | Supply Chain / Upstream | dependency provenance, signatures, SBOM, licenses, vulnerability management, Ankole intake and release provenance | OPEN → now CLOSED |
| MA-20 | Qualification / Release Gates | test taxonomy, adversarial qualification, long-duration tests, platform matrix, release vetoes and readiness evidence | OPEN → now CLOSED |

Closure proceeded strictly **MA-01 → MA-20** and is now complete. All MA domains are CLOSED / PASS.

This register is retained as historical closure-record evidence. Current architecture authority is `00_MASTER_ARCHITECTURE.md` and the closed MA documents.

---

## 7. MA-01 migrated decisions (historical closure record)

The following MA-01 decisions were migrated during architecture closure.

### LOCKED

- Security guarantees are platform-neutral; each supported host must prove enforcement.
- Trusted core owns identity, AuthZ, capabilities, Action Assurance, policy, authoritative-state mutation, audit, host-resource mediation and recovery.
- Untrusted workloads do not receive ambient host authority.
- One hard Agent Appliance boundary is assigned to one Agent principal at a time.
- Different Agents do not share the same hostile-code outer boundary concurrently.
- `/agents` is durable Agent workspace but is not authoritative Company state.
- No arbitrary host filesystem mounts into the Agent Appliance.
- No direct database credentials to Agents.
- Model runtime is separate and restricted.
- Agent network is deny-by-default.
- No direct GPU exposure by default.
- Host resource budgets are authoritative.
- Global pause/kill remains outside the Agent runtime.
- Compromised disposable appliance runtime is replaced rather than repaired.
- Windows production-boundary direction: QEMU/WHPX was the primary candidate at closure time.
- WSL2 is rejected as the production outer hostile-Agent boundary.
- Full Hyper-V remains a conditional/reference alternative.
- The execution architecture is locked independently of the final hypervisor/VMM.

### PROPOSED (historical closure-record items, not current architecture-blocking questions)

- Minimal immutable Linux Agent Appliance.
- LinuxKit as an appliance-construction candidate.
- Small guest-local appliance launcher if needed.

### UNRESOLVED (historical closure-record items; implementation deferred to governed qualification)

- Final appliance builder.
- Final Windows VMM/backend selection.
- Final Linux backend selection.
- Appliance/control-channel transport.
- Exact persistent workspace disk implementation.
- Final runtime packaging and supply-chain treatment.

Runtime prototypes are paused until the Final Master Architecture Gate authorizes empirical qualification.

---

## 8. Consolidated doctrine

`docs/serapeumos/DOCTRINE.md` must become the concise normative product doctrine. It must contain only durable rules, not implementation experiments.

Required doctrine sections:

- Product identity and purpose.
- Gold Rule #1.
- Platform-neutrality.
- Private Digital Company hierarchy.
- FUNCTION / LEARN / RESEARCH / EVOLVE.
- OBSERVE/EVALUATE and GOVERN/PROTECT.
- MEMORY / PROVENANCE.
- Agent ≠ Model.
- state separation.
- OSS reuse and low-diff Ankole rule.
- Action Assurance vs AuthZ.
- System Evolution safety boundary.
- failure/host-safety principle.
- repository-as-project-memory rule.

---

## 9. Prerequisite contract

`docs/serapeumos/PREREQUISITES.md` must separate:

### Product prerequisites
Capabilities that a supported host must provide, independent of implementation.

### Development prerequisites
Tools needed only to build/test SerapeumOS.

### Qualified implementation dependencies
Dependencies selected only after the related MA gate closes.

No candidate tool becomes a permanent prerequisite merely because it was used in an experiment.

The prerequisite document must cover:

- supported host capabilities;
- CPU/RAM/storage baseline;
- virtualization requirements;
- local inference requirements;
- filesystem requirements;
- security requirements;
- developer toolchain;
- offline/runtime requirements;
- architecture-specific optional prerequisites.

---

## 10. Fresh-agent bootstrap

Every execution agent must start from repository truth, not chat history.

Required reading sequence:

```text
1. AGENTS.md
2. PROJECT_BOOTSTRAP.md
3. PROJECT_STATE.md
4. PROJECT_CONSTITUTION.md
5. OWNER_CHARTER.md
6. PROJECT_MANAGER_CONTRACT.md
7. DOCTRINE.md
8. architecture/00_MASTER_ARCHITECTURE.md
9. relevant MA document(s)
10. DECISION_LOG.md
11. ROADMAP.md
12. agent/EXECUTION_AGENT_CONTRACT.md
13. agent/EVIDENCE_AND_COMPLETION_CONTRACT.md
14. nearest applicable AGENTS.md
15. assigned task file
```

The agent must not require previous Kilo conversation history.

---

## 11. Execution-agent behaviour

The execution agent:

- executes approved tasks;
- does not act as Project Manager;
- does not redesign architecture;
- does not convert PROPOSED or UNRESOLVED items into implementation decisions;
- verifies repository truth before work;
- preserves unrelated work;
- follows applicable inherited Ankole engineering rules unless SerapeumOS supersedes them;
- stops on architecture/governance conflict;
- reports evidence;
- never claims success without proof.

The agent receives **tasks, not architecture prompts**.

Its operating loop is:

```text
READ REPO TRUTH
→ READ TASK
→ VERIFY PRECONDITIONS
→ EXECUTE ONLY TASK
→ TEST
→ COLLECT EVIDENCE
→ REPORT
→ STOP
```

---

## 12. Canonical Kilo task format

Every implementation task must have:

```text
TASK-ID:
TITLE:

OBJECTIVE:
Why this task exists and the exact outcome required.

AUTHORITY:
The MA/decision documents that authorize the task.

PRECONDITIONS:
Required repository state and dependencies.

SCOPE:
What may change.

ALLOWED FILES / OWNERS:
Expected ownership surface.

FORBIDDEN:
Explicit non-goals and architecture boundaries.

REQUIRED BEHAVIOUR:
Observable implementation requirements.

ACCEPTANCE CRITERIA:
Binary criteria for completion.

VALIDATION:
Tests/checks that must run.

EVIDENCE:
Exact outputs/diffs/state required in the report.

STOP / ESCALATE:
Conditions where the agent must stop rather than invent a solution.

GIT HANDLING:
Branch/commit/push authority for this task.

FINAL REPORT:
Files changed, tests, evidence, residual risks, verdict.
```

A task must reference architecture rather than restating the entire architecture.

---

## 13. Definition of done for an execution task

A task is not complete because code was written or a command exited zero.

Completion requires:

1. requested behavior implemented;
2. architecture preserved;
3. required tests executed;
4. expected observable result verified;
5. repository state inspected;
6. no unauthorized scope expansion;
7. evidence returned;
8. unresolved material issue reported;
9. PM acceptance.

Only the PM closes the task.

---

## 14. Required PROJECT_STATE update (historical example)

When ARCH-CLOSE-01 was originally persisted, `PROJECT_STATE.md` was expected
to state current project status. `PROJECT_STATE.md` now owns current state and
must not be hardcoded from this historical framework.

## 15. Required DECISION_LOG additions (completed)

The following locked decisions were added to `DECISION_LOG.md` during architecture
closure and are now part of the permanent decision record:

### D-020 — Platform-neutral core
SerapeumOS core architecture is host-platform neutral. Host-specific security/runtime mechanisms must remain behind adapters/brokers.

### D-021 — Architecture closure before implementation
MA-01 through MA-20, doctrine, prerequisites and execution-agent operating rules must close before normal product implementation begins.

### D-022 — Repository-native execution-agent behaviour
Execution agents reconstruct project state from the repository and receive bounded task specifications. Prior chat history is never required.

### D-023 — Tasks, not architecture prompts
Once the execution-agent contract is established, Kilo/Codex receive task specifications. Architecture and doctrine remain repository authority and are not re-designed inside task prompts.

### D-024 — Runtime prototype pause
QEMU/LinuxKit/runtime prototype work is paused during Final Master Architecture closure and resumes only when the architecture gate authorizes empirical qualification.

---

## 16. Required ROADMAP update (historical)

The original roadmap sequence established by this framework was:

```text
1. ARCH-CLOSE-01 — architecture closure framework
2. MA-01 closure
3. MA-02 closure
...
21. MA-20 closure
22. Final cross-domain consistency audit
23. Fresh-agent reconstruction validation
24. Final Master Architecture Gate PASS
25. Implementation task decomposition
26. Kilo execution-agent activation
27. Controlled implementation
28. Qualification
29. Release preparation
```

This sequence has been superseded by the current ROADMAP.md. No product
implementation occurs before the Final Master Architecture Gate passes.

---

## 17. Fresh-agent reconstruction validation

After the framework and all MA documents are persisted, start a fresh execution agent with no prior SerapeumOS conversation context.

Its first task is read-only:

**TASK-000 — Repository Reconstruction Qualification**

It must reconstruct only from repository content:

- product purpose;
- Owner/PM/agent authority;
- Gold Rule;
- foundation;
- current phase;
- all closed MA domains;
- unresolved architecture items;
- Agent/model distinction;
- state model;
- security/failure principle;
- implementation prohibition before gate pass;
- current next action;
- task execution rules.

PASS requires no material dependency on chat history and no contradiction with repository truth.

Failure means the repository documentation must be repaired before implementation.

---

## 18. ARCH-CLOSE-01 completion criteria

ARCH-CLOSE-01 is complete when:

- the authoritative document tree exists in the repository;
- status vocabulary is adopted;
- MA-01→MA-20 files exist;
- current MA-01 decisions are migrated;
- doctrine and prerequisite ownership are defined;
- execution-agent behaviour is durable;
- canonical task format exists;
- PROJECT_STATE, DECISION_LOG and ROADMAP are updated;
- no product code is changed;
- the repository is ready to close MA-01 sequentially.

Fresh-agent reconstruction is the final validation of the overall architecture-documentation closure before implementation.

---

## 19. Immediate next architecture action (historical)

After repository persistence of ARCH-CLOSE-01, the original next action was:

**MA-01-CLOSE — Host Integrity, Isolation & Trusted Computing Base**

Architecture only.

No QEMU test.
No LinuxKit build.
No runtime prototype.
No product implementation.

This action has been completed. Current next action is read from PROJECT_STATE.md
or ROADMAP.md.
