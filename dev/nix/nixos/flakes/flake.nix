{
  description = "System config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ...}@inputs:
  let
    inherit (nixpkgs) lib;

    system = "x86_64-linux";

    util = import ./lib {
      inherit system pkgs home-manager lib; overlays = (pkgs.overlays);
    };

    inherit (util) user;
    inherit (util) host;

    pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = false;
        overlays = [];
    };

  in {
    homeManagerConfigurations = {
      alex = user.mkHMUser {
        # ...
      };
    };

    nixosConfigurations = {
      testnix = host.mkHost {
        name = "testnix";
        NICs = [ "enp1s0" ];
        boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
        boot.initrd.kernelModules = [ ];
        boot.kernelModules = [ "kvm-intel" ];
        boot.extraModulePackages = [ ];
        kernelParams = [];
        systemConfig = {
          # your abstracted system config
        };
        users = [{
          name = "jd";
          groups = [ "wheel" "networkmanager" "video" ];
          uid = 1000;
          shell = pkgs.zsh;
        }];
      };
    };
  };



} #fin