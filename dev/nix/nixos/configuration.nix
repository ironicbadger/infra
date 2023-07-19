[root@testnix:~]# cat /etc/nixos/configuration.nix
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      #./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  #boot.zfs.extraPools = [ "zfstest" ];
  services.zfs.autoScrub.enable = true;

  time.timeZone = "America/New_York";

  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };
  users.users.alex.openssh.authorizedKeys.keyFiles = [
    /etc/nixos/ssh/authorized_keys
  ];
  users.users.root.openssh.authorizedKeys.keyFiles = [
    /etc/nixos/ssh/authorized_keys
  ];

  environment.systemPackages = with pkgs; [
    docker-compose
    htop
    hddtemp
    intel-gpu-tools
    iotop
    lm_sensors
    mergerfs
    mc
    ncdu
    nmap
    nvme-cli
    sanoid
    snapraid
    tailscale
    tdns-cli
    tmux
    tree
    vim
    wget
  ];

  networking = {
    firewall.enable = false;
    hostName = "testnix";
    hostId = "e5f2dc02";
    interfaces = {
      enp1s0 = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = "10.42.0.50";
          prefixLength = 20;
        } ];
      };
    };
    defaultGateway = "10.42.0.254";
    nameservers = [ "10.42.0.253" ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "yes";
  };
  services.tailscale.enable = true;

  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  services = {
    xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = true;
        defaultSession = "xfce";
        #defaultSession = "xfce+bspwm";
      };
      desktopManager.xfce.enable = true;
      windowManager.bspwm.enable = true;
    };
  };

  nix = {
    settings = {
        experimental-features = [ "nix-command" "flakes" ];
        warn-dirty = false;
    };
  };

  system.copySystemConfiguration = true;
  system.stateVersion = "23.05";

}