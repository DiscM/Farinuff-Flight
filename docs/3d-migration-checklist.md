# Native 3D Migration Checklist

**Status**: implementation in progress; the Player Craft wrapper is at its manual asset-review gate

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
- [ ] Move mouse aiming onto the Y=0 Combat Plane through `Camera3D` ray projection.
- [ ] Convert keyboard/gamepad movement through the camera's projected right/forward basis onto world X/Z without synthetic rays.
- [ ] Map aim and movement direction to world-Y yaw while keeping pitch and roll visual-only.
- [ ] Preserve existing InputMap action names and keyboard/gamepad semantics while converting them through `FlightSpace3D`.
- [ ] Add optional visual banking beneath the gameplay transform without rotating gameplay hitboxes.
- [ ] Normalize every actor gameplay root to `(x, 0, z)` on the Combat Plane and apply GLB centering/height corrections below `Visuals`.
- [ ] Keep the aim reticle in the 2D HUD and position it from the projected native 3D aim point.
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
- This Player Craft wrapper and asset-review scene now require explicit user approval before controls, asset loading, projectiles, Basic Enemy, or another migrated scene is implemented.

## Phase 2 — Pooled 3D projectiles

- [ ] Add a `ProjectileManager3D` with prewarmed player and enemy projectile pools.
- [ ] Keep pooled `Area3D` projectile wrappers as the first-slice collision authority; let the manager coordinate acquisition, activation, lifetime, movement where practical, and collision arming.
- [ ] Reuse the existing generic `ObjectPool` for 3D wrapper scenes and keep 3D-specific policy in `ProjectileManager3D` rather than duplicating pool infrastructure.
- [ ] Require pooled 3D objects to implement `pool_activate()`/`despawn()` and reset transforms, visibility, processing, collision, timers, movement, material parameters, and effect state on reuse.
- [ ] Add a scene-owned inert `PoolRoot3D` and reparent idle pooled nodes beneath it with rendering, processing, monitoring, and collision disabled.
- [ ] Reuse projectile nodes without per-shot instantiate/free churn.
- [ ] Separate projectile visual state from collision state.
- [ ] Keep visible projectile motion and lifetime updates active while far from the player.
- [ ] Arm incoming projectile `Area3D` collision only within Interaction Range plus a speed margin.
- [ ] Use hysteresis and swept-distance protection to prevent fast projectiles from tunneling through the player.
- [ ] Keep player projectile collision active while it remains inside the visible Combat Plane bounds.
- [ ] Use primitive sphere or capsule projectile hitboxes.
- [ ] Flatten projectile spawn, movement, collision, and hit-event positions to `Y=0` while allowing muzzle/launch presentation effects to use 3D socket height.
- [ ] Share projectile meshes, textures, shaders, and materials; pool projectile nodes and collision proxies only.
- [ ] Pool projectile impact placeholders and avoid per-projectile dynamic lights.
- [ ] Reserve `MultiMeshInstance3D` projectile visuals for a profiling-driven optimization pass.
- [ ] Instrument active projectiles, armed collision shapes, pool growth, frame time, and allocations.
- [ ] Share native 3D meshes, textures, shaders, and base materials across compatible craft and projectile families.
- [ ] Apply evolution, palette, and damage-state variation through per-instance shader parameters or node-level overrides without mutating shared resources.
- [ ] Reuse existing compatible toon, voxel, neon, and outline shader materials as the first native 3D visual baseline.
- [ ] Import native 3D textures at appropriate target-view resolution with mipmaps and standard 3D filtering; declare nearest filtering only for intentional pixel-art textures.
- [ ] Use appropriately low-poly GLBs for the first slice and defer runtime LOD variants until profiling demonstrates geometry, shadow, or draw-call pressure.
- [ ] Preserve bounded pools for pickups, XP orbs, special-attack fragments, and transient effects in the native 3D port.
- [ ] Keep Player Craft and Basic Enemy scene-managed initially; leave bosses and rare set pieces directly instantiated.
- [ ] Add regular-enemy pooling only if profiling demonstrates meaningful spawn/despawn churn savings after accounting for retained memory.

## Phase 3 — Player/BasicEnemy vertical slice

- [ ] Scope the first native 3D validation scene to Player Craft, Basic Enemy, and their pooled Projectiles only.
- [ ] Keep all other enemy roles, bosses, and unported gameplay actors outside the first 3D validation scene.
- [x] Create the final `Player3D` scene with a gameplay body, primitive hitbox, `Visuals` `Node3D`, GLB model, sockets, and VFX hooks.
- [x] Use existing GLB mockups for the first slice where polished replacement models are not yet ready.
- [x] Keep polished GLB replacements drop-in compatible with the established wrapper, origin, material, and `Marker3D` socket contracts.
- [ ] Keep gameplay animation control in wrapper-local `AnimationPlayer`/procedural transforms; treat imported GLB animations as optional visual inputs rather than gameplay dependencies.
- [x] Create a dedicated 3D asset-review scene using runtime scale, orientation, lighting, materials, sockets, and relevant animation presentation.
- [ ] Obtain manual asset approval in the review scene before swapping a polished replacement into a validated gameplay slice.
- [ ] Port player controls, movement tuning, aim, rotation, boost, damage, invulnerability, and boundaries.
- [ ] Reuse shared spatially independent gameplay data for tuning, damage, weapons, upgrades, evolution, and encounter rules instead of duplicating balance constants.
- [ ] Keep 3D-specific scene references, model scale, sockets, primitive hitboxes, and visual parameters in native 3D scenes or dedicated 3D resources.
- [ ] Migrate position-bearing gameplay signals to canonical `Vector3` combat positions with `Y=0`.
- [ ] Add temporary 2D boundary conversions for the reference scene and remove them during final 2D gameplay cleanup; keep UI layout coordinates as `Vector2`.
- [ ] Create the final `BasicEnemy3D` scene with its native 3D gameplay and visual structure.
- [ ] Port Basic Enemy movement, targeting, attack timing, damage, death, reward, and despawn behavior.
- [ ] Connect pooled player and enemy projectiles to native 3D hit detection.
- [ ] Add lightweight pooled placeholder muzzle, impact, death, and boost effects.
- [ ] Implement first-slice placeholders with pooled `GPUParticles3D` for repeated trails/sparks and primitive mesh bursts for discrete flashes/impacts, attached through stable `Marker3D` effect hooks.
- [ ] Run the complete manual user-validation checklist.
- [ ] Pause implementation and wait for explicit user approval before continuing.
- [ ] Record explicit user acceptance before production cutover or legacy cleanup.

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
