# ADR-0002: Site-to-site VPN — WireGuard over IPsec

**Status:** Accepted
**Affects:** [01 — Network Architecture](../01-network-architecture.md#site-to-site-vpn), [`configs/pfsense/wireguard-site-to-site.conf.sample`](../../configs/pfsense/wireguard-site-to-site.conf.sample)

## Context

Both branches need a persistent, always-up tunnel back to HQ carrying AD auth, file access, VoIP, and POS traffic. The realistic options on pfSense: **IPsec** (the traditional site-to-site standard, what most commercial UTMs push as default), **OpenVPN** (mature, widely deployed, TLS-based), and **WireGuard** (modern, minimal, kernel-level on most platforms).

## Decision

Use **WireGuard**, hub-and-spoke, HQ as hub.

## Rationale

- **Config simplicity:** a WireGuard peer definition is ~5 lines (key, allowed IPs, endpoint, keepalive). IPsec site-to-site between two different admins' worth of Phase 1/Phase 2 proposals (encryption, hashing, DH group, lifetimes, PFS) is a well-known source of "why won't this tunnel come up" debugging sessions — especially painful for a solo IT generalist without a peer to sanity-check config against.
- **Throughput on modest hardware:** WireGuard's in-kernel (or heavily optimized userspace) implementation meaningfully outperforms IPsec/OpenVPN on the kind of small-appliance hardware branch sites actually get budgeted ([08 — Cost & BOM](../08-cost-and-bom.md)) — this matters when VoIP and POS traffic share the tunnel and are latency-sensitive.
- **Smaller attack surface:** WireGuard's codebase is a small fraction of IPsec's (strongSwan/racoon) or OpenVPN's — fewer negotiated parameters, fewer historical CVEs, easier to reason about from a security-review standpoint.

## Consequences

- **No native pfSense GUI maturity at the level of IPsec's**, historically — WireGuard support in pfSense is newer than IPsec's, which has been battle-tested in that platform far longer. This is called out explicitly rather than glossed over: pick a pfSense version confirmed to have stable WireGuard support before committing to this design in a real deployment.
- **No built-in MFA on the tunnel itself.** Site-to-site WireGuard authenticates by keypair only — there's no username/password/TOTP challenge at the tunnel layer (this is normal for site-to-site VPNs generally, IPsec included, but worth stating: the security boundary here is "who holds the private key," not an interactively-verified identity). This is why [03 — Identity & Access](../03-identity-and-access.md#remote-access) keeps the *road-warrior* (human, remote-user) VPN on a separate profile with MFA enforced at the SSO layer behind it — the site-to-site tunnel and the human-remote-access tunnel are deliberately different trust models, not the same mechanism reused.
- **Key management is manual at this scale.** Three sites means three keypairs to generate, distribute, and rotate if ever compromised — trivial to track by hand at 3 sites, but this doesn't scale gracefully past a handful of sites without a config-management layer (e.g. Ansible) generating and distributing peer configs.

## Revisit if

The site count grows past what's comfortable to hand-manage (roughly 5–8 sites), at which point either a WireGuard config-generation tool/mesh manager or a move to a full IPsec/SD-WAN overlay with centralized management becomes worth the added complexity.
