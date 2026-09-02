# VLAN Segmentation

Full design context: [01 — Network Architecture](../docs/01-network-architecture.md#ip-addressing-plan), firewall policy detail: [05 — Security Architecture](../docs/05-security-architecture.md#vlan-to-vlan-policy)

## HQ VLAN layout

```mermaid
flowchart LR
    subgraph FW["fw-hq (pfSense)"]
    end

    FW --- V10["VLAN 10 — Management<br/>10.10.10.0/24"]
    FW --- V20["VLAN 20 — Servers<br/>10.10.20.0/24"]
    FW --- V30["VLAN 30 — Staff<br/>10.10.30.0/24"]
    FW --- V40["VLAN 40 — Warehouse/Ops<br/>10.10.40.0/24"]
    FW --- V50["VLAN 50 — VoIP<br/>10.10.50.0/24"]
    FW --- V60["VLAN 60 — Guest WiFi<br/>10.10.60.0/24"]
    FW --- V70["VLAN 70 — CCTV/IoT<br/>10.10.70.0/24"]
    FW --- V99["VLAN 99 — Native/Unused<br/>10.10.99.0/24"]

    style V60 fill:#fff0f0,stroke:#c0392b
    style V70 fill:#fff0f0,stroke:#c0392b
    style V99 fill:#f0f0f0,stroke:#888
```

## Branch VLAN layout (North shown — South identical, `10.30.x.0/24`)

```mermaid
flowchart LR
    subgraph FWN["fw-north (pfSense)"]
    end

    FWN --- N10["VLAN 10 — Management<br/>10.20.10.0/24"]
    FWN --- N30["VLAN 30 — POS/Retail<br/>10.20.30.0/24"]
    FWN --- N40["VLAN 40 — Staff/Back Office<br/>10.20.40.0/24"]
    FWN --- N50["VLAN 50 — VoIP<br/>10.20.50.0/24"]
    FWN --- N60["VLAN 60 — Guest WiFi<br/>10.20.60.0/24"]
    FWN --- N70["VLAN 70 — CCTV<br/>10.20.70.0/24"]

    style N30 fill:#fff8e0,stroke:#b9950a
    style N60 fill:#fff0f0,stroke:#c0392b
    style N70 fill:#fff0f0,stroke:#c0392b
```

**Color key:** red = fully isolated from internal network (guest, CCTV/IoT — internet/NVR only, no route to staff/server VLANs); amber = PCI-sensitive, allowed only to the specific ERP POS API port at HQ, nothing else.

## Inter-VLAN policy summary

| From ↓ / To → | Servers (HQ) | Staff | Warehouse | VoIP | POS (branch) | Guest | CCTV/IoT | Internet |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Staff | ✅ (app ports) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Warehouse/Ops | ✅ (ERP only) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| POS (branch) | ✅ (ERP POS API only) | ❌ | ❌ | ❌ | ✅ (same site) | ❌ | ❌ | ❌ |
| VoIP | ✅ (SIP/RTP to PBX only) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Guest WiFi | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (isolated) | ❌ | ✅ |
| CCTV/IoT | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (NVR only) | ❌ |
| Management | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (updates only) |

This matrix is enforced by explicit firewall rules on each site's pfSense — the VPN tunnel makes subnets *reachable* across sites, but these rules decide what's actually *permitted*. Full rule tables: [`configs/pfsense/firewall-rules-hq.md`](../configs/pfsense/firewall-rules-hq.md) and [05 — Security Architecture](../docs/05-security-architecture.md).
