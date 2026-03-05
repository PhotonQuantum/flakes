{
  lib,
  homelabSecrets,
  resolvedGroups,
  resolvedMachines,
}:
let
  allGroupConfigs = builtins.attrValues resolvedGroups;
  allMachineConfigs = builtins.attrValues resolvedMachines;
in
{
  # Only groups with host access enabled are trusted for host firewall bypass.
  networking.firewall.trustedInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: group.networkPolicy.hostAccess) allGroupConfigs
    )
  );

  networking.nat =
    let
      natInternalInterfaces = lib.unique (map (group: group.bridgeName) allGroupConfigs);
    in
    {
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
            networkConfig = {
              ConfigureWithoutCarrier = true;
              MulticastDNS = group.networkPolicy.hostAccess;
            };
          };
        }) allGroupConfigs);

        # Keep tap rules before generic host ethernet matching in system.nix.
        tapNetworks = builtins.listToAttrs (map (machine: {
          name = "09-${machine.tapName}";
          value = {
            matchConfig.Name = machine.tapName;
            networkConfig.Bridge = machine.bridgeName;
            bridgeConfig.Isolated = !machine.groupConfig.networkPolicy.inBridgeInterconnect;
          };
        }) allMachineConfigs);
      in
      bridgeNetworks // tapNetworks;
  };
}
