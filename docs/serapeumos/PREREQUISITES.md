# SerapeumOS — Prerequisites

This document distinguishes three categories of prerequisites. Only the first
two are authoritative for project state; the third is filled in as each
relevant MA domain closes.

## Product prerequisites

Capabilities that a supported host must provide, independent of implementation.
These are defined by MA-01, MA-17, and MA-20.

### Compute

| Requirement | Notes |
|---|---|
| x86_64 or arm64 CPU | Host-platform neutral above adapter layer |
| Hardware virtualization support (VT-x / AMD-V / HV) | Required for VM-based Agent Appliance |
| HypervisorPlatform or equivalent WHP/KVM/Hyper-V feature | Enables WHPX or KVM acceleration |
| Minimum 16 GiB physical RAM | Prototype target; production may differ |
| Minimum 2 logical processors available to guest | 2 vCPU minimum for Worker Appliance prototype |

### Storage

| Requirement | Notes |
|---|---|
| ~20 GiB free for QEMU + LinuxKit artifacts (prototype) | Production image size TBD after MA-18 |
| NTFS or ext4/xfs (host-dependent) | Path/case/locking semantics per MA-17 |
| Persistent writable disk for `/agents` workspace | Separate from immutable appliance image |

### Virtualization

| Requirement | Notes |
|---|---|
| Windows 11 Pro or equivalent supported host OS family | First qualification target; not yet empirically qualified |
| WSL2 runtime (for Docker Desktop / dev workflow) | Not the production Agent boundary |
| Docker CLI reachable (for Worker OCI build/pull) | Used during build; not required at Appliance runtime |

### Local inference

| Requirement | Notes |
|---|---|
| Local inference runtime capable of replacing NaraRouter | Must not require redesign of Company/Agents/Brain/Tasks/Governance/Evolution/ActionAssurance |
| NaraRouter permitted temporarily during development only | Temporary token allowance; replaceable by design |

### Filesystem

| Requirement | Notes |
|---|---|
| Case-preserving filesystem | Windows NTFS preserves case; Linux ext4/xfs are case-sensitive |
| No file-locking conflicts for concurrent Agent workspaces | MA-17 defines contract |
| Atomic rename support | Required for backup/restore integrity (MA-13) |

### Security

| Requirement | Notes |
|---|---|
| Host-level isolation boundary (VM or equivalent) | One hard Agent boundary per Agent Principal at a time |
| Ability to deny network by default | Default-deny networking contract (MA-01) |
| Ability to restrict GPU exposure | No direct GPU passthrough by default |
| TPM or equivalent attestation (recommended) | Supports trusted boot path per MA-01 |

## Development prerequisites

Tools needed only to build, test, and qualify SerapeumOS. Installed only when
an approved task proves they are required.

| Tool | Purpose | Current status |
|---|---|---|
| Git | Version control | ✅ Installed (2.55.0) |
| GitHub CLI (`gh`) | Repository management | ✅ Installed (2.93.0), authenticated |
| VS Code | Source editing / task execution | ✅ Installed (1.136.1) |
| Node.js / Bun | Ankole runtime (build + Worker) | ✅ Bun available; Node via pi-node |
| Go toolchain | LinuxKit build tool (if selected) | Not installed — pending MA-18/MA-20 |
| QEMU | WHPX prototyping backend | ✅ Installed (11.1.0) at `C:\Program Files\qemu\` |
| Docker CLI + Compose | Worker OCI image build | ✅ CLI present; engine stopped (Docker Desktop stopped) |
| Python 3 | eval tooling, Jupyter runtime | ⚠️ Partially installed (3.12.10); default alias broken |
| Rust / cargo | Kernel native binding build | Not installed — pending implementation task |
| Elixir / Erlang/OTP | Ankole control-plane build | Not installed — pending implementation task |
| Make | Build orchestration | Not installed — pending implementation task |

No tool is installed merely because a candidate architecture mentions it.
Toolchains are installed only when an approved implementation or qualification
task proves they are required.

## Qualified implementation dependencies

Dependencies selected only after the related MA gate closes. Populated as each
domain reaches LOCKED status.

| Dependency | Selecting MA | Selection status |
|---|---|---|
| LinuxKit (appliance builder) | MA-01 / MA-17 | PROPOSED — F-W1A INCONCLUSIVE |
| QEMU/WHPX (VMM backend) | MA-01 | PROPOSED — WHPX recognized by binary; empirical boot proof PENDING |
| Hyper-V (alternative VMM) | MA-01 | CONDITIONAL / REFERENCE |
| Firecracker / Cloud Hypervisor | MA-01 | NOT SELECTED — backend-neutrality assessment INCONCLUSIVE |
| Trivy (SBOM/security) | Architecture candidates | Architectural selection only; not installed |
| OSV-Scanner (vuln intelligence) | Architecture candidates | Architectural selection only; not installed |
| iron-proxy (egress control) | Architecture candidates | Architectural selection only; not installed |
| OpenTelemetry (telemetry) | Architecture candidates | Architectural selection only; not installed |
| age (local encryption) | Architecture candidates | Architectural selection only; not installed |

No candidate becomes a permanent prerequisite merely because it appeared in an
experiment or proposal.
