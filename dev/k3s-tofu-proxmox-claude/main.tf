# locals.tf
locals {
  # Create a mapping for even distribution
  control_plane_hosts = [for i in range(var.control_plane_count) :
    var.proxmox_hosts[i % length(var.proxmox_hosts)]]

  worker_hosts = [for i in range(var.worker_count) :
    var.proxmox_hosts[i % length(var.proxmox_hosts)]]
}

# control_plane.tf
resource "proxmox_vm_qemu" "k3s_control_plane" {
  count = var.control_plane_count

  name = "k3s-control-${count.index + 1}"
  target_node = local.control_plane_hosts[count.index]

  # Clone from template
  clone = var.template_name
  #full_clone = true

  # VM Resources
  memory = var.vm_memory
  cores = 2
  sockets = 1

  # Storage
  disk {
    type = "disk"
    storage = var.storage_name
    size = var.vm_disk_size
    slot = "scsi0"
  }

  # Network configuration
  network {
    model = "virtio"
    bridge = "vmbr0"
    id = 0
  }

  # Cloud-init settings
  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"

  # Other settings
  onboot = true
  agent = 1
}

# workers.tf
resource "proxmox_vm_qemu" "k3s_worker" {
  count = var.worker_count

  name = "k3s-worker-${count.index + 1}"
  target_node = local.worker_hosts[count.index]

  # Clone from template
  clone = var.template_name
  #full_clone = true

  # VM Resources
  memory = var.vm_memory
  cores = 2
  sockets = 1

  # Storage
  disk {
    type = "disk"
    storage = var.storage_name
    size = var.vm_disk_size
    slot = "scsi0"
  }

  # Network configuration
  network {
    model = "virtio"
    bridge = "vmbr0"
    id = 0
  }

  # Cloud-init settings
  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"

  # Other settings
  onboot = true
  agent = 1
}