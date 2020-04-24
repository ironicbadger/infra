### Providers
provider "digitalocean" {
    token = yamldecode(file("~/.config/doctl/config.yaml"))["access-token"]
}

provider "cloudflare" {
    version = "~> 2.0"
    email = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["account-email"]
    api_key = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["api-key"]
    account_id = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["account-id"]

    #domain-me = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-me"]
    #domain-cloud = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-cloud"]
}

variable "env_name" {
    description = "Environment name - must be unique"
    type = string
    default = "prod" # comment out if you want to be prompted every time or set in tfvars
}

## DigitalOcean vars
variable "do_image" {
    description = "Execute `doctl compute image list --public` for possible values"
    default = "ubuntu-20-04-x64"
}

variable "do_region" {
    description = "Execute `doctl compute region list` for possible values"
    #ams3 set to default as it has s3 compatible 'spaces' available
    default = "nyc3"
}

variable "do_size_5usd" {
    description = "Execute `doctl compute size list` for possible values"
    default = "s-1vcpu-1gb" 
}

variable "do_size_10usd" {
    description = "10 usd"
    default = "s-1vcpu-2gb"
}

resource "digitalocean_tag" "prod" {
  name = "prod"
}