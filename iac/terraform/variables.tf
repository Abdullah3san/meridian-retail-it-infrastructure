variable "proxmox_endpoint" {
  description = "Proxmox VE API URL — any node of the HQ cluster."
  type        = string
  default     = "https://pve-hq-01.corp.meridianretail.com:8006/"
}

variable "proxmox_api_token" {
  description = "API token in the form 'terraform@pve!provision=<uuid>'. Supply via TF_VAR_proxmox_api_token."
  type        = string
  sensitive   = true
}

variable "nodes" {
  description = "Proxmox cluster nodes (docs/02 — 2-node cluster, rack elevation)."
  type        = list(string)
  default     = ["pve-hq-01", "pve-hq-02"]
}

variable "vm_datastore" {
  description = "Datastore for VM disks — local ZFS per node, replicated for critical VMs (docs/02)."
  type        = string
  default     = "local-zfs"
}

variable "image_datastore" {
  description = "Datastore holding the cloud image and cloud-init snippets. Needs the 'Import' and 'Snippets' content types enabled."
  type        = string
  default     = "local"
}

variable "debian_image_url" {
  description = "Debian 13 generic cloud image — the base for every server VM."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "ansible_ssh_public_key" {
  description = "Public key for the 'ansible' bootstrap user that cloud-init creates on every VM."
  type        = string
}

variable "servers_gateway" {
  description = "VLAN 20 gateway — fw-hq's SERVERS interface (configs/pfsense/vlan-interfaces.md)."
  type        = string
  default     = "10.10.20.1"
}

variable "domain" {
  description = "AD/DNS domain (ADR-0007)."
  type        = string
  default     = "corp.meridianretail.com"
}
