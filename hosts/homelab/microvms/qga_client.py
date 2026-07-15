#!/usr/bin/env python3

import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import NoReturn, Sequence


DEFAULT_TIMEOUT = 10.0


class QgaError(Exception):
    pass


class QgaClient:
    def __init__(self, socket_path: Path, timeout: float) -> None:
        self.socket_path = socket_path
        self.timeout = timeout
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.settimeout(timeout)
        try:
            self.socket.connect(str(socket_path))
        except OSError as exc:
            self.socket.close()
            raise QgaError(f"cannot connect to QGA socket {socket_path}: {exc}") from exc
        self.stream = self.socket.makefile("rwb", buffering=0)

    def __enter__(self) -> "QgaClient":
        return self

    def __exit__(self, *_: object) -> None:
        self.stream.close()
        self.socket.close()

    def _read_response(self, request_id: str) -> object:
        deadline = time.monotonic() + self.timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise QgaError(f"timed out waiting for QGA response to {request_id}")
            self.socket.settimeout(remaining)
            try:
                line = self.stream.readline()
            except (OSError, TimeoutError) as exc:
                raise QgaError(
                    f"failed while waiting for QGA response to {request_id}: {exc}"
                ) from exc
            if not line:
                raise QgaError(f"QGA disconnected while handling {request_id}")

            # guest-sync-delimited prefixes its response with 0xff.  Prefixing
            # requests with the same byte also resets any partial stale input.
            line = line.lstrip(b"\xff")
            try:
                response = json.loads(line)
            except (UnicodeDecodeError, json.JSONDecodeError):
                continue
            if not isinstance(response, dict) or response.get("id") != request_id:
                continue
            if "error" in response:
                error = response["error"]
                if isinstance(error, dict):
                    description = error.get("desc", error)
                else:
                    description = error
                raise QgaError(f"QGA command {request_id} failed: {description}")
            if "return" not in response:
                raise QgaError(f"malformed QGA response to {request_id}: {response}")
            return response["return"]

    def execute(
        self,
        command: str,
        arguments: dict[str, object] | None = None,
        *,
        reset_stream: bool = False,
    ) -> object:
        request_id = f"{command}-{secrets.token_hex(8)}"
        request: dict[str, object] = {"execute": command, "id": request_id}
        if arguments is not None:
            request["arguments"] = arguments
        prefix = b"\xff" if reset_stream else b""
        payload = json.dumps(request, separators=(",", ":")).encode("utf-8")
        try:
            self.stream.write(prefix + payload + b"\n")
        except OSError as exc:
            raise QgaError(f"failed to send QGA command {command}: {exc}") from exc
        return self._read_response(request_id)

    def synchronize(self) -> None:
        token = secrets.randbits(63)
        result = self.execute(
            "guest-sync-delimited",
            {"id": token},
            reset_stream=True,
        )
        if result != token:
            raise QgaError(f"QGA synchronization returned {result!r}, expected {token}")


def require_status(value: object) -> str:
    if not isinstance(value, str) or value not in {"thawed", "frozen"}:
        raise QgaError(f"unexpected QGA filesystem freeze status: {value!r}")
    return str(value)


def require_count(command: str, value: object) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise QgaError(f"{command} returned a non-integer filesystem count: {value!r}")
    return value


def emergency_thaw(socket_path: Path, timeout: float) -> int:
    with QgaClient(socket_path, timeout) as client:
        # Reset the parser and issue thaw directly: synchronization is useful
        # but must not stand between a frozen guest and the recovery command.
        result = client.execute("guest-fsfreeze-thaw", reset_stream=True)
        return require_count("guest-fsfreeze-thaw", result)


def freeze_exec(
    socket_path: Path,
    timeout: float,
    command: Sequence[str],
) -> int:
    if not command:
        raise QgaError("freeze-exec requires a command after --")

    freeze_attempted = False
    thawed = False
    command_result: subprocess.CompletedProcess[bytes] | None = None
    primary_error: BaseException | None = None

    try:
        with QgaClient(socket_path, timeout) as client:
            client.synchronize()
            client.execute("guest-ping")
            status = require_status(client.execute("guest-fsfreeze-status"))
            if status != "thawed":
                raise QgaError(
                    f"refusing to take ownership of guest already in {status!r} state"
                )

            freeze_attempted = True
            frozen_count = require_count(
                "guest-fsfreeze-freeze",
                client.execute("guest-fsfreeze-freeze"),
            )
            if frozen_count < 1:
                raise QgaError("guest-fsfreeze-freeze did not freeze any filesystems")
            print(f"QGA: froze {frozen_count} guest filesystem(s)", flush=True)

            try:
                command_result = subprocess.run(command, check=False)
            except BaseException as exc:
                primary_error = exc
            finally:
                try:
                    thawed_count = require_count(
                        "guest-fsfreeze-thaw",
                        client.execute("guest-fsfreeze-thaw"),
                    )
                    final_status = require_status(
                        client.execute("guest-fsfreeze-status")
                    )
                    if final_status != "thawed":
                        raise QgaError(
                            f"guest remained in {final_status!r} state after thaw"
                        )
                    thawed = True
                    print(
                        f"QGA: thawed {thawed_count} guest filesystem(s)",
                        flush=True,
                    )
                except BaseException as exc:
                    if primary_error is None:
                        primary_error = exc
    except BaseException as exc:
        if primary_error is None:
            primary_error = exc

    if freeze_attempted and not thawed:
        try:
            thawed_count = emergency_thaw(socket_path, timeout)
            thawed = True
            print(
                f"QGA: emergency thaw released {thawed_count} guest filesystem(s)",
                flush=True,
            )
        except BaseException as thaw_error:
            if primary_error is None:
                primary_error = thaw_error
            else:
                primary_error = QgaError(
                    f"{primary_error}; emergency thaw also failed: {thaw_error}"
                )

    if primary_error is not None:
        raise primary_error
    if command_result is None:
        raise QgaError("snapshot command did not run")
    return command_result.returncode


def inspect_agent(socket_path: Path, timeout: float, command: str) -> object:
    with QgaClient(socket_path, timeout) as client:
        client.synchronize()
        if command == "ping":
            return client.execute("guest-ping")
        if command == "status":
            return require_status(client.execute("guest-fsfreeze-status"))
    raise QgaError(f"unsupported inspection command: {command}")


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Control qemu-ga and run a host command during a short guest freeze"
    )
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    subparsers = parser.add_subparsers(dest="action", required=True)

    for action in ("ping", "status", "thaw"):
        subparser = subparsers.add_parser(action)
        subparser.add_argument("socket", type=Path)

    freeze_parser = subparsers.add_parser("freeze-exec")
    freeze_parser.add_argument("socket", type=Path)
    freeze_parser.add_argument("command", nargs=argparse.REMAINDER)
    return parser.parse_args(argv)


def fail(message: str) -> NoReturn:
    print(f"microvm-qga: error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.timeout <= 0:
        fail("--timeout must be positive")

    try:
        if args.action == "freeze-exec":
            command = args.command
            if command and command[0] == "--":
                command = command[1:]
            return freeze_exec(args.socket, args.timeout, command)

        if args.action == "thaw":
            thawed_count = emergency_thaw(args.socket, args.timeout)
            print(f"QGA: thawed {thawed_count} guest filesystem(s)")
            return 0

        result = inspect_agent(args.socket, args.timeout, args.action)
        if args.action == "status":
            print(result)
        else:
            print("ok")
        return 0
    except (OSError, QgaError, subprocess.SubprocessError) as exc:
        fail(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
