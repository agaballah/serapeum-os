# MA-08 — Tools / Skills / Plugins / MCP / External Research

**Status:** CLOSED — ARCHITECTURE LOCKED  
**Phase:** Final Master Architecture / Design Gate  
**Implementation:** NOT STARTED

---

## 1. Purpose

MA-08 defines how SerapeumOS extends Agent capability through:

- built-in tools;
- Skills;
- plugins/adapters;
- MCP servers/tools;
- browser/computer use;
- external research;
- extension installation, enablement, and removal.

The governing principle is:

> **Extensions may expand what an Agent can attempt, but they never expand what the Agent is authorized to do.**

Authority remains governed by MA-06.

---

## 2. Existing Ankole foundation

### REPOSITORY FACT

Ankole already provides:

- built-in Agent Computer tools;
- Skills with runtime loading and path-boundary checks;
- Skill-declared MCP dependencies;
- MCP stdio and streamable-HTTP configuration;
- tool allow/deny filters;
- plugin discovery/validation/registry;
- plugin adapter contracts;
- browser runtime and sandbox;
- browser navigation policy and SSRF protection;
- web/search/fetch capability paths;
- controlled background jobs/workflows.

### LOCKED

SerapeumOS reuses these extension mechanisms where their contracts fit.

It does not create a second generic plugin, Skill, MCP, or tool framework without a proven gap.

---

## 3. Extension classes

### LOCKED

SerapeumOS distinguishes:

| Class | Meaning |
|---|---|
| **Built-in Tool** | SerapeumOS/Ankole-shipped callable capability |
| **Skill** | Agent-usable instructions/resources/tool dependencies |
| **Plugin** | Trusted extension package that can register adapters/services/configuration |
| **MCP Server** | Tool/resource provider accessed through the MCP protocol |
| **Browser/Computer Runtime** | Interactive hostile execution surface |
| **External Research Source** | Network-accessed information source |

These classes have different trust and lifecycle semantics.

They must not be treated as equivalent simply because they are all “tools.”

---

## 4. Tool authority

### LOCKED

A tool declaration describes an available operation.

It does **not** grant permission to invoke that operation.

Canonical flow:

```text
Model / Agent proposes tool
        ↓
Tool is registered and enabled
        ↓
Task/profile permits tool class
        ↓
MA-06 AuthZ
        ↓
Capability validation
        ↓
Action Assurance where required
        ↓
Tool/broker executes
        ↓
Result / receipt
```

### LOCKED

No extension may bypass MA-06 by calling a privileged subsystem directly.

---

## 5. Tool registry

### LOCKED

The trusted system maintains the authoritative registry of callable tools.

Each callable tool must have stable metadata equivalent to:

- tool identity;
- extension/source identity;
- version/revision where applicable;
- input contract;
- output contract;
- risk class/default risk posture;
- resource classes touched;
- network requirements;
- secret requirements;
- side-effect classification;
- trust class;
- qualification/enabled state.

Exact schema belongs to MA-09.

---

## 6. Trust classes

### LOCKED

Extensions are treated according to execution location and authority.

Conceptually:

### Trusted extension

Runs inside or extends trusted control-plane code.

Examples: approved SerapeumOS/Ankole plugin adapters.

Requirements:

- strict review;
- supply-chain qualification;
- explicit registration;
- no silent authority expansion.

### Untrusted Agent extension

Runs inside the Agent Appliance.

Examples:

- Skills;
- MCP stdio servers;
- downloaded code/tools;
- browser automation.

It remains inside the hostile Agent boundary.

### External service

Runs outside SerapeumOS.

Examples:

- remote MCP;
- external website/API.

It is treated as external/untrusted and cannot become a required final-system dependency unless explicitly permitted by the Constitution.

---

## 7. Installation ≠ enablement ≠ authorization

### LOCKED

These are separate states:

```text
AVAILABLE
→ INSTALLED
→ ENABLED
→ QUALIFIED FOR USE
→ INVOKED UNDER AUTHORITY
```

An installed extension is not automatically enabled.

An enabled extension is not automatically available to every Agent.

An Agent being allowed to see a tool does not mean it is authorized to execute every operation.

### LOCKED

SerapeumOS must not rely on “all discovered plugins enabled automatically” as final product doctrine.

Foundation first-run behavior may exist, but SerapeumOS final enablement policy is explicit and governed.

---

## 8. Skills

### LOCKED

A Skill is primarily:

- instructions;
- domain procedure;
- reference material;
- optional declared tool/MCP dependencies.

A Skill is **not** a security principal and does not grant authority.

### LOCKED

Skills may be:

- shipped;
- Company-managed;
- Agent-installed where policy permits.

Each Skill remains bound to one Agent/Company scope where applicable.

### LOCKED

Skill content is untrusted input to the Agent reasoning process unless it is part of trusted SerapeumOS governance documentation.

A malicious Skill must not be able to escape the Agent hard boundary.

---

## 9. Skill dependencies

### LOCKED

Skill-declared dependencies must be explicit and machine-readable.

A Skill cannot silently:

- install arbitrary host software;
- open unrestricted network access;
- request secrets without declaration;
- create undeclared MCP servers;
- execute host commands outside its assigned boundary.

Dependency resolution must fail closed when declarations conflict or exceed policy.

---

## 10. Plugins

### LOCKED

Plugins extend trusted SerapeumOS/Ankole subsystems through explicit contracts.

The current Ankole model of:

```text
plugin
→ validated spec
→ adapter declaration
→ subsystem contract
```

is retained.

### LOCKED

A plugin may not replace core authority layers such as:

- Principal identity authority;
- AuthZ;
- Action Assurance;
- authoritative Company state ownership;
- audit authority;
- capability issuance.

It may provide an adapter behind those authorities.

---

## 11. Plugin lifecycle

### LOCKED

Conceptual plugin lifecycle:

```text
DISCOVERED
→ VALIDATED
→ INSTALLED
→ ENABLED
→ ACTIVE
→ DISABLED / REMOVED
```

Activation must fail closed if:

- identity is invalid;
- adapter contract conflicts;
- required configuration is invalid;
- dependency/supply-chain qualification fails.

### LOCKED

Plugin updates are treated as new executable code and require MA-19/MA-20 qualification before promotion.

---

## 12. MCP

### LOCKED

MCP is a protocol integration mechanism, not an authority model.

An MCP server may expose:

- tools;
- resources;
- prompts/metadata.

SerapeumOS must still govern each callable operation.

### LOCKED

MCP servers may run:

- inside the Agent Appliance via stdio;
- through an explicitly governed network path.

Remote MCP is optional external egress, never a mandatory final-system dependency.

---

## 13. MCP tool filtering

### LOCKED

MCP registration must support explicit tool allow/deny filtering.

A server exposing more tools than expected does not automatically make them available.

### LOCKED

MCP server identity/configuration conflicts fail closed.

Tool exposure must be attributable to the Skill/plugin/configuration that enabled it.

---

## 14. MCP stdio execution

### LOCKED

MCP stdio servers are untrusted Agent-side processes unless explicitly promoted to a trusted SerapeumOS component.

They run inside the Agent hard boundary.

They do not receive ambient host access.

The Agent cannot use MCP stdio as a disguised host-shell escape.

---

## 15. Remote MCP

### LOCKED

Remote MCP requires explicit network authorization.

It is subject to:

- endpoint allow policy;
- MA-06 authorization;
- MA-10 secret mediation;
- MA-14 audit;
- MA-19 trust/supply-chain policy where code/configuration is installed.

### LOCKED

Remote MCP credentials are not stored in Skills or prompts.

Credential injection is mediated.

---

## 16. Browser runtime

### LOCKED

Browser execution is hostile/untrusted workload.

It remains inside the assigned Agent boundary or another equally qualified isolation boundary.

### LOCKED

The browser does not run as an ambient trusted desktop process simply for convenience.

### LOCKED

Browser navigation is governed by network policy and SSRF protections.

Requests to metadata/private/local infrastructure must remain blocked unless a separately governed local-resource exception exists.

---

## 17. Computer-use runtime

### LOCKED

General UI/computer interaction is treated as a high-capability tool class.

It may interact only with resources explicitly exposed to its sandbox.

It does not receive automatic access to:

- the Owner desktop;
- arbitrary local applications;
- arbitrary host filesystem;
- credential managers;
- clipboard;
- devices.

Any host-side UI automation requires a separately qualified broker and MA-06 action controls.

---

## 18. External research

### LOCKED

External research is an optional, explicit network capability.

SerapeumOS itself remains fully local even when an Agent is temporarily authorized to research public Internet sources.

### LOCKED

External research does not mean:

- cloud control plane;
- cloud memory;
- cloud inference;
- mandatory hosted service.

It means only controlled egress to approved information sources when a Task requires it.

---

## 19. Research workflow

### LOCKED

Canonical external research flow:

```text
Task requires external evidence
        ↓
Network/research capability authorized
        ↓
Search / browse / fetch
        ↓
Source material captured
        ↓
MA-05 evidence/provenance processing
        ↓
Claims / synthesis
```

### LOCKED

Search snippets, model summaries, or provider-hosted search results are not automatically factual truth.

MA-05 provenance rules still apply.

---

## 20. Source provenance

### LOCKED

Research results must preserve enough information to identify:

- source/URL/resource;
- retrieval timestamp;
- source revision/date where available;
- retrieval mechanism;
- Agent/Task;
- relevant excerpt/artifact reference.

A summary without source lineage cannot become high-confidence external knowledge.

---

## 21. Network posture

### LOCKED

Agent network remains deny-by-default.

Network authority is granted by:

- Task;
- purpose;
- endpoint/category;
- duration;
- protocol/operation where practical.

### LOCKED

Enabling a browser, MCP server, plugin, or Skill does not automatically grant Internet/LAN access.

---

## 22. LAN and host-service protection

### LOCKED

External research/tool egress must not provide a route into:

- host management endpoints;
- metadata services;
- local credential endpoints;
- database ports;
- model administration ports;
- control-plane privileged interfaces;
- peer Agent Appliances.

Access to local services requires explicit internal contracts, not generic web/network permission.

---

## 23. Secrets

### LOCKED

Tool/plugin/MCP/browser credentials are mediated by trusted secret services.

Extensions receive the narrowest practical credential or opaque broker access.

Secrets must not be embedded in:

- Skill documents;
- prompts;
- plugin descriptions;
- MCP tool schemas;
- ordinary Agent memory.

Detailed secret architecture belongs to MA-10.

---

## 24. Side-effect classification

### LOCKED

Tools are classified at operation level, not merely tool name.

A single tool may have:

```text
read
create
modify
delete
publish
send
execute
administer
```

operations with different MA-06 risk classes.

### LOCKED

A “tool allowed” flag cannot mean unrestricted permission to every operation the tool offers.

---

## 25. Provider-hosted model tools

### LOCKED

Model-provider-native capabilities such as web search or image generation are not trusted merely because the model provider exposes them.

If used, they must fit the same:

- Task permission;
- provenance;
- external-action;
- audit

contracts.

### LOCKED

Provider-hosted side-effectful tools cannot bypass SerapeumOS Action Assurance.

For final local-only inference, SerapeumOS should prefer locally mediated tool execution where practical.

---

## 26. Extension-created code

### LOCKED

Generated or extension-supplied code executes as untrusted code.

It must stay within the Agent hard boundary or another explicitly qualified execution environment.

A Skill/plugin description cannot elevate generated code into trusted execution.

---

## 27. Dynamic installation by Agents

### LOCKED

An Agent may propose installation of a new Skill/tool/plugin/MCP dependency.

It may not silently install trusted code or expand its own capability surface.

Conceptual flow:

```text
Agent identifies need
→ proposes extension
→ source/license/security metadata collected
→ policy / approval
→ installation
→ qualification
→ enablement
```

Trusted plugin installation is higher risk than Agent-local Skill installation.

---

## 28. Open-source rule

### LOCKED

SerapeumOS-owned, required, distributed, or managed production extensions above the host boundary must comply with the Owner's OSS/local doctrine.

A proprietary remote service may not become a required SerapeumOS capability.

Optional user-chosen external endpoints must remain replaceable and non-architectural.

Supply-chain/license enforcement belongs to MA-19.

---

## 29. Extension state and provenance

### LOCKED

The system must be able to answer:

- what extension is installed;
- version/digest;
- source;
- who enabled it;
- which Company/Agent can use it;
- what tools it exposes;
- what network/secrets it requires;
- qualification status;
- last relevant failure/change.

Exact storage belongs to MA-09/MA-14/MA-19.

---

## 30. Tool result handling

### LOCKED

Tool results are untrusted inputs unless they are trusted system observations.

They must be:

- bounded/sanitized where required;
- attributed to the tool/source;
- fed through MA-05 provenance rules before becoming durable knowledge.

Large or malformed tool output must not destabilize the model/runtime.

---

## 31. Failure behavior

### LOCKED

Tool/extension failure must remain bounded.

Failure may:

- fail the operation;
- return structured error;
- pause/wait the Task;
- trigger an approved fallback.

It must not:

- expand network scope;
- bypass authorization;
- retry through a more privileged tool automatically;
- silently replace evidence with fabricated output.

---

## 32. Removal / disablement

### LOCKED

Disabling/removing an extension blocks new use but preserves historical references needed to understand past execution.

Historical Task/receipt evidence must remain attributable to the original extension/version.

Removing a plugin/Skill must not rewrite history.

---

## 33. Boundaries to later domains

| Concern | Owning domain |
|---|---|
| permissions/capabilities/approvals | MA-06 |
| model-native tool routing | MA-07 |
| extension/tool registry storage | MA-09 |
| credentials/secrets | MA-10 |
| CPU/RAM/network quotas | MA-11 |
| retry/recovery | MA-12 |
| audit/privacy | MA-14 |
| self-improving Skill/tool proposals | MA-15 |
| install/permission UX | MA-16 |
| host compatibility | MA-17 |
| package install/update | MA-18 |
| OSS/license/SBOM/signing | MA-19 |
| adversarial qualification | MA-20 |

These deferrals do not block MA-08 closure.

---

## 34. Veto conditions

An MA-08 implementation is invalid if it:

- treats tool availability as permission;
- enables all discovered extensions by default as final doctrine;
- lets a Skill/plugin/MCP server expand its own authority;
- runs untrusted extension code in the trusted host/control plane without qualification;
- gives MCP stdio ambient host shell/filesystem authority;
- gives browser/computer use unrestricted host access;
- grants network automatically when a tool is enabled;
- allows generic Internet permission to reach protected LAN/host control services;
- embeds secrets in Skills/prompts/tool schemas;
- lets provider-hosted tools bypass Action Assurance;
- treats research output as factual truth without provenance;
- lets Agent-installed trusted plugins bypass approval/qualification;
- makes a proprietary external service a required final-system dependency.

---

## 35. MA-08 closure decision

### CLOSED

MA-08 is architecture-complete.

Locked:

- tool availability separate from authority;
- explicit extension classes/trust levels;
- reuse of Ankole Skills/plugins/MCP/browser foundations;
- install/enable/qualify/invoke separation;
- Skills as non-authoritative Agent extensions;
- plugins as explicit trusted adapter contracts;
- MCP as protocol, not authority;
- MCP stdio inside hostile Agent boundary;
- governed remote MCP;
- browser/computer use as hostile high-capability execution;
- optional controlled external research;
- deny-by-default network;
- source provenance;
- secret mediation;
- operation-level risk classification;
- historical extension provenance;
- OSS/local final-product rule.

No material MA-08 architecture question remains inside this domain.

---

## 36. Decisions to persist

When repository persistence is available, record decisions equivalent to:

### D-081 — Tool availability does not grant authority
A registered/enabled tool still requires Task policy, AuthZ, Capability validation, and Action Assurance where applicable.

### D-082 — Extension lifecycle is explicit
Available, installed, enabled, qualified, and invoked are separate states.

### D-083 — Skills are untrusted capability guidance
Skills may provide instructions/resources/dependencies but do not grant authority and run within Agent security boundaries.

### D-084 — Plugins extend trusted subsystems only through contracts
Plugins may register adapters/services but cannot replace Principal, AuthZ, Action Assurance, Company truth, or audit authority.

### D-085 — MCP is not an authority boundary
MCP exposes operations; SerapeumOS still governs every operation. Stdio MCP remains inside the hostile Agent boundary.

### D-086 — Browser/computer use remains hostile execution
Browser and UI automation cannot receive ambient host access and remain constrained by isolation, SSRF, network, and Action Assurance policy.

### D-087 — External research is optional governed egress
Internet research is Task-scoped optional egress, not a cloud dependency; retrieved material enters MA-05 as sourced evidence.

### D-088 — Network remains deny-by-default per capability
Tool/Skill/plugin enablement does not itself create network authority.

### D-089 — Extension secrets are broker-mediated
Credentials are not embedded in Skill content, prompts, schemas, or Agent memory.

### D-090 — Required production extensions obey OSS/local doctrine
No proprietary external service may become a required SerapeumOS production capability.

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
MA-08 — CLOSED

Current architecture domain:
MA-09 — Storage / Database / Artifact Store / User-File Publication

Implementation:
NOT STARTED

Runtime prototypes:
PAUSED

Next action:
MA-09-CLOSE — architecture only
```

---

## 38. Next action

**MA-09-CLOSE — Storage / Database / Artifact Store / User-File Publication**

Architecture only.
