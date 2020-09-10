module "node" {
  source = "../modules/linode-instance"

  label   = "test"
  image   = "linode/ubuntu20.04"
  region  = "us-east"
  type    = "g6-standard-1"
  sshkeys = [
    data.linode_sshkey.randy.ssh_key, 
    data.linode_sshkey.mooncake.ssh_key
  ]
}
