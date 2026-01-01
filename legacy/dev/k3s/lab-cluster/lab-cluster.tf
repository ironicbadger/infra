resource "proxmox_vm_qemu" "node" {
    for_each = var.lab_cluster_nodes

    name = "${var.lab_cluster_name}-${each.key}"
    target_node = each.value["target"]
    vmid = 2000 + index(keys(var.lab_cluster_nodes), each.key)

    clone = "ubuntu-2404"
    full_clone = true
    cores = 4
    memory = 4096
    agent = 0
    vga = "std"

    network {
        id = 0
        bridge = "vmbr0"
        model = "virtio"
        macaddr = each.value["mac"]
    }
    disk {
      type = "disk"
      slot = "scsi0"
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