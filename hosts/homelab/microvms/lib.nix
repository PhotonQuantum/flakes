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

  mkCredentialName =
    targetPath:
    "K${lib.toUpper (lib.substring 0 24 (builtins.hashString "sha256" targetPath))}";

  tailscaleServeToEndpoint =
    serviceName: serve:
    let
      parts = lib.splitString ":" serve;
      protocol = builtins.elemAt parts 0;
      port = builtins.elemAt parts 1;
    in
    assert lib.assertMsg
      (builtins.length parts == 2)
      "tailscale service ${serviceName}.serve must be formatted as `<protocol>:<port>`";
    if builtins.elem protocol [ "https" "http" ] then
      "tcp:${port}"
    else
      "${protocol}:${port}";

  certGroup = "cert";
  certGroupGid = 954;

  resolveBackupDefaults =
    backupDefaults:
    let
      startAt = backupDefaults.startAt or "daily";
      compression = backupDefaults.compression or "auto,zstd";
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
        compression
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
        compression = backup.compression or backupDefaults.compression;
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
        (builtins.isString compression && compression != "")
        "machines.${name}.backup.compression must be a non-empty string";
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
          compression
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

  resolveCert =
    {
      name,
      cert ? { },
      certDefaults,
    }:
    let
      enabled = cert.enable or false;
      defaultDomain =
        certDefaults.domain
          or (throw "certDefaults.domain is required when machines.${name}.cert.enable = true");
      domain = cert.domain or "${name}.${defaultDomain}";
      hostSharePath = "/srv/microvms/certs/${name}";
      mountPoint = "/run/homelab-certs";
    in
    if !enabled then
      {
        enabled = false;
      }
    else
      assert ensure
        (builtins.isAttrs cert)
        "machines.${name}.cert must be an attribute set";
      assert ensure
        (builtins.isBool enabled)
        "machines.${name}.cert.enable must be a boolean";
      assert ensure
        (builtins.isString domain && domain != "")
        "machines.${name}.cert.domain must be a non-empty string";
      assert ensure
        (builtins.isString defaultDomain && defaultDomain != "")
        "certDefaults.domain must be a non-empty string";
      assert ensure
        (!(cert ? user))
        "machines.${name}.cert.user is no longer supported; cert files are owned by root:${certGroup}";
      assert ensure
        (!(cert ? group))
        "machines.${name}.cert.group is no longer supported; cert files are owned by root:${certGroup}";
      {
        inherit
          enabled
          domain
          hostSharePath
          mountPoint
          ;
        group = certGroup;
        gid = certGroupGid;
        certPath = "${mountPoint}/fullchain.pem";
        keyPath = "${mountPoint}/key.pem";
        chainPath = "${mountPoint}/chain.pem";
        certOnlyPath = "${mountPoint}/cert.pem";
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
            layout = group.layout or "managed";
            usesManagedSubnet = layout == "managed";
            gateway =
              if usesManagedSubnet then
                group.gateway or "${group.ipv4Prefix}.${toString group.gatewayHost}"
              else
                null;
            bridgeAddress =
              if usesManagedSubnet then
                group.bridgeAddress or "${gateway}/${toString group.cidr}"
              else
                null;
            networkPolicyDefaults = {
              hostAccess = false;
              lanAccess = false;
              inBridgeInterconnect = true;
            };
            networkPolicy = networkPolicyDefaults // (group.networkPolicy or { });
          in
          assert ensure
            (builtins.elem layout [ "managed" "uplink-dhcp" ])
            "bridgeGroups.${groupName}.layout must be one of `managed` or `uplink-dhcp`; got `${toString layout}`";
          assert ensure
            (usesManagedSubnet || !(group ? networkPolicy))
            "bridgeGroups.${groupName}.networkPolicy is only supported when layout = \"managed\"";
          assert ensureRange "bridgeGroups.${groupName}.groupId" group.groupId 1 254;
          assert ensure
            (builtins.isString group.bridgeName && group.bridgeName != "")
            "bridgeGroups.${groupName}.bridgeName must be a non-empty string";
          assert ensure
            (builtins.stringLength group.bridgeName <= 15)
            "bridgeGroups.${groupName}.bridgeName `${group.bridgeName}` is longer than Linux max length 15";
          assert ensure
            (!usesManagedSubnet || (group ? ipv4Prefix))
            "bridgeGroups.${groupName}.ipv4Prefix is required when layout = \"managed\"";
          assert ensure
            (!usesManagedSubnet || (group ? cidr))
            "bridgeGroups.${groupName}.cidr is required when layout = \"managed\"";
          assert ensure
            (!usesManagedSubnet || (group ? gatewayHost))
            "bridgeGroups.${groupName}.gatewayHost is required when layout = \"managed\"";
          assert ensure
            (!usesManagedSubnet || ensureRange "bridgeGroups.${groupName}.cidr" group.cidr 1 32)
            "bridgeGroups.${groupName}.cidr must be between 1 and 32";
          assert ensure
            (!usesManagedSubnet || ensureRange "bridgeGroups.${groupName}.gatewayHost" group.gatewayHost 1 254)
            "bridgeGroups.${groupName}.gatewayHost must be between 1 and 254";
          assert ensure
            (builtins.isBool networkPolicy.hostAccess)
            "bridgeGroups.${groupName}.networkPolicy.hostAccess must be a boolean";
          assert ensure
            (builtins.isBool networkPolicy.lanAccess)
            "bridgeGroups.${groupName}.networkPolicy.lanAccess must be a boolean";
          assert ensure
            (builtins.isBool networkPolicy.inBridgeInterconnect)
            "bridgeGroups.${groupName}.networkPolicy.inBridgeInterconnect must be a boolean";
          {
            name = groupName;
            value = group // {
              name = groupName;
              inherit layout usesManagedSubnet;
              inherit gateway bridgeAddress;
              inherit networkPolicy;
            };
          }
        ) groupNames
      );
      groupValues = builtins.attrValues resolved;
      uplinkDhcpGroups = builtins.filter (group: group.layout == "uplink-dhcp") groupValues;
    in
    assert ensureNoDuplicates "bridgeGroups.*.groupId" (map (group: group.groupId) groupValues);
    assert ensureNoDuplicates "bridgeGroups.*.bridgeName" (map (group: group.bridgeName) groupValues);
    assert ensure
      (builtins.length uplinkDhcpGroups <= 1)
      "Only one bridgeGroups entry may use layout = `uplink-dhcp`";
    resolved;

  resolveMachine =
    {
      name,
      machine,
      bridgeGroups,
      backupDefaults,
      certDefaults,
      resolveCerts ? true,
      volumePath,
    }:
    let
      groupName = machine.group;
      group =
        bridgeGroups.${groupName}
          or (throw "Unknown MicroVM group `${groupName}` for machine `${name}`");
      vmId = machine.vmId;
      usesManagedSubnet = group.usesManagedSubnet;
      usesDhcp = !usesManagedSubnet;
      ip =
        if usesManagedSubnet then
          machine.ip or "${group.ipv4Prefix}.${toString vmId}"
        else
          null;
      gateway =
        if usesManagedSubnet then
          machine.gateway or group.gateway
        else
          null;
      tapName = machine.tapName or (mkTapNameAuto name vmId);
      tailscaleEnabled = machine.tailscale.enable or false;
      tailscale = (machine.tailscale or { }) // {
        services = lib.mapAttrs (
          serviceName: service:
          service
          // {
            endpoint = tailscaleServeToEndpoint serviceName service.serve;
          }
        ) (machine.tailscale.services or { });
      };
      moduleInput = machine.module or machine.extraConfig or null;
      machineExtraConfig =
        if moduleInput == null then
          [ ]
        else if builtins.isList moduleInput then
          moduleInput
        else
          [ moduleInput ];
      extraConfig = machineExtraConfig ++ lib.optionals tailscaleEnabled [ ./vms/tailscale.nix ];
      extraOptions = machine.extraOptions or { };
      machineKeys = machine.keys or { };
      tailscaleKeys = lib.optionalAttrs tailscaleEnabled {
        "/var/keys/tailscale-auth-key" = {
          file = "/var/keys/tailscale_${name}_authkey";
          user = "root";
          group = "root";
          permissions = "0400";
        };
      };
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
        keys = machineKeys // tailscaleKeys;
      };
      certResolved =
        if resolveCerts then
          resolveCert {
            inherit name certDefaults;
            cert = machine.cert or { };
          }
        else
          {
            enabled = false;
          };
      vmIdHi = builtins.div vmId 256;
      vmIdLo = vmId - (vmIdHi * 256);
    in
    assert ensureRange "machines.${name}.vmId" vmId 2 254;
    assert ensure
      (!usesManagedSubnet || vmId != group.gatewayHost)
      "machines.${name}.vmId (${toString vmId}) must not match gateway host (${toString group.gatewayHost})";
    assert ensure
      (builtins.stringLength tapName <= 15)
      "tap name `${tapName}` for machine `${name}` is longer than Linux max length 15";
    assert ensure
      (builtins.isAttrs extraOptions)
      "machines.${name}.extraOptions must be an attribute set";
    assert ensure
      (usesManagedSubnet || !(machine ? ip))
      "machines.${name}.ip is only supported when the group layout is `managed`";
    assert ensure
      (usesManagedSubnet || !(machine ? gateway))
      "machines.${name}.gateway is only supported when the group layout is `managed`";
    assert ensure
      (usesManagedSubnet || !(machine ? ipCidr))
      "machines.${name}.ipCidr is only supported when the group layout is `managed`";
    assert ensure
      (!tailscaleEnabled || !(builtins.hasAttr "/var/keys/tailscale-auth-key" machineKeys))
      "machines.${name}.keys already defines `/var/keys/tailscale-auth-key`, which is reserved for tailscale.enable";
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
        extraOptions
        volumePath
        dataVolumeResolved
        backupResolved
        keysResolved
        certResolved
        tailscale
        usesManagedSubnet
        usesDhcp
        ;
      group = groupName;
      groupConfig = group;
      groupId = group.groupId;
      bridgeName = group.bridgeName;
      ipCidr =
        if usesManagedSubnet then
          machine.ipCidr or "${ip}/${toString group.cidr}"
        else
          null;
      vsockCid = machine.vsockCid or (20000 + (group.groupId * 256) + vmId);
      mac = machine.mac or "02:00:${hexByte group.groupId}:${hexByte vmIdHi}:${hexByte vmIdLo}:01";
    };

  resolveMachines =
    {
      machines,
      bridgeGroups,
      backupDefaults ? { },
      certDefaults ? { },
      resolveCerts ? certDefaults != { },
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
            inherit certDefaults resolveCerts;
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
      managedMachineIps = map
        (machine: machine.ip)
        (builtins.filter (machine: machine.ip != null) machineValues);
      certDomains = map
        (machine: machine.certResolved.domain)
        (builtins.filter (machine: machine.certResolved.enabled) machineValues);
    in
    assert ensureNoDuplicates "machine names" (map (machine: machine.name) machineValues);
    assert builtins.all (check: check) groupVmIdChecks;
    assert ensureNoDuplicates "machine ip addresses" managedMachineIps;
    assert ensureNoDuplicates "machine vsock CIDs" (map (machine: machine.vsockCid) machineValues);
    assert ensureNoDuplicates "machine MAC addresses" (map (machine: machine.mac) machineValues);
    assert ensureNoDuplicates "machine tap names" (map (machine: machine.tapName) machineValues);
    assert ensureNoDuplicates "machines.*.dataVolume.hostImagePath" dataVolumeHostImagePaths;
    assert ensureNoDuplicates "machines.*.backup.repo" backupRepos;
    assert ensureNoDuplicates "machines.*.cert.domain" certDomains;
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
      usesDhcp ? false,
      mem ? 256,
      vcpu ? 1,
      nameservers ? [
        "1.1.1.1"
        "8.8.8.8"
      ],
      extraConfig ? [ ],
      extraOptions ? { },
      volumePath ? "/srv/microvms",
      dataVolumeResolved ? null,
      keysResolved ? [ ],
      certResolved ? { enabled = false; },
      tailscale ? { },
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
      volumeFromTailscaleState =
        lib.optionals (tailscale.enable or false) [
          {
            image = "${volumePath}/${name}/tailscale-state.img";
            mountPoint = "/var/lib/tailscale";
            size = 8;
            fsType = "ext4";
            label = "tailscale";
          }
        ];
      certShares =
        lib.optionals certResolved.enabled [
          {
            source = certResolved.hostSharePath;
            mountPoint = certResolved.mountPoint;
            tag = "certs-${sanitizeName name}";
            proto = "virtiofs";
            readOnly = true;
          }
        ];
      extraOptionShares = extraOptions.shares or [ ];
      credentialFiles = let 
        credentialFilesFromKeys = builtins.listToAttrs (map (key: {
          name = key.credentialName;
          value = key.file;
        }) keysResolved);
        ephemeralSshCredentialFiles = {
          # NOTE QEMU fw_cfg names are limited to 55 bytes including
          # "opt/io.systemd.credentials/", so use the shorter root-specific
          # systemd SSH credential rather than ssh.ephemeral-authorized_keys-all.
          # TODO we can probably switch to the all-users ephemeral SSH key once https://github.com/microvm-nix/microvm.nix/issues/511 gets implemented.
          "ssh.authorized_keys.root" = ../../../secrets/id_rsa.pub;
        };
        in
        credentialFilesFromKeys // ephemeralSshCredentialFiles;
      installKeyCommands = lib.concatMapStringsSep "\n" (
        key: ''
          if [ ! -f "$CREDENTIALS_DIRECTORY/${key.credentialName}" ]; then
            echo "Missing credential ${key.credentialName} for ${key.targetPath}" >&2
            exit 1
          fi
          install -D -m ${lib.escapeShellArg key.permissions} -o ${lib.escapeShellArg key.user} -g ${lib.escapeShellArg key.group} "$CREDENTIALS_DIRECTORY/${key.credentialName}" ${lib.escapeShellArg key.targetPath}
        ''
      ) keysResolved;
      generatedMicrovm = {
        hypervisor = "qemu";
        interfaces = [
          {
            type = "tap";
            id = tapName;
            inherit mac;
          }
        ];
        volumes = volumeFromDataVolume ++ volumeFromTailscaleState;
        shares = certShares ++ extraOptionShares;
        vsock.cid = vsockCid;
        registerWithMachined = true;
        inherit vcpu mem;
        # storeDiskErofsFlags = ["-zlz4hc" "-Eztailpacking"]; # FIXME this is a debug option for faster disk generation
        inherit credentialFiles;
      };
    in
    { pkgs, ... }:
    {
      imports = if builtins.isList extraConfig then extraConfig else [ extraConfig ];

      _module.args = {
        inherit vmSelf vmTopology;
        vmTailscale = tailscale;
        vmCert =
          if certResolved.enabled then
            {
              enabled = true;
              inherit (certResolved)
                domain
                group
                gid
                certPath
                keyPath
                chainPath
                certOnlyPath
                ;
            }
          else
            {
              enabled = false;
            };
      };

      users.groups.${certGroup} = lib.mkIf certResolved.enabled {
        gid = certGroupGid;
      };

      services.journald.extraConfig = ''
        ForwardToSocket=vsock:2:19534
      '';

      networking.hostName = name;
      networking.useDHCP = false;
      networking.useNetworkd = true;
      networking.nameservers = if usesDhcp then [ ] else nameservers;

      systemd.network.enable = true;
      systemd.network.networks."10-uplink" =
        if usesDhcp then
          {
            matchConfig.MACAddress = mac;
            networkConfig = {
              DHCP = "ipv4";
              IPv6AcceptRA = true;
              MulticastDNS = true;
            };
          }
        else
          {
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
      services.fstrim.enable = true;

      networking.firewall.allowedUDPPorts = [
        5353 # mDNS
      ];

      boot.blacklistedKernelModules = [
        "esp4"
        "esp6"
        "rxrpc"
      ];

      boot.extraModprobeConfig = ''
        install esp4 ${pkgs.coreutils}/bin/false
        install esp6 ${pkgs.coreutils}/bin/false
        install rxrpc ${pkgs.coreutils}/bin/false
      '';

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

      services.openssh = {
        enable = true;
        ports = lib.mkDefault [];
        startWhenNeeded = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "prohibit-password";
          AllowAgentForwarding = false;
          X11Forwarding = false;
          PermitTunnel = false;
        };
      };

      # Keep sshd available for systemd-ssh-generator without exposing
      # a TCP listener from the guest network.
      boot.kernelParams = [ "systemd.ssh_listen=vsock::22" ];
      boot.kernelPackages = pkgs.linuxPackages_latest;

      microvm = generatedMicrovm // (builtins.removeAttrs extraOptions [ "shares" ]);

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
    certGroup
    certGroupGid
    hexByte
    mkTapNameAuto
    resolveBackupDefaults
    resolveSnapshotRoot
    resolveGroups
    resolveKeys
    resolveCert
    resolveMachine
    resolveMachines
    mkTopology
    mkVmConfig
    mkVmEntry
    ;
}
