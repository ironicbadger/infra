terraform {
  required_version = ">= 0.13.0"

  required_providers {
    proxmox = {
        source = "telmate/proxmox"
    }
  }
}

variable "proxmox_api_url_anton" {
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

variable "cluster_udt_name" {
    type = string
}

variable "cluster_udt_master_macs" {
    type    = list(string)
    default = []
}

variable "cluster_udt_node_macs" {
    type    = list(string)
    default = []
}

provider "proxmox" {
    pm_api_url = var.proxmox_api_url_anton
    pm_api_token_id = var.proxmox_api_token_id
    pm_api_token_secret = var.proxmox_api_token_secret

    # pm_log_enable = false
    # pm_log_file = "terraform-plugin-proxmox.log"
    # pm_debug = true
    # pm_log_levels = {
    #     _default = "debug"
    #     _capturelog = ""
    # }
}