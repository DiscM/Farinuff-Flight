# Pixel-forged enemy armor

## Analysis of PixelPlanets

The active combat reference is `effects/shaders/PixelPlanets/Planets/NoAtmosphere/NoAtmosphere.gdshader`. The menu's ringed planet also uses `GasPlanetLayers/GasLayers.gdshader`. Both start by flooring coordinates to a small grid. Noise is evaluated on that grid, then converted into a small set of palette colors. NoAtmosphere uses three colors with explicit shade thresholds and a narrow checker-dither transition. GasLayers distorts layered noise into cloud bands, then selects entries from light and dark palettes. Asteroids uses offset noise samples to produce similarly stepped relief and crater shadows.

The result comes from **palette selection and the shapes of the shade boundaries**, not just reducing the number of screen pixels. The existing `pixel_toon_3d.gdshader` is an earlier fleet experiment with multiplicative light levels and circuit overlays; the current native enemies previously all used `imported_enemy_surface_3d.gdshader` instead.

## New shader and integration

`effects/shaders/models/pixel_planet_enemy_3d.gdshader` adapts the reference into a spatial material:

- A three-color ramp per authored material: violet-biased shadow, class-colored middle, warm highlight.
- Six fixed noise octaves total, split across two small layered samples, deform the light boundaries into blocky patches.
- All imported mesh parts map into one hull-local coordinate frame. Quantized terrain and narrow checker dithering use the same grid, so the pattern follows movement, yaw, and the existing breathing animation.
- Actual mesh normals supply the form. Dominant-axis mapping carries the pixel pattern onto upright armor faces. The underlying mesh silhouette and collision geometry are retained.
- Reactors use restrained, stepped emissive light. The existing per-actor clock stops during pause; the armor texture is static. Hit flash is applied after both armor and reactor shading.
- Opaque rendering uses one surface pass, no screen-texture sampling, extra mesh, viewport, outline pass, texture asset, or additional light.

The production basic, tank, and bomber scenes select `surface_style = 1` (Pixel Planet). Fast, sniper, courier, boss, and player materials keep their current selection. The broad selected hulls carry the pattern better than the small, narrow fast/sniper shapes. Authored red, purple, and green role palettes remain distinct; generation colors affect reactor details.

`effects/rendering/enemy_surface_materials.gd` caches immutable conversions by source material **and shader**. The same GLB can appear with alloy and pixel materials in a comparison without changing other actors. Instance uniforms keep animation, damage, generation, and hull mapping independent. No new Blender model is needed for this material-only change.

## Tune and review

Run `scenes/pixel_enemy_material_review.tscn` to compare the production material with the previous alloy appearance at 3.5× size, plus a row at gameplay size. Press **1–4** for generation, **R** to rotate, and **H** to flash. The actual PixelPlanets reference remains in the corner. `comparison.png` is a capture from that running Godot scene.

An enemy's Inspector exposes **Surface Style** and **Surface Pixel Density**. Density defaults to 8 cells per combat unit; lower values make larger pixel patches. Shared shader controls include `terrain_scale`, `terrain_strength`, `shadow_border`, `light_border`, and `dither_width`. Keep dithering narrow so it reads as a shade transition during movement.

## References and attribution

PixelPlanets is copyright © 2020 Deep-Fold, MIT licensed. Its full license remains at `effects/shaders/PixelPlanets/LICENSE`. The new shader follows its coordinate-quantization, palette-band, value-noise, and dithering approach; it does not change the original planet shaders.

Godot's [spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) documents model/view coordinate conventions, unshaded rendering, and the fact that built-in `TIME` does not pause. This shader uses the project's existing scene-owned animation clock.

## Validation

- Godot 4.6.3, Forward+ / Metal, Apple A18 Pro: compiled and visually inspected at 1280×720 and 960×600, including rotating Generation IV hulls, Generation I comparison, and active Generation II basic/tank/bomber movement, armor, and attacks. No runtime, script, or shader errors during the live review.
- `tests/pixel_enemy_material_smoke.tscn`: **PASS**, exit 0. Confirms cached material reuse, isolated alloy/pixel variants, reversible style selection, mesh-to-hull coordinate mapping under translation/rotation, independent generation colors and hit flashes, flash expiry, and paused reactor time.
- `tests/native_completion_smoke.tscn`: **PASS**, exit 0. Retains coverage for all five ordinary enemy classes, authored colors/emission, model envelopes/sockets, native graph, upgrades, projectile reuse, pools, transitions, and five boss variants. Its material check now expects pixel armor on basic/tank/bomber and the existing alloy shader on fast/sniper.
- `python3 tools/check_native_transition.py`: **PASS**, 292 source/resources. `git diff --check`: **PASS**.
- The short active encounter sample held 60 FPS, 113 draw calls, and zero orphan nodes. This is a small local sample, not a worst-case performance claim.
- The headless smoke runs still emit the previously observed shutdown diagnostics: two DummyShader RID allocations, plus ObjectDB/resource shutdown messages in native completion. The tests finish successfully; these diagnostics are not treated as a warning-free result. The earlier unrelated legacy file-only completion-check failures are documented in `design/void-frontier/README.md`.

The focused smoke scene is also included in `.github/workflows/smoke_tests.yml`. Local persistent test logs: `/tmp/farinuff-pixel_enemy_material_smoke-pixel-pass.log` and `/tmp/farinuff-native_completion_smoke-pixel-pass.log`.
