# Farinuff Flight

A premium single-purchase native 3D arcade shooter built in Godot 4. Farinuff Flight centers on fast survival play, drift-heavy ship handling, boost-reflection combat, transformative run builds, and an authored Wave-20 Expedition that opens into optional Endless mastery.

Gameplay now runs entirely through native 3D actors, with five boss hulls, destructible boss weapon pods, all 13 elite abilities, modular ship upgrades, and pooled 3D effects. The old 2D combat runtime has been retired. Completion hardening is covered by native contract checks and a live Godot 4.6.3 scene run; target-hardware visual and performance acceptance remains a release-validation task. Changes and validation are recorded in [the transition log](docs/3d-migration-checklist.md).

![Gameplay capture](assets/readme/gameplay-capture.png)

![Elite boss fight capture 1](assets/readme/elite-boss-fight.png)

![Elite boss fight capture 2](assets/readme/elite-boss-fight-fullpower.png)

## Gameplay Mechanics

Farinuff Flight uses a taught finite Expedition followed by optional Endless play. Standard enemies spawn from the screen edges, drop XP orbs on defeat, and increase pressure as the wave count rises. XP orbs fill the wave meter, restore lives after enough collection, and advance the run toward tougher enemy mixes.

Combat uses held auto-fire with free aim support. The ship can aim with mouse movement or controller right stick input, while keyboard movement keeps the ship inside the visible playfield. Boosting adds a short high-speed dash, post-boost drift, native particle bursts, projectile deflection, and chain potential after multiple reflected shots.

The default window is 2560 × 1440, fitted to the display when necessary. Settings retains smaller window presets and fullscreen. The combat frame has 25% more width and depth, with larger voxel enemies and bosses for visible armor, reactor, and animation detail during combat. Movement and projectile speeds retain their existing world scale.

Power-ups appear during active waves and can be collected by contact or shot pickup. Current temporary effects include bullet scale increases, rapid fire, shield, spread shot, magnet, and nuke. These stack with run upgrades to create different weapon profiles across a session.

Progression adds permanent run choices at milestone moments. Every fifth cleared wave grants stat allocation points for fire rate, health, and movement speed. Native boss identities are authored at stable milestones: Assault Commander (Wave 5), Iron Bulwark (Wave 10), Tempest (Wave 15), Tempest Core (Wave 20), then Void Harbinger (Wave 25) as the first Endless revelation. Elite rewards offer up to three unowned upgrades, including homing fire, twin cannons, permanent spread, rear fire, shield bursts, overclock, permanent magnet, hull plating, afterburners, and a drone escort. Unlocked blueprints add orbitals, piercing, and explosive rounds. The cards preview the selected hull with its existing modules and the proposed addition; acquired modules also appear on the native craft. Temporary spread and permanent spread combine into a five-shot central fan.

The first launch opens Flight School, a replayable five-page briefing covering movement, boost reflection, the orb/life economy, build decisions, and the Wave-20 target. Failure uses a try-again flow before final game over. Remaining try-again stocks can continue a run, clear immediate pressure, and return the ship with temporary invincibility. Final game over records score, high score, and highest wave reached.

Runs also earn salvage — a persistent currency banked from boss kills and an end-of-run bonus based on score and waves cleared. Salvage spends in the Hangar on the title screen: tiered ship systems (starting lives, speed, fire rate, extra try-again stocks), elite blueprints that add Orbital Array, Piercing Rounds, and Explosive Rounds to the elite upgrade pool, ship variants, and challenge modifiers.

Before each run, the launch bay offers a loadout choice: pick an unlocked ship variant (the balanced Swallowtail, the fast-but-fragile Interceptor, or the slow-but-tough Bulwark) and toggle any owned challenge modifiers — faster spawns, armored enemies, no power-ups, and more — each paying a percentage bonus on all salvage earned that run. The game-over screen itemizes where the run's salvage came from.

Expedition runs are intentionally session-scoped: quitting the process or abandoning a run discards its current wave, enemies, projectiles, and in-run build. Saves retain durable progression and campaign discoveries, but an active run cannot be resumed after process exit.

## Controls

- Movement: `WASD` or `Arrow Keys`, or gamepad left stick
- Shoot: hold `Space`, gamepad `A` / right trigger
- Boost: `Shift`, gamepad `B` / left trigger
- Pause: `Escape`
- Free aim: mouse movement or gamepad right stick
- Alt controls (Settings toggle): shoot with `Left Mouse Button`, boost with `Space`

## Tech Stack

- Engine: Godot 4.6 project format with Forward+ rendering; the menu and retry flow launch the native 3D runtime; 2D HUD and backdrop remain
- Language: GDScript 2.0 with typed scripts across gameplay systems
- Architecture: scene-based composition with reusable player, enemy, bullet, power-up, HUD, menu, and popup scenes
- Global state: autoload singletons for `GameManager`, `MetaProgression`, `SignalBus`, and `SaveManager`
- Event flow: signal-driven score, combo, life, orb meter, wave, boss, allocation, elite upgrade, settings, and game-over updates
- Rendering: procedural starfield and background layers, shader-driven CRT overlay, distortion pass, screen shake, tweens, and generated visual effects
- Persistence: saved settings and high score through the save manager
- Build target: exported Windows desktop build included with the repository


## Native assets and checks

The completion asset source is `tools/generate_native_completion_assets.py`. It generates six original low-poly GLBs in `assets/models/native/`: an orbital sentinel, orbital/piercing/explosive modules, a shock ring, and a muzzle flare. Existing authored boss hulls and butterfly variants supply the rest of the fleet.

Run `python3 tools/check_native_transition.py` for file-only resource and GLB checks. CI retains autoload/VFX smoke coverage and adds `tests/native_completion_smoke.tscn` for native upgrades, projectile recycling, and boss variants. Static checks do not establish engine parsing, visual quality, combat balance, or frame rate. The gameplay screenshots above predate the completion changes.

### GitHub smoke tests

CI uses the checksum-pinned Godot 4.6.3 editor and `tools/run_smoke_tests.py` to run all 20 scenes, including frontend navigation, Expedition progression, menu boot, reward installation, backdrop drift, audio controls, and combat readability. Each scene must exit successfully, print its completion marker, and report no GDScript errors. A scene has a 120-second timeout; failures do not skip the remaining scenes, and GitHub retains their logs as the `smoke-test-logs` artifact.

To reproduce CI in a disposable checkout, set `GODOT_PATH` to the Godot 4.6.3 executable and run:

```sh
python3 tools/check_native_transition.py
python3 tests/check_native_completion.py
python3 tests/test_smoke_runner.py
python3 tests/test_release_tools.py
cat tests/ci_settings.cfg >> project.godot
"$GODOT_PATH" --headless --path . --import
python3 tools/run_smoke_tests.py
```

The CI settings serialize asset imports to avoid a Godot font-import crash and disable Blender source imports: runtime scenes use the checked-in GLB exports, so the runner does not need Blender. The workflow checks `import.log` for errors before starting the scenes and includes it in the log artifact. Settings are appended directly because Godot ignores `override.cfg` during editor imports.

After resources have been imported, the runner also works directly in a development checkout without appending CI settings. It creates a temporary project and a different disposable user-data directory for each scene, before autoloads start. Player saves and the working `project.godot` remain untouched; temporary profiles are removed after success, failure, or timeout. The runner uses filesystem symlinks (Linux/macOS, or Windows with symlink support). To run one scene, append its name, for example `python3 tools/run_smoke_tests.py dev_commands_smoke`. Local logs are stored in `.godot/smoke-logs/`.

### Production release candidates

The [implementation ledger](docs/production-implementation.md) tracks the production slices and their remaining acceptance evidence. `Release Candidate` can be dispatched in GitHub Actions or triggered with a `v*` tag. It requires the smoke suite to pass, downloads the matching verified export templates, and retains a Windows package as an artifact. It does not publish a release or update a storefront.

From a clean checkout with Godot 4.6.3 available:

```sh
python3 tools/install_release_engine.py --templates
python3 tools/export_release.py --godot "$GODOT_PATH" --output builds/windows-candidate
```

The output directory must be empty. Use `--allow-dirty` only for local development validation; the build records that state. Export uses a temporary project with serial imports and Blender imports disabled. Each artifact contains the executable/PCK, complete license files, notices, a checked PCK inventory, build version/revision, export log, and SHA-256 checksums. The gate rejects development/source-only files and missing runtime planet scenes. Authored runtime hulls under `assets/models/ships/` remain included.

Export and automated checks do not establish Windows execution, minimum hardware, commercial asset permissions, or release approval. Test install, launch, a full run, controls, quit/reopen, update, and rollback on target machines before promoting a candidate. Current headless tests retain Godot teardown diagnostics in their logs; these are not a measured memory-stability result.
