# Implementation Profile: Godot Native 3D

Status: migration target/reference slice

## Scope and fidelity

- Engine: Godot 4.6.x
- Renderer: Forward+
- Presentation: fixed top-down 3D over a horizontal Combat Plane
- Reference entry: `scenes/native_3d_gameplay.tscn`
- The target preserves the portable gameplay rules; native 3D changes presentation, coordinate mapping, asset runtime format, and collision API.

## Coordinate and camera mapping

- Screen right maps to world +X.
- Screen down maps to world +Z.
- World Y is reserved for visual height and effects in the first slice.
- Initial scale: 11 baseline screen pixels per model/world unit.
- Camera: fixed orthographic, near-top-down, approximately 70° above the Combat Plane.
- Gameplay collision occurs on the X/Z plane and uses dedicated primitive `Area3D` proxies.
- Mouse aiming intersects the camera ray with the Combat Plane; movement maps input through the camera basis rather than cursor position.

## Simulation and scene ownership

- Keep simulation state outside the renderer and preserve the same portable event meanings.
- Use wrapper scenes to own gameplay state and visual child hierarchies.
- Use pooled Projectiles, hazards, XP Orbs, and effects where needed.
- Never instantiate the 2D and native 3D actor versions in the same validation run.

## Presentation and assets

- GLB/glTF assets are the canonical runtime craft format.
- Imported animation is optional; wrapper-local procedural transforms and animation tracks may drive gameplay presentation.
- Reuse a shared environment/lighting rig across native 3D gameplay scenes.
- Retain the HUD, backdrop, and screen-space post-processing as 2D layers until an explicit design decision replaces them.
- Asset loading begins before the encounter that needs the asset; first combat use must not synchronously load a new role.

## Input, UI, and persistence

- Preserve portable action names and current keyboard/controller semantics.
- Keep text-heavy HUD, menus, and accessibility-sensitive controls in CanvasLayer/Control surfaces.
- Reuse the same save schema and run-state boundaries as the 2D profile.

## Verification gate

- Gameplay parity and explicit manual playtesting are required before replacing a 2D actor.
- Validate cold-start time, first-use hitches, pool growth, memory, frame time, and full-load visual readability.
- The detailed historical migration evidence is in [`docs/3d-migration-checklist.md`](../../docs/3d-migration-checklist.md) and ADRs 0001–0002.
