# SerapeumOS — Prerequisites

This document describes the durable prerequisite contracts for SerapeumOS.
It distinguishes product prerequisites (required of every supported host),
development prerequisites (tools needed to build and qualify), and candidate
dependencies (technologies under architectural consideration but not yet
selected or qualified).

No numeric minimums, installed-tool inventories, or machine-specific facts
belong here. Those values are determined by the applicable MA-20 Qualification
Policy and qualified release profile.

## Product prerequisites

Capabilities that a supported host must provide, independent of implementation.
Defined by MA-01, MA-17, and MA-20.

### Compute and virtualization

| Requirement | Notes |
|---|---|
| CPU with hardware virtualization support | Architecture-neutral; exact host families and minima determined by MA-20 Qualification Policy |
| Hypervisor feature (WHP/KVM/Hyper-V or equivalent) | Enables VM-based Agent Appliance acceleration |
| Sufficient physical RAM for guest + host safety reserve | Exact minimum determined by MA-20 Qualification Policy |
| Sufficient logical processors for guest allocation | Exact minimum determined by MA-20 Qualification Policy |

### Storage

| Requirement | Notes |
|---|---|
| Local fixed storage with appropriate semantics | NTFS (Windows 11 x86-64) and ext4/XFS (Linux x86-64) as initial qualification families; exact filesystem requirements per MA-17 |
| Capacity for immutable appliance image + persistent `/agents` disk | Exact sizes determined by MA-20 Qualification Policy |
| Atomic rename and durability guarantees | Required by MA-13 backup/restore and MA-17 storage contract |

### Network

| Requirement | Notes |
|---|---|
| Ability to deny network by default | MA-01 contract; default-deny networking |
| Optional controlled egress for research/updates | Governed by MA-08 external research controls; not required |

### Security

| Requirement | Notes |
|---|---|
| Host-level isolation boundary (VM or equivalent) | One hard Agent boundary per Agent Principal at a time (MA-01) |
| Protected root-secret storage | Required capability; missing controls disable production mode (MA-17) |
| Physical encrypted-at-rest for managed storage | Where policy requires it (MA-17, D-194) |

### Local inference

| Requirement | Notes |
|---|---|
| Local inference runtime capable of replacing temporary development inference | Must not require redesign of Company/Agents/Brain/Tasks/Governance/Evolution/ActionAssurance (D-073) |
| Temporary development inference tool permitted during build/validation only | Must remain replaceable by design (D-074) |

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
| Trivy (SBOM/security) | Architecture candidates | Architectural selection only |
| OSV-Scanner (vuln intelligence) | Architecture candidates | Architectural selection only |
| iron-proxy (egress control) | Architecture candidates | Architectural selection only |
| OpenTelemetry (telemetry) | Architecture candidates | Architectural selection only |
| age (local encryption) | Architecture candidates | Architectural selection only |

No candidate becomes a permanent prerequisite merely because it appeared in an
experiment or proposal.
