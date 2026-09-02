# Meridian Retail Group — Complete SMB IT Infrastructure

A full, from-scratch IT infrastructure design for a fictional 3-location small business — **network, servers, security, and the complete software stack** — built as a portfolio piece to demonstrate end-to-end IT/infrastructure engineering.

> **Company:** Meridian Retail Group — general merchandise retailer
> **Footprint:** Head Office (admin + warehouse) + 2 retail branches, ~60 staff, ~14 servers
> **Design philosophy:** Open-source / self-hosted first — every core service is a tool you can actually deploy and run today, at close to $0 in licensing.

This repo is a **design document + reference implementation**, not a live production system. Every diagram is real (Mermaid, renders on GitHub), every config is a real, working sample (pfSense rules, WireGuard, VLANs, Docker Compose), and every architectural decision is explained — the point is to show *how* and *why*, not just *what*.

---

## Why this exists

Most "homelab" portfolios show one server running one app. Real SMB environments are a system: a WAN edge, segmented VLANs, a domain, centralized identity, a backup chain with a real RPO/RTO, and a dozen business-critical apps that all have to talk to each other securely across three sites. This project designs that whole system for a realistic small business, end to end.

## Repo map

| Folder | What's in it |
|---|---|
| [`docs/`](docs/) | The written design — company profile, network, servers, identity, software, security, monitoring, DR, cost |
| [`diagrams/`](diagrams/) | Mermaid network/architecture/data-flow diagrams (render natively on GitHub) |
| [`configs/`](configs/) | Real, working config samples — pfSense firewall rules, WireGuard site-to-site, VLANs, DHCP, Docker Compose stacks |
| [`policies/`](policies/) | The paperwork side of IT — AUP, password policy, backup retention |

## Start here

1. **[Company Profile](docs/00-company-profile.md)** — the business this whole design is built for, and the requirements that drove every decision
2. **[Network Architecture](docs/01-network-architecture.md)** — topology, IP/VLAN plan, WAN, site-to-site VPN
3. **[Network Topology Diagram](diagrams/network-topology.md)** — the picture version of #2
4. **[Server Infrastructure](docs/02-server-infrastructure.md)** — virtualization, storage, the 14-VM service map
5. **[Software Stack](docs/04-software-stack.md)** — what runs the business day to day, and why each tool was picked
6. **[Security Architecture](docs/05-security-architecture.md)** — segmentation, SIEM, hardening, remote access
7. **[Disaster Recovery](docs/07-disaster-recovery.md)** — backup chain, RTO/RPO, the actual failover runbook

## Full documentation index

- [00 — Company Profile & Requirements](docs/00-company-profile.md)
- [01 — Network Architecture](docs/01-network-architecture.md)
- [02 — Server Infrastructure](docs/02-server-infrastructure.md)
- [03 — Identity & Access Management](docs/03-identity-and-access.md)
- [04 — Software Stack](docs/04-software-stack.md)
- [05 — Security Architecture](docs/05-security-architecture.md)
- [06 — Monitoring & Observability](docs/06-monitoring-observability.md)
- [07 — Disaster Recovery](docs/07-disaster-recovery.md)
- [08 — Cost & Bill of Materials](docs/08-cost-and-bom.md)

## Diagrams

- [Network Topology](diagrams/network-topology.md) — all 3 sites, WAN edges, VPN mesh, core devices
- [VLAN Segmentation](diagrams/vlan-segmentation.md) — per-site VLAN layout and inter-VLAN policy
- [Logical Software Architecture](diagrams/logical-architecture.md) — every service and how users reach it
- [Security Zones & Data Flow](diagrams/dataflow-security-zones.md) — trust boundaries, DMZ, traffic flow
- [Backup & DR Flow](diagrams/backup-dr-flow.md) — the 3-2-1 backup chain end to end

## Configs (real samples, not screenshots)

- [`configs/pfsense/`](configs/pfsense/) — firewall rule tables, WireGuard site-to-site sample, VLAN interfaces
- [`configs/switch/`](configs/switch/) — VLAN/trunk config sample for a managed access switch
- [`configs/dhcp/`](configs/dhcp/) — Kea DHCPv4 config sample
- [`configs/docker-compose/`](configs/docker-compose/) — the self-hosted app stacks (monitoring, Nextcloud, Vaultwarden, etc.)

## At a glance

| Layer | Choice | Why |
|---|---|---|
| Firewall / Router | pfSense (CE) | Free, enterprise-grade, huge community, does routing + firewall + VPN + IDS in one box |
| Site-to-site VPN | WireGuard (hub-and-spoke via HQ) | Modern, fast, tiny attack surface, native in pfSense |
| Virtualization | Proxmox VE | Free KVM hypervisor with clustering, snapshots, and a built-in backup story |
| Identity | Samba 4 Active Directory | Real AD (Kerberos/LDAP/GPO) compatible with Windows clients, at $0 |
| ERP / POS / Accounting / Inventory / HR / CRM | ERPNext | One system covering nearly every back-office function — avoids 6 separate SaaS subscriptions |
| File sync/share | Nextcloud | Dropbox-equivalent, self-hosted, mobile + desktop clients |
| Email | Mailcow | Full mail server (SMTP/IMAP + webmail + spam filtering) in a Docker stack |
| Monitoring | Zabbix + Grafana | Infrastructure monitoring + alerting with real dashboards |
| SIEM / EDR | Wazuh | Log correlation, file integrity monitoring, active response |
| Backup | Proxmox Backup Server + TrueNAS + offsite object storage | A real 3-2-1 chain, not "just snapshots" |

## License

Documentation and configs in this repo are provided under the [MIT License](LICENSE) — reuse, adapt, and build on it freely.

---

*This is a portfolio/reference design. Company name, addresses, and IP ranges are fictional. Config samples are meant to be read and adapted, not copy-pasted into a production network without review.*
