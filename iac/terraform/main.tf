# Provisions the server VMs from docs/02-server-infrastructure.md on the HQ
# Proxmox cluster, then writes the Ansible inventory that configures them.
#
# pbs01 and nas01 are deliberately NOT here: they're separate physical boxes
# outside the cluster, so a broken cluster (or a bad `terraform apply`) can
# never take the backup target down with it (docs/02, docs/07).

locals {
  # One entry per VM. `octet` drives the IP (10.10.20.<octet>), the VM ID
  # (20<octet> — VLAN 20 + host), and the MAC, so all three line up with the
  # Kea reservations in configs/dhcp/kea-dhcp4.conf.sample.
  #
  # Sizing check: ~78 GB RAM total across two 64 GB nodes. The critical tier
  # (dc01, dc02, erp01, vault01 = 25 GB) fits on either node alone, which
  # is what lets one node be patched or fail without losing auth or the ERP.
  vm_specs = {
    dc01       = { octet = 11, node = "pve-hq-01", cores = 2, memory = 4096, disk = 32, critical = true, groups = ["domain_controllers"] }
    dc02       = { octet = 12, node = "pve-hq-02", cores = 2, memory = 4096, disk = 32, critical = true, groups = ["domain_controllers"] }
    erp01      = { octet = 13, node = "pve-hq-01", cores = 4, memory = 16384, disk = 100, critical = true, groups = ["member_servers", "app_hosts"] }
    files01    = { octet = 14, node = "pve-hq-02", cores = 4, memory = 8192, disk = 32, data_disk = 500, groups = ["member_servers", "app_hosts"], stack = "nextcloud" }
    mail01     = { octet = 15, node = "pve-hq-02", cores = 4, memory = 8192, disk = 100, groups = ["member_servers", "app_hosts"], stack = "mailcow" }
    vault01    = { octet = 16, node = "pve-hq-01", cores = 1, memory = 2048, disk = 16, critical = true, groups = ["member_servers", "app_hosts"], stack = "vaultwarden" }
    wiki01     = { octet = 17, node = "pve-hq-02", cores = 2, memory = 2048, disk = 32, groups = ["member_servers", "app_hosts"] }
    helpdesk01 = { octet = 18, node = "pve-hq-02", cores = 4, memory = 8192, disk = 64, groups = ["member_servers", "app_hosts"] }
    voip01     = { octet = 19, node = "pve-hq-01", cores = 2, memory = 4096, disk = 32, groups = ["member_servers"] }
    mon01      = { octet = 20, node = "pve-hq-01", cores = 2, memory = 4096, disk = 64, groups = ["member_servers", "app_hosts"], stack = "monitoring" }
    siem01     = { octet = 21, node = "pve-hq-02", cores = 8, memory = 16384, disk = 250, groups = ["member_servers", "app_hosts"], stack = "wazuh" }
    web01      = { octet = 22, node = "pve-hq-01", cores = 2, memory = 2048, disk = 32, groups = ["member_servers", "app_hosts"] }
  }

  # Fill in optional fields so every VM has the same shape (for_each needs a map).
  vms = {
    for name, spec in local.vm_specs : name => merge(
      { critical = false, data_disk = null, stack = null },
      spec,
    )
  }
}

# --- Base image + bootstrap config, one copy per node (local datastores) ---

resource "proxmox_download_file" "debian" {
  for_each = toset(var.nodes)

  node_name    = each.key
  datastore_id = var.image_datastore
  content_type = "import"
  url          = var.debian_image_url
  file_name    = "debian-13-genericcloud-amd64.qcow2"
  overwrite    = false # Re-pulling "latest" on every apply would churn every VM disk
}

# Minimal first-boot config: just enough for Ansible to take over. Everything
# else (hardening, domain join, agents) lives in Ansible so it can be
# re-applied to drift, not only run once at birth.
resource "proxmox_virtual_environment_file" "bootstrap" {
  for_each = toset(var.nodes)

  node_name    = each.key
  datastore_id = var.image_datastore
  content_type = "snippets"

  source_raw {
    file_name = "meridian-bootstrap.yaml"
    data      = <<-EOT
      #cloud-config
      users:
        - name: ansible
          groups: [sudo]
          shell: /bin/bash
          sudo: "ALL=(ALL) NOPASSWD:ALL"
          lock_passwd: true
          ssh_authorized_keys:
            - ${trimspace(var.ansible_ssh_public_key)}
      ssh_pwauth: false
      disable_root: true
      package_update: true
      packages: [qemu-guest-agent]
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
  }
}

# --- The VMs ---

resource "proxmox_virtual_environment_vm" "server" {
  for_each = local.vms

  name        = each.key
  description = "Managed by Terraform — iac/terraform. Config: iac/ansible."
  node_name   = each.value.node
  vm_id       = 2000 + each.value.octet
  tags        = concat(["terraform", "vlan20"], each.value.critical ? ["critical"] : [])

  on_boot         = true
  stop_on_destroy = true

  agent {
    enabled = true # qemu-guest-agent is installed by the bootstrap snippet
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  # Debian cloud images log to the serial console; without one, boot can hang.
  serial_device {}

  disk {
    datastore_id = var.vm_datastore
    import_from  = proxmox_download_file.debian[each.value.node].id
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
    iothread     = true
  }

  # Separate data disk where the service has bulk data (Nextcloud user files),
  # so the OS disk stays small and data can be resized or moved on its own.
  dynamic "disk" {
    for_each = each.value.data_disk == null ? [] : [each.value.data_disk]
    content {
      datastore_id = var.vm_datastore
      interface    = "scsi1"
      size         = disk.value
      discard      = "on"
      iothread     = true
    }
  }

  network_device {
    bridge      = "vmbr0"
    vlan_id     = 20
    mac_address = format("AA:BB:CC:00:20:%02X", each.value.octet - 10)
  }

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.bootstrap[each.value.node].id

    ip_config {
      ipv4 {
        address = "10.10.20.${each.value.octet}/24"
        gateway = var.servers_gateway
      }
    }

    dns {
      domain = var.domain
      # The DCs can't resolve via themselves before Samba is provisioned,
      # so they start on the firewall's resolver; Ansible repoints them.
      servers = contains(each.value.groups, "domain_controllers") ? [var.servers_gateway] : ["10.10.20.11", "10.10.20.12"]
    }
  }

  lifecycle {
    # A newer cloud image must not trigger a rebuild of running servers —
    # existing VMs are patched in place by Ansible/unattended-upgrades.
    ignore_changes = [disk[0].import_from]
  }
}

# --- Hand-off to Ansible ---

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    vms    = local.vms
    domain = var.domain
    groups = sort(distinct(flatten([for vm in values(local.vms) : vm.groups])))
  })
}
