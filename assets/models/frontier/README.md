# Original Void Frontier models

The active station scenery now uses the cohesive six-model set in
`station_debris/README.md`, with editable source `sources/station_debris.blend`.
Six companion props live in `space_debris/README.md`, with editable source
`sources/space_debris.blend`. The whole field drifts and stops during boss fights.
The original relay below is retained; the small fragments remain in use by VFX.

Authored in Blender 5.2.1 for Farinuff Flight. No external models or textures.

| Asset | Triangles | Use |
| --- | ---: | --- |
| broken_orbital_relay.glb | 2,412 | Distant broken station, four material roles |
| hull_fragment.glb | 12 | Drifting scenery and pooled metal fragments |
| void_splinter.glb | 8 | Pooled violet collapse splinters |

Editable source: `sources/void_frontier.blend` (excluded from Godot import).
Rebuild: Blender Python `tools/build_void_frontier_blender.py`. The script creates
a separate scene and exports only the selected asset from that scene. Blender
Z-up is converted to glTF Y-up. No physics, lights, cameras, or animation exported.
