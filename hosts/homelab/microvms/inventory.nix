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
      hostname = "vm-${machine.name}";
      tags = tailscale.tags or [ ];
    };

  tailscale =
    let
      nodes = lib.mapAttrs (_: mkTailscaleNode) (
        lib.filterAttrs (_: machine: machine.tailscale.enable or false) resolvedMachines
      );
      services =
        let
          machineServices = lib.concatMap (
            machine:
            lib.mapAttrsToList (
              serviceName: service:
              assert lib.assertMsg
                (!lib.hasPrefix "vm-" serviceName)
                "machines.${machine.name}.tailscale.services.${serviceName} must not start with `vm-`";
              {
                name = serviceName;
                value = {
                machine = machine.name;
                inherit (service)
                  grants
                  endpoint
                  ;
                };
              }
            ) (machine.tailscale.services or { })
          ) allMachineConfigs;
        in
        builtins.listToAttrs machineServices;
      policy = {
        tagOwners = builtins.listToAttrs (
          map (tag: {
            name = tag;
            value = [ "autogroup:admin" ];
          }) (lib.unique (lib.concatMap (node: node.tags) (builtins.attrValues nodes)))
        );
        grants = lib.mapAttrsToList (serviceName: service: {
          src = service.grants;
          dst = [ "svc:${serviceName}" ];
          ip = [ service.endpoint ];
        }) services;
      };
    in
    {
      inherit nodes services policy;
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
    ;
}
