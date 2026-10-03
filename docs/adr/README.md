# Architecture Decision Records

An ADR captures a decision *at the moment it was made* — the options actually on the table, why one won, and what it costs. The rest of this repo's `docs/` describes the system as it stands; these describe the reasoning that got it there, including the trade-offs a clean design doc tends to smooth over.

Format follows the standard lightweight ADR template (context → decision → consequences), one file per decision.

| # | Decision | Status |
|---|---|---|
| [0001](0001-pfsense-over-commercial-utm.md) | Firewall/router platform: pfSense over a commercial UTM appliance | Accepted |
| [0002](0002-wireguard-over-ipsec.md) | Site-to-site VPN: WireGuard over IPsec | Accepted |
| [0003](0003-proxmox-over-vmware.md) | Virtualization platform: Proxmox VE over VMware vSphere | Accepted |
| [0004](0004-samba-ad-over-cloud-idp.md) | Identity: Samba 4 AD over a cloud identity provider | Accepted |
| [0005](0005-erpnext-over-point-solutions.md) | Business systems: ERPNext over point-solution SaaS | Accepted |
| [0006](0006-dhcp-local-per-site.md) | DHCP served locally per site instead of centralized at HQ | Accepted |
| [0007](0007-ad-domain-subdomain-not-local.md) | AD domain: `corp.` subdomain of the public domain, not `.local` | Accepted |

Each ADR is referenced from the design doc it affects — e.g. ADR-0001 is linked from [01 — Network Architecture](../01-network-architecture.md#why-this-design-not-the-alternatives).
