# 04 — Software Stack

See also: [Logical Software Architecture](../diagrams/logical-architecture.md), [02 — Server Infrastructure](02-server-infrastructure.md), Docker Compose samples in [`configs/docker-compose/`](../configs/docker-compose/). Full trade-off reasoning: [ADR-0005 — ERPNext over point-solution SaaS](adr/0005-erpnext-over-point-solutions.md).

## Philosophy

Every business function below could be a separate SaaS subscription. At 60 staff, that's realistically 6–10 monthly subscriptions, each with its own login, its own data silo, and its own price increase on renewal. This design consolidates aggressively where one good open-source tool can honestly replace several SaaS products, and stays with SaaS-shaped simplicity only where self-hosting would genuinely be worse (see the "what's *not* self-hosted" note at the bottom).

## ERPNext — the core of the business

**Replaces:** separate accounting software, inventory system, HR/payroll tracker, CRM, and POS software.

- Hosted as `erp01` (see [02](02-server-infrastructure.md)), one instance serving HQ and both branches.
- **Accounting:** chart of accounts, AP/AR, bank reconciliation, financial statements.
- **Inventory:** stock levels across HQ warehouse + both branch storefronts, transfer orders between sites, reorder alerts.
- **POS:** the POS terminals at each branch run ERPNext's point-of-sale screen, hitting `erp01` over the site-to-site VPN — sales, at both branches, land directly in the same inventory and accounting ledgers with no manual reconciliation step.
- **HR:** employee records, leave management, basic payroll.
- **CRM:** customer records and communication history, useful for B2B/wholesale customers alongside walk-in retail.
- Why one system instead of five best-of-breed tools: the integration *is* the product here — a sale at Branch North instantly reflects in HQ inventory and the books, with no nightly sync job to babysit.

## Nextcloud — file sync & share

**Replaces:** Dropbox/Google Drive for business.

- `files01`, with the desktop and mobile sync clients installed on staff machines via GPO software deployment.
- Departmental folders permissioned by AD group (via LDAP integration) — Finance sees Finance, Warehouse sees Warehouse.
- Also used for structured document sharing with external accountants/auditors via time-limited share links, instead of emailing spreadsheets.

## Mailcow — business email

**Replaces:** Google Workspace / Microsoft 365 mail (for mail specifically — see the note on M365 below).

- `mail01`, full Docker Compose stack (Postfix, Dovecot, Rspamd, SOGo webmail) — see [`configs/docker-compose/mailcow/`](../configs/docker-compose/mailcow/) (settings + deployment) and [`iac/ansible`](../iac/ansible/) (automated install).
- SPF/DKIM/DMARC configured on the public DNS zone; Rspamd handles spam/phishing filtering.
- Mailboxes provisioned/deprovisioned by syncing against AD group membership, keeping mail access tied to the same joiner/mover/leaver process as everything else ([03](03-identity-and-access.md)).

## Vaultwarden — password management

Covered in [03 — Identity & Access](03-identity-and-access.md#password--secrets-management).

## BookStack — internal wiki

**Replaces:** Confluence, or (more honestly) the "tribal knowledge in one person's head" default.

- `wiki01` — organized as Shelves (department) → Books (topic) → Pages (procedure). IT runbooks, HR onboarding steps, POS troubleshooting guides for branch staff.
- This is where [07 — Disaster Recovery](07-disaster-recovery.md)'s runbook actually lives in production — the markdown in this repo is the portfolio version of what would be a living BookStack page.

## Zammad — helpdesk / ticketing

**Replaces:** a shared inbox and a spreadsheet.

- `helpdesk01` — handles both internal IT requests ("my laptop won't join WiFi") and customer-facing support (order issues, warranty questions), in separate queues with different SLAs.
- Integrates with Mailcow so `support@` and `it-help@` both flow into Zammad automatically.

## FreePBX / Asterisk — VoIP phones

**Replaces:** a traditional phone-line PBX and per-line telco fees.

- `voip01` — desk phones at all 3 sites register over the VPN (VLAN 50 at each site, see [01](01-network-architecture.md)). A SIP trunk provider handles outbound PSTN calling.
- Branch-to-HQ and branch-to-branch calls are free internal extension-to-extension calls over the VPN instead of PSTN minutes.

## WordPress — public website

**Replaces:** a website builder SaaS subscription.

- `web01`, the only internally-hosted service exposed to the public internet, and only via reverse proxy (see [05 — Security Architecture](05-security-architecture.md#dmz--public-facing-services)) — it never sits directly on a public IP.

## What's deliberately *not* self-hosted

Being "open-source first" doesn't mean self-hosting everything regardless of cost/benefit. Two exceptions, and why:

- **Card payment processing** — handled by a PCI-DSS-certified payment processor (e.g. Stripe/Square terminal integration into ERPNext), never custom-built. The readers come from the processor's PCI-listed P2PE solution, so payment card data never touches infrastructure this business operates itself — that's what PCI-DSS scoping exists to prevent. Reasoning: [ADR-0008](adr/0008-p2pe-terminals-for-pci-scope.md).
- **Office productivity (docs/spreadsheets/slides for collaborative editing)** — a case where a hosted office suite (e.g. Microsoft 365 Apps or Google Workspace, seat-licensed) is pragmatically better than self-hosted alternatives (Collabora/OnlyOffice) for a non-technical staff used to Word/Excel. Noted as a deliberate SaaS exception, not an oversight — see [08 — Cost & BOM](08-cost-and-bom.md) for the trade-off.

## Software-to-VM map

See [02 — Server Infrastructure](02-server-infrastructure.md#the-14-vm-service-map) for the full table of which VM runs which service, and [`configs/docker-compose/`](../configs/docker-compose/) for the actual stack definitions.
