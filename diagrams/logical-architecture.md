# Logical Software Architecture

Full design context: [02 — Server Infrastructure](../docs/02-server-infrastructure.md), [04 — Software Stack](../docs/04-software-stack.md)

## Every service, and how users reach it

```mermaid
flowchart TB
    subgraph Users["Users"]
        HQU[HQ Staff]
        BRU[Branch Staff / POS]
        REM[Remote / Roaming Staff]
        PUB[Public Internet]
    end

    subgraph Edge["Edge (HQ pfSense)"]
        RP[Reverse Proxy + WAF<br/>Caddy/NGINX]
        VPN[WireGuard Road-Warrior<br/>+ MFA]
    end

    subgraph Identity["Identity (03)"]
        AD[Samba AD DC<br/>dc01 / dc02]
        SSO[Authelia SSO Gateway]
    end

    subgraph Apps["Proxmox Cluster — Business Apps (02, 04)"]
        ERP[ERPNext<br/>Accounting / Inventory / HR / CRM / POS]
        FILES[Nextcloud<br/>File Sync/Share]
        MAIL[Mailcow<br/>Email]
        VAULT[Vaultwarden<br/>Passwords]
        WIKI[BookStack<br/>Docs/SOPs]
        HELP[Zammad<br/>Helpdesk]
        VOIP[FreePBX<br/>Phones]
        WEB[WordPress<br/>Public Site]
    end

    subgraph Ops["Ops & Security (05, 06, 07)"]
        MON[Zabbix + Grafana]
        SIEM[Wazuh SIEM/EDR]
        BAK[Proxmox Backup Server<br/>+ TrueNAS + Offsite]
    end

    HQU --> AD
    HQU --> SSO
    BRU --> ERP
    REM --> VPN --> SSO
    PUB --> RP --> WEB
    PUB -.contact/orders.-> RP -.-> MAIL

    SSO --> ERP & FILES & MAIL & VAULT & WIKI & HELP
    AD --- SSO

    ERP --- VOIP
    Apps -.agents.-> SIEM
    Apps -.metrics.-> MON
    Apps -.nightly.-> BAK

    style Identity fill:#eef5ff,stroke:#3b6fb6
    style Ops fill:#fff5e8,stroke:#b9761f
    style Edge fill:#f5f0ff,stroke:#7a4fc9
```

## Read this diagram as

- **One identity, one login.** Samba AD is the source of truth for who staff are; Authelia sits in front of every self-hosted web app as an SSO + MFA gateway, so staff log in once instead of juggling per-app passwords. Detail: [03 — Identity & Access](../docs/03-identity-and-access.md).
- **Branch staff and POS terminals talk to ERPNext directly** over the site-to-site VPN (not through the public internet) — this is the same ERPNext instance serving accounting, inventory, HR, CRM, *and* the POS terminals at both branches.
- **Remote/roaming staff** (e.g. a manager working from home) connect via a separate WireGuard road-warrior profile with MFA, landing behind the same SSO gateway as everyone else — no special-cased access path.
- **The public internet only ever reaches two things**: the reverse-proxied public website, and inbound email — everything else is unreachable from outside without a VPN connection first.
- **Every app is watched two ways**: metrics/uptime by Zabbix+Grafana ([06](../docs/06-monitoring-observability.md)), security events by Wazuh ([05](../docs/05-security-architecture.md)) — and everything backs up nightly to Proxmox Backup Server, replicated onward per the [DR plan](../docs/07-disaster-recovery.md).
