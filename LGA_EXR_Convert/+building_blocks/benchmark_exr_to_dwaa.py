#!/usr/bin/env python3
"""Benchmark EXR -> DWAA conversion methods on a small frame subset."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = Path(r"T:\VFX-TEST\ERSO_000_310_FgPlate_v02")
OIIO_TOOL = REPO_ROOT / "OIIO" / "oiiotool.exe"
IINFO = REPO_ROOT / "OIIO" / "iinfo.exe"
EXRHEADER = REPO_ROOT / "OpenEXR" / "exrheader.exe"
EXRMETRICS = REPO_ROOT / "OpenEXR" / "exrmetrics.exe"
OUTPUT_ROOT = Path(__file__).resolve().parent / "_benchmark_output"

EXPECTED_METADATA_DIFF_PREFIXES = (
    "compression:",
    "exr:dwaCompressionLevel:",
    "openexr:dwaCompressionLevel:",
)


@dataclass(frozen=True)
class FrameJob:
    source: Path
    output: Path


def run_command(args: list[str], timeout: int | None = 60) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        return subprocess.CompletedProcess(
            args=args,
            returncode=124,
            stdout=exc.stdout or "",
            stderr=(exc.stderr or "") + f"\nTIMEOUT after {timeout}s",
        )


def list_frames(source_dir: Path, count: int) -> list[Path]:
    frames = sorted(source_dir.glob("*.exr"), key=lambda p: p.name.lower())
    if len(frames) < count:
        raise RuntimeError(f"Only found {len(frames)} EXR frames in {source_dir}")
    return frames[:count]


def prepare_method_dir(run_dir: Path, method_name: str) -> Path:
    method_dir = run_dir / method_name
    if method_dir.exists():
        shutil.rmtree(method_dir)
    method_dir.mkdir(parents=True, exist_ok=True)
    return method_dir


def output_name_for(source: Path) -> str:
    return source.stem + "_dwaa.exr"


def make_jobs(frames: Iterable[Path], method_dir: Path) -> list[FrameJob]:
    return [FrameJob(frame, method_dir / output_name_for(frame)) for frame in frames]


def convert_oiiotool(job: FrameJob, compression_arg: str = "dwaa:quality=60") -> dict:
    started = time.perf_counter()
    args = [
        str(OIIO_TOOL),
        str(job.source),
        "--compression",
        compression_arg,
        "--nosoftwareattrib",
        "-o",
        str(job.output),
    ]
    proc = run_command(args)
    elapsed = time.perf_counter() - started
    return {
        "source": str(job.source),
        "output": str(job.output),
        "returncode": proc.returncode,
        "elapsed_seconds": elapsed,
        "stdout_tail": proc.stdout[-1000:],
        "stderr_tail": proc.stderr[-1000:],
        "output_exists": job.output.exists(),
        "output_bytes": job.output.stat().st_size if job.output.exists() else 0,
    }


def convert_exrmetrics(job: FrameJob, level: int = 60) -> dict:
    started = time.perf_counter()
    args = [
        str(EXRMETRICS),
        "-z",
        "dwaa",
        "-l",
        str(level),
        str(job.source),
        str(job.output),
    ]
    proc = run_command(args)
    elapsed = time.perf_counter() - started
    return {
        "source": str(job.source),
        "output": str(job.output),
        "returncode": proc.returncode,
        "elapsed_seconds": elapsed,
        "stdout_tail": proc.stdout[-1000:],
        "stderr_tail": proc.stderr[-1000:],
        "output_exists": job.output.exists(),
        "output_bytes": job.output.stat().st_size if job.output.exists() else 0,
    }


def benchmark_sequential(name: str, jobs: list[FrameJob], converter) -> dict:
    print(f"Running {name}...", flush=True)
    started = time.perf_counter()
    frame_results = [converter(job) for job in jobs]
    elapsed = time.perf_counter() - started
    print(f"Finished {name}: {elapsed:.3f}s", flush=True)
    return summarize_method(name, jobs, frame_results, elapsed)


def benchmark_parallel(name: str, jobs: list[FrameJob], converter, workers: int) -> dict:
    print(f"Running {name}...", flush=True)
    started = time.perf_counter()
    with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as executor:
        frame_results = list(executor.map(converter, jobs))
    elapsed = time.perf_counter() - started
    print(f"Finished {name}: {elapsed:.3f}s", flush=True)
    result = summarize_method(name, jobs, frame_results, elapsed)
    result["workers"] = workers
    return result


def benchmark_oiiotool_frames(run_dir: Path, frames: list[Path]) -> dict:
    method_name = "oiiotool_frames_single_process"
    print(f"Running {method_name}...", flush=True)
    method_dir = prepare_method_dir(run_dir, method_name)
    frame_range = frame_range_from_names(frames)
    if frame_range is None:
        return {
            "method": method_name,
            "skipped": True,
            "skip_reason": "Could not infer a contiguous printf-style frame pattern.",
        }

    input_pattern, output_pattern, frame_spec = frame_range
    output_pattern = str(method_dir / Path(output_pattern).name)
    started = time.perf_counter()
    args = [
        str(OIIO_TOOL),
        "--frames",
        frame_spec,
        input_pattern,
        "--compression",
        "dwaa:quality=60",
        "--nosoftwareattrib",
        "-o",
        output_pattern,
    ]
    proc = run_command(args)
    elapsed = time.perf_counter() - started
    expected_outputs = [method_dir / output_name_for(frame) for frame in frames]
    produced = sorted(method_dir.glob("*.exr"))
    print(f"Finished {method_name}: {elapsed:.3f}s", flush=True)
    return {
        "method": method_name,
        "command": args,
        "returncode": proc.returncode,
        "elapsed_seconds": elapsed,
        "fps": len(produced) / elapsed if elapsed > 0 else 0,
        "stdout_tail": proc.stdout[-2000:],
        "stderr_tail": proc.stderr[-2000:],
        "input_pattern": input_pattern,
        "output_pattern": output_pattern,
        "frame_spec": frame_spec,
        "expected_count": len(expected_outputs),
        "output_count": len(produced),
        "output_bytes_total": sum(p.stat().st_size for p in produced),
        "input_bytes_total": sum(frame.stat().st_size for frame in frames),
        "size_ratio": (
            sum(p.stat().st_size for p in produced) / sum(frame.stat().st_size for frame in frames)
            if frames
            else None
        ),
    }


def frame_range_from_names(frames: list[Path]) -> tuple[str, str, str] | None:
    parsed = []
    for frame in frames:
        match = re.match(r"^(.*?)(\d+)(\.exr)$", frame.name, re.IGNORECASE)
        if not match:
            return None
        prefix, digits, suffix = match.groups()
        parsed.append((prefix, digits, suffix))

    prefixes = {p[0] for p in parsed}
    widths = {len(p[1]) for p in parsed}
    suffixes = {p[2] for p in parsed}
    if len(prefixes) != 1 or len(widths) != 1 or len(suffixes) != 1:
        return None

    numbers = [int(p[1]) for p in parsed]
    if numbers != list(range(numbers[0], numbers[0] + len(numbers))):
        return None

    prefix = parsed[0][0]
    width = len(parsed[0][1])
    source_dir = frames[0].parent
    input_pattern = str(source_dir / f"{prefix}%0{width}d.exr")
    output_pattern = f"{prefix}%0{width}d_dwaa.exr"
    frame_spec = f"{numbers[0]}-{numbers[-1]}"
    return input_pattern, output_pattern, frame_spec


def summarize_method(name: str, jobs: list[FrameJob], frame_results: list[dict], elapsed: float) -> dict:
    ok_count = sum(1 for item in frame_results if item["returncode"] == 0 and item["output_exists"])
    output_bytes_total = sum(item["output_bytes"] for item in frame_results)
    input_bytes_total = sum(job.source.stat().st_size for job in jobs)
    return {
        "method": name,
        "elapsed_seconds": elapsed,
        "fps": len(jobs) / elapsed if elapsed > 0 else 0,
        "frame_count": len(jobs),
        "ok_count": ok_count,
        "failed_count": len(jobs) - ok_count,
        "input_bytes_total": input_bytes_total,
        "output_bytes_total": output_bytes_total,
        "size_ratio": output_bytes_total / input_bytes_total if input_bytes_total else None,
        "frame_results": frame_results,
    }


def iinfo_metadata(path: Path) -> list[str]:
    proc = None
    for attempt in range(3):
        proc = run_command([str(IINFO), "-v", str(path)], timeout=10)
        if proc.returncode != 124:
            break
        time.sleep(0.2 * (attempt + 1))
    assert proc is not None
    if proc.returncode != 0:
        return [f"__IINFO_ERROR__ {proc.stderr.strip()}"]
    return normalize_metadata_lines(proc.stdout)


def normalize_metadata_lines(text: str) -> list[str]:
    lines = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(path_marker_prefixes()):
            continue
        if re.match(r"^.* : \d+ x \d+,", line):
            continue
        if re.match(r"^\d+ x \d+,", line):
            lines.append(line)
            continue
        if ":" in line:
            lines.append(line)
    return sorted(set(lines))


def path_marker_prefixes() -> tuple[str, ...]:
    return ("Reading", "Opened", "input", "filename")


def metadata_diff(source: Path, output: Path) -> dict:
    source_lines = iinfo_metadata(source)
    output_lines = iinfo_metadata(output)
    source_set = set(source_lines)
    output_set = set(output_lines)
    missing = sorted(source_set - output_set)
    added = sorted(output_set - source_set)
    unexpected_missing = [line for line in missing if not is_expected_metadata_diff(line)]
    unexpected_added = [line for line in added if not is_expected_metadata_diff(line)]
    return {
        "source": str(source),
        "output": str(output),
        "missing_count": len(missing),
        "added_count": len(added),
        "unexpected_missing_count": len(unexpected_missing),
        "unexpected_added_count": len(unexpected_added),
        "missing": missing[:200],
        "added": added[:200],
        "unexpected_missing": unexpected_missing[:200],
        "unexpected_added": unexpected_added[:200],
    }


def is_expected_metadata_diff(line: str) -> bool:
    return line.startswith(EXPECTED_METADATA_DIFF_PREFIXES)


def validate_metadata_for_method(method_result: dict, frames: list[Path], run_dir: Path) -> dict:
    method_name = method_result["method"]
    print(f"Validating metadata for {method_name}...", flush=True)
    method_dir = run_dir / method_name
    if method_result.get("skipped"):
        return {"method": method_name, "skipped": True}

    diffs = []
    for frame in frames:
        output = method_dir / output_name_for(frame)
        if not output.exists():
            continue
        diffs.append(metadata_diff(frame, output))

    return {
        "method": method_name,
        "checked_count": len(diffs),
        "frames_with_unexpected_missing": sum(1 for d in diffs if d["unexpected_missing_count"]),
        "frames_with_unexpected_added": sum(1 for d in diffs if d["unexpected_added_count"]),
        "sample": diffs[:2],
    }


def write_summary_markdown(results_path: Path, payload: dict) -> None:
    lines = [
        "# Benchmark Results",
        "",
        f"- Date: {payload['run_started']}",
        f"- Source: `{payload['source_dir']}`",
        f"- Frames: {payload['frame_count']}",
        f"- Resize: no",
        f"- OCIO/color conversion: no",
        "",
        "## Methods",
        "",
        "| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]

    validations = {item["method"]: item for item in payload["metadata_validation"]}
    for result in payload["results"]:
        if result.get("skipped"):
            lines.append(f"| {result['method']} | - | skipped | - | - | - | - |")
            continue
        validation = validations.get(result["method"], {})
        unexpected = validation.get("frames_with_unexpected_missing", 0) + validation.get(
            "frames_with_unexpected_added", 0
        )
        lines.append(
            "| {method} | {workers} | {seconds:.3f} | {fps:.2f} | {ok}/{total} | {ratio:.3f} | {unexpected} |".format(
                method=result["method"],
                workers=result.get("workers", "-"),
                seconds=result["elapsed_seconds"],
                fps=result["fps"],
                ok=result.get("ok_count", result.get("output_count", 0)),
                total=result.get("frame_count", result.get("expected_count", payload["frame_count"])),
                ratio=result.get("size_ratio", 0) or 0,
                unexpected=unexpected,
            )
        )

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- This benchmark is intentionally limited to the first frames and does not test resize yet.",
            "- Expected metadata differences currently include EXR compression and DWA compression level attributes.",
            "- Full raw data is stored next to this file as JSON.",
            "",
        ]
    )
    results_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--frames", type=int, default=10)
    parser.add_argument("--workers", type=int, nargs="*", default=[2, 4, 8])
    parser.add_argument(
        "--parallel-only",
        action="store_true",
        help="Run only Python-orchestrated parallel oiiotool methods.",
    )
    args = parser.parse_args()

    for tool in (OIIO_TOOL, IINFO, EXRHEADER, EXRMETRICS):
        if not tool.exists():
            raise FileNotFoundError(tool)

    frames = list_frames(args.source, args.frames)
    run_started = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    run_dir = OUTPUT_ROOT / run_started
    run_dir.mkdir(parents=True, exist_ok=True)

    results = []

    if not args.parallel_only:
        sequential_dir = prepare_method_dir(run_dir, "oiiotool_sequential")
        results.append(benchmark_sequential("oiiotool_sequential", make_jobs(frames, sequential_dir), convert_oiiotool))

    for workers in args.workers:
        if workers < 1:
            continue
        method = f"oiiotool_parallel_{workers}w"
        method_dir = prepare_method_dir(run_dir, method)
        results.append(benchmark_parallel(method, make_jobs(frames, method_dir), convert_oiiotool, workers))

    if not args.parallel_only:
        exrmetrics_dir = prepare_method_dir(run_dir, "exrmetrics_sequential")
        results.append(
            benchmark_sequential("exrmetrics_sequential", make_jobs(frames, exrmetrics_dir), convert_exrmetrics)
        )
        results.append(benchmark_oiiotool_frames(run_dir, frames))

    metadata_validation = [validate_metadata_for_method(result, frames, run_dir) for result in results]

    payload = {
        "run_started": run_started,
        "repo_root": str(REPO_ROOT),
        "source_dir": str(args.source),
        "frame_count": len(frames),
        "frames": [str(frame) for frame in frames],
        "cpu_count": os.cpu_count(),
        "parallel_only": args.parallel_only,
        "tools": {
            "oiiotool": str(OIIO_TOOL),
            "iinfo": str(IINFO),
            "exrheader": str(EXRHEADER),
            "exrmetrics": str(EXRMETRICS),
        },
        "results": results,
        "metadata_validation": metadata_validation,
    }

    json_path = run_dir / "benchmark_results.json"
    json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    write_summary_markdown(run_dir / "BENCHMARK_RESULTS.md", payload)
    print(json.dumps({"run_dir": str(run_dir), "json": str(json_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
