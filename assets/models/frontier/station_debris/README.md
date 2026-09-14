# Pixel-forged station wreckage

Six original Blender assets, sharing the game's PixelPlanets spatial shader.

| Asset | Triangles |
| --- | ---: |
| shattered_orbital_relay.glb | 4,180 |
| station_ring_section.glb | 288 |
| station_habitat_wreck.glb | 602 |
| station_solar_wing.glb | 570 |
| station_truss.glb | 220 |
| station_armor_plate.glb | 176 |

Editable source: `assets/models/frontier/sources/station_debris.blend`.
Rebuild inside Blender: `tools/build_station_debris_blender.py`.
All paths in this document and `manifest.json` are relative to the repository.
The source is an asset-only Blender library and preserves other open scenes.

Exports use meters and glTF Y-up, flat normals, identity object transforms, and
four or five shared material roles per mesh. No textures, animation, cameras,
lights, physics or runtime asset generation. The original small VFX fragments
remain separate from this scenery set.

`effects/frontier_landmarks_3d.gd` uses the relay and a bounded set of eighteen
pieces cycling through all five fragments and six companion space props. The
whole field falls slowly and holds still during boss encounters. The shared material adapter uses
instance exposure, so it never dims enemies through their material cache.
`design/station-debris/STYLE_REFERENCE.md` records the visual rules.

Review scene: `scenes/station_debris_review.tscn`.
