# 00 — Company Profile & Requirements

## The business

**Meridian Retail Group** is a fictional general-merchandise retailer used as the design target for this project. It's deliberately modeled as a *typical* small business, not a best-case one — the constraints below (budget, staff size, no in-house network engineer) are what shape every decision in this repo.

| | |
|---|---|
| Industry | Retail (general merchandise) + light warehousing/distribution |
| Locations | 3: Head Office (HQ), Branch North, Branch South |
| Staff | ~60 total (30 HQ, 15 per branch) |
| IT staff | 1 IT generalist (part sysadmin, part helpdesk) — everything must be manageable by one person |
| Budget posture | Cost-conscious — avoid recurring per-seat SaaS fees wherever a self-hosted alternative is credible |
| Compliance | Standard PCI-DSS awareness for card payments (POS), no other regulatory regime assumed |

## Sites

| Site | Role | Staff | Notes |
|---|---|---|---|
| **HQ** | Admin, Finance, HR, IT, Warehouse/Ops, server room | ~30 | Hosts all core infrastructure — the two branches are effectively thin sites that depend on HQ over VPN |
| **Branch North** | Retail storefront | ~15 | 10 sales floor / POS, 5 back-office |
| **Branch South** | Retail storefront | ~15 | Same layout as North |

## Requirements that drove the design

**Connectivity**
- All 3 sites need to operate as one network — shared file access, shared directory login, centralized phone system
- A branch losing its WAN link should not stop it from selling (local POS resilience matters)
- Guest WiFi at every site, isolated from business systems

**Security**
- Card payment terminals must be network-isolated from everything else (PCI-DSS segmentation expectation)
- CCTV/IoT devices must never reach the internet directly or sit on the same broadcast domain as staff machines
- Single sign-on and centrally enforced password/MFA policy — no local-only accounts scattered across apps
- One place to see security events across all sites, not three

**Software**
- Accounting, inventory, POS, HR, and CRM should not be five unrelated subscriptions with five different logins and no shared data
- Staff need file sharing/sync that works like Dropbox, without sending company files to a third party by default
- IT needs a ticketing system and a documentation wiki — "how do I reset the printer" shouldn't live in someone's head

**Operations**
- Backups need a real 3-2-1 story with a tested restore path, not "the snapshot from last Tuesday"
- Monitoring should alert *before* a branch calls to say the internet is down
- Everything should be manageable remotely by a single IT generalist — no fleet of specialists required

## What this repo delivers against those requirements

| Requirement | Where it's addressed |
|---|---|
| Multi-site connectivity | [01 — Network Architecture](01-network-architecture.md), [Network Topology](../diagrams/network-topology.md) |
| Segmentation (POS, guest, IoT/CCTV) | [01 — Network Architecture](01-network-architecture.md) §VLANs, [VLAN Segmentation](../diagrams/vlan-segmentation.md) |
| Servers & virtualization | [02 — Server Infrastructure](02-server-infrastructure.md) |
| Identity, SSO, MFA | [03 — Identity & Access](03-identity-and-access.md) |
| ERP/POS/accounting/HR/CRM, file sync, email, wiki, helpdesk | [04 — Software Stack](04-software-stack.md) |
| Firewall policy, SIEM, hardening, remote access | [05 — Security Architecture](05-security-architecture.md) |
| Proactive alerting | [06 — Monitoring & Observability](06-monitoring-observability.md) |
| Backup & real restore path | [07 — Disaster Recovery](07-disaster-recovery.md) |
| Budget reality check | [08 — Cost & Bill of Materials](08-cost-and-bom.md) |
| Card payments isolated (PCI-DSS) | [09 — PCI DSS Control Map](09-pci-dss-control-map.md), [ADR-0008](adr/0008-p2pe-terminals-for-pci-scope.md) |
| Knowing what to do when it breaks | [Incident runbooks](../runbooks/) |

## Naming conventions used throughout this repo

- Public domain: `meridianretail.com` — website and email addresses
- Internal AD/DNS domain: `corp.meridianretail.com` (NetBIOS name `MERIDIAN`) — a delegated subdomain of the public domain, not `.local` (see [ADR-0007](adr/0007-ad-domain-subdomain-not-local.md))
- Hostname pattern: `<service>-<site>` for site-specific gear (e.g. `fw-hq`, `sw-north`), `<service>0<n>` for centrally hosted VMs (e.g. `erp01`, `files01`)
- Site codes: `HQ`, `BRN` (Branch North), `BRS` (Branch South) — used in IP addressing and diagrams
