# ADR-0001: Firewall/router platform — pfSense over a commercial UTM appliance

**Status:** Accepted
**Affects:** [01 — Network Architecture](../01-network-architecture.md), [05 — Security Architecture](../05-security-architecture.md), [08 — Cost & BOM](../08-cost-and-bom.md)

## Context

Every site needs a firewall/router doing NAT, stateful firewalling, VLAN routing, site-to-site VPN, and IDS/IPS. Three real options were on the table:

- **pfSense CE** (open-source, FreeBSD-based) on commodity/appliance hardware
- **A commercial UTM appliance** — Fortinet FortiGate, SonicWall, or similar, with per-feature/per-year licensing
- **Ubiquiti UniFi** gear — cheaper, simpler, good UX, but a shallower firewall/IDS feature set and a more consumer-oriented security model

## Decision

Use **pfSense CE** at all three sites.

## Rationale

- **Cost:** UTM licensing at this scale (IDS/IPS + VPN + AV subscription tiers) commonly runs $400–1,500/year *per site*, recurring forever. pfSense CE's IDS (Suricata) and VPN (WireGuard) are included, free, community-maintained packages — see [08 — Cost & BOM](../08-cost-and-bom.md) for how much this matters at 3 sites over a 5-year hardware life.
- **Feature depth:** pfSense's rule engine, multi-WAN/failover, and package ecosystem (pfBlockerNG, Suricata) are enterprise-grade — UniFi's firewall is comparatively basic, and Ubiquiti's cloud-dependency model (UniFi OS / cloud console) doesn't fit "operable when the internet is down," a requirement from [00 — Company Profile](../00-company-profile.md).
- **Community & documentation:** for a solo IT generalist ([00](../00-company-profile.md)) without a vendor support contract, pfSense's documentation and community size matter more than a vendor TAC line that isn't in the budget anyway.

## Consequences

**Accepted trade-offs, stated plainly — this is not a free lunch:**

- **No vendor support contract.** If something breaks at 2am, there's no TAC to call — the on-call answer is community forums, the FreeBSD/pfSense docs, and the admin's own troubleshooting. This is a real risk at a business this size with one IT person, and is why [05 — Security Architecture](../05-security-architecture.md#incident-response-lightweight-one-admin-operable) keeps the incident-response process deliberately simple and pre-planned rather than assuming expert-level improvisation under pressure.
- **Hardware is BYO.** Unlike a UTM appliance, pfSense doesn't come with vetted hardware — the business is responsible for picking compatible, adequately-sized hardware (NIC compatibility with FreeBSD in particular is a known pfSense gotcha) and for physical warranty/RMA on that hardware separately from the software.
- **No single-vendor accountability.** If a security incident happens, there's no UTM vendor to point to — the design and its consequences are fully owned in-house. Considered acceptable here specifically because of the open-source-first requirement set in [00](../00-company-profile.md), but this is a genuine trade against a commercial UTM's "one throat to choke."

## Revisit if

The business scales to a size where a formal support SLA becomes worth paying for, or where PCI-DSS scope expands enough that a vendor compliance attestation (common with commercial UTMs) becomes a contractual requirement from a payment partner.
