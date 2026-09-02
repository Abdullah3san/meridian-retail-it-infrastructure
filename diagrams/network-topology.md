# Network Topology

Full design context: [01 — Network Architecture](../docs/01-network-architecture.md) · See also the single-page [Infrastructure Map](assets/infrastructure-map.svg) for a poster-style view of all 3 sites together.

## All 3 sites, WAN edges, and the VPN mesh

```mermaid
flowchart TB
    INET((Internet))

    subgraph HQ["HQ — Head Office"]
        direction TB
        ISP_HQ[Fiber ISP 200/200] --- FW_HQ[pfSense fw-hq]
        LTE_HQ[LTE Failover] -.backup.- FW_HQ
        FW_HQ --- SW_HQ[Core L3 Switch]
        SW_HQ --- AP_HQ[WiFi APs]
        SW_HQ --- SRV[Proxmox Cluster<br/>14 VMs — see 02-server-infrastructure]
        SW_HQ --- WH[Warehouse Terminals]
        SW_HQ --- STAFF_HQ[Staff Workstations]
        SW_HQ --- CCTV_HQ[CCTV / IoT]
        SW_HQ --- VOIP_HQ[VoIP Phones]
    end

    subgraph BRN["Branch North"]
        direction TB
        ISP_N[Fiber/Cable 100/50] --- FW_N[pfSense fw-north]
        LTE_N[LTE Failover] -.backup.- FW_N
        FW_N --- SW_N[Access Switch]
        SW_N --- AP_N[WiFi APs]
        SW_N --- POS_N[POS Terminals]
        SW_N --- BO_N[Back Office PCs]
        SW_N --- CCTV_N[CCTV]
    end

    subgraph BRS["Branch South"]
        direction TB
        ISP_S[Fiber/Cable 100/50] --- FW_S[pfSense fw-south]
        LTE_S[LTE Failover] -.backup.- FW_S
        FW_S --- SW_S[Access Switch]
        SW_S --- AP_S[WiFi APs]
        SW_S --- POS_S[POS Terminals]
        SW_S --- BO_S[Back Office PCs]
        SW_S --- CCTV_S[CCTV]
    end

    FW_HQ ===|WireGuard VPN hub| INET
    INET ===|WireGuard tunnel| FW_N
    INET ===|WireGuard tunnel| FW_S

    style HQ fill:#eef5ff,stroke:#3b6fb6
    style BRN fill:#f5fff0,stroke:#4a9c3f
    style BRS fill:#f5fff0,stroke:#4a9c3f
```

## Read this diagram as

- **HQ is the hub.** It holds the only server room and is the WireGuard hub both branches tunnel into (hub-and-spoke, not full mesh — branches never talk directly to each other).
- **Every site has WAN failover** (primary fiber/cable + LTE backup on pfSense multi-WAN), so a single ISP outage at any site doesn't take it fully offline.
- **Branches are thin sites.** No local servers beyond the firewall/switch/AP — everything (AD auth, ERP/POS backend, file shares, email, phones) is centrally hosted at HQ and reached over the VPN. Local DHCP/routing keeps branches functional for local traffic even if the HQ link drops (see [01 — Network Architecture](../docs/01-network-architecture.md#dhcp--dns)).
- **IP plan:** HQ = `10.10.0.0/16`, Branch North = `10.20.0.0/16`, Branch South = `10.30.0.0/16`. Full VLAN breakdown in [VLAN Segmentation](vlan-segmentation.md).
