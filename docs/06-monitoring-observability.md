# 06 — Monitoring & Observability

See also: [02 — Server Infrastructure](02-server-infrastructure.md), [05 — Security Architecture](05-security-architecture.md) (Wazuh is the security-event counterpart to this doc's health/performance monitoring)

## Design goal

The business requirement from [00 — Company Profile](00-company-profile.md) is blunt: **IT should know a branch's internet is down before the branch calls to say so.** Everything here is built around that — proactive alerting, not a dashboard nobody looks at.

## Stack: Zabbix + Grafana

- `mon01` runs both. **Zabbix** does the actual monitoring/polling/alerting engine work; **Grafana** sits on top as the dashboard layer, querying Zabbix as a data source for the boards people actually look at day to day.
- Why this pairing over one tool alone: Zabbix's alerting/trigger engine is more mature for infrastructure monitoring than Grafana's alerting alone, but Grafana's dashboards are far nicer to actually look at than Zabbix's native frontend — using both plays to each one's strength.

## What's monitored

| Layer | Method | Key checks |
|---|---|---|
| Firewalls (all 3 sites) | SNMP + Zabbix agent | WAN link state, failover-to-LTE events, VPN tunnel up/down, CPU/memory, IDS alert volume |
| Switches & APs | SNMP | Port errors/discards, PoE budget, client count per SSID |
| Proxmox hosts | Zabbix agent + Proxmox API | CPU/RAM/storage utilization, cluster quorum state, replication lag between nodes |
| Every VM | Zabbix agent | Disk space, CPU, memory, service-specific checks (is Postfix accepting mail, is ERPNext responding, is Samba AD DC healthy) |
| Backup jobs | Zabbix agent + PBS API | Last successful backup time per VM — alerts if any VM hasn't backed up in >26 hours |
| UPS | SNMP/USB monitoring | Battery status, on-battery events, runtime remaining |

## Alerting philosophy

- **Tiered severity:** informational (log only), warning (daily digest email), critical (immediate push — email + Slack/webhook), disaster (immediate + repeats until acknowledged — e.g. a site WAN down or a domain controller unreachable).
- **Dependency-aware alerting:** Zabbix trigger dependencies mean if a branch's WAN link goes down, IT gets *one* alert for the WAN, not fifteen follow-on alerts for every device behind it going unreachable. This matters as much for a one-person IT team as the detection itself — alert fatigue is how real outages get missed.
- **Thresholds tuned to this business, not defaults:** e.g. disk-space warning at 80% / critical at 90% on server VMs, but the backup-target NAS gets a lower critical threshold (85%) since it fills predictably and running out silently breaks the entire DR chain ([07](07-disaster-recovery.md)).

## Dashboards (Grafana)

- **NOC overview board:** all 3 sites' WAN/VPN status, Proxmox cluster health, at-a-glance red/yellow/green — meant to be the first thing IT glances at each morning.
- **Capacity board:** storage/CPU/RAM trends over 90 days, used to plan hardware upgrades before something runs out rather than after.
- **Business-hours board:** POS terminal reachability and ERPNext response time during store hours specifically — the metric that maps most directly to "can the branches actually sell right now."

## Log aggregation vs. SIEM — the split

Zabbix/Grafana here answers *"is everything healthy and performing?"*; Wazuh ([05 — Security Architecture](05-security-architecture.md)) answers *"did something bad happen?"* — deliberately separate concerns rather than one tool trying to do both, even though both pull from largely the same set of hosts.
