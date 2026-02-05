_:

{
  deployment.keys = {
    "id_ed25519_borg" = {
      keyFile = ../../secrets/id_ed25519_meow_borg;
      destDir = "/var/keys";
      user = "root";
      group = "root";
    };
    "id_ed25519_borg.pub" = {
      keyFile = ../../secrets/id_ed25519_meow_borg.pub;
      destDir = "/var/keys";
      user = "root";
      group = "root";
    };
  };

  # services.borgbackup.jobs = {
  #   synapse = {
  #     paths = [ "/var/backup/postgresql" "/var/lib/matrix-synapse" ];
  #     repo = "ssh://c96qu46z@c96qu46z.repo.borgbase.com/./repo";
  #     encryption.mode = "none";
  #     compression = "auto,zstd";
  #     startAt = "*-*-* 00:30:00";
  #     environment = {
  #       BORG_RSH = "ssh -i /var/keys/id_ed25519_borg";
  #     };
  #     prune = {
  #       keep = {
  #         within = "10H";
  #         hourly = 2;
  #         daily = 7;
  #         weekly = 4;
  #         monthly = 6;
  #         yearly = 2;
  #       };
  #     };
  #   };
  # };

  # services.borgbackup.repos = {
  #   aliyun = {
  #     path = "/var/lib/borgbackup/aliyun";
  #     quota = "30G";
  #     user = "borg-aliyun";
  #     authorizedKeys = [
  #       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvwlbYZzoGg+MYu9HyXhTor07AyoAEbRKpUpNi15LVu"
  #     ];
  #   };
  #   hydev = {
  #     path = "/var/lib/borgbackup/hydev";
  #     quota = "10G";
  #     user = "borg-hydev";
  #     authorizedKeys = [
  #       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHmsSyeENaYXUWWXDIETEu1u8Ah7zEX8dCcXuGcqWLxQ"
  #     ];
  #   };
  #   projects = {
  #     path = "/var/lib/borgbackup/projects";
  #     quota = "2000G";
  #     user = "borg-projects";
  #     authorizedKeys = [
  #       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL3wabckxXT3q9ih7Y070OKjI3lf3+VuLrfilj3FzpK8"
  #     ];
  #   };
  # };

  # systemd.services = lib.mapAttrs'
  #   (repo: repoCfg: {
  #     name = "borgbackup-compact-${repo}";
  #     value = {
  #       path = with pkgs; [ borgbackup ];
  #       script = "borg compact --verbose ${repoCfg.path}";
  #       serviceConfig = {
  #         CPUSchedulingPolicy = "idle";
  #         IOSchedulingClass = "idle";
  #         IOReadIOPSMax = 10;
  #         IOWriteIOPSMax = 10;
  #         PrivateTmp = true;
  #         ProtectSystem = "strict";
  #         ReadWritePaths = repoCfg.path;
  #         User = repoCfg.user;
  #       };
  #       startAt = "weekly";
  #     };
  #   })
  #   config.services.borgbackup.repos;
}
