# Wazuh — Deployment Note

Design context: [05 — Security Architecture](../../docs/05-security-architecture.md#siem--edr-wazuh)

Like Mailcow, Wazuh publishes its own official multi-container Compose bundle (indexer, manager, dashboard — an OpenSearch-based stack with specific certificate bootstrapping steps) that's best deployed from upstream rather than hand-rolled, so this is documented as steps rather than a standalone `docker-compose.yml`.

## Deploy on `siem01`

```bash
git clone https://github.com/wazuh/wazuh-docker -b v4.9.0
cd wazuh-docker/single-node
# Generate the required indexer TLS certificates (one-time)
docker compose -f generate-indexer-certs.yml run --rm generator
docker compose up -d
```

## Agent rollout (mapped to this repo's design)

| Target | Method |
|---|---|
| All 14 server VMs ([02 — Server Infrastructure](../../docs/02-server-infrastructure.md#the-14-vm-service-map)) | Wazuh agent installed at VM template stage, so every new VM ships with it already registered |
| Windows workstations (all 3 sites) | Agent MSI pushed via AD GPO software deployment ([03](../../docs/03-identity-and-access.md)) |
| pfSense firewalls (all 3 sites) | Syslog forwarding to `siem01`, parsed via Wazuh's pfSense/Suricata log decoders |

## Key rule groups enabled

- File integrity monitoring on `dc01`/`dc02` (AD database, SYSVOL) and every service VM's config directories
- Authentication failure correlation (brute-force detection) across AD, SSH, and the SSO gateway (Authelia)
- Active response: automatic local firewall block after repeated failed auth attempts against a monitored service
- AD privileged-group-membership change alerting — immediate notification, not a daily digest

Full rationale: [05 — Security Architecture](../../docs/05-security-architecture.md#siem--edr-wazuh). Firewall rules permitting agent→manager traffic (TCP 1514/1515) and syslog forwarding: [`configs/pfsense/firewall-rules-hq.md`](../pfsense/firewall-rules-hq.md).
