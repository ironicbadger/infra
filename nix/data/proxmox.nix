{
  proxmox = {
    host = "10.42.1.91";
    node = "m90q-1";
    user = "root";
  };

  defaults = {
    storage = "ceph-nvme3";
    template = "nixos";
  };

  templates = {
    # Built and maintained by ironicbadger/nix-config.
    nixos = {
      name = "nixos-tmpl";
      vmid = 9000;
    };
  };
}
