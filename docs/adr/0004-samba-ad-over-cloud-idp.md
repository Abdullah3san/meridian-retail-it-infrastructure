# ADR-0004: Identity — Samba 4 AD over a cloud identity provider

**Status:** Accepted
**Affects:** [03 — Identity & Access](../03-identity-and-access.md)

## Context

~60 staff on Windows workstations need centralized authentication, group policy, and a directory every app can authenticate against. Realistic options: **Samba 4 as an on-prem AD DC** (open-source, Kerberos/LDAP-compatible), **Microsoft Entra ID** (cloud-native, Microsoft's current direction, seat-licensed), or **a self-hosted alternative directory** (FreeIPA — strong on Linux/Kerberos, historically weaker on Windows GPO parity).

## Decision

Use **Samba 4 in AD DC mode**, on-prem, two domain controllers for redundancy.

## Rationale

- **Windows GPO parity:** Samba 4 AD DC supports the same Group Policy mechanism real Windows AD does — screen-lock policy, software deployment, drive mapping — which matters because staff use Windows workstations day to day ([00 — Company Profile](../00-company-profile.md)) and GPO is how those get centrally managed without a third-party MDM subscription.
- **Works when the internet doesn't.** A branch's domain-joined workstations can still authenticate locally against a reachable DC over the VPN even during an upstream ISP outage at HQ (as long as the branch's own local link and VPN tunnel are up) — a cloud IdP is a hard dependency on internet reachability for every single login, which conflicts with the branch-resilience requirement in [01 — Network Architecture](../01-network-architecture.md).
- **$0 licensing** at this scale, versus Entra ID P1 (needed for the conditional access / group-based licensing this design assumes) running a recurring per-seat cost.

## Consequences

- **Two directories to eventually reconcile, if the business ever adopts Microsoft 365** for productivity (see [04 — Software Stack](../04-software-stack.md#whats-deliberately-not-self-hosted): M365 Apps is kept as a deliberate SaaS exception). Entra ID Connect / hybrid sync would then be needed to reconcile on-prem Samba AD with a cloud tenant — an added integration layer this design doesn't currently need but would if that exception ever expands into full M365 identity federation.
- **Samba AD DC is not 1:1 feature-complete with Windows Server AD** — some advanced AD features (certain fine-grained trust relationship types, some newer AD schema extensions certain enterprise apps expect) aren't supported. For a single-domain, single-forest, ~60-user design this gap doesn't bite; it would need re-evaluation for a more complex AD topology.
- **No Microsoft support contract.** Same category of risk as ADR-0001 for pfSense — troubleshooting AD replication or Kerberos issues relies on community docs and the admin's own expertise, not a Microsoft Premier Support case.

## Revisit if

The business standardizes on Microsoft 365 broadly enough that a hybrid-identity (Entra Connect) or fully-cloud (Entra ID as sole IdP) model becomes the pragmatic choice — most likely to happen if branch-resilience-during-WAN-outage stops being a hard requirement (e.g. if branches get materially more reliable connectivity over time).
