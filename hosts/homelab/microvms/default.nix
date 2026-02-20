{ lib, ... }:
let
  homelabSecrets = import ../../../secrets/homelab.nix;
  vmLib = import ./lib.nix { inherit lib; };
  registry = import ./registry.nix;
  volumePath = registry.volumePath or "/srv/microvms";
  inherit (registry) backupDefaults bridgeGroups machines;

  resolvedGroups = vmLib.resolveGroups bridgeGroups;
  resolvedMachines = vmLib.resolveMachines {
    inherit backupDefaults machines volumePath;
    bridgeGroups = resolvedGroups;
  };
  vmTopology = vmLib.mkTopology resolvedMachines;

  allGroupConfigs = builtins.attrValues resolvedGroups;
  allMachineConfigs = builtins.attrValues resolvedMachines;
  dataVolumeMachines = builtins.filter (machine: machine.dataVolumeResolved != null) allMachineConfigs;
  dataVolumeSubvolumeTmpfiles = map (
    machine: "v ${builtins.dirOf machine.dataVolumeResolved.hostImagePath} 0770 microvm kvm - -"
  ) dataVolumeMachines;

  natEnabledGroups = builtins.filter (group: group.natEnabled) allGroupConfigs;
  natInternalInterfaces = lib.unique (map (group: group.bridgeName) natEnabledGroups);
  trustedInternalInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: !(group.isolated or false)) natEnabledGroups
    )
  );
  internetOnlyInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: (group.isolated or false) && group.natEnabled) allGroupConfigs
    )
  );

  privateIPv4Cidrs = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
    "100.64.0.0/10"
  ];

  isolatedInputCommands = lib.concatMapStrings (
    bridgeName: ''
      # Block isolated guests from reaching host services on any port.
      iptables -w -I nixos-fw 1 -i '${bridgeName}' -j DROP
      ip6tables -w -I nixos-fw 1 -i '${bridgeName}' -j DROP
    ''
  ) internetOnlyInterfaces;

  mkPrivateForwardDropCommands =
    bridgeName:
    lib.concatMapStrings (
      cidr: "iptables -w -I nixos-filter-forward 1 -i '${bridgeName}' -d '${cidr}' -j DROP\n"
    ) (lib.reverseList privateIPv4Cidrs);

  isolatedNatCommands = lib.concatMapStrings (
    bridgeName: ''
      # NAT module already adds accept rules for internal interfaces, so force
      # internet-only behavior by inserting stricter rules at chain head.
      iptables -w -I nixos-filter-forward 1 -i '${bridgeName}' -j DROP
      iptables -w -I nixos-filter-forward 1 -i '${bridgeName}' -o '${homelabSecrets.uplinkName}' -j ACCEPT
      ${mkPrivateForwardDropCommands bridgeName}
    ''
  ) internetOnlyInterfaces;
in
{
  imports = [ ./backup.nix ];

  systemd.tmpfiles.rules = dataVolumeSubvolumeTmpfiles;

  # Keep routed groups trusted for host access, but do not trust isolated groups.
  networking.firewall.trustedInterfaces = trustedInternalInterfaces;
  networking.firewall.extraCommands = isolatedInputCommands;
  networking.nat.extraCommands = isolatedNatCommands;

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
