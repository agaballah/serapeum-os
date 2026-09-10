# SerapeumOS — Prerequisites

This document describes the durable prerequisite contracts for SerapeumOS.
It distinguishes product prerequisites (mode-aware capability requirements),
development prerequisites (tools needed to build and qualify), and candidate
dependencies (technologies under architectural consideration but not yet
selected or qualified).

No numeric minimums, installed-tool inventories, or machine-specific facts
belong here. Those values are determined by the applicable MA-20 Qualification
Policy and qualified release profile.

## Operating modes

MA-17 defines the operating modes that apply when required capabilities are
present, degraded, or absent:

| Mode | Meaning |
|---|---|
| `FULL_LOCAL_AUTONOMY` | Complete hard-Agent isolation, resource, storage, and security capability set is present and qualified |
| `TRUSTED_CORE_ONLY` | Hostile-Agent hard outer boundary is unavailable or unqualified; trusted core may operate with reduced scope |
| `RECOVERY_ONLY` | Still narrower permitted operation, typically limited to durable-state recovery and audit |
| `UNSUPPORTED` | Required baseline capabilities for trusted durable operation are absent or unknown |

A missing capability does not imply weakened security. It implies a degraded
or disabled operating mode per MA-17.

## Product prerequisites

Capabilities that a supported host must provide for trusted durable operation,
and additional capabilities required for fuller autonomy modes.

### Baseline trusted-durable-operation requirements

These capabilities are required for any mode that processes durable state,
authoritative actions, or Owner-facing operations:

| Capability | Notes |
|---|---|
| Host-level isolation boundary (VM or equivalent) | One hard Agent Appliance boundary per Agent Principal at a time (MA-01). This is a security/isolation requirement, not merely VM acceleration. |
| Protected root-secret storage | Required capability; missing controls disable production mode (MA-17) |
| Physical encrypted-at-rest for managed storage | Where policy requires it (MA-17, D-194) |
| Atomic rename and durability guarantees | Required by MA-13 backup/restore and MA-17 storage contract |
| Ability to deny network by default | MA-01 contract; default-deny networking |
| Local inference runtime capable of replacing temporary development inference | Must not require redesign of Company/Agents/Brain/Tasks/Governance/Evolution/ActionAssurance (D-073) |

### Additional `FULL_LOCAL_AUTONOMY` requirements

When the host can provide the full capability set, these additional requirements
apply:

| Capability | Notes |
|---|---|
| CPU with hardware virtualization support | Architecture-neutral; exact host families and minima determined by MA-20 Qualification Policy |
| Qualified hypervisor backend (WHP/KVM/Hyper-V or equivalent) | Enables VM-based Agent Appliance isolation per MA-01/MA-17 |
| Sufficient physical RAM for guest + host safety reserve | Exact minimum determined by MA-20 Qualification Policy |
| Sufficient logical processors for guest allocation | Exact minimum determined by MA-20 Qualification Policy |
| Capacity for immutable appliance image + persistent `/agents` disk | Exact sizes determined by MA-20 Qualification Policy |
| Temporary development inference tool permitted during build/validation only | Must remain replaceable by design (D-074) |

### Degraded-mode behavior

| Missing capability | Resulting mode |
|---|---|
| No qualified hypervisor / hard Agent Appliance boundary | `TRUSTED_CORE_ONLY` or `UNSUPPORTED` per MA-17 |
| No protected root-secret storage | `UNSUPPORTED` for production mode |
| No local inference runtime | `RECOVERY_ONLY` or `UNSUPPORTED` depending on remaining capabilities |
| Network cannot be denied by default | `UNSUPPORTED` for production mode |

## Development prerequisites

Tools needed only to build, test, and qualify SerapeumOS. Installed only when
an approved task proves they are required. No specific versions are locked here;
the applicable MA-20 Qualification Policy determines required tool versions.

| Tool | Purpose |
|---|---|
| Git | Version control |
| GitHub CLI (`gh`) | Repository management |
| VS Code or equivalent editor | Source editing / task execution |
| Bun | Ankole Worker runtime |
| Go toolchain | Candidate appliance-builder tooling (if selected) |
| QEMU | Candidate WHPX prototyping backend |
| Docker CLI + Compose | Candidate Worker OCI image build |
| Rust / cargo | Kernel native binding build |
| Elixir / Erlang/OTP | Ankole control-plane build |
| Make or equivalent | Build orchestration |

No tool is installed merely because a candidate architecture mentions it.
Toolchains are installed only when an approved implementation or qualification
task proves they are required.

## Candidate dependencies

Technologies under architectural consideration. These are NOT prerequisites
until explicitly selected and qualified through the appropriate MA gate.

| Candidate | Selecting MA | Status |
|---|---|---|
| LinuxKit (appliance builder) | MA-01 / MA-17 | PROPOSED — F-W1A INCONCLUSIVE |
| QEMU/WHPX (VMM backend) | MA-01 | PROPOSED — WHPX recognized by binary; empirical boot proof PENDING |
| Hyper-V (alternative VMM) | MA-01 | CONDITIONAL / REFERENCE |
| Firecracker / Cloud Hypervisor | MA-01 | NOT SELECTED — backend-neutrality assessment INCONCLUSIVE |
| OpenTelemetry (telemetry) | MA-14 | Inherited/optional capability — not an architecture-selected dependency unless MA-14 explicitly locks it |

No candidate becomes a permanent prerequisite merely because it appeared in an
experiment or proposal.
