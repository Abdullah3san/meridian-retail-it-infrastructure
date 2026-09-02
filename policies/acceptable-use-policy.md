# Acceptable Use Policy — Meridian Retail Group (Sample)

Design context: [03 — Identity & Access](../docs/03-identity-and-access.md), [05 — Security Architecture](../docs/05-security-architecture.md)

*This is a sample policy document written to match the technical design in this repo — it's meant to show the paperwork side of an IT program, not to be legal advice. Adapt with actual legal/HR review before use.*

## Scope

Applies to all staff, contractors, and any device connecting to Meridian Retail Group networks or systems at HQ, Branch North, or Branch South.

## Account use

- Company accounts (AD login, email, SSO) are for business use and are individually assigned — no shared logins.
- Staff are responsible for all activity under their account. Suspected compromise must be reported to IT immediately (see [helpdesk process](../docs/04-software-stack.md#zammad--helpdesk--ticketing)).
- MFA, once enrolled, must not be disabled or bypassed without IT approval.

## Acceptable use

- Company systems are provided for business purposes; incidental personal use (checking personal email, brief browsing) is permitted within reason and does not interfere with work or company security.
- No installation of unapproved software on company workstations — request additions through the helpdesk.
- No use of personal cloud storage, personal email, or unapproved messaging apps for company data — company file sharing goes through Nextcloud ([04 — Software Stack](../docs/04-software-stack.md#nextcloud--file-sync--share)).
- No connecting personal storage devices (USB drives, phones for file transfer) to POS terminals or servers.

## Network use

- Guest WiFi is for visitors only — staff use the Staff SSID, which requires domain credentials ([01 — Network Architecture](../docs/01-network-architecture.md#wifi)).
- No connecting unauthorized devices (personal routers, access points, switches) to any company network jack — this can create a rogue bridge across the segmentation described in [05 — Security Architecture](../docs/05-security-architecture.md).
- Remote access is only via the company-issued VPN profile ([03 — Identity & Access](../docs/03-identity-and-access.md#remote-access)).

## Data handling

- Customer payment card data must never be stored, emailed, or entered anywhere outside the certified payment processor integration ([04 — Software Stack](../docs/04-software-stack.md#whats-deliberately-not-self-hosted)).
- Company documents belong in Nextcloud or ERPNext, not local-only files on a single workstation with no backup coverage.

## Enforcement

Violations are handled per standard HR process. Security-relevant violations (e.g. disabling MFA, connecting unauthorized network devices) are logged via [Wazuh](../docs/05-security-architecture.md#siem--edr-wazuh) and reviewed by IT.

## Acknowledgment

All staff acknowledge this policy at onboarding, as part of the [joiner process](../docs/03-identity-and-access.md#joiner--mover--leaver-process).
