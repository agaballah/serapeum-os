# MA-10 — Secrets / Credentials / Security Principals

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-10 defines:

- security Principal classes;
- authentication identity vs organizational identity;
- secret taxonomy;
- credential ownership;
- root/key hierarchy;
- encryption-at-rest principles;
- secret references and mediation;
- runtime credential issuance;
- secret injection;
- rotation and revocation;
- redaction and leakage response.

The governing rule is:

> **Identity may be durable; credentials must remain replaceable. Authority must never depend on exposing long-lived secrets to untrusted Agent execution.**

---

## 2. Existing Ankole foundation

### REPOSITORY FACT

Ankole already provides:

- durable `Principal` identities of type:
  - `human`
  - `agent`
  - `system`;
- human local credentials using Argon2id password hashes;
- external identity bindings;
- encrypted application/plugin configuration fields;
- encrypted AIGateway provider credential fields;
- purpose/context-derived AEAD keys;
- generated RuntimeFabric Worker authentication secret;
- encrypted Worker environment values;
- outbound filtering for selected installation secrets;
- token/signing/authentication components.

### LOCKED

SerapeumOS reuses these foundations where their security semantics fit.

It does not create a second competing Principal identity system or generic credential store without a proven architectural need.

---

## 3. Identity is not credential

### LOCKED

```text
Principal identity
    ≠
Authentication credential
    ≠
Authorization grant
    ≠
Capability
    ≠
Runtime token
```

A Principal keeps the same identity when:

- password changes;
- external account changes;
- token rotates;
- runtime credential expires;
- secret is revoked;
- model changes;
- Agent runtime is replaced.

Credentials prove or enable access for an identity; they are not the identity itself.

---

## 4. Durable accountable Principals

### LOCKED

The durable accountable Principal classes remain:

```text
HUMAN
AGENT
SYSTEM
```

using the inherited Ankole Principal model.

### Human Principal

Represents a human user/Owner/operator.

### Agent Principal

Represents a persistent AI colleague.

### System Principal

Represents a trusted installation/service identity when durable attribution is required.

### LOCKED

No new Principal type is introduced merely for:

- Worker process;
- appliance instance;
- model;
- browser process;
- tool process;
- transient connection.

Those are runtime identities, not durable organizational Principals.

---

## 5. Runtime security identities

### LOCKED

Transient trusted/untrusted runtimes may have authenticated **runtime identities** separate from durable Principals.

Examples:

- Agent Appliance instance;
- Worker incarnation;
- trusted broker instance;
- local model runtime connection.

A runtime identity must resolve to its accountable context where needed, for example:

```text
runtime_instance
→ worker_incarnation
→ assigned Agent Principal
→ Company
```

### LOCKED

Runtime identity is ephemeral and cannot replace Agent Principal identity.

Destroying/replacing a Worker or appliance destroys its runtime identity without changing the Agent.

---

## 6. Authentication vs authorization

### LOCKED

Authentication answers:

> **Who/what is presenting this request?**

Authorization answers:

> **May that authenticated Principal/runtime perform this action?**

Authentication success never implies unrestricted authority.

MA-06 remains the authorization authority.

---

## 7. Human authentication

### LOCKED

SerapeumOS supports local human authentication without requiring an external identity provider.

The inherited Argon2id local-password model is an acceptable foundation.

### LOCKED

Human authentication method is replaceable.

Future supported methods may include host-native or external identity bindings, but:

- Company identity remains local;
- Human Principal identity remains local;
- external identity is only a binding;
- losing/changing an external identity must not redefine Company/Principal identity.

### LOCKED

Passwords are never stored reversibly.

Password hashes are verification material, not decryptable secrets.

---

## 8. Secret taxonomy

### LOCKED

SerapeumOS distinguishes at least these secret classes:

| Class | Examples | Normal exposure |
|---|---|---|
| **S-ROOT** | installation root/master secret | trusted key service only |
| **S-HUMAN-AUTH** | password verifier/recovery material | authentication service only |
| **S-SERVICE** | external API/OAuth credentials, plugin credentials | trusted secret broker/service |
| **S-RUNTIME** | Worker/appliance session credential, local service token | exact runtime/process only |
| **S-SIGNING** | token/signing/private keys | trusted signing service only |
| **S-RECOVERY** | backup/recovery encryption material | MA-13 recovery authority |
| **S-OPAQUE-REF** | non-secret identifier referencing a secret | safe for authorized metadata use |

Not all deployments need every class.

---

## 9. Root secret / key hierarchy

### LOCKED

SerapeumOS requires an installation-scoped root secret/key that is **not stored in plaintext inside the same database it protects**.

The root secret is used to derive purpose-bound encryption/signing keys rather than being reused directly for every secret.

Conceptually:

```text
Installation Root Secret
    ├── derive → configuration-encryption key
    ├── derive → provider-credential key
    ├── derive → Worker/runtime-secret key
    ├── derive → token/signing domain
    └── derive → future purpose-specific keys
```

### LOCKED

Derived keys must be context/purpose separated.

A ciphertext copied between unrelated rows/purposes must not decrypt as valid data.

This preserves the useful existing Ankole AEAD pattern.

---

## 10. Root-secret storage

### LOCKED

The root secret must be protected by the strongest practical local host mechanism available through a host adapter.

The architecture does not hard-code:

- Windows DPAPI;
- Linux kernel keyring;
- TPM;
- OS credential manager;
- file-based key store.

These are MA-17 implementation/qualification choices.

### LOCKED

If the host cannot securely obtain the root secret, protected services fail closed.

The product must not silently fall back to plaintext secret storage.

---

## 11. Database secret storage

### LOCKED

Long-lived reversible secrets stored in PostgreSQL/configuration must be encrypted at rest using purpose/context-bound authenticated encryption.

Database rows may contain:

- ciphertext;
- safe metadata;
- credential status;
- rotation/version information.

They must not expose plaintext through ordinary API/list/read operations.

### LOCKED

A database compromise without the host-protected root secret should not directly reveal protected plaintext secrets.

This is a defense-in-depth objective, not a claim that database compromise has no impact.

---

## 12. Secret metadata

### LOCKED

The trusted system may store non-secret metadata such as:

- secret/credential reference ID;
- type;
- owner/scope;
- provider/service;
- created time;
- last rotated time;
- expiry;
- status;
- safe label;
- last bounded failure;
- version/revision.

### LOCKED

Secret values themselves are never returned in list/read APIs after creation except where an explicit one-time human workflow is deliberately designed.

---

## 13. Opaque secret references

### LOCKED

Agents, Tasks, Skills, and configuration should refer to secrets through opaque references, not plaintext.

Conceptually:

```text
credential_ref: cred_123
```

not:

```text
api_key: sk-...
```

### LOCKED

An opaque reference grants no authority by itself.

The trusted secret broker still validates:

- Principal;
- Company;
- Task;
- capability;
- target service;
- operation;
- current credential state.

---

## 14. Secret broker

### LOCKED

A trusted Secret/Credential Broker mediates access to long-lived credentials.

Preferred execution order:

1. trusted broker performs the privileged authenticated operation itself;
2. if that is impractical, broker issues/injects the narrowest short-lived credential;
3. direct long-lived secret disclosure is exceptional and should be avoided.

### LOCKED

The broker is part of the TCB.

It must not become a generic “show me the secret” service for Agents.

---

## 15. Agent secret exposure

### LOCKED

Long-lived secrets must not be placed in:

- model prompts;
- Working Context;
- Agent Brain/memory;
- Task descriptions;
- Skill documents;
- ordinary `/agents` files;
- logs;
- receipts;
- generated artifacts.

### LOCKED

An Agent may know that a credential exists and may hold an opaque reference, without seeing the credential value.

---

## 16. Runtime secret injection

### LOCKED

When untrusted Agent-side execution genuinely requires credential material, injection must be:

- exact-purpose;
- exact-runtime;
- short-lived where possible;
- revocable;
- non-persistent;
- excluded from durable workspace;
- excluded from model-visible context where possible.

Preferred carriers are runtime-local protected channels/files/descriptors rather than broad inherited process environments.

### LOCKED

Environment variables may be used only as a bounded compatibility mechanism when the target tool requires them.

If used:

- scope them to the smallest process tree;
- avoid placing unrelated secrets in the same environment;
- prevent persistence into workspace/config;
- sanitize child-process propagation where practical.

---

## 17. Worker/appliance boundary authentication

### LOCKED

Every production Agent Appliance / Worker incarnation must authenticate to the trusted control plane using a credential that is:

- bound to that runtime incarnation;
- bound to the intended appliance/assignment;
- short-lived or bounded to runtime lifetime;
- revocable;
- replaced on runtime recreation;
- incapable of authenticating as another active appliance/Agent.

### LOCKED

Compromise of one Agent Appliance must not yield a credential that authenticates arbitrary other Workers/Agents.

---

## 18. Existing global WorkerAuthKey

### REPOSITORY FACT

Current Ankole uses one persisted global RuntimeFabric Worker authentication key shared by Workers.

### SUPERSEDED FOR FINAL SERAPEUMOS PRODUCTION

The shared global Worker authentication key may remain temporarily for foundation compatibility or controlled development/prototype work.

It is **not accepted as the final SerapeumOS hostile-appliance authentication architecture**.

Final production must move to per-runtime/incarnation bounded credentials under the MA-10 contract.

The exact transport/token/certificate mechanism is deferred to MA-17/MA-18 implementation design.

---

## 19. Runtime credential bootstrap

### LOCKED

Runtime credentials are introduced through a trusted bootstrap path.

Conceptually:

```text
Trusted Runtime Controller creates appliance
→ creates runtime incarnation
→ issues bounded bootstrap credential
→ injects credential through controlled channel
→ Worker authenticates
→ Control Plane validates current incarnation/assignment
→ runtime admitted
```

The Agent/model cannot mint or modify this credential.

---

## 20. Runtime credential destruction

### LOCKED

When an appliance/Worker is:

- stopped;
- replaced;
- reassigned;
- compromised;
- expired;

its runtime credential becomes unusable.

Reassignment from Agent A to B never reuses A's runtime credential.

---

## 21. Service credentials

### LOCKED

External service credentials are bound to their intended service/provider/account and Company/Principal policy context.

A credential for Service A must not be usable as generic network authority.

### LOCKED

Final SerapeumOS core operation must not require external service credentials.

External credentials exist only for optional user-enabled integrations/research or temporary development services such as NaraRouter.

---

## 22. NaraRouter credential rule

### LOCKED

NaraRouter credentials, while temporarily used during development/validation:

- remain outside repository content;
- remain outside prompts;
- remain outside Agent memory;
- remain outside committed environment/config files;
- are injected only through developer/runtime secret configuration;
- are removable without architectural change.

NaraRouter credential support must not become a permanent production requirement.

---

## 23. Model runtime credentials

### LOCKED

Final local inference should normally require no external API secret.

If a local runtime uses an authentication token for local IPC/API protection, that token is an S-RUNTIME credential:

- locally generated;
- bounded to that runtime/service;
- not model-visible;
- not Agent-authoritative;
- rotatable/revocable.

---

## 24. Tool / MCP / plugin credentials

### LOCKED

MA-08 extension credentials use MA-10 mediation.

A Skill or MCP declaration may state that a credential is required, but does not contain its secret value.

Trusted configuration binds:

```text
extension/tool
→ credential reference
```

The Secret Broker supplies only the allowed operation/runtime with necessary credential material.

---

## 25. Credential ownership and scope

### LOCKED

Every long-lived credential has an explicit ownership/scope model such as:

- installation;
- Company;
- human Principal;
- Agent Principal where justified;
- external integration/account.

No credential exists as an unscoped global secret merely because implementation is easier.

Installation-global credentials are reserved for true installation services.

---

## 26. Least exposure

### LOCKED

The architecture minimizes both:

- **authority scope**; and
- **plaintext exposure duration**.

Decrypted secrets should exist only:

- in trusted memory;
- during the operation requiring them;
- in the minimum process boundary necessary.

Persistent plaintext caches are prohibited.

---

## 27. Rotation

### LOCKED

Long-lived credentials and key material must support rotation.

Conceptual lifecycle:

```text
CREATED / IMPORTED
→ ACTIVE
→ ROTATING
→ REPLACED
→ REVOKED / RETIRED
```

### LOCKED

Rotation must not require changing Principal identity.

Where continuity is required, the system may support overlapping old/new credential versions for a bounded transition window.

Old versions then become unusable.

---

## 28. Root-key rotation

### LOCKED

The architecture must support root-key/version evolution without requiring loss of all encrypted state.

A future implementation may use:

- wrapped data keys;
- versioned derived-key roots;
- staged re-encryption;
- another qualified approach.

The exact mechanism is deferred.

### LOCKED

Root-key rotation is a trusted maintenance/recovery operation, never an Agent action.

---

## 29. Revocation

### LOCKED

Credential revocation must be independent of Agent cooperation.

Revocation may follow:

- suspected compromise;
- Principal disablement;
- Company suspension;
- external-account removal;
- Task cancellation where Task-scoped;
- runtime destruction;
- Owner request;
- credential expiry;
- provider/service invalidation.

### LOCKED

Revoked credentials cannot silently remain active through stale runtime caches indefinitely.

Exact propagation mechanics belong to MA-12/MA-17.

---

## 30. Expiry

### LOCKED

Runtime/delegated credentials should expire automatically.

Long-lived external credentials may lack upstream expiry but still carry local lifecycle/review state.

Expired credentials fail closed.

---

## 31. Authentication tokens

### LOCKED

Authentication/session/access tokens are credentials.

They must be:

- audience/purpose bound;
- integrity protected;
- time bounded where practical;
- revocable or short-lived;
- validated against current Principal/runtime state.

A token cannot outlive the security context that authorized it.

---

## 32. Signing keys

### LOCKED

Signing/private keys are S-SIGNING secrets.

Untrusted Agents never receive private signing keys.

Agents may request a governed signing operation through a trusted service if MA-06 permits it.

Public keys/certificates are not secrets and may be broadly distributed.

---

## 33. Redaction

### LOCKED

SerapeumOS performs structured secret prevention/redaction at trust boundaries.

Redaction is defense in depth, not the primary secret-control mechanism.

The preferred control is **do not disclose the secret in the first place**.

### LOCKED

Known runtime/credential values must be removed from:

- model-visible output;
- external provider payloads;
- logs;
- crash reports;
- audit views;
- exported diagnostics

where those surfaces do not require the value.

---

## 34. Secret scanning limitations

### LOCKED

Pattern-based scanning cannot prove that output contains no secrets.

Therefore SerapeumOS does not rely solely on:

- regex;
- entropy detection;
- “looks like a token” heuristics.

Exact-value/redaction registries and structural non-disclosure remain primary where possible.

---

## 35. Logging and observability

### LOCKED

Logs/audit records use:

- secret references;
- safe labels;
- credential IDs/revisions;
- redacted errors.

They do not log plaintext secret values.

Upstream/provider error bodies must be bounded and sanitized before durable logging/display.

MA-14 owns telemetry retention.

---

## 36. Crash/core-dump handling

### LOCKED

Secret-bearing trusted processes should avoid uncontrolled memory/core dumps where the supported host allows this to be configured safely.

Crash reports must not intentionally serialize secret-bearing process state.

Host-specific controls belong to MA-17.

---

## 37. Backups

### LOCKED

Encrypted database backups may contain encrypted secret ciphertext.

Recovery of those secrets requires the associated protected recovery/root-key material.

Backup and root-key recovery must be designed together.

MA-13 owns the concrete backup/recovery contract.

### LOCKED

A backup that contains a plaintext root secret alongside the encrypted database defeats the security boundary and is prohibited.

---

## 38. Secret loss

### LOCKED

If a non-recoverable secret is lost:

- the system must identify affected capabilities/integrations;
- mark them unavailable;
- require credential replacement/re-authentication;
- not fabricate/reconstruct secret values.

Loss of optional external credentials must not prevent core local Company state from being read/recovered where unrelated.

Root-secret loss is a MA-13 disaster-recovery condition.

---

## 39. Suspected compromise

### LOCKED

On suspected credential compromise, the trusted system supports:

```text
disable/revoke credential
→ stop affected runtime/action
→ rotate/re-authenticate
→ invalidate derived/session authority
→ record security event
→ evaluate affected actions/receipts
```

The system must not merely “hide” the secret from UI and continue using it.

---

## 40. Repository and development secrets

### LOCKED

Secrets must never be committed to the SerapeumOS repository.

This includes:

- API keys;
- passwords;
- private keys;
- bearer tokens;
- refresh tokens;
- generated runtime credentials;
- recovery codes.

### LOCKED

Development configuration uses ignored/local secret mechanisms.

Sample `.env`/configuration files may contain only placeholders/non-secret examples.

---

## 41. User-visible secret UX principle

### LOCKED

Where the Owner enters a credential:

- explain why it is needed;
- show intended scope/integration;
- do not redisplay plaintext after storage;
- allow replace/revoke/delete;
- show safe status metadata.

Detailed UX belongs to MA-16.

---

## 42. Break-glass credentials

### LOCKED

If MA-13 introduces break-glass recovery material, it is:

- human-controlled;
- exceptional;
- offline-capable where appropriate;
- not accessible to Agents;
- strongly audited when used.

It does not grant a permanent hidden administrator identity.

---

## 43. System Principals

### LOCKED

System Principals are durable attributable service subjects, not secret containers.

A trusted service may use a System Principal for audit/AuthZ attribution while its authentication key remains separately managed.

### LOCKED

Creating a System Principal does not automatically create credentials or permissions.

---

## 44. Agent Principals

### LOCKED

Agent Principals do not possess human-login credentials.

Their execution authority derives from:

- trusted Agent identity;
- current Company/Task assignment;
- MA-06 authorization/capabilities;
- authenticated runtime binding.

The runtime credential authenticates the Worker/appliance, not the Agent's organizational identity itself.

---

## 45. External identity bindings

### LOCKED

External identities are mappings to local Human Principals.

They are not Company identity and do not become authorization grants by themselves.

External provider tokens/credentials are stored separately from identity mapping records.

---

## 46. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| permissions/capabilities | MA-06 |
| model-provider credentials | MA-07 + MA-10 |
| tool/MCP/plugin credential use | MA-08 + MA-10 |
| physical encrypted storage | MA-09 / MA-17 |
| resource limits | MA-11 |
| token/cache/revocation recovery | MA-12 |
| root-secret backup/recovery | MA-13 |
| audit/redaction retention | MA-14 |
| credential UX | MA-16 |
| OS keystore/root-key mechanism | MA-17 |
| install/bootstrap/key creation | MA-18 |
| signing/supply-chain keys | MA-19 |
| penetration/adversarial tests | MA-20 |

These deferrals do not block MA-10 closure.

---

## 47. Veto conditions

An MA-10 implementation is invalid if it:

- equates Principal identity with credential value;
- creates a second competing Principal identity system;
- stores reversible long-lived secrets in plaintext;
- stores the root secret in plaintext beside the protected database;
- silently falls back to plaintext when secure root-key retrieval fails;
- returns stored secret plaintext through ordinary read APIs;
- places long-lived secrets in prompts, Agent memory, Skills, workspaces, logs, or receipts;
- exposes one compromised Agent Appliance credential as authority to impersonate other Workers/Agents;
- uses the current global shared WorkerAuthKey as final production hostile-appliance authentication;
- gives Agents private signing keys;
- treats external identity binding as authorization;
- relies only on regex/heuristic secret scanning;
- commits secrets to the repository;
- makes external credentials required for core local SerapeumOS operation.

---

## 48. MA-10 closure decision

### CLOSED

MA-10 is architecture-complete.

Locked:

- Ankole human/agent/system Principals retained;
- durable Principal identity separated from authentication credentials;
- ephemeral runtime identities separated from durable Principals;
- explicit secret taxonomy;
- installation root secret with purpose/context-derived keys;
- host-protected root-secret storage;
- encrypted-at-rest long-lived secrets;
- opaque secret references;
- trusted Secret/Credential Broker;
- least exposure and short-lived injection;
- per-runtime/incarnation Worker/appliance credentials;
- current global WorkerAuthKey superseded for final production;
- rotation/revocation/expiry;
- signing-key isolation;
- structural non-disclosure and redaction;
- repository secret prohibition;
- local-core operation independent of external credentials.

No material MA-10 architecture question remains inside this domain.

---

## 49. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-101 — Principal identity is separate from credentials
Human, Agent, and System Principal identities remain stable when passwords, tokens, runtime credentials, or external identity bindings change.

### D-102 — Durable Principal classes remain human / agent / system
Transient Workers, appliances, models and tools use runtime identities rather than new durable Principal types.

### D-103 — SerapeumOS uses a host-protected installation root secret
Long-lived reversible secrets are protected through purpose/context-derived keys rooted in local host-protected key material.

### D-104 — Secret plaintext is never ordinary Agent state
Long-lived secrets are excluded from prompts, memory, Skills, workspaces, logs, receipts and general artifacts; Agents use opaque references and trusted mediation.

### D-105 — Secret access is broker-mediated
Trusted services perform credentialed actions where possible; direct secret injection is minimized, scoped, temporary and non-persistent.

### D-106 — Worker/appliance credentials are per runtime incarnation
Final production runtime authentication uses bounded revocable credentials tied to a specific Worker/appliance incarnation and assignment.

### D-107 — Global shared WorkerAuthKey is not final production architecture
The inherited Ankole global Worker authentication key may support compatibility/development but is superseded by the MA-10 per-runtime credential contract for production.

### D-108 — Credentials support rotation and revocation
Credential replacement does not change Principal identity, and revocation is independent of Agent cooperation.

### D-109 — Private signing keys remain trusted-only
Agents may request governed signing operations but never receive private signing keys directly.

### D-110 — Core local operation requires no external credentials
External service credentials are optional integration/development state and cannot become required for final SerapeumOS core operation.

---

## 50. Project-state transition

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

Current architecture domain:
MA-11 — Resource Governance

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-11-CLOSE — architecture only
```

---

## 51. Next action

**MA-11-CLOSE — Resource Governance**

Architecture only.
