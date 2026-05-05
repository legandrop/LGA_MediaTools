#!/usr/bin/env python3
"""Portable EXR conversion tool for DWAA-oriented workflows."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


BASE_DIR = Path(__file__).resolve().parent
TOOLS_DIR = BASE_DIR / "Tools"
EXRMETRICS = TOOLS_DIR / "OpenEXR" / "exrmetrics.exe"
OIIOTOOL = TOOLS_DIR / "OIIO" / "oiiotool.exe"


@dataclass(frozen=True)
class ConvertOptions:
    compression: str = "dwaa"
    dwa_level: int = 60
    resize: str | None = None
    resize_filter: str | None = None
    ocio_config: str | None = None
    ocio_src: str | None = None
    ocio_dst: str | None = None
    workers: int = 6
    exrmetrics_threads: int = 6
    engine: str = "auto"
    overwrite: bool = False
    dry_run: bool = False


@dataclass(frozen=True)
class FrameTask:
    src: Path
    dst: Path


def tool_env(tool_dir: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["PATH"] = str(tool_dir) + os.pathsep + env.get("PATH", "")
    return env


def run_command(args: list[str], env: dict[str, str], timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=timeout,
        env=env,
    )


def parse_resize(value: Any) -> tuple[str | None, str | None]:
    if value is None:
        return None, None
    if isinstance(value, str):
        return value, None
    if isinstance(value, dict):
        width = value.get("width")
        height = value.get("height")
        if width and height:
            return f"{int(width)}x{int(height)}", value.get("filter")
        geometry = value.get("geometry")
        if geometry:
            return str(geometry), value.get("filter")
    raise ValueError("resize must be null, a geometry string, or an object with width/height")


def resolve_relative_path(value: str | None, base: Path) -> str | None:
    if not value:
        return None
    path = Path(value)
    if path.is_absolute():
        return str(path)
    return str(base / path)


def resolve_task_path(value: str, base: Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return base / path


def load_manifest(path: Path, cli: argparse.Namespace) -> tuple[list[FrameTask], ConvertOptions]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    manifest_dir = path.resolve().parent
    resize, resize_filter = parse_resize(data.get("resize"))
    ocio = data.get("ocio") or {}

    tasks = []
    for item in data.get("tasks", []):
        src = item.get("src")
        dst = item.get("dst")
        if not src or not dst:
            raise ValueError("Each manifest task must contain src and dst")
        tasks.append(FrameTask(resolve_task_path(src, manifest_dir), resolve_task_path(dst, manifest_dir)))

    if not tasks:
        raise ValueError("Manifest has no tasks")

    options = ConvertOptions(
        compression=cli.compression or data.get("compression", "dwaa"),
        dwa_level=cli.dwa_level if cli.dwa_level is not None else int(data.get("dwa_level", 60)),
        resize=cli.resize or resize,
        resize_filter=cli.resize_filter or resize_filter,
        ocio_config=resolve_relative_path(cli.ocio_config or ocio.get("config"), BASE_DIR),
        ocio_src=cli.ocio_src or ocio.get("src_colorspace"),
        ocio_dst=cli.ocio_dst or ocio.get("dst_colorspace"),
        workers=cli.workers or int(data.get("workers", 6)),
        exrmetrics_threads=cli.exrmetrics_threads or int(data.get("exrmetrics_threads", 6)),
        engine=cli.engine or data.get("engine", "auto"),
        overwrite=bool(cli.overwrite or data.get("overwrite", False)),
        dry_run=bool(cli.dry_run or data.get("dry_run", False)),
    )
    return tasks, options


def tasks_from_cli(cli: argparse.Namespace) -> tuple[list[FrameTask], ConvertOptions]:
    if not cli.input or not cli.output:
        raise ValueError("Use --manifest, or provide --input and --output")

    resize, resize_filter = parse_resize(cli.resize)
    tasks = [FrameTask(Path(cli.input), Path(cli.output))]
    options = ConvertOptions(
        compression=cli.compression or "dwaa",
        dwa_level=cli.dwa_level if cli.dwa_level is not None else 60,
        resize=resize,
        resize_filter=cli.resize_filter or resize_filter,
        ocio_config=resolve_relative_path(cli.ocio_config, BASE_DIR),
        ocio_src=cli.ocio_src,
        ocio_dst=cli.ocio_dst,
        workers=cli.workers or 6,
        exrmetrics_threads=cli.exrmetrics_threads or 6,
        engine=cli.engine or "auto",
        overwrite=cli.overwrite,
        dry_run=cli.dry_run,
    )
    return tasks, options


def select_engine(options: ConvertOptions) -> str:
    if options.engine != "auto":
        return options.engine
    if options.resize or options.ocio_config or options.ocio_src or options.ocio_dst:
        return "oiiotool"
    if options.compression.lower() == "dwaa":
        return "exrmetrics"
    return "oiiotool"


def validate_tools(engine: str) -> None:
    if engine == "exrmetrics" and not EXRMETRICS.exists():
        raise FileNotFoundError(f"Missing exrmetrics: {EXRMETRICS}")
    if engine == "oiiotool" and not OIIOTOOL.exists():
        raise FileNotFoundError(f"Missing oiiotool: {OIIOTOOL}")


def build_exrmetrics_command(task: FrameTask, options: ConvertOptions) -> tuple[list[str], dict[str, str]]:
    args = [
        str(EXRMETRICS),
        "--convert",
        "-m",
        "-t",
        str(options.exrmetrics_threads),
        "-z",
        options.compression,
        "-l",
        str(options.dwa_level),
        str(task.src),
        "-o",
        str(task.dst),
    ]
    return args, tool_env(EXRMETRICS.parent)


def build_oiiotool_command(task: FrameTask, options: ConvertOptions) -> tuple[list[str], dict[str, str]]:
    compression = options.compression
    if compression.lower() in {"dwaa", "dwab"}:
        compression = f"{compression}:quality={options.dwa_level}"

    args = [str(OIIOTOOL)]
    if options.ocio_config:
        args.extend(["--colorconfig", options.ocio_config])

    args.append(str(task.src))

    if options.resize:
        resize = options.resize
        if options.resize_filter:
            resize = f"{resize}:filter={options.resize_filter}"
        args.extend(["--resize", resize])

    if options.ocio_src and options.ocio_dst:
        args.extend(["--colorconvert", options.ocio_src, options.ocio_dst])
    elif options.ocio_src or options.ocio_dst:
        raise ValueError("OCIO conversion requires both ocio src and ocio dst colorspaces")

    args.extend(["--compression", compression, "--nosoftwareattrib", "-o", str(task.dst)])
    return args, tool_env(OIIOTOOL.parent)


def convert_one(task: FrameTask, options: ConvertOptions, engine: str) -> dict[str, Any]:
    started = time.perf_counter()
    if not task.src.exists():
        return frame_result(task, engine, [], 0, started, "source does not exist")
    if task.dst.exists() and not options.overwrite and not options.dry_run:
        return frame_result(task, engine, [], 0, started, "output exists; use overwrite")

    args, env = (
        build_exrmetrics_command(task, options)
        if engine == "exrmetrics"
        else build_oiiotool_command(task, options)
    )

    if options.dry_run:
        return frame_result(task, engine, args, 0, started, None, dry_run=True)

    task.dst.parent.mkdir(parents=True, exist_ok=True)
    proc = run_command(args, env=env)
    error = None if proc.returncode == 0 and task.dst.exists() else (proc.stderr or proc.stdout or "conversion failed")
    return frame_result(
        task,
        engine,
        args,
        proc.returncode,
        started,
        error,
        stdout=proc.stdout,
        stderr=proc.stderr,
    )


def frame_result(
    task: FrameTask,
    engine: str,
    command: list[str],
    returncode: int,
    started: float,
    error: str | None,
    stdout: str = "",
    stderr: str = "",
    dry_run: bool = False,
) -> dict[str, Any]:
    elapsed = time.perf_counter() - started
    return {
        "src": str(task.src),
        "dst": str(task.dst),
        "engine": engine,
        "returncode": returncode,
        "ok": error is None,
        "error": error,
        "elapsed_seconds": elapsed,
        "output_exists": task.dst.exists(),
        "output_bytes": task.dst.stat().st_size if task.dst.exists() else 0,
        "command": command,
        "stdout_tail": stdout[-2000:],
        "stderr_tail": stderr[-2000:],
        "dry_run": dry_run,
    }


def run_tasks(tasks: list[FrameTask], options: ConvertOptions) -> dict[str, Any]:
    engine = select_engine(options)
    validate_tools(engine)
    started = time.perf_counter()

    with concurrent.futures.ThreadPoolExecutor(max_workers=options.workers) as executor:
        futures = [executor.submit(convert_one, task, options, engine) for task in tasks]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]

    results.sort(key=lambda item: item["src"].lower())
    elapsed = time.perf_counter() - started
    ok_count = sum(1 for item in results if item["ok"])
    return {
        "ok": ok_count == len(results),
        "engine": engine,
        "workers": options.workers,
        "frame_count": len(results),
        "ok_count": ok_count,
        "failed_count": len(results) - ok_count,
        "elapsed_seconds": elapsed,
        "fps": len(results) / elapsed if elapsed else 0,
        "options": {
            "compression": options.compression,
            "dwa_level": options.dwa_level,
            "resize": options.resize,
            "resize_filter": options.resize_filter,
            "ocio_config": options.ocio_config,
            "ocio_src": options.ocio_src,
            "ocio_dst": options.ocio_dst,
            "exrmetrics_threads": options.exrmetrics_threads,
            "overwrite": options.overwrite,
            "dry_run": options.dry_run,
        },
        "results": results,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert EXR frames to DWAA/DWAB/other EXR compression.")
    parser.add_argument("--manifest", type=Path, help="JSON manifest with tasks and options.")
    parser.add_argument("--input", help="Single input EXR path when not using manifest.")
    parser.add_argument("--output", help="Single output EXR path when not using manifest.")
    parser.add_argument("--compression", help="Output compression. Default: dwaa.")
    parser.add_argument("--dwa-level", type=int, help="DWA quality level. Default: 60.")
    parser.add_argument("--resize", help="Resize geometry, for example 3840x2160 or 50%%.")
    parser.add_argument("--resize-filter", help="OIIO resize filter, for example lanczos3.")
    parser.add_argument("--ocio-config", help="OCIO config.ocio path.")
    parser.add_argument("--ocio-src", help="Source colorspace for --colorconvert.")
    parser.add_argument("--ocio-dst", help="Destination colorspace for --colorconvert.")
    parser.add_argument("--workers", type=int, help="Parallel frame workers. Default: 6.")
    parser.add_argument("--exrmetrics-threads", type=int, help="Threads per exrmetrics process. Default: 6.")
    parser.add_argument("--engine", choices=["auto", "exrmetrics", "oiiotool"], help="Conversion backend.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing outputs.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned work without converting.")
    parser.add_argument("--log-json", type=Path, help="Optional path for full JSON report.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        tasks, options = load_manifest(args.manifest, args) if args.manifest else tasks_from_cli(args)
        report = run_tasks(tasks, options)
        payload = json.dumps(report, indent=2)
        print(payload)
        if args.log_json:
            args.log_json.parent.mkdir(parents=True, exist_ok=True)
            args.log_json.write_text(payload + "\n", encoding="utf-8")
        return 0 if report["ok"] else 2
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
