{ lib, pkgs, ... }:
let
  hardwareConfig = ./hardware-configuration.nix;
  homelabSecrets = import ../../secrets/homelab.nix;
in
{
  imports = [
    ../../profiles/system/capabilities/minimal.nix
    ./disko.nix
    ./coredns.nix
    ./tailscale.nix
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
        "tg3-rs.env" = {
          keyFile = ../../secrets/tg3-rs.env;
          destDir = "/var/keys";
          user = "microvm";
          group = "kvm";
        };
        "forgejo_runner_secret" = {
          keyFile = ../../secrets/forgejo_runner_secret;
          destDir = "/var/keys";
          user = "microvm";
          group = "kvm";
        };
        "forgejo_cloudflared_credentials.json" = {
          keyFile = ../../secrets/cf/forgejo.json;
          destDir = "/var/keys";
          user = "microvm";
          group = "kvm";
        };
        "tailscale_key" = {
          keyFile = ../../secrets/tailscale_key;
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
      linkConfig.Name = "lan0";
    };

    # Host uplink DHCP/bridge membership is intentionally managed in ./microvms.
    # That module keeps the host on plain `lan0` unless an uplink-bridged
    # MicroVM group is enabled, in which case the bridge holds the DHCP lease.
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
    extraGroups = [ "wheel" "systemd-journal-remote" ];
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
      DNS = "1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google";
      MulticastDNS = true;
      LLMNR = false;
      DNSOverTLS = true;
    };
  };

  services.apcupsd.enable = true;

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
    extraOptions = ''
      min-free = ${toString (1024*1024*1024)}
      max-free = ${toString (1024*1024*1024*5)}
    '';
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";
}
