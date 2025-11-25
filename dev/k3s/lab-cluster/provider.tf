terraform {

  required_providers {
    proxmox = {
        source = "telmate/proxmox"
        version = "3.0.1-rc9"
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

variable "lab_cluster_name" {
    type = string
}

variable "lab_cluster_nodes" {
    type = map
}

provider "proxmox" {
    pm_api_url = var.proxmox_api_url
    pm_api_token_id = var.proxmox_api_token_id
    pm_api_token_secret = var.proxmox_api_token_secret

    pm_tls_insecure = true
    #pm_parallel = 10

    # pm_log_enable = false
    # pm_log_file = "terraform-plugin-proxmox.log"
    # pm_debug = true
    # pm_log_levels = {
    #     _default = "debug"
    #     _capturelog = ""
    # }
}