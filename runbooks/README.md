# Incident Runbooks

Step-by-step responses to the three incidents most likely to hit a 3-site retailer with one IT person. They expand the lightweight detect → contain → recover → document process in [05 — Security Architecture](../docs/05-security-architecture.md#incident-response-lightweight-one-admin-operable), and together they form the incident response plan PCI DSS 12.10.1 asks for ([09](../docs/09-pci-dss-control-map.md)).

| Runbook | Typical trigger | Worst case |
|---|---|---|
| [RB-01 — Ransomware on a staff PC](RB-01-ransomware-staff-pc.md) | Defender/Wazuh alert, files renamed, ransom note | Spreads through shared folders to `files01`, or reaches a server |
| [RB-02 — Lost, stolen, or tampered POS device](RB-02-lost-or-tampered-pos-device.md) | Opening inspection fails, reader missing, unexpected "technician" | Skimmer overlay capturing cards before P2PE encryption |
| [RB-03 — ISP failure](RB-03-isp-failure.md) | Zabbix WAN/VPN alert, branch calls | HQ offline: every branch loses ERP, and with it card payments |

The canonical copies live in BookStack ([04](../docs/04-software-stack.md#bookstack--internal-wiki)), where store managers can reach them. These are the reviewed source versions.

## Severity

| Level | Meaning | Response |
|---|---|---|
| **SEV-1** | Possible card-data exposure, a server or DC compromised, or a whole site unable to trade | IT drops everything; owner informed within 30 min; external parties (processor, insurer) as each runbook says |
| **SEV-2** | Contained to one device or one degraded link; trading continues | IT responds within 1 hour during business hours |
| **SEV-3** | No business impact yet | Next business day |

Upgrade the severity the moment new facts justify it. Downgrade only after verification.

## Roles

There's one IT person, so roles are about **who decides**, not team size.

| Role | Who | Decides |
|---|---|---|
| Incident lead | IT generalist (backup: owner, using the printed contact sheet) | Technical containment and recovery |
| Business owner | Owner / general manager | Paying anything, talking to customers, closing a site, calling in outside help |
| Site contact | Store manager on shift | Cash-only trading, which counter to use, local evidence |

## Rules that apply to every incident

1. **Contain before you investigate.** Isolating a device costs minutes; letting something spread costs days.
2. **Preserve evidence.** Don't wipe, reimage, or "clean up" until the evidence below is captured. Insurers and payment brands may require it.
3. **Write as you go.** Start the incident record at the first step, with timestamps. It's quicker than reconstructing it afterwards.
4. **Never pay, negotiate, or contact an attacker** without the business owner and the cyber insurer.
5. **Don't contact customers or the press yourself.** That goes through the owner, and for card incidents the acquirer leads.

## Incident record

One BookStack page per incident, opened at step one and closed within 5 business days:

```
Incident:      <short title>                  Severity: SEV-<n>
Opened:        <date time>  by <name>         Closed: <date time>
Runbook:       RB-0<n>
Timeline:      <time> — <what happened / what was done / by whom>
Scope:         devices, accounts, data, sites affected
Evidence:      what was captured and where it's stored
Root cause:    how it started (or "unknown" + why)
Fixes:         what changes so it doesn't happen again — each with an owner and a date
```

## Before you need them

Keep these current, or every runbook slows down at the worst moment:

- **Contact sheet** (BookStack, and printed in each branch's back office): ISP circuit IDs and support numbers for all 3 sites, LTE carrier, payment processor merchant ID and fraud line, cyber insurer hotline and policy number, owner's mobile.
- **`QUARANTINE` alias and rules** pre-built on all three firewalls ([`firewall-rules-hq.md`](../configs/pfsense/firewall-rules-hq.md#floating-incident-quarantine-pre-staged-on-all-3-firewalls)).
- **Annual tabletop**: walk through RB-01 and RB-02 with store managers and time each step (PCI DSS 12.10.2).
