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
      inherit (machine) name;
      hostname = machine.name;
      tags = tailscale.tags or [ ];
    };

  tailscale =
    let
      nodes = lib.mapAttrs (_: mkTailscaleNode) (
        lib.filterAttrs (_: machine: machine.tailscale.enable or false) resolvedMachines
      );
      enabledMachines = builtins.attrValues (
        lib.filterAttrs (_: machine: machine.tailscale.enable or false) resolvedMachines
      );
      policy = {
        tagOwners = builtins.listToAttrs (
          map (tag: {
            name = tag;
            value = [ "autogroup:admin" ];
          }) (lib.unique (lib.concatMap (node: node.tags) (builtins.attrValues nodes)))
        );
        grants = lib.concatMap (
          machine:
          map (grant: {
            src = grant.from;
            dst = [ "tag:${machine.name}" ];
            ip = grant.ports;
          }) (machine.tailscale.grants or [ ])
        ) enabledMachines;
      };
    in
    {
      inherit nodes policy;
    };
  beszel = {
    agentMachines = lib.sort builtins.lessThan (
      builtins.attrNames (
        lib.filterAttrs (_: machine: machine.beszel.agent.enable or false) resolvedMachines
      )
    );
  };
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
    tailscale
    beszel
    ;
}
