{ inputs, lib, ... }:
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

  systemd.tmpfiles.rules =
    let
      volumeRules = map (
        machine: "v ${builtins.dirOf machine.dataVolumeResolved.hostImagePath} 0770 microvm kvm - -"
      ) (builtins.filter (machine: machine.dataVolumeResolved != null) allMachineConfigs);
      journalDirRules = map (
        machine: "d /var/lib/microvms/${machine.name}/journal 0755 root root - -"
      ) allMachineConfigs;
      journalRules = map (
        machine:
        "L+ /var/log/journal/${machine.machineId} - - - - /var/lib/microvms/${machine.name}/journal/${machine.machineId}"
      ) allMachineConfigs;
    in
    volumeRules ++ journalDirRules ++ journalRules;

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
