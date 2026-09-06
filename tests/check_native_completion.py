#!/usr/bin/env python3
"""File-only checks for the native 3D completion/migration contract.

This checker intentionally reads source, scenes, and resources only. It does
not invoke Godot; the companion native_completion_smoke.tscn contains the
deterministic runtime assertions used by CI when Godot is available.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NATIVE_RUN = "res://scenes/native_3d_run.tscn"
NATIVE_GAMEPLAY = "res://scenes/native_3d_gameplay.tscn"

UPGRADE_IDS = [
    "twin_cannons",
    "spread_shot_elite",
    "rear_gunner",
    "afterburner",
    "hull_plating",
    "drone_escort",
    "auto_aim",
    "shield_burst",
    "magnet_field",
    "overclock",
    "orbitals",
    "piercing",
    "explosive_rounds",
]

ARCHETYPES = ("basic", "fast", "bomber", "tank", "sniper")
GENERATION_NUMBERS = (1, 2, 3, 4)
FAILURES: list[str] = []
CHECKS = 0


def require(condition: bool, message: str) -> None:
    global CHECKS
    CHECKS += 1
    if not condition:
        FAILURES.append(message)


def read(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.is_file():
        FAILURES.append(f"missing required file: {relative_path}")
        return ""
    return path.read_text(encoding="utf-8")


def exists(relative_path: str) -> bool:
    path = ROOT / relative_path
    require(path.is_file(), f"missing required resource: {relative_path}")
    return path.is_file()


def require_all(relative_path: str, source: str, needles: list[tuple[str, str]]) -> None:
    for label, needle in needles:
        require(needle in source, f"{relative_path}: missing {label}")


def extract_array(source: str, constant_name: str) -> list[str]:
    match = re.search(
        rf"const\s+{re.escape(constant_name)}\b[^=]*=\s*\[(.*?)\]",
        source,
        re.DOTALL,
    )
    if not match:
        require(False, f"missing array constant: {constant_name}")
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def source_section(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    end_index = source.find(end, start_index + len(start))
    if start_index < 0 or end_index < 0:
        return ""
    return source[start_index:end_index]


def check_native_entry_and_transitions() -> None:
    project = read("project.godot")
    menu = read("ui/main_menu.gd")
    game_over = read("ui/game_over.gd")
    retry = read("ui/try_again_popup.gd")
    run = read("scenes/native_3d_run.gd")
    victory = read("ui/expedition_victory.gd")
    manager = read("autoloads/game_manager.gd")
    signals = read("autoloads/signal_bus.gd")
    resource_cache = read("autoloads/resource_cache.gd")

    require(
        'run/main_scene="res://ui/main_menu.tscn"' in project,
        "project main scene must remain the native-capable menu",
    )
    require_all(
        "ui/main_menu.gd",
        menu,
        [
            ("native run path", f'const NATIVE_RUN_PATH := "{NATIVE_RUN}"'),
            ("Play handler", "func _on_play_pressed()"),
            ("launch-bay handoff", "_open_launch_bay()"),
            ("bounded native cache prime", "ResourceCache.prime_scene(NATIVE_RUN_PATH)"),
            ("cache-backed native polling", "ResourceCache.is_scene_ready(NATIVE_RUN_PATH)"),
            ("native packed-scene transition", "get_tree().change_scene_to_packed(_native_run_scene)"),
        ],
    )
    require(
        'ResourceCache="*res://autoloads/resource_cache.gd"' in project,
        "project must register the bounded root-scene cache",
    )
    require_all(
        "autoloads/resource_cache.gd",
        resource_cache,
        [
            ("root-scene allowlist", "const CACHEABLE_SCENES: PackedStringArray"),
            ("bounded scene budget", "const MAX_CACHED_SCENES := 2"),
            ("threaded scene request", 'ResourceLoader.load_threaded_request(path, \"PackedScene\", true)'),
            ("asynchronous wait", "func wait_for_scene(path: String) -> PackedScene"),
        ],
    )
    require_all(
        "ui/game_over.gd",
        game_over,
        [
            ("retry handler", "func _on_retry_pressed()"),
            ("native retry scene", f'change_scene_to_file("{NATIVE_RUN}")'),
            ("menu handler", "func _on_menu_pressed()"),
            ("menu return scene", 'change_scene_to_file("res://ui/main_menu.tscn")'),
        ],
    )
    require(exists("ui/main_menu.tscn"), "native menu scene must exist")
    require('name="PlayButton" type="Button"' in read("ui/main_menu.tscn"), "menu must expose a Play button")
    require('name="RetryButton" type="Button"' in read("ui/game_over.tscn"), "game over must expose retry")
    require(not (ROOT / "scenes/game.tscn").exists(), "retired 2D gameplay entry must stay absent")

    require_all(
        "scenes/native_3d_run.gd",
        run,
        [
            ("Try Again scene", 'const TRY_AGAIN := preload("res://ui/try_again_popup.tscn")'),
            ("Game Over scene", 'const GAME_OVER := preload("res://ui/game_over.tscn")'),
            ("allocation scene", 'const ALLOCATION := preload("res://ui/point_allocation_popup.tscn")'),
            ("elite reward scene", 'const ELITE_REWARD := preload("res://ui/elite_upgrade_popup.tscn")'),
            ("victory scene", 'const VICTORY := preload("res://ui/expedition_victory.tscn")'),
            ("game-over signal route", "SignalBus.game_over.connect(_end_run)"),
            ("allocation signal route", "SignalBus.allocation_triggered.connect(_queue_allocation)"),
            ("elite signal route", "SignalBus.elite_upgrade_triggered.connect(_queue_elite_reward)"),
            ("victory signal route", "SignalBus.expedition_completed.connect(_show_victory)"),
            ("stock branch", "if GameManager.try_again_stocks > 0:"),
            ("try-again accept route", "popup.try_again_accepted.connect(_revive)"),
            ("try-again decline route", "popup.try_again_declined.connect(_show_game_over.bind(score), CONNECT_DEFERRED)"),
            ("finalize on game over", "GameManager.finalize_run()"),
            ("allocation queue", "_allocation_queue.append(points)"),
            ("available native upgrades", "var choices := NativeUpgrades.available()"),
            ("allocation dequeue", "_allocation_queue.pop_front()"),
            ("reward completion", "_show_next_reward.call_deferred()"),
            ("victory result", "screen.show_result(wave)"),
            ("endless route", "screen.continue_endless.connect(_continue_endless)"),
            ("victory menu route", "screen.return_to_menu.connect(_return_to_menu)"),
            ("continue call", "GameManager.continue_into_endless()"),
            ("victory menu transition", 'get_tree().change_scene_to_file("res://ui/main_menu.tscn")'),
        ],
    )
    require_all(
        "ui/try_again_popup.gd",
        retry,
        [
            ("accepted signal", "signal try_again_accepted"),
            ("declined signal", "signal try_again_declined"),
            ("stock consumption", "GameManager.try_again_stocks -= 1"),
            ("loadout life restore", "GameManager.lives = GameManager.starting_lives"),
            ("revive activation", "GameManager.is_game_active = true"),
            ("accepted emission", "try_again_accepted.emit()"),
            ("declined emission", "try_again_declined.emit()"),
        ],
    )
    require_all(
        "ui/expedition_victory.gd",
        victory,
        [
            ("endless signal", "signal continue_endless"),
            ("menu signal", "signal return_to_menu"),
            ("single-resolution guard", "var _resolved := false"),
            ("continue emission", "continue_endless.emit()"),
            ("menu emission", "return_to_menu.emit()"),
        ],
    )
    require_all(
        "autoloads/signal_bus.gd",
        signals,
        [
            ("allocation signal", "signal allocation_triggered(points: int)"),
            ("elite signal", "signal elite_upgrade_triggered"),
            ("victory signal", "signal expedition_completed(final_wave: int)"),
            ("game-over signal", "signal game_over(final_score: int)"),
        ],
    )

    require("const FINAL_EXPEDITION_WAVE: int = 20" in manager, "finite campaign must end at wave 20")
    require_all(
        "autoloads/game_manager.gd",
        manager,
        [
            ("final wave completion flag", "expedition_completed = true"),
            ("final wave pauses gameplay", "is_game_active = false"),
            ("final wave advances endless cursor", "current_wave = FINAL_EXPEDITION_WAVE + 1"),
            ("victory emission", "SignalBus.expedition_completed.emit(FINAL_EXPEDITION_WAVE)"),
            ("continuation guard", "if not expedition_completed:"),
            ("continuation activation", "is_game_active = true"),
            ("continuation clears flag", "expedition_completed = false"),
            ("continuation wave event", "SignalBus.wave_started.emit(current_wave)"),
        ],
    )


def check_native_scene_graph() -> None:
    gameplay_scene = read("scenes/native_3d_gameplay.tscn")
    run_scene = read("scenes/native_3d_run.tscn")
    gameplay_script = read("scenes/native_3d_gameplay.gd")
    presentation_settings = read("effects/rendering/native_3d_presentation_settings.tres")
    director = read("systems/native_encounter_director.gd")

    require('instance=ExtResource("1")' in run_scene, "native run must instance the native gameplay scene")
    require(NATIVE_GAMEPLAY in run_scene, "native run scene must point at native gameplay")
    require('rewards_enabled = true' in run_scene, "production native run must enable rewards")
    require('consume_field_supplies = true' in run_scene, "production native run must consume field supplies")
    require_all(
        "scenes/native_3d_gameplay.tscn",
        gameplay_scene,
        [
            ("native player scene", 'path="res://entities/player/player_3d.tscn"'),
            ("3D world", '[node name="World3D" type="Node3D" parent="."]'),
            ("3D actor root", '[node name="Actors3D" type="Node3D" parent="World3D"]'),
            ("native player mount", '[node name="Player3D" parent="World3D/Actors3D" instance=ExtResource("9_player")]'),
            ("projectile container", '[node name="Projectiles3D" type="Node3D" parent="World3D"]'),
            ("pickup container", '[node name="Pickups3D" type="Node3D" parent="World3D"]'),
            ("power-up container", '[node name="PowerUps3D" type="Node3D" parent="World3D"]'),
            ("effect container", '[node name="Effects3D" type="Node3D" parent="World3D"]'),
            ("hazard container", '[node name="Hazards3D" type="Node3D" parent="World3D"]'),
            ("pool root", '[node name="PoolRoot3D" type="Node3D" parent="World3D"]'),
            ("projectile manager", 'path="res://systems/projectile_manager_3d.gd"'),
            ("hazard manager", 'path="res://systems/native_hazard_manager_3d.gd"'),
        ],
    )
    require_all(
        "scenes/native_3d_gameplay.gd",
        gameplay_script,
        [
            ("native Player3D preload", 'preload("res://entities/player/player_3d.gd")'),
            ("native projectile preload", 'preload("res://entities/projectiles/projectile_3d.gd")'),
            ("native enemy preload", 'preload("res://entities/enemies/basic_enemy_3d.gd")'),
            ("native actor root", '@onready var actors_root: Node3D = $World3D/Actors3D'),
            ("presentation monitor registration", 'Performance.add_custom_monitor(monitor_name, Callable(self, method_name))'),
            ("presentation metric sampling", "_sample_presentation_frame_timing()"),
            ("presentation pool metrics", "_cache_presentation_pool_metrics("),
        ],
    )
    require_all(
        "effects/rendering/native_3d_presentation_settings.tres",
        presentation_settings,
        [
            ("64-effect budget", "effect_pool_size = 64"),
            ("16-effect warm batch", "effect_warm_batch_size = 16"),
            ("four-light budget", "max_local_effect_lights = 4"),
        ],
    )
    require(not re.search(r"res://(?:scenes/game\.tscn|entities/player/player\.tscn)", gameplay_scene + gameplay_script), "native gameplay must not reference legacy combat scenes")

    expected_director_scenes = {
        '"basic": preload("res://entities/enemies/basic_enemy_3d.tscn")',
        '"fast": preload("res://entities/enemies/fast_enemy_3d.tscn")',
        '"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn")',
        '"tank": preload("res://entities/enemies/tank_enemy_3d.tscn")',
        '"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn")',
        '"boss": preload("res://entities/enemies/boss_enemy_3d.tscn")',
    }
    for scene_reference in expected_director_scenes:
        require(scene_reference in director, f"encounter director missing {scene_reference}")
    require("Area2D" not in director, "encounter director must remain native-only")

    native_actor_scenes = [
        "entities/player/player_3d.tscn",
        "entities/player/player_drone_3d.tscn",
        "entities/enemies/basic_enemy_3d.tscn",
        "entities/enemies/fast_enemy_3d.tscn",
        "entities/enemies/bomber_enemy_3d.tscn",
        "entities/enemies/tank_enemy_3d.tscn",
        "entities/enemies/sniper_enemy_3d.tscn",
        "entities/enemies/boss_enemy_3d.tscn",
        "entities/projectiles/player_projectile_3d.tscn",
        "entities/projectiles/enemy_projectile_3d.tscn",
        "entities/collectibles/xp_orb_3d.tscn",
        "entities/powerups/power_up_3d.tscn",
        "entities/enemies/seeker_fragment_3d.tscn",
        "entities/enemies/enemy_mine_3d.tscn",
        "entities/enemies/plasma_field_3d.tscn",
        "entities/enemies/enemy_rail_beam_3d.tscn",
    ]
    for relative_path in native_actor_scenes:
        scene = read(relative_path)
        root_match = re.search(r'^\[node name="[^"]+" type="([^"]+)"', scene, re.MULTILINE)
        require(root_match is not None and root_match.group(1) == "Area3D", f"{relative_path}: native actor root must be Area3D")
        require("Area2D" not in scene and "CharacterBody2D" not in scene, f"{relative_path}: legacy 2D actor marker")
        require("_3d.gd" in scene, f"{relative_path}: native actor must use a 3D script")

    smoke_scene = read("tests/native_completion_smoke.tscn")
    require(NATIVE_GAMEPLAY in smoke_scene, "native completion smoke must instance native gameplay")
    require("tests/native_completion_smoke.gd" in smoke_scene, "native completion smoke script must be attached")


def check_upgrades_and_projectiles() -> None:
    catalog = read("entities/player/native_player_upgrades.gd")
    player = read("entities/player/player_3d.gd")
    visuals = read("entities/player/native_upgrade_visuals.gd")
    manager = read("systems/projectile_manager_3d.gd")
    projectile = read("entities/projectiles/projectile_3d.gd")
    game_manager = read("autoloads/game_manager.gd")
    smoke = read("tests/native_completion_smoke.gd")

    ids = extract_array(catalog, "SUPPORTED_IDS")
    require(ids == UPGRADE_IDS, "native supported upgrade IDs must be the exact 13-ID catalog")
    require(len(ids) == 13 and len(set(ids)) == 13, "native supported upgrade IDs must be unique")

    all_upgrades = source_section(game_manager, "const ALL_UPGRADES", "const META_ELITE_UPGRADES")
    meta_upgrades = source_section(game_manager, "const META_ELITE_UPGRADES", "## Returns the elite upgrade pool")
    game_manager_ids = re.findall(r'"id":\s*"([a-z_]+)"', all_upgrades + meta_upgrades)
    require(sorted(game_manager_ids) == sorted(UPGRADE_IDS), "GameManager and native upgrade catalogs must agree")

    module_section = source_section(visuals, "const MODULES", "const ORBITAL")
    module_ids = re.findall(r'^\s*"([a-z_]+)":\s*preload\(', module_section, re.MULTILINE)
    require(sorted(module_ids) == sorted(UPGRADE_IDS), "every native upgrade must have one visual module")
    require("_elite_upgrades[upgrade_id] = true" in player, "successful native upgrades must be recorded locally")
    require("not NativeUpgrades.SUPPORTED_IDS.has(upgrade_id) or has_elite_upgrade(upgrade_id)" in player, "native upgrade application must reject unsupported/duplicate IDs")
    require("_upgrade_visuals.set_upgrade(upgrade_id, true)" in player, "native upgrade application must update visuals")
    require("_elite_upgrades.clear()" in player and "func reset_elite_upgrades()" in player, "native upgrade reset must clear local state")

    require_all(
        "entities/player/player_3d.gd",
        player,
        [
            ("elite spread gate", 'has_elite_upgrade("spread_shot_elite")'),
            ("temporary/elite spread stack", 'if has_spread_shot and has_elite_upgrade("spread_shot_elite")'),
            ("outer spread angles", "angles.append_array([-deg_to_rad(30.0), deg_to_rad(30.0)])"),
            ("twin cannon shots", 'has_elite_upgrade("twin_cannons")'),
            ("rear gunner shots", 'has_elite_upgrade("rear_gunner")'),
        ],
    )
    require_all(
        "systems/projectile_manager_3d.gd",
        manager,
        [
            ("homing snapshot", 'projectile.homing = _player.has_elite_upgrade("auto_aim")'),
            ("piercing snapshot", 'projectile.piercing = _player.has_elite_upgrade("piercing")'),
            ("explosive snapshot", 'projectile.explosive = _player.has_elite_upgrade("explosive_rounds")'),
            ("saturation guard", "pool.checked_out.size() >= pool.warmed_ids.size()"),
            ("growth metric", '"pool_growth_after_warmup": pool.pool_growth'),
        ],
    )
    require(projectile.count("piercing = false") >= 2, "projectile activation and return must both clear piercing")
    require(projectile.count("explosive = false") >= 2, "projectile activation and return must both clear explosive")
    require(projectile.count("homing = false") >= 2, "projectile activation and return must both clear homing")
    require_all(
        "tests/native_completion_smoke.gd",
        smoke,
        [
            ("13-ID runtime loop", "supported.size() == 13"),
            ("duplicate application", "Duplicate rejected: "),
            ("five-direction runtime check", "size() == 5"),
            ("three-direction runtime check", "size() == 3"),
            ("stacked projectile flags", "shot.homing and shot.piercing and shot.explosive"),
            ("same-instance pool reuse", "recycled.get_instance_id() == configured_projectile_id"),
            ("modifier reset", "not recycled.homing and not recycled.piercing and not recycled.explosive"),
        ],
    )


def check_bosses_and_generations() -> None:
    boss_script = read("entities/enemies/boss_enemy_3d.gd")
    boss_scene = read("entities/enemies/boss_enemy_3d.tscn")
    basic_script = read("entities/enemies/basic_enemy_3d.gd")
    smoke = read("tests/native_completion_smoke.gd")

    titles = extract_array(boss_script, "TITLES")
    expected_titles = [
        "ASSAULT COMMANDER",
        "IRON BULWARK",
        "TEMPEST",
        "VOID HARBINGER",
        "TEMPEST CORE",
    ]
    require(titles == expected_titles, "boss titles must preserve all five ordered variants")
    require("% TITLES.size()" in boss_script, "boss variant selection must wrap over the five-title catalog")
    require("for index in visuals.get_child_count():" in boss_script, "boss activation must select one visible hull")
    require("section.activate" in boss_script and "section.deactivate" in boss_script, "boss sections must activate/deactivate per variant")
    require("func _active_section_count()" in boss_script, "boss must expose active section accounting")
    require(len(re.findall(r'parent="Visuals" instance=ExtResource\("model\d+"\)', boss_scene)) == 5, "boss scene must contain five hull model variants")
    require(boss_scene.count('script = ExtResource("2")') == 2, "boss scene must contain two destructible section scripts")
    require('name="Left" type="Area3D"' in boss_scene and 'name="Right" type="Area3D"' in boss_scene, "boss scene must expose left/right sections")
    require_all(
        "tests/native_completion_smoke.gd",
        smoke,
        [
            ("five boss loop", "for index in 5"),
            ("wave-driven variant", "(index + 1) * 5"),
            ("variant assertion", "boss.variant == index"),
            ("section destruction", "boss._sections[0].take_damage(99999)"),
            ("remaining section assertion", "boss._active_section_count() == 1"),
        ],
    )

    require(len(re.findall(r'preload\("res://entities/enemies/basic_enemy_generation_[1-4]\.tres"\)', basic_script)) == 4, "basic native lineage must preload four basic generation resources")
    require("func _get_generation_stats()" in basic_script, "native enemies must resolve generation resources through one seam")
    for archetype in ARCHETYPES:
        actor_path = f"entities/enemies/{archetype}_enemy_3d.tscn"
        actor = read(actor_path)
        require(f"res://entities/enemies/{archetype}_enemy_generation_1.tres" in actor, f"{actor_path}: generation I resource not wired")
        require("gameplay_stats = ExtResource(\"3_stats\")" in actor, f"{actor_path}: gameplay_stats must be resource-backed")
        for generation in GENERATION_NUMBERS:
            resource_path = f"entities/enemies/{archetype}_enemy_generation_{generation}.tres"
            resource = read(resource_path)
            require("script_class=\"EnemyGenerationStats\"" in resource, f"{resource_path}: wrong resource class")
            require('path="res://entities/enemies/enemy_generation_stats.gd"' in resource, f"{resource_path}: missing stats script")
            require("max_health = " in resource, f"{resource_path}: missing max_health")
            require("move_speed = " in resource, f"{resource_path}: missing move_speed")
            require("base_points = " in resource, f"{resource_path}: missing base_points")


def check_bounded_pools() -> None:
    manager_paths = [
        "systems/projectile_manager_3d.gd",
        "systems/native_effect_manager_3d.gd",
        "systems/xp_orb_manager_3d.gd",
        "systems/power_up_manager_3d.gd",
        "systems/native_hazard_manager_3d.gd",
    ]
    pool_manager_sources = {path: read(path) for path in manager_paths}
    for path, source in pool_manager_sources.items():
        require("ObjectPool.acquire(" in source, f"{path}: native pool must acquire through ObjectPool")
        require("func get_metrics()" in source, f"{path}: native pool must expose metrics")
        require('"pool_growth_after_warmup"' in source, f"{path}: native pool must expose growth telemetry")
        require("warm_" in source, f"{path}: native pool must warm before use")
        require("clear_" in source, f"{path}: native pool must expose reset/clear behavior")
        require("@export_range" in source, f"{path}: pool capacity must be bounded by an export range")
        require("size() >=" in source, f"{path}: active checkout must have a saturation guard")

    projectile = pool_manager_sources["systems/projectile_manager_3d.gd"]
    require("pool.checked_out.size() >= pool.warmed_ids.size()" in projectile, "projectile pool must reject saturation")
    hazard = pool_manager_sources["systems/native_hazard_manager_3d.gd"]
    require("_checked_out_rails.is_empty()" in hazard, "major hazard pool must reject a second rail")
    object_pool = read("autoloads/object_pool.gd")
    require("const MAX_IDLE_PER_SCENE := 512" in object_pool, "ObjectPool must cap retained idle nodes")
    require("bucket.size() >= MAX_IDLE_PER_SCENE" in object_pool, "ObjectPool must free idle overflow")

    gameplay = read("scenes/native_3d_gameplay.gd")
    require('"pool_growth_after_warmup"' in gameplay and "GROWTH %d" in gameplay, "native HUD/test telemetry must surface pool growth")
    smoke = read("tests/native_completion_smoke.gd")
    require("_check_pool_contract()" in smoke, "native smoke must exercise bounded pool metrics")


def main() -> int:
    check_native_entry_and_transitions()
    check_native_scene_graph()
    check_upgrades_and_projectiles()
    check_bosses_and_generations()
    check_bounded_pools()

    if FAILURES:
        print("NATIVE_COMPLETION_CONTRACT_FAIL")
        for failure in FAILURES:
            print(f"- {failure}")
        return 1

    print(f"NATIVE_COMPLETION_CONTRACT_PASS: {CHECKS} file-only assertions")
    print("PASS: native entry/graph, 13 upgrades, stacked modifiers, five bosses, generations, transitions, and bounded pools")
    return 0


if __name__ == "__main__":
    sys.exit(main())
