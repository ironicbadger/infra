terraform {
  required_providers {
    # proxmox = {
    #   source = "telmate/proxmox"
    #   version = "3.0.1-rc6"
    # }
    proxmox = {
        source = "bpg/proxmox"
        version = "0.72.0"
    }
  }
}

variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
    sensitive = true
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

# provider.tf
provider "proxmox" {
    pm_api_url = var.proxmox_api_url
    pm_api_token_id = var.proxmox_api_token_id
    pm_api_token_secret = var.proxmox_api_token_secret
    pm_tls_insecure = true
}

## in lieu of a separate variables.tf file
variable "cluster_name" {
    type = string
}

variable "cluster_nodes" {
    type = map
}