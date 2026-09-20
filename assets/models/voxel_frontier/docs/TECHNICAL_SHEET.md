# Voxel Frontier — technical inventory

Measurements are read from the delivered GLB rest scene. X is width, Y is height, Z is length in Godot. Dimensions precede the game scene's per-role presentation scale.

| Asset | Triangles | Vertices | Surfaces | Mesh nodes | Dimensions X × Y × Z |
| --- | ---: | ---: | ---: | ---: | --- |
| `basic_enemy.glb` | 1,592 | 3,184 | 12 | 6 | 4.75 × 0.75 × 5.50 |
| `fast_enemy.glb` | 1,612 | 3,224 | 10 | 6 | 2.42 × 0.66 × 8.14 |
| `bomber_enemy.glb` | 2,500 | 5,000 | 14 | 6 | 8.12 × 0.84 × 5.04 |
| `tank_enemy.glb` | 2,960 | 5,920 | 13 | 6 | 5.88 × 1.40 × 5.88 |
| `sniper_enemy.glb` | 1,608 | 3,216 | 10 | 6 | 2.64 × 0.72 × 8.40 |
| `relay_fragment.glb` | 1,040 | 2,080 | 5 | 1 | 5.32 × 0.84 × 5.04 |
| `solar_fragment.glb` | 952 | 1,904 | 5 | 1 | 4.76 × 1.40 × 3.08 |
| `cargo_wreck.glb` | 1,208 | 2,416 | 4 | 1 | 3.64 × 1.40 × 2.52 |
| `engine_wreck.glb` | 1,348 | 2,696 | 4 | 1 | 2.52 × 2.52 × 3.64 |
| `hull_fragment.glb` | 876 | 1,752 | 4 | 1 | 4.20 × 0.84 × 3.08 |
| `asteroid_cluster.glb` | 1,016 | 2,032 | 4 | 1 | 3.64 × 2.52 × 3.08 |

Surfaces are material partitions; they are not a measured GPU draw-call count. Hard face normals intentionally split corner vertices.

The complete set contains 16,712 triangles. Every GLB embeds the same 256 × 256 RGB atlas and supplies TEXCOORD_0 UVs on every surface.

Each enemy has one four-joint skeleton and four clips: `cruise`, `hit`, `windup`, `attack`. All vertices carry one full-weight bone influence. Debris contains no skeletons or animation clips.

The static validator requires nondegenerate geometry and UV triangles, finite coordinates, valid material tints and atlas references, and no collision meshes/cameras/lights. The exact check policy, all material factors, texture digests, and animation durations are in `validation.json`.
