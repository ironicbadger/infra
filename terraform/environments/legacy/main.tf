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

## firewall
resource "digitalocean_firewall" "cloud" {
  name = "cloud"
  droplet_ids = [digitalocean_droplet.cloud.id]

  # ssh
  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # http
  inbound_rule {
    protocol = "tcp"
    port_range = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # https
  inbound_rule {
    protocol = "tcp"
    port_range = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # mysql (pubtrivia)
  inbound_rule {
    protocol = "tcp"
    port_range = "3306"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # ub
  inbound_rule {
    protocol = "tcp"
    port_range = "27280"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # ub/udp
  inbound_rule {
    protocol = "udp"
    port_range = "3478"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # wg
  inbound_rule {
    protocol = "udp"
    port_range = "51820"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

}
