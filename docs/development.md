# Development and validation

[Back to the project overview](../README.md)

## Tech Stack

- Engine: Godot 4.6 project format with Forward+ rendering; the menu and retry flow launch the native 3D runtime; 2D HUD and backdrop remain
- Language: GDScript 2.0 with typed scripts across gameplay systems
- Architecture: scene-based composition with reusable player, enemy, bullet, power-up, HUD, menu, and popup scenes
- Global state: autoload singletons for `GameManager`, `MetaProgression`, `SignalBus`, and `SaveManager`
- Event flow: signal-driven score, combo, life, orb meter, wave, boss, allocation, elite upgrade, settings, and game-over updates
- Rendering: procedural starfield and background layers, shader-driven CRT overlay, distortion pass, screen shake, tweens, and generated visual effects
- Persistence: local settings, score records, salvage, ship unlocks and campaign discoveries
- Build target: Windows desktop release candidates generated through the export tooling


## Native assets and checks

The earlier compact 3D combat setup is deprecated and its camera-fitting branches and separate lighting resources have been removed. `scenes/native_3d_gameplay.tscn` is the shared current runtime for Expedition, Flight School and the harbor combat variant. All use `systems/flight_space_3d_config.tres` and the home-port presentation; practice teaches the same camera, actor scale and flight speed as a normal run. `scenes/native_3d_run.tscn` remains the launch/retry entry and owns encounters and rewards. The shared scene is a combat sandbox when opened directly, not an alternate old level.

The completion asset source is `tools/generate_native_completion_assets.py`. It generates six original low-poly GLBs in `assets/models/native/`: an orbital sentinel, orbital/piercing/explosive modules, a shock ring, and a muzzle flare. Existing authored boss hulls and butterfly variants supply the rest of the fleet.

Run `python3 tools/check_native_transition.py` for resource-reference and scene-ID checks. Godot import validates the assets themselves; runtime tests exercise the shipping scenes. Static and headless checks do not establish visual quality, combat balance, or frame rate. Historical captures are development evidence rather than release acceptance.

### GitHub smoke tests

CI uses the checksum-pinned Godot 4.6.3 editor and a ten-scene smoke suite:

| Scene | Coverage |
| --- | --- |
| `autoload_smoke` | Saves, settings persistence, progression, shared pool and game state |
| `menu_boot_smoke` | Flyable home-port startup, practice service returns and legacy redirect |
| `frontend_navigation_smoke` | Pages, focus, modals, navigation and launch signals |
| `native_completion_smoke` | Shipping actors/models, upgrades, projectile reuse and boss variants |
| `expedition_progression_smoke` | Campaign persistence, rewards and assisted production journeys |
| `pooling_smoke` | Scene teardown and stale pooled references |
| `resource_cache_smoke` | Paused loading and menu/run/practice cache reuse |
| `audio_settings_smoke` | Audio controls and settings application |
| `home_base_smoke` | Station scale, six spatial services, flight, camera, pause, quitting and save isolation |
| `home_base_ui_smoke` | Home-port routing, service focus, device prompts and enlarged text layout |

Each scene must exit successfully, print its completion marker, and report no GDScript or unexpected engine errors. Intentional negative-test errors require the expected scene and test backtrace; known teardown diagnostics are allowed only after completion. Each has a 120-second timeout; failures do not skip remaining scenes. GitHub retains import and scene logs as `smoke-test-logs`. Python tooling tests run together before installing Godot.

Retired mockup showrooms are removed: their ignored preview outputs are not project dependencies. The source-text migration checker (`tests/check_native_completion.py`) is no longer a CI gate; its implementation-string assertions overlap runtime coverage. The resource checker no longer validates obsolete redesign GLBs or freezes migration-era source patterns.

To reproduce CI in a **disposable checkout**, set `GODOT_PATH` to the Godot 4.6.3 executable and run:

```sh
python3 tools/check_native_transition.py
python3 tools/check_home_base_assets.py
python3 tools/check_crescent_harbor.py
python3 -m unittest discover -s tests -p 'test_*.py'
cat tests/ci_settings.cfg >> project.godot
"$GODOT_PATH" --headless --path . --import > import.log 2>&1
cat import.log
if grep -Eq '(SCRIPT ERROR|ERROR):' import.log; then exit 1; fi
printf '\n[gui]\ntheme/custom="res://ui/themes/farinuff_frontend_theme.tres"\n' >> project.godot
python3 tools/run_smoke_tests.py --suite smoke
```

CI serializes asset imports to avoid a Godot font-import crash and disables Blender source imports: runtime scenes use checked-in GLB exports. The shipping theme is restored after its fonts import. Settings are appended directly because Godot ignores `override.cfg` during editor imports.

After importing resources, the runner also works in a development checkout without appending CI settings. It creates a temporary project and a disposable user-data directory for each scene before autoloads start. Player saves and the working `project.godot` remain untouched; temporary profiles are removed after success, failure, or timeout. The runner requires filesystem symlinks (Linux/macOS, or Windows with symlink support). Local logs are stored in `.godot/smoke-logs/`.

The default is the CI smoke suite. Focused boss behavior, VFX, material, motion, layout and backdrop tests remain available locally, along with the warmup benchmark:

```sh
python3 tools/run_smoke_tests.py --suite extended
python3 tools/run_smoke_tests.py boss_ai_smoke voxel_boss_material_smoke
```

`extended` includes all ten smoke scenes plus the focused regressions and benchmark. Explicit scene names override suite selection. Performance evidence should be collected on representative hardware, outside the PR smoke gate.

### Production release candidates

The [implementation ledger](production-implementation.md) tracks the production slices and their remaining acceptance evidence. `Release Candidate` can be dispatched in GitHub Actions or triggered with a `v*` tag. It requires the smoke suite to pass, downloads the matching verified export templates, and retains a Windows package as an artifact. It does not publish a release or update a storefront.

From a clean checkout with Godot 4.6.3 available:

```sh
python3 tools/install_release_engine.py --templates
python3 tools/export_release.py --godot "$GODOT_PATH" --output builds/windows-candidate
```

The output directory must be empty. Use `--allow-dirty` only for local development validation; the build records that state. Export uses a temporary project with serial imports and Blender imports disabled. Each artifact contains the executable/PCK, complete license files, notices, a checked PCK inventory, build version/revision, export log, and SHA-256 checksums. The gate rejects development/source-only files and missing runtime planet scenes. Authored runtime hulls under `assets/models/ships/` remain included.

Export and automated checks do not establish Windows execution, minimum hardware, commercial asset permissions, or release approval. Test install, launch, a full run, controls, quit/reopen, update, and rollback on target machines before promoting a candidate. Current headless tests retain Godot teardown diagnostics in their logs; these are not a measured memory-stability result.
