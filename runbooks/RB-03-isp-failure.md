# RB-03 — ISP failure

**Severity:** SEV-3 on LTE failover with trading normal. SEV-2 if a branch is fully offline. **SEV-1** if HQ is unreachable, because every branch depends on it.
**Goal:** keep the stores selling, and know before they call.

## What actually breaks

Branches are thin and depend on HQ over WireGuard ([01](../docs/01-network-architecture.md)), and card payments need the branch's internet **and** `erp01` ([ADR-0008](../docs/adr/0008-p2pe-terminals-for-pci-scope.md)). So *where* the outage is matters more than how long it lasts.

| Scenario | Local network, DHCP, Wi-Fi | ERPNext POS | Card payments | Logins, files, phones |
|---|---|---|---|---|
| **A.** Branch primary down, LTE up | ✅ | ✅ over LTE | ✅ | ✅ |
| **B.** Branch fully offline | ✅ ([ADR-0006](../docs/adr/0006-dhcp-local-per-site.md)) | Offline mode only, if enabled | ❌ cash only* | Cached Windows logons only; no files or phones |
| **C.** HQ primary down, LTE up | ✅ | ⚠️ only if the branches can still reach HQ — see the gap below | ⚠️ same | ⚠️ same |
| **D.** HQ fully offline | ✅ | Offline mode only, if enabled | ❌ cash only* | Cached logons only; no files or phones; inbound email queues at senders |

\* Unless the processor contract enables an offline (store-and-forward) mode on the readers. Offline approvals are at the merchant's own risk of later declines, so it's the business owner's call, made in advance.

## Signs

Zabbix alerts on `mon01` ([06](../docs/06-monitoring-observability.md)). Dependency-aware, so one site outage produces one alert, not fifty:

- **"WAN failover to LTE"** on a firewall → scenario A or C
- **"VPN tunnel down"** plus the branch unreachable → scenario B
- **HQ itself unreachable**: `mon01` lives at HQ and can't alert while HQ is offline, so today the first signal is a store calling (gap 2 below fixes this)

## Scenario A — branch on LTE

1. Confirm in Zabbix that the tunnel came back over LTE. Ask the store to make a sale and a small test card payment.
2. **Open a fault with the ISP** using the circuit ID from the contact sheet. Write the ticket number in the incident record.
3. **Protect the LTE data allowance:** turn off guest Wi-Fi on the LTE link. On the branch firewall, the Guest VLAN's internet rule should use the **primary gateway only**, not the failover gateway group, so guests drop off automatically and business traffic keeps the LTE capacity. If it isn't set up that way yet, disable the guest SSID until the primary link is back.
4. Watch LTE data usage in Zabbix for as long as the failover lasts.

## Scenario B — branch fully offline

1. **Check it isn't the branch's own equipment**: the store manager confirms the firewall and ISP router have power and lights. Ask them to power-cycle the ISP router (not the firewall) once.
2. **Tell the store to switch to the offline plan**, decided in advance with the business owner: ERPNext POS offline mode, if it's set up, to record sales for syncing later, and **cash only** unless offline card mode is part of the processor contract.
3. Open faults with **both** the ISP and the LTE carrier (an LTE failure at the same time often means a local mast or power problem). Check both carriers' status pages.
4. Staff use mobile phones until VoIP is back.

## Scenario C — HQ on LTE

1. **Check immediately whether the branch tunnels re-established.** This depends on the HQ LTE link having a public, reachable IP (see the gap below). If both branch tunnels are up: treat as scenario A for HQ and keep watching.
2. If the branches **can't** reach HQ, handle each branch as scenario B for ERP and card payments: offline mode or cash only. Their local internet still works.
3. Remote staff on the road-warrior VPN will have dropped too. Tell them by phone or chat.
4. Open the HQ fault with the ISP as **business-critical**, and escalate if the SLA allows.

## Scenario D — HQ fully offline

1. Treat as SEV-1. Every branch goes to its offline plan (scenario B steps 2 and 4).
2. Check whether it's actually a power or hardware failure at HQ. On UPS, the server room has about 15 minutes ([02](../docs/02-server-infrastructure.md#physical-layer)). If it's a site disaster, switch to the DR runbook in [07](../docs/07-disaster-recovery.md#dr-runbook-full-hq-site-loss-summary).
3. Inbound email isn't lost: sending servers queue and retry for days. The public website (`web01`) is down until HQ is back.

## Verify before closing

- [ ] Primary link back and stable for 30 minutes; Zabbix shows the firewall back on the primary gateway
- [ ] All WireGuard tunnels up; branches can reach `erp01`
- [ ] Test card payment succeeds at each affected branch
- [ ] POS offline sales synced to ERPNext with no sync errors; cash reconciled
- [ ] Guest Wi-Fi re-enabled if it was turned off by hand

## Afterwards

- Record the outage length against the targets in [07](../docs/07-disaster-recovery.md#rto--rpo-targets), and claim any SLA credit from the ISP.
- If LTE failed at the same time, consider an LTE plan on a different carrier from the ISP.

## Known gaps this runbook exposes

Writing this down surfaced two weaknesses in the design. They're recorded here rather than hidden:

1. **HQ LTE failover may not restore the branch tunnels.** Branches connect to HQ's public address ([`wireguard-site-to-site.conf.sample`](../configs/pfsense/wireguard-site-to-site.conf.sample)). If HQ's LTE link sits behind carrier NAT, the branches can't reach it at all, and scenario C turns into D for every branch. **Fix:** an LTE plan with a static public IP at HQ, plus a second WireGuard tunnel on each branch pointing at that IP, used as a backup gateway (pfSense gateway groups switch routes when the primary tunnel's monitor fails).
2. **Nobody gets alerted when HQ itself is down.** `mon01` can't report its own site's outage. **Fix:** a free external uptime check (a cloud ping/HTTP monitor) against HQ's public IP and the public website, alerting the IT generalist's phone directly.
