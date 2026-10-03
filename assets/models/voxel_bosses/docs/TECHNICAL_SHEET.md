# Voxel Bosses — technical inventory

Bounds are measured from the delivered GLB rest scene in Godot coordinates: X width, Y height, Z length. Runtime presentation scale is applied separately. The origin is a central hull datum; bounds can be asymmetric.

| Asset | Triangles | Vertices | Surfaces | Meshes | Dimensions X × Y × Z | Sockets |
| --- | ---: | ---: | ---: | ---: | --- | ---: |
| `boss_assault.glb` | 5,532 | 11,064 | 18 | 6 | 9.52 × 1.61 × 9.80 | 9 |
| `boss_bulwark.glb` | 6,788 | 13,576 | 18 | 6 | 9.52 × 2.07 × 6.16 | 9 |
| `boss_tempest.glb` | 4,568 | 9,136 | 17 | 6 | 9.52 × 1.38 × 9.24 | 11 |
| `boss_void_harbinger.glb` | 5,312 | 10,624 | 16 | 6 | 10.08 × 1.84 × 8.68 | 9 |
| `boss_tempest_core.glb` | 7,728 | 15,456 | 19 | 6 | 9.52 × 2.53 × 8.40 | 11 |
| `tempest_section.glb` | 2,404 | 4,808 | 13 | 6 | 4.48 × 1.61 × 6.16 | 8 |

Total geometry: 32,332 triangles. Every asset has a four-bone rigid skeleton, thirteen moving animation clips, valid UVs and the shared embedded atlas. Hard face normals intentionally split vertices. Surfaces are material partitions; they are not a measured draw-call count.

Exact bone/socket bindings, moving bones per clip, clip durations, material factors, atlas hashes and file digests are recorded in `validation.json`.
