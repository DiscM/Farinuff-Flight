#!/usr/bin/env python3
"""File-only contract for the production bomber hazard seam.

The runtime smoke scene is responsible for exercising the encounter director
with a live native run. This check keeps the wiring contract obvious even on
machines where Godot is not installed: both production spawn paths must inject
the scene-owned hazard manager into bomber actors, and the bomber must request
mines through the manager's bounded API.
"""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FAILURES: list[str] = []
CHECKS = 0


def require(condition: bool, message: str) -> None:
    global CHECKS
    CHECKS += 1
    if not condition:
        FAILURES.append(message)


def read(relative_path: str) -> str:
    path = ROOT / relative_path
    require(path.is_file(), f"missing required file: {relative_path}")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def source_section(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    end_index = source.find(end, start_index + len(start))
    return source[start_index:end_index] if start_index >= 0 and end_index >= 0 else ""


def main() -> int:
    director = read("systems/native_encounter_director.gd")
    bomber = read("entities/enemies/bomber_enemy_3d.gd")
    hazards = read("systems/native_hazard_manager_3d.gd")
    gameplay_scene = read("scenes/native_3d_gameplay.tscn")

    for spawn_path in ("spawn_enemy", "dev_spawn_archetype"):
        section = source_section(director, f"func {spawn_path}(", "\n\nfunc ")
        require(section, f"encounter director must expose {spawn_path}()")
        require(
            "if actor is BomberEnemy3D" in section,
            f"{spawn_path}() must branch on the native bomber actor",
        )
        require(
            "actor.configure_hazard_manager(gameplay.hazard_manager)" in section,
            f"{spawn_path}() must inject gameplay.hazard_manager into bombers",
        )

    require("func configure_hazard_manager" in bomber, "bomber must expose the hazard injection seam")
    require("generation >= 2" in bomber and "_hazard_manager.spawn_mine(" in bomber, "Gen II-IV bombers must request mines through the injected manager")
    require('func spawn_mine(' in hazards, "hazard manager must expose the pooled mine API")
    require('_checked_out_mines.size() >= _warmed_mine_ids.size()' in hazards, "mine checkout must reject pool saturation")
    require('path="res://systems/native_hazard_manager_3d.gd"' in gameplay_scene, "gameplay scene must own the native hazard manager")

    if FAILURES:
        print("NATIVE_BOMBER_PRODUCTION_CONTRACT_FAIL")
        for failure in FAILURES:
            print(f"- {failure}")
        return 1

    print(f"NATIVE_BOMBER_PRODUCTION_CONTRACT_PASS: {CHECKS} file-only assertions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
