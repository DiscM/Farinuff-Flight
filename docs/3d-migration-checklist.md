# Native 3D Transition Log

**Direction updated 2026-09-04:** the game is moving fully to native 3D gameplay. This document primarily records implementation changes and verified results. Earlier guidance is optional context, not a required work order. Choose work that advances the integrated 3D game.

The previous checklist and its detailed slice/approval history are available in Git history. This guide supersedes their parity, frozen-reference, parallel-runtime, and per-slice approval requirements. Implementation progress below is not a claim that the full game has been integrated or performance-tested.

## 2026-09-04 — First integrated native production run

**Changed**

- Added `scenes/native_3d_run.tscn` and its run controller on top of the native combat scene. The normal menu launch and game-over retry now enter this scene. The menu requests its resources on a background loading thread, polls progress while remaining responsive, and retains the loaded scene through transition. Actor visuals and existing pools warm before activating the run; production starts consume the selected field supplies and apply the starting drop-pod power-up.
- Added `NativeEncounterDirector`: camera-derived edge spawns, player-distance rerolls, five enemy roles, shared threat budgets/caps, wave generation selection, and periodic pooled power-ups respecting Supply Blockade and boss nuke restrictions. Rewards and XP use the existing `GameManager`/`SignalBus` route. Fast stays Generation I until its later abilities/stats are implemented instead of inheriting Basic stats accidentally.
- Added a simplified native Siege Commander every fifth wave. It reuses the Tank hull, armor and attack behavior, holds a moving firing lane, has wave-scaled health, drives the existing boss HUD, and advances the shared run state on defeat. Contact does not remove it, and nukes spare it. This replaces the production dependency on the old 2D boss, but does not claim to implement its distinct variants or destructible sections.
- Connected stat allocation, stock-based continue with temporary immunity and pressure clearing, final game over, native retry, Wave-20 victory, and Endless continuation. The first elite reward automatically grants the implemented Drone Escort; subsequent elite rewards grant three extra stat points. The broader legacy transformation selection is not exposed as if it worked in native combat.
- Connected native power-up countdowns to the existing HUD. Hid diagnostic flight/pool readouts in production and omitted legacy-only dev spawning controls from native pause menus. Kept the menu, HUD, backdrop, and screen effects as 2D presentation.
- Fixed Fast Enemy's inherited duplicate `_time_alive` member, which prevented the combined actor graph from parsing. Extended only Generation IV Sniper hold time from six to nine seconds to allow its natural rail opportunity.
- Updated the README to describe the active native runtime and simplified content. Legacy files remain on disk; bulk cleanup is not part of this change.

**Validation**

- Godot 4.6.3 / Metal Forward+: normal menu launch reached `native_3d_run.tscn`, started encounters, and contained zero active `Area2D` nodes. All five native enemy roles spawned through the director; a kill awarded score and periodic pickup spawning used the native pool.
- Twenty Basic spawn requests respected the 12-active/12-threat cap; Escape pause and resume worked. Exercised XP-driven transition into wave five, boss health/damage/contact survival, boss defeat advancing to wave six, and paused stat allocation. Wave-ten boss defeat granted an active Drone Escort; actual popup allocation controls applied points and resumed the run.
- Wave-20 boss defeat opened the existing victory screen; Endless continuation resumed at wave 21. A lethal hit with one continue stock offered the popup, spent one stock, restored three lives and immunity, and resumed encounters. A second death without stocks opened game over, and its retry action loaded a fresh native run at wave one with score zero.
- Natural Generation IV Sniper timing produced one rail and returned it to the pool. Native rapid-fire HUD chips displayed through the new timing contract. Observed projectile/hazard pools retained zero post-warm-up growth during these bounded checks. Full 1920×1080 heavy-wave performance, cold-load timing, complete playthrough balance, and all input combinations remain unmeasured.
- Fixed the startup parse failure before rerunning. One diagnostic missed the timed continue popup and called the wrong screen; reran the death/continue/retry checks together successfully. Existing MCP bridge warnings are separate from gameplay errors. `git diff --check` passed.

**Remaining work**

Distinct native boss variants/sections, remaining Fast/evolution and player transformation abilities, richer reward presentation, difficulty tuning, VFX polish, stress/performance measurements, and dependency-aware legacy cleanup. The first native boss and elite rewards are intentional interim content, not completed equivalents of the old catalog.

## Working approach

- Develop one native 3D gameplay implementation. The old 2D actors can inform intent, but they do not need to stay runnable, synchronized, or behaviorally identical.
- Adapt movement, attack timing, balance, visuals, and architecture to make the 3D game work well. Fix inherited bugs directly instead of preserving them for parity; record meaningful gameplay changes.
- Prioritize a playable end-to-end 3D run over completing isolated actor slices or reproducing every legacy feature. Simplify or retire obsolete mechanics and migration scaffolding where appropriate.
- Remove obsolete 2D gameplay code, actors, compatibility adapters, and transitional rendering paths as their dependencies are replaced. Routine migration cleanup does not require a separate legacy-cleanup approval gate. Check references and preserve assets still used by the game; use version control for historical recovery.
- Keep useful 2D presentation: menus, HUD, backdrop, reticle, and screen-space effects can remain 2D in a fully 3D gameplay runtime.
- Continue autonomously after relevant functional checks. Visual playtesting, dedicated review scenes, manual asset approval, and a dedicated migration test suite are not required gates. Existing diagnostics are tools to use when helpful.

## Architecture to build on

These are the current defaults, not a requirement to reproduce the 2D implementation:

- Native `Camera3D`, GLB craft visuals, and Forward+ rendering at the active viewport resolution. Use the existing orthographic camera and 4× MSAA as the starting point.
- Gameplay on the X/Z plane at `Y=0`; visual height, banking, and effects live below the gameplay transform. Vertical maneuvering remains outside the current scope.
- `FlightSpace3D` owns camera projection, input conversion, and combat bounds. The existing 11-pixels-per-world-unit convention is a starting scale; avoid spreading conversion constants across actors.
- Dedicated actor wrappers own hitboxes, visuals, and stable attachment/socket hooks. Prefer simple collision geometry independent of visual meshes.
- One set of native spawners, encounter systems, and gameplay managers. Avoid carrying dual 2D/3D branches or two active combat runtimes.
- `GameManager` and `SignalBus` remain the run-state and event authorities. Use `Vector3` for world positions and `Vector2` for UI coordinates, removing legacy conversions as callers migrate.
- Reuse the existing bounded `ObjectPool` lifecycle for high-churn objects. Idle nodes are inert; reuse resets collision, transforms, timers, effects, and ownership. Keep shared resources shared.
- Load assets before first combat use and warm necessary pools during transition. Menu loading should cache resources without activating combat nodes.
- Use shared lighting and materials, restrained shadows, and pooled effects. Add more elaborate rendering or batching when it solves an observed need.
- Keep global hit-stop removed. Any future boss-defeat cinematic should be a deliberate presentation feature.

## Current implementation

| Area | Implemented foundation | Work still needed |
| --- | --- | --- |
| Rendering and flight space | Forward+, native camera/world, camera-derived bounds, input projection, retained backdrop/HUD | Output/filtering audit and loading measurements |
| Player combat | Flight, aiming, boost, firing, damage/immunity, deflection/chains, six power-up effects, Drone Escort | Remaining player transformation/upgrade assembly |
| Projectiles and pickups | Native pooled player/enemy projectiles, XP orbs, power-ups, interaction-range collision | Drop tuning and load testing |
| Enemy actors | Basic lineage; Fast, Bomber, Tank, and Sniper native wrappers | Remaining evolution abilities and integrated encounter behavior |
| Special attacks and hazards | Basic fragments, mines/plasma, Tank armor/double rings/overload, Sniper warnings/prediction/pooled rail; Gen IV hold extended | Heavy-encounter tuning and broader ability integration |
| Feedback | Pooled native placeholder effects and stable hooks | Native VFX polish where it improves combat readability |
| Production flow | Native menu/retry entry, encounter spawning, simplified boss waves, allocation, continue/game-over, victory/Endless | Broader upgrade/boss content, encounter tuning, loading/performance profiling, legacy cleanup |

Targeted runtime checks have exercised these foundations, including damage routing, attack timing, coordinator ownership, pause behavior, reset, and pool reuse. They do not establish complete run coverage or worst-case performance.

## Validation reference (optional)

Choose checks appropriate to the change and record actual outcomes. Focus on the 3D game's intended behavior:

- Controls, aiming, movement bounds, projectile hits, damage/immunity, and special-attack behavior.
- Rewards, pickups, upgrades, encounter progression, and boss completion in an integrated run.
- Pause/resume, game over, retry, scene transitions, and cancellation of pending attacks on death/reset.
- Pool reuse, collision deactivation, coordinator release, resource lifetime, and absence of new runtime errors.
- Performance under representative heavy combat at the target output resolution.

No 2D comparison run is required. Keep known gaps visible, and update this guide as the implementation changes rather than treating each bullet as a permanent obligation.
