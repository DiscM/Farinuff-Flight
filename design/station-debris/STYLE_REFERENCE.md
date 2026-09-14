# Pixel-forged station debris

Written style authority: `design/pixel-enemies/README.md`,
`design/void-frontier/README.md`, and
`effects/shaders/models/pixel_planet_enemy_3d.gdshader` (paths from repository root).
These assets are authored as geometry in Blender, without generated images or
external models. The palette and provenance are recorded in the asset manifest.

## Fixed style rules

- Flat, beveled metal with clipped corners, broad armor panels and sparse ribs.
- Actual PixelPlanets fleet shader: three stepped shade colors, violet shadows,
  irregular block-shaped shade boundaries, narrow checker dithering.
- Slate armor `#687b96`, cut edges `#9cacc0`, violet recesses `#30344e`, faded cyan
  inlays `#639eab`, small weathered brass fittings `#a48a68`.
- No smooth metallic glare or luminous reactor centers. Cyan is painted inlay.
- Each piece has a distinct damaged silhouette. Habitat ribs, ring bands,
  panel corners and truss widths repeat the parent relay's construction.
- Attached braces and conduits terminate at the station or at an exposed break.
- Pattern coordinates stay attached to each piece as it turns; large and small
  pieces share a similar on-screen pixel size.
- Gameplay exposure remains below ships, shots and pickups. All scenery stays
  behind the combat plane, with no collision, shadow casting or extra lights.

## New geometry

One shattered orbital relay, plus five fragments: ring section, habitat wreck,
solar wing, exposed truss and armor plate. Fragment shapes are derived from the
same Blender geometry functions used to construct the larger station.

The companion space debris set extends these rules to a derelict satellite,
ruptured cargo pod, spent fuel tank, discarded engine bell, broken survey dish,
and faceted asteroid. Manufactured pieces repeat the clipped armor, cyan inlays
and brass fittings. The asteroid keeps broad slate facets with sparse mineral
patches, without artificial panel markings. Source: `sources/space_debris.blend`
under `assets/models/frontier/`; rebuild: `tools/build_space_debris_blender.py`.
Its six meshes contain 2,460 triangles in total and share the same material adapter.

## Review

Use `scenes/station_debris_review.tscn` for the actual exported meshes and shared
shader. This detail view raises exposure and scale for inspection; press R to
rotate. Check the native gameplay scene separately at its normal exposure.
The companion six-prop gallery is `scenes/space_debris_review.tscn`.
Reject smooth shading, free-floating attached details, overbright cyan, or
surface patterns that slide while a piece turns.

## Validation and captures

Validated in Godot 4.6.3, Metal Forward+, at 1920×1080 and 960×600.
`detail-review.png` shows the exported set at inspection scale and full exposure;
`combat-1080p.png` shows normal scenery exposure with six staged enemies in a
practice session. `space-debris-review.png` shows the six companion props with the
production shader at inspection scale. The tutorial panel was hidden for the
combat capture. Gameplay uses
0.78 exposure for the relay and 0.68 for fragments; these remain below combat cues.

- All twelve Blender meshes are closed and contain no degenerate faces. GLB checks
  verify identity transforms, embedded buffers, triangle counts and file hashes.
- Live checks confirm all eleven fragments are represented in the eighteen-piece
  field, use the existing pixel shader, retain mesh-local pattern coordinates,
  share materials safely, and pause and drift normally. There are no scenery
  colliders, emissive cores or shadow casters. Resize preserves screen anchors.
- `background_drift_smoke.tscn`, `frontier_visual_smoke.tscn`, and
  `pixel_enemy_material_smoke.tscn`: PASS, exit 0.
  The previously documented two shader RID shutdown diagnostics remain.
- The drift test exercises all five actual practice boss types, weapon-pod
  destruction, both phase changes, pause/unpause, and actual defeat. It also checks
  offscreen wrapping and long-frame/subdivided-frame travel equivalence. Live
  checks confirm frozen screen positions during boss camera follow and preserved
  viewport fractions after resize. Resume advances by normal frame time only.
- `tools/check_native_transition.py`: PASS. No script or shader errors in the
  live asset review and practice checks. R toggles rotation in the review scene.
