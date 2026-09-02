# 07 — Disaster Recovery

See also: [Backup & DR Flow Diagram](../diagrams/backup-dr-flow.md), [02 — Server Infrastructure](02-server-infrastructure.md), [policies/backup-retention-policy.md](../policies/backup-retention-policy.md)

## Design goal

A backup that has never been restored isn't a backup, it's a hope. This design is built around a real, testable **3-2-1 chain** (3 copies, on 2 different media types, 1 offsite) with defined RTO/RPO targets — not just "there's a snapshot somewhere."

## The 3-2-1 chain

| Copy | Location | Medium | Mechanism |
|---|---|---|---|
| **1 — Production** | Proxmox cluster, HQ | ZFS on hypervisor local disk | The running VM itself |
| **2 — Primary backup** | `pbs01`, HQ (separate physical box) | Proxmox Backup Server, dedup'd incremental | Nightly scheduled backup job, all 14 VMs |
| **3 — Secondary/offsite** | `nas01` (local, different medium) **and** cloud object storage (offsite) | TrueNAS ZFS + encrypted cloud object storage (e.g. Backblaze B2/S3-compatible) | `pbs01` replicates its backup datastore to `nas01` locally, then a scheduled sync pushes an encrypted copy offsite |

This satisfies all three legs: 3 copies (production + PBS + NAS/cloud), 2 media types (hypervisor ZFS + PBS dedup store, distinct from the NAS's separate array), 1 offsite (the cloud object storage copy, which also survives a total HQ site loss — fire, theft, flood).

## Backup schedule & retention

| VM tier | Frequency | Retention |
|---|---|---|
| Critical (`dc01`, `dc02`, `erp01`, `vault01`) | Every 4 hours + nightly full | 7 daily, 4 weekly, 6 monthly |
| Standard (everything else) | Nightly | 7 daily, 4 weekly, 3 monthly |

Full retention policy and rationale: [policies/backup-retention-policy.md](../policies/backup-retention-policy.md)

## RTO / RPO targets

| Scenario | RPO (max data loss) | RTO (max downtime) |
|---|---|---|
| Single VM failure/corruption | ≤4 hours (critical) / 24 hours (standard) | ≤30 min (restore from PBS on surviving Proxmox node) |
| Proxmox node failure | Near-zero for replicated critical VMs (ZFS replication, [02](02-server-infrastructure.md)) | ≤15 min (VM starts on surviving node) |
| Full HQ site loss (fire/flood/theft) | ≤24 hours (last offsite sync) | ≤48 hours (rebuild on replacement hardware or a cloud VPS, restore from offsite copy) |
| Branch site loss | Near-zero — branches hold no unique data; only local network gear needs replacing | ≤1 business day for new firewall/switch/AP install |
| Ransomware / SIEM-flagged compromise | Depends on detection lag; PBS backups are immutable for their retention window, so a clean pre-incident restore point is always available | ≤4 hours to restore affected VM(s) from last known-good backup |

## Why branches recover fast

Because the architecture deliberately keeps branches "thin" (no unique local data — see [01](01-network-architecture.md) and [02](02-server-infrastructure.md)), a branch disaster is a *hardware replacement problem*, not a *data recovery problem*. Swap in a spare pfSense/switch/AP, re-establish the WireGuard tunnel, and the branch is back to full functionality — nothing at the branch itself needs restoring.

## DR runbook: full HQ site loss (summary)

The living version of this lives in BookStack ([04 — Software Stack](04-software-stack.md#bookstack--internal-wiki)); this is the portfolio summary.

1. **Stand up replacement compute** — either repaired/replacement hardware on-site, or a temporary Proxmox instance on a cloud VPS as a bridge.
2. **Pull the offsite copy** from cloud object storage, restore to the new Proxmox instance — critical VMs first (`dc01`, `erp01`), in priority order.
3. **Re-point DNS/VPN** — update each branch pfSense's WireGuard peer endpoint to the new HQ public IP (or bring the new HQ up on the same public IP if hardware was just replaced).
4. **Verify AD/DNS first** — nothing else authenticates correctly until `dc01` is confirmed healthy.
5. **Bring up remaining VMs** in priority order (ERP → mail → files → everything else), verifying each against its Zabbix health check ([06](06-monitoring-observability.md)) before moving on.
6. **Confirm branch connectivity and POS function** end to end before declaring recovery complete — the actual business-facing success criterion, not "the VMs are running."

## Backup testing

- Quarterly: restore one random VM from `pbs01` to an isolated test network, verify it boots and the application is functional — the single most-skipped step in most SMB DR plans, and the one that actually matters. Documented in [policies/backup-retention-policy.md](../policies/backup-retention-policy.md).
- Annually: full tabletop exercise of the runbook above, timed against the RTO targets, findings fed back into this document.
