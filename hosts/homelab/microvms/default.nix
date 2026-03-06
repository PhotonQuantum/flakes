{ inputs, lib, pkgs, ... }:
let
  homelabSecrets = import ../../../secrets/homelab.nix;
  vmLib = import ./lib.nix { inherit lib; };
  registry = import ./registry.nix { inherit inputs; };
  volumePath = registry.volumePath or "/srv/microvms";
  inherit (registry) backupDefaults bridgeGroups machines;

  resolvedGroups = vmLib.resolveGroups bridgeGroups;
  resolvedMachines = vmLib.resolveMachines {
    inherit backupDefaults machines volumePath;
    bridgeGroups = resolvedGroups;
  };
  vmTopology = vmLib.mkTopology resolvedMachines;

  allMachineConfigs = builtins.attrValues resolvedMachines;
in
{
  imports = [
    ./backup.nix
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
