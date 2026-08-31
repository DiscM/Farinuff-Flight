# Implementation Profile: Godot 2D

Status: reference implementation in this repository

## Scope and fidelity

- Engine: Godot 4.6.x
- Presentation: Node2D top-down arcade playfield
- Reference entry: `ui/main_menu.tscn` → `scenes/game.tscn`
- Source implementation: the verified 2D baseline in the repository
- This profile is a starting point for a clean rebuild, not a prescription to reproduce every historical migration artifact.

## Simulation ownership

- `GameManager` owns score, combo, lives, wave progression, boss state, allocation, run finalization, and run-scoped tuning.
- `MetaProgression` owns Salvage, catalog data, purchases, loadout selections, modifiers, consumables, milestones, and lifetime statistics.
- `SaveManager` owns persistent serialization and settings.
- `SignalBus` carries cross-system events.
- `ObjectPool` and `AudioManager` provide shared reuse and presentation services.
- Gameplay actors are reusable scenes with scripts; UI listens to events rather than becoming the source of truth.

## Coordinate and camera mapping

- Use the reference 1280×720 display as the baseline design-unit space.
- Map design units directly to the 2D virtual canvas or through a documented scale policy.
- Keep gameplay bounds independent from decorative background sizing.
- Use `Area2D` and dedicated `CollisionShape2D` proxies for gameplay contacts.

## Input and UI

- Portable actions map to Godot InputMap actions: `move_left`, `move_right`, `move_up`, `move_down`, `shoot`, `boost`, and `pause`.
- Default bindings are WASD/arrows, Space, Shift, and Escape, with controller equivalents.
- Menus, HUD, and popups use Control/CanvasLayer surfaces.
- Pause freezes the scene tree or equivalent simulation state without consuming the resume input.

## Presentation and assets

- The current 2D reference uses transparent four-frame sprite strips, procedural effects, shaders, CRT/distortion layers, and tweens.
- Stable portable IDs should map through a catalog rather than becoming direct dependencies on filenames.
- Visual modules must not alter collision shapes unless the portable specification changes.
- Audio routes through independent music and SFX buses with rate-limited pooled players.

## Persistence

- Current reference location: `user://save_data.json`.
- Current reference also keeps a temporary file and last-known-good backup.
- Current schema version: 2, with compatibility handling for version 1 and missing-version saves.
- Persisted categories include high score, settings, Salvage, unlock levels, ship/modifier selections, consumables, milestones, and lifetime statistics.

## Verification

- Headless smoke scenes live under `tests/` and run in CI through `.github/workflows/smoke_tests.yml`.
- Use the cross-engine scenarios in `../09-acceptance-tests.md` as the portable test contract.
- Add a deterministic full-run harness before treating this profile as a complete clean rebuild.
