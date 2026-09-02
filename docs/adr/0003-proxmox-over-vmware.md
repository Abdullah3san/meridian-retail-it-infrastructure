# ADR-0003: Virtualization platform — Proxmox VE over VMware vSphere

**Status:** Accepted
**Affects:** [02 — Server Infrastructure](../02-server-infrastructure.md), [07 — Disaster Recovery](../07-disaster-recovery.md), [08 — Cost & BOM](../08-cost-and-bom.md)

## Context

14 VMs need a hypervisor with clustering, live migration, snapshots, and an integrated backup story. The realistic options: **VMware vSphere** (the incumbent enterprise standard, Essentials Plus tier at this scale), **Proxmox VE** (KVM-based, open-source with optional paid support), or **Hyper-V** (free with Windows Server Datacenter/Standard licensing, tightly coupled to a Windows-centric shop).

## Decision

Use **Proxmox VE**, 2-node cluster with ZFS replication for critical VMs.

## Rationale

- **Licensing model shift:** Broadcom's post-acquisition changes to VMware licensing (elimination of the free ESXi tier, bundling changes, and steep list-price increases for smaller deployments) made vSphere materially worse economics for a business this size than it was a few years ago — this is a live, well-documented industry shift, not a hypothetical.
- **Integrated backup:** Proxmox Backup Server is a first-class, purpose-built companion product with deduplication and incremental-forever backups — this is what makes the [3-2-1 backup chain](../07-disaster-recovery.md#the-3-2-1-chain) achievable without a *third* separate backup product license (e.g. Veeam) on top of the hypervisor license itself.
- **ZFS-native replication:** built into Proxmox at no extra cost, giving near-zero-RPO failover for the critical VMs (AD, ERP) between the two cluster nodes — vSphere's equivalent (vSAN, or replication add-ons) is a separate licensed product.

## Consequences

- **Smaller admin talent pool.** More IT hires have hands-on vSphere experience than Proxmox — if this business ever needs to hire a second sysadmin, vSphere experience is easier to source in the job market than Proxmox experience. This is a real hiring-pipeline cost, not just a technical one.
- **Ecosystem maturity gap.** Certain third-party tools (some backup vendors, some monitoring integrations, some hardware vendors' management stacks) have first-class vSphere support and only community-grade or no Proxmox support. Anything requiring deep vSphere-specific integration (e.g. a hardware vendor's proprietary vSphere plugin) would need a workaround or wouldn't work at all.
- **2-node cluster quorum is a known sharp edge.** A 2-node Proxmox cluster needs a third quorum device (a small QDevice, per [02 — Server Infrastructure](../02-server-infrastructure.md#virtualization-proxmox-ve)) to avoid split-brain — this is an extra moving part that a 3+-node cluster (or a licensed vSphere HA setup) wouldn't need in the same way. Documented explicitly rather than left as an implicit assumption.

## Revisit if

The business scales to a size (more sites, a dedicated infrastructure team) where vSphere's ecosystem maturity and talent availability outweigh the licensing cost delta — or where a specific piece of required hardware/software has a hard vSphere-only dependency.
