let
  proxmox = import ./proxmox.nix;
in
{
  defaults = {
    targetNode = proxmox.proxmox.node;
    template = proxmox.defaults.template;
    storage = proxmox.defaults.storage;
    cores = 2;
    memoryMiB = 4096;
    ipConfig0 = "ip=dhcp";
  };

  vms = {
    forgejo = {
      vmid = 1101;
      cores = 2;
      memoryMiB = 2048;
      diskGiB = 100;
      storage = "ceph-nvme3";
      ipConfig0 = "ip=10.42.1.101/21,gw=10.42.0.254";
      description = "NixOS host managed by ironicbadger/nix-config";
    };
  };
}
