# Infrastructure as Code — building the server layer

The rest of this repo describes the design. This folder **builds** a slice of it: the server VMs from [02 — Server Infrastructure](../docs/02-server-infrastructure.md), from an empty Proxmox cluster to domain-joined, monitored, patched hosts running their app stacks.

```
terraform apply          →  12 VMs on the HQ Proxmox cluster (static IPs, VLAN 20, cloud-init)
                         →  writes ansible/inventory/hosts.yml
ansible-playbook site.yml →  baseline hardening → AD join → Wazuh agent → Docker → app stacks
```

## What each layer owns

| Layer | Owns | Doesn't own |
|---|---|---|
| [**Terraform**](terraform/) | VM existence and shape: CPU/RAM/disk, node placement, VLAN, IP, MAC, the Debian 13 cloud image, first-boot user | Anything inside the OS |
| [**Ansible**](ansible/) | Everything inside the OS, re-applied on every run so drift gets corrected | VM lifecycle |

The handoff is a file, not a convention: Terraform renders [`ansible/inventory/hosts.yml`](ansible/inventory/hosts.yml) from the same VM list it provisions (`local.vm_specs` in [`main.tf`](terraform/main.tf)). One list drives the VM, its IP, its Ansible groups, and which app stack it runs, so they can't disagree.

## The VM list

| VM | IP | Node | vCPU / RAM | Ansible groups | Stack deployed |
|---|---|---|---|---|---|
| `dc01` / `dc02` | .11 / .12 | 01 / 02 | 2 / 4 GB | `domain_controllers`, `critical` | — |
| `erp01` | .13 | 01 | 4 / 16 GB | `member_servers`, `app_hosts`, `critical` | — |
| `files01` | .14 | 02 | 4 / 8 GB + 500 GB data disk | `member_servers`, `app_hosts` | [Nextcloud](../configs/docker-compose/nextcloud.yml) |
| `mail01` | .15 | 02 | 4 / 8 GB | `member_servers`, `app_hosts` | [Mailcow](../configs/docker-compose/mailcow/) |
| `vault01` | .16 | 01 | 1 / 2 GB | `member_servers`, `app_hosts`, `critical` | [Vaultwarden](../configs/docker-compose/vaultwarden.yml) |
| `mon01` | .20 | 01 | 2 / 4 GB | `member_servers`, `app_hosts` | [Zabbix + Grafana](../configs/docker-compose/monitoring-stack.yml) |
| `siem01` | .21 | 02 | 8 / 16 GB | `member_servers`, `app_hosts` | [Wazuh](../configs/docker-compose/wazuh/) |
| `wiki01`, `helpdesk01`, `voip01`, `web01` | .17–.19, .22 | split | 1–4 / 2–8 GB | `member_servers` (+ `app_hosts`) | — |

IPs are `10.10.20.x`. VM ID = `20` + last octet (e.g. `dc01` → 2011), and MACs follow the [Kea reservations](../configs/dhcp/kea-dhcp4.conf.sample), so a VM ID or MAC in a log tells you which server it is. Total RAM is ~78 GB across two 64 GB nodes, and the `critical` tier (25 GB) fits on either node alone, so one node can be patched or fail without losing auth, passwords, or the ERP.

`pbs01` and `nas01` are deliberately absent. They're physical boxes outside the cluster, so neither a cluster failure nor a bad `terraform apply` can reach the backups ([07](../docs/07-disaster-recovery.md)).

## What the playbook does

| Role | Runs on | Does |
|---|---|---|
| [`baseline`](ansible/roles/baseline/) | all | Hostname/FQDN, updates, unattended security upgrades (no auto-reboot — `mon01` alerts instead), SSH hardening (keys only, no root), chrony (DCs sync upstream, everything else syncs to the DCs), data-disk mount |
| [`domain_join`](ansible/roles/domain_join/) | `member_servers` | `realm join` into `OU=Servers` with a join-only service account; sssd restricted to `GRP-ITAdmins`, who also get sudo |
| [`wazuh_agent`](ansible/roles/wazuh_agent/) | all except `siem01` | Agent pinned to the manager's exact version and held, so patching can't break manager/agent compatibility |
| [`docker`](ansible/roles/docker/) | `app_hosts` | Docker Engine from Docker's repo, log rotation, `live-restore`, data-root on the data disk when there is one |
| [`app_stack`](ansible/roles/app_stack/) | hosts with `compose_stack` | Deploys the **same files** in [`configs/docker-compose/`](../configs/docker-compose/), with secrets rendered from the vault into `.env` |

## Running it

Prerequisites, once per cluster: a `terraform@pve` API token, the `terraform` SSH user on each node, and the `local` datastore allowing **Import** and **Snippets** content.

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars        # add the Ansible SSH public key
export TF_VAR_proxmox_api_token='terraform@pve!provision=…'
terraform init && terraform apply

cd ../ansible
ansible-galaxy collection install -r requirements.yml
pip install passlib bcrypt                         # for the Wazuh password hashing
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml   # after filling it in
ansible-playbook site.yml --ask-vault-pass
```

No secrets live in Git. The API token comes from the environment, app passwords live in an ansible-vault file that's gitignored, and Terraform state (VM IDs and MACs, no credentials) stays local.

## Deliberately out of scope

- **Promoting the first Samba AD DC.** `samba-tool domain provision` is a one-time, judgement-heavy step (realm, DNS backend, forest functional level) that's done by hand per [03](../docs/03-identity-and-access.md). The DCs get the baseline and the Wazuh agent; everything that joins the domain runs after it exists.
- **ERPNext, Zammad, BookStack, FreePBX, WordPress.** Their hosts are provisioned, hardened, joined, and have Docker ready, but the app installs aren't automated here yet. `compose_stack` is the hook for adding each one.
- **Proxmox host config and ZFS replication jobs.** Those are set up once on the two nodes, not per VM.

CI runs `terraform fmt`/`validate`, `ansible-lint`, and a syntax check on every push ([`lint.yml`](../.github/workflows/lint.yml)).
