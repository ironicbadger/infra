# Control plane nodes
resource "proxmox_vm_qemu" "talos_control_plane" {
  for_each = local.control_plane_nodes

  name        = each.key
  target_node = "c137"
  vmid        = each.value.id
  clone       = "template-talos-qemu"
  clone_wait  = 5
  full_clone  = true

  # VM specifications
  memory     = each.value.memory
  cores      = each.value.cores
  sockets    = 1
  cpu_type   = "host"
  agent      = 1
  
  # Set boot order to include cdrom
  boot       = "order=virtio0;ide2;net0"
  
  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = each.value.mac
  }

  disk {
    slot    = "virtio0"
    type    = "disk"
    storage = "vmstore-nfs"
    size    = each.value.disk_size
    format  = "raw"
  }
  
  disk {
    slot    = "ide2"
    type    = "cdrom"
    iso     = "c137-isos:iso/talos-1.9.5-nocloud-amd64-qemuguest-tailscale.iso"
  }
}

# Worker nodes
resource "proxmox_vm_qemu" "talos_workers" {
  for_each = local.worker_nodes

  name        = each.key
  target_node = "c137"
  vmid        = each.value.id
  clone       = "template-talos-qemu"
  clone_wait  = 5
  full_clone  = true

  memory     = each.value.memory
  cores      = each.value.cores
  sockets    = 1
  cpu_type   = "host"
  agent      = 1
  
  # Set boot order to include cdrom
  boot       = "order=virtio0;ide2;net0"
  
  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = each.value.mac
  }

  disk {
    slot    = "virtio0"
    type    = "disk"
    storage = "vmstore-nfs"
    size    = each.value.disk_size
    format  = "raw"
  }
  
  disk {
    slot    = "ide2"
    type    = "cdrom"
    iso     = "c137-isos:iso/talos-1.9.5-nocloud-amd64-qemuguest-tailscale.iso"
  }

}