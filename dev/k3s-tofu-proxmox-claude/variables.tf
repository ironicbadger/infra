variable "proxmox_hosts" {
  description = "List of Proxmox host nodes"
  type        = list(string)
  default     = ["clarkson", "hammond", "may"]
}

variable "template_name" {
  description = "Name of the VM template to clone from"
  type        = string
  default     = "ubuntu-2404"
}

variable "storage_name" {
  description = "Name of the shared storage"
  type        = string
  default     = "shared"
}

variable "vm_memory" {
  description = "Memory size in MB for VMs"
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "Disk size for VMs"
  type        = string
  default     = "50G"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}