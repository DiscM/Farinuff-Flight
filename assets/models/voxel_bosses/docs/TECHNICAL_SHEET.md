# Voxel Bosses — technical inventory

Bounds are measured from the delivered GLB rest scene in Godot coordinates: X width, Y height, Z length. Runtime presentation scale is applied separately. The origin is a central hull datum; bounds can be asymmetric.

| Asset | Triangles | Vertices | Surfaces | Meshes | Dimensions X × Y × Z | Sockets |
| --- | ---: | ---: | ---: | ---: | --- | ---: |
| `boss_assault.glb` | 5,564 | 11,128 | 16 | 6 | 9.52 × 1.96 × 9.80 | 9 |
| `boss_bulwark.glb` | 6,796 | 13,592 | 18 | 6 | 9.52 × 2.52 × 6.16 | 9 |
| `boss_tempest.glb` | 4,804 | 9,608 | 15 | 6 | 9.52 × 1.68 × 9.24 | 11 |
| `boss_void_harbinger.glb` | 5,504 | 11,008 | 16 | 6 | 10.08 × 2.24 × 8.68 | 9 |
| `boss_tempest_core.glb` | 7,908 | 15,816 | 17 | 6 | 9.52 × 3.08 × 8.40 | 11 |
| `tempest_section.glb` | 2,496 | 4,992 | 11 | 6 | 4.48 × 1.96 × 6.16 | 8 |

Total geometry: 33,072 triangles. Every asset has a four-bone rigid skeleton, four moving animation clips, valid UVs and the shared embedded atlas. Hard face normals intentionally split vertices. Surfaces are material partitions; they are not a measured draw-call count.

Exact bone/socket bindings, moving bones per clip, clip durations, material factors, atlas hashes and file digests are recorded in `validation.json`.
