# Mailcow — business email on `mail01`

Design context: [04 — Software Stack](../../../docs/04-software-stack.md#mailcow--business-email)

Mailcow runs ~15 containers (Postfix, Dovecot, Rspamd, SOGo, ClamAV, Redis, MariaDB, Nginx, …) whose Compose file is generated and upgraded by Mailcow's own tooling (`generate_config.sh`, `update.sh`). Every supported customisation goes through `mailcow.conf`, so that's what this repo commits: **[`mailcow.conf.overrides`](mailcow.conf.overrides)** — each setting this design changes, with the reason next to it. A copied `docker-compose.yml` would just drift behind upstream.

| Setting | Why |
|---|---|
| `MAILCOW_HOSTNAME=mail.meridianretail.com` | Public name for MX, SPF, and the TLS certificate ([ADR-0007](../../../docs/adr/0007-ad-domain-subdomain-not-local.md)) |
| POP3 / POP3S / ManageSieve bound to `127.0.0.1` | Staff use IMAP, ActiveSync, and webmail only, so the other protocols aren't exposed |
| `SKIP_CLAMD=n` | Attachment scanning ([05](../../../docs/05-security-architecture.md#endpoint-security)) |
| `ENABLE_IPV6=false` | Site network is IPv4-only; half-configured IPv6 is a known open-relay risk |
| `WATCHDOG_NOTIFY_EMAIL` | Container health alerts land in the same inbox as Zabbix ([06](../../../docs/06-monitoring-observability.md)) |

## Deploy

Automated by [`iac/ansible`](../../../iac/ansible/) (`roles/app_stack/tasks/mailcow.yml`): it clones Mailcow, runs `generate_config.sh` unattended on first run, enforces every line of `mailcow.conf.overrides` on each run, and recreates the containers only when a setting changed. The manual equivalent:

```bash
git clone https://github.com/mailcow/mailcow-dockerized /opt/mailcow-dockerized
cd /opt/mailcow-dockerized
MAILCOW_HOSTNAME=mail.meridianretail.com MAILCOW_TZ=Etc/UTC MAILCOW_BRANCH=master \
  SKIP_CLAMD=n ENABLE_IPV6=false ./generate_config.sh
# then set each KEY=VALUE from mailcow.conf.overrides in mailcow.conf
docker compose pull && docker compose up -d
```

Upgrades use Mailcow's own `./update.sh`, not Ansible. Ansible only re-checks that the settings above survived the upgrade.

## Post-deploy configuration (mapped to this repo's design)

| Step | Where it's covered |
|---|---|
| SPF/DKIM/DMARC records on the public DNS zone for `meridianretail.com` | Standard Mailcow DKIM key export → added as TXT records at the domain registrar |
| Mailbox provisioning synced to AD group membership | [03 — Identity & Access](../../../docs/03-identity-and-access.md) — mailboxes created/disabled alongside the joiner/mover/leaver process |
| Only reachable via the DMZ reverse proxy (443) + direct SMTP (25) | [05 — Security Architecture](../../../docs/05-security-architecture.md#dmz--public-facing-services) |
| Zammad ticket queues fed from `support@` / `it-help@` | [04 — Software Stack](../../../docs/04-software-stack.md#zammad--helpdesk--ticketing) |
| Wazuh agent + ClamAV scanning on the mail VM | [05 — Security Architecture](../../../docs/05-security-architecture.md#endpoint-security) |
| Backup: all Mailcow volumes (`mysql-vol-1`, `vmail-vol-1`, etc.) | Critical/standard tier per [07 — Disaster Recovery](../../../docs/07-disaster-recovery.md#backup-schedule--retention) — mail is business-critical, treated as near-critical tier alongside AD/ERP |

Firewall rules restricting `mail01`'s inbound/outbound to exactly what's needed: [`configs/pfsense/firewall-rules-hq.md`](../../pfsense/firewall-rules-hq.md).
