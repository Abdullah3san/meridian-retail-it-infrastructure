terraform {
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.115"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # State is local by default. For a single-admin shop that's acceptable as
  # long as terraform.tfstate is backed up with the rest of the IT repo
  # (it is gitignored — it holds VM IDs and MACs, not secrets, but it's
  # still the source of truth for what Terraform owns).
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token # export TF_VAR_proxmox_api_token — never in a file

  # Uploading cloud-init snippets and importing disk images goes over SSH
  # to each node; the key comes from the admin's ssh-agent.
  ssh {
    agent    = true
    username = "terraform"
  }
}
