# MA-07 — Models / Inference Runtime / Routing / Regression Control

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-07 defines how SerapeumOS uses models without making any model, provider, or inference server part of Agent identity or organizational authority.

It governs:

- model/provider abstraction;
- local inference runtime;
- logical model profiles;
- routing and binding;
- fallback;
- model/runtime lifecycle;
- capability discovery;
- reproducibility;
- regression qualification;
- temporary NaraRouter development use.

MA-07 does not select final model weights, benchmark thresholds, GPU budgets, installer mechanics, or tool execution policy.

---

## 2. Governing principle

### LOCKED

```text
Agent identity
    ≠
Model
    ≠
Provider
    ≠
Inference Runtime
```

Models are replaceable intelligence.

They do not own:

- Agent identity;
- Company authority;
- permissions;
- durable organizational truth;
- durable execution truth;
- approval authority.

Changing a model must not require redesigning the Agent or Company architecture.

---

## 3. Existing Ankole foundation

### REPOSITORY FACT

Ankole already provides:

- control-plane-owned `AIGateway`;
- provider abstraction and provider DSL;
- model/profile resolution;
- Agent-scoped model profiles;
- frozen runtime model references for durable jobs;
- provider/model capability metadata;
- reasoning/context/provider options;
- vision fallback;
- embedding/rerank model paths;
- provider credential isolation from Workers.

Current built-in Agent model profiles include:

```text
primary
light
heavy
coding
vision_fallback
web_search
web_fetch
image_generate
```

### LOCKED

SerapeumOS reuses the **AIGateway abstraction and profile/binding concepts**.

It does not create a second generic model gateway.

---

## 4. Final production locality rule

### LOCKED OWNER RULE

Final SerapeumOS production operation is **100% local**.

Therefore final production inference must use qualified local inference runtimes and locally available model artifacts.

Normal final operation must not require:

- hosted LLM APIs;
- cloud inference;
- hosted model routing;
- remote credential pools;
- Internet availability.

Inherited Ankole cloud provider implementations may remain foundation code, but they are **not eligible as required SerapeumOS production inference dependencies**.

---

## 5. NaraRouter exception

### LOCKED OWNER RULE

NaraRouter is permitted only as a temporary external inference dependency during development and validation.

### LOCKED

NaraRouter must sit behind the same inference abstraction used by local models.

No Company, Agent, Task, memory, workflow, or tool architecture may depend on NaraRouter-specific semantics.

Removing NaraRouter must require configuration/provider replacement, not system redesign.

NaraRouter is not a final runtime prerequisite.

---

## 6. Canonical inference topology

### LOCKED

```text
Agent / Brain / Trusted Service
          ↓
      AIGateway
          ↓
Model Profile / Capability Selector
          ↓
Frozen Model Binding
          ↓
Qualified Local Provider Adapter
          ↓
Local Inference Runtime
          ↓
Local Model Artifact
```

The Agent runtime never directly owns model-server administration.

---

## 7. AIGateway authority

### LOCKED

AIGateway remains the trusted inference mediation boundary.

It owns or mediates:

- provider configuration;
- model resolution;
- model binding;
- request normalization;
- provider/runtime differences;
- runtime credentials where applicable;
- response normalization;
- inference telemetry/evidence.

### LOCKED

AIGateway does not:

- become the Agent loop;
- become Task authority;
- grant permissions;
- execute Company tools;
- own organizational truth.

---

## 8. Local provider adapter contract

### LOCKED

A qualified local inference provider adapter must expose a common logical contract independent of the local runtime product.

At minimum it must support applicable capabilities for:

- discovery/health;
- model availability;
- request execution;
- streaming where supported;
- cancellation where supported;
- model capability metadata;
- bounded runtime errors.

The adapter hides runtime-specific details such as:

- endpoint protocol;
- CLI/API management;
- load/unload commands;
- model identifiers;
- runtime process mechanics.

### LOCKED

LM Studio, Ollama, llama.cpp-based runtimes, or future OSS local runtimes are **implementations**, not SerapeumOS architecture.

No one runtime is constitutionally locked by MA-07.

---

## 9. Local model artifact identity

### LOCKED

A model used for qualified execution must be identifiable independently of a mutable display name.

The runtime model identity should resolve, where technically available, to stable evidence equivalent to:

- model family/name;
- exact artifact/variant;
- quantization/build;
- local artifact fingerprint/hash or immutable source digest;
- inference-runtime compatibility;
- relevant context/capability metadata.

A mutable alias alone is insufficient for reproducible qualification.

Exact manifest format belongs to MA-09/MA-19.

---

## 10. Model profiles

### LOCKED

SerapeumOS uses **logical model profiles** so Company/Agent behavior requests a class of intelligence rather than hard-coding a model name.

The inherited profile concept is retained.

Core language-model semantics include at least:

- **primary** — normal Agent reasoning;
- **light** — lower-cost/lower-resource bounded work;
- **heavy** — difficult reasoning;
- **coding** — repository/code-oriented execution.

Additional capability profiles may exist for:

- vision;
- embedding;
- reranking;
- other local multimodal capabilities.

### LOCKED

Profile names express intended use.

They do not imply permission or organizational role.

---

## 11. Agent-scoped vs system-scoped models

### LOCKED

Language-model profile selection may be Agent-scoped.

Shared system functions such as:

- embedding;
- reranking;
- selected Brain maintenance functions

may use system/instance-level model configuration when appropriate.

This follows the useful Ankole separation.

### LOCKED

Shared system models still operate as non-authoritative inference services.

---

## 12. Model resolution

### LOCKED

A logical profile resolves through trusted configuration to a concrete runtime binding.

Conceptually:

```text
profile
→ provider/runtime
→ exact model artifact
→ request/runtime options
→ capability metadata
```

Resolution occurs outside the untrusted model.

A model cannot select itself into a more privileged profile.

---

## 13. Frozen execution binding

### LOCKED

For durable work, the concrete model binding is frozen when the execution attempt or durable job is admitted.

The binding must preserve enough information to identify:

- logical profile;
- provider/runtime;
- concrete model;
- relevant runtime/request options;
- relevant capability metadata.

### LOCKED

Retries of the **same execution attempt** use the same frozen binding unless a governed retry policy explicitly creates a new execution attempt with a new binding.

This preserves reproducibility and prevents silent behavioral drift.

---

## 14. Model change and Task identity

### LOCKED

Changing a model during later execution does not change:

- Agent identity;
- Mission;
- Task identity;
- accountability.

If a new model is used after failure/retry, the execution evidence must record that the binding changed.

The system must not present materially different model execution as if it were the same deterministic attempt.

---

## 15. Routing

### LOCKED

Routing decisions are trusted control-plane decisions.

Routing may consider:

- requested profile/capability;
- model qualification status;
- modality support;
- context requirements;
- runtime availability;
- MA-11 resource policy;
- Task policy;
- regression status.

A model cannot route itself outside the set authorized for the Task/profile.

---

## 16. Fallback

### LOCKED

Fallback must be explicit and deterministic.

Permitted conceptual fallback examples:

```text
coding → heavy
light → primary
text model → qualified vision fallback for image interpretation
```

only when configured and architecturally compatible.

### LOCKED

There is no uncontrolled “try any available model/provider” behavior.

### LOCKED

For high-assurance work, a materially different model fallback may require a new execution attempt/re-admission rather than transparent continuation.

Fallback use must be visible in execution evidence.

---

## 17. Provider/runtime failure

### LOCKED

Runtime/model failure must not silently broaden scope or authority.

If the required qualified model is unavailable, the system may:

- wait;
- retry under the same qualified binding;
- use an explicitly authorized fallback;
- fail/refuse the execution.

It must not silently use an unqualified model merely to produce an answer.

---

## 18. Model capability contract

### LOCKED

Each qualified model/runtime binding should expose relevant observed/declared capability metadata, such as:

- input modalities;
- context capacity;
- structured-output support;
- tool-call compatibility;
- reasoning mode/options;
- parallel tool-call support where applicable;
- embedding/rerank capability where applicable.

### LOCKED

Capability must be qualified, not assumed solely from model marketing/name.

Unknown capability fails closed for tasks that require it.

---

## 19. Tool boundary

### LOCKED

The model may propose tool calls.

It does not gain tool authority.

Canonical flow:

```text
Model proposes tool/action
        ↓
Agent/runtime interprets
        ↓
MA-08 tool contract
        ↓
MA-06 AuthZ / Capability / Action Assurance
        ↓
Tool/broker executes
```

### LOCKED

Provider-hosted tool execution must not become a bypass around SerapeumOS governance.

Final SerapeumOS should prefer tools executed through its governed tool boundary.

Any provider/runtime-native capability that creates external side effects requires explicit MA-08 qualification.

---

## 20. Model runtime isolation

### LOCKED

The model runtime is a restricted compute service separate from the Agent hard appliance.

It does not receive by default:

- arbitrary host files;
- Company database credentials;
- Agent secrets;
- tool credentials;
- governance authority;
- external network authority.

It receives only the inference inputs required for the request.

---

## 21. GPU and hardware

### LOCKED

GPU/accelerator use belongs to the local model runtime, not the hostile Agent appliance by default.

Agent execution obtains intelligence through AIGateway rather than direct GPU authority.

Detailed CPU/RAM/VRAM scheduling belongs to MA-11.

---

## 22. Local runtime lifecycle

### LOCKED

SerapeumOS may manage or observe local inference runtime state through a replaceable host/runtime adapter.

Conceptual states include:

```text
UNAVAILABLE
AVAILABLE
STARTING
READY
MODEL_LOADING
MODEL_READY
DEGRADED
STOPPING
FAILED
```

Exact commands/process mechanics are implementation-specific.

### LOCKED

A local runtime reporting a process as running does not prove the requested model is ready.

Readiness is capability/model-specific.

---

## 23. Offline operation

### LOCKED

Once required model artifacts and runtime components are installed locally, normal inference must operate offline.

Normal startup must not require:

- model registry access;
- cloud license validation;
- hosted metadata;
- remote authentication.

Artifact acquisition/update is a separate controlled lifecycle owned by MA-18/MA-19.

---

## 24. Model qualification

### LOCKED

A model/runtime binding is **unqualified** until tested for the profile/capability it is intended to serve.

Qualification is use-case specific.

A model may be qualified for:

```text
light
```

but not:

```text
coding
```

or vice versa.

### LOCKED

Qualification belongs to the binding/profile combination, not only to the model family name.

---

## 25. Regression control

### LOCKED

Changing any materially relevant inference component requires regression evaluation before promotion to a qualified/default binding.

Material changes include:

- model artifact;
- quantization;
- provider/runtime;
- major runtime version;
- prompt/protocol contract affecting behavior;
- tool-call protocol;
- reasoning-mode default;
- context/compaction behavior.

### LOCKED

Regression evaluation must cover the capabilities relevant to that profile.

Examples:

- task correctness;
- evidence/refusal behavior;
- structured output;
- tool selection/calling;
- coding correctness;
- context handling;
- failure behavior;
- latency/resource envelope where applicable.

Exact benchmark suites and thresholds belong to MA-20.

---

## 26. Promotion states

### LOCKED

Model bindings conceptually progress through:

```text
DISCOVERED
→ CANDIDATE
→ QUALIFIED
→ DEFAULT / APPROVED USE

and may become:

DEGRADED
REVOKED
SUPERSEDED
```

An unqualified discovered model is not automatically usable for production Agent work.

---

## 27. Default changes

### LOCKED

Changing a profile's default binding affects **newly admitted work**.

Already frozen durable executions keep their binding unless explicitly restarted/re-admitted under policy.

This prevents an operator model change from silently altering in-flight durable work.

---

## 28. Regression rollback

### LOCKED

If a newly promoted binding fails qualification or causes unacceptable regression:

- stop new assignment to that binding;
- restore the previous qualified profile binding where available;
- preserve evidence of affected runs;
- do not rewrite historical execution records.

Exact rollback mechanics belong to MA-12/MA-18/MA-20.

---

## 29. Model output epistemic status

### LOCKED

Model output remains inference.

It does not become:

- factual evidence;
- Company truth;
- Owner instruction;
- permission;
- Task completion

merely because it came from a qualified model.

MA-05 epistemic governance still applies.

---

## 30. Model observability

### LOCKED

Inference execution evidence must allow the system to determine, at minimum:

- subject/Agent;
- Task/execution context;
- logical profile;
- concrete model binding;
- provider/runtime;
- timing/outcome;
- fallback if used;
- bounded error classification;
- relevant token/resource information where available.

Prompts/responses may be subject to privacy/redaction policy.

Detailed telemetry and retention belong to MA-14.

---

## 31. Secrets

### LOCKED

Workers/models do not receive provider/runtime secrets unless the final local runtime contract absolutely requires a narrowly scoped runtime credential.

Secret handling is mediated by trusted services.

For final local-only inference, the preferred architecture requires no external provider secrets.

Exact secret storage belongs to MA-10.

---

## 32. Configuration authority

### LOCKED

Agents may request/recommend model-profile changes but cannot make themselves use an unqualified or more privileged runtime binding without trusted policy authorization.

Company Owner/operator configuration controls approved bindings.

System Evolution may propose new bindings under MA-15 but cannot silently promote them.

---

## 33. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| tool execution / web research | MA-08 |
| model artifact/storage manifests | MA-09 |
| runtime secrets | MA-10 |
| CPU/RAM/GPU admission | MA-11 |
| retry/recovery details | MA-12 |
| inference audit/privacy | MA-14 |
| automatic model improvement proposals | MA-15 |
| runtime/model UX | MA-16 |
| host/runtime compatibility | MA-17 |
| runtime/model installation/update | MA-18 |
| model/runtime supply chain | MA-19 |
| benchmark thresholds/release qualification | MA-20 |

These deferrals do not block MA-07 closure.

---

## 34. Veto conditions

An MA-07 implementation is invalid if it:

- makes model identity equal Agent identity;
- requires cloud inference for final operation;
- makes NaraRouter a permanent runtime dependency;
- lets Agents bypass AIGateway to administer inference infrastructure;
- silently falls back to arbitrary models/providers;
- changes an in-flight durable binding without evidence/re-admission;
- treats discovered models as automatically qualified;
- lets model output bypass MA-05 truth governance;
- lets provider-hosted tools bypass MA-06/MA-08 governance;
- exposes arbitrary Company/host state directly to model runtime;
- ties core architecture to one local runtime product.

---

## 35. MA-07 closure decision

### CLOSED

MA-07 is architecture-complete.

Locked:

- Agent/model/runtime identity separation;
- AIGateway retained as inference mediation boundary;
- final production local-only inference;
- NaraRouter development-only exception;
- replaceable local runtime adapters;
- logical model profiles;
- stable local model artifact identity;
- frozen bindings for durable execution;
- trusted routing;
- explicit deterministic fallback;
- capability qualification;
- model/runtime isolation;
- offline operation;
- profile-specific qualification;
- regression gating and rollback;
- model output remains non-authoritative inference.

No material MA-07 architecture question remains inside this domain.

---

## 36. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-071 — Models are replaceable intelligence
Agent identity, authority, Mission, and Task identity are independent from model/provider/runtime selection.

### D-072 — AIGateway remains the inference boundary
SerapeumOS reuses Ankole AIGateway for provider abstraction, model resolution, binding, request mediation, and response normalization.

### D-073 — Final production inference is local
Qualified final SerapeumOS operation uses local inference runtimes and local model artifacts; hosted inference is not a required production dependency.

### D-074 — NaraRouter is development/validation only
NaraRouter may temporarily serve inference during build/validation but cannot enter final architecture as a required service.

### D-075 — Logical profiles select qualified bindings
Agents/tasks request logical model profiles; trusted resolution maps them to concrete qualified local model/runtime bindings.

### D-076 — Durable work freezes its model binding
A durable execution stores/fixes the concrete model binding at admission. Retries do not silently change models.

### D-077 — Fallback is explicit and evidenced
Fallback may occur only through configured compatible paths and must be observable; arbitrary provider/model fallback is prohibited.

### D-078 — Model qualification is profile-specific
A discovered model/runtime binding is not production-usable until qualified for its intended capability/profile.

### D-079 — Inference changes require regression gates
Material model, quantization, runtime, protocol, reasoning, or tool-call changes require regression evaluation before promotion.

### D-080 — Model tools remain governed
Model-generated or provider-native tool actions cannot bypass AuthZ, Capability, Action Assurance, or MA-08 tool governance.

---

## 37. Project-state transition

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

Current architecture domain:
MA-08 — Tools / Skills / Plugins / MCP / External Research

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-08-CLOSE — architecture only
```

---

## 38. Next action

**MA-08-CLOSE — Tools / Skills / Plugins / MCP / External Research**

Architecture only.
