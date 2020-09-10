terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "2.10.1"
    }
    linode = {
      source = "terraform-providers/linode"
    }
  }
  required_version = ">= 0.13"
}
