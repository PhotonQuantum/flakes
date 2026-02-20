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
          backup.backupSnapshotCurrentPath
          backup.dataVolumeSubvolumePath
        ];
        paths = [ "${backup.backupSnapshotCurrentPath}/./." ];
        prune.keep = backup.pruneKeep;
        extraCreateArgs = [ "-p" ];
        preHook = ''
          set -eu

          is_btrfs_subvolume() {
            ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$1" >/dev/null 2>&1
          }

          ${pkgs.coreutils}/bin/mkdir -p '${backup.backupSnapshotParent}'

          if [ -e '${backup.backupSnapshotCurrentPath}' ]; then
            if is_btrfs_subvolume '${backup.backupSnapshotCurrentPath}'; then
              ${pkgs.btrfs-progs}/bin/btrfs subvolume delete '${backup.backupSnapshotCurrentPath}'
            else
              echo "Refusing to delete stale non-subvolume snapshot path: ${backup.backupSnapshotCurrentPath}" >&2
              exit 1
            fi
          fi

          ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r \
            '${backup.dataVolumeSubvolumePath}' \
            '${backup.backupSnapshotCurrentPath}'
        '';
        postHook = ''
          set +e

          if [ -e '${backup.backupSnapshotCurrentPath}' ]; then
            if ${pkgs.btrfs-progs}/bin/btrfs subvolume show '${backup.backupSnapshotCurrentPath}' >/dev/null 2>&1; then
              ${pkgs.btrfs-progs}/bin/btrfs subvolume delete '${backup.backupSnapshotCurrentPath}'
            else
              echo "warning: expected snapshot path to be a btrfs subvolume: ${backup.backupSnapshotCurrentPath}" >&2
            fi
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
      subvolumePath = backup.dataVolumeSubvolumePath;
      snapshotCurrentPath = backup.backupSnapshotCurrentPath;
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

      is_btrfs_subvolume() {
        ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$1" >/dev/null 2>&1
      }

      delete_subvolume_strict_if_exists() {
        local path="$1"
        local label="$2"
        if [ -e "$path" ]; then
          if is_btrfs_subvolume "$path"; then
            ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$path"
          else
            echo "Refusing to delete non-btrfs $label at $path" >&2
            return 1
          fi
        fi
      }

      cleanup_subvolume_best_effort() {
        local path="$1"
        local label="$2"
        if [ -e "$path" ]; then
          if is_btrfs_subvolume "$path"; then
            if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$path"; then
              echo "warning: failed to delete $label at $path" >&2
            fi
          else
            echo "warning: $label at $path exists but is not a btrfs subvolume" >&2
          fi
        fi
      }

      ${mkCaseFn "vm_repo" (name: backupMachines.${name}.backupResolved.repo)}
      ${mkCaseFn "vm_image" (name: backupMachines.${name}.backupResolved.imagePath)}
      ${mkCaseFn "vm_subvolume" (name: backupMachines.${name}.backupResolved.dataVolumeSubvolumePath)}
      ${mkCaseFn "vm_restore_stage" (name: backupMachines.${name}.backupResolved.restoreStageSubvolumePath)}
      ${mkCaseFn "vm_restore_old" (name: backupMachines.${name}.backupResolved.restoreOldSubvolumePath)}
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
          target_subvolume="$(vm_subvolume "$vm")"
          stage_subvolume="$(vm_restore_stage "$vm")"
          old_subvolume="$(vm_restore_old "$vm")"
          was_active=0
          swap_done=0
          restore_finished=0

          if ! is_btrfs_subvolume "$target_subvolume"; then
            echo "Target VM path is not a btrfs subvolume: $target_subvolume" >&2
            exit 1
          fi

          delete_subvolume_strict_if_exists "$stage_subvolume" "restore stage subvolume"
          delete_subvolume_strict_if_exists "$old_subvolume" "restore old subvolume"

          ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$stage_subvolume"

          restore_cleanup() {
            local exit_code=$?
            set +e

            if [ "$restore_finished" -ne 1 ]; then
              echo "Restore failed for VM '$vm'; attempting rollback." >&2
              if [ "$swap_done" -eq 1 ]; then
                if [ -e "$target_subvolume" ] && is_btrfs_subvolume "$target_subvolume"; then
                  ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$target_subvolume" || \
                    echo "warning: failed to delete partially restored target: $target_subvolume" >&2
                fi
                if [ -e "$old_subvolume" ]; then
                  if mv "$old_subvolume" "$target_subvolume"; then
                    echo "Rollback completed for VM '$vm'." >&2
                  else
                    echo "warning: rollback move failed ($old_subvolume -> $target_subvolume)" >&2
                  fi
                else
                  echo "warning: rollback source missing: $old_subvolume" >&2
                fi
              fi

              if [ "$was_active" -eq 1 ]; then
                systemctl start -v "$service" || \
                  echo "warning: failed to restart VM service after rollback: $service" >&2
              fi
            fi

            cleanup_subvolume_best_effort "$stage_subvolume" "restore stage subvolume"
            if [ "$restore_finished" -eq 1 ]; then
              cleanup_subvolume_best_effort "$old_subvolume" "previous VM subvolume"
            fi

            trap - EXIT
            exit "$exit_code"
          }
          trap restore_cleanup EXIT

          load_borg_context "$vm"
          (
            cd "$stage_subvolume"
            borg extract "::''${archive}"
          )

          if systemctl is-active --quiet "$service"; then
            was_active=1
            systemctl stop -v "$service"
          fi

          mv "$target_subvolume" "$old_subvolume"
          mv "$stage_subvolume" "$target_subvolume"
          swap_done=1

          if [ "$was_active" -eq 1 ]; then
            systemctl start -v "$service"
          fi

          restore_finished=1
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
