# ADR-0006: DHCP served locally per site instead of centralized at HQ

**Status:** Accepted
**Affects:** [01 — Network Architecture](../01-network-architecture.md#dhcp--dns), [`configs/dhcp/kea-dhcp4.conf.sample`](../../configs/dhcp/kea-dhcp4.conf.sample)

## Context

With everything else in this design centralized at HQ (identity, ERP, file storage, email — see [02 — Server Infrastructure](../02-server-infrastructure.md)), DHCP could plausibly follow the same pattern: one central DHCP server, with branches relaying requests over the VPN. The alternative is each site's own firewall serving DHCP for its own local VLANs independently.

## Decision

Each site's pfSense serves DHCP **locally**, independently, for its own VLANs.

## Rationale

- **This is the one deliberate exception to "centralize everything at HQ,"** and it's driven by a specific, named business requirement from [00 — Company Profile](../00-company-profile.md): *"a branch losing WAN doesn't lose the ability to sell."* If DHCP relayed to HQ and the HQ link dropped, new leases (a rebooted POS terminal, a new device joining WiFi) would fail branch-wide during exactly the outage window when the branch most needs to keep operating.
- **DHCP relay adds a dependency for no real benefit here.** Centralizing DHCP mainly pays off when there's a strong reason to manage leases/reservations from one pane of glass across many sites — at 3 sites with a handful of static reservations each ([`kea-dhcp4.conf.sample`](../../configs/dhcp/kea-dhcp4.conf.sample)), that benefit is marginal next to the resilience cost of the dependency.

## Consequences

- **Three DHCP configs to keep consistent instead of one.** If a VLAN's scope or option needs to change (e.g. a new DNS forwarder), it has to be changed at each site individually rather than in one central place — a manual-consistency burden that's small at 3 sites but wouldn't stay small if the site count grew significantly.
- **No single lease-visibility pane.** Troubleshooting "what got which IP" means checking the specific site's firewall rather than one central DHCP server's lease table — mitigated in practice by [Zabbix monitoring](../06-monitoring-observability.md) pulling health checks from every site's firewall into one dashboard, but the raw lease data itself is still per-site.

## Revisit if

The site count grows enough that per-site config drift becomes a recurring problem — at which point a config-management tool (Ansible pushing a templated Kea config to every site) would preserve the local-resilience property while solving the consistency problem, rather than centralizing DHCP itself.
