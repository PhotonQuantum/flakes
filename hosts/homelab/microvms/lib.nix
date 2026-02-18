{ lib }:
let
  mkTapName = name: "vm-${name}";

  resolveVmSpec =
    {
      vmSpec,
      bridgeGroups,
    }:
    let
      groupName = vmSpec.group;
      groupConfig = bridgeGroups.${groupName}
        or (throw "Unknown MicroVM bridge group `${groupName}` for VM `${vmSpec.name}`");
      tapName = vmSpec.tapName or (mkTapName vmSpec.name);
    in
    vmSpec
    // {
      inherit groupConfig tapName;
      bridgeName = groupConfig.bridgeName;
      gateway = vmSpec.gateway or groupConfig.gateway;
      isolated = vmSpec.isolated or groupConfig.isolated;
    };

  mkVmConfig =
    {
      name,
      mac,
      ip,
      gateway,
      vsockCid,
      tapName ? mkTapName name,
      mem ? 256,
      vcpu ? 1,
      nameservers ? [
        "1.1.1.1"
        "8.8.8.8"
      ],
      extraConfig ? { },
      ...
    }:
    { ... }:
    lib.recursiveUpdate
      {
        networking.hostName = name;
        networking.useDHCP = false;
        networking.useNetworkd = true;
        networking.nameservers = nameservers;

        systemd.network.enable = true;
        systemd.network.networks."10-uplink" = {
          matchConfig.MACAddress = mac;
          address = [ ip ];
          routes = [ { Gateway = gateway; } ];
          networkConfig.DNS = nameservers;
        };

        networking.firewall.allowedTCPPorts = [ 80 ];

        microvm = {
          hypervisor = "cloud-hypervisor";
          interfaces = [
            {
              type = "tap";
              id = tapName;
              inherit mac;
            }
          ];
          vsock.cid = vsockCid;
          inherit vcpu mem;
        };

        system.stateVersion = "25.11";
      }
      extraConfig;

  mkVmEntry = spec: {
    name = spec.name;
    value = {
      config = mkVmConfig spec;
    };
  };
in
{
  inherit
    mkTapName
    resolveVmSpec
    mkVmConfig
    mkVmEntry
    ;
}
