# Native 3D Transition Log

**Direction updated 2026-09-04:** the game is moving fully to native 3D gameplay. This document primarily records implementation changes and verified results. Earlier guidance is optional context, not a required work order. Choose work that advances the integrated 3D game.

The previous checklist and its detailed slice/approval history are available in Git history. This guide supersedes their parity, frozen-reference, parallel-runtime, and per-slice approval requirements. The current entry states implementation status; dated entries retain their original validation limits.

## 2026-09-06 — Native 3D VFX replacement (file checks only)

**Changed**

- Replaced the single first-slice feedback shape with a pooled layered native VFX unit covering core, engine, muzzle, projectile, impact, explosion, shield, boost, pickup, and charge-telegraph presentation. Each effect composes reusable meshes, animated shader bands, GPU particles, and optional height-preserving socket placement without adding gameplay nodes or per-event allocations.
- Added native core/engine glow materials to Player3D, animated the shield rim/band shader, and kept engine particles local to their sockets so yaw and boost intensity read correctly in the Combat Plane presentation.
- Added projectile-fire feedback at the manager seam for both factions, per-shot muzzle feedback at the actual player/drone sockets, impact/explosion/shield feedback for damage and ability events, and charge start/release feedback for regular enemies and all boss variants. Boss warning rings now use the native telegraph shader.
- Added a scene-owned cap of eight simultaneous OmniLight3D accents. The effect pool reports active light usage alongside pool growth, while projectiles, particles, meshes, and lights remain bounded by the existing transition warm-up.

**Inspection**

- `python3 tools/check_native_transition.py` passed for 206 source/resources and six generated GLBs. Python tool compilation and `git diff --check` passed.
- No Godot process, debugger, screenshot, or playtest was launched, following the migration guide's file-only working preference. Native-resolution readability, shader compilation, light cost, heavy-wave performance, and pool pressure remain runtime validation items.

## 2026-09-04 — Native transition implementation completed (file checks only)

This entry supersedes the interim content limits in earlier entries. The shipping paths now use one native 3D combat runtime. Completion here refers to source/content integration; engine parsing, visual acceptance, balance, and performance of these changes remain unverified.

**Gameplay and assets**

- Integrated all 13 elite abilities. Added homing steering, piercing with per-activation target deduplication, splash damage, a permanent faster magnet, a 10-second defensive burst, 2.5 seconds of triple-rate Overclock every 16 seconds, and two orbiting defensive/damage sentinels. Temporary and permanent spread now stack into a five-shot central fan. Existing twin/rear fire, hull, afterburner, and drone upgrades remain supported.
- Projectiles snapshot applicable upgrades at activation and clear them on return/reuse. Piercing recasts the current step for up to eight contacts to catch closely spaced enemies; explosions exclude the direct-hit target. Corrected player shots inheriting the enemy-only relative-player-motion sweep adjustment. Expanded bounded pools to 512 player shots, 256 enemy shots, and 96 effects; the shared idle ceiling is 512. These are capacity decisions, not measured performance results.
- Added original generated GLBs for the orbital sentinel, orbital mount, piercing module, explosive module, shock ring, and muzzle flare. The reproducible stdlib generator and asset manifest are checked in. Reused the existing butterfly module assets for the other ten upgrades, and mapped Interceptor/Bulwark loadouts to the Morpho/Monarch hulls. Modules and hull variants warm under the transition cover.
- Replaced the Tank-based boss with Assault Commander, Iron Bulwark, Tempest, Void Harbinger, and Tempest Core hulls. Bosses cycle every five encounters; the first four occupy waves 5/10/15/20. Each has distinct fan/ring/pinwheel patterns, visible charge warnings, two health thresholds, and bounded firing cadence. Later hulls carry two destructible weapon pods; destroying pods reduces volley density and removes Bulwark/Core hull resistance when both are gone. Rings leave a two-slot escape gap.
- Boss completion is deferred through the scene-owned director, clears remaining hostile shots/hazards, and preserves a pending completion across simultaneous player death/continue. Scene teardown discards that pending state.
- Enabled 3D reward-card previews for the full module catalog and selected hull. Added native engine particles and a rim/band shield shader; muzzle flashes and shock rings now use generated geometry through the existing pooled feedback API.

**Retirement**

- Removed the old `game` entry, 2D player/enemy/bullet/pickup/hazard actors, old spawners, coordinate adapter, evolution scaffolding, proxy rendering bridge, legacy dev tools, and their dependent comparison tests. Removed the obsolete screenshot tool targeting that entry. Git retains the historical implementation.
- Removed old enemy-class dependencies from the menu's model catalog, the legacy upgrade application branch, and HUD Timer-node fallback. Extracted the shared pickup enum into a dimension-independent data script. Retained 2D menus/HUD/backdrop, native review scenes, shared tuning resources, model previews, and existing art assets.
- Updated CI to retain autoload/VFX checks and use a native completion smoke scene instead of retired renderer/parity tests. The new smoke scene covers duplicate-safe upgrades, stacked spread, projectile modifiers/deduplication/reuse, and the five boss/section variants. It has been authored but not executed in this task.

**Validation performed**

- `python3 tools/check_native_transition.py` passed: project-owned resource references/IDs, six generated GLB headers and buffer ranges, 13 unique upgrade modules, native menu/retry targets, and no remaining `Area2D` combat actors. The vendored PixelPlanets standalone project is excluded from root-relative reference checks.
- Asset generation validates finite vertices and rejects degenerate or duplicate coplanar triangles; generated completion assets contain 1,640 triangles total. Python source compilation and `git diff --check` passed.
- Inspected inheritance/member names, signal wiring, pool reset paths, reward ownership, boss finish/death handling, and scene resource counts. No Godot process, debugger, gameplay test, export, or screenshot run was launched, as requested. Native CI tests, worst-case firing pressure, homing/piercing collision behavior, all reward UI combinations, and complete playthrough balance await engine validation.

## 2026-09-04 — Native elite upgrade choices (file changes only)

**Changed**

- Replaced the temporary automatic Drone Escort reward with the existing elite-choice UI, supplied with a native-only capability catalog. Each offer contains up to three unowned choices from Twin Cannons, permanent Spread Shot, Rear Gunner, Afterburner, Hull Plating, and Drone Escort. Unsupported transformations and blueprint abilities are excluded. When the supported catalog is exhausted, the reward becomes three stat points.
- Native Player now applies upgrades through an explicit, duplicate-safe method. Twin Cannons adds two shots from the left/right sockets; permanent Spread Shot enables the three-way central fan (five forward shots with Twin Cannons); Rear Gunner adds one backward shot from a new rear socket. These shots use the existing projectile request/scale/damage path. Temporary spread does not duplicate the permanent fan.
- Afterburner adds 20% normal flight speed and 15% acceleration, including drift/braking acceleration; boost distance and timing remain unchanged. Hull Plating grants one life once. Drone Escort uses the existing native escort lifecycle. Continue retains permanent upgrades; run reset clears their local state after resetting GameManager.
- Added an elite-first reward queue so simultaneous elite/stat milestones resolve serially without briefly resuming combat. Global chosen IDs are recorded only after native application succeeds. Native cards use icons and descriptions; they do not load the old ship-preview rendering path. Modular GLB upgrade visuals remain a later presentation task.
- Muzzle feedback now uses each emitted shot's position, including side and rear shots, instead of always playing at the central socket. Updated the README's reward description. This entry supersedes the automatic-reward policy in the first production-run log below.

**Inspection**

Static file checks passed for resource paths, duplicate methods, all six IDs against the shared catalog and native implementation, four muzzle nodes, reward ordering, and reset/continue call sites. Inspected popup callback ownership and duplicate-selection handling. `git diff --check` passed. No Godot launch, debugger, runtime test, or playtest was performed. Upgrade combinations, modal interaction, firing density/pool pressure, and gameplay balance remain unverified at runtime.

## 2026-09-04 — Native Fast Enemy evolution (file changes only)

**Changed**

- Added Fast-specific Generation II-IV resources: speeds 290/300/315, one base HP, 150 base points, and generation-specific 21/23/25-pixel hitbox envelopes. Existing shared difficulty/reward multipliers and per-instance generation materials still apply.
- Generation II changes weave amplitude/frequency periodically. Changes recenter the path so switching patterns does not teleport the craft; no new model or duplicated material is needed.
- Generation III checks approaching active native Player Projectiles at a throttled 0.12-second interval, sidesteps up to 44 baseline pixels, and observes a 2.5-second cooldown. Displacement chooses the side with room and trims to camera-derived bounds.
- Generation IV adds a single phase dash after a 0.4-second native mesh warning. The dash traverses up to 100 baseline pixels over 0.16 seconds with normal gameplay collision retained. Pattern changes and reactive sidesteps wait while the phase attack is in progress; leaving view during the warning or finishing the actor cancels it. Timers remain actor-owned and inherit pause/scene lifetime.
- Reused pooled boost feedback for pattern changes, sidesteps, and phase release instead of allocating sprite ghosts. The scene owns one reusable shadow-free warning mesh and shared material.
- Removed the production director's Generation I restriction for Fast enemies; all five regular roles now receive the encounter generation. This supersedes the temporary Fast restriction recorded in the first production-run entry below.

**Inspection**

Checked referenced resources, scene resource counts, the warning-node path, inherited member names, projectile velocity/group interfaces, effect-manager calls, and production generation routing. `git diff --check` passed. No Godot launch, debugger, runtime checks, or playtest was performed, per the user's instruction. Timing, collision feel, dash readability, and performance remain unverified in the running game.

**Working preference**

Continue migration through file changes and code inspection. Do not launch Godot/debugger or playtest unless the user asks. Record inspection separately from runtime validation; earlier runtime results remain historical evidence only.

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

Remaining evolution refinements and player transformation abilities, richer reward presentation, difficulty tuning, native VFX readability/performance validation, stress measurements, and dependency-aware legacy cleanup. The first native boss and elite rewards are intentional interim content, not completed equivalents of the old catalog.

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
| Player combat | Flight, boost, damage/deflection, six power-ups, all 13 elite abilities and modules, three loadout hulls | Runtime checks of elite combinations and firing pressure |
| Projectiles and pickups | Native pooled player/enemy projectiles, XP orbs, power-ups, interaction-range collision | Drop tuning and load testing |
| Enemy actors | Basic lineage; Fast Generation I-IV weave/sidestep/phase behavior; Bomber, Tank, and Sniper native wrappers | Runtime validation of Fast evolution and broader encounter tuning |
| Special attacks and hazards | Basic fragments, mines/plasma, Tank armor/double rings/overload, Sniper warnings/prediction/pooled rail; Gen IV hold extended | Heavy-encounter tuning and broader ability integration |
| Feedback | Pooled native core/engine/muzzle/projectile/impact/explosion/shield/boost/telegraph VFX, GPU particles, and capped local lights | Native-resolution readability and performance validation |
| Production flow | Native menu/retry entry, five boss variants and pods, all upgrades, allocation, continue/game-over, victory/Endless; legacy combat retired | Engine validation, encounter tuning, loading/performance profiling |

Targeted runtime checks have exercised these foundations, including damage routing, attack timing, coordinator ownership, pause behavior, reset, and pool reuse. They do not establish complete run coverage or worst-case performance.

## Validation reference (optional)

Choose checks appropriate to the change and record actual outcomes. Focus on the 3D game's intended behavior:

- Controls, aiming, movement bounds, projectile hits, damage/immunity, and special-attack behavior.
- Rewards, pickups, upgrades, encounter progression, and boss completion in an integrated run.
- Pause/resume, game over, retry, scene transitions, and cancellation of pending attacks on death/reset.
- Pool reuse, collision deactivation, coordinator release, resource lifetime, and absence of new runtime errors.
- Performance under representative heavy combat at the target output resolution.

No 2D comparison run is required. Keep known gaps visible, and update this guide as the implementation changes rather than treating each bullet as a permanent obligation.
