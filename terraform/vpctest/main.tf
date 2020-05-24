provider "digitalocean" {
    token = yamldecode(file("~/.config/doctl/config.yaml"))["access-token"]
}

resource "digitalocean_droplet" "cloud" {
  count = 3
  name                = "test-${count.index + 1}"
  region              = "nyc3"
  image               = "ubuntu-20-04-x64"
  size                = "s-1vcpu-1gb"
  monitoring          = true
  ipv6                = false
  vpc_uuid  = digitalocean_vpc.vpc.id
  ssh_keys = [
    17525420, # ktzTP
    3296803,  # rMBP
    22174810  # m1
  ]

}

resource "digitalocean_vpc" "vpc" {
  name     = "ocp4-vpc"
  region   = "nyc3"
  ip_range = "192.168.5.0/24"
}

resource "digitalocean_loadbalancer" "api-int" {
  name = "api-int"
  region = "nyc3"
  vpc_uuid  = digitalocean_vpc.vpc.id
  droplet_ids = digitalocean_droplet.cloud.*.id

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port     = 22
    protocol = "tcp"
  }
  
}