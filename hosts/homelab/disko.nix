{ ... }:
let
  diskIds = import ../../secrets/homelab-disk-id.nix;
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
            end = "-0";
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

                "/srv" = {
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
    };
  };
}
