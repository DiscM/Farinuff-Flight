# Pixel-forged space debris

Six original Blender props extend the station wreckage's five material roles,
clipped armor and flat facets. The asteroid uses the same subdued mineral tones.
All receive the fleet's three-band PixelPlanets shader in Godot.

| Asset | Triangles |
| --- | ---: |
| derelict_satellite.glb | 814 |
| ruptured_cargo_pod.glb | 370 |
| spent_fuel_tank.glb | 584 |
| discarded_engine_bell.glb | 312 |
| broken_survey_dish.glb | 300 |
| faceted_asteroid.glb | 80 |

Editable source: `assets/models/frontier/sources/space_debris.blend`.
Rebuild inside Blender: `tools/build_space_debris_blender.py`, which reuses the
station's geometry helpers and palette. Paths are relative to the repository.
`manifest.json` records export hashes, dimensions, provenance and material colors.
Each GLB is self-contained, Y-up, flat-shaded, and exported at its origin without
lights, textures, animation, shadows or physics. Attached parts meet their mounts.

The production field has one relay and eighteen fragments drawn from all eleven
station/space debris shapes. Fragments descend at 16–28 canvas pixels/second;
the larger, more distant relay descends at 12 pixels/second. An enclosing sphere
keeps long antennas and the station fully outside the viewport before wrapping.
Objects are reused, with no spawning or allocation during travel.

`GameManager.boss_active` freezes falling, tumbling and planet surface animation
through boss entry, phase changes and pause/continue. Defeat resumes from the
held positions. Scenery remains aligned with the screen during boss camera follow.

Review: `scenes/space_debris_review.tscn` (R toggles rotation).
Style: `design/station-debris/STYLE_REFERENCE.md`.
Lifecycle check: `tests/background_drift_smoke.tscn`.
