# MA-05 — Memory / Knowledge / Provenance / Epistemic Governance

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-05 defines what SerapeumOS may know, remember, infer, retrieve, forget, and treat as evidence.

It governs:

- truth classes;
- evidence;
- facts and judgments;
- provenance;
- confidence;
- temporal validity;
- contradiction;
- supersession;
- memory scope;
- retrieval;
- working context;
- learned lessons.

The objective is not “more memory.” The objective is **traceable, scoped, revisable knowledge without silent epistemic promotion**.

---

## 2. Five truth/state classes

### LOCKED

SerapeumOS keeps these domains conceptually separate:

| Truth/state class | Meaning | Primary owner |
|---|---|---|
| **Organizational Truth** | Company, Owner, Agents, roles, missions, goals, task responsibility | MA-03 / MA-04 |
| **Execution Truth** | task/workflow/job/turn state, attempts, results, receipts | MA-04 / MA-12 / MA-14 |
| **Epistemic Truth** | evidence, claims, facts, judgments, confidence, provenance, contradiction | **MA-05** |
| **Working Context** | temporary material assembled for the current reasoning/execution step | runtime only |
| **System Evolution Truth** | evaluations, lessons, strategy candidates, experiments, promoted improvements | MA-15 |

### LOCKED

No layer may silently overwrite another.

Examples:

- retrieved context cannot redefine Company structure;
- a model-generated claim cannot become an Owner decision;
- a successful execution cannot prove a factual claim outside its evidence;
- a learned lesson cannot automatically become governance.

---

## 3. Existing Ankole knowledge substrate

### REPOSITORY FACT

Ankole Brain already provides useful primitives:

- durable Objects/pages with version history;
- atomic Claims;
- `fact` and `take` claim types;
- confidence/weight;
- provenance;
- temporal validity;
- supersession;
- expiration/deactivation;
- contradiction records;
- audience scopes;
- source records;
- recall via lexical/vector retrieval;
- derived chunks/embeddings;
- deliberate forgetting;
- Dreaming/consolidation;
- Agent skill lessons;
- runtime context assembly.

### LOCKED

SerapeumOS reuses these primitives where their semantics fit.

It does not create a second generic vector-memory database or second knowledge graph without a proven architectural gap.

---

## 4. Evidence precedes belief

### LOCKED

The canonical epistemic flow is:

```text
SOURCE / OBSERVATION
       ↓
EVIDENCE
       ↓
CLAIM
       ↓
evaluation / corroboration / contradiction
       ↓
CURRENT EPISTEMIC STATE
       ↓
retrieval / reasoning
```

A model output by itself is not evidence of the external world.

A model may:

- extract;
- summarize;
- classify;
- infer;
- propose.

Its output must retain provenance to the material and process that produced it.

---

## 5. Evidence

### LOCKED

Evidence is an immutable or integrity-verifiable observation/input used to support a claim.

Evidence may originate from:

- Owner/human statement;
- local file/document;
- system observation;
- tool result;
- execution receipt;
- external research source;
- imported structured data;
- another governed system.

Evidence must preserve enough provenance to answer:

- **what was observed?**
- **where did it come from?**
- **when was it observed?**
- **who/what captured it?**
- **what source revision/version applied?**
- **what Company scope applies?**

Exact artifact storage belongs to MA-09.

---

## 6. Claims

### LOCKED

An epistemic Claim is an atomic assertion derived from evidence, observation, or explicit judgment.

The existing Ankole distinction is retained:

### Fact

A **Fact** is an assertion intended to describe reality.

It carries:

- provenance;
- confidence;
- temporal validity where applicable;
- scope;
- holder/subject context.

### Take

A **Take** is an interpretation, judgment, prediction, preference, hypothesis, or other calibratable non-factual assertion.

It carries:

- provenance;
- weight/confidence semantics;
- active/resolved state;
- calibration/resolution evidence where applicable.

### LOCKED

The database label `fact` means **fact-type epistemic claim**, not infallible truth.

A Fact remains challengeable, supersedable, expirable, and subject to contradiction.

---

## 7. No silent epistemic promotion

### LOCKED

Information cannot silently move upward in epistemic authority.

Examples:

```text
retrieved text ≠ verified fact
model inference ≠ observed evidence
repeated claim ≠ corroboration
high similarity ≠ truth
high model confidence ≠ source confidence
Agent memory ≠ Company decision
```

Any promotion from observation/inference into durable current knowledge must pass explicit write rules and retain provenance.

---

## 8. Provenance

### LOCKED

Every durable Claim requires provenance.

Provenance must identify, directly or through stable references:

- source/evidence;
- author/capturing Principal or system;
- derivation method where applicable;
- relevant source revision/session;
- timestamp/validity;
- Company scope.

### LOCKED

Derived knowledge must preserve lineage to its inputs.

Consolidation, summarization, extraction, or synthesis does not sever provenance.

---

## 9. Confidence and uncertainty

### LOCKED

Confidence is explicit epistemic metadata, not hidden model intuition.

The existing bounded Ankole confidence/weight concept is retained.

### LOCKED

The system must distinguish at least:

- unknown;
- weak/uncertain;
- supported;
- contradicted/disputed;
- superseded/expired;
- resolved.

Exact UI labels and numeric calibration are implementation details.

### LOCKED

Absence of evidence must not be represented as positive evidence.

When required evidence is missing, the system must be able to answer:

> **Unknown / insufficient evidence**

rather than fabricate certainty.

---

## 10. Source independence

### LOCKED

Corroboration requires meaningful source independence.

Multiple claims copied from the same upstream source are not multiple independent confirmations.

The system should preserve upstream source identity/revision so later confidence logic can distinguish:

- repeated observation of one source;
- genuinely independent evidence.

Detailed confidence aggregation remains implementation design.

---

## 11. Temporal truth

### LOCKED

Knowledge may change over time.

Facts may carry:

- valid-from;
- valid-until;
- observed/captured time;
- supersession;
- expiration.

### LOCKED

A newer claim does not automatically erase an older historically valid claim.

The system must distinguish:

```text
was true then
is current now
was corrected
became obsolete
is disputed
```

This supports historical reconstruction.

---

## 12. Supersession

### LOCKED

Corrections and updates preserve history.

The preferred semantic pattern is:

```text
old claim
   ↓ superseded_by
new claim
```

rather than destructive overwrite.

The old claim leaves current-state retrieval where appropriate but remains auditable.

This aligns with the inherited Ankole Claim contract.

---

## 13. Contradictions

### LOCKED

Contradictions are first-class epistemic objects.

Detection of a contradiction must not silently mutate either claim.

The system records:

- conflicting claim identities;
- conflict axis;
- severity;
- confidence;
- status;
- resolution evidence/decision.

### LOCKED

Unresolved material contradictions remain visible as uncertainty.

The system must not arbitrarily choose whichever claim is newest, most similar, or model-preferred unless an explicit domain rule establishes that behavior.

Resolution history remains durable.

---

## 14. Objects / knowledge pages

### LOCKED

Brain Objects/pages are durable knowledge containers and navigation surfaces.

They are useful for:

- entity/topic pages;
- structured knowledge presentation;
- source-managed projections;
- contextual retrieval.

### LOCKED

An Object body is not automatically authoritative merely because it is stored in the Brain.

Atomic Claim/evidence provenance remains the stronger epistemic unit where factual precision matters.

Object version history is preserved.

---

## 15. Retrieval is not truth authority

### LOCKED

Search, embeddings, BM25, reranking, salience, recency, graph adjacency, and similar mechanisms answer:

> **What should be considered?**

They do not answer:

> **What is true?**

### LOCKED

Retrieval scores never become factual confidence.

Changing embedding model, index, reranker, or retrieval algorithm cannot change authoritative stored knowledge.

---

## 16. Derived retrieval state

### LOCKED

The following are rebuildable projections:

- embeddings;
- chunks;
- search indexes;
- retrieval caches;
- context packs;
- ranking scores.

Loss or rebuild of these must not destroy authoritative knowledge/evidence.

Exact physical storage belongs to MA-09.

---

## 17. Working Context

### LOCKED

Working Context is temporary material assembled for one reasoning/execution step.

It may include:

- retrieved Claims;
- source excerpts;
- Task data;
- recent conversation;
- Mission/role projections;
- tool results;
- temporary summaries.

### LOCKED

Working Context is disposable.

It is **not institutional memory**.

A model seeing information in context does not mean the Company or Agent has durably learned it.

Durable learning requires an explicit governed write.

---

## 18. Memory scopes

### LOCKED

Every epistemic record is Company-scoped first.

Within a Company, audience/disclosure scope may further restrict access.

Conceptually:

```text
Company Scope
   └── Audience Scope
        ├── company-wide
        ├── organizational group/unit
        └── Principal-private
```

### LOCKED

Ankole's existing `world / group:<...> / principal:<...>` audience model may be reused internally, but in SerapeumOS:

> **`world` means the broadest permitted audience inside the record's Company scope — never cross-Company global disclosure.**

This prevents future multi-Company leakage.

---

## 19. Agent-private vs Company knowledge

### LOCKED

An Agent may hold private or restricted epistemic state.

That does not make it invisible to governance/audit authority where policy requires oversight.

### LOCKED

Agent-private knowledge does not automatically become Company-wide knowledge.

Company-wide knowledge requires explicit compatible scope and write authority.

Likewise, a Company Owner's ability to govern an Agent does not automatically disclose group-restricted content to unrelated recipients.

Detailed disclosure policy belongs to MA-06/MA-16.

---

## 20. Knowledge access and disclosure

### LOCKED

Knowledge retrieval has two gates:

1. **reachability** — may the querying Principal access the record?
2. **disclosure** — may the retrieved record be disclosed to the actual recipients/context?

This aligns with the inherited Ankole Brain access design.

### LOCKED

Knowledge should be filtered before final context assembly where technically practical.

A model should not receive inaccessible knowledge and then be trusted not to reveal it.

---

## 21. Human statements

### LOCKED

Explicit human statements are evidence of **what that human stated**.

They are not automatically universal factual truth.

For example:

- “I prefer X” can directly support a preference about that person.
- “Vendor Y is certified” is a claim requiring appropriate evidence if factual correctness matters.

The system must preserve this distinction.

---

## 22. Agent/model-derived knowledge

### LOCKED

Agent/model inference may generate candidate Facts or Takes only through governed epistemic write paths.

Such writes require:

- explicit provenance;
- author/system attribution;
- confidence/weight;
- applicable source references;
- scope.

### LOCKED

Model-generated knowledge must never be mislabelled as human-authored or directly observed.

---

## 23. Learning and skill lessons

### LOCKED

Operational learning is distinct from factual knowledge.

Examples:

- “This tool sequence works better.”
- “This coding pattern caused failures.”
- “This workflow should use strategy B.”

These belong to **lessons/evolution evidence**, not ordinary external-world Facts.

The inherited Agent Skill Lesson machinery may be reused.

### LOCKED

A learned lesson does not automatically change:

- governance;
- permissions;
- architecture;
- Company doctrine;
- executable system strategy.

Promotion into durable System Evolution behavior belongs to MA-15.

---

## 24. Dreaming / consolidation

### LOCKED

Background consolidation may:

- group related evidence;
- synthesize candidate Takes;
- identify patterns;
- detect contradictions;
- propose schema/knowledge improvements.

It may not silently:

- rewrite Company governance;
- resolve material contradictions without policy;
- convert unsupported inference into high-authority truth;
- erase source evidence.

### LOCKED

Dreaming outputs remain derived knowledge with provenance.

Human/authorized review remains required for promotion classes defined by MA-15.

---

## 25. Forgetting and deletion

### LOCKED

Normal forgetting means withdrawing information from current use while preserving required history.

Preferred semantics:

- Fact → expire;
- Take → deactivate;
- Object → soft-delete;
- corrected Claim → supersede.

This matches current Ankole behavior.

### LOCKED

Hard deletion is exceptional and governed by:

- privacy/data-retention rules;
- Company/Owner intent;
- legal/operational requirements;
- backup/recovery constraints.

Hard deletion policy belongs to MA-09/MA-13/MA-14.

---

## 26. Source updates

### LOCKED

When an upstream source changes, the system must not leave old source-derived claims silently current.

Source revision/relearning must support:

- identifying prior source-derived claims;
- expiring/superseding affected current claims;
- writing new claims;
- preserving historical provenance.

This aligns with Ankole source-session provenance behavior.

---

## 27. Epistemic vs organizational authority

### LOCKED

The Brain does not own organizational decisions.

Examples:

- Company Owner;
- Agent role;
- Mission;
- Task assignment;
- AuthZ permission;
- Action approval.

These may be *represented* or referenced in knowledge, but their authoritative state remains in the owning domain.

If Brain memory contradicts authoritative Company state, authoritative Company state wins and the memory discrepancy becomes an epistemic issue to repair.

---

## 28. Epistemic vs execution truth

### LOCKED

Execution receipts/results can be evidence for claims, but the Brain does not replace execution state.

Example:

```text
Task status = COMPLETED
```

belongs to Execution Truth.

```text
“The task produced output X with measured result Y”
```

may become epistemic knowledge with provenance to the execution evidence.

---

## 29. Provenance preservation through summarization

### LOCKED

Summaries, synthesized pages, context packs, and consolidated knowledge must retain links to underlying sources/claims sufficient for later inspection.

A concise representation may omit source text, but it must not sever source identity.

---

## 30. Epistemic read rule

### LOCKED

When answering or deciding from knowledge, the system should be able to distinguish:

- supported Fact;
- Take/judgment;
- unresolved contradiction;
- stale/superseded information;
- insufficient evidence.

The model may phrase this naturally, but the underlying classification must not be lost.

---

## 31. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| Company/role/task authority | MA-03 / MA-04 |
| capabilities and disclosure permission | MA-06 |
| embedding/model provider | MA-07 |
| external research/tool ingestion | MA-08 |
| physical DB/artifact schema | MA-09 |
| secrets in sources | MA-10 |
| retry/recovery | MA-12 |
| backups/retention | MA-13 |
| audit/privacy retention | MA-14 |
| lesson/evolution promotion | MA-15 |
| memory/uncertainty UX | MA-16 |

These deferrals do not block MA-05 closure.

---

## 32. Veto conditions

An MA-05 implementation is invalid if it:

- treats vector similarity as truth;
- treats model confidence as evidence confidence;
- stores durable factual claims without provenance;
- makes Working Context institutional memory automatically;
- silently resolves contradictions by model preference;
- destructively overwrites corrected claims by default;
- loses source lineage during summarization/consolidation;
- allows cross-Company knowledge leakage through `world` scope;
- lets Agent memory override Organizational or Execution Truth;
- treats duplicated copies of one source as independent corroboration;
- converts lessons directly into governance/architecture changes;
- depends on one embedding/model vendor for authoritative memory.

---

## 33. MA-05 closure decision

### CLOSED

MA-05 is architecture-complete.

Locked:

- five truth/state classes;
- evidence-before-claim model;
- Facts vs Takes;
- mandatory provenance;
- explicit confidence/uncertainty;
- temporal validity;
- supersession;
- first-class contradictions;
- Company-first knowledge scope;
- reachability + disclosure gates;
- retrieval as non-authoritative projection;
- Working Context as disposable;
- source-revision lineage;
- governed forgetting;
- operational lessons separated from factual knowledge;
- Dreaming/consolidation as derived, non-governing learning.

No material MA-05 architecture question remains inside this domain.

---

## 34. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-054 — Five truth/state classes remain separate
Organizational Truth, Execution Truth, Epistemic Truth, Working Context, and System Evolution Truth are distinct and cannot silently overwrite one another.

### D-055 — Evidence precedes durable epistemic claims
Durable knowledge requires explicit provenance. Model output alone is not external-world evidence.

### D-056 — Reuse Ankole Fact/Take semantics
Ankole Facts remain challengeable factual claims; Takes remain judgments/hypotheses. Neither is infallible truth.

### D-057 — Retrieval is not authority
Embeddings, chunks, lexical/vector ranking, reranking, salience and context packs are rebuildable retrieval projections and cannot determine truth.

### D-058 — Working Context is disposable
Information entering model context does not become institutional memory without an explicit governed write.

### D-059 — Company scope precedes audience scope
All epistemic records are Company-scoped. `world` is only the broadest audience inside that Company, never cross-Company global scope.

### D-060 — Contradictions remain explicit until resolved
Contradiction detection never silently rewrites competing claims; unresolved material contradictions remain visible.

### D-061 — Corrections preserve history
Fact expiration, Take deactivation, Claim supersession, and Object versioning/soft deletion are preferred over destructive overwrite.

### D-062 — Learning lessons are not factual/governance truth
Operational lessons/evolution evidence are separated from external-world Facts and require MA-15 promotion before changing system strategy/governance.

---

## 35. Project-state transition

After persistence:

```text
Completed architecture domains:
MA-01 — CLOSED
MA-02 — CLOSED
MA-03 — CLOSED
MA-04 — CLOSED
MA-05 — CLOSED

Current architecture domain:
MA-06 — AuthZ / Capabilities / Action Assurance

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-06-CLOSE — architecture only
```

---

## 36. Next action

**MA-06-CLOSE — AuthZ / Capabilities / Action Assurance**

Architecture only.
