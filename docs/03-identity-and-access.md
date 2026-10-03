# 03 — Identity & Access Management

See also: [Logical Software Architecture](../diagrams/logical-architecture.md), [05 — Security Architecture](05-security-architecture.md), [policies/password-policy.md](../policies/password-policy.md). Full trade-off reasoning: [ADR-0004 — Samba 4 AD over a cloud identity provider](adr/0004-samba-ad-over-cloud-idp.md).

## Design goals

1. One identity per person, one place to disable it when they leave
2. MFA enforced everywhere it can be — VPN, SSO gateway, admin access
3. Windows-compatible directory (staff use Windows workstations day to day) at $0 licensing
4. Every self-hosted app authenticates against the same directory instead of keeping its own user table

## Directory: Samba 4 Active Directory

- `dc01` (primary) and `dc02` (secondary, different Proxmox node) run **Samba 4 in AD DC mode** — a real, Kerberos/LDAP-compatible Active Directory implementation, not a lookalike. Windows machines domain-join to it exactly as they would to Windows Server AD.
- Domain: `corp.meridianretail.com` (NetBIOS `MERIDIAN`) — a subdomain of the public `meridianretail.com`, never `.local`; reasoning in [ADR-0007](adr/0007-ad-domain-subdomain-not-local.md). Both DCs are also authoritative internal DNS for the domain (see [01 — Network Architecture](01-network-architecture.md#dhcp--dns)).
- Organizational Units mirror the org: `OU=HQ`, `OU=BranchNorth`, `OU=BranchSouth`, each with `Staff`, `Workstations`, and role-based security groups (`GRP-Finance`, `GRP-Warehouse`, `GRP-POS`, `GRP-ITAdmins`, …).
- Group Policy (GPO) enforces: screen lock after 10 minutes idle, disallow local admin for standard staff, drive mappings to Nextcloud/departmental shares, Windows Update deferral rings (IT tests updates on a pilot group before broad rollout).
- Why Samba AD instead of a cloud directory (Entra ID/Google Workspace) as the *primary* source of truth: it's free, it works when the internet is down (local auth for domain-joined machines), and it's what on-prem file/print/VoIP infrastructure expects. Cloud IdPs are a valid alternative if the business later goes fully cloud-first — noted as a future option, not the current design.

## Single sign-on: Authelia

- **Authelia** sits in front of every self-hosted web app (ERPNext, Nextcloud, BookStack, Zammad, Grafana, etc.) as a forward-auth layer behind the reverse proxy.
- Authelia authenticates against the same Samba AD via LDAP — so a staff member's AD account *is* their login for every app, and disabling that one AD account locks them out of everything at once.
- **MFA (TOTP)** is enforced by Authelia policy for: any admin-group account, any access originating outside the internal VLANs (i.e. anyone coming in over the road-warrior VPN), and the ERPNext accounting module specifically.
- Session policy: 8-hour SSO session for internal network access, re-auth required for sensitive apps (accounting) after 2 hours idle.

## Remote access

- Roaming/remote staff connect via a **separate WireGuard "road-warrior" VPN profile** on HQ's pfSense (distinct from the site-to-site tunnels in [01](01-network-architecture.md)) — each user gets their own keypair, revocable individually.
- pfSense's OpenVPN alternative with the Google Authenticator (TOTP) RADIUS package is documented as a fallback for any device that can't run a WireGuard client (kept for completeness — WireGuard is the default).
- Once connected, remote staff land on a dedicated Remote-Access VLAN with the *same* firewall restrictions as if they were a Staff-VLAN device on-site — VPN access doesn't grant extra trust, it just relocates them onto the network they'd already have rights on.

## Password & secrets management

- **Vaultwarden** (Bitwarden-compatible, self-hosted) is the company password manager for anything that isn't AD-integrated SSO — vendor portals, ISP logins, per-service admin credentials.
- IT-admin and service-account credentials (Proxmox root, pfSense admin, DB root passwords) live in a separate, more restricted Vaultwarden "IT Admin" org/collection, not in the general-staff vault.
- Full policy: [policies/password-policy.md](../policies/password-policy.md).

## Joiner / mover / leaver process

| Event | Action |
|---|---|
| **Joiner** | IT creates AD account in the correct OU + security groups → Authelia/SSO access follows automatically from group membership → Vaultwarden org invite sent → workstation domain-joined |
| **Mover** (role change) | AD security group membership updated → app access changes automatically (nothing to touch per-app) |
| **Leaver** | AD account disabled (not deleted, for audit trail) same day → this alone revokes SSO to every app, VPN access, and email login → Vaultwarden org access revoked → account deleted after 90 days per [policies/password-policy.md](../policies/password-policy.md) |

The single-directory design is what makes the leaver process a *one-click* action instead of a checklist across a dozen admin panels — this is one of the biggest practical wins of centralizing identity.
