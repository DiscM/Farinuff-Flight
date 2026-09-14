# Void Frontier

## Art direction

A small cyan exploration craft crosses the remains of an orbital civilization as
violet corruption takes hold. The existing butterfly hulls and Neon Cabinet
interface supply the identity: swept wings, precise light strips, clipped corners,
and warm gold rewards. World scenery supplies scale and history.

- Space: near-black indigo with restrained violet cloud banks and a quiet center.
- Friendly technology: readable blue-gray metal, ice-cyan edges, white energy cores.
- Hostiles: retain class-colored armor for recognition; violet energy unifies their
  rims and muzzle flashes. Existing projectile-motion colors (including the cyan
  boost-breaker diamond) retain their taught meanings.
- Rewards: warm gold. Damage sparks: hot amber. White is a brief peak, not a fill.
- Shapes: player energy draws lines and arcs; metal breaks into plates; void energy
  contracts before dispersing. Large rings belong to shields and major events.
- Scenery: a pixel planet and a broken orbital relay, with sparse drifting debris.
  Background objects have no collision and stay behind the combat plane.

## Implementation plan

1. Establish shared palette and backdrop defaults, reduce persistent screen warp,
   and tune lighting so hulls remain visible without turning every surface emissive.
2. Author an original broken relay and two fragment meshes in Blender. Keep the
   editable source, a reproducible build script, and small GLB runtime exports.
3. Integrate the relay at a distant depth and retain the original pixel planets
   in both menu and combat, as requested during review.
4. Apply a consistent hull material to player variants, modules, drones, and previews.
   Add bounded world-space engine ribbons with stronger boost and reflection response.
5. Distinguish contact sparks, metal fragmentation, void collapse, reflection, and
   hostile muzzle flashes within the existing effect pool and light budget.
6. Validate engine import, existing native contracts, effect reuse/pause/cleanup,
   and inspect actual combat, boost, effects, and menu captures.

## Acceptance

The player must read immediately at 1280 × 720; scenery must stay visually quieter
than bullets; menu and play must share craft materials while retaining their
original pixel planets. Presentation
must respect pause, resize, pooled reuse, and existing visual settings. Gameplay
bounds, collision, movement tuning, upgrade rules, and rewards remain authoritative.

## Implemented

All six steps above are implemented. The pixel planets and their source assets are
unchanged. Combat and menu now use the same subdued galaxy palette and the same
player surface material. Combat clouds gradually become warmer violet over the
Expedition, with an eight-second transition rather than a sudden color change.

The broken relay and fourteen small pieces of distant wreckage add history and
depth. Their exposure is fixed so rotation cannot produce a distracting specular
flash. They have no collisions, cast no shadows, and live behind the flight plane.

Player variants, installed modules, orbitals, escort, and previews share a blue-gray
alloy/cyan-energy treatment. Two world-space engine ribbons keep 28 samples each,
curve through drift, brighten during boost/reflection, and reset on teleports and
inactive play. Existing engine particles remain inert for scene compatibility.
Static menu previews now flush their camera transform before the single render,
fixing an edge-on hull image reproduced when returning from a run.

The existing 64-effect pool and four-light cap now support short directional hits,
warm metal fragmentation, heavier armor breaks, contracting violet splinters, and
a white-cyan reflection accent. Each fragmentation effect uses six Blender meshes
in a MultiMesh. Ordinary hits no longer generate expanding rings. Enemy muzzle
flashes are separated from player muzzle flashes. Core, ring, and shield animation
use scene-owned time so they stop with gameplay. Pool clearing now iterates a
snapshot because despawn callbacks remove live entries synchronously.

## Validation — Godot 4.6.3, macOS / Apple A18 Pro

- `tools/check_native_transition.py`: pass (286 source/resources).
- `tests/frontier_visual_smoke.tscn`: pass. Exercises all effect kinds, returns,
  light release, saturation, pause, ribbon limits/teleport reset, and actual enemy
  death routing. Added to the existing CI smoke loop.
- `tests/native_completion_smoke.tscn`: pass (upgrades, projectile reuse, pools,
  five boss variants, transitions).
- `tests/neon_cabinet_smoke.tscn` and `tests/menu_boot_smoke.tscn`: pass.
- Blender GLB checks: one node per export, 2,412 / 12 / 8 triangles, no cameras or
  extra startup cube, total runtime asset size approximately 137 KiB.
- Live Forward+ inspection: menu, native gameplay, shooting, boost ribbons,
  three destruction families and reflection; checked at 1280 × 720 and 960 × 600.
  An early-wave live sample reported 60 FPS and 155 draw calls. This is a sampled
  observation, not a worst-case performance certification.

Known validation limits: the headless renderer still reports resource/RID cleanup
warnings on shutdown. `tests/check_native_completion.py` reports five legacy
string-matching failures (cache budget, menu Play button location, and three old
reward queue/signal assumptions); running it against HEAD source produces the
same five failures. These are separate from the passing native runtime checks.

`effects-review.png` is a staged in-engine comparison of the actual pooled effects
and engine ribbons. `combat.png` and `menu.png` are runtime captures. These images
and the Blender source are excluded from Godot asset import.
