#!/usr/bin/env python3
"""Benchmark newly installed EXR conversion candidates."""

from __future__ import annotations

import argparse
import concurrent.futures
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_SOURCE = Path(r"T:\VFX-TEST\ERSO_000_310_FgPlate_v02")
OUTPUT_ROOT = SCRIPT_DIR / "_benchmark_output"
CONDA_TOOLS = REPO_ROOT / "LGA_EXR_Convert" / "Tools" / "conda_exrtools"
EXRMETRICS_NEW = CONDA_TOOLS / "Library" / "bin" / "exrmetrics.exe"
CONDA_PYTHON = CONDA_TOOLS / "python.exe"


def load_base_benchmark_module():
    path = SCRIPT_DIR / "benchmark_exr_to_dwaa.py"
    spec = importlib.util.spec_from_file_location("benchmark_exr_to_dwaa", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["benchmark_exr_to_dwaa"] = module
    spec.loader.exec_module(module)
    return module


BASE = load_base_benchmark_module()


@dataclass(frozen=True)
class Job:
    source: Path
    output: Path
    threads: int | None = None


def run_command(args: list[str], timeout: int = 120) -> subprocess.CompletedProcess:
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


def prepare_method_dir(run_dir: Path, method_name: str) -> Path:
    method_dir = run_dir / method_name
    if method_dir.exists():
        shutil.rmtree(method_dir)
    method_dir.mkdir(parents=True, exist_ok=True)
    return method_dir


def make_jobs(frames: list[Path], method_dir: Path, threads: int | None = None) -> list[Job]:
    return [Job(frame, method_dir / BASE.output_name_for(frame), threads) for frame in frames]


def convert_exrmetrics_new(job: Job) -> dict:
    threads = job.threads or 1
    started = time.perf_counter()
    args = [
        str(EXRMETRICS_NEW),
        "--convert",
        "-m",
        "-t",
        str(threads),
        "-z",
        "dwaa",
        "-l",
        "60",
        str(job.source),
        "-o",
        str(job.output),
    ]
    proc = run_command(args)
    elapsed = time.perf_counter() - started
    return frame_result(job, proc, elapsed)


def convert_oiio_py(job: Job) -> dict:
    started = time.perf_counter()
    args = [
        str(CONDA_PYTHON),
        str(SCRIPT_DIR / "oiio_py_convert_one.py"),
        str(job.source),
        str(job.output),
    ]
    proc = run_command(args)
    elapsed = time.perf_counter() - started
    return frame_result(job, proc, elapsed)


def frame_result(job: Job, proc: subprocess.CompletedProcess, elapsed: float) -> dict:
    return {
        "source": str(job.source),
        "output": str(job.output),
        "returncode": proc.returncode,
        "elapsed_seconds": elapsed,
        "stdout_tail": (proc.stdout or "")[-1000:],
        "stderr_tail": (proc.stderr or "")[-1000:],
        "output_exists": job.output.exists(),
        "output_bytes": job.output.stat().st_size if job.output.exists() else 0,
    }


def summarize(name: str, jobs: list[Job], results: list[dict], elapsed: float, workers: int | None = None) -> dict:
    ok_count = sum(1 for item in results if item["returncode"] == 0 and item["output_exists"])
    input_bytes_total = sum(job.source.stat().st_size for job in jobs)
    output_bytes_total = sum(item["output_bytes"] for item in results)
    payload = {
        "method": name,
        "elapsed_seconds": elapsed,
        "fps": len(jobs) / elapsed if elapsed else 0,
        "frame_count": len(jobs),
        "ok_count": ok_count,
        "failed_count": len(jobs) - ok_count,
        "input_bytes_total": input_bytes_total,
        "output_bytes_total": output_bytes_total,
        "size_ratio": output_bytes_total / input_bytes_total if input_bytes_total else None,
        "frame_results": results,
    }
    if workers is not None:
        payload["workers"] = workers
    return payload


def benchmark_exrmetrics_threadpool(run_dir: Path, frames: list[Path], threads: int) -> dict:
    method = f"exrmetrics_3411_threadpool_t{threads}"
    print(f"Running {method}...", flush=True)
    method_dir = prepare_method_dir(run_dir, method)
    outputs = [method_dir / BASE.output_name_for(frame) for frame in frames]
    started = time.perf_counter()
    args = [
        str(EXRMETRICS_NEW),
        "--convert",
        "-m",
        "-t",
        str(threads),
        "-z",
        "dwaa",
        "-l",
        "60",
        *[str(frame) for frame in frames],
        "-o",
        str(method_dir / "%04d.exr"),
    ]
    proc = run_command(args, timeout=600)
    elapsed = time.perf_counter() - started

    produced = sorted(method_dir.glob("*.exr"))
    frame_results = []
    for frame, output in zip(frames, outputs):
        actual_output = method_dir / output.name
        if not actual_output.exists() and produced:
            index = len(frame_results)
            if index < len(produced):
                actual_output = produced[index]
        frame_results.append(
            {
                "source": str(frame),
                "output": str(actual_output),
                "returncode": proc.returncode,
                "elapsed_seconds": elapsed / len(frames) if frames else elapsed,
                "stdout_tail": (proc.stdout or "")[-1000:],
                "stderr_tail": (proc.stderr or "")[-1000:],
                "output_exists": actual_output.exists(),
                "output_bytes": actual_output.stat().st_size if actual_output.exists() else 0,
            }
        )
    result = summarize(method, [Job(f, o) for f, o in zip(frames, outputs)], frame_results, elapsed, threads)
    print(f"Finished {method}: {elapsed:.3f}s", flush=True)
    return result


def benchmark_parallel_per_frame(name: str, jobs: list[Job], workers: int, fn) -> dict:
    print(f"Running {name}...", flush=True)
    started = time.perf_counter()
    with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as executor:
        results = list(executor.map(fn, jobs))
    elapsed = time.perf_counter() - started
    print(f"Finished {name}: {elapsed:.3f}s", flush=True)
    return summarize(name, jobs, results, elapsed, workers)


def validate_metadata(result: dict, frames: list[Path], run_dir: Path) -> dict:
    method = result["method"]
    print(f"Validating metadata for {method}...", flush=True)
    diffs = []
    for frame_result in result["frame_results"]:
        output = Path(frame_result["output"])
        if not output.exists():
            continue
        diffs.append(BASE.metadata_diff(Path(frame_result["source"]), output))
    return {
        "method": method,
        "checked_count": len(diffs),
        "frames_with_unexpected_missing": sum(1 for d in diffs if d["unexpected_missing_count"]),
        "frames_with_unexpected_added": sum(1 for d in diffs if d["unexpected_added_count"]),
        "sample": diffs[:2],
    }


def write_markdown(path: Path, payload: dict) -> None:
    validations = {item["method"]: item for item in payload["metadata_validation"]}
    lines = [
        "# External Tools Benchmark Results",
        "",
        f"- Date: {payload['run_started']}",
        f"- Source: `{payload['source_dir']}`",
        f"- Frames: {payload['frame_count']}",
        "- Resize: no",
        "- OCIO/color conversion: no",
        "",
        "| Method | Workers/Threads | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for result in payload["results"]:
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
                ok=result["ok_count"],
                total=result["frame_count"],
                ratio=result.get("size_ratio", 0) or 0,
                unexpected=unexpected,
            )
        )
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--frames", type=int, default=100)
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--exrmetrics-threads", type=int, nargs="*", default=[6])
    parser.add_argument("--skip-oiio-py", action="store_true")
    parser.add_argument("--skip-exrmetrics", action="store_true")
    args = parser.parse_args()

    frames = BASE.list_frames(args.source, args.frames)
    run_started = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    run_dir = OUTPUT_ROOT / run_started
    run_dir.mkdir(parents=True, exist_ok=True)

    results = []
    if not args.skip_exrmetrics:
        for threads in args.exrmetrics_threads:
            name = f"exrmetrics_3411_parallel_{args.workers}w_t{threads}"
            method_dir = prepare_method_dir(run_dir, name)
            jobs = make_jobs(frames, method_dir, threads)
            results.append(benchmark_parallel_per_frame(name, jobs, args.workers, convert_exrmetrics_new))

    if not args.skip_oiio_py:
        name = f"oiio_py_2518_parallel_{args.workers}w"
        method_dir = prepare_method_dir(run_dir, name)
        jobs = make_jobs(frames, method_dir)
        results.append(benchmark_parallel_per_frame(name, jobs, args.workers, convert_oiio_py))

    metadata_validation = [validate_metadata(result, frames, run_dir) for result in results]
    payload = {
        "run_started": run_started,
        "source_dir": str(args.source),
        "frame_count": len(frames),
        "cpu_count": os.cpu_count(),
        "tools": {
            "exrmetrics": str(EXRMETRICS_NEW),
            "conda_python": str(CONDA_PYTHON),
        },
        "results": results,
        "metadata_validation": metadata_validation,
    }

    (run_dir / "benchmark_external_tools.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    write_markdown(run_dir / "BENCHMARK_EXTERNAL_TOOLS.md", payload)
    print(json.dumps({"run_dir": str(run_dir)}, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
