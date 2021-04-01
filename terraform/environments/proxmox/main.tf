terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.6.7"
    }
  }
}

# Using proxmox from a vagrant e.g. https://github.com/rgl/proxmox-ve
provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = "https://192.168.1.10:8006/api2/json"
    pm_user = "root@pam"
    pm_password = "123"
}

resource "proxmox_vm_qemu" "example" {
    name = "servymcserverface"
    desc = "A test for using terraform and vagrant"
    disk {
        storage = "intel2tbnvme"
        type = "virtio"
        size = "20G"
    }
    target_node = "morpheus"
    iso = "local:iso/archlinux-2021.02.01-x86_64.iso"
    #clone = "redhat-irc"
    #bios = "ovmf"
}