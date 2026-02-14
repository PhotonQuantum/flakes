{ lib, pkgs, ... }:
let
  hardwareConfig = ./hardware-configuration.nix;
in
{
  imports = [
    ../../profiles/system/capabilities/minimal.nix
    ./disko.nix
    ./microvm-static-http.nix
  ] ++ lib.optionals (builtins.pathExists hardwareConfig) [ hardwareConfig ];

  networking.hostName = "lightquantum-homelab";
  networking.useDHCP = false;
  networking.useNetworkd = true;

  networking.firewall.allowedUDPPorts = [
    5353 # mDNS
  ];

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig = {
        Type = "ether";
        Kind = "!*";
      };
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
        MulticastDNS = true;
      };
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
