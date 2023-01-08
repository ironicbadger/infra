resource "proxmox_vm_qemu" "udt_master" {
    name = "${var.cluster_udt_name}-m${format("%02d", count.index + 1)}"
    target_node = "anton"
    count = length(var.cluster_udt_master_macs)
    vmid = 2000 + count.index

    clone = "ubuntu-cloud-2204"
    full_clone = true
    cores = 4
    memory = 4096
    agent = 0
    network {
        bridge = "vmbr0"
        model = "virtio"
        macaddr = "${var.cluster_udt_master_macs[count.index]}"
    }

    lifecycle {
      ignore_changes = [
        ipconfig0 #dhcp related after initial clone
      ]
    }
}

resource "proxmox_vm_qemu" "udt_node" {
    name = "${var.cluster_udt_name}-node${format("%02d", count.index + 1)}"
    target_node = "anton"
    count = length(var.cluster_udt_node_macs)
    vmid = 2010 + count.index

    clone = "ubuntu-cloud-2204"
    full_clone = true
    cores = 4
    memory = 4096
    agent = 0
    network {
        bridge = "vmbr0"
        model = "virtio"
        macaddr = "${var.cluster_udt_node_macs[count.index]}"
    }

    lifecycle {
      ignore_changes = [
        ipconfig0 #dhcp related after initial clone
      ]
    }
}