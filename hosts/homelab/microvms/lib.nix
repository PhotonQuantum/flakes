{ lib }:
let
  hexDigits = [
    "0"
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
  ];

  ensure = cond: msg: if cond then true else throw msg;

  ensureRange =
    label: value: min: max:
    ensure
      (value >= min && value <= max)
      "${label} must be between ${toString min} and ${toString max}; got ${toString value}";

  findDuplicateValues =
    values:
    let
      counts = lib.foldl' (
        acc: value:
        let
          key = toString value;
        in
        acc
        // {
          "${key}" = (acc.${key} or 0) + 1;
        }
      ) { } values;
    in
    builtins.attrNames (lib.filterAttrs (_: count: count > 1) counts);

  ensureNoDuplicates =
    label: values:
    let
      duplicates = findDuplicateValues values;
    in
    ensure
      (duplicates == [ ])
      "${label} must be unique; duplicates: ${lib.concatStringsSep ", " duplicates}";

  sanitizeName =
    name:
    let
      chars = lib.stringToCharacters (lib.toLower name);
      allowed = builtins.filter (c: builtins.match "[a-z0-9]" c != null) chars;
      sanitized = builtins.concatStringsSep "" allowed;
    in
    if sanitized == "" then "vm" else sanitized;

  hexByte =
    n:
    assert ensureRange "hex byte" n 0 255;
    let
      hi = builtins.div n 16;
      lo = n - (hi * 16);
    in
    "${builtins.elemAt hexDigits hi}${builtins.elemAt hexDigits lo}";

  mkTapNameAuto =
    name: vmId:
    let
      shortName = lib.substring 0 8 (sanitizeName name);
      tapName = "vm-${shortName}-${toString vmId}";
    in
    assert ensure
      (builtins.stringLength tapName <= 15)
      "tap name `${tapName}` for VM `${name}` is longer than Linux max length 15";
    tapName;

  resolveGroups =
    bridgeGroups:
    let
      groupNames = builtins.attrNames bridgeGroups;
      resolved = builtins.listToAttrs (
        map (
          groupName:
          let
            group = bridgeGroups.${groupName};
            gateway = group.gateway or "${group.ipv4Prefix}.${toString group.gatewayHost}";
            bridgeAddress = group.bridgeAddress or "${gateway}/${toString group.cidr}";
          in
          assert ensureRange "bridgeGroups.${groupName}.groupId" group.groupId 1 254;
          assert ensureRange "bridgeGroups.${groupName}.cidr" group.cidr 1 32;
          assert ensureRange "bridgeGroups.${groupName}.gatewayHost" group.gatewayHost 1 254;
          {
            name = groupName;
            value = group // {
              name = groupName;
              inherit gateway bridgeAddress;
            };
          }
        ) groupNames
      );
      groupValues = builtins.attrValues resolved;
    in
    assert ensureNoDuplicates "bridgeGroups.*.groupId" (map (group: group.groupId) groupValues);
    assert ensureNoDuplicates "bridgeGroups.*.bridgeName" (map (group: group.bridgeName) groupValues);
    resolved;

  resolveMachine =
    {
      name,
      machine,
      bridgeGroups,
    }:
    let
      groupName = machine.group;
      group =
        bridgeGroups.${groupName}
          or (throw "Unknown MicroVM group `${groupName}` for machine `${name}`");
      vmId = machine.vmId;
      ip = machine.ip or "${group.ipv4Prefix}.${toString vmId}";
      gateway = machine.gateway or group.gateway;
      tapName = machine.tapName or (mkTapNameAuto name vmId);
      moduleInput = machine.module or machine.extraConfig or null;
      extraConfig =
        if moduleInput == null then
          [ ]
        else if builtins.isList moduleInput then
          moduleInput
        else
          [ moduleInput ];
      vmIdHi = builtins.div vmId 256;
      vmIdLo = vmId - (vmIdHi * 256);
    in
    assert ensureRange "machines.${name}.vmId" vmId 2 254;
    assert ensure
      (vmId != group.gatewayHost)
      "machines.${name}.vmId (${toString vmId}) must not match gateway host (${toString group.gatewayHost})";
    assert ensure
      (builtins.stringLength tapName <= 15)
      "tap name `${tapName}` for machine `${name}` is longer than Linux max length 15";
    machine
    // {
      inherit
        name
        groupName
        vmId
        ip
        gateway
        tapName
        extraConfig
        ;
      group = groupName;
      groupConfig = group;
      groupId = group.groupId;
      bridgeName = group.bridgeName;
      isolated = machine.isolated or group.isolated;
      ipCidr = machine.ipCidr or "${ip}/${toString group.cidr}";
      vsockCid = machine.vsockCid or (20000 + (group.groupId * 256) + vmId);
      mac = machine.mac or "02:00:${hexByte group.groupId}:${hexByte vmIdHi}:${hexByte vmIdLo}:01";
    };

  resolveMachines =
    {
      machines,
      bridgeGroups,
    }:
    let
      machineNames = builtins.attrNames machines;
      resolved = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = resolveMachine {
            inherit name bridgeGroups;
            machine = machines.${name};
          };
        }) machineNames
      );
      machineValues = builtins.attrValues resolved;
      vmIdsByGroup = lib.foldl' (
        acc: machine:
        let
          currentVmIds = acc.${machine.group} or [ ];
        in
        acc
        // {
          "${machine.group}" = currentVmIds ++ [ machine.vmId ];
        }
      ) { } machineValues;
      groupVmIdChecks = map (
        groupName: ensureNoDuplicates "machines in group `${groupName}` vmId" vmIdsByGroup.${groupName}
      ) (builtins.attrNames vmIdsByGroup);
    in
    assert builtins.all (check: check) groupVmIdChecks;
    assert ensureNoDuplicates "machine ip addresses" (map (machine: machine.ip) machineValues);
    assert ensureNoDuplicates "machine vsock CIDs" (map (machine: machine.vsockCid) machineValues);
    assert ensureNoDuplicates "machine MAC addresses" (map (machine: machine.mac) machineValues);
    assert ensureNoDuplicates "machine tap names" (map (machine: machine.tapName) machineValues);
    resolved;

  mkVmRef = machine: {
    inherit (machine)
      name
      group
      groupId
      vmId
      ip
      ipCidr
      gateway
      vsockCid
      mac
      tapName
      bridgeName
      isolated
      ;
  };

  mkTopology =
    resolvedMachines:
    let
      machineValues = builtins.attrValues resolvedMachines;
      byName = lib.mapAttrs (_: machine: mkVmRef machine) resolvedMachines;
      groupNames = lib.unique (map (machine: machine.group) machineValues);
      byGroup = builtins.listToAttrs (
        map (
          groupName:
          let
            groupMachines = lib.sort (a: b: a.vmId < b.vmId) (
              builtins.filter (machine: machine.group == groupName) machineValues
            );
          in
          {
            name = groupName;
            value = {
              names = map (machine: machine.name) groupMachines;
              machines = builtins.listToAttrs (map (machine: {
                name = machine.name;
                value = mkVmRef machine;
              }) groupMachines);
            };
          }
        ) groupNames
      );
    in
    {
      inherit byName byGroup;
    };

  mkVmConfig =
    {
      name,
      mac,
      ipCidr,
      gateway,
      vsockCid,
      tapName,
      mem ? 256,
      vcpu ? 1,
      nameservers ? [
        "1.1.1.1"
        "8.8.8.8"
      ],
      extraConfig ? [ ],
      vmSelf ? null,
      vmTopology ? null,
      ...
    }:
    {
      imports = if builtins.isList extraConfig then extraConfig else [ extraConfig ];

      _module.args = {
        inherit vmSelf vmTopology;
      };

      networking.hostName = name;
      networking.useDHCP = false;
      networking.useNetworkd = true;
      networking.nameservers = nameservers;

      systemd.network.enable = true;
      systemd.network.networks."10-uplink" = {
        matchConfig.MACAddress = mac;
        address = [ ipCidr ];
        routes = [ { Gateway = gateway; } ];
        networkConfig = {
          DNS = nameservers;
          MulticastDNS = true;
        };
      };
      services.resolved = {
        enable = true;
        settings.Resolve = {
          MulticastDNS = true;
          LLMNR = false;
        };
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
    };

  mkVmEntry =
    {
      spec,
      vmTopology,
    }:
    {
      name = spec.name;
      value = {
        config = mkVmConfig (
          spec
          // {
            vmSelf = vmTopology.byName.${spec.name};
            inherit vmTopology;
          }
        );
      };
    };
in
{
  inherit
    sanitizeName
    hexByte
    mkTapNameAuto
    resolveGroups
    resolveMachine
    resolveMachines
    mkTopology
    mkVmConfig
    mkVmEntry
    ;
}
