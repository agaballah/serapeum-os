# Decision Log

Chronological register of locked project decisions. Each entry is ordered by
project sequence ID. Dates are recorded where historically exact; otherwise
sequence ID is the primary ordering key.

---

## D-001 — 100% Open Source and 100% Local target

- **Status:** LOCKED
- **Decision:** The final SerapeumOS system must be 100% open source and 100% local.
  No proprietary cloud infrastructure may be a required final dependency.
- **Reason:** The product vision requires full data sovereignty and elimination
  of mandatory cloud dependencies.
- **Supersession:** Only an explicit Owner-approved constitutional change may
  supersede this decision.

---

## D-002 — NaraRouter is temporary inference only

- **Status:** LOCKED
- **Decision:** NaraRouter is permitted temporarily during development and
  validation. It must remain replaceable by local AI.
- **Reason:** Temporary inference capability is needed during bootstrap while
  local inference stacks are being qualified.
- **Supersession:** None. NaraRouter is explicitly temporary by definition.

---

## D-003 — System capabilities model

- **Status:** LOCKED
- **Decision:** SerapeumOS capabilities = Function / Learn / Research / Evolve,
  with cross-cutting rails Observe/Evaluate and Govern/Protect.
- **Reason:** This model captures the full adaptive loop required for an
  autonomous digital organization.
- **Supersession:** Only via constitutional change.

---

## D-004 — Learning scope includes failure, success, and strategy

- **Status:** LOCKED
- **Decision:** System learning must include failures, successes, repeated
  patterns, corrections, outcomes, and strategy performance. It must also
  identify successful strategies and determine what worked, under which
  conditions, whether it generalizes, and when it should be revalidated.
- **Reason:** Limiting learning to "lessons learned from failures" misses
  positive pattern recognition and strategy adoption.
- **Supersession:** Only via constitutional change.

---

## D-005 — Gate 1 PASS

- **Status:** LOCKED
- **Decision:** Most hard infrastructure already exists across open source
  projects. No single known OSS project implements the complete SerapeumOS
  target.
- **Reason:** Gate 1 question: "Has somebody already built most of this?"
- **Supersession:** N/A — gate result.

---

## D-006 — Gate 2 PASS

- **Status:** LOCKED
- **Decision:** Existing OSS should be reused aggressively instead of rebuilding.
- **Reason:** Gate 2 question: "Should existing OSS be reused instead of
  rebuilding everything?"
- **Supersession:** N/A — gate result.

---

## D-007 — Foundation Composition PASS — Ankole selected

- **Status:** LOCKED
- **Decision:** Ankole v1.0.4-rc.1 is selected as the primary low-level
  foundation for SerapeumOS.
- **Reason:** Ankole provides the required identity, AuthZ, Brain, jobs,
  workflow, scheduling, and runtime infrastructure.
- **Supersession:** Only via an explicit Owner-approved foundation change.

---

## D-008 — Cyber AI Team and Paperclip are references, not runtimes

- **Status:** LOCKED
- **Decision:** Cyber AI Team and Paperclip are reference/architectural
  adaptation sources. They are NOT parallel control planes or second runtimes.
- **Reason:** Running two control planes would duplicate identity, AuthZ,
  and execution infrastructure, violating the low-diff principle.
- **Supersession:** Only via constitutional change.

---

## D-009 — SerapeumOS directly owns four differentiated domains

- **Status:** LOCKED
- **Decision:** SerapeumOS directly owns its differentiated product/governance
  domains: Company Domain, System Evolution, Action Assurance, and Owner
  Governance.
- **Reason:** These four layers express the product differentiation and
  are not provided by Ankole in the required form. Other capabilities may come
  from Ankole or from other supporting OSS components selected through bounded
  integrations; not every non-SerapeumOS capability must come from Ankole.
- **Supersession:** Only via architectural decision gate.

---

## D-010 — Product name

- **Status:** LOCKED
- **Decision:** Product name is SerapeumOS.
- **Reason:** Selected by the Owner.
- **Supersession:** Only via explicit Owner decision.

---

## D-011 — Public repository

- **Status:** LOCKED
- **Decision:** Public repository is agaballah/serapeum-os on GitHub.
- **Reason:** Owner's GitHub account is agaballah.
- **Supersession:** Only via explicit Owner decision.

---

## D-012 — Independent downstream, not GitHub fork

- **Status:** LOCKED
- **Decision:** SerapeumOS is an independent downstream repository that
  preserves complete Ankole Git ancestry. It is NOT a GitHub fork.
- **Reason:** An independent repository gives SerapeumOS full governance
  autonomy while preserving provenance.
- **Supersession:** Only via constitutional change.

---

## D-013 — Qualified foundation commit

- **Status:** LOCKED
- **Decision:** Qualified foundation = Ankole v1.0.4-rc.1 at exact commit
  7434d934315881438d4788d41228ba31d2f26fbb.
- **Reason:** This is the architecture-qualified baseline commit selected
  by the foundation qualification process.
- **Supersession:** Only via an explicit foundation requalification decision.

---

## D-014 — GitHub/repository as permanent project memory

- **Status:** LOCKED
- **Decision:** GitHub/repository content is the permanent authoritative
  source of truth for SerapeumOS. Chat history and model memory are
  ephemeral.
- **Reason:** A fresh capable AI with zero prior conversation history must
  be able to reconstruct the project solely from the repository.
- **Supersession:** Only via constitutional change.

---

## D-015 — Current development workspace

- **Status:** LOCKED
- **Decision:** Current development workspace is D:\SerapeumOS on Windows
  using VS Code + Kilo. No WSL or Docker requirement is locked at this phase.
- **Reason:** Direct Windows development matches the existing workflow.
  Toolchains are installed only when an approved task proves they are required.
- **Supersession:** Can be changed by the Project Manager without Owner
  approval, as long as the change does not violate Gold Rule #1.

---

## D-016 — SerapeumOS governance precedence over inherited repository rules

- **Status:** LOCKED
- **Decision:** SerapeumOS governance controls SerapeumOS project/repository
  management. Inherited Ankole engineering instructions remain applicable to
  inherited Ankole implementation areas except where explicitly superseded by
  SerapeumOS governance.
  Ankole-specific changelog/version/release requirements do not automatically
  apply to SerapeumOS-only governance/project-memory commits.
- **Reason:** SerapeumOS is an independent downstream product. Automatically
  applying upstream Ankole repository-release semantics to all SerapeumOS
  commits would incorrectly make SerapeumOS governance changes look like
  Ankole product releases and creates conflicting authority.
- **Supersession:** Only through an explicit Owner-approved repository-governance
  decision.

---

## D-017 — Repository reconstruction contract validated

- **Status:** LOCKED
- **Decision:** A fresh capable Project Manager AI with zero prior SerapeumOS
  conversation history successfully reconstructed from repository truth:
  product identity, authority model, Gold Rule #1, instruction precedence,
  foundation, SerapeumOS-owned domains, Action Assurance semantics, System
  Evolution, project status, next gate.
- **Reason:** This validates the repository-as-project-memory requirement
  established by D-014.
- **Supersession:** N/A. Future reconstruction failure requires repair/revalidation
  rather than deletion of this historical validation.

---

## D-018 — Constitution and Owner Communication Contract are first-class governance

- **Status:** LOCKED
- **Decision:** SerapeumOS maintains dedicated `PROJECT_CONSTITUTION.md` and
  `OWNER_COMMUNICATION_CONTRACT.md` as mandatory Project Manager bootstrap
  documents.
- **Reason:** Constitutional authority and Owner interaction rules must survive
  individual AI sessions and cannot depend on chat memory.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-019 — Strict Project Manager / Execution Agent role separation

- **Status:** LOCKED
- **Decision:** The Project Manager does not perform normal product implementation.
  The Project Manager architects, plans, delegates, reviews, accepts/rejects,
  and governs. Authorized execution agents implement, edit source, run
  implementation commands, test, build, and commit/push when authorized.
  If no execution agent can perform a required implementation task, the Project
  Manager reports the blocker to the Owner rather than silently collapsing
  management and coder roles.
- **Reason:** Separation preserves architecture fidelity, independent review,
  accountability, and auditability.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-020 — Platform-neutral core

- **Status:** LOCKED
- **Decision:** SerapeumOS core architecture is host-platform neutral. Host-specific
  security/runtime mechanisms must remain behind bounded adapters and brokers.
- **Reason:** The product must be operable on any host satisfying the prerequisites
  in PREREQUISITES.md. Windows 11 x86-64 is the first production qualification
  target/family. Windows is not the architecture and is not yet empirically
  release-qualified.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-021 — Architecture closure before implementation

- **Status:** LOCKED
- **Decision:** MA-01 through MA-20, doctrine, prerequisites and execution-agent
  operating rules must close before normal product implementation begins.
- **Reason:** Implementation without closed architecture risks architectural drift,
  unauthorized security weakening, and inconsistent state separation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-022 — Repository-native execution-agent behaviour

- **Status:** LOCKED
- **Decision:** Execution agents reconstruct project state from the repository and
  receive bounded task specifications. Prior chat history is never required.
- **Reason:** Repository-as-project-memory (D-014) requires that any fresh agent
  can operate from repository truth alone.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-023 — Tasks, not architecture prompts

- **Status:** LOCKED
- **Decision:** Once the execution-agent contract is established, Kilo/Codex
  receive task specifications. Architecture and doctrine remain repository
  authority and are not re-designed inside task prompts.
- **Reason:** Mixing architecture prompts with task execution conflates PM and
  agent roles, risking unsanctioned architecture changes.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-024 — Runtime prototype pause

- **Status:** LOCKED
- **Decision:** QEMU/LinuxKit/runtime prototype work is paused during Final Master
  Architecture closure and resumes only when the architecture gate authorizes
  empirical qualification.
- **Reason:** Prototypes before architecture closure risk anchoring on unapproved
  implementation choices.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-025 — Platform-neutral host security contract

- **Status:** LOCKED
- **Decision:** The SerapeumOS security guarantee is defined independently of host OS.
  Each supported platform must prove an implementation that enforces the same contract.
- **Reason:** Security must be portable across host platforms; host-specific proof
  is a prerequisite, not an exception.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-026 — Hostile Agent runtime outside TCB

- **Status:** LOCKED
- **Decision:** Agent reasoning, generated code, browser, tools, plugins and Worker-local
  execution are untrusted and cannot directly own authoritative Company state or host
  authority.
- **Reason:** The trusted computing base must be strictly separated from hostile
  execution to contain compromise.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-027 — One Agent principal per hard appliance boundary

- **Status:** LOCKED
- **Decision:** One hard Agent execution boundary is assigned to one Agent principal
  at a time. Different Agent principals do not concurrently share the same outer
  hostile-code boundary.
- **Reason:** Shared hostile boundaries create cross-Agent contamination vectors.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-028 — Durable Agent workspace is non-authoritative

- **Status:** LOCKED
- **Decision:** `/agents` provides durable Agent continuity but is not authoritative
  Company truth.
- **Reason:** Authoritative state resides in PostgreSQL/Artifacts; `/agents` is
  Agent working state, not organizational truth.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-029 — Broker-mediated host authority

- **Status:** LOCKED
- **Decision:** Host files, host execution, devices, secrets, networking and publication
  are broker/capability mediated and deny-by-default.
- **Reason:** Direct host access from untrusted execution breaks the trust boundary.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-030 — WSL2 rejected as production outer Agent boundary

- **Status:** LOCKED
- **Decision:** WSL2 may be used for development/tooling but is not accepted as the
  production hard boundary between hostile Agent principals.
- **Reason:** WSL2 shares the Windows kernel and host process space, weakening the
  isolation contract required by MA-01.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-031 — Backend implementation is replaceable

- **Status:** LOCKED
- **Decision:** Hypervisor, appliance builder and host-specific isolation technology
  are replaceable implementations of the MA-01 contract, not SerapeumOS product
  architecture.
- **Reason:** Architecture is backend-agnostic; implementation is a qualification
  selection, not a design lock.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-032 — Single trusted runtime control authority

- **Status:** LOCKED
- **Decision:** SerapeumOS has one trusted Control Plane for runtime orchestration and
  authoritative execution decisions. Agent Computer remains execution, not control authority.
- **Reason:** Multiple control authorities create race conditions and ambiguous ownership.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-033 — Runtime Controller owns hostile-compute lifecycle

- **Status:** LOCKED
- **Decision:** Creation, assignment, admission, resource control, stop, kill, and replacement
  of Agent Appliances are controlled outside the Agent runtime.
- **Reason:** The hosted runtime must not control its own containment.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-034 — Outer Agent assignment constrains inherited Worker pool

- **Status:** LOCKED
- **Decision:** Ankole Worker may remain pool-scoped internally, but SerapeumOS admits work
  for only one Agent principal per hard appliance assignment at a time.
- **Reason:** Multi-Agent sharing of a single runtime boundary violates the isolation contract.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-035 — RuntimeFabric retained as logical Worker boundary

- **Status:** LOCKED
- **Decision:** RuntimeFabric message/RPC/file semantics are reused. Its physical transport
  remains replaceable and is not product-domain architecture.
- **Reason:** Logical protocol reuse avoids reinventing the Worker control channel.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-036 — Readiness is explicit and layered

- **Status:** LOCKED
- **Decision:** Process existence is not readiness. Agent execution starts only after durable
  services, security services, appliance, Worker, authentication, and assignment admission
  are valid.
- **Reason:** Implicit readiness creates race windows where incomplete state accepts work.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-037 — Model runtime is separate non-authoritative compute

- **Status:** LOCKED
- **Decision:** Model runtime may be shared or dedicated under MA-07, but it never becomes
  Agent identity, Company-state authority, or runtime orchestration authority.
- **Reason:** Model binding must remain swappable without identity or authority disruption.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-038 — Company is an explicit SerapeumOS aggregate

- **Status:** LOCKED
- **Decision:** Company identity is durable and distinct from installation, Principal, runtime,
  model, and host.
- **Reason:** Conflating Company with any transient layer enables identity corruption on reinstallation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-039 — Reuse Ankole Principal identity

- **Status:** LOCKED
- **Decision:** Humans, Agents, and system subjects continue to use Ankole Principal identity.
  SerapeumOS adds Company semantics above it rather than duplicating identity.
- **Reason:** Duplicate identity systems create sync failures and authority ambiguity.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-040 — One human Company Owner

- **Status:** LOCKED
- **Decision:** Every active Company has exactly one human Company Owner. AI/system principals
  cannot hold Company Owner authority.
- **Reason:** Shared or automated Owner authority breaks accountability and constitutional enforcement.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-041 — Company Agents are single-Company identities

- **Status:** LOCKED
- **Decision:** A SerapeumOS Agent belongs to exactly one Company organizational identity.
  Cross-Company rehoming is not a normal operation.
- **Reason:** Multi-Company Agents create cross-Company data leakage vectors.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-042 — Organization does not imply authorization

- **Status:** LOCKED
- **Decision:** Hierarchy, reporting, role, and placement govern organizational responsibility
  but do not bypass AuthZ or Action Assurance.
- **Reason:** Organizational authority ≠ execution authority; conflating them breaks least-privilege.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-043 — Installation and Company remain distinct

- **Status:** LOCKED
- **Decision:** Even if the initial product exposes one Company per installation, durable
  architecture keeps explicit Company scope.
- **Reason:** Installation scope is operational; Company scope is organizational.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-044 — Organizational roles are not Principal types

- **Status:** LOCKED
- **Decision:** Supervisor, Manager, Specialist, and Reviewer are Company role classes assigned
  to Agent Principals; they do not extend the Principal type system.
- **Reason:** Role inheritance would conflate identity with temporary assignment.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-045 — Agent identity is independent from role, mission, model and runtime

- **Status:** LOCKED
- **Decision:** The Ankole Agent Principal remains the stable Agent identity across role, Mission,
  model, Worker, appliance, and task changes.
- **Reason:** Identity churn on role/model/runtime changes breaks durable Authorization and audit.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-046 — Canonical work hierarchy

- **Status:** LOCKED
- **Decision:** SerapeumOS uses Goal → Mission → Task → execution. Workflow, BackgroundAgentJob,
  Agent Call and Actor Turn are execution mechanisms beneath the canonical Task.
- **Reason:** A single canonical hierarchy prevents ambiguous ownership of work state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-047 — Primary AI role classes

- **Status:** LOCKED
- **Decision:** The organizational AI role classes are Supervisor, Manager, Specialist, and Reviewer.
  Each active Agent has one primary role class at a time.
- **Reason:** Multiple simultaneous primary roles create authority conflict and audit ambiguity.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-048 — One Primary AI Supervisor

- **Status:** LOCKED
- **Decision:** Each active Company has one designated Primary AI Supervisor beneath the human
  Company Owner.
- **Reason:** Multiple Supervisors create conflicting delegation and review authority.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-049 — One accountable Agent per Task

- **Status:** LOCKED
- **Decision:** Every committed Task has exactly one accountable Agent at a time; contributions
  and delegation do not make accountability ambiguous.
- **Reason:** Shared accountability prevents clear audit and accountability tracing.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-050 — Formal review requires independent Principal

- **Status:** LOCKED
- **Decision:** A formal review gate cannot be satisfied by the primary executor of the reviewed
  revision.
- **Reason:** Self-review invalidates the review guarantee.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-051 — Delegation is explicit and authority-attenuating

- **Status:** LOCKED
- **Decision:** Delegated work has durable lineage and may not exceed the authority/scope from
  which it was delegated.
- **Reason:** Implicit or expanding delegation breaks accountability chains.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-052 — Runtime success is not Task completion

- **Status:** LOCKED
- **Decision:** Workflow, Job, Agent Call, or Turn success is execution evidence; canonical Task
  completion requires Task acceptance criteria and required review.
- **Reason:** Execution success without acceptance criteria invites incomplete or wrong work.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-053 — MISSION.md is projection, not authority

- **Status:** LOCKED
- **Decision:** The Agent Mission is trusted durable semantic state; Worker-visible `MISSION.md`
  is a projection of that state.
- **Reason:** Filesystem edits to MISSION.md must not override authoritative PostgreSQL state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-054 — Five truth/state classes remain separate

- **Status:** LOCKED
- **Decision:** Organizational Truth, Execution Truth, Epistemic Truth, Working Context, and
  System Evolution Truth are distinct and cannot silently overwrite one another.
- **Reason:** Cross-domain contamination corrupts accountability and provenance.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-055 — Evidence precedes durable epistemic claims

- **Status:** LOCKED
- **Decision:** Durable knowledge requires explicit provenance. Model output alone is not
  external-world evidence.
- **Reason:** Unprovenanced claims corrupt epistemic truth and enable hallucination drift.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-056 — Reuse Ankole Fact/Take semantics

- **Status:** LOCKED
- **Decision:** Ankole Facts remain challengeable factual claims; Takes remain judgments/hypotheses.
  Neither is infallible truth.
- **Reason:** Blurring fact and judgment undermines contradiction detection and supersession.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-057 — Retrieval is not authority

- **Status:** LOCKED
- **Decision:** Embeddings, chunks, lexical/vector ranking, reranking, salience and context
  packs are rebuildable retrieval projections and cannot determine truth.
- **Reason:** Retrieval rank reflects relevance, not correctness or authority.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-058 — Working Context is disposable

- **Status:** LOCKED
- **Decision:** Information entering model context does not become institutional memory without
  an explicit governed write.
- **Reason:** Context leakage into durable state bypasses provenance and revision control.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-059 — Company scope precedes audience scope

- **Status:** LOCKED
- **Decision:** All epistemic records are Company-scoped. `world` is only the broadest audience
  inside that Company, never cross-Company global scope.
- **Reason:** Cross-Company audience promotion leaks organizational isolation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-060 — Contradictions remain explicit until resolved

- **Status:** LOCKED
- **Decision:** Contradiction detection never silently rewrites competing claims; unresolved
  material contradictions remain visible.
- **Reason:** Silent overwrites erase audit history and hide disagreement evidence.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-061 — Corrections preserve history

- **Status:** LOCKED
- **Decision:** Fact expiration, Take deactivation, Claim supersession, and Object versioning/soft
  deletion are preferred over destructive overwrite.
- **Reason:** Destructive overwrite destroys provenance and revision history.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-062 — Learning lessons are not factual/governance truth

- **Status:** LOCKED
- **Decision:** Operational lessons/evolution evidence are separated from external-world Facts
  and require MA-15 promotion before changing system strategy/governance.
- **Reason:** Direct promotion of lessons bypasses evolution governance and poisoning defenses.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-063 — Ankole AuthZ remains the permission substrate

- **Status:** LOCKED
- **Decision:** Principal/group grants over resource, action, and condition remain the baseline
  SerapeumOS authorization engine.
- **Reason:** Replacing AuthZ foundation risks breaking existing permission semantics.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-064 — AuthZ, Capability, and Action Assurance are separate

- **Status:** LOCKED
- **Decision:** AuthZ determines permission; Capabilities delegate bounded runtime authority;
  Action Assurance governs exact consequential action execution.
- **Reason:** Conflating these layers removes defense-in-depth and audit clarity.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-065 — Default deny

- **Status:** LOCKED
- **Decision:** Missing, invalid, stale, or ambiguous authority fails closed.
- **Reason:** Fail-open authority creates silent privilege escalation vectors.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-066 — Capabilities are bounded and attenuating

- **Status:** LOCKED
- **Decision:** Capabilities bind Principal, Company, resource, action, context, constraints,
  lifetime, risk, and approvals where required and cannot broaden delegated authority.
- **Reason:** Unbounded capabilities effectively grant unrestricted authority.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-067 — Authorization is not approval

- **Status:** LOCKED
- **Decision:** An AuthZ allow decision does not itself satisfy high-impact action approval
  or correctness checks.
- **Reason:** Permission ≠ consequence; high-impact actions require layered review.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-068 — Action Assurance is the consequential-action lifecycle

- **Status:** LOCKED
- **Decision:** Intent normalization, risk classification, authorization, precondition validation,
  approval, execution authority, trusted execution, postcondition verification, receipt, and
  recovery form the canonical assurance sequence.
- **Reason:** Skipping lifecycle stages creates unverified execution gaps.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-069 — Privileged effects execute through trusted brokers/services

- **Status:** LOCKED
- **Decision:** Agents do not receive raw host, database, or long-lived credential authority
  merely because an action is approved.
- **Reason:** Direct privileged access bypasses Audit, Action Assurance, and recovery controls.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-070 — Constitutional invariants cannot be bypassed by ordinary approval

- **Status:** LOCKED
- **Decision:** Owner approval may authorize governed high-impact actions but cannot silently
  disable SerapeumOS constitutional security boundaries.
- **Reason:** Ordinary approval must not erode hard safety invariants.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-071 — Models are replaceable intelligence

- **Status:** LOCKED
- **Decision:** Agent identity, authority, Mission, and Task identity are independent from
  model/provider/runtime selection.
- **Reason:** Model coupling to identity creates lock-in and breaks the Agent≠Model contract.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-072 — AIGateway remains the inference boundary

- **Status:** LOCKED
- **Decision:** SerapeumOS reuses Ankole AIGateway for provider abstraction, model resolution,
  binding, request mediation, and response normalization.
- **Reason:** A centralized inference boundary enables routing, fallback, and regression control.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-073 — Final production inference is local

- **Status:** LOCKED
- **Decision:** Qualified final SerapeumOS operation uses local inference runtimes and local
  model artifacts; hosted inference is not a required production dependency.
- **Reason:** Hosted inference as a requirement violates Gold Rule #1 local-first doctrine.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-074 — NaraRouter is development/validation only

- **Status:** LOCKED
- **Decision:** NaraRouter may temporarily serve inference during build/validation but cannot
  enter final architecture as a required service.
- **Reason:** Temporary inference tooling must not become a permanent dependency.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-075 — Logical profiles select qualified bindings

- **Status:** LOCKED
- **Decision:** Agents/tasks request logical model profiles; trusted resolution maps them to
  concrete qualified local model/runtime bindings.
- **Reason:** Abstract profile selection decouples Agent intent from concrete binding choices.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-076 — Durable work freezes its model binding

- **Status:** LOCKED
- **Decision:** A durable execution stores/fixes the concrete model binding at admission.
  Retries do not silently change models.
- **Reason:** Model churn mid-execution corrupts reproducibility and audit.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-077 — Fallback is explicit and evidenced

- **Status:** LOCKED
- **Decision:** Fallback may occur only through configured compatible paths and must be observable;
  arbitrary provider/model fallback is prohibited.
- **Reason:** Silent fallback creates unpredictable behavior and audit gaps.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-078 — Model qualification is profile-specific

- **Status:** LOCKED
- **Decision:** A discovered model/runtime binding is not production-usable until qualified for
  its intended capability/profile.
- **Reason:** General qualification does not imply suitability for all use profiles.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-079 — Inference changes require regression gates

- **Status:** LOCKED
- **Decision:** Material model, quantization, runtime, protocol, reasoning, or tool-call changes
  require regression evaluation before promotion.
- **Reason:** Unvalidated inference changes can silently degrade output quality or safety.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-080 — Model tools remain governed

- **Status:** LOCKED
- **Decision:** Model-generated or provider-native tool actions cannot bypass AuthZ, Capability,
  Action Assurance, or MA-08 tool governance.
- **Reason:** Tool actions derived from model output still require the same governance as direct agent actions.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-081 — Tool availability does not grant authority

- **Status:** LOCKED
- **Decision:** A registered/enabled tool still requires Task policy, AuthZ, Capability validation,
  and Action Assurance where applicable.
- **Reason:** Registration is not permission; availability without governance enables unauthorized execution.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-082 — Extension lifecycle is explicit

- **Status:** LOCKED
- **Decision:** Available, installed, enabled, qualified, and invoked are separate states.
- **Reason:** Collapsing lifecycle states creates ambiguity about trust and authorization boundaries.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-083 — Skills are untrusted capability guidance

- **Status:** LOCKED
- **Decision:** Skills may provide instructions/resources/dependencies but do not grant authority
  and run within Agent security boundaries.
- **Reason:** Skills are content, not permission; treating them as authoritative breaks isolation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-084 — Plugins extend trusted subsystems only through contracts

- **Status:** LOCKED
- **Decision:** Plugins may register adapters/services but cannot replace Principal, AuthZ, Action
  Assurance, Company truth, or audit authority.
- **Reason:** Plugin authority must remain bounded by contracted interfaces.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-085 — MCP is not an authority boundary

- **Status:** LOCKED
- **Decision:** MCP exposes operations; SerapeumOS still governs every operation. Stdio MCP remains
  inside the hostile Agent boundary.
- **Reason:** Protocol exposure does not confer authorization; every MCP call仍需 AuthZ/AA.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-086 — Browser/computer use remains hostile execution

- **Status:** LOCKED
- **Decision:** Browser and UI automation cannot receive ambient host access and remain constrained
  by isolation, SSRF, network, and Action Assurance policy.
- **Reason:** Browser automation has historically been a common privilege escalation vector.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-087 — External research is optional governed egress

- **Status:** LOCKED
- **Decision:** Internet research is Task-scoped optional egress, not a cloud dependency; retrieved
  material enters MA-05 as sourced evidence.
- **Reason:** Research access must remain scoped, governed, and evidentiary—not ambient.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-088 — Network remains deny-by-default per capability

- **Status:** LOCKED
- **Decision:** Tool/Skill/plugin enablement does not itself create network authority.
- **Reason:** Feature enablement ≠ network permission; each requires explicit AuthZ.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-089 — Extension secrets are broker-mediated

- **Status:** LOCKED
- **Decision:** Credentials are not embedded in Skill content, prompts, schemas, or Agent memory.
- **Reason:** Embedded secrets leak through retrieval, logging, and model context.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-090 — Required production extensions obey OSS/local doctrine

- **Status:** LOCKED
- **Decision:** No proprietary external service may become a required SerapeumOS production capability.
- **Reason:** Mandatory proprietary extensions violate Gold Rule #1 and platform neutrality.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-091 — PostgreSQL remains authoritative structured state

- **Status:** LOCKED
- **Decision:** SerapeumOS reuses Ankole PostgreSQL for Company, Agent, Task, AuthZ, epistemic and
  other structured durable control-plane truth.
- **Reason:** A single authoritative structured store prevents divergent state and ensures consistency.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-092 — General durable payloads use a managed Artifact Store

- **Status:** LOCKED
- **Decision:** PostgreSQL holds Artifact metadata/references; general document/file payloads use a
  separate local managed Artifact Store.
- **Reason:** Separating metadata from payload storage enables independent scaling and integrity.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-093 — Artifacts are immutable

- **Status:** LOCKED
- **Decision:** Changing payload bytes creates a new Artifact/version. SHA-256 is the baseline
  content-integrity digest.
- **Reason:** Mutability destroys provenance and makes reproducibility impossible.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-094 — Database reference commit is artifact authority

- **Status:** LOCKED
- **Decision:** Artifact payloads are staged/verified before database references become live;
  orphan payload is preferable to a live DB reference to missing bytes.
- **Reason:** Live references to missing content create inconsistent state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-095 — `/agents` is durable non-authoritative continuity

- **Status:** LOCKED
- **Decision:** Agent Home, session/job workspaces and `user-files` are persistent Agent working
  state but cannot override Company/Task/Brain authoritative state.
- **Reason:** Workspace persistence ≠ organizational authority; they serve different truth classes.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-096 — Agent Home domain files are one-way projections

- **Status:** LOCKED
- **Decision:** `SOUL.md`, `MISSION.md`, and `DESIGN.md` are rebuilt from trusted PostgreSQL state;
  filesystem edits alone do not mutate authority.
- **Reason:** Filesystem-only edits would bypass audit and Provenance controls.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-097 — User files are imported as managed snapshots by default

- **Status:** LOCKED
- **Decision:** Owner resources are copied into controlled immutable Artifact state before Agent
  processing; live host mounts are exceptional and brokered.
- **Reason:** Direct host mounts expose Agent execution to uncontrolled host state changes.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-098 — User-file writes are Publication

- **Status:** LOCKED
- **Decision:** Publishing to Owner resources requires immutable source, exact target, AuthZ/Action
  Assurance, stale-target recheck, trusted write, verification and receipt.
- **Reason:** Unverified publication can silently overwrite Owner data.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-099 — Publication conflicts fail closed

- **Status:** LOCKED
- **Decision:** A materially changed target invalidates stale publication assumptions; SerapeumOS
  does not silently overwrite under stale approval.
- **Reason:** Stale-target overwrites erase concurrent Owner edits and break audit.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-100 — General storage remains local and platform-neutral

- **Status:** LOCKED
- **Decision:** Final operation requires no cloud DB/object store and domain semantics do not
  depend on host-specific path/filesystem identity.
- **Reason:** Cloud storage dependency violates Gold Rule #1 local-first doctrine.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-101 — Principal identity is separate from credentials

- **Status:** LOCKED
- **Decision:** Human, Agent, and System Principal identities remain stable when passwords, tokens,
  runtime credentials, or external identity bindings change.
- **Reason:** Identity churn on credential rotation breaks durable authorization and audit.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-102 — Durable Principal classes remain human / agent / system

- **Status:** LOCKED
- **Decision:** Transient Workers, appliances, models and tools use runtime identities rather than
  new durable Principal types.
- **Reason:** Proliferating durable Principal types creates unmanageable authority sprawl.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-103 — SerapeumOS uses a host-protected installation root secret

- **Status:** LOCKED
- **Decision:** Long-lived reversible secrets are protected through purpose/context-derived keys
  rooted in local host-protected key material.
- **Reason:** Hardcoded or cloud-stored root secrets create single points of failure and leakage.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-104 — Secret plaintext is never ordinary Agent state

- **Status:** LOCKED
- **Decision:** Long-lived secrets are excluded from prompts, memory, Skills, workspaces, logs,
  receipts and general artifacts; Agents use opaque references and trusted mediation.
- **Reason:** Plaintext secrets in any persistent store risk exfiltration through retrieval or leaks.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-105 — Secret access is broker-mediated

- **Status:** LOCKED
- **Decision:** Trusted services perform credentialed actions where possible; direct secret injection
  is minimized, scoped, temporary and non-persistent.
- **Reason:** Direct secret exposure to Agents enables accidental logging and context leakage.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-106 — Worker/appliance credentials are per runtime incarnation

- **Status:** LOCKED
- **Decision:** Final production runtime authentication uses bounded revocable credentials tied to
  a specific Worker/appliance incarnation and assignment.
- **Reason:** Reusing credentials across incarnations enables privilege persistence after replacement.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-107 — Global shared WorkerAuthKey is not final production architecture

- **Status:** LOCKED
- **Decision:** The inherited Ankole global Worker authentication key may support compatibility/
  development but is superseded by the MA-10 per-runtime credential contract for production.
- **Reason:** Global keys violate per-incarnation isolation and complicate revocation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-108 — Credentials support rotation and revocation

- **Status:** LOCKED
- **Decision:** Credential replacement does not change Principal identity, and revocation is
  independent of Agent cooperation.
- **Reason:** Dependency on Agent cooperation for revocation enables persistence after compromise.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-109 — Private signing keys remain trusted-only

- **Status:** LOCKED
- **Decision:** Agents may request governed signing operations but never receive private signing
  keys directly.
- **Reason:** Direct private key exposure enables unauthorized signing and provenance forgery.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-110 — Core local operation requires no external credentials

- **Status:** LOCKED
- **Decision:** External service credentials are optional integration/development state and cannot
  become required for final SerapeumOS core operation.
- **Reason:** Mandatory external credentials violate Gold Rule #1 and create platform lock-in.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-111 — Trusted Resource Governor owns allocation

- **Status:** LOCKED
- **Decision:** Resource admission, reservation, enforcement coordination, pressure response, and
  reclamation are trusted control functions outside Agent authority.
- **Reason:** Self-governed resources enable resource exhaustion attacks and starvation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-112 — Resource budgets are hierarchical

- **Status:** LOCKED
- **Decision:** Capacity is governed through Host Safety Envelope → Company → Agent → Task/Execution
  ceilings and reservations.
- **Reason:** Flat budgeting prevents isolation guarantees and safety envelope enforcement.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-113 — Trusted host safety reserve is mandatory

- **Status:** LOCKED
- **Decision:** Control Plane, database, audit, Owner control, kill, and recovery capacity are
  protected before maximizing untrusted throughput.
- **Reason:** Starving the trusted layer during load causes systemic collapse.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-114 — Expensive work requires resource admission

- **Status:** LOCKED
- **Decision:** Agent Appliances, model loads, Agent/Task execution, browsers/tools, and large
  artifact operations are admitted against current local capacity.
- **Reason:** Unadmitted heavy work can starve trusted services and destabilize the system.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-115 — Resource lease is not authorization

- **Status:** LOCKED
- **Decision:** A resource lease grants capacity only; MA-06 Capability/AuthZ determines authority.
- **Reason:** Capacity ≠ permission; conflating them enables resource-based privilege escalation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-116 — Priority, fairness and preemption are explicit

- **Status:** LOCKED
- **Decision:** Safety/recovery and Owner control outrank ordinary/background work; preemption
  affects execution, not Task authority.
- **Reason:** Equal priority for all work risks safety-critical tasks being starved.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-117 — GPU/VRAM remain inference-runtime resources

- **Status:** LOCKED
- **Decision:** The Agent Appliance receives no direct GPU authority by default; model residency
  is governed through qualified inference/resource policy.
- **Reason:** Direct GPU access bypasses resource governance and safety envelopes.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-118 — Resource pressure cannot weaken integrity

- **Status:** LOCKED
- **Decision:** Scarcity may delay/refuse work but cannot weaken isolation, bypass security, use
  unqualified fallbacks, or silently delete protected authoritative state.
- **Reason:** Pressure-induced security degradation creates exploitable moments of weakness.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-119 — Resource accounting and reclamation are trusted

- **Status:** LOCKED
- **Decision:** Usage/reservations are attributable and stale/dead execution cannot hold capacity
  indefinitely.
- **Reason:** Unreclaimed resources cause gradual degradation and denial-of-service.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-120 — No self-expansion or automatic cloud bursting

- **Status:** LOCKED
- **Decision:** Agents cannot raise their own authoritative resource ceilings, and local shortages
  never silently move final SerapeumOS work to cloud infrastructure.
- **Reason:** Self-expansion and silent cloud burst break budget enforcement and Gold Rule #1.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-121 — Committed trusted state outranks runtime state

- **Status:** LOCKED
- **Decision:** Process/Worker/appliance/model context is expendable; PostgreSQL and committed
  Artifacts/receipts remain recovery authority.
- **Reason:** Runtime state is ephemeral; only committed state survives crashes and resets.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-122 — Task and execution attempt are separate

- **Status:** LOCKED
- **Decision:** Retries/restarts preserve one Task identity while retaining distinct attempt
  history and accountability.
- **Reason:** Collapsing attempt history loses evidence needed for reconciliation and audit.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-123 — Wakeups are not authority

- **Status:** LOCKED
- **Decision:** Durable state commits before runtime notification; lost wakeups must be
  reconstructable from committed rows.
- **Reason:** Notification-dependant work creates loss windows on crash/restart.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-124 — Runtime commits are fenced

- **Status:** LOCKED
- **Decision:** Stale Worker/appliance/activation/attempt results cannot mutate current execution
  truth after ownership changes.
- **Reason:** Stale commits from replaced runtimes corrupt current authoritative state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-125 — Resume requires a valid durable checkpoint

- **Status:** LOCKED
- **Decision:** Loss of Worker/model-local context without a sufficient checkpoint causes restart/
  new attempt, not false continuation.
- **Reason:** False continuation from insufficient state produces incorrect or inconsistent results.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-126 — Retries require idempotency or reconciliation

- **Status:** LOCKED
- **Decision:** Consequential operations must be naturally idempotent, keyed/deduplicated, previously-
  completed-aware, or reconciled before repeat.
- **Reason:** Non-idempotent retries create duplicate side effects and state corruption.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-127 — External exactly-once is not assumed

- **Status:** LOCKED
- **Decision:** SerapeumOS uses durable intent, provider idempotency where available, reconciliation,
  and explicit unknown outcomes rather than universal exactly-once claims.
- **Reason:** Exactly-once is often impossible over unreliable networks; fence-and-reconcile is safer.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-128 — Outbox is the preferred asynchronous side-effect pattern

- **Status:** LOCKED
- **Decision:** Durable external-action intent commits before dispatch; delivery/reconciliation then
  produces terminal evidence.
- **Reason:** Commit-before-dispatch ensures no intent is lost even if dispatch fails.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-129 — Cancellation is authoritative work state, not process death

- **Status:** LOCKED
- **Decision:** Cancellation propagates through capability revocation, runtime stop, late-result
  fencing, and side-effect reconciliation while preserving history.
- **Reason:** Process death without cancellation propagation leaves orphaned work and ambiguous state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-130 — Crash recovery is trusted and evidence-driven

- **Status:** LOCKED
- **Decision:** Recovery reconstructs from durable state, reconciles expired/stale runtime ownership
  and ambiguous actions, and fails closed where evidence is insufficient.
- **Reason:** Speculative recovery from incomplete evidence risks state corruption.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-131 — Backup Sets cover all authoritative recovery classes

- **Status:** LOCKED
- **Decision:** A valid recovery point includes PostgreSQL authoritative state, required managed
  Artifacts, protected Agent Workspace continuity, required reconstruction/recovery metadata,
  and protected audit/receipt state where separate.
- **Reason:** Partial backups create inconsistent recovery points that cannot restore full state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-132 — Backup validity is manifest- and integrity-based

- **Status:** LOCKED
- **Decision:** A backup is a verifiable immutable Backup Set, not merely a filesystem copy.
- **Reason:** Unverified copies may be corrupt, incomplete, or tampered without detection.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-133 — PostgreSQL and Artifact recovery must be self-consistent

- **Status:** LOCKED
- **Decision:** A recovery point cannot activate with live authoritative references to missing or
  wrong Artifact content.
- **Reason:** Inconsistent recovery creates cascading failures when references resolve to missing data.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-134 — Workspace recovery never overrides authoritative truth

- **Status:** LOCKED
- **Decision:** `/agents` is backed up for continuity but restored PostgreSQL/domain authority wins
  and runtime projections may be regenerated.
- **Reason:** Workspace restoration must not override authoritative Company state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-135 — Restore occurs in isolation before promotion

- **Status:** LOCKED
- **Decision:** Backup restore defaults to a quarantined/staging recovery environment and becomes
  ACTIVE only after validation and trusted promotion.
- **Reason:** Direct-in-place restore risks propagating corrupted state into production.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-136 — Restored runtime authority is invalidated

- **Status:** LOCKED
- **Decision:** Worker credentials, runtime sessions, leases, assignments, reservations, and stale
  runtime authority are not resurrected from backups.
- **Reason:** Revived runtime authority bypasses current AuthZ and Capability state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-137 — Recovery keys are separate from protected Backup Sets

- **Status:** LOCKED
- **Decision:** The root/recovery secret is not stored plaintext beside the encrypted data it
  protects; backup data and recovery-key material use separate trust channels.
- **Reason:** Co-located keys and ciphertext defeats the purpose of encryption at rest.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-138 — Quarantine is first-class recovery state

- **Status:** LOCKED
- **Decision:** Suspect Artifacts, Workspaces, Backup Sets, recovery copies, and executable content
  remain preserved but outside normal trusted operation until validated.
- **Reason:** Discarding suspect material destroys evidence needed for forensics and recovery.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-139 — Disaster recovery is local, portable, and cloud-independent

- **Status:** LOCKED
- **Decision:** SerapeumOS supports offline/local recovery and replacement qualified hosts without
  requiring hosted backup infrastructure.
- **Reason:** Cloud-dependent DR violates Gold Rule #1 and creates single-point-of-failure.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-140 — Verified backup and test restore are required for DR confidence

- **Status:** LOCKED
- **Decision:** Backup-file existence alone is insufficient; integrity verification and isolated
  restore testing are required for release-quality disaster recovery.
- **Reason:** Untested backups are unproven and may fail at the moment of need.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-141 — Observability, audit, receipts, and diagnostic content are separate classes

- **Status:** LOCKED
- **Decision:** Operational telemetry is not authoritative audit or Action Assurance evidence.
- **Reason:** Conflating telemetry with audit enables false confidence in unverifiable claims.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-142 — High-impact accountability is committed by trusted services

- **Status:** LOCKED
- **Decision:** Agents, Workers, models, and tools may emit evidence but cannot directly create
  trusted audit history.
- **Reason:** Untrusted sources creating audit entries enables provenance forgery.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-143 — Consequential actions require durable Action Receipts

- **Status:** LOCKED
- **Decision:** Receipt state binds request, authority, attempt, outcome, verification, and evidence;
  model/Worker claims alone cannot prove completion.
- **Reason:** Claims without receipt binding enable false completion reports.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-144 — Mandatory audit is append-oriented and tamper-protected

- **Status:** LOCKED
- **Decision:** Material governance/security history is not silently rewritten; corrections and
  privacy redactions are themselves governed events.
- **Reason:** Rewritable audit destroys evidentiary value and enables cover-ups.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-145 — Telemetry is metadata-first and secret-free

- **Status:** LOCKED
- **Decision:** Sensitive content is minimized before emission and plaintext credentials/recovery
  secrets are prohibited from telemetry/audit stores.
- **Reason:** Secret-bearing telemetry creates leakage vectors through log aggregation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-146 — SerapeumOS has no mandatory external telemetry

- **Status:** LOCKED
- **Decision:** Local observability is sufficient for final operation; OTLP/SaaS/product analytics
  export is optional, explicit, and replaceable.
- **Reason:** Mandatory external telemetry violates Gold Rule #1 local-first doctrine.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-147 — Detailed diagnostic content is optional and bounded

- **Status:** LOCKED
- **Decision:** Prompt/output/body tracing is not required for correctness and, when enabled, is
  explicit, redacted, scoped, and retention-limited.
- **Reason:** Unbounded diagnostics leak sensitive content and create unnecessary storage burden.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-148 — Privacy retention does not falsify accountable history

- **Status:** LOCKED
- **Decision:** Data erasure may remove/detach sensitive payload while preserving a minimal
  policy-permitted audit skeleton and an auditable erasure/redaction event.
- **Reason:** Complete erasure without audit trail prevents distinguishing legitimate privacy from evidence destruction.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-149 — Required audit/receipts cannot be sampled away

- **Status:** LOCKED
- **Decision:** Sampling/drop policies apply only to non-authoritative observability; inability to
  persist required audit may block the affected consequential action.
- **Reason:** Dropping required audit eliminates accountability for the blocked action.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-150 — Telemetry never becomes Agent memory automatically

- **Status:** LOCKED
- **Decision:** Any movement from observability/audit into durable knowledge or System Evolution
  learning requires MA-05/MA-15 governance.
- **Reason:** Automatic promotion of telemetry to memory bypasses provenance and evolution governance.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-151 — System Evolution Truth is a separate durable domain

- **Status:** LOCKED
- **Decision:** Candidates, evaluations, approvals, promotions, rollbacks, and evolution history do
  not overwrite Organizational, Execution, or Epistemic Truth.
- **Reason:** Mixing evolution history with operational truth corrupts accountability and provenance.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-152 — Evolution uses candidate → evaluation → governed promotion

- **Status:** LOCKED
- **Decision:** Learning/model output/generated code may create candidates but cannot directly
  modify trusted production behavior.
- **Reason:** Direct self-modification bypasses evaluation and review gates.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-153 — Evolution changes are classified SE-0 through SE-4

- **Status:** LOCKED
- **Decision:** Only explicitly pre-authorized bounded SE-1 and selected SE-2 changes may ever
  qualify for autonomous production promotion; SE-3 and SE-4 cannot.
- **Reason:** Higher-severity changes require human/PM oversight to prevent catastrophic self-modification.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-154 — Architecture and constitutional safeguards are protected from autonomous evolution

- **Status:** LOCKED
- **Decision:** Owner authority, MA locks, TCB, AuthZ, Action Assurance, secrets, audit, Company
  isolation, and release/supply-chain governance require higher-authority change paths.
- **Reason:** Self-modifying safeguards enables gradual erosion of all security controls.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-155 — Evolution cannot amend its own safeguards

- **Status:** LOCKED
- **Decision:** Promotion gates, evaluation policy, poisoning screens, audit, authority, resource
  ceilings, and protected change classes cannot be autonomously weakened by the system they govern.
- **Reason:** Self-weakening eliminates the guarantee that evolution is safe.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-156 — Evolution evidence requires provenance and contamination status

- **Status:** LOCKED
- **Decision:** Training/evaluation examples, lessons, telemetry-derived signals, and candidate
  evidence retain source lineage and contamination/holdout status.
- **Reason:** Untagged evidence may contain poisoned or contaminated data that biases evolution.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-157 — Material candidates are tested against frozen baselines in isolation

- **Status:** LOCKED
- **Decision:** Live authoritative state is not the default experiment environment; candidate/
  baseline/dataset/model/tool versions are fixed and recorded.
- **Reason:** Testing against mutable live state produces non-reproducible and unreliable results.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-158 — Hard safety invariants cannot be traded for aggregate quality

- **Status:** LOCKED
- **Decision:** Security, privacy, authority, isolation, and corruption failures are release
  blockers regardless of average benchmark improvement.
- **Reason:** Aggregate quality gains do not justify sacrificing hard safety guarantees.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-159 — Independent review separates candidate creation from material approval

- **Status:** LOCKED
- **Decision:** Self-evaluation is supplementary evidence; material SE-2 and all SE-3/SE-4 changes
  require the independent/higher-authority review path defined by policy.
- **Reason:** Self-approval of evolution changes creates conflict of interest and bias.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-160 — Poisoned or suspicious evolution inputs are quarantined

- **Status:** LOCKED
- **Decision:** External content, logs, model/tool output, generated code, Skills/plugins, and
  contaminated benchmarks remain untrusted until screened/qualified.
- **Reason:** Unscreened inputs can inject poisoned strategies that degrade system behavior.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-161 — Promotion changes new work by default

- **Status:** LOCKED
- **Decision:** Existing frozen durable executions are not silently mutated by newly promoted
  models, Skills, strategies, or configuration.
- **Reason:** Silent mutation of existing work breaks reproducibility and audit trails.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-162 — Promotion is reversible and monitored

- **Status:** LOCKED
- **Decision:** Material promoted behavior has rollback/supersession policy and post-promotion
  monitoring; failed candidates/history are preserved.
- **Reason:** Irreversible promotion prevents recovery from bad evolution decisions.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-163 — Generated trusted-product code never self-deploys

- **Status:** LOCKED
- **Decision:** Generated code follows repository review, MA-19 supply-chain/build controls, MA-20
  qualification, and MA-18 controlled update/promotion.
- **Reason:** Self-deployment of generated code bypasses all governance gates.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-164 — Company learning is isolated by default

- **Status:** LOCKED
- **Decision:** Private Company data/lessons/telemetry do not become cross-Company/global evolution
  data without separately governed policy.
- **Reason:** Uncontrolled cross-Company learning leaks organizational isolation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-165 — Final System Evolution is local and cloud-independent

- **Status:** LOCKED
- **Decision:** No external training, hosted evaluator, NaraRouter, or cloud improvement service is
  required for final SerapeumOS evolution.
- **Reason:** Cloud-dependent evolution violates Gold Rule #1 and creates external chokepoints.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-166 — Owner Workspace is the primary product UX

- **Status:** LOCKED
- **Decision:** SerapeumOS presents the Company, work, Agents, approvals, activity, and security as
  an operational product; inherited technical Console surfaces remain secondary/admin substrate.
- **Reason:** The product UX must serve the Owner's operational needs, not developer debugging needs.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-167 — UX is explanatory, not authoritative

- **Status:** LOCKED
- **Decision:** Authentication, AuthZ, capabilities, Action Assurance, secrets, and durable state
  remain enforced by trusted backend services.
- **Reason:** UI-level controls are presentation only; backend enforcement is what matters.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-168 — Normal permissions use human-readable policy semantics

- **Status:** LOCKED
- **Decision:** Routine delegation is expressed as Who / What / Scope / Conditions / Duration; raw
  resource/action/policy expressions are advanced administration.
- **Reason:** Raw policy expressions are inaccessible to non-technical Owners.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-169 — Approval and permission are separate UX flows

- **Status:** LOCKED
- **Decision:** A one-time action approval cannot silently create permanent authority; persistent
  delegation requires a separate permission flow.
- **Reason:** Conflating approval with permission enables scope creep through repeated approvals.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-170 — Consequential approvals bind exact action and target state

- **Status:** LOCKED
- **Decision:** Material changes after approval invalidate reuse and require governed re-evaluation.
- **Reason:** Approving a stale plan that has diverged from reality risks executing unauthorized changes.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-171 — Stored secret plaintext is not redisplayed in normal product UX

- **Status:** LOCKED
- **Decision:** Secret management exposes safe metadata and replace/revoke/delete flows while
  preserving MA-10 non-disclosure.
- **Reason:** Redisplaying secrets in UX creates accidental exposure through screenshots and logs.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-172 — Security status must expose unknown and stale states

- **Status:** LOCKED
- **Decision:** No-error and unavailable evidence are not represented as healthy.
- **Reason:** Silent health reporting hides failures that need attention.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-173 — Owner has trusted emergency controls independent of Agents

- **Status:** LOCKED
- **Decision:** Global pause, Agent pause/suspension, eligible execution stop, and authority
  revocation do not depend on Agent cooperation.
- **Reason:** Cooperative-only emergency controls fail when Agents are compromised or unresponsive.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-174 — Uncertain external outcomes are first-class UX states

- **Status:** LOCKED
- **Decision:** UNCERTAIN is never collapsed into success/failure until reconciliation proves the result.
- **Reason:** Collapsing uncertainty hides incomplete information from the Owner.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-175 — Consequential actions produce durable receipts

- **Status:** LOCKED
- **Decision:** Transient frontend notifications are insufficient evidence of trusted side effects.
- **Reason:** Notifications can be dismissed or lost; receipts provide permanent proof.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-176 — External data-boundary crossings are visible

- **Status:** LOCKED
- **Decision:** Destination, purpose, and material data leaving local control are surfaced where relevant.
- **Reason:** Invisible egress prevents Owner awareness of data flow across boundaries.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-177 — Chat cannot be the sole governance surface

- **Status:** LOCKED
- **Decision:** Durable permissions, consequential approvals, secret management, ownership, and
  governance changes use structured authoritative workflows.
- **Reason:** Chat-based governance is ephemeral, unstructured, and unverifiable.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-178 — Security UX uses progressive disclosure

- **Status:** LOCKED
- **Decision:** Default views remain minimal and human-readable while technical evidence/details
  remain inspectable.
- **Reason:** Overwhelming default views hide critical information; under-detailing prevents verification.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-179 — Product security semantics are accessible and localization-safe

- **Status:** LOCKED
- **Decision:** Critical states and decisions cannot rely on color alone and must preserve meaning
  across supported localization/accessibility modes.
- **Reason:** Color-only encoding excludes colorblind users and breaks across locales.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-180 — Host capability, not OS name, defines compatibility

- **Status:** LOCKED
- **Decision:** SerapeumOS qualifies a versioned Host Compatibility Profile. Unknown or stale
  security-critical capabilities fail closed.
- **Reason:** OS-name-based assumptions miss capability gaps that vary within families.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-181 — Windows 11 x86-64 is the first production qualification target

- **Status:** LOCKED
- **Decision:** Windows is the first release host target, while SerapeumOS core remains platform-neutral
  and Linux remains architecture-supported through the same contract.
- **Reason:** First-target status does not imply qualified; it means first in line for MA-20 proof.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-182 — Active managed state requires qualified local fixed storage

- **Status:** LOCKED
- **Decision:** R0/R1/R2 do not use network shares, cloud-sync folders, removable media, FAT or
  exFAT as the normal production baseline. NTFS is the first Windows baseline; ext4/XFS are
  initial Linux candidates.
- **Reason:** Network/removable/media-storage lacks the durability and atomicity guarantees required.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-183 — Core path authority is structured and root-relative

- **Status:** LOCKED
- **Decision:** Raw absolute host paths are not authority. Trusted adapters resolve authorized roots
  plus validated relative path segments and target state.
- **Reason:** Absolute path acceptance enables traversal attacks and unauthorized access.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-184 — Host path ambiguity fails closed

- **Status:** LOCKED
- **Decision:** Traversal, case/Unicode collision, DOS/device namespace ambiguity, symlink/reparse/
  mount escape and other host-specific path reinterpretation are rejected or safely broker-resolved
  before use.
- **Reason:** Unresolved path ambiguity enables boundary escape through filesystem tricks.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-185 — Host file identity is operation-scoped evidence, not durable domain identity

- **Status:** LOCKED
- **Decision:** Handle-derived file IDs/inodes/volume metadata strengthen stale-target validation
  but never become Company/Artifact identity or portable backup identity.
- **Reason:** Host file IDs are ephemeral and non-portable across hosts and backups.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-186 — Consequential publication uses staged same-volume commit semantics

- **Status:** LOCKED
- **Decision:** Strong local publication stages and verifies exact bytes, revalidates the target,
  performs qualified same-volume atomic create/replace, applies durability steps, reopens/verifies,
  then receipts the result.
- **Reason:** Single-step publish risks partial writes, stale targets, and unverifiable outcomes.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-187 — Atomic visibility, durability and verification are separate guarantees

- **Status:** LOCKED
- **Decision:** SerapeumOS never equates a successful write/rename call with a fully verified
  durable publication.
- **Reason:** Write success ≠ verified durability; separate checks catch cache/write-hole gaps.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-188 — Agent workspace persistence uses per-Agent virtual block storage

- **Status:** LOCKED
- **Decision:** `/agents` is backed by a dedicated Agent-bound virtual block volume with Linux-native
  guest filesystem semantics; arbitrary shared host folders are not the production baseline.
- **Reason:** Shared host folders leak between Agents and lack Linux filesystem semantics.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-189 — File locks and filesystem events are advisory/supporting evidence

- **Status:** LOCKED
- **Decision:** Locks/watchers/timestamps do not replace AuthZ, Action Assurance, object identity
  revalidation or content verification.
- **Reason:** Locks can be broken, watchers missed, and timestamps forged; they are supplemental only.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-190 — Root-secret and hard resource controls are host qualification requirements

- **Status:** LOCKED
- **Decision:** Protected root-secret storage and externally enforced resource limits are required
  capabilities; missing controls disable the affected production mode rather than causing plaintext/
  unlimited fallback.
- **Reason:** Graceful degradation into insecurity is worse than failing closed.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-191 — Host lifecycle changes require reconciliation

- **Status:** LOCKED
- **Decision:** Sleep, resume, reboot and material host changes can stale runtime/capability
  assumptions and trigger trusted revalidation before new untrusted work.
- **Reason:** Stale assumptions after host changes enable unauthorized execution on resumed state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-192 — Compatibility fallback may reduce capability, never safeguards

- **Status:** LOCKED
- **Decision:** If a qualified backend/capability is unavailable, SerapeumOS may enter a clearly
  degraded trusted/recovery mode but cannot substitute a weaker boundary while claiming equivalent
  production security.
- **Reason:** Misleading security claims during fallback erode trust and enable exploitation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-193 — MA-20 owns executable platform qualification

- **Status:** LOCKED
- **Decision:** MA-17 defines the host contract; MA-20 proves concrete OS/build/filesystem/VMM
  profiles. Starting successfully is not qualification.
- **Reason:** Boot success proves availability, not security, reliability, or correctness.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-194 — Physical at-rest protection is an explicit host capability

- **Status:** LOCKED
- **Decision:** Active managed storage records physical encrypted-at-rest status separately from
  application secret encryption. Where policy requires it, unproven/unavailable volume or block
  protection blocks the affected production storage profile.
- **Reason:** Application-level encryption without physical protection leaves data exposed at disk level.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-195 — Installation identity survives software generation change

- **Status:** LOCKED
- **Decision:** `installation_uid` and durable Company identity are independent of product binaries,
  host paths, service IDs, and normal updates.
- **Reason:** Identity tied to binaries breaks continuity across updates and reinstallations.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-196 — Lifecycle mutation belongs to a trusted Maintenance Plane

- **Status:** LOCKED
- **Decision:** Install, update, migration, storage relocation, repair, rollback, uninstall, and
  purge are trusted bounded maintenance operations; Agents cannot self-authorize them.
- **Reason:** Agent-authorized lifecycle changes bypass security floors and qualification.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-197 — Production updates use immutable Release Generations

- **Status:** LOCKED
- **Decision:** New trusted code is staged as a complete verified generation and activated through
  a trusted selector; normal update does not patch the running executable tree in place.
- **Reason:** In-place patching creates inconsistent state during transition and complicates rollback.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-198 — Compatibility is defined by a Persistent State Vector

- **Status:** LOCKED
- **Decision:** Product version alone is insufficient. Database/schema/artifact/workspace/config/
  key/protocol/host contract versions are tracked independently and transitions must be explicitly
  supported.
- **Reason:** Version-number-only compatibility misses component-level divergence.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-199 — Release transitions use an explicit compatibility graph

- **Status:** LOCKED
- **Decision:** Version skipping and migration are allowed only through declared qualified source→target
  edges; no compatibility is inferred from version numbers alone.
- **Reason:** Inferred compatibility skips required migration steps and qualification.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-200 — Consequential migration requires recovery readiness

- **Status:** LOCKED
- **Decision:** Before an update makes authoritative state backward-incompatible, an independent
  MA-13-compliant recovery anchor must exist and verify successfully.
- **Reason:** Migration without verified recovery anchor risks unrecoverable state corruption.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-201 — Migration progress is durably journaled

- **Status:** LOCKED
- **Decision:** Every material migration step has explicit source/target state, pre/postconditions,
  reversibility/resume semantics and verification evidence; crash recovery never blindly replays
  ambiguous mutations.
- **Reason:** Unjournaling migration creates unrecoverable partial-state corruption.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-202 — Database downgrade is not a generic rollback mechanism

- **Status:** LOCKED
- **Decision:** Older product code may run only against a state vector it is qualified to consume.
  Otherwise rollback uses a qualified inverse migration or MA-13 recovery-point restore.
- **Reason:** Running old code against new schema causes silent data loss and incorrect behavior.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-203 — Last Known Good is a qualified tuple

- **Status:** LOCKED
- **Decision:** LKG binds software generation, persistent state vector, host/qualification context
  and verification evidence; an old binary directory alone is not LKG.
- **Reason:** Binary-only LKG ignores state incompatibility and unqualified host context.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-204 — Rollback classes are explicit

- **Status:** LOCKED
- **Decision:** SerapeumOS distinguishes activation rollback, qualified reversible migration rollback,
  recovery-point rollback and forward-repair-only states; automatic rollback is limited to
  predeclared safe classes.
- **Reason:** Undifferentiated rollback obscures what can and cannot be reversed.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-205 — Security/downgrade floors cannot be silently lowered

- **Status:** LOCKED
- **Decision:** Authentic old packages may still be inadmissible because of security floor, state
  incompatibility, or host qualification. Ordinary Owner approval does not bypass that floor.
- **Reason:** Approval-based bypass of security floors erodes the protection they provide.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-206 — Offline update is first-class

- **Status:** LOCKED
- **Decision:** Release acquisition may be fully local/offline. Update transport is non-authoritative
  and no mandatory cloud updater/control plane is part of SerapeumOS.
- **Reason:** Cloud-dependent updates violate Gold Rule #1 and create single points of failure.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-207 — Update success requires post-activation qualification

- **Status:** LOCKED
- **Decision:** Staging or launching a new generation is not success. Trusted post-update validation
  must pass before commit/finalization and Agent admission.
- **Reason:** Launch without validation risks activating an unverified or broken generation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-208 — Repair does not rewrite Company truth

- **Status:** LOCKED
- **Decision:** Repair restores exact qualified installation assets and reconstructable host state;
  authoritative data corruption uses MA-13 recovery, and missing root-key material is never
  replaced over existing encrypted state.
- **Reason:** Repair overwriting Company truth corrupts authoritative state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-209 — Reinstall detects and protects existing installation state

- **Status:** LOCKED
- **Decision:** A non-empty SerapeumOS managed root is classified for adoption/repair/recovery before
  initialization; fresh install never silently overwrites an existing installation identity or
  durable state.
- **Reason:** Silent overwrite on reinstall destroys durable Company state.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-210 — Ordinary uninstall preserves durable Company state

- **Status:** LOCKED
- **Decision:** Removing the application and destroying Company-managed state are separate lifecycle
  actions. Destructive purge requires explicit high-risk governance.
- **Reason:** Automatic destructive uninstall on remove violates data preservation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-211 — Lifecycle maintenance does not own Owner R5 resources

- **Status:** LOCKED
- **Decision:** Install/update/rollback/uninstall/purge cannot treat external user files as
  installation-owned merely because SerapeumOS interacted with them.
- **Reason:** Claiming ownership of user files enables unauthorized modification or deletion.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-212 — Managed-root relocation is a verified migration

- **Status:** LOCKED
- **Decision:** Storage relocation qualifies destination, fences/quiesces writers, migrates and
  verifies R0/R1/R2, atomically cuts over trusted root selection, and retains rollback material
  until policy permits cleanup.
- **Reason:** Unverified relocation risks data loss and inconsistent state at the new location.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-213 — Runtime authority is refreshed across material updates

- **Status:** LOCKED
- **Decision:** Material generation/state transitions invalidate stale runtime sessions, leases,
  Worker/appliance credentials and affected approval/capability bindings; stable Agent organizational
  identity remains intact.
- **Reason:** Stale runtime authority after update enables unauthorized continued operation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-214 — MA-19 and MA-20 are mandatory lifecycle gates

- **Status:** LOCKED
- **Decision:** MA-18 controls lifecycle semantics, MA-19 proves software supply-chain acceptability,
  and MA-20 proves concrete executable host/release/migration behavior. No one gate substitutes
  for another.
- **Reason:** Skipping gates creates unproven attack surfaces and unqualified behavior.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-215 — Supply-chain trust is a reconstructable chain, not a source reputation check

- **Status:** LOCKED
- **Decision:** Trusted production software requires canonical source/material identity, controlled
  build provenance, release authorization, policy admission, and MA-20 qualification.
- **Reason:** Reputation-based trust cannot verify exact bytes or reproduce builds independently.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-216 — Production materials are immutable and independently digested

- **Status:** LOCKED
- **Decision:** Mutable branches/tags/version ranges/`latest` are non-authoritative; exact source
  and dependency snapshots are bound to strong content digests. Legacy Git commit IDs remain
  lineage locators only.
- **Reason:** Floating references enable supply-chain poisoning through tag/branch mutation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-217 — Complete dependency closure is mandatory

- **Status:** LOCKED
- **Decision:** Direct, transitive, native, build-time executable, appliance, runtime, and other
  material dependencies are included in the admitted graph; unknown executable composition blocks
  release.
- **Reason:** Hidden dependencies create unverifiable attack surface and compliance gaps.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-218 — OSS/local doctrine is a production admission gate

- **Status:** LOCKED
- **Decision:** Required/bundled/distributed SerapeumOS-controlled production software above the
  host boundary must be open source and locally operable; mandatory proprietary/cloud dependencies
  are inadmissible.
- **Reason:** Proprietary dependencies violate Gold Rule #1 and create platform lock-in.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-219 — Host substrate cannot be used to launder closed product dependencies

- **Status:** LOCKED
- **Decision:** OS-provided capabilities are modeled as host substrate under MA-17, but a SerapeumOS-distributed/managed closed component cannot be relabeled as a host prerequisite to bypass Gold Rule #1.
- **Reason:** Relabeling closed components as host prerequisites evades OSS/local doctrine.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-220 — Ankole foundation requires exact intake provenance

- **Status:** LOCKED
- **Decision:** The locked Ankole v1.0.4-rc.1 commit remains the baseline, but production admission
  requires an intake receipt binding canonical upstream, independent tree digest, license,
  dependencies, patches, vulnerability state, and source bundle.
- **Reason:** Baseline commit alone does not prove current integrity or license compliance.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-221 — Ankole upstream changes are governed supply-chain events

- **Status:** LOCKED
- **Decision:** Moving away from the locked Ankole revision requires new provenance/security/license
  intake, MA-15 change governance, MA-20 qualification, and MA-18 deployment.
- **Reason:** Uncontrolled upstream adoption bypasses all governance and qualification gates.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-222 — License compliance is release-bound evidence

- **Status:** LOCKED
- **Decision:** Every production release binds component license identities, obligations/notices,
  and corresponding-source/source-bundle evidence; open-source status alone does not prove
  redistribution compatibility.
- **Reason:** License compatibility varies by combination; individual OSS status is insufficient.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-223 — Vulnerability status is exact-component affectedness, not scanner output

- **Status:** LOCKED
- **Decision:** Findings from multiple advisory sources are mapped to exact source/version/patch
  context and tracked as unknown/not-affected/affected/mitigated/patched/exception/revoked.
- **Reason:** Raw scanner output without component-level mapping produces false positives/negatives.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-224 — Security-invariant defeat is a release veto class

- **Status:** LOCKED
- **Decision:** A known unmitigated vulnerability that defeats a locked security invariant cannot be
  waived merely because a build is current or functional; post-release findings may raise the
  MA-18 security floor.
- **Reason:** Waiving invariant defeats enables known-exploitable production releases.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-225 — Canonical production release builds are controlled and network-disabled

- **Status:** LOCKED
- **Decision:** All materials are admitted first; the authoritative build consumes only declared
  local inputs in a clean environment and does not resolve mutable network dependencies.
- **Reason:** Network-dependent builds introduce unpredictable and unverifiable material.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-226 — Build provenance binds exact bytes to exact source/materials/environment

- **Status:** LOCKED
- **Decision:** Every candidate has verifiable provenance identifying subject digests, source snapshot,
  material graph, builder, recipe, and build environment.
- **Reason:** Unprovenanced builds cannot be independently verified or reproduced.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-227 — Reproducibility strengthens but does not replace trust

- **Status:** LOCKED
- **Decision:** Canonical payloads are designed for reproducible/verifiable builds; nondeterministic
  packaging/signing envelopes are isolated and explained. Reproducibility does not override
  source/license/security/qualification gates.
- **Reason:** Reproducibility without other gates creates false confidence.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-228 — Build authority and release authority are distinct

- **Status:** LOCKED
- **Decision:** The Build Provenance Authority cannot self-authorize its own output. Root, build
  provenance, release authorization, and security revocation are separate logical authorities.
- **Reason:** Self-authorizing builds creates conflict of interest and eliminates independent review.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-229 — Supply-chain root is locally verifiable and not cloud-dependent

- **Status:** LOCKED
- **Decision:** Routine production verification/signing must not require a hosted transparency log,
  cloud CA, keyless identity service, or proprietary signing service. Root changes are offline/
  high-risk and dual-controlled.
- **Reason:** Cloud-dependent supply-chain roots violate Gold Rule #1 and create external chokepoints.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-230 — Release Envelope is the signed supply-chain identity

- **Status:** LOCKED
- **Decision:** The Release Envelope binds exact payload manifest, source, build provenance, material
  graph, SBOM, license/vulnerability evidence, compatibility contracts, MA-20 qualification identity,
  and security floor.
- **Reason:** Dispersed metadata prevents unified verification at activation time.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-231 — SBOM is mandatory but not the sole supply-chain database

- **Status:** LOCKED
- **Decision:** Every production release includes a machine-readable interoperable SBOM; the richer
  Supply-Chain Registry and Build Materials Inventory retain policy/provenance detail outside
  normal SBOM scope.
- **Reason:** SBOM alone lacks the depth needed for full provenance and policy enforcement.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-232 — Offline updates preserve authenticity and anti-rollback semantics

- **Status:** LOCKED
- **Decision:** Offline packages contain sufficient trust/release/security metadata for local
  verification, while persisted sequence/security-floor state prevents silent downgrade.
  Offline authenticity never falsely claims global freshness.
- **Reason:** Offline-only packages without anti-rollback state enable downgrade attacks.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-233 — Signed old software can still be inadmissible

- **Status:** LOCKED
- **Decision:** Revocation/security-floor metadata can block a historically authentic release or
  signer; signatures preserve provenance history but do not override current security policy.
- **Reason:** Historical authenticity ≠ current admissibility; security policy supersedes signature validity.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-234 — No production dynamic public-registry dependency installation

- **Status:** LOCKED
- **Decision:** Trusted runtime/update paths consume admitted Release Envelopes or separately admitted
  prerequisites; public registries never directly extend trusted production state.
- **Reason:** Public registry installation introduces unadmitted and unverified material into production.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-235 — Appliance images and privileged helpers are transparent supply-chain artifacts

- **Status:** LOCKED
- **Decision:** VMMs/drivers/helpers and Agent Appliance images have explicit source/material/
  license/provenance and exact digests; opaque golden images are not trusted production foundations.
- **Reason:** Opaque artifacts prevent independent verification and create black-box dependencies.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-236 — AI/Agent output cannot grant supply-chain trust

- **Status:** LOCKED
- **Decision:** Agents/models may propose or analyze dependencies but cannot admit them, sign
  provenance/releases, waive blockers, or promote generated code into trusted production.
- **Reason:** Agent-authored trust decisions lack independent verification and enable manipulation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-237 — MA-19 and MA-20 prove different facts

- **Status:** LOCKED
- **Decision:** MA-19 establishes exact identity, lineage, materials, licensing, vulnerability state,
  and release authorization; MA-20 establishes executable behavior/fitness of those exact bytes.
  MA-18 activates only after both gates pass.
- **Reason:** Identity proof ≠ behavior proof; both are required before activation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-238 — Architecture closure and executable qualification are separate states

- **Status:** LOCKED
- **Decision:** MA-20 closure completes the qualification architecture only; no product/backend/
  release is qualified until the implemented exact candidate later executes the required evidence suite.
- **Reason:** Architecture completion ≠ empirical qualification; the latter requires execution.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-239 — Qualification binds exact candidate, transition and environment scope

- **Status:** LOCKED
- **Decision:** A passing verdict is bound to exact candidate digests, Qualification Policy, matrix
  row/resource profile and migration/state-transition claims; it cannot be reused for materially
  different bytes or contexts.
- **Reason:** Reusing qualification across different candidates invalidates the evidence binding.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-240 — Qualification Authority is independent of candidate/build/release authority

- **Status:** LOCKED
- **Decision:** Agents/models/candidate generators and ordinary build processes cannot self-declare
  production qualification. MA-20 emits evidence; MA-19 Release Authorization remains separate.
- **Reason:** Self-qualification eliminates independent verification and creates conflict of interest.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-241 — Qualification Policy is durable and versioned

- **Status:** LOCKED
- **Decision:** Required gates, matrices, thresholds, evidence quality, exceptions, vetoes and
  requalification triggers are versioned policy; threshold changes cannot retroactively manufacture
  a pass.
- **Reason:** Retroactive threshold lowering invalidates prior qualification evidence.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-242 — Inconclusive/not-run/stale evidence is not pass

- **Status:** LOCKED
- **Decision:** Required evidence must be explicitly PASS or covered by a legitimate non-veto
  applicability/exception rule; uncertainty fails closed.
- **Reason:** Assuming pass on uncertainty enables unproven claims to become production basis.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-243 — Failure and rerun history is preserved

- **Status:** LOCKED
- **Decision:** Passing reruns do not erase earlier failures; rerun-until-green without retained
  evidence is prohibited.
- **Reason:** Erasing failure history hides patterns that indicate systemic issues.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-244 — Production qualification uses a QG-0→QG-9 gate graph

- **Status:** LOCKED
- **Decision:** Candidate identity, static/component/system, adversarial, recovery, lifecycle,
  resource/endurance, host-matrix and final evidence-review gates are separate and ordered
  by dependency.
- **Reason:** Sequential gating ensures each layer is proven before the next is attempted.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-245 — Real security mechanisms require real qualification

- **Status:** LOCKED
- **Decision:** Mocks may supplement tests but cannot be the sole proof of VMM, filesystem,
  key-provider, service, storage or other real host-enforced security properties.
- **Reason:** Mock proofs do not exercise real hardware/OS security boundaries.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-246 — Hostile Agent qualification assumes guest-root compromise

- **Status:** LOCKED
- **Decision:** FULL_LOCAL_AUTONOMY backend qualification includes malicious guest/Worker scenarios
  and must prove the MA-01/MA-17 containment contract, not merely cooperative workload operation.
- **Reason:** Cooperative-only qualification misses the actual threat model of hostile execution.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-247 — False success is a hard release veto

- **Status:** LOCKED
- **Decision:** A consequential action that can report success before its required postcondition is
  proven blocks the affected production qualification until fixed/requalified.
- **Reason:** False success creates confidence in unproven behavior, enabling production failures.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-248 — Storage guarantees are independently qualified

- **Status:** LOCKED
- **Decision:** Atomic visibility, crash durability, content correctness, path containment and
  concurrency behavior are distinct tested properties on each claimed host/filesystem family.
- **Reason:** One property passing does not imply others pass; each requires independent proof.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-249 — Backup claims require restore proof

- **Status:** LOCKED
- **Decision:** An untested Backup Set is not represented as proven recoverable; supported recovery
  paths are exercised in isolation with integrity/reconciliation evidence.
- **Reason:** Untested backups are unproven and may fail catastrophically at the moment of need.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-250 — Update/migration/rollback support is edge-specific

- **Status:** LOCKED
- **Decision:** Every claimed source→target transition and rollback class has explicit qualification
  evidence. There is no generic "upgrade/rollback from any version" claim.
- **Reason:** Generic claims hide unqualified edges where migration may fail silently.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-251 — Clean-machine qualification prevents hidden developer dependencies

- **Status:** LOCKED
- **Decision:** Every claimed first-install production family is tested from a controlled clean host
  without undeclared developer state/caches/runtimes/credentials.
- **Reason:** Developer-environment dependencies create failure on clean production hosts.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-252 — Resource scarcity must fail safe under stress

- **Status:** LOCKED
- **Decision:** Stress/OOM/disk/concurrency/endurance qualification proves that scarcity cannot
  broaden authority, weaken isolation/audit/recovery, expose secrets or corrupt authoritative state.
- **Reason:** Normal-operation qualification misses failure modes that emerge under pressure.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-253 — Endurance is a release evidence class

- **Status:** LOCKED
- **Decision:** Material releases execute policy-defined long-duration/churn workloads; zero
  architecture-invariant violations, false success, authoritative corruption and unexplained
  trusted-plane crashes are required for the applicable endurance gate.
- **Reason:** Short-duration tests miss degradation, memory leaks, and state corruption that
  appear only over extended operation.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-254 — Qualification Matrix rows define production support

- **Status:** LOCKED
- **Decision:** Windows/Linux support is claimed only for evidence-backed host/backend/filesystem/
  resource/mode rows or justified equivalence classes; architecture support alone is not release
  support.
- **Reason:** Architecture support ≠ qualified production support; claims require evidence per row.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-255 — Windows 11 x86-64/NTFS is the first qualification family

- **Status:** LOCKED
- **Decision:** The first production family remains Windows 11 x86-64 on qualified local fixed NTFS
  storage, with exact OS/backend versions selected and proven during actual qualification.
- **Reason:** First-family designation sets the baseline against which all subsequent families
  are compared; it must be fully qualified before claiming broader support.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-256 — Linux remains separately qualified

- **Status:** LOCKED
- **Decision:** Linux x86-64/KVM with qualified ext4/XFS remains architecture-supported but becomes
  production-supported only for matrix rows that independently pass MA-20.
- **Reason:** Architecture support for Linux does not imply qualified production support.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-257 — Material host changes can stale qualification

- **Status:** LOCKED
- **Decision:** OS/kernel/backend/storage/key-provider/driver and other material host changes
  trigger reprobe and impact-based requalification rather than inheriting support silently.
- **Reason:** Silent inheritance of qualification across host changes risks untested combinations.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-258 — Final production qualification proves local-only operation

- **Status:** LOCKED
- **Decision:** Core production operation and release verification must function without mandatory
  cloud inference, NaraRouter, public registries, hosted signing/transparency, external telemetry
  or other hidden cloud dependencies.
- **Reason:** Hidden cloud dependencies violate Gold Rule #1 and create external failure points.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-259 — Delta qualification requires evidence-backed impact analysis

- **Status:** LOCKED
- **Decision:** Prior evidence may be retained only when exact baseline/diff/dependency impact proves
  unaffected claims remain valid; diff size alone is not authority.
- **Reason:** Large diffs may be benign; small diffs may be critical—size alone is not evidence.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-260 — Flaky hard-gate behavior is not a pass

- **Status:** LOCKED
- **Decision:** Unexplained intermittent failure in required security/reliability gates remains
  FAIL/INCONCLUSIVE until resolved or, only for non-veto items, covered by a bounded visible
  exception.
- **Reason:** Accepting flaky passes hides real failures that may manifest in production.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-261 — Qualification exceptions cannot waive constitutional/security invariants

- **Status:** LOCKED
- **Decision:** Exceptions are scoped, justified, visible and expiring; hard architecture/security
  vetoes require architecture/governance change and requalification, not ordinary waiver.
- **Reason:** Waivable vetoes erode the security floor over time through accumulated exceptions.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-262 — Release readiness is multidimensional gate evidence

- **Status:** LOCKED
- **Decision:** No scalar score or pass percentage can trade many successful tests against one hard
  veto.
- **Reason:** Composite scores mask hard failures that individually block release.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-263 — MA-20 emits a Release Qualification Receipt

- **Status:** LOCKED
- **Decision:** The Receipt binds exact candidate, policy, matrix rows, transition claims, Evidence
  Bundle, verdict, exceptions and staleness conditions and is referenced by MA-19 Release
  Authorization.
- **Reason:** Without a structured Receipt, qualification evidence is dispersed and unverifiable.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-264 — Post-release evidence may stale/revoke current qualification without rewriting history

- **Status:** LOCKED
- **Decision:** A release can remain historically qualified at time T while new vulnerability/host/
  field evidence changes current admissibility/support and triggers security-floor/revocation action.
- **Reason:** History must remain accurate; current admissibility reflects current evidence.
- **Supersession:** Only through explicit Owner-approved governance change.

---

## D-265 — MA-20 closure does not start implementation automatically

- **Status:** LOCKED
- **Decision:** After MA-20 persistence, the required next steps remain Final cross-domain consistency
  audit, fresh-agent reconstruction validation and Final Master Architecture Gate PASS before
  implementation decomposition/agent activation.
 - **Reason:** Architecture closure ≠ implementation readiness; governance gates must still pass.
 - **Supersession:** Only through explicit Owner-approved governance change.

 ---

## D-266 — Foundation terminology clarification

- **Status:** LOCKED
- **Decision:** The term "qualified foundation" in D-013's original historical
  wording referred to foundation selection and architecture-baseline status. It
  does NOT mean the foundation has completed MA-20 executable release qualification.
  The correct current term is "locked foundation baseline." Any earlier use of
  "qualified" in the Foundation field refers to architecture-selection, not
  empirical release qualification.
- **Reason:** A fresh agent reading D-013 could conflate architecture selection
  with MA-20 production admission. The terminology must be unambiguous.
- **Supersession:** Only through explicit Owner-approved governance change.
