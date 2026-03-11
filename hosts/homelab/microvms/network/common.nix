{
  lib,
  homelabSecrets,
  resolvedGroups,
  resolvedMachines,
}:
let
  allGroupConfigs = builtins.attrValues resolvedGroups;
  allMachineConfigs = builtins.attrValues resolvedMachines;
  managedGroupConfigs = builtins.filter (group: group.usesManagedSubnet) allGroupConfigs;
  uplinkDhcpGroups = builtins.filter (group: group.layout == "uplink-dhcp") allGroupConfigs;
  uplinkDhcpGroup = if uplinkDhcpGroups == [ ] then null else builtins.head uplinkDhcpGroups;
  externalInterface = if uplinkDhcpGroup == null then "lan0" else uplinkDhcpGroup.bridgeName;
in
{
  # Only groups with host access enabled are trusted for host firewall bypass.
  networking.firewall.trustedInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: group.networkPolicy.hostAccess) managedGroupConfigs
    )
  );

  networking.nat =
    let
      natInternalInterfaces = lib.unique (map (group: group.bridgeName) managedGroupConfigs);
    in
    {
      enable = natInternalInterfaces != [ ];
      inherit externalInterface;
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
        managedBridgeNetworks = builtins.listToAttrs (map (group: {
          name = "10-${group.bridgeName}";
          value = {
            matchConfig.Name = group.bridgeName;
            address = [ group.bridgeAddress ];
            networkConfig = {
              ConfigureWithoutCarrier = true;
              MulticastDNS = group.networkPolicy.hostAccess;
            };
          };
        }) managedGroupConfigs);

        hostUplinkNetwork =
          if uplinkDhcpGroup == null then
            {
              "10-lan" = {
                matchConfig.Name = "lan0";
                networkConfig = {
                  DHCP = "ipv4";
                  IPv6AcceptRA = true;
                  MulticastDNS = true;
                };
                dhcpV4Config.UseDNS = false;
                linkConfig.RequiredForOnline = "routable";
              };
            }
          else
            {
              "10-${uplinkDhcpGroup.bridgeName}" = {
                matchConfig.Name = uplinkDhcpGroup.bridgeName;
                networkConfig = {
                  DHCP = "ipv4";
                  IPv6AcceptRA = true;
                  MulticastDNS = true;
                };
                dhcpV4Config.UseDNS = false;
                linkConfig.RequiredForOnline = "routable";
              };

              "10-lan" = {
                matchConfig.Name = "lan0";
                networkConfig.Bridge = uplinkDhcpGroup.bridgeName;
              };
            };

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
      managedBridgeNetworks // hostUplinkNetwork // tapNetworks;
  };
}
