# Control plane nodes
resource "proxmox_virtual_machine" "talos_control_plane" {
  for_each = local.control_plane_nodes

  name        = each.key
  node        = "c137"
  vm_id       = each.value.id
  clone       = "template-talos-qemu"
  clone_wait  = 5
  full_clone  = true

  # VM specifications
  memory {
    dedicated = each.value.memory
  }
  cpu {
    cores    = each.value.cores
    sockets  = 1
    type     = "host"
  }
  agent {
    enabled = true  # Enable QEMU agent for Talos
  }
  
  # Set boot order
  boot_order = ["virtio0", "ide2", "net0"]
  
  network_device {
    bridge    = "vmbr0"
    model     = "virtio"
    mac_address = each.value.mac
  }

  disk {
    datastore_id = "vmstore-nfs"
    file_format  = "raw"
    interface    = "virtio0"
    size         = each.value.disk_size
  }
  
  # Add ISO as a separate disk
  cdrom {
    enabled = true
    iso_file = "c137-isos:iso/talos-1.9.5-nocloud-amd64-qemuguest-tailscale.iso"
  }

  # Timeouts
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      boot_order
    ]
  }
  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "3m"
  }
}

# Worker nodes
resource "proxmox_virtual_machine" "talos_workers" {
  for_each = local.worker_nodes

  name        = each.key
  node        = "c137"
  vm_id       = each.value.id
  clone       = "template-talos-qemu"
  clone_wait  = 5
  full_clone  = true

  # VM specifications
  memory {
    dedicated = each.value.memory
  }
  cpu {
    cores    = each.value.cores
    sockets  = 1
    type     = "host"
  }
  agent {
    enabled = true  # Enable QEMU agent for Talos workers as well
  }
  
  # Set boot order
  boot_order = ["virtio0", "ide2", "net0"]
  
  network_device {
    bridge    = "vmbr0"
    model     = "virtio"
    mac_address = each.value.mac
  }

  disk {
    datastore_id = "vmstore-nfs"
    file_format  = "raw"
    interface    = "virtio0"
    size         = each.value.disk_size
  }
  
  # Add ISO as a separate disk
  cdrom {
    enabled = true
    iso_file = "c137-isos:iso/talos-1.9.5-nocloud-amd64-qemuguest-tailscale.iso"
  }

  # Timeouts
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      boot_order
    ]
  }
  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "3m"
  }
}