{
  lib,
  homelabSecrets,
  resolvedGroups,
  resolvedMachines,
}:
let
  allGroupConfigs = builtins.attrValues resolvedGroups;
  allMachineConfigs = builtins.attrValues resolvedMachines;
  natEnabledGroups = builtins.filter (group: group.natEnabled) allGroupConfigs;
  natInternalInterfaces = lib.unique (map (group: group.bridgeName) natEnabledGroups);
  trustedInternalInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: !(group.isolated or false)) natEnabledGroups
    )
  );
in
{
  # Keep routed groups trusted for host access, but do not trust isolated groups.
  networking.firewall.trustedInterfaces = trustedInternalInterfaces;

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
}
