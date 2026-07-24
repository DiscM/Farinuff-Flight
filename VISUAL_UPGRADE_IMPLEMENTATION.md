# Visual Elite Upgrade System — Implementation Specification

## Problem Statement

Elite upgrades permanently change the player's combat capabilities during a run, but most of them do not change the ship's appearance. The player cannot read their build from the ship itself, and choosing an upgrade does not currently deliver the fantasy of physically transforming the craft.

The visual-upgrade system must make every elite upgrade recognizable on the ship while preserving the current compact player-ship design, gameplay readability, collision behavior, and performance under the Compatibility renderer.

## Solution

Add a cumulative, runtime-drawn visual module for each of the ten elite upgrades. Installed modules remain visible together in fixed attachment positions and use the existing ship's flat, low-detail polygon language. The original hull remains visible and recognizable beneath every combination.

Two composite procedural drawing layers will render ship-mounted hardware behind and in front of the existing animated sprite. Both layers will synchronize to the sprite strip's four baked animation frames. Static geometry will redraw only when upgrade state changes. Short functional animations will communicate firing, targeting, charging, attraction, and Overclock activation without introducing continuous decorative motion.

The existing collision capsule remains unchanged. Permanent ship-mounted geometry and idle lighting must stay inside a centered `104 × 96` source-pixel envelope within the existing `128 × 128` animation cell. The independent escort drone is not part of that envelope.

## Implementation Status — 2026-07-24

The first production implementation is complete: canonical reversible elite state, both procedural ship layers, all ten visual designs, synchronized muzzle origins, paused installation, card previews, a state-keyed four-frame afterimage atlas, the expanded developer panel, and automated combination/runtime smoke coverage are in place.

The remaining release-validation work is a representative visual capture matrix, full-load frame profiling, and Compatibility export verification on Windows and Linux. Forward+ and global 2D MSAA remain separate backlog work.

## User Stories

1. As a player, I want every elite upgrade to change my ship's appearance, so that each choice feels physically installed.
2. As a player, I want acquired modules to remain visible together, so that my ship records the history of my run.
3. As a player, I want the original hull to remain recognizable, so that the upgraded craft still feels like my starting ship.
4. As a player, I want each upgrade to have a distinct silhouette, so that I can recognize it during combat.
5. As a player, I want modules to share one coherent material language, so that a fully upgraded ship does not look like a patchwork of unrelated art.
6. As a player, I want accent colors to match upgrade-card colors, so that menu choices and installed hardware are visually connected.
7. As a player, I want idle lighting to remain restrained, so that the ship does not distract me from enemies, bullets, pickups, and hazards.
8. As a player, I want active modules to brighten or move only when functioning, so that their feedback is meaningful.
9. As a player, I want visible weapons to be the real projectile origins, so that bullets do not appear from unrelated parts of the hull.
10. As a player, I want Twin Cannon shots to emerge from the paired cannon pods, so that the hardware and firing pattern agree.
11. As a player, I want Spread Shot projectiles to emerge from the canted emitters, so that the fan pattern has a visible source.
12. As a player, I want rear volleys to emerge from the rear turret, so that Rear Gunner reads clearly.
13. As a player, I want Auto-Aim hardware to track its target, so that I can see when guidance is active.
14. As a player, I want Shield Burst hardware to communicate an approaching charge without dominating the screen, so that the burst has readable anticipation.
15. As a player, I want Orb Magnet hardware to react when an object is being pulled, so that magnetic attraction has a visible cause.
16. As a player, I want Overclock hardware to deploy during its active window, so that its temporary burst is unmistakable.
17. As a player, I want Afterburner exhaust to strengthen during boosting, so that the mobility upgrade feels connected to movement.
18. As a player, I want the Drone Escort to look like a small companion craft rather than a placeholder, so that it belongs to the ship's visual family.
19. As a player, I want a selected module to materialize onto the actual paused ship, so that installation feels consequential.
20. As a player, I want installation to preserve the normal camera scale, so that I do not lose spatial orientation.
21. As a player, I want upgrade cards to preview the candidate hardware on my current build, so that I can anticipate the cumulative result.
22. As a player, I want the candidate module highlighted while existing modules are dimmed, so that the proposed change is obvious.
23. As a player, I want boost afterimages to include installed hardware, so that the trail matches my ship's silhouette.
24. As a player, I want transient flashes and the escort drone excluded from afterimages, so that the trail remains clean.
25. As a player, I want ship-mounted modules to inherit invincibility blinking, visibility, boost tint, and drift tint, so that they remain visually attached to the hull.
26. As a player, I want installed modules to remain intact after taking damage or losing a life, so that permanent upgrades do not appear disabled.
27. As a player, I want the hitbox to remain unchanged, so that installing upgrades never makes the ship easier to hit.
28. As a developer, I want to enable or disable any elite upgrade independently, so that I can inspect arbitrary visual combinations.
29. As a developer, I want Grant All and Clear All controls, so that I can review both the fully upgraded and baseline states quickly.
30. As a developer, I want overlays for the visual envelope, attachment anchors, muzzle origins, and collision capsule, so that alignment errors are easy to diagnose.
31. As a developer, I want stateful developer controls to be reversible, so that repeated testing does not compound gameplay values.
32. As a developer, I want one canonical visual definition per upgrade, so that gameplay, card previews, installation, debug views, and afterimages do not drift apart.
33. As a developer, I want static module geometry to avoid per-frame rebuilding, so that cumulative visuals add negligible runtime cost.
34. As a developer, I want the implementation to work under the current Compatibility renderer, so that the feature does not require a renderer migration.
35. As a developer, I want Forward+ and 2D MSAA evaluated separately, so that renderer risk does not block the upgrade feature.

## Visual Module Specifications

All modules use simple polygons, flat fills, thin dark outlines, and sparse illuminated accents. The upgrade color identifies the module but does not replace the ship's white, gray, dark-metal, purple, and cyan base palette. Ship-mounted modules have one canonical placement in every build.

| Elite upgrade | Permanent visual addition | Accent and functional state |
| --- | --- | --- |
| Twin Cannons | Two compact forward-facing gun pods at the inner wing roots | Yellow strips remain dim at idle; localized muzzle flashes accompany the two offset shots |
| Auto-Aim Core | Small faceted targeting lens above the nose, held by two short forward-swept antenna prongs | Green lens subtly tracks the current guidance target and pulses on acquisition |
| Drone Escort | Miniature angular fighter that echoes the player's swept-wing shape and hovers on the starboard side; no docking clamp | Cyan-blue engine and weapon accents; gentle hover and banking are allowed |
| Hull Plating | Flush, contour-following dark titanium overlays inset along the hull and wings | Narrow purple seams provide readability; armor must not make the silhouette bulky |
| Afterburner | Two compact auxiliary nozzles at the rear wing roots, flanking the central engine | Short orange idle exhaust becomes brighter and longer during boosting |
| Spread Shot | Two slim outward-canted emitter vanes near the wingtips, aligned to the side-shot angles | Magenta energy channels and short muzzle flashes accompany angled projectiles |
| Shield Burst | Two slim crescent projectors hugging the port and starboard mid-hull | Cyan cores stay dim until the end of the cooldown, then brighten shortly before the burst |
| Orb Magnet | Amber induction coils along the outer rear-wing edges with short inward-hooked pole tips | Small amber motion or a faint field cue appears only while an object is being attracted |
| Overclock | Segmented reactor collar around the central energy spine with two compact folding heat-sink fins | Lime-yellow segments illuminate in sequence; fins flare outward and brief arcs appear only while active |
| Rear Gunner | Short raised dorsal turret on the rear centerline above the central engine | Red breech remains dim at idle; the backward-facing muzzle flashes with rear volleys |

## Implementation Decisions

### Scope and state

- Only the ten elite upgrades receive permanent visual modules.
- Temporary pickups, repeatable stat allocations, and developer-only legacy RPG abilities do not add permanent ship hardware.
- Runtime elite state must have one canonical representation that can drive gameplay, visuals, previews, afterimages, and developer controls.
- Normal run-selection history remains distinct from developer overrides so debug combinations do not pollute the upgrade-choice exclusion pool.
- Enabling an already enabled upgrade must be idempotent.
- Disabling and re-enabling an upgrade in developer tools must not compound one-time or multiplicative effects.
- Hull Plating's normal installation grants one life once. Developer visualization toggles must not repeatedly add lives.
- Afterburner must use deterministic derived modifiers or a reversible state application rather than repeatedly multiplying speed and acceleration.
- Starting a new run clears visual state, transient module state, previews, and afterimage caches.

### Rendering architecture

- Preserve the existing four-frame animated ship sprite as the base visual.
- Add one composite procedural canvas layer behind the sprite and one in front.
- The rear layer owns under-hull hardware and exhaust geometry. The front layer owns armor, weapon housings, sensors, projectors, coils, reactor hardware, and the raised rear turret.
- A layer draws every active module assigned to that depth; do not create one persistent renderer per module.
- Store canonical module geometry and anchors in shared visual definitions so the player, card previews, installation effect, debug overlays, and afterimage compositor use the same source data.
- Static geometry rebuilds only after the active upgrade set changes.
- Functional animations may update only the small subset of geometry or transforms that actually changes.
- Do not use continuous SubViewports, per-module Viewports, per-frame texture generation, or per-frame geometry allocation.
- Filled polygon edges must be reinforced by thin antialiased outline strokes so the modules match the base sprite under the Compatibility renderer.
- Do not make the implementation depend on global 2D MSAA.

### Frame synchronization and dimensions

- Author module geometry in the same `128 × 128` source coordinate system as one ship animation frame.
- Permanent ship-mounted geometry and idle lighting must fit within a centered `104 × 96` envelope.
- The escort drone is an independent companion and is excluded from the ship envelope.
- The two procedural layers must follow the currently displayed animation frame's baked bob and roll.
- Hull-anchored and wing-anchored geometry may use separate authored frame transforms where needed to match the base strip.
- Synchronization must be data-driven by the current frame index and must not require redrawing unrelated module geometry.
- The collision capsule remains centered with its current gameplay dimensions.
- Module geometry must not modify collision layers, masks, damage reception, viewport physics, or enemy targeting.

### Visual behavior

- The original pointed hull, swept wings, purple cockpit, cyan spine, and cyan engine remain visible in every combination.
- Modules must not redesign, replace, or substantially cover the base hull.
- Idle accent lighting is dim and localized.
- Avoid continuous decorative pulsing, spinning, or mechanical movement.
- Functional motion is limited to target tracking, exhaust flicker, shield charging, attraction feedback, Overclock deployment, weapon flashes, and the drone's hover.
- Brief effects may use the transparent remainder of the animation cell, but must remain restrained and non-collidable.
- Ship-mounted modules inherit hull opacity, invincibility blinking, boost tint, drift tint, and other global visibility states.
- Accent hue may be preserved while inheriting opacity and overall intensity.
- The escort drone follows its own existing visibility and gameplay behavior.
- Installed hardware always returns visually intact after damage, respawn, or try-again recovery.

### Projectile integration

- Visible weapon hardware becomes the authoritative muzzle source for its associated projectile lanes.
- Twin Cannon projectile origins move to the paired inner-wing barrels.
- Elite Spread Shot side-projectile origins move to the two canted emitters.
- Rear Gunner projectile origins move to the rear turret.
- Projectile direction, rate, damage, homing behavior, stacking behavior, and inherited bullet modifiers remain unchanged.
- Temporary Spread Shot without the elite upgrade does not permanently install elite emitter hardware.
- Muzzle locations must follow ship rotation and the synchronized visual frame.

### Installation sequence

- Selecting an elite upgrade keeps gameplay paused.
- The selected card receives its existing confirmation feedback.
- The upgrade UI then fades away and reveals the actual gameplay ship in place.
- The candidate module appears as an accent-colored wireframe at its canonical attachment point.
- Over roughly `0.4` seconds, the wireframe resolves into the solid module and emits one restrained confirmation pulse.
- The camera scale does not change.
- Gameplay resumes only after installation completes.
- Installation timing must continue while the scene tree is paused.

### Upgrade-card previews

- Replace emoji as the primary visual identifier with a procedural module preview while retaining the upgrade name and description.
- Each card shows the player's current ship configuration dimly.
- The candidate module is added at its canonical location and highlighted in its accent color.
- Preview rendering reuses canonical module definitions.
- Previews may be cached for the lifetime of the popup and do not need continuous processing.
- A preview is illustrative only; it must not mutate player or run state.

### Afterimages

- Boost afterimages include the base ship and all installed ship-mounted modules as one flattened composite.
- Do not duplicate the two live procedural layers for every ghost.
- Rebuild a four-frame composite afterimage strip only when the installed upgrade set changes.
- Continue spawning one sprite per afterimage and retain the current fade-and-shrink behavior.
- Exclude the escort drone, muzzle flashes, electrical arcs, field arcs, shield charge effects, and exhaust flames from the cached ghost.
- Invalidate the cache when elite state is cleared or rebuilt.

### Developer tools

- Convert the developer panel into a scrollable layout with the following sections:
  - Run Actions
  - Player State
  - Elite Upgrades
  - Visual Debug
- Keep event and counter operations as one-shot buttons:
  - Add Orbs
  - Clear Enemies
  - Spawn Elite Boss
  - Spawn Tempest Core
  - Trigger Elite Upgrade
  - Trigger Point Allocation
  - Add Lives
- Convert God Mode to a visible reversible checkbox.
- Replace Full Power with individual reversible controls where applicable:
  - Rapid Fire
  - Spread Shot
  - Orbitals
  - Piercing
  - Explosive Rounds
- Provide one reversible checkbox for each elite upgrade.
- Provide Clear All and Grant All elite-upgrade actions.
- Developer state changes must use deterministic set semantics and must not compound values.
- Add optional overlays for:
  - `104 × 96` visual envelope
  - Module attachment anchors
  - Weapon muzzle origins
  - Existing collision capsule
- Visual debug overlays are development-only, non-collidable, and excluded from exports where the existing developer menu is unavailable.

### Performance constraints

- A fully upgraded ship uses the existing base sprite plus no more than two persistent composite module canvas items, excluding the independent drone and short-lived effects.
- Static upgrade state must not allocate or rebuild geometry every frame.
- Preview and afterimage composites rebuild only after relevant state changes.
- Active effects must use short lifetimes, restrained particle counts, and localized drawing.
- The fully upgraded boost trail must retain one sprite per ghost rather than cloning the live module hierarchy.
- Profile the fully upgraded state while boosting, firing the maximum stacked weapon pattern, attracting objects, running the drone, and triggering Shield Burst and Overclock.
- The feature must not introduce visible frame pacing regressions in the existing stress conditions for supported desktop exports.

### Renderer backlog

- The implementation targets the current Compatibility renderer.
- A separate backlog item must evaluate migration to Forward+ and enabling 2D MSAA.
- That evaluation must cover Windows and Linux export compatibility, low-end hardware requirements, shader and visual regressions, performance at `2×` and `4×` MSAA, and whether the base PNG's alpha edges benefit enough to justify the migration.
- The visual-upgrade implementation must remain functional if that backlog item is never completed.

## Implementation Sequence

1. Introduce canonical elite runtime state and idempotent enable/disable behavior.
2. Extract shared module definitions, anchors, colors, depth assignments, bounds, and muzzle locations.
3. Add the rear and front procedural drawing layers and synchronize them to all four sprite frames.
4. Implement the ten static module shapes within the `104 × 96` envelope.
5. Add functional module animations and inherited global visual state.
6. Move projectile origins to their visible muzzle anchors without changing projectile behavior.
7. Implement the paused wireframe-to-solid installation sequence.
8. Replace card emoji primacy with current-build candidate previews.
9. Add the flattened four-frame afterimage cache.
10. Expand and reorganize developer tools with reversible state controls and visual overlays.
11. Add the visual regression harness, combination checks, and full-load performance validation.
12. Update player-facing and developer documentation after behavior is verified.

## Testing Decisions

### Primary test seam

The highest practical seam is a scene-level player visual harness that instantiates the real player ship, applies elite state through the same public state interface used by normal selection, and inspects or captures the resulting player scene. The expanded developer menu is the interactive entry point for this harness.

The repository currently has no automated test framework. Do not test private drawing helpers independently. Prefer behavior-level checks against the active upgrade set, reported geometry bounds, muzzle anchors, visible node count, and rendered scene output.

### Automated and data-level checks

- Enabling each upgrade individually produces exactly its canonical module state.
- Every combination of the ten elite upgrades can be enumerated without errors or duplicate modules.
- Reported persistent geometry bounds remain inside `104 × 96` for every combination.
- Repeated enable calls are idempotent.
- Reversible developer toggles do not stack Afterburner modifiers or Hull Plating rewards.
- Clearing elite state restores baseline gameplay values and removes visual modules.
- Run reset clears active modules and invalidates caches.
- Every weapon muzzle anchor exists only when its corresponding hardware is installed.
- Projectile direction and modifier behavior remain unchanged after origin movement.
- The active afterimage cache contains the current base frame and every installed ship-mounted module.
- The afterimage cache excludes transient effects and the drone.
- The persistent player visual hierarchy remains within the agreed canvas-item budget.

### Scene and visual checks

- Capture the baseline ship, each individual module, representative two- and three-module combinations, and the fully upgraded ship in all four animation frames.
- Confirm the base hull remains recognizable and unobscured.
- Confirm the fully upgraded silhouette respects the `104 × 96` envelope.
- Confirm module accents remain subordinate to enemy, projectile, pickup, and hazard readability.
- Confirm front and rear layers occlude correctly against the base sprite.
- Confirm modules remain aligned while the ship idles, rotates, drifts, boosts, blinks, and changes tint.
- Confirm the collision capsule remains unchanged and centered.
- Confirm visible wings and modules do not unexpectedly receive collision.
- Confirm each muzzle flash and projectile originates from the matching hardware.
- Confirm card previews show the current configuration dimly and only the candidate brightly.
- Confirm installation runs while paused, uses the actual ship, takes approximately `0.4` seconds, and does not zoom the camera.
- Confirm afterimages show the complete installed silhouette without the drone or transient effects.
- Confirm developer checkboxes can produce arbitrary combinations and restore baseline state.

### Performance checks

- Profile baseline and fully upgraded scenes under the same enemy and projectile load.
- Exercise maximum firing stacks while the drone, magnet, Shield Burst, Overclock, boost tint, and afterimages are active.
- Verify static module geometry does not continuously redraw or allocate.
- Verify afterimage spawning does not create module-layer clones.
- Verify popup previews stop processing after the popup closes.
- Verify installation-time cache rebuilding produces no gameplay hitch after the game resumes.
- Verify Windows and Linux Compatibility exports render the procedural geometry and antialiased outlines consistently.

## Acceptance Criteria

- All ten elite upgrades have approved, cumulative, recognizable ship visuals.
- The original ship remains visibly intact in the fully upgraded state.
- Permanent ship-mounted visuals stay inside `104 × 96`.
- The existing collision capsule and gameplay collision behavior are unchanged.
- Weapon projectiles originate from their visible elite weapon hardware.
- Upgrade cards preview the player's current build plus the highlighted candidate.
- Installation materializes on the actual paused ship without camera zoom.
- Boost afterimages include installed hardware as a single composite ghost.
- Ship-mounted modules inherit global ship visual states.
- Developer tools support reversible individual elite configurations, Grant All, Clear All, and visual-debug overlays.
- The implementation works under the Compatibility renderer without global 2D MSAA.
- Full-load profiling shows no visible frame pacing regression attributable to the module system.

## Out of Scope

- Visual transformations for temporary pickups.
- Visual transformations for repeatable fire-rate, health, or speed allocations.
- Permanent visuals for legacy RPG abilities that are not part of the ten-option elite pool.
- Collision expansion or per-module hit detection.
- Combo-specific module shapes or dynamic relocation.
- Persistent module damage, breakage, or repair states.
- Camera zoom during installation.
- Decorative idle animation unrelated to module function.
- Replacing or redrawing the current base ship sprite.
- Migrating the project to Forward+ as part of this feature.
- Enabling global 2D MSAA as part of this feature.
- Changing upgrade balance, cadence, descriptions, projectile damage, rate, or modifier stacking.
- Production use of the generated planning mockups.

## Further Notes

- The current ship occupies approximately `77 × 68` opaque source pixels inside each `128 × 128` animation frame.
- The existing collision capsule maps to approximately `45 × 62` source pixels relative to the unscaled artwork.
- The `104 × 96` limit is the agreed permanent visual envelope, not a request to fill the entire area.
- The escort drone remains an independent gameplay entity and does not require a docking clamp.
- Generated mockups establish placement and density only. The current in-game sprite is the authoritative source for proportions, polygon complexity, palette, and finish.
- The shared module-definition layer is the central architectural seam. Any implementation that separately redraws module geometry for gameplay, previews, installation, debug views, and afterimages risks visual drift and should be avoided.
