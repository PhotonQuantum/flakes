{
  config,
  lib,
  pkgs,
  ...
}:
let
  hardwareConfig = ./hardware-configuration.nix;
  homelabSecrets = import ../../secrets/homelab.nix;
in
{
  imports = [
    ../../profiles/system/capabilities/minimal.nix
    ./disko.nix
    ./tailscale.nix
    ./tailscale-auth-keys.nix
    ./beszel-keys.nix
    (import ./beszel-agent.nix {
      environmentFile = "/var/keys/beszel_agent_homelab.env";
      extraFilesystems = [ "/srv__srv" ];
      extraPath = [ config.hardware.nvidia.package.bin ];
      smartmon = {
        enable = true;
        deviceAllow = [
          "/dev/nvme0"
          "/dev/nvme1"
        ];
      };
    })
    ./microvms
    ./media.nix
    ./norgb.nix
  ]
  ++ lib.optionals (builtins.pathExists hardwareConfig) [ hardwareConfig ];

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
      "cloudflare-acme.env" = {
        keyFile = ../../secrets/cf/acme.env;
        destDir = "/var/keys";
        user = "root";
        group = "root";
        permissions = "0400";
      };
      "tailscale_key" = {
        keyFile = ../../secrets/tailscale_key;
        destDir = "/var/keys";
        user = "root";
        group = "root";
      };
      "qbittorrent_password_pbkdf2" = {
        keyFile = ../../secrets/qbittorrent/password_pbkdf2;
        destDir = "/var/keys";
        user = "microvm";
        group = "kvm";
        permissions = "0400";
      };
      "qbittorrent_password" = {
        keyFile = ../../secrets/qbittorrent/password;
        destDir = "/var/keys";
        user = "microvm";
        group = "kvm";
        permissions = "0400";
      };
      "hermes.env" = {
        keyFile = ../../secrets/hermes.env;
        destDir = "/var/keys";
        user = "microvm";
        group = "kvm";
        permissions = "0400";
      };
      "hermes.SOUL.md" = {
        keyFile = ../../secrets/SOUL.md;
        destDir = "/var/keys";
        user = "microvm";
        group = "kvm";
        permissions = "0400";
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

  boot.blacklistedKernelModules = [
    "esp4"
    "esp6"
    "rxrpc"
  ];

  boot.extraModprobeConfig = ''
    install esp4 ${pkgs.coreutils}/bin/false
    install esp6 ${pkgs.coreutils}/bin/false
    install rxrpc ${pkgs.coreutils}/bin/false
  '';

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
    extraGroups = [
      "wheel"
      "systemd-journal-remote"
    ];
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
      min-free = ${toString (1024 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024 * 5)}
    '';
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";
}
