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

  resolveBackupDefaults =
    backupDefaults:
    let
      snapshotRoot = backupDefaults.snapshotRoot or "/srv/.snapshots/microvm-borg";
      startAt = backupDefaults.startAt or "daily";
      passFile = backupDefaults.passFile or "/var/keys/homelab_borg.pass";
      sshKeyPath = backupDefaults.sshKeyPath or "/var/keys/id_ed25519_homelab_borg";
      prune = backupDefaults.prune or {
        within = "24H";
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };
    in
    assert ensure
      (builtins.match "^/srv(/.*)?$" snapshotRoot != null)
      "backupDefaults.snapshotRoot must be an absolute path under /srv; got `${snapshotRoot}`";
    assert ensure
      (builtins.match "^/.*" passFile != null)
      "backupDefaults.passFile must be an absolute path; got `${passFile}`";
    assert ensure
      (builtins.match "^/.*" sshKeyPath != null)
      "backupDefaults.sshKeyPath must be an absolute path; got `${sshKeyPath}`";
    {
      inherit
        snapshotRoot
        startAt
        passFile
        sshKeyPath
        prune
        ;
    };

  resolveDataVolume =
    name: dataVolume:
    if dataVolume == null then
      null
    else
      let
        sizeMiB =
          dataVolume.sizeMiB
            or (throw "machines.${name}.dataVolume.sizeMiB is required");
        mountPoint = dataVolume.mountPoint or "/mnt";
        hostImagePath = "/srv/microvms/${name}/image.img";
        fsType = dataVolume.fsType or "ext4";
        label = dataVolume.label or null;
      in
      assert ensure
        (!(dataVolume ? hostImagePath))
        "machines.${name}.dataVolume.hostImagePath is no longer supported; image path is fixed to `${hostImagePath}`";
      assert ensure
        (builtins.isInt sizeMiB && sizeMiB >= 1)
        "machines.${name}.dataVolume.sizeMiB must be a positive integer (MiB); got `${toString sizeMiB}`";
      assert ensure
        (builtins.match "^/.*" mountPoint != null)
        "machines.${name}.dataVolume.mountPoint must be an absolute path; got `${mountPoint}`";
      {
        inherit
          sizeMiB
          mountPoint
          hostImagePath
          fsType
          label
          ;
      };

  resolveBackup =
    {
      name,
      backup,
      backupDefaults,
      dataVolumeResolved,
      dataVolumeSubvolumePath,
      dataVolumeImageBasename,
      backupSnapshotParent,
    }:
    if backup == null then
      null
    else
      let
        repo =
          backup.repo
            or (throw "machines.${name}.backup.repo is required when backup is configured");
        startAt = backup.startAt or backupDefaults.startAt;
        archivePrefix = backup.archivePrefix or name;
        pruneKeep = backupDefaults.prune // (backup.prune or { });
      in
      assert ensure
        (dataVolumeResolved != null)
        "machines.${name}.backup requires machines.${name}.dataVolume";
      assert ensure
        (builtins.isString repo && repo != "")
        "machines.${name}.backup.repo must be a non-empty string";
      assert ensure
        (builtins.isString startAt && startAt != "")
        "machines.${name}.backup.startAt must be a non-empty string";
      assert ensure
        (builtins.isString archivePrefix && archivePrefix != "")
        "machines.${name}.backup.archivePrefix must be a non-empty string";
      {
        inherit
          repo
          startAt
          archivePrefix
          pruneKeep
          dataVolumeSubvolumePath
          dataVolumeImageBasename
          backupSnapshotParent
          ;
        imagePath = dataVolumeResolved.hostImagePath;
        imagePathInArchive = dataVolumeImageBasename;
        inherit (backupDefaults)
          snapshotRoot
          passFile
          sshKeyPath
          ;
      };

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
      backupDefaults,
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
      dataVolumeResolved = resolveDataVolume name (machine.dataVolume or null);
      dataVolumeSubvolumePath = if dataVolumeResolved == null then null else "/srv/microvms/${name}";
      dataVolumeImageBasename = if dataVolumeResolved == null then null else "image.img";
      backupSnapshotParent = if dataVolumeResolved == null then null else "${backupDefaults.snapshotRoot}/${name}";
      backupResolved = resolveBackup {
        inherit
          name
          backupDefaults
          dataVolumeResolved
          dataVolumeSubvolumePath
          dataVolumeImageBasename
          backupSnapshotParent
          ;
        backup = machine.backup or null;
      };
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
        dataVolumeResolved
        dataVolumeSubvolumePath
        dataVolumeImageBasename
        backupSnapshotParent
        backupResolved
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
      backupDefaults ? { },
    }:
    let
      resolvedBackupDefaults = resolveBackupDefaults backupDefaults;
      machineNames = builtins.attrNames machines;
      resolved = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = resolveMachine {
            inherit name bridgeGroups;
            machine = machines.${name};
            backupDefaults = resolvedBackupDefaults;
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
      dataVolumeHostImagePaths = map
        (machine: machine.dataVolumeResolved.hostImagePath)
        (builtins.filter (machine: machine.dataVolumeResolved != null) machineValues);
      backupRepos = map
        (machine: machine.backupResolved.repo)
        (builtins.filter (machine: machine.backupResolved != null) machineValues);
    in
    assert builtins.all (check: check) groupVmIdChecks;
    assert ensureNoDuplicates "machine ip addresses" (map (machine: machine.ip) machineValues);
    assert ensureNoDuplicates "machine vsock CIDs" (map (machine: machine.vsockCid) machineValues);
    assert ensureNoDuplicates "machine MAC addresses" (map (machine: machine.mac) machineValues);
    assert ensureNoDuplicates "machine tap names" (map (machine: machine.tapName) machineValues);
    assert ensureNoDuplicates "machines.*.dataVolume.hostImagePath" dataVolumeHostImagePaths;
    assert ensureNoDuplicates "machines.*.backup.repo" backupRepos;
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
      dataVolumeResolved ? null,
      vmSelf ? null,
      vmTopology ? null,
      ...
    }:
    let
      volumeFromDataVolume =
        if dataVolumeResolved == null then
          [ ]
        else
          [
            ({
              image = dataVolumeResolved.hostImagePath;
              mountPoint = dataVolumeResolved.mountPoint;
              size = dataVolumeResolved.sizeMiB;
              fsType = dataVolumeResolved.fsType;
            }
            // lib.optionalAttrs (dataVolumeResolved.label != null) {
              label = dataVolumeResolved.label;
            })
          ];
    in
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
        hypervisor = "qemu";
        interfaces = [
          {
            type = "tap";
            id = tapName;
            inherit mac;
          }
        ];
        volumes = volumeFromDataVolume;
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
    resolveBackupDefaults
    resolveGroups
    resolveMachine
    resolveMachines
    mkTopology
    mkVmConfig
    mkVmEntry
    ;
}
