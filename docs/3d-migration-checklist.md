# Native 3D Migration Checklist

**Status**: implementation in progress; the native Generation I Basic Enemy slice is at its manual-playtest gate

This checklist tracks the migration from the current 2D gameplay runtime to a native 3D combat runtime. The existing 2D actor scenes remain frozen reference and rollback implementations until the user manually validates each 3D slice.

## Accepted constraints

- Native Top-down 3D is the target runtime.
- Combat remains on a horizontal X/Z plane; vertical maneuvering is deferred.
- Collision remains overlap-driven, using `Area3D` where appropriate.
- Visible projectiles may remain active across the plane while incoming projectile collisions are armed only within Interaction Range.
- The first 3D camera is fixed, orthographic, and near-top-down at approximately 70 degrees above the Combat Plane.
- The active game backbuffer or viewport is the native 3D output resolution; the reduced-resolution ship `SubViewport` is transitional only.
- Forward+ is the target renderer for native 3D.
- The initial world scale is 11 screen pixels per model/world unit.
- Screen right maps to world +X, screen down maps to world +Z, and world Y is reserved for visual height and effects.
- GLB models are the canonical runtime assets.
- Initial animation uses rigid model parts, procedural transforms, shaders, and limited `AnimationPlayer` tracks; richer animation is a later polish phase.
- Initial gameplay hitboxes use dedicated primitive shapes, not visual-mesh-derived collision.
- Global simulation-time hit-stop is not used. If boss-defeat slow motion is introduced later, it must be a deliberate four-second cinematic sequence that zooms in on the exploding boss rather than a subsecond whole-game time-scale jolt.
- Combat lighting uses a shared global rig and capped pooled local lights.
- Combat VFX become native 3D, but the first slice uses lightweight pooled placeholders because the current VFX are scheduled for replacement.
- The backdrop, HUD, and screen-space post-processing remain 2D initially and receive an explicit resolution audit.
- Parallel 2D/3D actor files may coexist in the repository, but both versions must never be instantiated in the same validation run.
- Gameplay parity and explicit user playtesting are required before replacing or removing the corresponding 2D implementation.
- Dedicated migration smoke tests are not required; manual scene-by-scene playtesting is the validation gate.
- Implementation must pause after every migrated scene or slice until the user explicitly approves it.

## Phase 0 — Renderer and output foundation

- [x] Preserve the current 2D runtime as the baseline.
- [x] Create the annotated Git tag `verified-2d-baseline` at commit `a4c488f8` before switching renderer settings or the active gameplay entry.
- [x] Switch the project renderer from GL Compatibility to Forward+.
- [x] Run a manual baseline playtest of the current 2D runtime under Forward+.
- [x] Resolve renderer-related regressions before building native 3D actors.
- [x] Remove the reduced-resolution 3D ship output path from the final-runtime design.
- [x] Configure native 3D rendering at a `1.0` scale against the active backbuffer or viewport resolution.
- [x] Render the native 3D validation scene directly through its `Camera3D`; do not load `ShipRenderLayer3D` or another reduced-resolution ship `SubViewport` in that scene.
- [x] Start native 3D with 4× MSAA; keep TAA/FSR2 deferred until art and performance validation.
- [ ] Audit retained 2D backdrop and HUD assets for accidental low-resolution upscaling.
- [ ] Preserve intentional pixel-art assets with explicit scale and filtering rules.
- [ ] Keep model/texture normalization and material preparation in the offline import/export pipeline rather than recomputing it at run start.
- [ ] Start background loading of first-slice Player Craft, Basic Enemy, shared Projectile, and temporary VFX resources from the menu or boot screen through the central asset catalog.
- [ ] Keep the menu responsive while polling background-load status and retain loaded resources through the scene transition.
- [ ] Cache menu-loaded resources and `PackedScene`s without instantiating active `Area3D` nodes, collision shapes, or gameplay pools in the menu.
- [ ] Wait or show loading progress if the player starts before required first-slice resources are ready.
- [ ] Warm first-slice projectile, collision-proxy, and placeholder-effect pools during the transition into the isolated native 3D gameplay scene.
- [ ] Thread-load later enemy roles and polished VFX before their first encounter; do not synchronously load new assets on first combat use.
- [ ] Measure cold-start time, first-use hitches, pool growth, and post-warm-up memory use.

### Phase 0 validation record

- Godot 4.6.3 launched the main menu and current 2D gameplay on Metal Forward+ at 1280×720 with no project runtime errors reported after the gameplay transition.
- The existing headless smoke scenes produced `PASS` in seven scenes. `enemy_evolution_shader_smoke` did not reach its pass sentinel, while `player_upgrade_3d_smoke` and `visual_upgrade_smoke` failed shared-shader identity assertions.
- The same three failures reproduce when forced back to `gl_compatibility`; they are retained baseline test/import issues rather than regressions introduced by the renderer switch.
- The user-owned Forward+ baseline playtest completed; the reported hit-stop and first-enemy-spawn issues were resolved before Phase 1 began.
- Manual baseline QA identified the legacy boss/nuke/game-over hit-stop as jittery. The shared time-scale mechanism and all of its callers were removed; the boss-defeat cinematic described above remains optional future work.
- Forward+ profiling isolated a 25–31 ms first-enemy frame to cold evolution-shader and actor setup rather than collision detection. The 2D spawner now warms that path with an inert off-plane craft before starting its timer; the measured first natural spawn fell below the 16.7 ms frame budget with no enemy-group membership, collision pair, reward, or threat-history entry from warm-up.

## Phase 1 — Native 3D flight-space foundation

- [x] Add a separate top-level native 3D gameplay scene that owns the active `Camera3D`, 3D world, pooled gameplay managers, native 3D actors, and retained `CanvasLayer` HUD.
- [x] Make each validation entry point load either the existing 2D gameplay scene or the native 3D gameplay scene, never both.
- [ ] When the first native 3D slice is ready for personal playtesting, switch the active gameplay entry directly to it; do not add an in-app 2D/3D selector.
- [x] Add the native 3D world shell without loading 2D and 3D gameplay actors together.
- [ ] Port the enemy spawner, power-up spawner, threat director, and special-attack coordinator to target native 3D scenes and pools.
- [x] Ensure the native 3D validation scene does not run the corresponding 2D coordinator implementations.
- [ ] Create a dedicated wrapper `.tscn` for each runtime craft; instantiate the wrapper from gameplay code rather than instantiating imported GLB files directly.
- [ ] Use the standard actor hierarchy inside each wrapper: `Area3D` root, sibling `CollisionShape3D`, `Visuals` `Node3D`, instanced GLB, and wrapper-owned `Attachments`/`Sockets` `Node3D` with named `Marker3D` points.
- [ ] Preserve modular player upgrade assembly as child GLB scenes attached through `Marker3D` points.
- [ ] Represent standard enemy evolution with material and modular attachment changes before authoring separate GLBs.
- [x] Add the fixed orthographic `Camera3D` and preserve the current combat framing.
- [x] Add a visual camera rig for screen shake using local camera position/rotation offsets without changing gameplay coordinates or bounds.
- [x] Centralize the 11-pixels-per-world-unit scale.
- [x] Add a scene-owned plain `FlightSpace3D` `Node` service with an active `Camera3D` reference and optional configuration `Resource`.
- [x] Keep `FlightSpace3D` free of rendering, collision, UI, autoload, and continuously running responsibilities.
- [x] Add separate adapter methods for screen positions and directional input within the same Combat Plane coordinate system.
- [x] Move mouse aiming onto the Y=0 Combat Plane through `Camera3D` ray projection.
- [x] Convert keyboard/gamepad movement through the camera's projected right/forward basis onto world X/Z without synthetic rays.
- [x] Map aim and movement direction to world-Y yaw while keeping pitch and roll visual-only.
- [x] Preserve existing InputMap action names and keyboard/gamepad semantics while converting them through `FlightSpace3D`.
- [ ] Add optional visual banking beneath the gameplay transform without rotating gameplay hitboxes.
- [ ] Normalize every actor gameplay root to `(x, 0, z)` on the Combat Plane and apply GLB centering/height corrections below `Visuals`.
- [x] Keep the aim reticle in the 2D HUD and position it from the projected native 3D aim point.
- [x] Define fixed combat-plane bounds equivalent to the current visible viewport limits.
- [x] Derive combat bounds, off-screen spawn margins, and despawn margins from the active orthographic camera projected onto `Y=0` rather than hard-coding screen-pixel rectangles.
- [x] Preserve the 16:9 baseline vertical orthographic framing, expand wider viewports horizontally, and avoid stretching native 3D models.
- [x] Configure named 3D physics layers and masks for Player Craft, Enemy Craft, Player Projectile, Enemy Projectile, Pickup, and Hostile Ordnance, preserving the existing interaction semantics.
- [ ] Add primitive gameplay hitboxes and keep them separate from GLB visual geometry.
- [ ] Use `Area3D` gameplay roots for the initial player, enemy, projectile, and pickup scenes; defer `CharacterBody3D` until solid physics is required.
- [x] Add the shared Forward+ environment, key light, ambient fill, emission, and bloom setup.
- [x] Enable moderate shadows on the shared `DirectionalLight3D` for craft depth and self-shadowing; keep routine projectiles and minor effects free of individual dynamic lights.
- [ ] Configure only Player Craft, Enemy Craft, bosses, and major 3D set pieces to cast/receive dynamic shadows; disable shadow participation for projectiles, pickups, particles, and minor effects.
- [x] Use one reusable environment/lighting configuration in each active native 3D gameplay scene, allowing only deliberate localized boss/effect overrides.
- [x] Activate the shared environment through a scene-owned `WorldEnvironment`; leave menus and 2D-only scenes outside that configuration.
- [x] Keep the existing 2D backdrop, HUD, and screen-space overlays available.
- [ ] Reuse the existing HUD, pause, game-over, allocation, upgrade, retry, and victory scenes through `CanvasLayer` integration; preserve `GameManager` and `SignalBus` as run-state authorities.
- [x] Configure the native 3D `WorldEnvironment` to use Canvas background mode where needed for selective HDR 2D/glow processing.
- [x] Route Canvas layers so backdrop processing does not unintentionally glow, blur, or grade the HUD and other UI.
- [x] Retain the existing galaxy, parallax, and celestial 2D shaders during the first 3D slice.
- [x] Defer SSAO, SSIL, SSR, volumetric fog, GI, decals, and reflection-probe treatment of the backdrop until a deliberate 3D backplate is designed and validated.
- [x] Do not add a visible 3D floor/backplate in the first slice; use craft shading and self-shadowing, deferring contact shadows and depth-aware fog.

### Phase 1 world-shell validation record

- `res://scenes/native_3d_gameplay.tscn` launched directly on Metal Forward+ at 1280×720 with 4× MSAA, scene-owned HDR 2D, the retained backdrop at Canvas layer -10, the retained HUD at layer 10, and the shared CRT/distortion passes at layers 1 and 100.
- The isolated scene contains no `SubViewport`, `Area2D`, `Area3D`, gameplay collision shape, 2D actor, or 2D coordinator. Its disabled, hidden `PoolRoot3D` remains empty until the projectile slice.
- The center viewport ray resolves to the Combat Plane origin, directional input maps right to world +X and down to world +Z, and world-to-screen HUD projection follows the active rendered camera.
- The baseline camera-derived Combat Plane is 109.35×65.45 world units. At 1920×720, it expands horizontally to 164.02 units while preserving the 65.45-unit vertical span.
- Screen shake moved only the active camera's local presentation offset; screen projection followed that rendered camera while the separate stable camera kept directional input and camera-derived Combat Plane bounds unchanged.
- The Player Projectile mask preserves the 2D interaction set while excluding its own layer, preventing projectile-to-projectile pair checks.
- HDR 2D is enabled only while the native scene is active and restores to its prior value when returning to the menu. Runtime inspection reported no project errors; the only warnings came from the temporary MCP interaction bridge.
- The complete existing 10-scene smoke suite preserved its baseline: seven scenes reached their PASS sentinel; `enemy_evolution_shader_smoke`, `player_upgrade_3d_smoke`, and `visual_upgrade_smoke` retained their three documented pre-existing failures, with no new failure introduced by this slice.
- The user explicitly approved the world-shell slice. `FoundationReference3D` was then removed when the first native craft wrapper entered the scene.

### Phase 1 Player Craft wrapper validation record

- `res://entities/player/player_3d.tscn` is the first dedicated native craft wrapper: an `Area3D` root on the Combat Plane, a separate rotated `CapsuleShape3D`, a `Visuals` pivot-correction node containing the canonical `player_butterfly.glb`, and wrapper-owned `Attachments/Sockets` plus `Modules` containers.
- The source GLB measures 3.91×4.18 world units and projects to 45.77×47.33 pixels at the 1280×720 runtime framing. Its nose points toward world -Z/screen up, its visual pivot is lifted 0.08 world units, and the mesh retains seven authored materials plus dynamic shadow casting.
- The gameplay capsule preserves the 2D 32×44-screen-pixel contact envelope under the approved runtime camera: radius 1.3668 accounts for the camera's 11.71 horizontal pixels per world unit, while height 4.0 preserves the 11-pixels-per-world-unit vertical span. The capsule is rotated onto the Combat Plane's Z axis.
- Ten wrapper-owned `Marker3D` sockets provide stable center/left/right muzzles, left/right engines, left/right upgrades, core, shield, and death/effect hooks. Imported socket coordinates were measured from the GLB and copied into the wrapper contract so gameplay does not depend on imported internal node paths.
- `res://scenes/player_3d_asset_review.tscn` uses the runtime camera, scale, lighting, environment, backdrop, and screen overlays. Its HUD projects the live collision shape through that camera instead of repeating nominal hitbox dimensions. `H` toggles the hitbox envelope and `S` toggles the color-coded socket guides without changing the wrapper.
- The native gameplay shell now contains exactly one active `Player3D` `Area3D`, one primitive `CollisionShape3D`, no `Area2D`, and no `SubViewport`. The wrapper uses Player Craft layer 1 and mask 58, stays at root Y=0, and deliberately does not join the legacy `player` group until its HUD-facing gameplay contract is ported.
- Both the asset-review scene and native gameplay shell launched on Metal Forward+ without project runtime errors. The review scene sampled at 145 FPS; controls, movement, aiming, weapons, upgrades, damage, and encounter coordinators remain outside this visual-contract slice.
- The final existing 10-scene smoke run preserved its accepted baseline: seven scenes reached their PASS sentinel; `enemy_evolution_shader_smoke`, `player_upgrade_3d_smoke`, and `visual_upgrade_smoke` reproduced only their three documented pre-existing failures.
- The user explicitly approved continuation from the Player Craft wrapper and asset-review gate. The next bounded slice adds flight controls only; combat, loading, and additional actors remain deferred.

### Phase 1 Player Craft flight-controls validation record

- `Player3D` now implements keyboard/left-stick movement, mouse/right-stick aiming, world-Y yaw, steerable boost, cooldown, post-boost drift/braking, and camera-derived boundary clamping. Existing InputMap actions remain unchanged. Weapons, damage, invulnerability, deflection/chain boosts, enemies, loading, and placeholder VFX are not part of this controls-only slice.
- Spatially independent movement, boost, drift, and aim constants live in `PlayerFlightTuning`. The 2D reference reads the same unchanged values; it is never instantiated by the native scene. `FlightSpace3D` converts baseline screen-equivalent velocities and distances through the stable camera basis, including foreshortening, while preserving analog magnitude and keeping motion independent of cursor rays or screen shake.
- At 1280×720 with speed bonuses neutralized, timed live checks measured 261.33 pixels traveled during the first second of acceleration in both cardinal and diagonal directions, a 280-pixels/second terminal speed, and half that travel/speed at half-strength input. A stationary boost covered 340.00 pixels, respected its 0.85-second cooldown, and entered the retained 0.4-second drift window. Mid-boost steering retained the 500-pixels/second speed; opposing input reduced drift speed more than coasting in a controlled 0.4-second comparison. Simulation time remained at 1×.
- Mouse aiming used the rendered camera's ray onto Y=0; the projected nose matched the cursor direction. The right-stick deadzone and left-stick analog InputMap path were exercised with input events. The retained 2D reticle is a 60-baseline-pixel facing marker projected from the Combat Plane; its pixel-art texture explicitly uses nearest filtering.
- Gameplay root Y stayed zero, with no pitch or roll. The wrapper's 45.184-baseline-pixel boundary inset preserves the reference's displayed-frame margin and scales with output resolution to keep its world-space distance fixed. Resizing from 1280×720 to 1920×720 expanded the horizontal Combat Plane without changing its vertical span or world speed; clamping refreshed from the camera on viewport resize.
- Review identified that margins also need to scale if the logical viewport height changes. Normal 1080p/1440p window resizing retains the configured 720-pixel logical height; a separate temporary runtime check exercised actual logical viewports of 1280×720, 1920×1080, and 2560×1440. All three preserved the same 101.626×57.239-world-unit movement bounds and 3.860/4.108-world-unit X/Z inset, with edge projection error below 0.001 pixel. No project stretch setting was changed.
- The existing HUD and pause menu are reused through `CanvasLayer`. Escape froze movement and cooldowns, resume restored input, Restart Run rebuilt the native scene with fresh movement/boost state, and Main Menu removed the native actor and restored the prior HDR 2D setting. The shared retry action now reloads its current gameplay scene instead of hard-coding the 2D entry.
- This non-combat review calls `GameManager.start_game(false)` so run/loadout state is initialized without spending persistent Hangar field supplies. Ordinary 2D runs retain the default consumption behavior; native combat entry must re-enable it when field supplies can actually be used.
- The native runtime still contains one `Area3D`, no `Area2D`, no `SubViewport`, no legacy `player` group member, and an empty inert pool root. The asset-review scene keeps controls disabled even if run state was previously active, preserving its static model/hitbox/socket review contract.
- Metal Forward+ runtime checks and the headless editor import completed without project script errors. No dedicated migration test scenes or harness were added; live diagnostics do not replace user acceptance.
- The final existing 10-scene regression run retained seven PASS sentinels and the same three known failures: `enemy_evolution_shader_smoke` could not complete its legacy enemy-import path, while `player_upgrade_3d_smoke` and `visual_upgrade_smoke` failed shared-shader identity checks. The balance scene still emitted its existing legacy enemy-import diagnostics despite reaching PASS. Separate Standards and Spec reviews have no outstanding findings after the viewport-inset correction.
- Save comparison caught a legacy regression-fixture side effect: 60 salvage was awarded and the normal save backup rotated. The active save was restored byte-for-byte to its pre-test hash; the backup now contains that same pre-test save. Future legacy regression runs should isolate `user://` or preserve both save files separately before execution.
- The user explicitly approved continuation from the flight-controls gate. The next bounded slice adds base Player Craft firing and pooled Player Projectiles only; enemy projectiles, Basic Enemy, damage, upgrades, menu asset loading, and production cutover remain deferred.

## Phase 2 — Pooled 3D projectiles

- [x] Add a `ProjectileManager3D` with a prewarmed Player Projectile pool.
- [x] Add the prewarmed Enemy Projectile pool and incoming-projectile policy.
- [x] Keep pooled `Area3D` Player and Enemy Projectile wrappers as the collision authority; let the manager coordinate acquisition and activation while wrappers own movement, lifetime, and swept/overlap detection.
- [x] Reuse the existing generic `ObjectPool` for 3D wrapper scenes and keep 3D-specific policy in `ProjectileManager3D` rather than duplicating pool infrastructure.
- [x] Implement the shared `pool_activate()`/`despawn()` contract for Player and Enemy Projectiles, resetting transforms, visibility, processing, collision, timers, movement, and material instance parameters on reuse.
- [x] Add a scene-owned inert `PoolRoot3D` and reparent idle pooled nodes beneath it with rendering, processing, monitoring, and collision disabled.
- [x] Reuse Player and Enemy Projectile nodes without per-shot instantiate/free churn.
- [x] Separate Player and Enemy Projectile visual state from collision state.
- [x] Keep visible projectile motion and lifetime updates active while far from the player.
- [x] Arm incoming projectile `Area3D` collision only within Interaction Range plus a speed margin.
- [x] Use hysteresis and swept-distance protection to prevent fast projectiles from tunneling through the player.
- [x] Keep Player Projectile collision active while it remains inside the visible Combat Plane bounds.
- [x] Use a primitive capsule Player Projectile hitbox with a swept-distance check for thin targets.
- [x] Flatten Player and Enemy Projectile spawn, movement, collision, and hit-event positions to `Y=0` while retaining the muzzle socket's 3D presentation height.
- [x] Share mesh, material, and shape resources within each projectile family, and the shader across both; pool wrapper nodes only.
- [ ] Pool projectile impact placeholders and avoid per-projectile dynamic lights.
- [ ] Reserve `MultiMeshInstance3D` projectile visuals for a profiling-driven optimization pass.
- [x] Instrument both projectile families' counts, armed collision shapes, executed sweeps, pool growth, projectile-step CPU time, frame/physics time, and live memory/object-count snapshots.
- [ ] Validate performance under the complete combat workload; narrow projectile-only samples do not establish the final target.
- [ ] Share native 3D meshes, textures, shaders, and base materials across compatible craft and projectile families.
- [ ] Apply evolution, palette, and damage-state variation through per-instance shader parameters or node-level overrides without mutating shared resources.
- [ ] Reuse existing compatible toon, voxel, neon, and outline shader materials as the first native 3D visual baseline.
- [ ] Import native 3D textures at appropriate target-view resolution with mipmaps and standard 3D filtering; declare nearest filtering only for intentional pixel-art textures.
- [ ] Use appropriately low-poly GLBs for the first slice and defer runtime LOD variants until profiling demonstrates geometry, shadow, or draw-call pressure.
- [ ] Preserve bounded pools for pickups, XP orbs, special-attack fragments, and transient effects in the native 3D port.
- [x] Keep Player Craft and Basic Enemy scene-managed initially; leave bosses and rare set pieces directly instantiated.
- [ ] Add regular-enemy pooling only if profiling demonstrates meaningful spawn/despawn churn savings after accounting for retained memory.

### Phase 2 Player Projectile validation record

- `res://entities/projectiles/player_projectile_3d.tscn` is the first native projectile wrapper: an `Area3D` root, a dedicated approximately 10×10-baseline-pixel capsule, a matching `ShapeCast3D`, and a low-poly emissive capsule beneath `Visuals`. All instances share one mesh, material, shader, and shape resource. The temporary visual reuses `pixel_toon_3d.gdshader`, casts no shadows, and adds no dynamic lights; polished projectile/impact VFX remain deferred.
- `ProjectileManager3D` warms 64 wrappers in batches of eight behind a transition cover before enabling controls. It uses the existing `ObjectPool`, whose optional idle parent now keeps native nodes under the scene-owned inert `PoolRoot3D`. The pool never grows on a normal or saturated firing path; a request beyond capacity is rejected and counted. Deferred returns remain checked out until reset and reparenting finish, so a same-frame request cannot allocate a replacement prematurely.
- Base firing uses the existing `shoot` action and center `Marker3D` muzzle. Spatially independent weapon constants live in `PlayerWeaponTuning`; the 2D reference reads the same unchanged values. With modifiers neutralized, held fire produced nine projectiles over two seconds (the 0.22-second timer quantizes to 14 physics ticks at 60 Hz). Travel measured 160 baseline pixels over 12 physics ticks, matching 800 pixels/second. Gamepad A and right-trigger input each fired through the unchanged InputMap.
- Active wrappers use Player Projectile layer 4 and mask 50, excluding their own layer. Sweeps target Enemy Craft and Hostile Ordnance only; Pickup overlap remains non-blocking. A temporary thin `Area3D` target placed between movement endpoints received exactly one hit, and a spawn-overlap check also emitted only one hit. Spawn, motion, and hit positions remained at Y=0. No real Enemy Craft, damage routing, rewards, or impact effects were introduced by these diagnostics.
- A 64-projectile burst armed 64 shapes with zero pool growth; the 65th request was rejected. Double despawn and a fire request during deferred return did not duplicate or allocate nodes. Reuse restored root/visual transforms, instance shader parameters, velocity, lifetime, visibility, processing, and collision state. Bounds exit, out-of-bounds spawn, six-second fallback expiry, and viewport-resize bounds refresh all returned nodes correctly. Idle nodes had monitoring, monitorability, layers, shapes, physics processing, and visibility disabled.
- The transition's render warmup initially waited for `frame_post_draw`, which can stop arriving when macOS fully covers the game window. A live restart diagnostic reproduced a stuck loading cover with 64 allocated nodes and no draw events. Warmup now performs one transition-only `RenderingServer.force_draw(false)` before returning nodes. The same pause/restart check passed with the normal render loop deliberately disabled, and the actual pause-menu restart also completed normally. No permanent diagnostic harness or migration smoke suite was added.
- A controlled post-warmup first activation started at zero fired projectiles, took 154 microseconds on the local Metal Forward+ run, allocated no new projectile node, and caused no additional canvas/draw/mesh/surface/specialization pipeline compilation. A separate 64-active-projectile sample measured at most 1.229 ms of summed projectile-step CPU time. These narrow development samples do not establish the final 1080p combat performance target; full-scene frame-time and cold-start acceptance remain manual gates.
- Escape froze projectile motion, lifetime, and firing cooldown with no extra shots; resume restored them. Restart created a fresh 64-node pool and removed the previous scene's nodes. Main Menu freed all native projectile nodes, left no active native group or `Area3D`, and restored HDR 2D. The static Player Craft asset-review scene kept controls and its firing timer disabled even with run state temporarily active.
- The native gameplay scene contains one Player Craft plus 64 pooled `Area3D` wrappers, with no `Area2D`, `SubViewport`, legacy projectile-group member, or 2D gameplay coordinator. The retained HUD includes active/armed/pool-growth counters and firing instructions. Live Metal Forward+ checks ended with no project runtime errors; temporary MCP bridge warnings are not gameplay errors.
- Separate Standards and Spec reviews found no issues in this bounded slice. The full existing 10-scene regression run retained seven PASS sentinels and the same three documented failures: `enemy_evolution_shader_smoke` did not complete its legacy enemy-import path; `player_upgrade_3d_smoke` and `visual_upgrade_smoke` failed shared-shader identity checks. The balance scene still emitted its existing enemy-import diagnostics despite reaching PASS. Tests ran against a temporary mirrored project with a verified, distinct `user://` profile; both live save files retained their pre-test SHA-256 hash (`6c70248833464a39995ee83a6754d4836ab3cc33daebe9b21577284ecc992f5f`).
- The user explicitly approved continuation from the Player Projectile gate. The next bounded slice adds pooled Enemy Projectiles, Interaction Range, and a manual incoming-volley review only; Basic Enemy, damage, deflection, menu loading, VFX polish, and production cutover remain deferred.

### Phase 2 Enemy Projectile validation record

- Both wrapper scenes now use `Projectile3D`, renamed from the player-only script with its resource UID preserved. The existing cyan Player Projectile visual and collision behavior are retained. `res://entities/projectiles/enemy_projectile_3d.tscn` adds an approximately 8×8-baseline-pixel capsule, matching `ShapeCast3D`, and a temporary low-poly orange emissive sphere. Each family shares one mesh, material, and shape; both reuse the existing toon shader. No projectile lights, impact effects, or polished VFX were introduced.
- `ProjectileManager3D` warms 64 wrappers per family in batches of eight, then performs one covered render warmup for both families. All 128 idle nodes belong to the gameplay scene's disabled `PoolRoot3D`; the existing `ObjectPool` remains the only node cache. Each family has an independent capacity and counters. Saturating both pools, requesting a 65th projectile, and requesting a replacement during deferred return produced no pool growth. A returned enemy wrapper reused the same instance ID and restored its transforms, shader parameters, visibility, processing, collision, sweep state, velocity, and lifetime.
- `EnemyProjectileTuning.DEFAULT_SPEED` preserves the existing 400-pixels/second value in both runtimes. The initial 74-baseline-pixel Interaction Range reads the unchanged boost-response radius from `PlayerFlightTuning`; native boost deflection itself is still deferred. The shared `ProjectileInteractionRange3D` takes one player-position/motion snapshot after Player Craft movement and before projectile steps, using the stable flight-space metric. It adds one relative-motion step as a speed margin and 16 pixels of hysteresis.
- A stationary enemy projectile remained visible and active with its shape, layers, monitoring, and sweep disabled at 200 pixels. It armed at 73, stayed armed at 80, disarmed at 91, remained disarmed on returning to 80, and rearmed at 73. A distant moving projectile traveled 80.00002 baseline pixels in 12 physics ticks, matching 400 pixels/second, without performing sweeps. Losing the target disabled collision without stopping the projectile's visual/lifetime lifecycle.
- Enemy Projectiles use layer 8 and mask 1, with sweeps targeting only Player Craft. An armed projectile crossed temporary Enemy Craft, Pickup, and Player Projectile shapes without being absorbed. A 12,000-pixels/second diagnostic crossing, a player moved across a stationary projectile between physics samples, and a spawn-overlap case each reported exactly one contact. All hit events stayed at Y=0. The retained Player Projectile sweep still hit a temporary thin Enemy Craft target exactly once while ignoring an intervening Pickup. These temporary runtime probes added no permanent fixtures, real enemies, or damage behavior.
- Off-bounds activation, boundary exit, viewport narrowing, and six-second fallback expiry returned enemy wrappers to the inert pool. Range/bounds checks remained consistent at 1280×720 and 1920×1080 window output and at a wider 1600×720 aspect; normal 1080p output retains the project's configured 720-pixel logical canvas height. The static Player Craft asset-review scene remained motionless with controls and its firing timer disabled, even when run state and input were temporarily active.
- In a 16-tick local Metal Forward+ sample, 64 distant enemy projectiles performed zero sweeps and used at most 376 microseconds of summed projectile-step CPU time; moving all 64 within range enabled 64 sweeps and measured at most 1,155 microseconds. A post-warmup first activation on the final code took 291 microseconds, reused a warmed node, and added no canvas/draw/mesh/surface/specialization pipeline compilations. The resumed-window sample still included a 41.9 ms frame interval: these narrow diagnostics do not certify stutter-free cold start or the full 1080p combat target. Godot's process/physics monitors report recent maxima, not instantaneous projectile cost.
- Standards and Spec reviews both identified the same telemetry issue: summing independent family peaks overstated simultaneous activity. The corrected manager records actual active counts on activation, excluding pending returns. Separate 64-player then 64-enemy bursts now report an aggregate peak of 64; an overlapping 64-enemy/32-player burst reports 96. Both review axes have no remaining findings after the correction and its live verification.
- `res://scenes/projectile_3d_review.tscn` composes the actual native gameplay scene with seven-lane incoming volleys. `1` fires the normal 400-pixels/second volley, `2` fires a deliberate 6× collision-stress volley, `V` toggles automatic volleys, and `H` toggles the base-range/hysteresis guides. The UI counts contacts only and explicitly states that damage and deflection are absent. The 6× setting belongs only to manual review and does not change enemy balance. The base native gameplay scene has no incoming-volley emitter.
- Escape froze active projectile positions, lifetimes, review input, and the volley timer. Resume restored activity. The actual Restart Run button rebuilt both pools and freed all 128 old nodes; the transition also completed with the normal render loop deliberately disabled, preserving the covered-window warmup fix. The actual Main Menu button freed all native projectiles and actors, removed the native gameplay group, unpaused the tree, and restored HDR 2D. The review scene contained 129 `Area3D` nodes, no `Area2D`, no `SubViewport`, and no legacy player-group member. Runtime checks reported no project errors; temporary MCP/probe warnings are not gameplay errors.
- The full existing 10-scene regression run retained seven PASS sentinels and the same three known failures: `enemy_evolution_shader_smoke` did not complete its legacy enemy-import path; `player_upgrade_3d_smoke` and `visual_upgrade_smoke` failed shared-shader identity checks. The balance scene still emitted its known enemy-import diagnostics despite reaching PASS. Tests used a temporary mirrored project with a verified, distinct `user://` profile. Both live save files retained SHA-256 `6c70248833464a39995ee83a6754d4836ab3cc33daebe9b21577284ecc992f5f`. No new automated migration suite was added.
- **Manual gate:** run `res://scenes/projectile_3d_review.tscn` directly. Check orange incoming-projectile readability, movement/boost through normal and fast volleys, stable arming near the range guides, continued Player Projectile firing, boundary cleanup, and pause/restart. Confirm the pool-growth counter stays at zero; contacts should increment without health loss or deflection. Implementation pauses here for explicit approval before Basic Enemy, native damage/deflection, menu loading, VFX, or another migration slice. The main gameplay entry remains unchanged.

### Phase 2 Enemy Projectile approval record

- The user's 2026-08-28 continuation approves moving past the Enemy Projectile gate. This next bounded slice covers the Generation I Basic Enemy wrapper, straight movement, receiving Player Projectile damage, and kill/contact/despawn lifecycle. Player damage/deflection, rewards/orbs, later-generation abilities, other enemies, VFX, menu asset loading, and production cutover remain deferred.

## Phase 3 — Player/BasicEnemy vertical slice

- [x] Scope the first native 3D validation scene to Player Craft, Basic Enemy, and their pooled Projectiles only.
- [x] Keep all other enemy roles, bosses, and unported gameplay actors outside the first 3D validation scene.
- [x] Create the final `Player3D` scene with a gameplay body, primitive hitbox, `Visuals` `Node3D`, GLB model, sockets, and VFX hooks.
- [x] Use existing GLB mockups for the first slice where polished replacement models are not yet ready.
- [x] Keep polished GLB replacements drop-in compatible with the established wrapper, origin, material, and `Marker3D` socket contracts.
- [x] Keep first-slice gameplay animation control in wrapper-local `AnimationPlayer`/procedural transforms; treat imported GLB animations as optional visual inputs rather than gameplay dependencies.
- [x] Create a dedicated 3D asset-review scene using runtime scale, orientation, lighting, materials, sockets, and relevant animation presentation.
- [ ] Obtain manual asset approval in the review scene before swapping a polished replacement into a validated gameplay slice.
- [x] Port player controls, movement tuning, aim, rotation, boost/drift, and boundaries.
- [x] Port base Player Craft firing through the center socket into the pooled Player Projectile manager; weapon upgrades remain deferred.
- [ ] Port player damage, invulnerability, and projectile-dependent boost deflection/chain behavior.
- [x] Share base Player flight/weapon tuning, base Projectile damage, Generation I Basic Enemy stats, and spawn/despawn margins with the 2D reference.
- [ ] Migrate the remaining shared upgrade, evolution, damage, and encounter data as their dependent actors are ported.
- [x] Keep first-slice 3D-specific scene references, model scale, sockets, primitive hitboxes, and visual parameters in native 3D scenes or dedicated 3D resources.
- [x] Emit native Projectile hit and Basic Enemy finish events with canonical `Vector3` combat positions at `Y=0`.
- [ ] Migrate position-bearing gameplay signals to canonical `Vector3` combat positions with `Y=0`.
- [ ] Add temporary 2D boundary conversions for the reference scene and remove them during final 2D gameplay cleanup; keep UI layout coordinates as `Vector2`.
- [x] Create the `BasicEnemy3D` wrapper with its native Generation I gameplay and visual structure.
- [x] Port Generation I Basic Enemy straight movement, damage reception, nonlethal hit flash, death, unrewarded player contact, and directional boundary despawn. Generation I has no shooting attack.
- [ ] Port later Basic Enemy generation targeting, charge timing, and fragment release.
- [ ] Port Basic Enemy score rewards, XP orbs, and death effects.
- [x] Connect pooled player and enemy projectiles to native 3D hit detection; Player damage and deflection remain separate pending work above.
- [ ] Add lightweight pooled placeholder muzzle, impact, death, and boost effects.
- [ ] Implement first-slice placeholders with pooled `GPUParticles3D` for repeated trails/sparks and primitive mesh bursts for discrete flashes/impacts, attached through stable `Marker3D` effect hooks.
- [ ] Run the complete manual user-validation checklist.
- [ ] Pause implementation and wait for explicit user approval before continuing.
- [ ] Record explicit user acceptance before production cutover or legacy cleanup.

### Phase 3 Generation I Basic Enemy validation record

- `res://entities/enemies/basic_enemy_3d.tscn` is a scene-managed `Area3D` with a dedicated `BoxShape3D`, `Visuals/BasicHullGLB`, and wrapper-owned `Attachments/Sockets` markers for MuzzleCenter, EngineLeft, EngineRight, Core, and Death. The existing Basic Enemy GLB is unchanged. Its imported socket nodes are visual-source data, not gameplay dependencies. Breathing affects `Visuals` only; combat roots and finish-event positions stay on `Y=0`.
- `basic_enemy_generation_1.tres` is the shared source of 1 HP, 150 baseline-pixels/second, and 100 base points. The reference Gen I stage and native wrapper both use it; other reference generation values remain unchanged. Shared spawn/despawn margins remain 80/60 baseline pixels, and base Player Projectile damage remains 1 plus `GameManager.bonus_damage`. Points are authored for future reward routing but are not awarded in this review.
- The primitive is authored for the shared 70-degree camera. Its X/Z cross-section projects to 26×26 baseline pixels at all four cardinal headings; the box stays world-aligned while the hull and sockets face the entry direction. This preserves Gen I's cardinal square envelope, not an arbitrary-angle steering contract for future generations.
- Four authored shared surface overrides reuse the current Gen I corrupted-void shader and palette. No mesh-derived hitbox, material duplication, GLB normalization, proxy catalog, or extra local light is created at spawn. Per-instance shader time and flash isolate enemy feedback; native materials disable global shader-time animation while the reference materials keep their unchanged default clock.
- `res://scenes/basic_enemy_3d_review.tscn` composes the actual `Native3DGameplay` controller. It adds deterministic cardinal entries, an eight-enemy cap, hitbox/socket guides, and destroyed/contact/escaped counters. Gen I does not fire; the already warmed Enemy Projectile pool is idle. Other enemy roles, 2D gameplay actors, and ship `SubViewport` proxies are absent. The earlier projectile-only review still loads without real enemy actors.
- The first enemy is scene-authored, visible but inert during transition: no collision layer, monitoring, physics processing, or active enemy group. A live reload with the ordinary render loop disabled reached readiness on frame 33 through the existing forced transition draw, then activated the same enemy instance. Subsequent enemies are directly instantiated and freed; they are not pooled. Full menu-threaded asset loading remains pending.
- Godot 4.6.3 imported and inspected both new scenes successfully. Live Metal/Forward+ checks confirmed 1-HP normal hits from all four headings, a surviving 24-pixel off-center miss, and one kill from a 12,000-pixels/second diagnostic crossing. Player firing through the actual input/controller/pool path also destroyed an enemy. Repeated damage/contact callbacks emitted only one finish event. Each outgoing edge cleaned up once, and offscreen incoming actors survived until entry. Player contact removed the enemy without changing lives or score; no rewards or orbs were created.
- A temporary wave-41 diagnostic preserved the reference's two-step health rounding and capped late-game speed: 2 HP and 195 baseline-pixels/second. A nonlethal hit flashed only that enemy while its material resources remained shared. Escape pause froze movement, breathing, shader time, and hit flash; resume/restart worked. The actual Restart Run button rebuilt this review with reset counters and 64+64 projectile nodes. Main Menu restored non-HDR UI, unpaused the tree, and removed native actors/managers. Inspection mistakes in temporary runtime probes were discarded; the clean restarted run reported no gameplay errors. MCP's generated bridge still reports its own shadowing/enum warnings.
- **Performance remains an open gate.** Eight warmed spawns measured 0.146 ms median and 2.016 ms maximum for instantiate/add/activate, with zero new pipeline compilations across all five tracked categories and zero projectile-pool growth. Short 180-frame debug samples at 1280×720 measured 10.015 ms median / 10.745 ms p95 with eight enemies, versus 9.996 / 11.482 ms without enemies. At an image-readback-confirmed 1920×1080, eight enemies measured 22.145 / 26.145 ms versus 20.010 / 25.168 ms without enemies; neither held 60 FPS. Reported physics maxima were 1.123 ms with enemies and 0.281 ms without. These are local debug observations, not a worst-wave/boss benchmark or evidence that final performance acceptance is complete. Use captured image dimensions when verifying output: `ViewportTexture.get_size()` overstated the 1920×1080 capture as 2880×1620 in this session.
- Independent Standards and Spec reviews against turn-start commit `e461ee3f5f9321280b2c5ab9f704bdc595426a64` reported zero findings on each axis. The existing ten-scene regression suite ran once with a verified isolated save profile. Seven scenes reported PASS; `balance_ttk_smoke` still printed its known legacy `BaseEnemy` import errors despite PASS. `enemy_evolution_shader_smoke` again produced no PASS before the frame cap, while `player_upgrade_3d_smoke` and `visual_upgrade_smoke` reproduced their known shared-shader identity failures. Expected save-corruption checks and existing exit-resource warnings remain. No dedicated migration test suite or permanent diagnostic fixture was added. Logs are retained outside the repo at `/private/tmp/farinuff-basic-enemy-regression.x90Os0`; live save and backup hashes remained unchanged.
- **Manual gate:** run `res://scenes/basic_enemy_3d_review.tscn` directly. Check Gen I silhouette/color, cardinal facing, movement, hitbox and socket alignment, firing hits/misses, contacts, cleanup, pause, and restart. Keys **1–4** spawn from top/right/bottom/left, **V** toggles automatic entries, **H** toggles hitboxes, and **G** toggles sockets; flight/fire/boost controls are unchanged. Destroyed, contact, and escape counters should each reflect their own outcome once; score and lives deliberately do not change. Explicit user acceptance is still required before the next slice. Player damage/deflection, rewards/orbs, later generations, VFX, menu loading, production cutover, legacy cleanup, and the 1080p 60-FPS acceptance gate remain open.

## Phase 4 — Remaining gameplay actor migration

- [ ] Port the remaining standard enemy roles one at a time using the 2D implementation as a frozen behavior reference.
- [ ] Port powerups, XP orbs, drones, mines, armor plates, hazards, and special attack sections to native 3D scenes.
- [ ] Port boss phases and destructible sections after the standard enemy roles pass validation.
- [ ] Port evolution and upgrade state onto the native 3D actor implementation.
- [ ] Add authored `AnimationPlayer` tracks only where procedural animation cannot express the required behavior.
- [ ] Validate each dependent scene as a complete 3D slice; never mix active 2D and 3D gameplay actors.
- [ ] Obtain explicit user playtest acceptance for each slice.
- [ ] Pause implementation after each scene or slice until explicit user approval is received.

## Phase 5 — Native 3D VFX replacement

- [ ] Replace the temporary placeholder combat VFX with the planned native 3D VFX set.
- [ ] Add polished core, engine, muzzle, projectile, impact, explosion, shield, boost, and boss telegraph effects.
- [ ] Use pooled `GPUParticles3D`, meshes, shaders, and capped local lights where appropriate.
- [ ] Preserve the stable effect and socket interfaces used by migrated actors.
- [ ] Validate visual readability at native output resolution and Forward+ lighting.
- [ ] Obtain explicit user approval for the replacement VFX.

## Phase 6 — Cutover and cleanup

- [ ] Confirm the full native 3D runtime meets gameplay parity.
- [ ] Confirm the full manual validation checklist has passed for every migrated scene.
- [ ] Confirm 60 FPS at 1920x1080 during the worst-case enemy wave and boss attack.
- [ ] Confirm no visible pool-growth hitching or hot-path allocation spikes after warm-up.
- [ ] Switch the production game flow to the native 3D actor scenes.
- [ ] Remove obsolete 2D actor scenes and migration-only adapters only after explicit user approval.
- [ ] Remove the transitional ship `SubViewport` and compatibility proxy path once no longer referenced.
- [ ] Retain the intentionally 2D backdrop, HUD, and screen-space post-processing.
- [ ] Update project documentation and mark this checklist complete.
