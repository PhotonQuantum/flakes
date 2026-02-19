{ lib, pkgs, ... }:
let
  vmLib = import ./lib.nix { inherit lib; };
  registry = import ./registry.nix;
  backupDefaults = vmLib.resolveBackupDefaults (registry.backupDefaults or { });
  inherit (registry) bridgeGroups machines;

  resolvedGroups = vmLib.resolveGroups bridgeGroups;
  resolvedMachines = vmLib.resolveMachines {
    inherit backupDefaults machines;
    bridgeGroups = resolvedGroups;
  };

  backupMachines = lib.filterAttrs (_: machine: machine.backupResolved != null) resolvedMachines;
  backupVmNames = builtins.attrNames backupMachines;
  hasBackupMachines = backupVmNames != [ ];

  snapshotTmpfiles =
    if hasBackupMachines then
      [ "d ${backupDefaults.snapshotRoot} 0750 root root - -" ]
    else
      [ ];

  borgJobs = lib.mapAttrs' (
    name: machine:
    let
      backup = machine.backupResolved;
      dumpCommandScript = pkgs.writeShellScript "microvm-borg-dump-${name}" ''
        exec ${pkgs.coreutils}/bin/cat "$MICROVM_SNAPSHOT_IMAGE"
      '';
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
        readWritePaths = [
          backup.snapshotRoot
          backup.backupSnapshotParent
          backup.dataVolumeSubvolumePath
        ];
        dumpCommand = dumpCommandScript;
        extraCreateArgs = [
          "--stdin-name"
          backup.imagePathInArchive
        ];
        prune.keep = backup.pruneKeep;
        extraCreateArgs = [ "-p" ];
        preHook = ''
          set -eu

          ${pkgs.coreutils}/bin/mkdir -p '${backup.backupSnapshotParent}'
          snapshot_id="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
          export MICROVM_SNAPSHOT_PATH='${backup.backupSnapshotParent}'/"$snapshot_id"
          export MICROVM_SNAPSHOT_IMAGE="$MICROVM_SNAPSHOT_PATH/${backup.dataVolumeImageBasename}"

          ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r \
            '${backup.dataVolumeSubvolumePath}' \
            "$MICROVM_SNAPSHOT_PATH"
        '';
        postHook = ''
          set +e

          if [ -n "''${MICROVM_SNAPSHOT_PATH:-}" ] && [ -d "$MICROVM_SNAPSHOT_PATH" ]; then
            ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$MICROVM_SNAPSHOT_PATH"
          fi

          if [ -d '${backup.backupSnapshotParent}' ] && \
             [ -z "$(${pkgs.findutils}/bin/find '${backup.backupSnapshotParent}' -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            ${pkgs.coreutils}/bin/rmdir '${backup.backupSnapshotParent}'
          fi
        '';
      };
    }
  ) backupMachines;

  backupManifest = lib.mapAttrs (
    name: machine:
    let
      backup = machine.backupResolved;
    in
    {
      repo = backup.repo;
      imagePath = backup.imagePath;
      imagePathInArchive = backup.imagePathInArchive;
      backupUnit = "borgbackup-job-microvm-${name}.service";
      vmServiceUnit = "microvm@${name}.service";
      passFile = backup.passFile;
      sshKeyPath = backup.sshKeyPath;
    }
  ) backupMachines;

  mkCaseFn =
    fnName: valueFn:
    ''
      ${fnName}() {
        case "$1" in
      ${lib.concatMapStringsSep "\n" (
        name:
        "    ${name}) echo ${lib.escapeShellArg (valueFn name)} ;;"
      ) backupVmNames}
          *)
            echo "unknown VM: $1" >&2
            return 1
            ;;
        esac
      }
    '';

  backupCli = pkgs.writeShellApplication {
    name = "microvm-image-backup";
    runtimeInputs = with pkgs; [
      borgbackup
      coreutils
      systemd
    ];
    text = ''
      set -euo pipefail

      known_vms=(${lib.concatMapStringsSep " " lib.escapeShellArg backupVmNames})

      if [ "''${#known_vms[@]}" -eq 0 ]; then
        echo "No backup-enabled VMs configured."
        exit 0
      fi

      usage() {
        cat <<'USAGE'
      Usage:
        microvm-image-backup backup <vm>
        microvm-image-backup list [vm]
        microvm-image-backup restore <vm> <archive>
      USAGE
      }

      vm_exists() {
        local target="$1"
        local vm
        for vm in "''${known_vms[@]}"; do
          if [ "$vm" = "$target" ]; then
            return 0
          fi
        done
        return 1
      }

      ${mkCaseFn "vm_repo" (name: backupMachines.${name}.backupResolved.repo)}
      ${mkCaseFn "vm_image" (name: backupMachines.${name}.backupResolved.imagePath)}
      ${mkCaseFn "vm_archive_image" (name: backupMachines.${name}.backupResolved.imagePathInArchive)}
      ${mkCaseFn "vm_pass_file" (name: backupMachines.${name}.backupResolved.passFile)}
      ${mkCaseFn "vm_ssh_key" (name: backupMachines.${name}.backupResolved.sshKeyPath)}
      ${mkCaseFn "vm_backup_unit" (name: "borgbackup-job-microvm-${name}.service")}
      ${mkCaseFn "vm_service_unit" (name: "microvm@${name}.service")}

      load_borg_context() {
        local vm="$1"
        local borg_pass_command
        local borg_repo
        local borg_rsh
        borg_pass_command="cat $(vm_pass_file "$vm")"
        export BORG_PASSCOMMAND="$borg_pass_command"
        borg_rsh="ssh -i $(vm_ssh_key "$vm")"
        export BORG_RSH="$borg_rsh"
        borg_repo="$(vm_repo "$vm")"
        export BORG_REPO="$borg_repo"
      }

      cmd=''${1:-}
      case "$cmd" in
        backup)
          vm=''${2:-}
          if [ -z "$vm" ]; then
            usage
            exit 1
          fi
          if ! vm_exists "$vm"; then
            echo "Unknown VM: $vm" >&2
            exit 1
          fi
          systemctl restart -v --wait "$(vm_backup_unit "$vm")"
          ;;

        list)
          vm=''${2:-}
          if [ -n "$vm" ]; then
            if ! vm_exists "$vm"; then
              echo "Unknown VM: $vm" >&2
              exit 1
            fi
            load_borg_context "$vm"
            echo "VM: $vm"
            echo "Image: $(vm_image "$vm")"
            borg list --short
          else
            for vm_name in "''${known_vms[@]}"; do
              load_borg_context "$vm_name"
              echo "VM: $vm_name"
              echo "Image: $(vm_image "$vm_name")"
              borg list --short
              echo
            done
          fi
          ;;

        restore)
          vm=''${2:-}
          archive=''${3:-}
          if [ -z "$vm" ] || [ -z "$archive" ]; then
            usage
            exit 1
          fi
          if ! vm_exists "$vm"; then
            echo "Unknown VM: $vm" >&2
            exit 1
          fi

          service="$(vm_service_unit "$vm")"
          image="$(vm_image "$vm")"
          archive_image="$(vm_archive_image "$vm")"
          tmp_image="$image.tmp.$$"
          restored_owner_group="microvm:kvm"
          restored_mode="0660"
          was_active=0

          if systemctl is-active --quiet "$service"; then
            was_active=1
            systemctl stop -v "$service"
          fi

          trap 'rm -f "$tmp_image"' EXIT

          if [ -e "$image" ]; then
            restored_owner_group="$(${pkgs.coreutils}/bin/stat -c '%u:%g' "$image")"
            restored_mode="$(${pkgs.coreutils}/bin/stat -c '%a' "$image")"
          fi

          load_borg_context "$vm"
          borg extract --stdout "::''${archive}" "$archive_image" > "$tmp_image"
          ${pkgs.coreutils}/bin/chown "$restored_owner_group" "$tmp_image"
          ${pkgs.coreutils}/bin/chmod "$restored_mode" "$tmp_image"
          mv "$tmp_image" "$image"

          if [ "$was_active" -eq 1 ]; then
            systemctl start -v "$service"
          fi
          ;;

        *)
          usage
          exit 1
          ;;
      esac
    '';
  };
in
{
  systemd.tmpfiles.rules = snapshotTmpfiles;

  services.borgbackup.jobs = borgJobs;

  environment.etc."microvm-backup/manifest.json".text = builtins.toJSON backupManifest;
  environment.systemPackages = [ backupCli ];
}
