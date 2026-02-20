import concurrent.futures
import importlib.util
import io
import os
import subprocess
import sys
import threading
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).with_name("microvm_image_backup.py")
SPEC = importlib.util.spec_from_file_location("microvm_image_backup", MODULE_PATH)
assert SPEC is not None
assert SPEC.loader is not None
mib = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mib
SPEC.loader.exec_module(mib)


def make_manifest() -> mib.Manifest:
    return mib.Manifest(
        volume_path=Path("/srv/microvms"),
        vms={
            "vm1": mib.VmBackupConfig(
                repo="ssh://example/repo",
                pass_file=Path("/var/keys/pass"),
                ssh_key_path=Path("/var/keys/key"),
            )
        },
    )


def make_context(*, dry_run: bool, borg: object | None = None) -> mib.AppContext:
    return mib.AppContext(
        manifest=make_manifest(),
        runner=mib.CommandRunner(dry_run=dry_run),
        btrfs=mock.Mock(),
        borg=borg if borg is not None else mock.Mock(),
        systemd=mock.Mock(),
    )


def make_info(archive: str) -> mib.ArchiveInfo:
    return mib.ArchiveInfo(
        archive=archive,
        start="2026-02-20T00:00:00",
        end="2026-02-20T00:01:00",
        duration="60s",
        hostname="test-host",
        username="root",
        source_path="/srv/microvms/vm1",
        command_line="borg create ...",
        file_count="10",
        original_size="1.00 MiB",
        compressed_size="512.00 KiB",
        deduplicated_size="256.00 KiB",
    )


class FakeBorgForPreview:
    def __init__(self, delay: float) -> None:
        self.delay = delay
        self.calls = 0
        self.lock = threading.Lock()

    def fetch_archive_info(
        self, vm_data: mib.VmBackupConfig, archive: str
    ) -> mib.ArchiveInfo:
        del vm_data
        with self.lock:
            self.calls += 1
        time.sleep(self.delay)
        return make_info(archive)

    def format_archive_details(self, info: mib.ArchiveInfo) -> str:
        return f"Archive: {info.archive}"


class BorgServiceTests(unittest.TestCase):
    def test_list_archive_names_sorted_descending(self) -> None:
        runner = mock.Mock()
        runner.check.return_value = subprocess.CompletedProcess(
            args=["borg", "list", "--short"],
            returncode=0,
            stdout="vm-2026-01-01\nvm-2026-01-03\nvm-2026-01-02\n",
            stderr="",
        )

        borg = mib.BorgService(runner)
        vm_data = make_manifest().vms["vm1"]
        names = borg.list_archive_names(vm_data)

        self.assertEqual(
            names,
            ["vm-2026-01-03", "vm-2026-01-02", "vm-2026-01-01"],
        )

    def test_format_archive_summary_includes_archive_without_heading(self) -> None:
        runner = mock.Mock()
        borg = mib.BorgService(runner)

        info = make_info("vm-2026-01-03")
        summary = borg.format_archive_summary(
            vm="vm1",
            target=Path("/srv/microvms/vm1"),
            info=info,
        )

        self.assertIn("VM: vm1", summary)
        self.assertIn("Archive: vm-2026-01-03", summary)
        self.assertIn("Restore target: /srv/microvms/vm1", summary)
        self.assertNotIn("Selected Archive", summary)


class ParserTests(unittest.TestCase):
    def test_restore_accepts_optional_positionals(self) -> None:
        parser = mib.build_parser()

        no_args = parser.parse_args(["restore"])
        self.assertIsNone(no_args.vm)
        self.assertIsNone(no_args.archive)
        self.assertFalse(no_args.yes)

        only_vm = parser.parse_args(["restore", "vm1"])
        self.assertEqual(only_vm.vm, "vm1")
        self.assertIsNone(only_vm.archive)

        vm_and_archive = parser.parse_args(["restore", "--yes", "vm1", "a1"])
        self.assertEqual(vm_and_archive.vm, "vm1")
        self.assertEqual(vm_and_archive.archive, "a1")
        self.assertTrue(vm_and_archive.yes)


class FlowTests(unittest.TestCase):
    def test_list_dry_run_requires_vm(self) -> None:
        parser = mib.build_parser()
        args = parser.parse_args(["--dry-run", "list"])
        ctx = make_context(dry_run=True)

        with self.assertRaises(mib.CliError):
            mib.handle_list(ctx, args)

    def test_list_interactive_path_uses_picker_and_prints_summary(self) -> None:
        parser = mib.build_parser()
        args = parser.parse_args(["list"])

        borg = mock.Mock()
        info = make_info("a1")
        borg.format_archive_summary.return_value = "summary"

        ctx = make_context(dry_run=False, borg=borg)

        picker = mock.Mock()
        picker.pick_vm.return_value = "vm1"
        picker.pick_archive.return_value = mib.ArchiveSelection(archive="a1", info=info)

        stdout = io.StringIO()
        with (
            mock.patch.object(mib, "InteractiveArchivePicker", return_value=picker),
            redirect_stdout(stdout),
        ):
            mib.handle_list(ctx, args)

        vm_data = ctx.manifest.vms["vm1"]
        picker.pick_vm.assert_called_once()
        picker.pick_archive.assert_called_once_with("vm1", vm_data)
        self.assertEqual(stdout.getvalue(), "summary\n")

    def test_restore_dry_run_requires_explicit_archive(self) -> None:
        parser = mib.build_parser()
        args = parser.parse_args(["--dry-run", "restore", "vm1"])
        ctx = make_context(dry_run=True)

        with self.assertRaises(mib.CliError):
            mib.handle_restore(ctx, args)

    def test_restore_yes_skips_confirmation(self) -> None:
        parser = mib.build_parser()
        args = parser.parse_args(["restore", "--yes", "vm1", "a1"])

        ctx = make_context(dry_run=False, borg=mock.Mock())
        tx = mock.MagicMock()
        tx.__enter__.return_value = tx
        tx.__exit__.return_value = False

        with (
            mock.patch.object(mib, "ask_restore_confirmation") as confirm,
            mock.patch.object(mib, "RestoreTransaction", return_value=tx),
        ):
            mib.handle_restore(ctx, args)

        confirm.assert_not_called()
        tx.run.assert_called_once()

    def test_restore_confirmation_reuses_archive_summary(self) -> None:
        borg = mock.Mock()
        borg.format_archive_summary.return_value = "summary-block"
        info = make_info("a1")

        with (
            mock.patch("builtins.input", return_value="yes"),
            mock.patch("sys.stdout", new_callable=io.StringIO) as stdout,
        ):
            confirmed = mib.ask_restore_confirmation(
                borg,
                "vm1",
                info,
                Path("/srv/microvms/vm1"),
            )

        self.assertTrue(confirmed)
        borg.format_archive_summary.assert_called_once_with(
            vm="vm1",
            target=Path("/srv/microvms/vm1"),
            info=info,
        )
        rendered = stdout.getvalue()
        self.assertIn("Restore Confirmation", rendered)
        self.assertIn("summary-block", rendered)

    def test_main_returns_130_on_picker_cancel(self) -> None:
        picker = mock.Mock()
        picker.pick_vm.side_effect = mib.PickerCancelled()

        with (
            mock.patch.object(mib, "ensure_root_for_privileged_command"),
            mock.patch.object(mib, "load_manifest", return_value=make_manifest()),
            mock.patch.object(mib, "InteractiveArchivePicker", return_value=picker),
            mock.patch.object(mib, "BorgService", return_value=mock.Mock()),
        ):
            rc = mib.main(["list"])

        self.assertEqual(rc, 130)


class PreviewServerTests(unittest.TestCase):
    @staticmethod
    def _wait_for(predicate: callable, timeout: float = 1.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.01)
        return False

    class PriorityBorg:
        def __init__(self, blocked: set[str] | None = None) -> None:
            self.blocked = blocked or set()
            self.release_events = {name: threading.Event() for name in self.blocked}
            self.started: dict[str, threading.Event] = {}
            self.order: list[str] = []
            self.lock = threading.Lock()

        def fetch_archive_info(
            self, vm_data: mib.VmBackupConfig, archive: str
        ) -> mib.ArchiveInfo:
            del vm_data
            with self.lock:
                self.order.append(archive)
                evt = self.started.setdefault(archive, threading.Event())
                evt.set()
            release = self.release_events.get(archive)
            if release is not None:
                release.wait(timeout=2.0)
            return make_info(archive)

        def format_archive_details(self, info: mib.ArchiveInfo) -> str:
            return f"Archive: {info.archive}"

    class ScriptedBorg:
        def __init__(self, script: dict[str, list[object]]) -> None:
            self.script = {k: list(v) for k, v in script.items()}
            self.calls: dict[str, int] = {}
            self.lock = threading.Lock()
            self.first_call_done: dict[str, threading.Event] = {}

        def fetch_archive_info(
            self, vm_data: mib.VmBackupConfig, archive: str
        ) -> mib.ArchiveInfo:
            del vm_data
            with self.lock:
                self.calls[archive] = self.calls.get(archive, 0) + 1
                action = self.script[archive].pop(0)

            try:
                if isinstance(action, Exception):
                    raise action
                if isinstance(action, float):
                    time.sleep(action)
                    return make_info(archive)
                if action == "ok":
                    return make_info(archive)
                raise AssertionError(f"unknown script action: {action}")
            finally:
                with self.lock:
                    evt = self.first_call_done.setdefault(archive, threading.Event())
                    evt.set()

        def format_archive_details(self, info: mib.ArchiveInfo) -> str:
            return f"Archive: {info.archive}"

    def test_priority_over_prefetch(self) -> None:
        fake_borg = self.PriorityBorg(blocked={"p1", "p2"})
        vm_data = make_manifest().vms["vm1"]
        response_holder: dict[str, dict[str, object]] = {}

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                server.prefetch_archives(["p1", "p2", "p3"])
                self.assertTrue(
                    self._wait_for(lambda: fake_borg.started.get("p1", threading.Event()).is_set())
                )
                self.assertTrue(
                    self._wait_for(lambda: fake_borg.started.get("p2", threading.Event()).is_set())
                )

                def request_d1() -> None:
                    response_holder["d1"] = mib._preview_rpc(
                        {"op": "get_preview", "archive": "d1", "wait_ms": 1500},
                        timeout_seconds=3.0,
                    )

                thread = threading.Thread(target=request_d1)
                thread.start()
                self.assertTrue(
                    self._wait_for(
                        lambda: "d1" in server._queued_demand,  # type: ignore[attr-defined]
                        timeout=0.5,
                    )
                )

                fake_borg.release_events["p1"].set()
                self.assertTrue(
                    self._wait_for(lambda: fake_borg.started.get("d1", threading.Event()).is_set())
                )
                fake_borg.release_events["p2"].set()
                thread.join(timeout=2.0)
                self.assertFalse(thread.is_alive())
                self.assertTrue(self._wait_for(lambda: fake_borg.started.get("p3", threading.Event()).is_set()))

        self.assertEqual(response_holder["d1"].get("status"), "ready")
        self.assertLess(fake_borg.order.index("d1"), fake_borg.order.index("p3"))

    def test_error_not_cached_retries(self) -> None:
        fake_borg = self.ScriptedBorg(
            {"flaky": [mib.CliError("generic failure"), "ok"]}
        )
        vm_data = make_manifest().vms["vm1"]

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                first = mib._preview_rpc(
                    {"op": "get_preview", "archive": "flaky", "wait_ms": 600},
                    timeout_seconds=3.0,
                )
                second = mib._preview_rpc(
                    {"op": "get_preview", "archive": "flaky", "wait_ms": 600},
                    timeout_seconds=3.0,
                )

        self.assertEqual(first.get("status"), "error")
        self.assertEqual(second.get("status"), "ready")
        self.assertEqual(fake_borg.calls.get("flaky"), 2)

    def test_prefetch_skips_when_demand_pending(self) -> None:
        fake_borg = self.PriorityBorg(blocked={"busy"})
        vm_data = make_manifest().vms["vm1"]
        response_holder: dict[str, dict[str, object]] = {}

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                def request_busy() -> None:
                    response_holder["busy"] = mib._preview_rpc(
                        {"op": "get_preview", "archive": "busy", "wait_ms": 1500},
                        timeout_seconds=3.0,
                    )

                thread = threading.Thread(target=request_busy)
                thread.start()
                self.assertTrue(
                    self._wait_for(lambda: fake_borg.started.get("busy", threading.Event()).is_set())
                )

                server.prefetch_archives(["later-prefetch"])
                time.sleep(0.1)
                fake_borg.release_events["busy"].set()
                thread.join(timeout=2.0)
                self.assertFalse(thread.is_alive())
                time.sleep(0.1)

                self.assertNotIn("later-prefetch", fake_borg.order)
                direct = mib._preview_rpc(
                    {"op": "get_preview", "archive": "later-prefetch", "wait_ms": 800},
                    timeout_seconds=3.0,
                )

        self.assertEqual(response_holder["busy"].get("status"), "ready")
        self.assertEqual(direct.get("status"), "ready")

    def test_lock_failure_prefetch_not_persisted(self) -> None:
        fake_borg = self.ScriptedBorg(
            {
                "locky": [
                    mib.CliError("repository is already locked by another borg process"),
                    "ok",
                ]
            }
        )
        vm_data = make_manifest().vms["vm1"]

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                server.prefetch_archives(["locky"])
                evt = fake_borg.first_call_done.setdefault("locky", threading.Event())
                self.assertTrue(evt.wait(timeout=1.0))
                response = mib._preview_rpc(
                    {"op": "get_preview", "archive": "locky", "wait_ms": 1200},
                    timeout_seconds=3.0,
                )

        self.assertEqual(response.get("status"), "ready")
        self.assertEqual(fake_borg.calls.get("locky"), 2)

    def test_lock_failure_retries_within_deadline(self) -> None:
        fake_borg = self.ScriptedBorg(
            {
                "retry-lock": [
                    mib.CliError("lock timeout"),
                    mib.CliError("already locked"),
                    "ok",
                ]
            }
        )
        vm_data = make_manifest().vms["vm1"]

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                response = mib._preview_rpc(
                    {"op": "get_preview", "archive": "retry-lock", "wait_ms": 1500},
                    timeout_seconds=3.0,
                )

        self.assertEqual(response.get("status"), "ready")
        self.assertEqual(fake_borg.calls.get("retry-lock"), 3)

    def test_single_flight_deduplicates_fetches(self) -> None:
        fake_borg = FakeBorgForPreview(delay=0.2)
        vm_data = make_manifest().vms["vm1"]

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                def request() -> dict[str, object]:
                    return mib._preview_rpc(
                        {"op": "get_preview", "archive": "a1", "wait_ms": 1500},
                        timeout_seconds=3.0,
                    )

                with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                    first = pool.submit(request)
                    second = pool.submit(request)
                    r1 = first.result()
                    r2 = second.result()

        self.assertEqual(r1.get("status"), "ready")
        self.assertEqual(r2.get("status"), "ready")
        self.assertEqual(fake_borg.calls, 1)

    def test_cached_response_is_reused(self) -> None:
        fake_borg = FakeBorgForPreview(delay=0.05)
        vm_data = make_manifest().vms["vm1"]

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                first = mib._preview_rpc(
                    {"op": "get_preview", "archive": "a1", "wait_ms": 1500},
                    timeout_seconds=3.0,
                )
                second = mib._preview_rpc(
                    {"op": "get_preview", "archive": "a1", "wait_ms": 0},
                    timeout_seconds=3.0,
                )

        self.assertEqual(first.get("status"), "ready")
        self.assertEqual(second.get("status"), "ready")
        self.assertEqual(fake_borg.calls, 1)

    def test_timeout_response_when_fetch_is_slow(self) -> None:
        fake_borg = FakeBorgForPreview(delay=0.5)
        vm_data = make_manifest().vms["vm1"]

        with mib.InlinePreviewServer(vm_data=vm_data, borg=fake_borg) as server:
            with mock.patch.dict(os.environ, {mib.PREVIEW_SOCKET_ENV: server.socket_name}):
                response = mib._preview_rpc(
                    {"op": "get_preview", "archive": "slow", "wait_ms": 1},
                    timeout_seconds=3.0,
                )

        self.assertEqual(response.get("status"), "timeout")


if __name__ == "__main__":
    unittest.main()
