{ lib, ... }:
let
  homelabSecrets = import ../../../secrets/homelab.nix;

  bridgeGroups = {
    routed = {
      bridgeName = "microvm";
      bridgeAddress = "10.200.0.1/24";
      gateway = "10.200.0.1";
      isolated = false;
      natEnabled = true;
    };
    isolated = {
      bridgeName = "microvm-iso";
      bridgeAddress = "10.201.0.1/24";
      gateway = "10.201.0.1";
      isolated = true;
      natEnabled = true;
    };
  };

  vmLib = import ./lib.nix { inherit lib; };

  vmSpecs = [
    {
      name = "static-http";
      group = "routed";
      mac = "02:00:00:00:20:02";
      ip = "10.200.0.2/24";
      vsockCid = 21002;
      mem = 512;
      vcpu = 1;
      extraConfig = import ./vms/static-http.nix;
    }
    {
      name = "experiment-http";
      group = "isolated";
      mac = "02:00:00:00:20:03";
      ip = "10.201.0.2/24";
      vsockCid = 21003;
      tapName = "vm-exp-http";
      mem = 512;
      vcpu = 1;
      extraConfig = import ./vms/experiment-http.nix;
    }
  ];

  resolvedVmSpecs = map (
    vmSpec:
    vmLib.resolveVmSpec {
      inherit vmSpec bridgeGroups;
    }
  ) vmSpecs;

  allGroupConfigs = builtins.attrValues bridgeGroups;

  natInternalInterfaces = lib.unique (
    map (group: group.bridgeName) (builtins.filter (group: group.natEnabled) allGroupConfigs)
  );
in
{
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
        tapNetworks = builtins.listToAttrs (map (spec: {
          name = "09-${spec.tapName}";
          value = {
            matchConfig.Name = spec.tapName;
            networkConfig.Bridge = spec.bridgeName;
            bridgeConfig.Isolated = spec.isolated;
          };
        }) resolvedVmSpecs);
      in
      bridgeNetworks // tapNetworks;
  };

  microvm = {
    autostart = map (spec: spec.name) resolvedVmSpecs;
    vms = builtins.listToAttrs (map vmLib.mkVmEntry resolvedVmSpecs);
  };
}
