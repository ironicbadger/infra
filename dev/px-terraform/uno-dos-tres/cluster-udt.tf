# # https://tothecloud.dev/terraform-loop-through-nested-map/

resource "proxmox_vm_qemu" "udt_master" {
    #name = "${var.cluster_udt_name}-m${format("%02d", count.index + 1)}"
    name        = "${var.cluster_udt_name}-${element(keys(var.cluster_udt_masters), count.index)}"
    target_node = var.cluster_udt_masters[element(keys(var.cluster_udt_masters), count.index)]["target"]
    count       = length(var.cluster_udt_masters)
    vmid        = 2000 + count.index

    clone = "ubuntu-cloud-2204"
    full_clone = true
    cores = 4
    memory = 4096
    agent = 0
    automatic_reboot = false
    
    network {
        bridge = "vmbr0"
        model = "virtio"
        macaddr = var.cluster_udt_masters[element(keys(var.cluster_udt_masters), count.index)]["mac"]
    }

    disk {
      type = "scsi"
      size = "15G"
      storage = "local"
    }

    lifecycle {
      ignore_changes = [
        ipconfig0 #dhcp related after initial clone
      ]
    }
}

resource "proxmox_vm_qemu" "udt_node" {
    name        = "${var.cluster_udt_name}-${element(keys(var.cluster_udt_nodes), count.index)}"
    target_node = var.cluster_udt_nodes[element(keys(var.cluster_udt_nodes), count.index)]["target"]
    count       = length(var.cluster_udt_nodes)
    vmid        = 2010 + count.index

    clone = "ubuntu-cloud-2204"
    full_clone = true
    cores = 4
    memory = 4096
    agent = 0

    network {
        bridge = "vmbr0"
        model = "virtio"
        macaddr = var.cluster_udt_nodes[element(keys(var.cluster_udt_nodes), count.index)]["mac"]
    }
    disk {
      type = "scsi"
      size = "15G"
      storage = "local"
    }

    lifecycle {
      ignore_changes = [
        ipconfig0 #dhcp related after initial clone
      ]
    }
}
