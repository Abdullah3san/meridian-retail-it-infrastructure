# Backup & DR Flow

Full design context: [07 — Disaster Recovery](../docs/07-disaster-recovery.md)

## The 3-2-1 chain, end to end

```mermaid
flowchart LR
    subgraph Prod["Copy 1 — Production"]
        VM[14 VMs on<br/>Proxmox Cluster<br/>ZFS local disk]
    end

    subgraph Local["HQ Server Room"]
        PBS[Copy 2 — pbs01<br/>Proxmox Backup Server<br/>dedup incremental, every 4h/nightly]
        NAS[Copy 3a — nas01<br/>TrueNAS ZFS<br/>local replica, different medium]
    end

    subgraph Offsite["Offsite"]
        CLOUD[Copy 3b — Cloud Object Storage<br/>encrypted, offsite<br/>survives full HQ loss]
    end

    VM -->|scheduled backup job| PBS
    PBS -->|replication| NAS
    PBS -->|encrypted sync| CLOUD

    TEST{{Quarterly restore test<br/>isolated network}} -.verifies.-> PBS

    style Prod fill:#eef5ff,stroke:#3b6fb6
    style Local fill:#f5fff0,stroke:#4a9c3f
    style Offsite fill:#fff5e8,stroke:#b9761f
    style TEST fill:#fff0f0,stroke:#c0392b
```

## Read this diagram as

- **3 copies:** production (the running VM), `pbs01` (primary backup), and the NAS + cloud pair (secondary/offsite) — losing any one copy still leaves two others.
- **2 media types:** the Proxmox cluster's ZFS and PBS's dedup datastore are architecturally distinct from the NAS's separate ZFS array — a filesystem-level or backup-software bug affecting one doesn't affect the other.
- **1 offsite:** the cloud object storage copy is the only one that survives HQ itself being destroyed (fire/flood/theft) — this is the copy the [DR runbook](../docs/07-disaster-recovery.md#dr-runbook-full-hq-site-loss-summary) pulls from in a full-site-loss scenario.
- **The quarterly restore test isn't decorative** — a backup chain with no tested restore path is, per [07 — Disaster Recovery](../docs/07-disaster-recovery.md#backup-testing), not actually trusted to work until it's been proven to.
