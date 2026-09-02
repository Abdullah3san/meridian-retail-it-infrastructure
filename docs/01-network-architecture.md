# 01 — Network Architecture

See also: [Network Topology Diagram](../diagrams/network-topology.md), [VLAN Segmentation Diagram](../diagrams/vlan-segmentation.md), config samples in [`configs/pfsense/`](../configs/pfsense/), [`configs/switch/`](../configs/switch/), [`configs/dhcp/`](../configs/dhcp/).

## Design goals

1. Every site can be administered remotely by one IT generalist
2. A branch losing WAN doesn't lose the ability to sell (local DHCP/routing, cached POS)
3. PCI-relevant traffic (POS) is on its own VLAN with no route to anything except the payment processor and the ERP server
4. Guest and IoT/CCTV traffic never touches the internal network
5. All three sites appear as one address space, routed cleanly, no overlapping subnets

## Topology overview

- **HQ** is the hub: it holds the server room, the primary internet breakout, and is the WireGuard hub for the two branches.
- **Branch North** and **Branch South** are spokes: each has a local firewall/router, a local switch, local WiFi, and a WireGuard tunnel back to HQ.
- All inter-site traffic (file access, AD auth, VoIP, POS→ERP) rides the site-to-site VPN — there is no direct branch-to-branch tunnel (hub-and-spoke), since branches never need to talk to each other directly.

## WAN edge

| Site | Primary ISP | Backup | Firewall/Router |
|---|---|---|---|
| HQ | Fiber (200/200 Mbps) | 4G/5G LTE failover (pfSense multi-WAN) | pfSense CE, dual-node CARP HA (optional, see below) |
| Branch North | Fiber/Cable (100/50 Mbps) | 4G/5G LTE failover | pfSense CE, single appliance |
| Branch South | Fiber/Cable (100/50 Mbps) | 4G/5G LTE failover | pfSense CE, single appliance |

**HQ high availability (optional upgrade path):** two pfSense boxes in CARP (Common Address Redundancy Protocol) sharing a virtual IP, with `pfsync` for state table replication. This is the standard pfSense HA pattern and is called out here as the next step once the business can justify a second HQ firewall — the base design assumes a single HQ firewall.

Each firewall does: NAT/routing, stateful firewall, WireGuard VPN endpoint, DHCP for local VLANs, DNS resolver (Unbound) forwarding internal-zone queries to the HQ AD DNS server, and IDS/IPS (Suricata package). See [05 — Security Architecture](05-security-architecture.md) for firewall rule design and IDS details.

## Site-to-site VPN

**WireGuard, hub-and-spoke, HQ as hub.** Chosen over IPsec/OpenVPN for simplicity of config, modern crypto by default, and much better throughput on modest branch hardware.

- HQ pfSense holds a WireGuard interface with one peer per branch
- Each branch pfSense holds a single WireGuard peer pointed at HQ's public IP
- Routes: each branch advertises its local VLAN subnets to HQ; HQ advertises the full `10.0.0.0/8` summary back so branches can reach every HQ VLAN they're permitted to (permission is enforced by firewall rules, not by what the tunnel can reach — see below)
- Keepalive set to 25s so NAT mappings on both ends stay open
- A sample working config (keys redacted) is in [`configs/pfsense/wireguard-site-to-site.conf.sample`](../configs/pfsense/wireguard-site-to-site.conf.sample)

**Important distinction:** the VPN tunnel makes subnets *reachable*; the firewall rules decide what's *permitted*. A branch's POS VLAN can reach HQ over the tunnel, but firewall rules only allow it to reach the ERP server's POS API port — nothing else. This is why segmentation lives in the firewall rule tables, not in the routing table.

## IP addressing plan

Each site gets its own `/16` out of the `10.x.0.0/16` private range so there's zero renumbering risk if a 4th site is added later. Each VLAN is a `/24` inside that.

| Site | Site block |
|---|---|
| HQ | `10.10.0.0/16` |
| Branch North | `10.20.0.0/16` |
| Branch South | `10.30.0.0/16` |

### HQ VLANs (`10.10.x.0/24`)

| VLAN | Name | Subnet | Purpose |
|---|---|---|---|
| 10 | Management | 10.10.10.0/24 | Switches, APs, firewall mgmt, iDRAC/IPMI, Proxmox mgmt |
| 20 | Servers | 10.10.20.0/24 | All Proxmox VMs — see [02 — Server Infrastructure](02-server-infrastructure.md) |
| 30 | Staff | 10.10.30.0/24 | Admin, Finance, HR, IT workstations |
| 40 | Warehouse/Ops | 10.10.40.0/24 | Warehouse scanners, label printers, ops terminals |
| 50 | VoIP | 10.10.50.0/24 | Desk phones, FreePBX signaling/media |
| 60 | Guest WiFi | 10.10.60.0/24 | Visitor internet only, fully isolated |
| 70 | CCTV/IoT | 10.10.70.0/24 | Cameras, NVR, smart building devices — no internet route |
| 99 | Native/Unused | 10.10.99.0/24 | Switch trunk native VLAN, intentionally unused (see [05](05-security-architecture.md)) |

### Branch VLANs (North: `10.20.x.0/24`, South: `10.30.x.0/24` — identical layout)

| VLAN | Name | Subnet (North) | Subnet (South) | Purpose |
|---|---|---|---|---|
| 10 | Management | 10.20.10.0/24 | 10.30.10.0/24 | Switch/AP/firewall mgmt |
| 30 | POS/Retail | 10.20.30.0/24 | 10.30.30.0/24 | Point-of-sale terminals and card readers only |
| 40 | Staff/Back Office | 10.20.40.0/24 | 10.30.40.0/24 | Back-office PCs, receiving terminal |
| 50 | VoIP | 10.20.50.0/24 | 10.30.50.0/24 | Desk/cordless phones |
| 60 | Guest WiFi | 10.20.60.0/24 | 10.30.60.0/24 | Customer WiFi |
| 70 | CCTV/IoT | 10.20.70.0/24 | 10.30.70.0/24 | In-store cameras |

Full inter-VLAN allow/deny matrix is in [05 — Security Architecture](05-security-architecture.md#vlan-to-vlan-policy).

## LAN switching

- **HQ:** one L3-capable core switch (handles inter-VLAN routing for east-west traffic that doesn't need to hit the firewall) + stacked/uplinked L2 access switches for port density. Server room uplinks are LACP (2×1G or better) to Proxmox hosts.
- **Branches:** a single managed L2/L3 switch is sufficient at this scale — VLAN routing for the branch happens on the branch pfSense box, keeping the branch switch config simple (VLAN tagging/trunking only).
- All access ports are configured with a single **access VLAN** (never trunk to an end-user device); trunk ports (to APs, other switches, firewall) explicitly tag only the VLANs they need, and native VLAN is set to the unused VLAN 99 (see [05 — Security Architecture](05-security-architecture.md) for why).
- Sample access/trunk config: [`configs/switch/vlan-config-sample.txt`](../configs/switch/vlan-config-sample.txt)

## WiFi

- Access points are VLAN-aware, broadcasting separate SSIDs mapped to separate VLANs: `Meridian-Staff` (tagged to Staff VLAN, WPA2/3-Enterprise via RADIUS against AD — see [03](03-identity-and-access.md)) and `Meridian-Guest` (tagged to Guest VLAN, WPA2-PSK with a rotating passphrase, client isolation on).
- Any OpenWRT-compatible or VLAN-capable commercial AP works here; the design is vendor-agnostic on purpose so it isn't tied to one manufacturer's ecosystem.

## DHCP & DNS

- **DHCP:** each site's pfSense runs DHCP locally for its own VLANs (via the ISC/Kea DHCP package). This is a deliberate resilience choice — if the WAN/VPN link to HQ is down, branch devices still get leases and local routing keeps working. Sample Kea config: [`configs/dhcp/kea-dhcp4.conf.sample`](../configs/dhcp/kea-dhcp4.conf.sample).
- **DNS:** each firewall runs Unbound as a local resolver. Queries for `meridianretail.local` are forwarded over the VPN to the HQ AD DNS servers (Samba, see [03](03-identity-and-access.md)); everything else resolves via DNS-over-TLS upstream, filtered through pfBlockerNG for malware/ad domains (see [05](05-security-architecture.md)).

## Why this design, not the alternatives

| Decision | Alternative considered | Why this won |
|---|---|---|
| pfSense over a commercial UTM appliance | Fortinet/Ubiquiti/SonicWall | No per-feature licensing, full IDS/IPS + VPN included, huge community for a solo IT admin to lean on |
| WireGuard over IPsec/OpenVPN | Site-to-site IPsec | Far simpler config, better throughput on low-power branch hardware, fewer interop quirks between vendors |
| DHCP local per site over centralized DHCP relay | Central DHCP server at HQ | Branches keep working during a WAN outage — a business requirement, not a nice-to-have |
| `/16` per site over one flat `/24` | Single shared subnet | Zero collision risk when adding a 4th site; each site's VLANs are self-contained and easy to reason about |
