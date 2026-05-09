{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homelabSecrets = import ../../../secrets/homelab.nix;
  inventory = import ./inventory.nix { inherit inputs lib; };
  inherit (inventory)
    vmLib
    volumePath
    certDefaults
    resolvedGroups
    resolvedMachines
    vmTopology
    allMachineConfigs
    ;
in
{
  imports = [
    ./backup.nix
    (import ./acme.nix {
      inherit
        lib
        certDefaults
        resolvedMachines
        volumePath
        ;
    })
    (import ./network {
      inherit
        lib
        homelabSecrets
        resolvedGroups
        resolvedMachines
        ;
    })
  ];

  systemd.tmpfiles.rules = map (
    machine: "v ${builtins.dirOf machine.dataVolumeResolved.hostImagePath} 0770 microvm kvm - -"
  ) (builtins.filter (machine: machine.dataVolumeResolved != null) allMachineConfigs);

  services.journald.remote = {
    enable = true;
    listen = "http";
    settings.Remote = {
      SplitMode = "host";
      MaxUse = "5G";
      KeepFree = "10G";
    };
  };

  systemd.services.systemd-journal-remote.serviceConfig.ExecStart = lib.mkForce [
    ""
    "${pkgs.systemd}/lib/systemd/systemd-journal-remote --output=/var/log/journal/remote/"
  ];

  systemd.sockets.systemd-journal-remote.listenStreams = lib.mkForce [
    ""
    "vsock::19534"
  ];

  microvm = {
    autostart = builtins.attrNames resolvedMachines;
    vms = builtins.listToAttrs (
      map (
        machine:
        vmLib.mkVmEntry {
          spec = machine;
          inherit vmTopology;
        }
      ) allMachineConfigs
    );
  };
}
