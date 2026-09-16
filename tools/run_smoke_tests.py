#!/usr/bin/env python3
"""Run the CI scenes after importing the project with the same Godot binary."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from godot_workspace import ROOT, staged_project, user_data_root

SCENES = (
    "dev_commands_smoke",
    "in_house_vfx_smoke",
    "native_completion_smoke",
    "boss_patterns_smoke",
    "boss_flight_smoke",
    "boss_ai_smoke",
    "frontier_visual_smoke",
    "pixel_enemy_material_smoke",
    "combat_motion_smoke",
    "pooling_smoke",
    "resource_cache_smoke",
    "run_warmup_benchmark",
    "autoload_smoke",
    "frontend_navigation_smoke",
    "expedition_progression_smoke",
    "menu_boot_smoke",
    "neon_cabinet_smoke",
    "background_drift_smoke",
    "audio_settings_smoke",
    "combat_readability_smoke",
)


@contextmanager
def isolated_project():
    """Reuse imported resources, but never open a player's user:// directory.

    A private project file overrides the user directory before autoload startup.
    Per-scene profiles also prevent one passing test from contaminating another.
    No override is written into the working project or its import cache.
    """
    data_root = user_data_root()
    data_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="farinuff-smoke-", dir=data_root) as profile:
        settings = (ROOT / "project.godot").read_text(encoding="utf-8")
        settings += "\n[application]\nconfig/use_custom_user_dir=true\n"
        settings += "config/custom_user_dir_name=" + json.dumps(Path(profile).name) + "\n"
        with staged_project(settings) as project:
            yield project


def run_scene(godot: str, scene: str, log_dir: Path, timeout: float) -> bool:
    print(f"=== {scene} ===", flush=True)
    log_path = log_dir / f"{scene}.log"
    problem = ""
    with log_path.open("w", encoding="utf-8") as log:
        try:
            with isolated_project() as project:
                result = subprocess.run(
                    [godot, "--headless", "--path", str(project), f"res://tests/{scene}.tscn"],
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    timeout=timeout,
                    check=False,
                )
            if result.returncode:
                problem = f"Godot exited with code {result.returncode}"
        except subprocess.TimeoutExpired:
            problem = f"timed out after {timeout:g} seconds"
        except OSError as error:
            problem = f"unable to prepare or launch isolated test: {error}"

    output = log_path.read_text(encoding="utf-8", errors="replace")
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    # Godot may return zero after a script error, and a scene that never ran
    # its assertions must not count as a pass. Shutdown diagnostics and the
    # autoload test's deliberately malformed JSON are not script failures.
    if re.search(r"^SCRIPT ERROR:", output, re.MULTILINE):
        problem = problem or "Godot reported a script error"
    if not re.search(rf"^{re.escape(scene.upper())}_PASS(?:\s|$)", output, re.MULTILINE):
        problem = problem or "missing completion marker"
    if problem:
        print(f"FAIL: {scene}: {problem} (log: {log_path})", flush=True)
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_PATH", "godot"))
    parser.add_argument("--timeout", type=float, default=120, help="seconds allowed per scene")
    parser.add_argument("--log-dir", type=Path, default=ROOT / ".godot" / "smoke-logs")
    parser.add_argument("scenes", nargs="*", help="scene names; defaults to the complete CI suite")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error(f"Godot executable not found: {args.godot}")
    scenes = args.scenes or SCENES
    for scene in scenes:
        if scene not in SCENES:
            parser.error(f"unknown CI scene: {scene}")
    args.log_dir.mkdir(parents=True, exist_ok=True)
    failures = [scene for scene in scenes if not run_scene(godot, scene, args.log_dir, args.timeout)]
    print(f"Smoke tests: {len(scenes) - len(failures)}/{len(scenes)} passed", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
