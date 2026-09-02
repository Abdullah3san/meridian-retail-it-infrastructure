# 08 — Cost & Bill of Materials

See also: [02 — Server Infrastructure](02-server-infrastructure.md), [01 — Network Architecture](01-network-architecture.md), [04 — Software Stack](04-software-stack.md)

All figures are rough, illustrative estimates (USD) to show the order of magnitude and where the money actually goes — not a vendor quote. The point of this document is the *shape* of the cost (mostly one-time hardware, near-zero recurring software) more than the exact numbers.

## One-time hardware (capital cost)

| Item | Qty | Est. unit cost | Est. total |
|---|---|---|---|
| Hypervisor server (Proxmox node) | 2 | $2,500 | $5,000 |
| Backup server (`pbs01`) | 1 | $2,000 | $2,000 |
| NAS appliance (`nas01`) | 1 | $1,500 | $1,500 |
| UPS (server room) | 1 | $600 | $600 |
| pfSense appliance (HQ) | 1 | $500 | $500 |
| pfSense appliance (per branch) | 2 | $300 | $600 |
| Core L3 switch (HQ) | 1 | $800 | $800 |
| Access switches (HQ + branches) | 4 | $300 | $1,200 |
| WiFi APs (all sites) | 8 | $150 | $1,200 |
| VoIP desk phones | 40 | $60 | $2,400 |
| **Total hardware** | | | **≈ $15,800** |

## Recurring costs

| Item | Frequency | Est. cost | Notes |
|---|---|---|---|
| Core software licensing | — | **$0** | Every core service in [04 — Software Stack](04-software-stack.md) is open-source with no per-seat fee |
| ISP (fiber, all 3 sites) | Monthly | ~$450/mo combined | Business-grade circuits |
| LTE failover data (all 3 sites) | Monthly | ~$120/mo combined | Standby only, low data plan sufficient |
| SIP trunk (PSTN calling) | Monthly | ~$50/mo + per-minute | Usage-based |
| Cloud offsite backup storage | Monthly | ~$30–80/mo | Scales with data volume, see [07 — Disaster Recovery](07-disaster-recovery.md) |
| Domain/SSL/DNS | Annual | ~$50/yr | TLS itself is free (Let's Encrypt); this is just domain registration |
| **Office productivity suite** (deliberate SaaS exception, see [04](04-software-stack.md#whats-deliberately-not-self-hosted)) | Monthly, per seat | ~$6–12/seat/mo × 60 | The one significant recurring per-seat cost in this design |
| **Total recurring (excl. productivity suite)** | | **≈ $650–700/mo** | |
| **Total recurring (incl. productivity suite)** | | **≈ $1,010–1,420/mo** | |

## What the open-source-first approach actually saves

For comparison, a rough SaaS-equivalent stack at 60 users would run something like:

| Function | Typical SaaS equivalent | Approx. cost at 60 seats |
|---|---|---|
| ERP/Accounting/Inventory/POS/CRM/HR | QuickBooks + Square + a CRM + an HR tool | $800–1,500+/mo combined |
| Email + productivity | Microsoft 365 Business Standard | ~$750/mo (this one is kept, see above) |
| File sync/share | Dropbox/Google Drive Business | ~$900/mo |
| Password manager | Bitwarden/1Password Business | ~$480/mo |
| Helpdesk | Zendesk/Freshdesk | ~$300–600/mo |
| VoIP | RingCentral/8x8 | ~$1,000–1,500/mo |
| Monitoring/SIEM | Datadog + a SIEM SaaS | $1,000+/mo easily |

That's a plausible **$4,000–6,000+/month** in stacked SaaS fees for the equivalent functionality — against roughly **$650–700/month recurring** plus a one-time ~$16K hardware spend in this design (keeping the productivity suite as the one SaaS exception). The trade-off is real and worth stating plainly: **self-hosting trades a recurring dollar cost for an ongoing time/expertise cost** — someone has to patch, back up, and operate all of this. This design assumes that's the one IT generalist role described in [00 — Company Profile](00-company-profile.md), and everything from [02](02-server-infrastructure.md) through [07](07-disaster-recovery.md) is built specifically to keep that operable by one person.

## Payback framing

Roughly: **$15,800 one-time hardware ÷ ~$3,300–5,300/month in avoided SaaS fees ≈ paid back inside the first 3–5 months**, with the hardware then amortizing over its realistic 4–5 year service life while recurring costs stay near-flat. This is the core financial argument for the whole design, not just a side note.
