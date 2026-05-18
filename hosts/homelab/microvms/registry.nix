{ inputs, ... }:
let
  secrets = import ../../../secrets/homelab.nix;
in
{
  volumePath = "/srv/microvms";
  snapshotRoot = "/srv/.snapshots/microvm-borg";

  certDefaults = {
    domain = "lqhome.me";
    email = secrets.acmeEmail;
  };

  backupDefaults = {
    startAt = "daily";
    compression = "zstd";
    passFile = "/var/keys/homelab_borg.pass";
    sshKeyPath = "/var/keys/id_ed25519_homelab_borg";
    prune = {
      within = "24H";
      daily = 7;
      weekly = 4;
      monthly = 6;
      yearly = 2;
    };
  };

  bridgeGroups = {
    isolated = {
      layout = "managed";
      groupId = 2;
      bridgeName = "microvm-iso";
      ipv4Prefix = "10.201.0";
      cidr = 24;
      gatewayHost = 1;
      networkPolicy = {
        hostAccess = false;
        lanAccess = false;
        inBridgeInterconnect = false;
      };
    };
    forgejo = {
      layout = "managed";
      groupId = 3;
      bridgeName = "microvm-forgejo";
      ipv4Prefix = "10.202.0";
      cidr = 24;
      gatewayHost = 1;
      networkPolicy = {
        hostAccess = false;
        lanAccess = false;
        inBridgeInterconnect = true;
      };
    };
    emby = {
      layout = "managed";
      groupId = 5;
      bridgeName = "microvm-emby";
      ipv4Prefix = "10.203.0";
      cidr = 24;
      gatewayHost = 1;
      networkPolicy = {
        hostAccess = false;
        lanAccess = true;
        inBridgeInterconnect = false;
      };
    };
    lan = {
      layout = "uplink-dhcp";
      groupId = 4;
      bridgeName = "microvm-lan";
    };
  };

  machines = {
    forgejo = {
      group = "forgejo";
      vmId = 2;
      module = ./vms/forgejo.nix;
      mem = 2049;
      vcpu = 4;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 65536;
        mountPoint = "/mnt";
        fsType = "ext4";
        label = "forgejo-data";
      };

      backup = {
        repo = secrets.backupRepos.forgejo;
      };

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:forgejo"
        ];
      };

      keys = {
        "/var/keys/forgejo-runner-secret" = {
          file = "/var/keys/forgejo_runner_secret";
          user = "forgejo";
          group = "forgejo";
        };
        "/var/keys/forgejo-cloudflared-credentials.json" = {
          file = "/var/keys/forgejo_cloudflared_credentials.json";
          user = "root";
          group = "root";
        };
      };
    };

    forgejo-runner = {
      group = "forgejo";
      vmId = 3;
      module = ./vms/forgejo-runner.nix;
      mem = 8192;
      vcpu = 4;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 65536;
        mountPoint = "/mnt";
        fsType = "ext4";
        label = "forgejo-r-data";
      };

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:forgejo-runner"
        ];
      };

      keys = {
        "/var/keys/forgejo-runner-secret" = {
          file = "/var/keys/forgejo_runner_secret";
          user = "forgejo-runner";
          group = "forgejo-runner";
        };
      };
    };

    tg3-rs = {
      group = "isolated";
      vmId = 4;
      module = [
        inputs.tg3-rs.nixosModules.tg3-bot
        ./vms/tg3-rs.nix
      ];
      mem = 512;
      vcpu = 1;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 2048;
        mountPoint = "/mnt";
        fsType = "ext4";
        label = "tg3rs-data";
      };

      backup = {
        repo = secrets.backupRepos.tg3-rs;
      };

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:tg3-rs"
        ];
      };

      keys = {
        "/var/keys/tg3-rs.env" = {
          file = "/var/keys/tg3-rs.env";
          user = "tg3-bot";
          group = "tg3-bot";
        };
      };
    };

    syncthing = {
      group = "lan";
      vmId = 10;
      module = ./vms/syncthing.nix;
      mem = 1024;
      vcpu = 2;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 32768;
        mountPoint = "/mnt";
        fsType = "ext4";
        label = "syncthing-data";
      };

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:syncthing"
        ];
        grants = [
          {
            from = [ "autogroup:member" ];
            ports = [
              "tcp:80"
              "tcp:443"
              "tcp:22000"
              "udp:22000"
              "udp:21027"
            ];
          }
        ];
      };
    };

    paperless = {
      group = "isolated";
      vmId = 11;
      module = ./vms/paperless.nix;
      mem = 4096;
      vcpu = 4;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 32768;
        mountPoint = "/mnt";
        fsType = "ext4";
        label = "paperless-data";
      };

      backup = {
        repo = secrets.backupRepos.paperless;
      };

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:paperless"
        ];
        grants = [
          {
            from = [ "autogroup:member" ];
            ports = [
              "tcp:80"
              "tcp:443"
            ];
          }
        ];
      };
    };

    coredns = {
      group = "isolated";
      vmId = 15;
      module = ./vms/coredns.nix;
      mem = 512;
      vcpu = 1;
      beszel.agent.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:dns"
        ];
      };
    };

    hermes = {
      group = "isolated";
      vmId = 16;
      module = [
        inputs.hermes-agent.nixosModules.default
        ./vms/hermes.nix
      ];
      mem = 8192;
      vcpu = 4;

      dataVolume = {
        sizeMiB = 65536;
        mountPoint = "/var/lib/hermes";
        fsType = "ext4";
        label = "hermes-data";
      };

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:hermes"
        ];
        grants = [
          {
            from = [ "autogroup:member" ];
            ports = [
              "tcp:80"
              "tcp:443"
            ];
          }
        ];
      };

      keys = {
        "/var/keys/hermes.env" = {
          file = "/var/keys/hermes.env";
          user = "hermes";
          group = "hermes";
          permissions = "0400";
        };
      };
    };

    emby = {
      group = "emby";
      vmId = 12;
      module = [
        inputs.self.nixosModules.emby
        ./vms/emby.nix
      ];
      mem = 4096;
      vcpu = 4;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 16384;
        mountPoint = "/srv/media";
        fsType = "ext4";
        label = "emby-data";
      };

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:media"
          "tag:emby"
        ];
        grants = [
          {
            from = [ "autogroup:member" ];
            ports = [
              "tcp:80"
              "tcp:443"
            ];
          }
        ];
      };

      extraOptions = {
        shares = [
          {
            source = "/srv/media/data";
            mountPoint = "/srv/media/data";
            tag = "emby-media";
            proto = "virtiofs";
            readOnly = true;
          }
        ];
      };
    };

    qbittorrent = {
      group = "lan";
      vmId = 13;
      module = ./vms/qbittorrent.nix;
      mem = 2049;
      vcpu = 2;
      beszel.agent.enable = true;

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:media"
          "tag:qbittorrent"
        ];
        grants = [
          {
            from = [
              "autogroup:member"
              "tag:ani-rss"
            ];
            ports = [
              "tcp:80"
              "tcp:443"
            ];
          }
        ];
      };

      keys = {
        "/var/keys/qbittorrent-password-pbkdf2" = {
          file = "/var/keys/qbittorrent_password_pbkdf2";
          user = "media";
          group = "media";
          permissions = "0400";
        };
      };

      extraOptions = {
        shares = [
          {
            source = "/srv/media/qbittorrent";
            mountPoint = "/config";
            tag = "qbittorrent-config";
            proto = "virtiofs";
          }
          {
            source = "/srv/media/downloads";
            mountPoint = "/downloads";
            tag = "qbittorrent-downloads";
            proto = "virtiofs";
          }
          {
            source = "/srv/media/data";
            mountPoint = "/Media";
            tag = "qbittorrent-media";
            proto = "virtiofs";
          }
        ];
      };
    };

    ani-rss = {
      group = "isolated";
      vmId = 14;
      module = [
        inputs.self.nixosModules.ani-rss
        ./vms/ani-rss.nix
      ];
      mem = 1024;
      vcpu = 1;
      beszel.agent.enable = true;

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:media"
          "tag:ani-rss"
        ];
        grants = [
          {
            from = [ "autogroup:member" ];
            ports = [
              "tcp:80"
              "tcp:443"
            ];
          }
        ];
      };

      keys = {
        "/var/keys/qbittorrent-password" = {
          file = "/var/keys/qbittorrent_password";
          user = "media";
          group = "media";
          permissions = "0400";
        };
      };

      extraOptions = {
        shares = [
          {
            source = "/srv/media/ani-rss";
            mountPoint = "/config";
            tag = "ani-rss-config";
            proto = "virtiofs";
          }
          {
            source = "/srv/media/data";
            mountPoint = "/Media";
            tag = "ani-rss-media";
            proto = "virtiofs";
          }
        ];
      };
    };

    beszel = {
      group = "isolated";
      vmId = 17;
      module = ./vms/beszel.nix;
      mem = 1024;
      vcpu = 1;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 8192;
        mountPoint = "/var/lib/beszel-hub";
        fsType = "ext4";
        label = "beszel-data";
      };

      backup = {
        repo = secrets.backupRepos.beszel;
      };

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:beszel"
        ];
        grants = [
          {
            from = [
              "autogroup:member"
              "tag:homelab-vm"
              "tag:homelab-host"
            ];
            ports = [
              "tcp:443"
            ];
          }
        ];
      };

      keys = {
        "/var/keys/beszel-hub.env" = {
          file = "/var/keys/beszel_hub.env";
          user = "root";
          group = "root";
          permissions = "0400";
        };
        "/var/keys/beszel-hub-config.yml" = {
          file = "/var/keys/beszel_hub_config.yml";
          user = "root";
          group = "root";
          permissions = "0400";
        };
        "/var/keys/beszel-hub-id-ed25519" = {
          file = "/var/keys/beszel_hub_id_ed25519";
          user = "root";
          group = "root";
          permissions = "0400";
        };
      };
    };

    home-assistant = {
      group = "lan";
      vmId = 18;
      module = ./vms/home-assistant.nix;
      mem = 4096;
      vcpu = 2;
      beszel.agent.enable = true;

      dataVolume = {
        sizeMiB = 16384;
        mountPoint = "/var/lib/home-assistant";
        fsType = "ext4";
        label = "ha-data";
      };

      backup = {
        repo = secrets.backupRepos.home-assistant;
      };

      cert.enable = true;

      tailscale = {
        enable = true;
        tags = [
          "tag:homelab-vm"
          "tag:home-assistant"
        ];
        grants = [
          {
            from = [ "autogroup:member" ];
            ports = [
              "tcp:80"
              "tcp:443"
            ];
          }
        ];
      };
    };

    # Example configuration only (documentation).
    # Uncomment and adapt when you need to run a MicroVM.
    # example-http = {
    #   group = "routed";
    #   vmId = 10;
    #   module = ./vms/example-http.nix;
    #   mem = 512;
    #   vcpu = 1;
    #
    #   # Optional per-VM data volume:
    #   dataVolume = {
    #     sizeMiB = 1024;
    #     # Optional; defaults to "/mnt".
    #     mountPoint = "/mnt";
    #     # Image path is fixed to "${volumePath}/${name}/image.img".
    #     # Optional; defaults to "ext4".
    #     fsType = "ext4";
    #     # Optional; defaults to null.
    #     label = "example-http-data";
    #   };
    #
    #   # Optional per-VM image backup:
    #   backup = {
    #     repo = "ssh://user@example/./repo-example-http";
    #     # Optional; defaults to backupDefaults.startAt.
    #     startAt = "daily";
    #     # Optional; defaults to backupDefaults.compression.
    #     compression = "zstd";
    #     # Optional; defaults to backupDefaults.passFile.
    #     passFile = "/var/keys/homelab_borg.pass";
    #     # Optional; defaults to backupDefaults.sshKeyPath.
    #     sshKeyPath = "/var/keys/id_ed25519_homelab_borg";
    #     # Optional; defaults to VM name.
    #     archivePrefix = "example-http";
    #     # Optional; defaults to backupDefaults.prune.
    #     prune = {
    #       within = "24H";
    #       daily = 7;
    #       weekly = 4;
    #       monthly = 6;
    #       yearly = 2;
    #     };
    #   };
    #
    #   # Optional per-VM key file injection via systemd credentials:
    #   keys = {
    #     "/var/keys/example-http-token" = {
    #       # Required absolute host path string.
    #       file = "/var/keys/example-http-token";
    #       # Optional; defaults to "root".
    #       user = "nginx";
    #       # Optional; defaults to "root".
    #       group = "nginx";
    #       # Optional; defaults to "0600". Supports 3-4 octal digits.
    #       permissions = "0640";
    #     };
    #     "/var/keys/example-http-defaults" = {
    #       file = "/var/keys/example-http-defaults";
    #     };
    #   };
    #
    #   # Optional host-provisioned ACME certificate mounted read-only in the guest.
    #   cert = {
    #     enable = true;
    #     # Optional; defaults to "example-http.${certDefaults.domain}".
    #     domain = "example-http.lightquantum.me";
    #     # Cert files are mounted as root:cert with a fixed cert GID.
    #     # Add service users that need private-key access to the guest `cert` group.
    #   };
    #
    #   # Optional extra MicroVM options merged into `microvm`.
    #   # `extraOptions` wins on conflicts with generated values.
    #   extraOptions = {
    #     shares = [
    #       {
    #         source = "/srv/share/example-http";
    #         mountPoint = "/share";
    #         tag = "example-share";
    #         proto = "virtiofs";
    #       }
    #     ];
    #     qemu.extraArgs = [ "-device" "virtio-rng-pci" ];
    #   };
    # };
  };
}
