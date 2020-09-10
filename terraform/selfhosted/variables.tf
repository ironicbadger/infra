## Provider configs

provider "linode" {
    # https://developers.linode.com/api/v4/#section/Personal-Access-Token
    token = yamldecode(file("~/.config/tokens/linode.yaml"))["token"]
}

provider "cloudflare" {
    # https://api.cloudflare.com/#getting-started-resource-ids
    version = "~> 2.0"
    email = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["account-email"]
    api_key = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["api-key"]
    account_id = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["account-id"]

    #domain-me = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-me"]
    #domain-cloud = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-cloud"]
    #domain-show = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-show"]
    #domain-pms = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-pms"]
}

## Grab Linode SSH keys by Label
## linode-cli sshkeys list

data "linode_sshkey" "randy" {
  label = "randy"
}

data "linode_sshkey" "mooncake" {
  label = "mooncake"
}