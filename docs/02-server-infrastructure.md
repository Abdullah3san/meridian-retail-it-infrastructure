# 02 — Server Infrastructure

See also: [Logical Software Architecture Diagram](../diagrams/logical-architecture.md), [04 — Software Stack](04-software-stack.md), [07 — Disaster Recovery](07-disaster-recovery.md). Full trade-off reasoning: [ADR-0003 — Proxmox VE over VMware vSphere](adr/0003-proxmox-over-vmware.md).

## Design goals

1. Everything centralized at HQ — branches stay thin, so there's one place to patch, back up, and secure
2. No single point of failure in the hypervisor layer for anything business-critical (AD, ERP)
3. One IT generalist can operate this — favor a small number of well-understood building blocks over a sprawling toolset
4. Storage and backup are separate concerns from compute, so a compute failure never threatens a backup

## Physical layer

See the [rack elevation diagram](../diagrams/assets/rack-elevation.svg) for exactly what's mounted where in the HQ server room.

| Role | Hardware | Notes |
|---|---|---|
| Hypervisor nodes | 2× rack server (e.g. Dell R340/R350-class or similar), 64GB RAM, 8+ cores each | Proxmox VE cluster — see below |
| Backup target | 1× dedicated server, large HDD array (RAID6/ZFS) | Runs Proxmox Backup Server, physically separate box from the hypervisors |
| Bulk storage/NAS | 1× NAS appliance or repurposed server, ZFS | Runs TrueNAS — file storage overflow, ISOs, secondary backup copy |
| Network | Server-room switch, LACP 2×1G+ uplinks per host | See [01 — Network Architecture](01-network-architecture.md) |
| Power | UPS sized for ~15 min runtime on the full server rack, network gear included | Enough to survive a blip or trigger clean shutdown on extended outage |

## Virtualization: Proxmox VE

- **2-node Proxmox VE cluster** (with a small witness/QDevice for quorum, e.g. a Raspberry Pi or the backup server) — gives live migration and the ability to patch/reboot one node without downtime.
- VM storage lives on local ZFS per node with **replication** between nodes for the critical VMs (AD, ERP), so a node failure has a near-current copy ready to start on the surviving node.
- Non-critical VMs (wiki, helpdesk) are single-node — acceptable downtime if that node fails, restored from Proxmox Backup Server.
- Why Proxmox over VMware/Hyper-V: no per-socket licensing, native ZFS + replication + backup integration, and a web UI a solo admin can actually run day to day without a vSphere-scale toolchain.

## The 14-VM service map

All VMs live on VLAN 20 (Servers) at HQ. Each VM is a single-purpose, small footprint — easier to patch, back up, and reason about than one monolithic "everything server."

The VMs below are defined as code: [`iac/terraform`](../iac/terraform/) provisions them (sizing, node placement, IPs) and [`iac/ansible`](../iac/ansible/) configures them. See [`iac/README.md`](../iac/README.md) for the full mapping.

| # | Hostname | Service | Purpose | Doc |
|---|---|---|---|---|
| 1 | `dc01` | Samba 4 AD DC | Primary domain controller, internal DNS | [03](03-identity-and-access.md) |
| 2 | `dc02` | Samba 4 AD DC | Secondary DC — redundancy for auth/DNS | [03](03-identity-and-access.md) |
| 3 | `erp01` | ERPNext | Accounting, inventory, HR, CRM, POS backend | [04](04-software-stack.md) |
| 4 | `files01` | Nextcloud | File sync/share across all 3 sites | [04](04-software-stack.md) |
| 5 | `mail01` | Mailcow | Business email (SMTP/IMAP/webmail) | [04](04-software-stack.md) |
| 6 | `vault01` | Vaultwarden | Company password manager | [04](04-software-stack.md), [03](03-identity-and-access.md) |
| 7 | `wiki01` | BookStack | Internal documentation/SOPs | [04](04-software-stack.md) |
| 8 | `helpdesk01` | Zammad | IT + customer support ticketing | [04](04-software-stack.md) |
| 9 | `voip01` | FreePBX/Asterisk | VoIP phone system, SIP trunking | [04](04-software-stack.md) |
| 10 | `mon01` | Zabbix + Grafana | Infrastructure monitoring, dashboards, alerting | [06](06-monitoring-observability.md) |
| 11 | `siem01` | Wazuh | SIEM/EDR — log correlation, file integrity, active response | [05](05-security-architecture.md) |
| 12 | `web01` | WordPress | Public company website (reverse-proxied from DMZ) | [04](04-software-stack.md) |
| 13 | `pbs01` | Proxmox Backup Server | Primary VM backup target | [07](07-disaster-recovery.md) |
| 14 | `nas01` | TrueNAS | Bulk storage + secondary backup copy | [07](07-disaster-recovery.md) |

## Why single-purpose VMs instead of fewer, bigger boxes

- **Blast radius:** a misconfigured update to the wiki shouldn't be able to take down email.
- **Backup granularity:** each VM backs up and restores independently — restoring `mail01` doesn't touch `erp01`.
- **Resource isolation:** ERPNext and Mailcow are both fairly resource-hungry; giving each its own VM means Proxmox's scheduler and resource limits keep one from starving another.
- **Patching:** OS-level patches to one service's VM don't force a maintenance window on unrelated services.

This is a deliberate trade-off against "just run everything in Docker on one big box" — more VMs to patch, but far easier to reason about, back up, and recover piece by piece. Most of these services are themselves deployed via Docker Compose *inside* their VM (see [`configs/docker-compose/`](../configs/docker-compose/)), so it's really "one VM per concern, Docker inside for the app itself."

## Server room network

- Each Proxmox node: 2× 1G NICs in LACP bond, tagged for VLAN 20 (VM traffic) and VLAN 10 (Proxmox cluster/management traffic) on separate VLAN-tagged sub-interfaces.
- `pbs01` and `nas01` sit on VLAN 20 as well but are **not** part of the Proxmox cluster — they're independent boxes, which is exactly the point: a Proxmox cluster failure (e.g. corrupted cluster config) can't take the backup target down with it.

## Patch management

- Proxmox hosts: patched manually in a scheduled after-hours window, one node at a time (the second node keeps everything running via migration).
- VM guest OS (Debian/Ubuntu base for all the above): unattended-upgrades for security patches, with `mon01` alerting if a VM hasn't checked in / rebooted for pending kernel updates in over 30 days.
- Windows staff workstations: see [05 — Security Architecture](05-security-architecture.md#patching--hardening).
