# 3D Ship Mockups

These Mk II `.glb` models are polished runtime assets for Farinuff Flight's
2.5D rendering pipeline. They use continuous lofted hulls, closed beveled
armor, welded indexed vertices, weighted smooth normals, embedded
PBR/emissive materials, and named empty nodes for weapon, engine, upgrade,
shield, core, and encounter-specific sockets.

Player and regular-enemy models:

- `player_ship_mockup.glb` — white/cyan modular player fighter
- `basic_enemy_mockup.glb` — compact crimson interceptor
- `fast_enemy_mockup.glb` — narrow orange pursuit ship
- `bomber_enemy_mockup.glb` — broad green heavy bomber
- `tank_enemy_mockup.glb` — purple armored bulwark
- `sniper_enemy_mockup.glb` — cyan long-barrel sniper

Player upgrade models:

| Asset | Installed module | Triangles |
| --- | --- | ---: |
| `player_upgrade_twin_cannons.glb` | Paired forward cannons | 60 |
| `player_upgrade_auto_aim.glb` | Dorsal targeting sensor | 32 |
| `player_upgrade_hull_plating.glb` | Paired armor shells | 52 |
| `player_upgrade_afterburner.glb` | Auxiliary engine pair | 48 |
| `player_upgrade_spread_shot.glb` | Wing-tip spread emitters | 40 |
| `player_upgrade_shield_burst.glb` | Paired shield projectors | 52 |
| `player_upgrade_magnet_field.glb` | Induction rails | 40 |
| `player_upgrade_overclock.glb` | Dorsal overclock reactor | 38 |
| `player_upgrade_rear_gunner.glb` | Rear-facing cannon | 32 |
| `player_drone_escort.glb` | Standalone escort craft | 60 |

All nine mounted modules total 394 triangles. A fully upgraded player hull is
644 source triangles including the 250-triangle base ship. Every component is
authored in the base hull's local coordinate space, so upgrades snap directly
to their final transform without bobbing, rolling, or attachment tweening.

Boss models:

| Asset | Visual identity | Triangles | Footprint (X × Z) |
| --- | --- | ---: | ---: |
| `boss_assault_mockup.glb` | Assault Wing spearhead | 322 | 9.96 × 9.74 |
| `boss_bulwark_mockup.glb` | Bulwark Array shield hull | 342 | 10.06 × 5.97 |
| `boss_tempest_mockup.glb` | Tempest Fork four-vane hull | 312 | 9.58 × 9.58 |
| `boss_void_harbinger_mockup.glb` | Elite crowned Harbinger | 374 | 10.01 × 8.47 |
| `boss_tempest_core_mockup.glb` | Wave 20 command core | 364 | 10.12 × 8.62 |
| `tempest_section_mockup.glb` | Reusable destructible orbital section | 84 | 2.36 × 4.19 |

The regular ships are approximately 175–265 triangles. The five full bosses
are 312–374 triangles, and the reusable Tempest section is 84 triangles. All
models use backface culling. Engine casings and nozzles point aft along
positive Z instead of being camera-facing discs. `manifest.json` records the
exact mesh statistics and socket positions.

The boss footprints are authored at their gameplay size—roughly 9.5–10.5
model units across their dominant axis at the current 11 px/model-unit render
scale. Scaling is baked into the vertices and sockets rather than left as a
root-node transform. The Tempest section is approximately 2.4 × 4.2 model
units to match the orbiting/destructible section nodes.

The models use Godot's conventional Y-up space. Their noses face negative Z,
making them suitable for a camera looking down from positive Y.

## Shader integration studies

`tests/shader_3d_mockups.tscn` applies an in-engine 3D translation of the
current visual language without changing any gameplay scenes or the source
GLBs. The study includes:

- `shader_previews/shader_3d_gameplay_mockup.png` — a top-down encounter using
  the galactic backdrop, glowing projectiles, class outlines, and CRT pass
- `shader_previews/shader_3d_evolution_mockup.png` — Generations I–IV progressing
  from body emission through circuits, heat veins, and apex interference
- `shader_previews/shader_3d_fleet_mockup.png` — all six authored colorways with
  Fresnel energy rims and object-space circuit patterns

Open the scene directly for an animated look-development view. To capture a
specific board at 1280×720:

```sh
godot --path . --resolution 1280x720 \
  res://tests/shader_3d_mockups.tscn -- \
  --shader-mockup-capture gameplay
```

Replace `gameplay` with `evolution` or `fleet` for the other boards.

## Runtime integration

The player, all nine mounted player upgrades, Drone Escort, all five regular
enemy archetypes, all five boss identities, and the Tempest Core's
destructible sections now render through
`effects/ship_render_layer_3d.tscn` during gameplay. One transparent shared
SubViewport synchronizes the GLB transforms to the existing Area2D actors, so
movement, collisions, weapons, evolution stages, boss phases, and spawn logic
remain 2D. The original Sprite2D/custom-draw nodes stay alive as state drivers
but suppress only their own pixels.

The runtime layer includes:

- generation-aware circuits, heat veins, apex interference, and class colors
- emissive silhouette outlines and paired animated engine trails
- player/enemy hit modulation and player invincibility blinking
- immediate GLB upgrade visibility with per-module neon colors and no
  animation-frame transform interpolation
- orthographic screen-to-world projection that updates with viewport resizing
- automatic proxy registration and cleanup as ships spawn and despawn
- boss-specific palettes, phase tints, and reusable 3D Tempest modules
- retained 2D boss muzzles, cracks, smoke, telegraphs, and black-hole backdrop
- frozen 3D animation while gameplay is paused
- shared cached materials and disabled 3D shadows for GL Compatibility

The elite-upgrade cards and fully upgraded main-menu ship reuse
`PlayerShipAssembly3D` in static transparent SubViewports, so those surfaces
match the gameplay models instead of falling back to composite sprites.

`shader_previews/in_game_3d_integration.png` is captured from the real game
scene using `tests/ship_render_layer_3d_smoke.tscn`.
`shader_previews/in_game_boss_3d_integration.png` exercises every boss identity
and the Tempest shield array through `tests/boss_render_layer_3d_smoke.tscn`.
`shader_previews/in_game_player_upgrades_3d.png` shows the fully upgraded player
and escort through `tests/player_upgrade_3d_smoke.tscn`.

Regenerate them with:

```sh
python3 tools/generate_mockup_models.py
```

Pillow is optional; when available, the script also regenerates the labeled
images in `previews/`. `godot_fleet_showroom.png` is captured from the real
Godot renderer through `tests/mockup_models_preview.tscn`.
