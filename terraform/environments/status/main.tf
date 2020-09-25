data "vultr_reverse_ipv4" "status" {
  filter {
    name = var.status_instance_id
    values = [var.status_instance_name]
  }
}

output "ipv4" {
  value = data.vultr_reverse_ipv4.status.ip
}

resource "cloudflare_record" "cloud" {
  zone_id  = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-cloud"]
  for_each = var.subdomains
  name     = each.key
  value    = data.vultr_reverse_ipv4.status.ip
  type     = "A"
}

# module "vultrinstance" {
#   source = "../modules/vultr-instance"

#   # $2.50 and $3.50 plans not available via API :(
#   plan_id = "201"
#   region_id = "1"
#   os_id = "387" #387 ubu20.04
# }