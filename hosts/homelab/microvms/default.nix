{ lib, ... }:
let
  homelabSecrets = import ../../../secrets/homelab.nix;
  vmLib = import ./lib.nix { inherit lib; };
  registry = import ./registry.nix;
  inherit (registry) bridgeGroups machines;

  resolvedGroups = vmLib.resolveGroups bridgeGroups;
  resolvedMachines = vmLib.resolveMachines {
    inherit machines;
    bridgeGroups = resolvedGroups;
  };
  vmTopology = vmLib.mkTopology resolvedMachines;

  allGroupConfigs = builtins.attrValues resolvedGroups;
  allMachineConfigs = builtins.attrValues resolvedMachines;

  natInternalInterfaces = lib.unique (
    map (group: group.bridgeName) (builtins.filter (group: group.natEnabled) allGroupConfigs)
  );
in
{
  systemd.tmpfiles.rules = [
    "d /srv/microvms 0770 microvm kvm - -"
  ];

  # Allow forwarding/NAT for all declared MicroVM bridge groups.
  networking.firewall.trustedInterfaces = natInternalInterfaces;

  networking.nat = {
    enable = natInternalInterfaces != [ ];
    externalInterface = homelabSecrets.uplinkName;
    internalInterfaces = natInternalInterfaces;
  };

  systemd.network = {
    netdevs = builtins.listToAttrs (map (group: {
      name = "10-${group.bridgeName}";
      value.netdevConfig = {
        Name = group.bridgeName;
        Kind = "bridge";
      };
    }) allGroupConfigs);

    networks =
      let
        bridgeNetworks = builtins.listToAttrs (map (group: {
          name = "10-${group.bridgeName}";
          value = {
            matchConfig.Name = group.bridgeName;
            address = [ group.bridgeAddress ];
            networkConfig.ConfigureWithoutCarrier = true;
          };
        }) allGroupConfigs);

        # Keep tap rules before generic host ethernet matching in system.nix.
        tapNetworks = builtins.listToAttrs (map (machine: {
          name = "09-${machine.tapName}";
          value = {
            matchConfig.Name = machine.tapName;
            networkConfig.Bridge = machine.bridgeName;
            bridgeConfig.Isolated = machine.isolated;
          };
        }) allMachineConfigs);
      in
      bridgeNetworks // tapNetworks;
  };

  microvm = {
    autostart = builtins.attrNames resolvedMachines;
    vms = builtins.listToAttrs (map (
      machine: vmLib.mkVmEntry {
        spec = machine;
        inherit vmTopology;
      }
    ) allMachineConfigs);
  };
}
