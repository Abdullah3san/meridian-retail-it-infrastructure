# pfSense Firewall Rules — HQ (`fw-hq`)

Design context: [05 — Security Architecture](../../docs/05-security-architecture.md), [01 — Network Architecture](../../docs/01-network-architecture.md), [VLAN Segmentation diagram](../../diagrams/vlan-segmentation.md)

These are representative rule tables per interface/VLAN, in the order pfSense evaluates them (first match wins, default deny at the end of every interface). Written for readability, not as a raw pfSense XML export — adapt to your actual pfSense config via the GUI or `config.xml`.

## Interface: WAN

| # | Action | Proto | Source | Dest | Dest Port | Notes |
|---|---|---|---|---|---|---|
| 1 | Pass | UDP | any | WAN address | 51820 | WireGuard site-to-site (branches) |
| 2 | Pass | UDP | any | WAN address | 51821 | WireGuard road-warrior (remote staff) |
| 3 | Pass | TCP | any | DMZ RP (NAT) | 443 | Reverse proxy — WordPress + Mailcow webmail |
| 4 | Pass | TCP | any | DMZ RP (NAT) | 25 | SMTP inbound to Mailcow |
| 5 | Block | any | any | any | any | Default deny (implicit) |

## Interface: VLAN 10 — Management

| # | Action | Proto | Source | Dest | Dest Port | Notes |
|---|---|---|---|---|---|---|
| 1 | Pass | any | VLAN10 net | VLAN10 net | any | Mgmt devices talk to each other |
| 2 | Pass | TCP | VLAN10 net | Firewall | 443, 22 | Admin access to pfSense |
| 3 | Pass | TCP | VLAN10 net | VLAN20 net | 8006 | Proxmox web UI |
| 4 | Pass | any | VLAN10 net | WAN | any | Firmware/update checks |
| 5 | Block | any | VLAN10 net | VLAN30/40/50/60/70 | any | Mgmt does not reach user VLANs |
| 6 | Block | any | any | any | any | Default deny |

## Interface: VLAN 20 — Servers

| # | Action | Proto | Source | Dest | Dest Port | Notes |
|---|---|---|---|---|---|---|
| 1 | Pass | any | VLAN20 net | VLAN20 net | any | Server-to-server (ERP↔SSO, Mail↔AD, etc.) |
| 2 | Pass | TCP/UDP | VLAN20 net | VLAN20 (dc01/dc02) | 88,389,445,464,636 | Kerberos/LDAP/SMB to AD |
| 3 | Pass | TCP | VLAN30 net | VLAN20 (erp01/files01/wiki01/helpdesk01/vault01) | 443 | Staff → business apps (via SSO) |
| 4 | Pass | TCP | Branch POS nets (via VPN) | VLAN20 (erp01) | 8443 | POS API only — no other VLAN20 host |
| 5 | Pass | UDP | VLAN20 (voip01) | VLAN50 nets (all sites, via VPN) | 5060,10000-20000 | SIP/RTP |
| 6 | Pass | TCP | VLAN20 net | WAN (specific: updates, SMTP relay, cloud backup endpoint) | 443,587 | Outbound allow-list only — not "any" |
| 7 | Block | any | VLAN20 net | WAN | any | Everything else outbound denied |
| 8 | Block | any | VLAN60/70 net | VLAN20 net | any | Guest/IoT can never initiate to servers |
| 9 | Block | any | any | any | any | Default deny |

## Interface: VLAN 30 — Staff

| # | Action | Proto | Source | Dest | Dest Port | Notes |
|---|---|---|---|---|---|---|
| 1 | Pass | TCP | VLAN30 net | VLAN20 (app servers) | 443 | Business apps |
| 2 | Pass | TCP/UDP | VLAN30 net | VLAN20 (dc01/dc02) | 88,389,445,464,636,53 | Domain auth/DNS |
| 3 | Pass | any | VLAN30 net | WAN | 443,80,53 | General internet (filtered by pfBlockerNG) |
| 4 | Block | any | VLAN30 net | VLAN40/50/60/70 net | any | No lateral access to warehouse/VoIP/guest/IoT |
| 5 | Block | any | any | any | any | Default deny |

## Interface: VLAN 60 — Guest WiFi

| # | Action | Proto | Source | Dest | Dest Port | Notes |
|---|---|---|---|---|---|---|
| 1 | Block | any | VLAN60 net | VLAN10/20/30/40/50/70 net | any | No route to anything internal |
| 2 | Pass | any | VLAN60 net | WAN | 443,80,53 | Internet only |
| 3 | Block | any | any | any | any | Default deny |

## Interface: VLAN 70 — CCTV/IoT

| # | Action | Proto | Source | Dest | Dest Port | Notes |
|---|---|---|---|---|---|---|
| 1 | Pass | TCP | VLAN70 net (cameras) | VLAN70 (NVR only) | 554,80,443 | Cameras → NVR |
| 2 | Pass | TCP | VLAN70 (NVR only) | WAN (specific cloud-backup endpoint) | 443 | Optional cloud footage backup — NVR only, nothing else |
| 3 | Block | any | VLAN70 net | VLAN10/20/30/40/50/60 net | any | Fully isolated from everything else |
| 4 | Block | any | any | any | any | Default deny |

## Design notes

- **No rule anywhere reads "source: any VLAN, dest: any VLAN."** Every permitted path is named explicitly, matching the matrix in [VLAN Segmentation](../../diagrams/vlan-segmentation.md#inter-vlan-policy-summary).
- **Branch pfSense rule sets mirror this pattern** but are much shorter — a branch only needs POS→ERP (via VPN), Staff→internet+VPN-to-HQ-apps, Guest→internet, CCTV→NVR-local. See [01 — Network Architecture](../../docs/01-network-architecture.md) for the branch VLAN layout.
- **Outbound from Servers VLAN is allow-listed, not "any."** This is deliberate: if a server VM is ever compromised, it can't freely exfiltrate to an arbitrary internet host — only to the specific update mirrors, mail relay, and backup endpoint it's allowed to reach.
