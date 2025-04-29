variable "proxmox_api_url" {
  description = "The Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "proxmox_user" {
  description = "Proxmox API token ID (e.g., 'root@pam!terraform')"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}