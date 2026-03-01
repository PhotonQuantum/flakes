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

  mkMachineId =
    name:
    let
      hash = builtins.hashString "sha256" name;
    in
    lib.substring 0 32 hash;

  mkCredentialName =
    targetPath:
    "K${lib.toUpper (lib.substring 0 24 (builtins.hashString "sha256" targetPath))}";

  resolveBackupDefaults =
    backupDefaults:
    let
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
      (builtins.match "^/.*" passFile != null)
      "backupDefaults.passFile must be an absolute path; got `${passFile}`";
    assert ensure
      (builtins.match "^/.*" sshKeyPath != null)
      "backupDefaults.sshKeyPath must be an absolute path; got `${sshKeyPath}`";
    {
      inherit
        startAt
        passFile
        sshKeyPath
        prune
        ;
    };

  resolveSnapshotRoot =
    snapshotRoot:
    let
      resolvedSnapshotRoot = if snapshotRoot == null then "/srv/.snapshots/microvm-borg" else snapshotRoot;
    in
    assert ensure
      (builtins.match "^/srv(/.*)?$" resolvedSnapshotRoot != null)
      "snapshotRoot must be an absolute path under /srv; got `${resolvedSnapshotRoot}`";
    resolvedSnapshotRoot;

  resolveVolumePath =
    volumePath:
    assert ensure
      (builtins.match "^/srv(/.*)?$" volumePath != null)
      "volumePath must be an absolute path under /srv; got `${volumePath}`";
    volumePath;

  resolveDataVolume =
    {
      name,
      dataVolume,
      volumePath,
    }:
    if dataVolume == null then
      null
    else
      let
        sizeMiB =
          dataVolume.sizeMiB
            or (throw "machines.${name}.dataVolume.sizeMiB is required");
        mountPoint = dataVolume.mountPoint or "/mnt";
        hostImagePath = "${volumePath}/${name}/image.img";
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
      assert ensure
        (label == null || builtins.stringLength label <= 16)
        "machines.${name}.dataVolume.label must be at most 16 characters; got `${toString label}`";
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
        passFile = backup.passFile or backupDefaults.passFile;
        sshKeyPath = backup.sshKeyPath or backupDefaults.sshKeyPath;
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
      assert ensure
        (builtins.match "^/.*" passFile != null)
        "machines.${name}.backup.passFile must be an absolute path; got `${toString passFile}`";
      assert ensure
        (builtins.match "^/.*" sshKeyPath != null)
        "machines.${name}.backup.sshKeyPath must be an absolute path; got `${toString sshKeyPath}`";
      {
        inherit
          repo
          startAt
          archivePrefix
          pruneKeep
          passFile
          sshKeyPath
          ;
      };

  resolveKeys =
    {
      name,
      keys ? { },
    }:
    let
      keyTargets = builtins.attrNames keys;
      resolvedKeys = map (
        targetPath:
        let
          keySpec = keys.${targetPath};
          file =
            keySpec.file
              or (throw "machines.${name}.keys.\"${targetPath}\".file is required");
          user = keySpec.user or "root";
          group = keySpec.group or "root";
          permissions = keySpec.permissions or "0600";
          credentialName = mkCredentialName targetPath;
        in
        assert ensure
          (builtins.isAttrs keySpec)
          "machines.${name}.keys.\"${targetPath}\" must be an attribute set";
        assert ensure
          (builtins.match "^/.*" targetPath != null)
          "machines.${name}.keys key `${targetPath}` must be an absolute guest target path";
        assert ensure
          (builtins.isString file && builtins.match "^/.*" file != null)
          "machines.${name}.keys.\"${targetPath}\".file must be an absolute host path string; got `${toString file}`";
        assert ensure
          (builtins.isString user && user != "")
          "machines.${name}.keys.\"${targetPath}\".user must be a non-empty string";
        assert ensure
          (builtins.isString group && group != "")
          "machines.${name}.keys.\"${targetPath}\".group must be a non-empty string";
        assert ensure
          (builtins.isString permissions && builtins.match "^[0-7]{3,4}$" permissions != null)
          "machines.${name}.keys.\"${targetPath}\".permissions must be a 3-4 digit octal string (e.g. 600 or 0600); got `${toString permissions}`";
        {
          inherit
            targetPath
            file
            user
            group
            permissions
            credentialName
            ;
        }
      ) keyTargets;
      credentialNames = map (key: key.credentialName) resolvedKeys;
    in
    assert ensureNoDuplicates "machines.${name}.keys credential names" credentialNames;
    resolvedKeys;

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
      volumePath,
    }:
    let
      groupName = machine.group;
      group =
        bridgeGroups.${groupName}
          or (throw "Unknown MicroVM group `${groupName}` for machine `${name}`");
      vmId = machine.vmId;
      machineId = mkMachineId name;
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
      dataVolumeResolved = resolveDataVolume {
        inherit name volumePath;
        dataVolume = machine.dataVolume or null;
      };
      backupResolved = resolveBackup {
        inherit name backupDefaults dataVolumeResolved;
        backup = machine.backup or null;
      };
      keysResolved = resolveKeys {
        inherit name;
        keys = machine.keys or { };
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
    assert ensure
      (builtins.match "^[0-9a-f]{32}$" machineId != null)
      "derived machine ID for machine `${name}` must be 32 lowercase hex characters; got `${machineId}`";
    machine
    // {
      inherit
        name
        machineId
        groupName
        vmId
        ip
        gateway
        tapName
        extraConfig
        dataVolumeResolved
        backupResolved
        keysResolved
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
      volumePath ? "/srv/microvms",
    }:
    let
      resolvedBackupDefaults = resolveBackupDefaults backupDefaults;
      resolvedVolumePath = resolveVolumePath volumePath;
      machineNames = builtins.attrNames machines;
      resolved = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = resolveMachine {
            inherit name bridgeGroups;
            machine = machines.${name};
            backupDefaults = resolvedBackupDefaults;
            volumePath = resolvedVolumePath;
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
    assert ensureNoDuplicates "machine names" (map (machine: machine.name) machineValues);
    assert builtins.all (check: check) groupVmIdChecks;
    assert ensureNoDuplicates "machine ip addresses" (map (machine: machine.ip) machineValues);
    assert ensureNoDuplicates "machine IDs" (map (machine: machine.machineId) machineValues);
    assert ensureNoDuplicates "machine vsock CIDs" (map (machine: machine.vsockCid) machineValues);
    assert ensureNoDuplicates "machine MAC addresses" (map (machine: machine.mac) machineValues);
    assert ensureNoDuplicates "machine tap names" (map (machine: machine.tapName) machineValues);
    assert ensureNoDuplicates "machines.*.dataVolume.hostImagePath" dataVolumeHostImagePaths;
    assert ensureNoDuplicates "machines.*.backup.repo" backupRepos;
    resolved;

  mkVmRef = machine: {
    inherit (machine)
      name
      machineId
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
      machineId,
      mem ? 256,
      vcpu ? 1,
      nameservers ? [
        "1.1.1.1"
        "8.8.8.8"
      ],
      extraConfig ? [ ],
      dataVolumeResolved ? null,
      keysResolved ? [ ],
      vmSelf ? null,
      vmTopology ? null,
      ...
    }:
    let
      hasKeys = keysResolved != [ ];
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
      credentialFilesFromKeys = builtins.listToAttrs (map (key: {
        name = key.credentialName;
        value = key.file;
      }) keysResolved);
      installKeyCommands = lib.concatMapStringsSep "\n" (
        key: ''
          if [ ! -f "$CREDENTIALS_DIRECTORY/${key.credentialName}" ]; then
            echo "Missing credential ${key.credentialName} for ${key.targetPath}" >&2
            exit 1
          fi
          install -D -m ${lib.escapeShellArg key.permissions} -o ${lib.escapeShellArg key.user} -g ${lib.escapeShellArg key.group} "$CREDENTIALS_DIRECTORY/${key.credentialName}" ${lib.escapeShellArg key.targetPath}
        ''
      ) keysResolved;
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

      environment.etc."machine-id" = {
        mode = "0644";
        text = "${machineId}\n";
      };

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

      systemd.services.microvm-install-keys = lib.mkIf hasKeys {
        description = "Install MicroVM key files from systemd credentials";
        before = [ "basic.target" ];
        after = [
          "local-fs.target"
          "systemd-sysusers.service"
        ];
        requiredBy = [ "basic.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = map (key: key.credentialName) keysResolved;
        };
        script = ''
          set -eu
          ${installKeyCommands}
        '';
      };

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
        shares = [
          {
            source = "/var/lib/microvms/${name}/journal";
            mountPoint = "/var/log/journal";
            tag = "journal";
            proto = "virtiofs";
            socket = "journal.sock";
          }
        ];
        vsock.cid = vsockCid;
        inherit vcpu mem;
      }
      // lib.optionalAttrs hasKeys {
        credentialFiles = credentialFilesFromKeys;
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
    mkMachineId
    resolveBackupDefaults
    resolveSnapshotRoot
    resolveGroups
    resolveKeys
    resolveMachine
    resolveMachines
    mkTopology
    mkVmConfig
    mkVmEntry
    ;
}
