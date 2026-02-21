let 
  secrets = import ../../../secrets/homelab.nix;
in
{
  volumePath = "/srv/microvms";
  snapshotRoot = "/srv/.snapshots/microvm-borg";

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
    routed = {
      groupId = 1;
      bridgeName = "microvm";
      ipv4Prefix = "10.200.0";
      cidr = 24;
      gatewayHost = 1;
      isolated = false;
      natEnabled = true;
    };
    isolated = {
      groupId = 2;
      bridgeName = "microvm-iso";
      ipv4Prefix = "10.201.0";
      cidr = 24;
      gatewayHost = 1;
      isolated = true;
      natEnabled = true;
    };
  };

  machines = {
    forgejo = {
      group = "isolated";
      vmId = 2;
      module = ./vms/forgejo.nix;
      mem = 8192;
      vcpu = 4;

      dataVolume = {
        sizeMiB = 65536;
        mountPoint = "/mnt";
        fsType = "ext4";
        label = "forgejo-data";
      };

      backup = {
        repo = secrets.backupRepos.forgejo;
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
    # };
  };
}
