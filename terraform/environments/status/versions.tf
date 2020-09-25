terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    vultr = {
      source = "vultr/vultr"
    }
  }
  required_version = ">= 0.13"
}
