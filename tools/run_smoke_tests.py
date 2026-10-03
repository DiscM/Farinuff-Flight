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

SMOKE_SCENES = (
    "autoload_smoke",
    "menu_boot_smoke",
    "frontend_navigation_smoke",
    "home_base_smoke",
    "home_base_ui_smoke",
    "native_completion_smoke",
    "expedition_progression_smoke",
    "pooling_smoke",
    "resource_cache_smoke",
    "audio_settings_smoke",
)

# Focused regression/visual checks and benchmarks are opt-in, not PR boot gates.
EXTENDED_SCENES = (
    "input_handoff_smoke",
    "recovery_decision_smoke",
    "practice_lesson_smoke",
    "reflection_mastery_smoke",
    "cohesion_smoke",
    "gameplay_refinement_smoke",
    "dev_commands_smoke",
    "in_house_vfx_smoke",
    "boss_patterns_smoke",
    "boss_flight_smoke",
    "boss_ai_smoke",
    "frontier_visual_smoke",
    "pixel_enemy_material_smoke",
    "voxel_boss_material_smoke",
    "combat_motion_smoke",
    "enemy_attack_animation_smoke",
    "enemy_flight_motion_smoke",
    "enemy_maneuver_smoke",
    "enemy_maneuver_attacks_smoke",
    "enemy_tactics_smoke",
    "enemy_advanced_tactics_smoke",
    "enemy_fsm_smoke",
    "enemy_fsm_maneuvers_smoke",
    "run_warmup_benchmark",
    "neon_cabinet_smoke",
    "background_drift_smoke",
    "combat_readability_smoke",
    "camera_transition_smoke",
    "harbor_combat_smoke",
)

SCENES = SMOKE_SCENES + EXTENDED_SCENES


def unexpected_engine_errors(output: str, scene: str) -> list[str]:
    """Allow only attributed negative tests and completion-time teardown errors."""
    completed = False
    unexpected = []
    blocks = re.split(r"(?=^\S)", output, flags=re.MULTILINE)
    for block in blocks:
        line = block.splitlines()[0] if block else ""
        if re.match(rf"^{re.escape(scene.upper())}_PASS(?:\s|$)", line):
            completed = True
        if not line.startswith("ERROR:"):
            continue
        if completed and (
            re.fullmatch(r"ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.", line)
            or re.fullmatch(r"ERROR: \d+ RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit\.", line)
        ):
            continue
        if not completed and scene == "autoload_smoke" and (
            line == "ERROR: Parse JSON failed. Error at line 0: Expected key"
            and ("(res://tests/player_trust_save_checks.gd:" in block
                 or "_check_save_manager (res://tests/autoload_smoke.gd:" in block
                 or "_check_settlement_storage (res://tests/autoload_smoke.gd:" in block)
        ):
            continue
        if not completed and scene == "frontend_navigation_smoke" and (
            (line == "ERROR: FrontendShell: unknown page id 'profile'"
             and "_check_unknown_page_rejected (res://tests/frontend_navigation_smoke.gd:" in block)
            or (line == "ERROR: FrontendShell: a modal is already open; modals are exclusive"
                and "_check_modal_exclusive_and_blocking (res://tests/frontend_navigation_smoke.gd:" in block)
        ):
            continue
        unexpected.append(line)
    return unexpected


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
    # its assertions must not count as a pass. Engine errors need explicit
    # negative-test attribution or a known completion-time teardown signature.
    if re.search(r"^SCRIPT ERROR:", output, re.MULTILINE):
        problem = problem or "Godot reported a script error"
    errors = unexpected_engine_errors(output, scene)
    if errors:
        problem = problem or "Godot reported an unexpected engine error: " + errors[0]
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
    parser.add_argument("--suite", choices=("smoke", "extended"), default="smoke",
                        help="smoke: CI essentials (default); extended: all regression scenes")
    parser.add_argument("scenes", nargs="*", help="explicit scene names override --suite")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error(f"Godot executable not found: {args.godot}")
    scenes = args.scenes or (SMOKE_SCENES if args.suite == "smoke" else SCENES)
    for scene in scenes:
        if scene not in SCENES:
            parser.error(f"unknown test scene: {scene}")
    args.log_dir.mkdir(parents=True, exist_ok=True)
    failures = [scene for scene in scenes if not run_scene(godot, scene, args.log_dir, args.timeout)]
    print(f"Smoke tests: {len(scenes) - len(failures)}/{len(scenes)} passed", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
