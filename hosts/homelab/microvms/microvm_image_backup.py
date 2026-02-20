#!/usr/bin/env python3

import argparse
import json
import logging
import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, Sequence


DEFAULT_MANIFEST_PATH = "/etc/microvm-backup/manifest.json"
LOGGER = logging.getLogger("microvm-image-backup")


class CliError(Exception):
    pass


@dataclass(frozen=True)
class VmBackupConfig:
    repo: str
    pass_file: Path
    ssh_key_path: Path


@dataclass(frozen=True)
class Manifest:
    volume_path: Path
    vms: dict[str, VmBackupConfig]


@dataclass(frozen=True)
class VmPaths:
    target: Path
    stage: Path
    old: Path


@dataclass(frozen=True)
class AppContext:
    manifest: Manifest
    runner: "CommandRunner"
    btrfs: "BtrfsManager"
    borg: "BorgManager"
    systemd: "SystemdManager"


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def ensure_root_for_privileged_command(command: str, *, dry_run: bool) -> None:
    if command not in {"backup", "list", "restore"}:
        return
    if dry_run:
        return
    if os.geteuid() == 0:
        return

    sudo_path = shutil.which("sudo")
    if sudo_path is None:
        raise CliError("sudo is required for this command but was not found in PATH")
    os.execvp(sudo_path, [sudo_path, "-E", "--", sys.argv[0], *sys.argv[1:]])


def _read_string_field(raw: object, *, field_path: str) -> str:
    if not isinstance(raw, str) or raw == "":
        raise CliError(f"{field_path} must be a non-empty string")
    return raw


def _read_absolute_path_field(raw: object, *, field_path: str) -> Path:
    value = _read_string_field(raw, field_path=field_path)
    path = Path(value)
    if not path.is_absolute():
        raise CliError(f"{field_path} must be an absolute path")
    return path


def load_manifest(manifest_override: str | None) -> Manifest:
    manifest_path = manifest_override or os.environ.get(
        "MICROVM_BACKUP_MANIFEST", DEFAULT_MANIFEST_PATH
    )
    path = Path(manifest_path)
    if not path.exists():
        raise CliError(f"manifest file does not exist: {path}")

    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise CliError(f"manifest file is not valid JSON: {path}: {exc}") from exc

    if not isinstance(raw, dict):
        raise CliError("manifest root must be a JSON object")

    volume_path = _read_absolute_path_field(
        raw.get("volumePath"), field_path="manifest.volumePath"
    )

    raw_vms = raw.get("vms")
    if not isinstance(raw_vms, dict):
        raise CliError("manifest.vms must be an object keyed by vm name")

    vms: dict[str, VmBackupConfig] = {}
    for vm_name, raw_vm in raw_vms.items():
        if not isinstance(vm_name, str) or vm_name == "":
            raise CliError("manifest.vms keys must be non-empty strings")
        if not isinstance(raw_vm, dict):
            raise CliError(f"manifest.vms.{vm_name} must be an object")

        repo = _read_string_field(
            raw_vm.get("repo"), field_path=f"manifest.vms.{vm_name}.repo"
        )
        pass_file = _read_absolute_path_field(
            raw_vm.get("passFile"), field_path=f"manifest.vms.{vm_name}.passFile"
        )
        ssh_key_path = _read_absolute_path_field(
            raw_vm.get("sshKeyPath"),
            field_path=f"manifest.vms.{vm_name}.sshKeyPath",
        )
        vms[vm_name] = VmBackupConfig(
            repo=repo, pass_file=pass_file, ssh_key_path=ssh_key_path
        )

    return Manifest(volume_path=volume_path, vms=vms)


def vm_paths(volume_path: Path, vm: str) -> VmPaths:
    return VmPaths(
        target=volume_path / vm,
        stage=volume_path / f".{vm}.restore-new",
        old=volume_path / f".{vm}.restore-old",
    )


def require_vm(manifest: Manifest, vm: str) -> VmBackupConfig:
    vm_data = manifest.vms.get(vm)
    if vm_data is None:
        raise CliError(f"Unknown VM: {vm}")
    return vm_data


class CommandRunner:
    def __init__(self, *, dry_run: bool) -> None:
        self.dry_run = dry_run

    @staticmethod
    def _coerce_cmd(cmd: Sequence[object]) -> list[str]:
        return [str(part) for part in cmd]

    def run(
        self,
        cmd: Sequence[object],
        *,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        capture_output: bool = False,
        mutating: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        cmd_list = self._coerce_cmd(cmd)
        cmd_display = shlex.join(cmd_list)

        if self.dry_run and mutating:
            LOGGER.info("[dry-run] %s", cmd_display)
            stdout = "" if capture_output else None
            stderr = "" if capture_output else None
            return subprocess.CompletedProcess(
                cmd_list, 0, stdout=stdout, stderr=stderr
            )

        LOGGER.debug("run: %s", cmd_display)
        return subprocess.run(
            cmd_list,
            cwd=str(cwd) if cwd is not None else None,
            env=dict(env) if env is not None else None,
            text=True,
            capture_output=capture_output,
            check=False,
        )

    def check(
        self,
        cmd: Sequence[object],
        *,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        capture_output: bool = False,
        mutating: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        result = self.run(
            cmd,
            cwd=cwd,
            env=env,
            capture_output=capture_output,
            mutating=mutating,
        )
        if result.returncode != 0:
            cmd_display = shlex.join(self._coerce_cmd(cmd))
            detail = ""
            if capture_output and result.stderr:
                detail = f": {result.stderr.strip()}"
            raise CliError(
                f"command failed (exit {result.returncode}): {cmd_display}{detail}"
            )
        return result


class BtrfsManager:
    def __init__(self, runner: CommandRunner) -> None:
        self.runner = runner

    @staticmethod
    def is_subvolume(path: Path) -> bool:
        result = subprocess.run(
            ["btrfs", "subvolume", "show", str(path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return result.returncode == 0

    def delete_subvolume_strict_if_exists(self, path: Path, label: str) -> None:
        if not path.exists():
            return
        if not self.is_subvolume(path):
            raise CliError(f"Refusing to delete non-btrfs {label} at {path}")
        self.runner.check(["btrfs", "subvolume", "delete", str(path)], mutating=True)

    def cleanup_subvolume_best_effort(self, path: Path, label: str) -> None:
        if not path.exists():
            return
        if not self.is_subvolume(path):
            LOGGER.warning("%s at %s exists but is not a btrfs subvolume", label, path)
            return
        result = self.runner.run(
            ["btrfs", "subvolume", "delete", str(path)], mutating=True
        )
        if result.returncode != 0:
            LOGGER.warning("failed to delete %s at %s", label, path)

    def create_subvolume(self, path: Path) -> None:
        self.runner.check(["btrfs", "subvolume", "create", str(path)], mutating=True)


class SystemdManager:
    def __init__(self, runner: CommandRunner) -> None:
        self.runner = runner

    @staticmethod
    def vm_service_unit(vm: str) -> str:
        return f"microvm@{vm}.service"

    @staticmethod
    def vm_backup_unit(vm: str) -> str:
        return f"borgbackup-job-microvm-{vm}.service"

    def restart_backup_job(self, vm: str) -> None:
        self.runner.check(
            ["systemctl", "restart", "-v", "--wait", self.vm_backup_unit(vm)],
            mutating=True,
        )

    def is_active(self, service: str) -> bool:
        result = self.runner.run(
            ["systemctl", "is-active", "--quiet", service], capture_output=True
        )
        return result.returncode == 0

    def stop(self, service: str) -> None:
        self.runner.check(["systemctl", "stop", "-v", service], mutating=True)

    def start(self, service: str) -> None:
        self.runner.check(["systemctl", "start", "-v", service], mutating=True)

    def start_best_effort(self, service: str) -> None:
        result = self.runner.run(["systemctl", "start", "-v", service], mutating=True)
        if result.returncode != 0:
            LOGGER.warning("failed to restart VM service after rollback: %s", service)


class BorgManager:
    def __init__(self, runner: CommandRunner) -> None:
        self.runner = runner

    @staticmethod
    def environment(vm_data: VmBackupConfig) -> dict[str, str]:
        env = os.environ.copy()
        env["BORG_REPO"] = vm_data.repo
        env["BORG_RSH"] = f"ssh -i {vm_data.ssh_key_path}"
        env["BORG_PASSCOMMAND"] = f"cat {vm_data.pass_file}"
        return env

    def list_archives(self, vm_data: VmBackupConfig) -> None:
        self.runner.check(["borg", "list", "--short"], env=self.environment(vm_data))

    def extract_archive(
        self, vm_data: VmBackupConfig, archive: str, *, cwd: Path
    ) -> None:
        self.runner.check(
            ["borg", "extract", "-p", f"::{archive}"],
            cwd=cwd,
            env=self.environment(vm_data),
            mutating=True,
        )


class RestoreTransaction:
    def __init__(
        self, ctx: AppContext, vm: str, archive: str, vm_data: VmBackupConfig
    ) -> None:
        self.ctx = ctx
        self.vm = vm
        self.archive = archive
        self.vm_data = vm_data
        self.paths = vm_paths(ctx.manifest.volume_path, vm)
        self.service = self.ctx.systemd.vm_service_unit(vm)
        self.was_active = False
        self.target_moved_to_old = False
        self.restore_finished = False

    def __enter__(self) -> "RestoreTransaction":
        if not self.ctx.btrfs.is_subvolume(self.paths.target):
            raise CliError(
                f"Target VM path is not a btrfs subvolume: {self.paths.target}"
            )

        self.ctx.btrfs.delete_subvolume_strict_if_exists(
            self.paths.stage, "restore stage subvolume"
        )
        self.ctx.btrfs.delete_subvolume_strict_if_exists(
            self.paths.old, "restore old subvolume"
        )
        self.ctx.btrfs.create_subvolume(self.paths.stage)
        return self

    def run(self) -> None:
        self.ctx.borg.extract_archive(self.vm_data, self.archive, cwd=self.paths.stage)
        if self.ctx.systemd.is_active(self.service):
            self.was_active = True
            self.ctx.systemd.stop(self.service)

        if self.ctx.runner.dry_run:
            LOGGER.info("[dry-run] mv %s -> %s", self.paths.target, self.paths.old)
            LOGGER.info("[dry-run] mv %s -> %s", self.paths.stage, self.paths.target)
        else:
            try:
                self.paths.target.rename(self.paths.old)
                self.target_moved_to_old = True
                self.paths.stage.rename(self.paths.target)
            except OSError as exc:
                raise CliError(
                    f"failed to move subvolumes during restore: {exc}"
                ) from exc

        if self.was_active:
            self.ctx.systemd.start(self.service)

        self.restore_finished = True

    def __exit__(self, exc_type, exc, tb) -> bool:
        if exc_type is not None:
            LOGGER.error("Restore failed for VM '%s'; attempting rollback.", self.vm)
            self._rollback_best_effort()

        self.ctx.btrfs.cleanup_subvolume_best_effort(
            self.paths.stage, "restore stage subvolume"
        )
        if self.restore_finished:
            self.ctx.btrfs.cleanup_subvolume_best_effort(
                self.paths.old, "previous VM subvolume"
            )
        return False

    def _rollback_best_effort(self) -> None:
        if self.target_moved_to_old:
            if self.paths.target.exists() and self.ctx.btrfs.is_subvolume(
                self.paths.target
            ):
                result = self.ctx.runner.run(
                    ["btrfs", "subvolume", "delete", str(self.paths.target)],
                    mutating=True,
                )
                if result.returncode != 0:
                    LOGGER.warning(
                        "failed to delete partially restored target: %s",
                        self.paths.target,
                    )

            if self.paths.old.exists():
                if self.ctx.runner.dry_run:
                    LOGGER.info(
                        "[dry-run] mv %s -> %s", self.paths.old, self.paths.target
                    )
                else:
                    try:
                        self.paths.old.rename(self.paths.target)
                        LOGGER.info("Rollback completed for VM '%s'.", self.vm)
                    except OSError:
                        LOGGER.warning(
                            "rollback move failed (%s -> %s)",
                            self.paths.old,
                            self.paths.target,
                        )
            else:
                LOGGER.warning("rollback source missing: %s", self.paths.old)

        if self.was_active:
            self.ctx.systemd.start_best_effort(self.service)


def handle_backup(ctx: AppContext, args: argparse.Namespace) -> None:
    require_vm(ctx.manifest, args.vm)
    ctx.systemd.restart_backup_job(args.vm)


def handle_list(ctx: AppContext, args: argparse.Namespace) -> None:
    if args.vm is not None:
        vm_data = require_vm(ctx.manifest, args.vm)
        print(f"VM: {args.vm}")
        print(f"Subvolume: {vm_paths(ctx.manifest.volume_path, args.vm).target}")
        ctx.borg.list_archives(vm_data)
        return

    vm_names = sorted(ctx.manifest.vms.keys())
    if not vm_names:
        print("No backup-enabled VMs configured.")
        return

    for vm_name in vm_names:
        vm_data = ctx.manifest.vms[vm_name]
        print(f"VM: {vm_name}")
        print(f"Subvolume: {vm_paths(ctx.manifest.volume_path, vm_name).target}")
        ctx.borg.list_archives(vm_data)
        print("")


def handle_restore(ctx: AppContext, args: argparse.Namespace) -> None:
    vm_data = require_vm(ctx.manifest, args.vm)
    with RestoreTransaction(ctx, args.vm, args.archive, vm_data) as tx:
        tx.run()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="microvm-image-backup")
    parser.add_argument(
        "--manifest",
        help=f"Path to manifest JSON (default: $MICROVM_BACKUP_MANIFEST or {DEFAULT_MANIFEST_PATH})",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print mutating actions without executing them",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    backup_parser = subparsers.add_parser("backup")
    backup_parser.add_argument("vm")
    backup_parser.set_defaults(handler=handle_backup)

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("vm", nargs="?")
    list_parser.set_defaults(handler=handle_list)

    restore_parser = subparsers.add_parser("restore")
    restore_parser.add_argument("vm")
    restore_parser.add_argument("archive")
    restore_parser.set_defaults(handler=handle_restore)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    configure_logging(args.verbose)

    try:
        ensure_root_for_privileged_command(args.command, dry_run=args.dry_run)
        manifest = load_manifest(args.manifest)
        runner = CommandRunner(dry_run=args.dry_run)
        ctx = AppContext(
            manifest=manifest,
            runner=runner,
            btrfs=BtrfsManager(runner),
            borg=BorgManager(runner),
            systemd=SystemdManager(runner),
        )

        handler = getattr(args, "handler", None)
        if handler is None:
            parser.error("unknown command")
        typed_handler: Callable[[AppContext, argparse.Namespace], None] = handler
        typed_handler(ctx, args)
    except CliError as exc:
        LOGGER.error("%s", exc)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
