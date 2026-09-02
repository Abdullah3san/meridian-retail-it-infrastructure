# Backup Retention Policy — Meridian Retail Group (Sample)

Design context: [07 — Disaster Recovery](../docs/07-disaster-recovery.md)

*Sample policy matching this repo's technical design — adapt with legal/HR review before real-world use.*

## Scope

Covers all 14 server VMs described in [02 — Server Infrastructure](../docs/02-server-infrastructure.md#the-14-vm-service-map). Workstations are not individually backed up — company data belongs in Nextcloud/ERPNext (which are backed up), not on local workstation disks, per the [Acceptable Use Policy](acceptable-use-policy.md).

## Retention schedule

| Tier | VMs | Backup frequency | Retention |
|---|---|---|---|
| Critical | `dc01`, `dc02`, `erp01`, `vault01` | Every 4 hours + nightly full | 7 daily, 4 weekly, 6 monthly restore points |
| Standard | `files01`, `mail01`, `wiki01`, `helpdesk01`, `voip01`, `mon01`, `siem01`, `web01`, `nas01` | Nightly | 7 daily, 4 weekly, 3 monthly restore points |

Rationale for the critical tier: these four VMs are what a total-loss recovery depends on first (identity, ERP/POS, and the password vault IT itself needs to get back into everything else) — see the [DR runbook](../docs/07-disaster-recovery.md#dr-runbook-full-hq-site-loss-summary), where `dc01` and `erp01` are explicitly first in the recovery order.

## The 3-2-1 chain this policy governs

Full mechanism and diagram: [07 — Disaster Recovery](../docs/07-disaster-recovery.md#the-3-2-1-chain), [Backup & DR Flow diagram](../diagrams/backup-dr-flow.md).

1. Production (the running VM)
2. `pbs01` — Proxmox Backup Server, on-site, separate physical box
3. `nas01` (local secondary) + encrypted cloud object storage (offsite)

## Immutability & ransomware protection

- Proxmox Backup Server retention is enforced by PBS's own prune/garbage-collection schedule, not by the guest OS — a compromised VM cannot reach back and delete its own backup history.
- The offsite cloud copy uses object lock / versioning where the provider supports it, so even an attacker with valid cloud credentials can't silently overwrite the last N days of backups.

## Restore testing

- **Quarterly:** one VM, chosen at random from the full 14, is restored from `pbs01` to an isolated test network and verified to boot and serve its application correctly. Results logged in BookStack ([04 — Software Stack](../docs/04-software-stack.md#bookstack--internal-wiki)).
- **Annually:** full DR runbook tabletop exercise per [07 — Disaster Recovery](../docs/07-disaster-recovery.md#backup-testing), timed against the documented RTO targets.
- A restore test that fails is treated as a P1 incident, not a footnote — it means the actual DR capability doesn't match what this policy claims.

## Data retention vs. legal/compliance retention

This policy governs *infrastructure* backup for disaster recovery (RTO/RPO — getting systems running again). It is distinct from any statutory financial-record retention requirement (e.g. tax/accounting record-keeping periods), which is a business/legal decision made in ERPNext's own document retention settings, not by this backup schedule.
