## DNS
resource "cloudflare_record" "unifitest" {
  zone_id = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-cloud"]
  name  = "unifitest"
  type  = "A"
  ttl   = 300
  value = digitalocean_droplet.cloud.ipv4_address
}

resource "cloudflare_record" "blogtest" {
  zone_id = yamldecode(file("~/.config/tokens/cloudflare.yaml"))["domain-me"]
  name    = "blogtest"
  type    = "A"
  ttl     = 300
  value   = digitalocean_droplet.cloud.ipv4_address
}

## droplet instance(s)
resource "digitalocean_droplet" "cloud" {

  name                = "${var.env_name}-test"
  region              = var.do_region
  image               = var.do_image
  size                = var.do_size_10usd
  monitoring          = true
  ipv6                = false
  private_networking  = false
  ssh_keys = [
    17525420, # ktzTP
    3296803,  # rMBP
    22174810  # m1
  ]
  tags = [
    "${digitalocean_tag.prod.id}",
  ]

}