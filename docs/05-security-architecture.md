# 05 — Security Architecture

See also: [Security Zones & Data Flow](../diagrams/dataflow-security-zones.md), [VLAN Segmentation](../diagrams/vlan-segmentation.md), firewall rule samples in [`configs/pfsense/`](../configs/pfsense/)

## Design goals

1. Segmentation that actually contains a compromise, not just VLANs for VLANs' sake
2. PCI-relevant traffic isolated per the requirements in [00 — Company Profile](00-company-profile.md)
3. One place to see security events across all 3 sites
4. Defense in depth without requiring a dedicated security team — every control has to be operable by one IT generalist

## Perimeter

- **pfSense** at every site (see [01 — Network Architecture](01-network-architecture.md)) runs:
  - **Suricata** (IDS/IPS package) on the WAN interface, inline blocking mode at HQ, alert-only at branches (lower-powered branch hardware — HQ absorbs the heavier inspection load since all branch-to-internet traffic that matters routes through the same edge policy).
  - **pfBlockerNG** — DNS and IP-reputation blocklists (malware C2, known botnets) applied to all internal VLANs.
  - Default-deny outbound from server-facing VLANs — servers only reach the specific external endpoints they need (package updates, SMTP relay, offsite backup target), not the open internet.

## VLAN-to-VLAN policy

Full matrix and rationale: [VLAN Segmentation diagram](../diagrams/vlan-segmentation.md#inter-vlan-policy-summary). Key principles the firewall rules enforce:

- **Default deny between VLANs.** Every inter-VLAN allow is an explicit rule with a documented reason — there is no "allow LAN to any" rule anywhere in this design.
- **POS isolation (PCI):** the POS VLAN at each branch can reach exactly one destination outside itself — the ERPNext POS API port at HQ, over the VPN. No internet access, no access to other VLANs, no access to other branches.
- **CCTV/IoT isolation:** cameras and the NVR have no route to the internet and no route to staff/server VLANs. The NVR is the only device on that VLAN permitted an outbound rule (for cloud backup of footage, if used) — everything else is fully contained.
- **Guest isolation:** internet-only, with client isolation enabled at the AP so guest devices can't even see each other, let alone reach internal VLANs.
- **Native VLAN trap (VLAN 99):** switch trunk ports are explicitly set to an unused native VLAN. This closes the classic VLAN-hopping attack where an untagged frame lands on the default VLAN 1 and inherits more access than intended — VLAN 99 carries no traffic and has no firewall rules permitting anything, so a stray untagged frame goes nowhere.

Sample rule tables (HQ): [`configs/pfsense/firewall-rules-hq.md`](../configs/pfsense/firewall-rules-hq.md)

## DMZ / public-facing services

- The only two things reachable from the public internet are the WordPress site (`web01`) and inbound mail (`mail01`) — both sit behind a **reverse proxy** (Caddy/NGINX) on a thin DMZ VLAN, not directly on VLAN 20 with the rest of the internal servers.
- The reverse proxy terminates TLS (Let's Encrypt, auto-renewed), and the DMZ VLAN has a firewall rule permitting it to reach *only* the specific backend port on the specific VM it proxies to — a compromised reverse proxy still can't pivot to `erp01` or `dc01`.
- No inbound port-forward exists anywhere in this design except the two above (plus the two site-to-site VPN endpoints and the road-warrior VPN endpoint at HQ).

## SIEM / EDR: Wazuh

- `siem01` runs Wazuh manager, receiving agent telemetry from every server VM and (via GPO-deployed agent) every Windows workstation.
- Monitors: file integrity (critical config paths, AD database), authentication events (failed logins, especially repeated failures against AD or SSH), rootkit detection, and log correlation across all 3 sites' pfSense firewalls (syslog forwarded to `siem01`).
- Active response rules: auto-block an IP at the local firewall after N failed SSH/RDP attempts; alert IT immediately on any AD privileged-group membership change (a common early indicator of compromise).
- This is the single pane of glass required by [00 — Company Profile](00-company-profile.md) — one dashboard for security events across HQ and both branches instead of three separate firewall logs nobody reads.

## Endpoint security

- Windows workstations: Microsoft Defender (built-in, no extra licensing) + the Wazuh agent for centralized visibility and file-integrity/log correlation Defender alone doesn't provide.
- Linux server VMs: ClamAV for on-demand/scheduled scanning (mail attachments in particular, via Mailcow's built-in integration) + the Wazuh agent.
- No local admin rights for standard staff accounts (enforced by GPO, see [03](03-identity-and-access.md)) — the single highest-leverage endpoint control available, and free.

## Patching & hardening

- **Servers:** see [02 — Server Infrastructure](02-server-infrastructure.md#patch-management).
- **Windows workstations:** WSUS-equivalent update ring managed via GPO — pilot group gets updates first, broad rollout a week later if no issues. Critical/zero-day patches pushed immediately, ring policy bypassed.
- **Network gear:** firmware updates reviewed monthly, applied in an after-hours maintenance window; pfSense and switch configs backed up before every change.
- **CIS-benchmark-informed baseline** applied via GPO for Windows workstations (disable unused services, enforce SMB signing, restrict anonymous enumeration) and via a hardening checklist for each Linux VM template (so every new VM inherits the baseline from the start rather than being hardened after the fact).

## Remote access security

Covered in [03 — Identity & Access](03-identity-and-access.md#remote-access) — road-warrior VPN with per-user keys and enforced MFA via Authelia, landing on the same VLAN-based trust model as on-site devices.

## Incident response (lightweight, one-admin-operable)

1. **Detect** — Wazuh alert or Zabbix anomaly ([06](06-monitoring-observability.md)) triggers a notification (email/Slack webhook).
2. **Contain** — isolate the affected VLAN or host at the firewall (pre-written pfSense rule templates for "quarantine this subnet" kept ready, not written from scratch mid-incident).
3. **Eradicate/Recover** — restore affected VM(s) from the most recent known-good Proxmox Backup Server snapshot ([07 — Disaster Recovery](07-disaster-recovery.md)) rather than attempting to clean an unknown compromise in place.
4. **Document** — incident writeup added to BookStack ([04](04-software-stack.md)) so the next occurrence (or the next admin) has a reference.

This is intentionally simple — a formal IR retainer / external SOC is a reasonable next step as the business grows, but the design above is what's realistically operable at this scale today.
