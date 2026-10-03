output "servers" {
  description = "Hostname → IP / node / VM ID, for a quick sanity check after apply."
  value = {
    for name, vm in local.vms : name => {
      ip    = "10.10.20.${vm.octet}"
      node  = vm.node
      vm_id = proxmox_virtual_environment_vm.server[name].vm_id
    }
  }
}
