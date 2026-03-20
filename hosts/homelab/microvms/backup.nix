{ lib, pkgs, ... }:
let
  vmLib = import ./lib.nix { inherit lib; };
  registry = import ./registry.nix;
  backupDefaults = vmLib.resolveBackupDefaults (registry.backupDefaults or { });
  snapshotRoot = vmLib.resolveSnapshotRoot (registry.snapshotRoot or null);
  volumePath = registry.volumePath or "/srv/microvms";
  inherit (registry) bridgeGroups machines;

  resolvedGroups = vmLib.resolveGroups bridgeGroups;
  resolvedMachines = vmLib.resolveMachines {
    inherit backupDefaults machines volumePath;
    bridgeGroups = resolvedGroups;
  };

  backupMachines = lib.filterAttrs (_: machine: machine.backupResolved != null) resolvedMachines;
  backupVmNames = builtins.attrNames backupMachines;
  hasBackupMachines = backupVmNames != [ ];

  snapshotTmpfiles = if hasBackupMachines then [ "d ${snapshotRoot} 0750 root root - -" ] else [ ];

  subvolumePath = name: "${volumePath}/${name}";
  snapshotParent = name: "${snapshotRoot}/${name}";
  snapshotCurrent = name: "${snapshotParent name}/current";

  borgJobs = lib.mapAttrs' (
    name: machine:
    let
      backup = machine.backupResolved;
      vmSubvolumePath = subvolumePath name;
      vmSnapshotParent = snapshotParent name;
      vmSnapshotCurrent = snapshotCurrent name;
    in
    {
      name = "microvm-${name}";
      value = {
        archiveBaseName = backup.archivePrefix;
        repo = backup.repo;
        startAt = backup.startAt;
        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat ${backup.passFile}";
        };
        environment = {
          BORG_RSH = "ssh -i ${backup.sshKeyPath}";
        };
        readWritePaths = [ snapshotRoot ];
        paths = [ "${vmSnapshotCurrent}/./." ];
        prune.keep = backup.pruneKeep;
        extraCreateArgs = [ "-p" ];
        preHook = ''
          set -eu

          is_btrfs_subvolume() {
            ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$1" >/dev/null 2>&1
          }

          ${pkgs.coreutils}/bin/mkdir -p '${vmSnapshotParent}'

          if [ -e '${vmSnapshotCurrent}' ]; then
            if is_btrfs_subvolume '${vmSnapshotCurrent}'; then
              ${pkgs.btrfs-progs}/bin/btrfs subvolume delete '${vmSnapshotCurrent}'
            else
              echo "Refusing to delete stale non-subvolume snapshot path: ${vmSnapshotCurrent}" >&2
              exit 1
            fi
          fi

          ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r \
            '${vmSubvolumePath}' \
            '${vmSnapshotCurrent}'
        '';
        postHook = ''
          set +e

          if [ -e '${vmSnapshotCurrent}' ]; then
            if ${pkgs.btrfs-progs}/bin/btrfs subvolume show '${vmSnapshotCurrent}' >/dev/null 2>&1; then
              ${pkgs.btrfs-progs}/bin/btrfs subvolume delete '${vmSnapshotCurrent}'
            else
              echo "warning: expected snapshot path to be a btrfs subvolume: ${vmSnapshotCurrent}" >&2
            fi
          fi

          if [ -d '${vmSnapshotParent}' ] && \
             [ -z "$(${pkgs.findutils}/bin/find '${vmSnapshotParent}' -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            ${pkgs.coreutils}/bin/rmdir '${vmSnapshotParent}'
          fi
        '';
      };
    }
  ) backupMachines;

  backupManifestVms = lib.mapAttrs (
    name: machine:
    let
      backup = machine.backupResolved;
    in
    {
      repo = backup.repo;
      passFile = backup.passFile;
      sshKeyPath = backup.sshKeyPath;
    }
  ) backupMachines;

  backupCli = pkgs.writers.writePython3Bin "microvm-image-backup" {
    flakeIgnore = [ "E501" "E265" ];
    makeWrapperArgs =
      let
        runtimeInputs = with pkgs; [
          python3
          borgbackup
          btrfs-progs
          coreutils
          systemd
        ];
      in
      [
        "--prefix"
        "PATH"
        ":"
        "${lib.makeBinPath runtimeInputs}"
      ];
  } (builtins.readFile ./microvm_image_backup.py);

  backupManifest = {
    inherit volumePath;
    vms = backupManifestVms;
  };
in
{
  systemd.tmpfiles.rules = snapshotTmpfiles;

  services.borgbackup.jobs = borgJobs;

  environment.etc."microvm-backup/manifest.json".text = builtins.toJSON backupManifest;
  environment.systemPackages = [ backupCli ];
}
