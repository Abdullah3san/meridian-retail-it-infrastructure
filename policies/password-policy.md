# Password & Access Policy — Meridian Retail Group (Sample)

Design context: [03 — Identity & Access](../docs/03-identity-and-access.md)

*Sample policy matching this repo's technical design — adapt with legal/HR review before real-world use.*

## Password requirements (AD domain accounts)

Enforced via AD fine-grained password policy (GPO):

| Setting | Value | Rationale |
|---|---|---|
| Minimum length | 14 characters | Length beats complexity rules for real-world resistance to cracking |
| Complexity | Required (mix of character classes) | Baseline AD default, kept |
| Maximum age | None (no forced periodic rotation) | Forced rotation drives weak, predictable patterns (`Summer2024!` → `Summer2025!`) — modern guidance (NIST 800-63B) favors length + breach monitoring over rotation |
| Account lockout | 10 failed attempts / 15 min lockout window | Balances brute-force resistance against accidental lockout from typos |
| Breach monitoring | Wazuh alerts on repeated auth failures against AD | See [05 — Security Architecture](../docs/05-security-architecture.md#siem--edr-wazuh) |

## Multi-factor authentication

- Required for: all IT-admin accounts, any access via the remote-access VPN, and the ERPNext accounting module — enforced at the Authelia SSO layer ([03 — Identity & Access](../docs/03-identity-and-access.md#single-sign-on-authelia)).
- TOTP-based (authenticator app), not SMS — SMS is vulnerable to SIM-swap attacks and isn't used anywhere in this design.
- Recovery codes issued at enrollment, stored by the user in their personal Vaultwarden vault — not held by IT (IT can reset/re-enroll MFA via the AD-verified helpdesk process instead).

## Password manager

- **Vaultwarden** is the required tool for any credential not covered by SSO (vendor portals, per-service admin logins) — see [04 — Software Stack](../docs/04-software-stack.md#vaultwarden--password-management).
- Browser-saved passwords and personal password managers are disallowed for company credentials.
- IT-admin/service-account credentials live in a separate, more restricted Vaultwarden collection, accessible only to the `GRP-ITAdmins` AD group.

## Privileged access

- No standard staff account has local admin rights on workstations (GPO-enforced, [05 — Security Architecture](../docs/05-security-architecture.md#endpoint-security)).
- IT-admin accounts are **separate** from an admin's day-to-day account — day-to-day email/browsing happens on a standard account; elevated tasks (server admin, AD changes) use a dedicated admin account, reducing the blast radius if the daily-use account is ever phished.
- Every privileged AD group membership change triggers an immediate Wazuh alert ([05](../docs/05-security-architecture.md#siem--edr-wazuh)).

## Account lifecycle

Full process: [03 — Identity & Access § Joiner / mover / leaver process](../docs/03-identity-and-access.md#joiner--mover--leaver-process).

- Leaver accounts are **disabled same-day**, not deleted, and retained disabled for **90 days** (audit trail / smooth handoff of any pending work) before deletion.
- Vaultwarden org access is revoked immediately on account disable — a disabled AD account cannot authenticate to the SSO gateway that fronts Vaultwarden.
