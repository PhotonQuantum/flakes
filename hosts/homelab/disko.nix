{ ... }:
let
  diskIds = import ../../secrets/homelab.nix;
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/${diskIds.mainDiskId}";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "ESP";
            type = "EF00";
            start = "1MiB";
            end = "1GiB";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            name = "root";
            end = "101GiB";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };

          srv = {
            name = "srv";
            end = "-0";
          };
        };
      };
    };

    disk.secondary = {
      type = "disk";
      device = "/dev/disk/by-id/${diskIds.secondaryDiskId}";
      content = {
        type = "gpt";
        partitions = {
          srv = {
            name = "srv";
            end = "-0";
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-d raid0"
                "-m raid1"
                "/dev/disk/by-partlabel/disk-main-srv"
              ];
              mountpoint = "/srv";
              mountOptions = [
                "compress=zstd"
                "noatime"
              ];
            };
          };
        };
      };
    };
  };
}
