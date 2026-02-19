{ lib, pkgs, ... }:
let
  hardwareConfig = ./hardware-configuration.nix;
  homelabSecrets = import ../../secrets/homelab.nix;
in
{
  imports = [
    ../../profiles/system/capabilities/minimal.nix
    ./disko.nix
    ./microvms
  ] ++ lib.optionals (builtins.pathExists hardwareConfig) [ hardwareConfig ];

  deployment = {
      keys = {
        "homelab_borg.pass" = {
          keyFile = ../../secrets/homelab_borg.pass;
          destDir = "/var/keys";
          user = "root";
          group = "root";
        };
        "id_ed25519_homelab_borg" = {
          keyFile = ../../secrets/id_ed25519_homelab_borg;
          destDir = "/var/keys";
          user = "root";
          group = "root";
        };
      };
  };

  networking.hostName = "lightquantum-homelab";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.firewall.allowedUDPPorts = [
    5353 # mDNS
  ];

  systemd.network = {
    enable = true;
    links."10-uplink" = {
      matchConfig.MACAddress = homelabSecrets.uplinkMacAddress;
      linkConfig.Name = homelabSecrets.uplinkName;
    };

    networks."10-lan" = {
      matchConfig.Name = homelabSecrets.uplinkName;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
        MulticastDNS = true;
      };
      dhcpV4Config.UseDNS = false;
      linkConfig.RequiredForOnline = "routable";
    };
  };

  time.timeZone = "Etc/UTC";

  nixpkgs.overlays = [ (final: prev: {
    inherit (prev.lixPackageSets.stable)
      nixpkgs-review
      nix-eval-jobs
      nix-fast-build
      colmena;
  }) ];
  nix.package = pkgs.lixPackageSets.stable.lix;
  nix.settings = {
    trusted-users = [
      "@wheel"
      "lightquantum"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  users.users.lightquantum = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (builtins.readFile ../../secrets/id_rsa.pub) ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.resolved = {
    enable = true;
    settings.Resolve = {
      MulticastDNS = true;
      LLMNR = false;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";
}
