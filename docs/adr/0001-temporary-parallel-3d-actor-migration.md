# Temporary Parallel 3D Actor Migration

**Status**: accepted

During the native Top-down 3D migration, new player and enemy actor scenes will be built beside the existing 2D actors so behavior can be migrated and compared incrementally without destabilizing the current runtime. This parallelism is temporal only: the existing 2D actors are a frozen reference and rollback path, not a second gameplay implementation that must remain synchronized with the 3D actors. After the user validates native 3D behavior and parity, the obsolete 2D actor scenes, migration-only adapters, and compatibility paths must be removed; the 2D backdrop and HUD are not part of this removal rule.

## Considered Options

- Rewrite the existing 2D actor scenes in place, creating a large and difficult-to-rollback change.
- Maintain a permanent 2D gameplay / 3D gameplay hybrid, which would preserve unnecessary duplicate systems.

## Consequences

The migration temporarily carries two actor representations and requires explicit parity checks and a user-validation gate before cleanup. Shared code should be extracted only where it is genuinely reusable; the final runtime contains one native 3D gameplay implementation, without allowing the temporary parallel architecture to become the product architecture.

## Validation Gate

The 3D actors are not considered ready for cleanup when they merely render or launch successfully. They must preserve the current run behavior—including controls, movement tuning, enemy patterns, weapon timing, damage, upgrades, deflection, spawning, and combat-plane limits—and the user must validate that parity before the legacy actor implementations are removed.

## Implementation Approach

The 3D actor code is the final implementation. Behavior will be ported directly from the 2D reference, with shared data or utilities extracted only when they are genuinely reusable; no permanent dual adapter layer or synchronized 2D/3D gameplay system will be created.

## Runtime Isolation

Parallel implementations may coexist in the repository for reference and rollback, but they must not be instantiated together in a validation run. Scene-by-scene validation will load either the 2D baseline or the 3D replacement, never both, to avoid duplicate rendering, physics shapes, processing, and pooled resources.

The native 3D runtime will live in a separate top-level gameplay scene. That scene owns the active `Camera3D`, 3D world, pooled gameplay managers, native 3D actors, and the retained `CanvasLayer` HUD needed for the run. A validation entry point loads either the existing 2D gameplay scene or this native 3D gameplay scene; it does not nest one gameplay scene inside the other or keep both resource graphs active.

Once the first native 3D slice is ready for personal playtesting, the active gameplay entry will switch directly to the native 3D scene. No in-app 2D/3D scene selector will be added; the 2D implementation remains repository-resident as a reference and rollback path and can be recovered through version control when needed. The active scene tree still contains only one gameplay implementation at a time.

Before the active gameplay entry is changed, the verified 2D baseline will receive a named Git checkpoint. This checkpoint records the known-good reference for rollback and comparison without requiring the runtime to carry a second active scene path.

## User Validation

Dedicated automated smoke tests are not part of this migration gate. The user must manually play each 3D migration slice and explicitly accept its behavior before the 3D scene replaces the production 2D path or the corresponding legacy 2D implementation is removed; automated checks, if used for development diagnostics, never authorize cleanup.

## Acceptance Checklist

Each slice must be reviewed for movement and controls, rotation and combat-plane boundaries, camera framing, model scale and orientation, weapon sockets, projectile and collision behavior, damage and deflection, hit effects, death and rewards, despawning and pooling, pause and restart flows, game-over behavior, visible rendering issues, runtime errors, and acceptable performance.

## Approval Pause

After each migrated scene or slice is presented for playtesting, implementation must pause until the user explicitly approves it. The workflow must not automatically continue to the next migration slice or remove the corresponding 2D reference after a playtest.

## Initial Vertical Slice

The first playable native 3D validation scene will contain only the Player Craft, one Basic Enemy role, and their pooled Projectiles. Remaining enemy roles, bosses, and other gameplay actors will remain outside that scene and will be migrated in later isolated slices, so the first playtest measures the core flight, aiming, firing, collision, damage, and pooling loop without activating unported actor systems.

## Coordinator System Porting

The native 3D gameplay scene will use 3D-targeting ports of the current enemy spawner, power-up spawner, threat director, and special-attack coordinator. These ports will own 3D scene references, transforms, and pool interfaces; the existing 2D coordinators remain the baseline implementation and are not run in the native 3D scene. No coordinator will maintain a permanent branch that runs both 2D and 3D gameplay paths together.

## Shared Gameplay Data

Spatially independent gameplay data remains shared between the 2D reference and the native 3D implementation. This includes enemy and weapon tuning, damage values, upgrade definitions, evolution thresholds, encounter timing, and progression rules. Scene references, model scale, sockets, primitive hitboxes, visual parameters, and other 3D-specific presentation data belong to the native 3D scenes or their dedicated resources, preventing the migration from creating two competing balance sources.

Native gameplay event positions will use `Vector3` as the canonical combat-space type, with `Y=0` for positions on the Combat Plane. Position-bearing shared signals such as enemy kills and power-up collection will be migrated to that representation. The temporary 2D reference path will convert at its boundary while it remains runnable; UI layout coordinates remain `Vector2`. These conversions are migration compatibility only and are removed with the obsolete 2D gameplay path.

The existing InputMap action names and keyboard/gamepad semantics will remain stable. Native 3D input code will convert those actions through `FlightSpace3D` onto the Combat Plane, preserving movement tuning and control expectations rather than introducing a second control scheme.

## UI and Run Lifecycle

The existing 2D HUD, pause, game-over, point-allocation, elite-upgrade, retry, and victory scenes remain in use during and after the native 3D gameplay migration. `GameManager` and `SignalBus` remain the run-state and event authorities; the native 3D gameplay scene hosts the UI through `CanvasLayer` integration and adapts only the world-position data that crosses into screen-space presentation. Rebuilding the UI or run lifecycle is outside the 3D actor migration.

## Runtime Asset Source

Imported GLB craft models are the canonical runtime visual assets for the native 3D implementation. The existing 2D sprite strips are temporary reference or fallback assets only and may be removed after the corresponding 3D actor passes the user-validation gate.

## Temporary Model Assets

The first native 3D vertical slice may use the existing imported GLB mockups so gameplay migration is not blocked by final art production. Polished GLB replacements remain a separate art pass and require the same manual visual and gameplay approval before they are considered final. Replacement models must remain drop-in visual assets under the established wrapper, origin, material, and socket contracts so art improvements do not require a second gameplay implementation.

Polished asset replacements will be reviewed in a dedicated 3D asset-review scene before gameplay cutover. The review scene will use the runtime scale, orientation, shared lighting, materials, socket markers, and relevant animation presentation so model problems can be corrected independently of encounter logic.

## Initial Animation Strategy

The first 3D implementation will use rigid model parts, node transforms, procedural motion, shader animation, and `AnimationPlayer` where authored timing is useful. This is a staged starting point rather than a limit: the implementation plan must reserve a later polish phase for richer authored animations and `Skeleton3D` only where future craft designs require deformation or articulated motion.

Gameplay animation control will remain in the owning wrapper scene. Wrapper-local `AnimationPlayer` tracks and procedural transforms may drive the visual hierarchy, while imported GLB animations are optional visual inputs rather than a dependency on the GLB's internal node paths. This keeps polished asset replacement compatible with the established gameplay and socket contracts.

## Initial Collision Geometry

The initial 3D actors and projectiles will use dedicated primitive gameplay hitboxes rather than collision generated from their visual meshes. Recomputing collision from visual geometry is a future option only after explicit user validation of contact behavior, gameplay parity, and performance.

## Camera and Combat Plane Framing

The first 3D version will use a fixed orthographic camera at a near-top-down angle and a fixed visible combat plane. Player and enemy movement will remain constrained to that plane; camera following and a larger scrolling world are deferred features.

Screen shake will be implemented on a visual `CameraRig3D`/camera transform using small local position and rotation offsets. It will not modify Combat Plane coordinates, actor transforms, hitboxes, or camera-derived Combat Plane bounds; the effect is presentation-only and the camera remains fixed for gameplay purposes.

Visible Combat Plane bounds, off-screen spawn margins, and despawn margins will be derived by projecting the active orthographic camera's view onto the Combat Plane. They will not be hard-coded in screen pixels or duplicated as unrelated world-coordinate rectangles, allowing the native scene to preserve the intended framing across supported viewport sizes.

Viewport adaptation will preserve the 16:9 baseline's vertical combat framing and orthographic span. Wider aspect ratios will expand the visible horizontal Combat Plane bounds rather than stretching craft or changing their world scale; the camera-derived bounds service remains authoritative for clamping and spawn margins.

## World-Unit Scale

The native 3D migration will retain the established 11 screen-pixels-per-model-unit convention as its initial world scale. Positions, speeds, distances, hitboxes, camera framing, and model sockets will convert through this shared scale so the first 3D pass preserves the current run behavior and visual sizing.

## Coordinate Mapping

The shared flight-space adapter will map screen right to world +X and screen down to world +Z. The combat plane remains at world Y=0; world Y is reserved for model height, visual offsets, and effects rather than gameplay movement.

The adapter will expose separate conversions for screen positions and directional input. Mouse aiming will cast a `Camera3D` ray through the cursor and intersect the Combat Plane. Keyboard and gamepad movement will convert the input vector through the camera's projected right/forward basis onto X/Z, without inventing a synthetic ray or making movement depend on cursor position. Both conversions resolve into the same Combat Plane coordinate system.

This flight-space logic will be implemented as a scene-owned plain `Node` service named `FlightSpace3D`, with a reference to the active `Camera3D` and optional configuration held in a `Resource`. It is not a `Control`, `Area3D`, or autoload: it has no visual or collision representation and does not create global state shared by the 2D and 3D scenes.

## Lighting Strategy

Native 3D will use a shared global environment and one key `DirectionalLight3D` with moderate dynamic shadow quality for consistent fleet lighting and model self-shadowing, with emission and bloom handling routine neon readability. Only Player Craft, Enemy Craft, bosses, and major 3D set pieces will cast or receive dynamic shadows. A capped, pooled set of local lights may serve major cores, explosions, and boss effects; routine projectiles, pickups, particles, and minor effects will not create individual dynamic lights or shadow casters.

Each active native 3D gameplay scene will instantiate the same reusable environment and lighting configuration, backed by shared resources, rather than developing independent scene-specific lighting rigs. Boss phases and major effects may apply explicit, localized overrides without changing the baseline fleet look.

The shared `Environment` resource will be activated through a `WorldEnvironment` owned by the active native 3D gameplay scene rather than through a project-wide global environment. Menus and other 2D-only scenes therefore retain their existing presentation unless they explicitly opt into the native 3D environment configuration.

## Craft Orientation

Native 3D craft will preserve the current directional behavior through yaw around the world Y axis. Pitch and roll are visual-only banking effects applied to the visual model hierarchy, while gameplay hitboxes remain governed by their dedicated primitive shapes.

Every actor gameplay root will use the same origin convention: its X/Z position is the Combat Plane position and its Y coordinate is zero. Model centering, visual height, and any imported-asset pivot correction will be applied below the gameplay root inside `Visuals`; collision and gameplay calculations will not depend on an individual GLB's artist pivot.

Projectile gameplay positions will be flattened to the Combat Plane even when they are spawned from a muzzle `Marker3D` with a visual height. The projectile root, movement, collision, and hit event use `Y=0`; muzzle flashes, launch trails, and other presentation effects may remain at the marker's 3D position.

## Native Gameplay Roots

The first native 3D player, enemy, projectile, and pickup gameplay roots will use `Area3D` with manual movement and overlap-driven interaction. `CharacterBody3D` and solid 3D bodies remain deferred until a future feature requires physical blocking, sliding, or navigation; `Node3D` remains the visual/model scaffold rather than the gameplay body.

The 3D physics configuration will preserve the existing interaction vocabulary: Player Craft, Enemy Craft, Player Projectile, Enemy Projectile, Pickup, and Hostile Ordnance. The 3D layer and mask assignments may use different numeric slots from the 2D project, but their names and allowed interactions must remain explicit and behaviorally equivalent.

## Standard Godot Model Composition

Native actor scenes will follow standard Godot 3D composition: an `Area3D` gameplay root with a sibling `CollisionShape3D`, a `Visuals` `Node3D` containing the instanced imported GLB visual scene, and a wrapper-owned `Attachments`/`Sockets` `Node3D` containing named `Marker3D` points for weapons, cores, engines, upgrades, and effects. Gameplay and attachment nodes belong to the owning Godot scene; imported GLB scenes remain visual assets rather than being edited into gameplay bodies.

Each runtime craft will be represented by a dedicated wrapper `.tscn`. Gameplay code will instantiate the wrapper scene rather than instantiate imported GLB files directly, giving the craft a stable home for collision, sockets, animation, VFX hooks, and future art overrides while keeping imported assets reusable and untouched.

## Modular Upgrade Assembly

Player upgrades will remain modular child GLB scenes attached through the owning actor's `Marker3D` points. The base hull and upgrade modules remain independently replaceable; full-ship assets for every possible upgrade combination will not be authored.

## Enemy Evolution Assets

Standard enemy evolution will reuse one canonical GLB per role, expressing progression through material parameters, palette and emission changes, scale, armor pieces, cores, and small modular attachments. Separate GLBs are reserved for evolution stages or boss phases that materially change the craft silhouette or structure.

## Transitional Combat VFX

Combat VFX will ultimately be native 3D so effects align with craft depth and Forward+ lighting, while HUD, backdrop, and screen-space post-processing remain 2D. Because the current combat VFX are scheduled for replacement, the first 3D slice will use lightweight pooled placeholders and stable effect/socket hooks rather than a one-for-one port of legacy 2D effects; a dedicated VFX replacement pass follows core gameplay validation.

The aim reticle remains a 2D HUD element. Its screen position will be derived by projecting the 3D aim point on the Combat Plane back through the active camera, so it tracks the native 3D target without becoming a gameplay mesh or collision object.

The first-slice placeholder library will use pooled `GPUParticles3D` for repeated trails and sparks and pooled primitive `MeshInstance3D` bursts for muzzle flashes, impacts, deaths, and boosts. These placeholders will attach through the wrapper-owned `Marker3D` hooks and will be replaced by the polished native 3D VFX pass after core gameplay validation.

## Backdrop Processing Boundary

The existing galaxy shader, parallax stars, and foreground celestial layers remain 2D canvas presentation. The native 3D scene may use a shared `WorldEnvironment` with Canvas background mode and HDR 2D/glow so supported environment processing can bridge the retained backdrop and native 3D emissive elements. Canvas-layer routing must keep the HUD and other UI layers from receiving unwanted glow or grading. Depth-dependent effects such as SSAO, SSIL, SSR, volumetric fog, GI, decals, and reflection probes are not applied to the current 2D backdrop; a 3D backplate for those effects is deferred until it is deliberately designed and validated.

The first native 3D slice will not add a visible 3D floor or combat-plane backplate. Craft will use model shading and self-shadowing for depth, while contact shadows, depth-aware fog, and other effects that require a receiving surface remain deferred.

## Projectile Visual Resources

Projectile families will share imported textures, meshes, shaders, and materials; these resources will not be duplicated or treated as pooled runtime objects. Projectile nodes and their collision proxies will be pooled, while `MultiMeshInstance3D` batching remains a later optimization selected by profiling if projectile draw-call or fill-rate cost becomes significant.

## Projectile Runtime Strategy

The first native 3D projectile implementation will retain pooled `Area3D` wrappers as the collision authority. A `ProjectileManager3D` will coordinate acquisition, activation, lifetime, movement updates where practical, and collision arming; only armed primitive collision shapes participate in physics. Manager-only array collision, fully batched projectile rendering, and replacement of the Area3D interaction path remain profiling-driven follow-ups rather than first-slice requirements.

The existing generic `ObjectPool` will remain the pooling implementation for native 3D wrapper scenes. `ProjectileManager3D` will add projectile-specific policy around that pool rather than creating a second cache/release system, preserving one lifecycle mechanism while allowing 3D collision and visual state to be reset correctly.

Every pooled native 3D object will follow a consistent `pool_activate()`/`despawn()` lifecycle contract. Reuse must reset transforms, visibility, processing mode, collision layers and monitoring, timers, movement state, material instance parameters, and effect state; release must leave the object inert until the next explicit activation.

Idle native 3D pooled nodes will be reparented under a dedicated `PoolRoot3D` owned by the active native 3D gameplay scene. The pool root is an inert container: pooled children are hidden and disabled for processing and collision until a manager explicitly acquires and activates them.

## Shared Materials and Instance Variation

Native 3D craft will share imported meshes, textures, shaders, and base materials wherever their structure is the same. Enemy evolution, palette, damage state, and other per-instance visual variation will use instance shader parameters or other node-level overrides rather than duplicating material or texture resources. A resource may be duplicated only when an asset genuinely requires a distinct material structure or texture set; changing one craft's state must never mutate a shared base resource for every craft.

The existing toon, voxel, neon, and outline shader materials in the project will be reused as the first native 3D visual baseline where their asset role matches. Wrapper scenes will reference these shared shader resources and expose only deliberate per-instance parameters; switching to plain `StandardMaterial3D` is not a prerequisite for the gameplay migration.

## Native 3D Texture Filtering

Native 3D textures will be authored and imported at an appropriate resolution for the target 1920×1080 presentation, with mipmaps and standard 3D filtering enabled to reduce shimmer on the angled view. Nearest-neighbor filtering is reserved for textures whose pixel-art treatment is intentional and explicitly declared; it is not applied globally to imported craft materials.

## Initial Geometry Complexity

The first native 3D slice will use appropriately low-poly GLB geometry without runtime LOD variants. Geometry, shadow, and draw-call costs will be measured at the target view; additional authored LOD resources may be introduced later only when profiling demonstrates a scaling need.

## Asset Loading and Warm-up

Model scale, pivots, texture import settings, mipmaps, filtering, and material preparation are offline import concerns and must not be recomputed when a run starts. The `Native3DAssetCatalog` will begin threaded requests for the Player Craft, Basic Enemy, shared Projectile resources, and required temporary VFX from an appropriate menu or boot screen, allowing them to be ready before gameplay begins without blocking the menu. The native 3D gameplay scene will then warm its nodes and pools during the transition into the isolated run. Later enemy roles and polished VFX may be requested asynchronously before they are introduced; gameplay must not synchronously load or instantiate a new asset on its first combat use. If the player starts before required resources are ready, the transition waits or reports loading progress. Cold-start time, first-use hitches, pool growth, and post-warm-up memory use will be measured during performance validation.

Menu-time loading caches resources and `PackedScene` definitions only. It does not instantiate active `Area3D` gameplay nodes, collision shapes, or projectile/effect pools; those are created and warmed only after the isolated native 3D gameplay scene is entered.

The first native 3D slice will preserve bounded pooling for short-lived, high-churn objects already using that pattern: Projectiles, pickups, XP orbs, special-attack fragments, and transient effects. The Player Craft and Basic Enemy instances will be scene-managed initially, and bosses or rare set pieces will remain directly instantiated. Regular-enemy pooling may be added later only if profiling shows spawn/despawn allocation or cleanup churn that justifies its retained memory footprint.
