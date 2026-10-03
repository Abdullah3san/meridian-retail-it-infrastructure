# Security Zones & Data Flow

Full design context: [05 — Security Architecture](../docs/05-security-architecture.md)

## Trust boundaries and traffic flow

```mermaid
flowchart TB
    INET((Public Internet))

    subgraph DMZ["DMZ — HQ (low trust)"]
        RP[Reverse Proxy<br/>TLS termination]
    end

    subgraph SRV["Servers VLAN 20 — HQ (high trust)"]
        WEB[web01 WordPress]
        MAILV[mail01 Mailcow]
        ERP[erp01 ERPNext]
        AD[dc01/dc02 AD]
        OTHER[files01 / wiki01 / helpdesk01 / voip01 / vault01]
        BAKV[pbs01 / nas01]
        SIEMV[siem01 Wazuh]
        MONV[mon01 Zabbix]
    end

    subgraph STAFFZ["Staff / Warehouse / VoIP (trusted)"]
        STAFF[Staff Workstations]
    end

    subgraph POSZ["POS — Branches (restricted, PCI)"]
        POS[POS Terminals]
    end

    subgraph GUESTZ["Guest / IoT (untrusted)"]
        GUEST[Guest WiFi]
        CCTV[CCTV / IoT]
    end

    INET -->|TLS 443 only| RP
    RP -->|proxied, single port| WEB
    RP -->|proxied, single port| MAILV
    INET -.SMTP 25.-> MAILV

    STAFF <-->|SSO + app ports| OTHER
    STAFF <-->|SSO + app ports| ERP
    STAFF <-->|Kerberos/LDAP| AD

    POS ==>|ERP POS API only, over VPN| ERP
    POS -.P2PE ciphertext, TLS 443.-> PROC[(Payment processor)]

    SRV -.agents/logs.-> SIEMV
    SRV -.metrics.-> MONV
    SRV -.nightly backup.-> BAKV

    GUEST -.internet only, isolated.-> INET
    CCTV -.no route.-x SRV
    CCTV -.no route.-x STAFF

    style DMZ fill:#fff5e8,stroke:#b9761f
    style SRV fill:#eef5ff,stroke:#3b6fb6
    style POSZ fill:#fff8e0,stroke:#b9950a
    style GUESTZ fill:#fff0f0,stroke:#c0392b
```

## Read this diagram as

- **The DMZ is a chokepoint, not a shortcut.** The only path from the public internet to any internal server is through the reverse proxy, and the reverse proxy itself can only reach the one backend port it's meant to proxy — a compromised `web01` or reverse proxy still can't pivot to `erp01` or the domain controllers.
- **POS traffic is two narrow arrows** — the ERPNext POS API over the site-to-site VPN, and the card readers' P2PE-encrypted link to the payment processor, nothing else. Card data is encrypted inside the reader ([ADR-0008](../docs/adr/0008-p2pe-terminals-for-pci-scope.md)), so those arrows are the second layer of the PCI control referenced in [00 — Company Profile](../docs/00-company-profile.md) and detailed in [05 — Security Architecture](../docs/05-security-architecture.md#vlan-to-vlan-policy).
- **CCTV/IoT has hard "no route" edges (✗)** to both the server VLAN and staff VLAN — not "restricted," but architecturally absent. Even a fully compromised camera has nowhere to go except the isolated VLAN it's already on.
- **Every server-side node feeds three ops systems** (Wazuh for security, Zabbix for health, Proxmox Backup Server for recovery) regardless of what the service does — visibility and recoverability are baked into the platform, not bolted on per-app.
