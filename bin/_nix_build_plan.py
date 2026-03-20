from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class BuildPlanRow:
    kind: str
    name: str
    drv: str
    pname: str
    version: str
    system: str


def _run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, cwd=cwd)


def _extract_drv_paths(output: str) -> list[str]:
    return [
        line.strip()
        for line in output.splitlines()
        if line.startswith("  /nix/store/") and line.endswith(".drv")
    ]


def _classify_derivation(drv: str, *, cwd: Path | None = None) -> BuildPlanRow:
    proc = _run(["nix", "derivation", "show", drv], cwd=cwd)
    if proc.returncode != 0:
        message = proc.stderr.strip() or f"failed to inspect derivation: {drv}"
        raise RuntimeError(message)

    derivation = next(iter(json.loads(proc.stdout)["derivations"].values()))
    env = derivation.get("env", {})

    if env.get("src") or env.get("pname") or env.get("version"):
        kind = "real-ish"
    elif env.get("buildCommand") and not env.get("buildInputs") and not env.get("nativeBuildInputs"):
        kind = "wrapper-ish"
    else:
        kind = "inspect"

    return BuildPlanRow(
        kind=kind,
        name=derivation.get("name", ""),
        drv=drv,
        pname=env.get("pname", ""),
        version=env.get("version", ""),
        system=derivation.get("system", ""),
    )


def classify_build_plan(build_args: list[str], *, cwd: Path | None = None) -> list[BuildPlanRow]:
    proc = _run(["nix", "build", *build_args, "--dry-run", "--no-link"], cwd=cwd)
    output = f"{proc.stdout}{proc.stderr}"
    if proc.returncode != 0:
        raise RuntimeError(output.strip())

    return [_classify_derivation(drv, cwd=cwd) for drv in _extract_drv_paths(output)]


def format_tsv(rows: list[BuildPlanRow]) -> str:
    lines = ["class\tname\tdrv"]
    lines.extend(f"{row.kind}\t{row.name}\t{row.drv}" for row in rows)
    return "\n".join(lines)


def format_table(headers: list[str], rows: list[list[str]]) -> str:
    matrix = [headers, *rows]
    widths = [max(len(row[i]) for row in matrix) for i in range(len(headers))]
    return "\n".join(
        "  ".join(value.ljust(widths[i]) for i, value in enumerate(row))
        for row in matrix
    )


def format_rows(rows: list[BuildPlanRow], *, output_format: str) -> str:
    if output_format == "tsv":
        return format_tsv(rows)
    return format_table(
        ["class", "name", "drv"],
        [[row.kind, row.name, row.drv] for row in rows],
    )


def hydra_job_candidate(row: BuildPlanRow) -> str | None:
    if row.kind != "real-ish":
        return None

    base = row.pname or row.name
    if not base:
        return None

    if row.version:
        suffix = f"-{row.version}"
        if base.endswith(suffix):
            base = base[: -len(suffix)]
    else:
        base = re.sub(r"-[0-9][A-Za-z0-9.+_-]*$", "", base)

    if not base:
        return None
    if row.system and not base.endswith(f".{row.system}"):
        return f"{base}.{row.system}"
    return base
