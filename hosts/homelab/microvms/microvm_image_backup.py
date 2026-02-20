#!/usr/bin/env python3

import argparse
import concurrent.futures
import json
import logging
import os
import random
import shlex
import shutil
import socket
import subprocess
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, Sequence


DEFAULT_MANIFEST_PATH = "/etc/microvm-backup/manifest.json"
PREVIEW_SOCKET_ENV = "MICROVM_BACKUP_PREVIEW_SOCKET"
PREVIEW_WAIT_MS = 10_000
PREVIEW_CLEAR_SCREEN = "\x1b[2J\x1b[H"
FETCH_WORKERS = 2
LOCK_RETRY_BASE_DELAY = 0.08
LOCK_RETRY_MAX_DELAY = 0.30
LOGGER = logging.getLogger("microvm-image-backup")


class CliError(Exception):
    pass


class PickerCancelled(Exception):
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
class ArchiveInfo:
    archive: str
    start: str
    end: str
    duration: str
    hostname: str
    username: str
    source_path: str
    command_line: str
    file_count: str
    original_size: str
    compressed_size: str
    deduplicated_size: str


@dataclass(frozen=True)
class ArchiveSelection:
    archive: str
    info: ArchiveInfo | None


@dataclass(frozen=True)
class PreviewRecord:
    status: str
    text: str
    info: ArchiveInfo | None


@dataclass(frozen=True)
class AppContext:
    manifest: Manifest
    runner: "CommandRunner"
    btrfs: "BtrfsManager"
    borg: "BorgService"
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


def _string_or_na(raw: object) -> str:
    if isinstance(raw, str) and raw != "":
        return raw
    if raw is None:
        return "N/A"
    return str(raw)


def _int_or_none(raw: object) -> int | None:
    if isinstance(raw, bool):
        return None
    if isinstance(raw, int):
        return raw
    if isinstance(raw, float):
        return int(raw)
    if isinstance(raw, str) and raw.isdigit():
        return int(raw)
    return None


def _format_bytes(raw: object) -> str:
    value = _int_or_none(raw)
    if value is None:
        return _string_or_na(raw)

    units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    size = float(value)
    idx = 0
    while size >= 1024.0 and idx < len(units) - 1:
        size /= 1024.0
        idx += 1

    if idx == 0:
        return f"{int(size)} {units[idx]}"
    return f"{size:.2f} {units[idx]}"


def _format_seconds(raw: object) -> str:
    if isinstance(raw, str) and raw != "":
        return raw

    total = _int_or_none(raw)
    if total is None:
        return _string_or_na(raw)

    if total < 60:
        return f"{total}s"
    minutes, seconds = divmod(total, 60)
    if minutes < 60:
        return f"{minutes}m {seconds}s"
    hours, minutes = divmod(minutes, 60)
    return f"{hours}h {minutes}m {seconds}s"


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
            if capture_output:
                stderr = (result.stderr or "").strip()
                if stderr:
                    detail = f": {stderr}"
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


class BorgService:
    def __init__(self, runner: CommandRunner) -> None:
        self.runner = runner

    @staticmethod
    def environment(vm_data: VmBackupConfig) -> dict[str, str]:
        env = os.environ.copy()
        env["BORG_REPO"] = vm_data.repo
        env["BORG_RSH"] = f"ssh -i {vm_data.ssh_key_path}"
        env["BORG_PASSCOMMAND"] = f"cat {vm_data.pass_file}"
        return env

    @staticmethod
    def is_lock_failure(exc: Exception) -> bool:
        message = str(exc).lower()
        lock_markers = (
            "lock",
            "already locked",
            "another borg process",
            "failed to create/acquire the lock",
            "failed to acquire",
            "lock timeout",
        )
        return any(marker in message for marker in lock_markers)

    def list_archives(self, vm_data: VmBackupConfig) -> None:
        self.runner.check(["borg", "list", "--short"], env=self.environment(vm_data))

    def list_archive_names(self, vm_data: VmBackupConfig) -> list[str]:
        result = self.runner.check(
            ["borg", "list", "--short"],
            env=self.environment(vm_data),
            capture_output=True,
        )
        names = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        return sorted(names, reverse=True)

    def fetch_archive_info(self, vm_data: VmBackupConfig, archive: str) -> ArchiveInfo:
        result = self.runner.check(
            ["borg", "info", "--json", f"::{archive}"],
            env=self.environment(vm_data),
            capture_output=True,
        )
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            raise CliError(
                f"failed to parse borg info JSON for '{archive}': {exc}"
            ) from exc

        entry = self._extract_archive_entry(payload)
        stats = entry.get("stats") if isinstance(entry.get("stats"), dict) else {}

        command_line_raw = entry.get("command_line")
        if isinstance(command_line_raw, list):
            command_line = " ".join(str(part) for part in command_line_raw)
        else:
            command_line = _string_or_na(command_line_raw)

        return ArchiveInfo(
            archive=_string_or_na(entry.get("name") or archive),
            start=_string_or_na(entry.get("start")),
            end=_string_or_na(entry.get("end")),
            duration=_format_seconds(entry.get("duration")),
            hostname=_string_or_na(entry.get("hostname")),
            username=_string_or_na(entry.get("username")),
            source_path=self._extract_source_path(entry, command_line),
            command_line=command_line,
            file_count=_string_or_na(stats.get("nfiles")),
            original_size=_format_bytes(stats.get("original_size")),
            compressed_size=_format_bytes(stats.get("compressed_size")),
            deduplicated_size=_format_bytes(stats.get("deduplicated_size")),
        )

    def format_archive_details(self, info: ArchiveInfo) -> str:
        lines = [
            f"Start: {info.start}",
            f"Duration: {info.duration}",
            f"Files: {info.file_count}",
            f"Original size: {info.original_size}",
            f"Compressed size: {info.compressed_size}",
            f"Deduplicated size: {info.deduplicated_size}",
        ]
        return "\n".join(lines)

    def format_archive_summary(
        self, *, vm: str, target: Path, info: ArchiveInfo
    ) -> str:
        lines = [
            f"VM: {vm}",
            f"Archive: {info.archive}",
            f"Restore target: {target}",
            "",
            self.format_archive_details(info),
        ]
        return "\n".join(lines)

    @staticmethod
    def _extract_archive_entry(payload: object) -> dict[str, object]:
        if isinstance(payload, dict):
            archives = payload.get("archives")
            if isinstance(archives, list) and archives:
                first = archives[0]
                if isinstance(first, dict):
                    return first
            archive = payload.get("archive")
            if isinstance(archive, dict):
                return archive
        return {}

    @staticmethod
    def _extract_source_path(entry: Mapping[str, object], command_line: str) -> str:
        for key in ("source_paths", "paths"):
            raw_paths = entry.get(key)
            if isinstance(raw_paths, list):
                values = [str(item) for item in raw_paths if isinstance(item, str)]
                if values:
                    return ", ".join(values)

        if command_line not in {"", "N/A"}:
            try:
                argv = shlex.split(command_line)
            except ValueError:
                argv = command_line.split()
            path_candidates = [
                token
                for token in argv
                if token.startswith("/") and not token.startswith("//")
            ]
            if path_candidates:
                return ", ".join(path_candidates)
        return "N/A"

    def extract_archive(
        self, vm_data: VmBackupConfig, archive: str, *, cwd: Path
    ) -> None:
        self.runner.check(
            ["borg", "extract", "-p", f"::{archive}"],
            cwd=cwd,
            env=self.environment(vm_data),
            mutating=True,
        )


class InlinePreviewServer:
    def __init__(self, *, vm_data: VmBackupConfig, borg: BorgService) -> None:
        self.vm_data = vm_data
        self.borg = borg
        self._records: dict[str, PreviewRecord] = {}
        self._inflight: dict[str, concurrent.futures.Future[PreviewRecord]] = {}
        self._demand_deadlines: dict[str, float] = {}
        self._demand_queue: deque[str] = deque()
        self._prefetch_queue: deque[str] = deque()
        self._queued_demand: set[str] = set()
        self._queued_prefetch: set[str] = set()
        self._active_demand = 0
        self._lock = threading.Lock()
        self._condition = threading.Condition(self._lock)
        self._stop = threading.Event()
        self._server_socket: socket.socket | None = None
        self._server_thread: threading.Thread | None = None
        self._workers: list[threading.Thread] = []
        self._client_pool = concurrent.futures.ThreadPoolExecutor(max_workers=16)
        token = random.randint(10_000, 999_999)
        self.socket_name = f"@microvm-image-backup-{os.getpid()}-{token}"

    def __enter__(self) -> "InlinePreviewServer":
        self.start()
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        self.stop()
        return False

    def start(self) -> None:
        bind_name = "\0" + self.socket_name[1:]
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(bind_name)
        sock.listen(32)
        sock.settimeout(0.2)
        self._server_socket = sock

        self._server_thread = threading.Thread(target=self._serve, daemon=True)
        self._server_thread.start()
        for _ in range(FETCH_WORKERS):
            worker = threading.Thread(target=self._worker_loop, daemon=True)
            worker.start()
            self._workers.append(worker)

    def stop(self) -> None:
        self._stop.set()
        if self._server_socket is not None:
            try:
                self._server_socket.close()
            except OSError:
                pass
        with self._condition:
            self._condition.notify_all()
        if self._server_thread is not None:
            self._server_thread.join(timeout=1.0)
        for worker in self._workers:
            worker.join(timeout=1.0)
        self._client_pool.shutdown(wait=False, cancel_futures=True)

    def prefetch_archives(self, archives: Sequence[str]) -> None:
        for archive in archives:
            name = archive.strip()
            if name == "":
                continue
            self._enqueue_prefetch(name)

    def resolve_archive_info(
        self, archive: str, *, timeout_ms: int
    ) -> ArchiveInfo | None:
        response = self.get_preview(archive=archive, wait_ms=timeout_ms)
        if response.status == "ready":
            return response.info
        return None

    def get_preview(self, *, archive: str, wait_ms: int) -> PreviewRecord:
        cached = self._get_cached(archive)
        if cached is not None:
            return cached

        future = self._enqueue_demand(archive, wait_ms=wait_ms)
        if wait_ms <= 0:
            return PreviewRecord(
                status="loading",
                text=f"Loading archive info for '{archive}'...",
                info=None,
            )

        try:
            return future.result(timeout=wait_ms / 1000.0)
        except concurrent.futures.TimeoutError:
            return PreviewRecord(
                status="timeout",
                text=f"Timed out after {wait_ms / 1000:.1f}s while loading '{archive}'.",
                info=None,
            )

    def _serve(self) -> None:
        assert self._server_socket is not None
        while not self._stop.is_set():
            try:
                conn, _ = self._server_socket.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            self._client_pool.submit(self._handle_connection, conn)

    def _handle_connection(self, conn: socket.socket) -> None:
        with conn:
            try:
                request = self._read_request(conn)
                response = self._dispatch(request)
            except Exception as exc:
                response = {
                    "status": "error",
                    "text": f"preview server error: {exc}",
                }
            payload = json.dumps(response).encode("utf-8") + b"\n"
            try:
                conn.sendall(payload)
            except OSError:
                return

    @staticmethod
    def _read_request(conn: socket.socket) -> dict[str, object]:
        chunks: list[bytes] = []
        while True:
            part = conn.recv(4096)
            if not part:
                break
            chunks.append(part)
            if b"\n" in part:
                break
        if not chunks:
            return {}
        line = b"".join(chunks).split(b"\n", 1)[0]
        if line == b"":
            return {}
        raw = json.loads(line.decode("utf-8"))
        if isinstance(raw, dict):
            return raw
        return {}

    def _dispatch(self, request: Mapping[str, object]) -> dict[str, object]:
        op = request.get("op")
        if op == "prefetch":
            archive = _string_or_na(request.get("archive")).strip()
            if archive != "":
                self._enqueue_prefetch(archive)
            return {"status": "ok"}

        if op == "get_preview":
            archive = _string_or_na(request.get("archive")).strip()
            wait_ms = _int_or_none(request.get("wait_ms"))
            if archive == "":
                return {"status": "error", "text": "missing archive"}
            preview = self.get_preview(archive=archive, wait_ms=wait_ms or 0)
            return {"status": preview.status, "text": preview.text}

        return {"status": "error", "text": f"unknown operation: {op}"}

    def _get_cached(self, archive: str) -> PreviewRecord | None:
        with self._lock:
            return self._records.get(archive)

    @staticmethod
    def _done_future(record: PreviewRecord) -> concurrent.futures.Future[PreviewRecord]:
        done: concurrent.futures.Future[PreviewRecord] = concurrent.futures.Future()
        done.set_result(record)
        return done

    def _enqueue_demand(
        self, archive: str, *, wait_ms: int
    ) -> concurrent.futures.Future[PreviewRecord]:
        deadline = time.monotonic() + max(wait_ms, 0) / 1000.0
        with self._condition:
            cached = self._records.get(archive)
            if cached is not None:
                return self._done_future(cached)

            inflight = self._inflight.get(archive)
            if inflight is not None:
                self._demand_deadlines[archive] = max(
                    deadline, self._demand_deadlines.get(archive, deadline)
                )
                if archive in self._queued_prefetch:
                    self._queued_prefetch.discard(archive)
                    try:
                        self._prefetch_queue.remove(archive)
                    except ValueError:
                        pass
                    if archive not in self._queued_demand:
                        self._demand_queue.append(archive)
                        self._queued_demand.add(archive)
                        self._condition.notify()
                return inflight

            future: concurrent.futures.Future[PreviewRecord] = (
                concurrent.futures.Future()
            )
            self._inflight[archive] = future
            self._demand_deadlines[archive] = deadline
            self._demand_queue.append(archive)
            self._queued_demand.add(archive)
            self._condition.notify()
            return future

    def _enqueue_prefetch(self, archive: str) -> None:
        with self._condition:
            if self._has_pending_demand_locked():
                return
            if archive in self._records:
                return
            if archive in self._inflight:
                return
            if archive in self._queued_prefetch:
                return

            future: concurrent.futures.Future[PreviewRecord] = (
                concurrent.futures.Future()
            )
            self._inflight[archive] = future
            self._prefetch_queue.append(archive)
            self._queued_prefetch.add(archive)
            self._condition.notify()

    def _has_pending_demand_locked(self) -> bool:
        return self._active_demand > 0 or bool(self._demand_queue)

    def _worker_loop(self) -> None:
        while True:
            with self._condition:
                while (
                    not self._stop.is_set()
                    and not self._demand_queue
                    and not self._prefetch_queue
                ):
                    self._condition.wait()

                if self._stop.is_set():
                    return

                if self._demand_queue:
                    archive = self._demand_queue.popleft()
                    self._queued_demand.discard(archive)
                    self._active_demand += 1
                    mode = "demand"
                    deadline = self._demand_deadlines.get(archive, time.monotonic())
                else:
                    archive = self._prefetch_queue.popleft()
                    self._queued_prefetch.discard(archive)
                    mode = "prefetch"
                    deadline = 0.0

            if mode == "demand":
                record = self._fetch_demand_with_retry(archive, deadline=deadline)
            else:
                record = self._fetch_prefetch_once(archive)

            with self._condition:
                if mode == "demand":
                    self._active_demand = max(0, self._active_demand - 1)

                future = self._inflight.pop(archive, None)
                self._demand_deadlines.pop(archive, None)
                if record.status == "ready":
                    self._records[archive] = record
                self._condition.notify_all()

            if future is not None and not future.done():
                future.set_result(record)

    def _fetch_once(self, archive: str) -> tuple[PreviewRecord, bool]:
        try:
            info = self.borg.fetch_archive_info(self.vm_data, archive)
            return (
                PreviewRecord(
                    status="ready",
                    text=self.borg.format_archive_details(info),
                    info=info,
                ),
                False,
            )
        except CliError as exc:
            classifier = getattr(
                self.borg, "is_lock_failure", BorgService.is_lock_failure
            )
            lock_failure = bool(classifier(exc))
            return (
                PreviewRecord(
                    status="error",
                    text=f"Failed to load archive '{archive}': {exc}",
                    info=None,
                ),
                lock_failure,
            )

    def _fetch_demand_with_retry(
        self, archive: str, *, deadline: float
    ) -> PreviewRecord:
        attempt = 0
        while True:
            record, lock_failure = self._fetch_once(archive)
            if record.status == "ready":
                return record
            if not lock_failure:
                return record

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return record

            delay = min(LOCK_RETRY_MAX_DELAY, LOCK_RETRY_BASE_DELAY * (2**attempt))
            jitter = random.uniform(0, delay * 0.25)
            sleep_for = min(remaining, delay + jitter)
            if sleep_for <= 0:
                return record
            time.sleep(sleep_for)
            attempt += 1

    def _fetch_prefetch_once(self, archive: str) -> PreviewRecord:
        record, _ = self._fetch_once(archive)
        return record


class InteractiveArchivePicker:
    def __init__(self, manifest: Manifest, borg: BorgService) -> None:
        self.manifest = manifest
        self.borg = borg
        self.program = str(Path(sys.argv[0]).resolve())

    @staticmethod
    def ensure_fzf_available() -> None:
        if shutil.which("fzf") is None:
            raise CliError(
                "fzf is required for interactive mode but was not found in PATH"
            )

    def pick_vm(self) -> str:
        vm_names = sorted(self.manifest.vms.keys())
        if not vm_names:
            raise CliError("No backup-enabled VMs configured.")
        self.ensure_fzf_available()
        return self._run_fzf(vm_names, prompt="vm> ")

    def pick_archive(self, vm: str, vm_data: VmBackupConfig) -> ArchiveSelection:
        self.ensure_fzf_available()
        archives = self.borg.list_archive_names(vm_data)
        if not archives:
            raise CliError(f"No archives found for VM: {vm}")

        with InlinePreviewServer(vm_data=vm_data, borg=self.borg) as server:
            server.prefetch_archives(archives)
            preview_cmd = f"{shlex.quote(self.program)} __preview --archive {{}}"
            selected = self._run_fzf(
                archives,
                prompt=f"{vm} archive> ",
                preview_command=preview_cmd,
                env={PREVIEW_SOCKET_ENV: server.socket_name},
            )
            info = server.resolve_archive_info(selected, timeout_ms=200)
        return ArchiveSelection(archive=selected, info=info)

    @staticmethod
    def _run_fzf(
        rows: Sequence[str],
        *,
        prompt: str,
        preview_command: str | None = None,
        env: Mapping[str, str] | None = None,
    ) -> str:
        if not rows:
            raise CliError("fzf invoked with no rows")

        cmd = ["fzf", "--prompt", prompt]
        if preview_command is not None:
            cmd.extend(
                [
                    "--preview",
                    preview_command,
                    "--preview-window",
                    "right:60%:wrap",
                ]
            )

        input_text = "\n".join(rows) + "\n"
        exec_env = os.environ.copy()
        if env is not None:
            exec_env.update(env)

        result = subprocess.run(
            cmd,
            input=input_text,
            text=True,
            capture_output=True,
            env=exec_env,
            check=False,
        )
        if result.returncode == 0:
            selected = result.stdout.strip()
            if selected == "":
                raise CliError("fzf completed without selecting a value")
            return selected

        if result.returncode in {1, 130}:
            raise PickerCancelled()

        stderr = (result.stderr or "").strip()
        if stderr:
            raise CliError(f"fzf failed (exit {result.returncode}): {stderr}")
        raise CliError(f"fzf failed (exit {result.returncode})")


def _parse_preview_socket_name(raw_name: str) -> str:
    if raw_name.startswith("@"):
        return "\0" + raw_name[1:]
    return raw_name


def _preview_rpc(
    request: Mapping[str, object], *, timeout_seconds: float
) -> dict[str, object]:
    raw_name = os.environ.get(PREVIEW_SOCKET_ENV)
    if raw_name is None or raw_name == "":
        raise CliError(f"missing {PREVIEW_SOCKET_ENV} for preview client")

    socket_name = _parse_preview_socket_name(raw_name)
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(timeout_seconds)
        try:
            client.connect(socket_name)
        except OSError as exc:
            raise CliError(f"failed to connect preview socket: {exc}") from exc

        payload = json.dumps(dict(request)).encode("utf-8") + b"\n"
        client.sendall(payload)
        client.shutdown(socket.SHUT_WR)

        chunks: list[bytes] = []
        while True:
            part = client.recv(4096)
            if not part:
                break
            chunks.append(part)
            if b"\n" in part:
                break

    if not chunks:
        raise CliError("preview server returned no response")

    line = b"".join(chunks).split(b"\n", 1)[0]
    try:
        raw = json.loads(line.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise CliError(f"invalid preview response: {exc}") from exc
    if not isinstance(raw, dict):
        raise CliError("invalid preview response type")
    return raw


def run_preview_client(args: argparse.Namespace) -> int:
    archive = _string_or_na(args.archive).strip()
    if archive == "":
        print("Missing archive name for preview", file=sys.stderr)
        return 1

    print(f"Loading archive info for {archive}...", flush=True)

    try:
        response = _preview_rpc(
            {
                "op": "get_preview",
                "archive": archive,
                "wait_ms": PREVIEW_WAIT_MS,
            },
            timeout_seconds=(PREVIEW_WAIT_MS / 1000.0) + 2.0,
        )
        status = _string_or_na(response.get("status"))
        text = _string_or_na(response.get("text"))
    except CliError as exc:
        status = "error"
        text = f"Preview client error: {exc}"

    if status == "loading":
        text = f"Loading archive info for '{archive}'..."
    elif status == "timeout":
        text = (
            f"Timed out while loading archive '{archive}' after "
            f"{PREVIEW_WAIT_MS / 1000:.1f}s."
        )
    elif status == "error" and text == "N/A":
        text = f"Failed to load preview for archive '{archive}'."

    sys.stdout.write(PREVIEW_CLEAR_SCREEN)
    sys.stdout.write(text)
    if not text.endswith("\n"):
        sys.stdout.write("\n")
    sys.stdout.flush()
    return 0


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


def ask_restore_confirmation(
    borg: BorgService, vm: str, info: ArchiveInfo, target: Path
) -> bool:
    print("Restore Confirmation")
    print(borg.format_archive_summary(vm=vm, target=target, info=info))
    answer = input("Proceed with restore? [y/N]: ").strip().lower()
    return answer in {"y", "yes"}


def handle_backup(ctx: AppContext, args: argparse.Namespace) -> None:
    require_vm(ctx.manifest, args.vm)
    ctx.systemd.restart_backup_job(args.vm)


def _resolve_vm_for_interactive(
    ctx: AppContext, requested_vm: str | None
) -> tuple[str, VmBackupConfig]:
    if requested_vm is not None:
        return requested_vm, require_vm(ctx.manifest, requested_vm)

    picker = InteractiveArchivePicker(ctx.manifest, ctx.borg)
    vm = picker.pick_vm()
    return vm, require_vm(ctx.manifest, vm)


def handle_list(ctx: AppContext, args: argparse.Namespace) -> None:
    if ctx.runner.dry_run:
        if args.vm is None:
            raise CliError(
                "interactive mode is disabled in dry-run; provide VM explicitly for list"
            )
        vm_data = require_vm(ctx.manifest, args.vm)
        print(f"VM: {args.vm}")
        print(f"Subvolume: {vm_paths(ctx.manifest.volume_path, args.vm).target}")
        ctx.borg.list_archives(vm_data)
        return

    vm, vm_data = _resolve_vm_for_interactive(ctx, args.vm)
    picker = InteractiveArchivePicker(ctx.manifest, ctx.borg)
    selection = picker.pick_archive(vm, vm_data)
    info = selection.info or ctx.borg.fetch_archive_info(vm_data, selection.archive)
    target = vm_paths(ctx.manifest.volume_path, vm).target
    print(ctx.borg.format_archive_summary(vm=vm, target=target, info=info))


def handle_restore(ctx: AppContext, args: argparse.Namespace) -> None:
    if ctx.runner.dry_run:
        if args.vm is None or args.archive is None:
            raise CliError(
                "interactive mode is disabled in dry-run; provide both VM and archive"
            )
        vm_data = require_vm(ctx.manifest, args.vm)
        with RestoreTransaction(ctx, args.vm, args.archive, vm_data) as tx:
            tx.run()
        return

    vm: str
    archive: str
    info: ArchiveInfo | None = None

    if args.vm is not None:
        vm = args.vm
        vm_data = require_vm(ctx.manifest, vm)
    else:
        picker = InteractiveArchivePicker(ctx.manifest, ctx.borg)
        vm = picker.pick_vm()
        vm_data = require_vm(ctx.manifest, vm)

    if args.archive is not None:
        archive = args.archive
    else:
        picker = InteractiveArchivePicker(ctx.manifest, ctx.borg)
        selection = picker.pick_archive(vm, vm_data)
        archive = selection.archive
        info = selection.info

    if not args.yes:
        if info is None:
            info = ctx.borg.fetch_archive_info(vm_data, archive)
        target = vm_paths(ctx.manifest.volume_path, vm).target
        confirmed = ask_restore_confirmation(ctx.borg, vm, info, target)
        if not confirmed:
            raise CliError("restore cancelled by user")

    with RestoreTransaction(ctx, vm, archive, vm_data) as tx:
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
    restore_parser.add_argument(
        "--yes", action="store_true", help="Skip restore confirmation"
    )
    restore_parser.add_argument("vm", nargs="?")
    restore_parser.add_argument("archive", nargs="?")
    restore_parser.set_defaults(handler=handle_restore)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    raw_argv = list(argv) if argv is not None else sys.argv[1:]
    if raw_argv and raw_argv[0] == "__preview":
        preview_parser = argparse.ArgumentParser(
            prog="microvm-image-backup __preview",
            add_help=False,
        )
        preview_parser.add_argument("--archive", required=True)
        preview_args = preview_parser.parse_args(raw_argv[1:])
        return run_preview_client(preview_args)

    parser = build_parser()
    args = parser.parse_args(raw_argv)

    configure_logging(args.verbose)

    try:
        ensure_root_for_privileged_command(args.command, dry_run=args.dry_run)
        manifest = load_manifest(args.manifest)
        runner = CommandRunner(dry_run=args.dry_run)
        ctx = AppContext(
            manifest=manifest,
            runner=runner,
            btrfs=BtrfsManager(runner),
            borg=BorgService(runner),
            systemd=SystemdManager(runner),
        )

        handler = getattr(args, "handler", None)
        if handler is None:
            parser.error("unknown command")
        typed_handler: Callable[[AppContext, argparse.Namespace], None] = handler
        typed_handler(ctx, args)
    except PickerCancelled:
        return 130
    except CliError as exc:
        LOGGER.error("%s", exc)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
