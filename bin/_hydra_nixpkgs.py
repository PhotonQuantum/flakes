from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import UTC, datetime


@dataclass(frozen=True)
class JobBuildInfo:
    build_id: int
    job: str
    jobset: str
    project: str
    system: str
    nix_name: str
    finished_at: str | None
    eval_ids: tuple[int, ...]


@dataclass(frozen=True)
class Resolution:
    revision: str
    eval_id: int
    jobs: tuple[JobBuildInfo, ...]


@dataclass(frozen=True)
class HydraLookup:
    resolution: Resolution | None
    absent_jobs: tuple[str, ...]
    dropped_jobs: tuple[str, ...]


def hydra_job_name(package: str, system: str | None) -> str:
    return f"{package}.{system}" if system else package


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "hydra-latest-nixpkgs-rev",
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        message = error.read().decode("utf-8", errors="replace").strip()
        detail = f": {message}" if message else ""
        raise RuntimeError(f"{url} returned HTTP {error.code}{detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"failed to fetch {url}: {error.reason}") from error


def _iso8601_utc(timestamp: int | None) -> str | None:
    if timestamp is None:
        return None
    return datetime.fromtimestamp(timestamp, UTC).isoformat().replace("+00:00", "Z")


def latest_build_url(base_url: str, project: str, jobset: str, job: str) -> str:
    return f"{base_url.rstrip('/')}/job/{project}/{jobset}/{job}/latest-finished"


def eval_url(base_url: str, eval_id: int) -> str:
    return f"{base_url.rstrip('/')}/eval/{eval_id}"


def fetch_latest_job_build(
    *,
    base_url: str,
    project: str,
    jobset: str,
    job: str,
) -> JobBuildInfo:
    try:
        build = fetch_json(latest_build_url(base_url, project, jobset, job))
    except RuntimeError as error:
        if " returned HTTP 404" in str(error):
            raise FileNotFoundError(job) from error
        raise

    if build.get("finished") != 1:
        raise RuntimeError(f"latest finished build for {project}:{jobset}:{job} is not marked finished")
    if build.get("buildstatus") != 0:
        raise RuntimeError(
            f"latest finished build for {project}:{jobset}:{job} did not succeed "
            f"(buildstatus={build.get('buildstatus')})"
        )

    eval_ids = build.get("jobsetevals") or []
    if not eval_ids:
        raise RuntimeError(f"build {build.get('id')} has no associated jobset evaluations")

    return JobBuildInfo(
        build_id=int(build["id"]),
        job=str(build["job"]),
        jobset=str(build["jobset"]),
        project=str(build["project"]),
        system=str(build["system"]),
        nix_name=str(build.get("nixname") or ""),
        finished_at=_iso8601_utc(build.get("stoptime")),
        eval_ids=tuple(sorted(int(eval_id) for eval_id in eval_ids)),
    )


def find_latest_revision(
    *,
    base_url: str,
    project: str,
    jobset: str,
    jobs: list[str],
    input_name: str,
    max_eval_id: int | None = None,
) -> Resolution:
    job_infos = []
    for job in jobs:
        info = fetch_latest_job_build(
            base_url=base_url,
            project=project,
            jobset=jobset,
            job=job,
        )
        job_infos.append(_with_filtered_evals(info, max_eval_id))

    common_eval_ids = _common_eval_ids(job_infos)

    if not common_eval_ids:
        names = ", ".join(info.job for info in job_infos)
        scope = f" at or before eval {max_eval_id}" if max_eval_id is not None else ""
        raise RuntimeError(f"no common evaluation found across latest successful builds for{scope}: {names}")

    eval_id = max(common_eval_ids)
    evaluation = fetch_json(eval_url(base_url, eval_id))
    inputs = evaluation.get("jobsetevalinputs") or {}
    input_info = inputs.get(input_name)
    if not input_info:
        available = ", ".join(sorted(inputs)) or "none"
        raise RuntimeError(
            f"evaluation {eval_id} does not have input {input_name!r}; available inputs: {available}"
        )

    revision = input_info.get("revision")
    if not revision:
        raise RuntimeError(f"evaluation {eval_id} input {input_name!r} has no revision")

    return Resolution(
        revision=str(revision),
        eval_id=eval_id,
        jobs=tuple(job_infos),
    )


def lookup_latest_revision(
    *,
    base_url: str,
    project: str,
    jobset: str,
    jobs: list[str],
    input_name: str,
    max_eval_id: int | None = None,
) -> HydraLookup:
    absent_jobs: list[str] = []
    job_infos: list[JobBuildInfo] = []

    for job in jobs:
        try:
            info = fetch_latest_job_build(
                base_url=base_url,
                project=project,
                jobset=jobset,
                job=job,
            )
        except FileNotFoundError:
            absent_jobs.append(job)
        else:
            job_infos.append(_with_filtered_evals(info, max_eval_id))

    resolution = None
    dropped_jobs: list[str] = []
    active_infos = [info for info in job_infos if info.eval_ids]

    while active_infos:
        common_eval_ids = _common_eval_ids(active_infos)
        if common_eval_ids:
            eval_id = max(common_eval_ids)
            evaluation = fetch_json(eval_url(base_url, eval_id))
            inputs = evaluation.get("jobsetevalinputs") or {}
            input_info = inputs.get(input_name)
            if not input_info:
                available = ", ".join(sorted(inputs)) or "none"
                raise RuntimeError(
                    f"evaluation {eval_id} does not have input {input_name!r}; available inputs: {available}"
                )
            revision = input_info.get("revision")
            if not revision:
                raise RuntimeError(f"evaluation {eval_id} input {input_name!r} has no revision")
            resolution = Resolution(revision=str(revision), eval_id=eval_id, jobs=tuple(active_infos))
            break

        if len(active_infos) == 1:
            dropped_jobs.append(active_infos[0].job)
            active_infos = []
            break

        removal_index = _best_job_to_drop(active_infos)
        dropped_jobs.append(active_infos[removal_index].job)
        active_infos = active_infos[:removal_index] + active_infos[removal_index + 1 :]

    dropped_jobs.extend(info.job for info in job_infos if not info.eval_ids and info.job not in dropped_jobs)
    return HydraLookup(
        resolution=resolution,
        absent_jobs=tuple(absent_jobs),
        dropped_jobs=tuple(dropped_jobs),
    )


def _with_filtered_evals(info: JobBuildInfo, max_eval_id: int | None) -> JobBuildInfo:
    eval_ids = tuple(eval_id for eval_id in info.eval_ids if max_eval_id is None or eval_id <= max_eval_id)
    return JobBuildInfo(
        build_id=info.build_id,
        job=info.job,
        jobset=info.jobset,
        project=info.project,
        system=info.system,
        nix_name=info.nix_name,
        finished_at=info.finished_at,
        eval_ids=eval_ids,
    )


def _common_eval_ids(job_infos: list[JobBuildInfo]) -> set[int]:
    if not job_infos:
        return set()
    common_eval_ids = set(job_infos[0].eval_ids)
    for info in job_infos[1:]:
        common_eval_ids &= set(info.eval_ids)
    return common_eval_ids


def _best_job_to_drop(job_infos: list[JobBuildInfo]) -> int:
    best_index = 0
    best_score: tuple[int, int, int, int] | None = None
    for index, info in enumerate(job_infos):
        remaining = job_infos[:index] + job_infos[index + 1 :]
        common_eval_ids = _common_eval_ids(remaining)
        score = (
            1 if common_eval_ids else 0,
            max(common_eval_ids) if common_eval_ids else -1,
            len(common_eval_ids),
            -len(info.eval_ids),
        )
        if best_score is None or score > best_score:
            best_score = score
            best_index = index
    return best_index
