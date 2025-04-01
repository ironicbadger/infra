resource "proxmox_virtual_environment_vm" "k3s_node" {
    for_each = var.cluster_nodes

    name = "${var.cluster_name}-${each.key}"
    node_name = each.value["target"]
    started = true

    cpu {
        cores = 2
    }
    memory {
        dedicated = 4096
    }
    clone {
        full = true
        vm_id = 9000
        node_name = "clarkson"
    }

    initialization {
        ip_config {
        ipv4 {
            address = "dhcp"
        }
        }
    }

    disk {
        datastore_id = "shared"
        file_id      = "shared:iso/debian-12-genericcloud-amd64.img"
        interface    = "virtio0"
        iothread     = true
        discard      = "on"
        size         = 20
    }
}