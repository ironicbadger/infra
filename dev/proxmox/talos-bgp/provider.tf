terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.86.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = "${var.proxmox_user}=${var.proxmox_password}"
  insecure = true
  ssh {
    agent = true
  }
}