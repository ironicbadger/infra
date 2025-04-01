terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

# provider.tf
provider "proxmox" {
  pm_api_url = "https://10.42.37.10:8006/api2/json"
  pm_api_token_id = "root@pam!root"
  pm_api_token_secret = "bc582d61-cf2e-4c84-a8e7-5680e03952fe"
  pm_tls_insecure = true
}