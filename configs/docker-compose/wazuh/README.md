# Wazuh — SIEM / EDR on `siem01`

Design context: [05 — Security Architecture](../../../docs/05-security-architecture.md#siem--edr-wazuh)

Wazuh publishes an official multi-container bundle (indexer, manager, dashboard — OpenSearch-based, with its own TLS bootstrapping). Rather than hand-copy it and drift out of date, this design runs **upstream's `single-node` stack unmodified at a pinned release** and layers its own changes on top:

| File | What it changes |
|---|---|
| [`docker-compose.override.yml`](docker-compose.override.yml) | Real passwords from `.env` instead of upstream's demo ones; indexer (9200) not published at all; API and dashboard bound to localhost behind the reverse proxy + SSO; indexer heap sized for `siem01` |
| [`ossec-meridian.conf`](ossec-meridian.conf) | Manager additions: syslog intake from the three pfSense firewalls, SSH brute-force active response |

Compose loads `docker-compose.override.yml` automatically when it sits next to upstream's `docker-compose.yml`. CI checks that the two still merge cleanly against the pinned release.

## Deploy

Automated by [`iac/ansible`](../../../iac/ansible/) (`roles/app_stack/tasks/wazuh.yml`) — that role is the source of truth. The manual equivalent:

```bash
sysctl -w vm.max_map_count=262144                 # indexer won't start below this
git clone https://github.com/wazuh/wazuh-docker -b v4.14.8
cd wazuh-docker/single-node
cp <this repo>/configs/docker-compose/wazuh/docker-compose.override.yml .
cat <this repo>/configs/docker-compose/wazuh/ossec-meridian.conf >> config/wazuh_cluster/wazuh_manager.conf
docker compose -f generate-indexer-certs.yml run --rm generator   # one-time TLS certs
# Before first start: put bcrypt hashes of the real passwords into
# config/wazuh_indexer/internal_users.yml (admin, kibanaserver) and the API
# password into config/wazuh_dashboard/wazuh.yml, then create .env.
docker compose up -d
```

The password step must happen **before first start**: the indexer seeds its users from `internal_users.yml` only while its data volume is empty. Ansible does this automatically; done by hand later, it needs upstream's `securityadmin.sh` procedure instead.

## Upgrades

Manager and agents are upgraded together, deliberately — an agent newer than its manager is unsupported. Bump `wazuh_version` in [`group_vars/all/main.yml`](../../../iac/ansible/inventory/group_vars/all/main.yml) and the pinned tag above; the agent package is held (`dpkg hold`) so unattended-upgrades can't move it on its own.

## Agent rollout

| Target | Method |
|---|---|
| All Linux server VMs ([02](../../../docs/02-server-infrastructure.md#the-14-vm-service-map)) | `wazuh_agent` Ansible role — enrolled into the `servers` or `domain_controllers` agent group |
| Windows workstations (all 3 sites) | Agent MSI pushed via AD GPO software deployment ([03](../../../docs/03-identity-and-access.md)) |
| pfSense firewalls (all 3 sites) | Remote syslog to `siem01:514/udp`, source address set to each firewall's MGMT interface (see the note in [`ossec-meridian.conf`](ossec-meridian.conf)) |

## Detection coverage

- File integrity monitoring on `dc01`/`dc02` (AD database, SYSVOL) and every service VM's config directories
- Authentication-failure correlation (brute force) across AD, SSH, and the SSO gateway (Authelia)
- Active response: local firewall block for 10 minutes on the attacked host after an SSH brute-force pattern
- AD privileged-group-membership change alerting — immediate notification, not a daily digest

Firewall rules permitting agent → manager (TCP 1514/1515) and syslog (UDP 514): [`configs/pfsense/firewall-rules-hq.md`](../../pfsense/firewall-rules-hq.md).
