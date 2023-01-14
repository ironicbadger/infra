resource "proxmox_vm_qemu" "node" {
    for_each = var.cluster_udt

    name = "${var.cluster_udt_name}-${each.key}"
    target_node = each.value["target"]
    vmid = 2000 + index(keys(var.cluster_udt), each.key)

    clone = "ubuntu-cloud-2204"
    full_clone = true
    cores = 2
    memory = 4096
    agent = 0

    network {
        bridge = "vmbr0"
        model = "virtio"
        macaddr = each.value["mac"]
    }
    disk {
      type = "scsi"
      size = each.value["disk"]
      storage = each.value["storage"]
    }

    lifecycle {
      ignore_changes = [
        ipconfig0, #dhcp related after initial clone
        ciuser,
        sshkeys
      ]
    }    
}