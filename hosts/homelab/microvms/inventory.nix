{ inputs, lib }:
let
  registry = import ./registry.nix { inherit inputs; };
  vmLib = import ./lib.nix { inherit lib; };

  volumePath = registry.volumePath or "/srv/microvms";
  backupDefaults = registry.backupDefaults or { };
  certDefaults = registry.certDefaults or { };
  inherit (registry) bridgeGroups machines;

  resolvedGroups = vmLib.resolveGroups bridgeGroups;
  resolvedMachines = vmLib.resolveMachines {
    inherit
      backupDefaults
      certDefaults
      machines
      volumePath
      ;
    bridgeGroups = resolvedGroups;
  };
  vmTopology = vmLib.mkTopology resolvedMachines;
  allMachineConfigs = builtins.attrValues resolvedMachines;

  mkTailscaleNode =
    machine:
    let
      tailscale = machine.tailscale or { };
    in
    {
      hostname = tailscale.hostname or machine.name;
      tags = tailscale.tags or [ ];
      inherit (machine)
        name
        group
        groupId
        vmId
        usesDhcp
        usesManagedSubnet
        bridgeName
        ip
        ipCidr
        mac
        ;
    };

  tailscaleNodes = lib.mapAttrs (_: mkTailscaleNode) (
    lib.filterAttrs (_: machine: machine.tailscale.enable or true) resolvedMachines
  );
in
{
  inherit
    registry
    vmLib
    volumePath
    backupDefaults
    certDefaults
    bridgeGroups
    machines
    resolvedGroups
    resolvedMachines
    vmTopology
    allMachineConfigs
    tailscaleNodes
    ;
}
