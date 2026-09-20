# Combat scale review

The default window is now 2560 × 1440 (`spacious`), with the existing 90% usable-display fit for smaller screens. The previous presets remain available. The current local window preference was set to the new preset at the user's request; other preferences and progression were retained.

The UI canvas remains 1280 × 720. The camera's independent combat baseline increases from 1280 × 720 to 1600 × 900. At 16:9 this changes the visible world from 109.346 × 65.455 to 136.683 × 81.818 units: 25% wider and deeper, or 56.25% more area. World movement, projectile speed, and pixel-tuned distance conversions remain unchanged.

Regular enemy models and their XZ collision envelopes grow 1.75×. Boss hulls and weapon pods grow 1.6×. Relative to the previous view at the same window size, regular models appear 40% larger and bosses 28% larger. At the new 2560 × 1440 window versus the previous 1920 × 1080 window, these increases become approximately 87% and 71%. The player retains its world size.

Static sockets, tank armor and warning rings, boss pods, and edge clearances follow the larger hulls. Actor roots stay unit-scaled and animations do not alter collision shapes. The HUD yields when the visible boss model overlaps it, using the rendered camera and the visible hull/pod bounds. Hidden boss variants do not enlarge the occlusion area.

## Verification

`qa/` contains isolated-profile Godot smoke logs. The focused checks cover projection and window fitting, HUD occlusion, save preferences, native gameplay contracts, boss flight and AI, animated model materials/sockets, and background wrapping. Existing headless renderer/resource teardown diagnostics are recorded in the logs; a passing sentinel does not imply silent teardown.

`regular-combat-2560.png` and `boss-combat-2560.png` are GPU captures in Flight Practice using production actors, shaders, AI, and projectile pools. Actors are explicitly placed for repeatable inspection, with an invulnerable stationary player and no progression rewards. They are controlled combat checks, not a complete campaign or performance benchmark. Companion JSON files record window/render dimensions, world bounds, visible projected model sizes, and texture bindings.

To reproduce a capture, launch `res://scenes/flight_practice.tscn`, wait until warmup completes, and call `prepare(game, wave)` then `capture(game, label)` from `res://tests/combat_scale_capture.gd`; wave 0 produces regular enemies and wave 20 produces Tempest Core. Let normal physics run between preparation and capture. Use the `spacious` window preset for the supplied image dimensions.

The previously delivered Voxel Frontier and Voxel Bosses source GLBs and ZIP archives are unchanged. These changes adjust their game integration.
