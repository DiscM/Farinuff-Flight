#!/usr/bin/env python3
"""Capture a complete candidate workload from a source tree or benchmark PCK."""

import argparse
from contextlib import ExitStack
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time

from godot_workspace import ROOT, staged_project, user_data_root
from performance_report import summarize, markdown


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def verify_build(directory: Path) -> dict:
    metadata = json.loads((directory / "build.json").read_text(encoding="utf-8"))
    if metadata.get("purpose") != "performance_benchmark":
        raise ValueError("Use a dedicated --benchmark package; shipping progress is never a benchmark profile")
    checked = set()
    for line in (directory / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines():
        digest, name = line.split("  ", 1)
        path = directory / name
        if not path.resolve().is_relative_to(directory.resolve()) or sha256(path) != digest:
            raise ValueError("Artifact checksum failed: " + name)
        checked.add(name)
    if not {"build.json", "Farinuff Flight.exe", "Farinuff Flight.pck"} <= checked:
        raise ValueError("Missing executable, pack, or metadata checksums")
    return metadata


def rss_bytes(pid: int) -> int | None:
    """Resident working set, sampled externally; never substitute system RAM."""
    try:
        if sys.platform == "win32":
            from ctypes import wintypes
            class Memory(ctypes.Structure):
                _fields_ = [("cb", wintypes.DWORD), ("faults", wintypes.DWORD)] + [(name, ctypes.c_size_t) for name in ("peak", "working_set", "paged_peak", "paged", "nonpaged_peak", "nonpaged", "pagefile", "pagefile_peak", "private")]
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.OpenProcess.restype = wintypes.HANDLE
            kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            handle = kernel.OpenProcess(0x410, False, pid)
            if not handle:
                return None
            try:
                memory = Memory()
                memory.cb = ctypes.sizeof(memory)
                query = ctypes.WinDLL("psapi").GetProcessMemoryInfo
                query.argtypes = [wintypes.HANDLE, ctypes.POINTER(Memory), wintypes.DWORD]
                return int(memory.working_set) if query(handle, ctypes.byref(memory), memory.cb) else None
            finally:
                kernel.CloseHandle(handle)
        if sys.platform.startswith("linux"):
            for line in Path(f"/proc/{pid}/status").read_text(encoding="utf-8").splitlines():
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) * 1024
            return None
        return int(subprocess.check_output(["ps", "-o", "rss=", "-p", str(pid)], text=True, stderr=subprocess.DEVNULL, encoding="utf-8").strip()) * 1024
    except (OSError, ValueError, subprocess.CalledProcessError):
        return None


def capture(command: list[str], output: Path, config_path: Path, timeout: float) -> tuple[list[dict], list[dict], dict, list[dict]]:
    events, rss, read_errors, diagnostics = [], [], [], []
    env = os.environ.copy()
    env["FARINUFF_PERFORMANCE_CONFIG"] = str(config_path)
    started = time.monotonic()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", env=env, bufsize=1)
    timings = {}
    def consume_output():
        completed = False
        with (output / "runtime.log").open("w", encoding="utf-8") as log, (output / "events.jsonl").open("w", encoding="utf-8") as records:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if line.startswith("PERFORMANCE_EVENT "):
                    try:
                        event = json.loads(line.removeprefix("PERFORMANCE_EVENT "))
                        if not isinstance(event, dict) or not isinstance(event.get("payload"), dict):
                            raise ValueError("Invalid event object")
                        event["received_ms"] = (time.monotonic() - started) * 1000
                        if event["kind"] == "cleanup":
                            event["process_rss_bytes"] = rss_bytes(process.pid)
                            (output / f"cleanup-{int(event['payload']['cycle'])}.ack").write_text("sampled\n", encoding="utf-8")
                        events.append(event)
                        records.write(json.dumps(event) + "\n")
                        records.flush()
                        if event["kind"] == "metadata":
                            timings["launch_to_metadata_ms"] = (time.monotonic() - started) * 1000
                        elif event["kind"] == "transition" and event["payload"]["cycle"] == 0:
                            timings["launch_to_" + event["payload"]["name"] + "_ms"] = (time.monotonic() - started) * 1000
                        if event["kind"] in {"stage", "cleanup", "failure"}:
                            print(event["kind"], event["payload"].get("cycle", ""), event["payload"].get("name", event["payload"].get("message", "")), flush=True)
                        if event["kind"] == "failure":
                            read_errors.append(event["payload"].get("message", "Workload failed"))
                        completed = completed or event["kind"] == "complete"
                    except (ValueError, KeyError) as error:
                        read_errors.append(str(error))
                elif line.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:")):
                    diagnostics.append({"phase": "shutdown" if completed else "workload", "message": line.strip()})
    def read_output():
        try:
            consume_output()
        except (OSError, UnicodeError, ValueError, KeyError) as error:
            read_errors.append(str(error))
    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    next_sample = started
    try:
        while process.poll() is None:
            if read_errors:
                raise ValueError("Telemetry reader failed: " + "; ".join(read_errors))
            now = time.monotonic()
            if now - started > timeout:
                raise TimeoutError("Benchmark exceeded its wall-clock timeout")
            if now >= next_sample:
                rss.append({"elapsed_ms": (now - started) * 1000, "rss_bytes": rss_bytes(process.pid)})
                next_sample = now + .5
            time.sleep(.05)
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        reader.join(timeout=10)
        if not reader.is_alive():
            process.stdout.close()
        (output / "rss.json").write_text(json.dumps(rss, indent=2) + "\n", encoding="utf-8")
    if process.returncode or read_errors or reader.is_alive():
        raise ValueError(f"Benchmark failed (exit {process.returncode}); inspect runtime.log and partial events")
    if "SCRIPT ERROR:" in (output / "runtime.log").read_text(encoding="utf-8"):
        raise ValueError("Benchmark logged a GDScript error")
    if any(d["phase"] == "workload" and d["message"].startswith("ERROR:") for d in diagnostics):
        raise ValueError("Benchmark logged a runtime error during its workload")
    return events, rss, timings, diagnostics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--godot", help="source/debug harness check")
    source.add_argument("--build", type=Path, help="directory from export_release.py --benchmark")
    parser.add_argument("--runtime", type=Path, help="explicit matching release runtime for a cross-platform local PCK check")
    parser.add_argument("--git", default="git", help="Git executable for source identity")
    parser.add_argument("--output", type=Path, required=True, help="new empty measurement directory")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--allow-background", action="store_true", help="rendered diagnostic only; allow focus loss and disqualify hardware acceptance")
    parser.add_argument("--cycles", type=int, default=3)
    parser.add_argument("--seconds", type=float, default=10)
    parser.add_argument("--warmup-seconds", type=float, default=2)
    parser.add_argument("--endless-seconds", type=float, default=60)
    parser.add_argument("--seed", type=int, default=8026)
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
    parser.add_argument("--resolution", nargs=2, type=int, default=[1280, 720])
    parser.add_argument("--power-state", default="unrecorded", help="record observed AC/battery and power mode")
    parser.add_argument("--timeout", type=float, default=900)
    args = parser.parse_args()
    if args.runtime and not args.build:
        parser.error("--runtime requires --build")
    if not 1 <= args.cycles <= 20 or not 0 < args.seconds <= 600 or not 0 < args.endless_seconds <= 3600 or not 0 <= args.warmup_seconds <= 60 or min(args.resolution) < 64 or max(args.resolution) > 16384 or not 0 < args.timeout <= 86400:
        parser.error("Invalid cycle, duration, or resolution bounds")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("Measurement directory must be new/empty; earlier evidence is retained")
    output.mkdir(parents=True, exist_ok=True)
    config = {"cycles": args.cycles, "seconds": args.seconds, "warmup_seconds": args.warmup_seconds,
              "endless_seconds": args.endless_seconds, "seed": args.seed, "quality": args.quality,
              "resolution": args.resolution, "power_state": args.power_state, "capture_path": str(output / "workload.png"), "external_cleanup_ack": True, "allow_background": args.allow_background}
    config_path = output / "config.json"
    config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    with ExitStack() as stack:
        if args.godot:
            executable = shutil.which(args.godot)
            if not executable:
                parser.error("Godot executable was not found")
            profile_parent = user_data_root()
            profile_parent.mkdir(parents=True, exist_ok=True)
            profile = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="farinuff-performance-", dir=profile_parent)))
            settings = (ROOT / "project.godot").read_text(encoding="utf-8") + '\n[application]\nrun/main_scene="res://benchmarks/candidate_performance.tscn"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(profile.name) + '\n[benchmark]\nenabled=true\n'
            project = stack.enter_context(staged_project(settings))
            command = [executable, "--path", str(project)]
            artifact = {"kind": "source_debug", "runtime_sha256": sha256(Path(executable)),
                        "commit": subprocess.check_output([args.git, "rev-parse", "HEAD"], cwd=ROOT, text=True, encoding="utf-8").strip(),
                        "working_tree_status": subprocess.check_output([args.git, "status", "--porcelain"], cwd=ROOT, text=True, encoding="utf-8").splitlines(),
                        "benchmark_sources": {p.name: sha256(p) for p in sorted((ROOT / "benchmarks").iterdir()) if p.is_file()}}
        else:
            build = args.build.resolve()
            metadata = verify_build(build)
            executable = str(args.runtime.resolve() if args.runtime else build / "Farinuff Flight.exe")
            command = [executable]
            if args.runtime:
                # Official release templates disable --main-pack. Their pack is
                # discovered beside the executable under the same basename.
                runtime_dir = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="farinuff-benchmark-runtime-")))
                packaged_runtime = runtime_dir / ("FarinuffPerformance.exe" if sys.platform == "win32" else "FarinuffPerformance")
                shutil.copy2(executable, packaged_runtime)
                shutil.copy2(build / "Farinuff Flight.pck", packaged_runtime.with_suffix(".pck"))
                command = [str(packaged_runtime)]
            artifact = {"kind": "benchmark_package", "build": metadata, "runtime_sha256": sha256(Path(executable)), "pack_sha256": sha256(build / "Farinuff Flight.pck")}
        engine = subprocess.check_output([executable, "--version"], text=True, timeout=30, encoding="utf-8").strip()
        expected_engine = json.loads((ROOT / "tools/godot_release.json").read_text(encoding="utf-8"))["engine_version"]
        if engine != expected_engine or (args.build and engine != metadata["engine"]):
            parser.error("Runtime must match the pinned engine and benchmark package")
        artifact["engine"] = engine
        command += ["--verbose"] + (["--headless"] if args.headless else [])
        (output / "artifact.json").write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
        try:
            events, rss, timings, diagnostics = capture(command, output, config_path, args.timeout)
            report = summarize(events, rss)
            if args.build and report["metadata"]["debug_build"]:
                raise ValueError("Benchmark package requires a release runtime")
            report.update({"artifact": artifact, "external_startup_timings": timings, "diagnostics": diagnostics})
        except (ValueError, TimeoutError, OSError) as error:
            (output / "failure.txt").write_text(str(error) + "\n", encoding="utf-8")
            print(str(error), file=sys.stderr)
            return 1
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (output / "report.md").write_text(markdown(report), encoding="utf-8")
    checksums = [sha256(p) + "  " + p.name for p in sorted(output.iterdir()) if p.is_file()]
    (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n", encoding="utf-8")
    print(f"Complete: {len(report['stages'])} stages; {output / 'report.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
