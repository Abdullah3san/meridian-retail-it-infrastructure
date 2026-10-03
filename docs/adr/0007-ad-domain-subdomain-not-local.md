# ADR-0007: AD domain is a subdomain of the public domain, not `.local`

**Status:** Accepted
**Affects:** [03 — Identity & Access](../03-identity-and-access.md#directory-samba-4-active-directory), [01 — Network Architecture](../01-network-architecture.md#dhcp--dns), [00 — Naming conventions](../00-company-profile.md#naming-conventions-used-throughout-this-repo), every config that references an internal hostname

## Context

Samba AD needs a DNS domain name, and it is effectively permanent: renaming an AD domain later means touching every domain-joined machine, every Kerberos principal, every service account, and every app pointed at the directory. Three options were on the table:

1. **A private pseudo-TLD** such as `meridianretail.local` — the old SBS-era habit, and what many small-business domains still use.
2. **The bare public domain** `meridianretail.com` for AD too ("same-name split-brain DNS").
3. **A dedicated subdomain of the public domain** — `corp.meridianretail.com`.

## Decision

The AD domain is **`corp.meridianretail.com`**, NetBIOS name **`MERIDIAN`**. The public `meridianretail.com` zone stays at the registrar/DNS host for the website and mail; the `corp.` subdomain is served only by the internal AD DNS servers (`dc01`/`dc02`) and is never published publicly.

## Rationale

- **`.local` is reserved for multicast DNS** (RFC 6762). macOS, iOS, and Linux (Avahi) send `.local` lookups to mDNS rather than unicast DNS, which produces slow or failed name resolution on exactly the non-Windows devices a retailer has plenty of (managers' iPhones/Macs, Linux-based POS and kiosk hardware). Microsoft's own guidance advises against single-label and `.local`-style AD names for the same reason.
- **Public certificates are impossible for `.local`.** No public CA will issue for a name nobody can prove ownership of. With a real subdomain, internal services (`files.corp.…`, `vault.corp.…`) can use real Let's Encrypt certificates via DNS-01 validation — no private CA to run, no "click through the certificate warning" habit to train out of staff.
- **A subdomain avoids the split-brain trap of option 2.** If AD owned the bare `meridianretail.com`, internal DNS would have to duplicate every public record (`www`, `mail`, MX, SPF) or internal users couldn't reach the company's own website — a classic, recurring SMB outage.
- **It's owned.** Any name under a domain the business has registered can't be claimed by someone else — unlike a made-up TLD that could later become real (as `.dev`, `.app`, and `.zip` did).

## Consequences

- **The public domain registration becomes critical infrastructure.** If `meridianretail.com` lapses, the AD namespace is orphaned. Mitigation: auto-renew with a multi-year term, registrar lock on, and renewal tracked in the IT calendar alongside certificate expiries ([06 — Monitoring](../06-monitoring-observability.md)).
- **Internal hostnames are longer** (`erp01.corp.meridianretail.com`). In practice DHCP hands out `corp.meridianretail.com` as the search domain ([`kea-dhcp4.conf.sample`](../../configs/dhcp/kea-dhcp4.conf.sample)), so staff and scripts can still use short names.
- **The `corp.` zone must never leak publicly.** No NS delegation for `corp.` is created in the public zone; branch firewalls forward it over the VPN to the DCs only ([01 — Network Architecture](../01-network-architecture.md#dhcp--dns)).

## Revisit if

The business moves identity to a cloud IdP ([ADR-0004](0004-samba-ad-over-cloud-idp.md) "revisit" path). Entra ID / Google Workspace would use the public `meridianretail.com` as the UPN suffix, which this design already supports by adding it as an alternative UPN suffix in AD.
