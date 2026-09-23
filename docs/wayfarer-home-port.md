# Wayfarer Crescent Home Port

Wayfarer is the game's start menu. Startup, completed runs, and abandoned expeditions return directly to this flyable home port. First-time pilots remain in the world with Flight School selected as their waypoint. Practice return requests reopen the appropriate local service.

The production port uses the complete **Crescent Harbor** Blender composition: the open habitation ring, port-control tower, five service relay islands, articulated cable bundles, and all fourteen authored spacecraft. Nine craft follow the original through-traffic routes; five remain attached to their berths. The previous station and circular four-craft support fleet remain available as source assets but are no longer instantiated by the home port.

![Crescent Harbor in the game](../design/home-base/game-crescent/crescent-homeport.png)

## Flight and services

The complete composition uses **2× runtime scale** while the player ship keeps its existing size. The pilot flies at source height 11.5, with the composition offset so that the gameplay plane remains Y = 0. Padded blockers protect towers, station housing and relay machinery while preserving the arrival basin and gaps through the ring. The camera follows the pilot around the wider harbor, and the pilot locator stays readable through structures.

| Station section | Service |
| --- | --- |
| Launch Bay | Choose a ship, configure challenges, and start an expedition |
| Hangar | Buy permanent systems, hulls, blueprints, and supplies |
| Flight School | Read the flight briefing and enter live practice |
| Route Map | Explore discovered sectors and the expedition route |
| Archives | Review recovered signals |
| Settings | Controls, sound, display, and accessibility |

Fly within 12 world units of a section marker and press the displayed interaction control, normally `E` or the gamepad south button. The control adapts to remapped flight bindings. Directory buttons select waypoints; they cannot open distant services. A local service pauses the world. Return to Station restores the pilot's position and updates the visible hull if the selected ship changed. Nested service navigation and confirmation dialogs retain their usual behavior.

Movement and boost retain their normal bindings. Mouse wheel, `−` / `+`, or available gamepad shoulders adjust the camera. Flight remaps take priority over service and zoom shortcuts. Escape opens pause, with Resume and Save & Quit. Window-close requests use the same save-aware exit flow, including recoverable save failures. The port itself never starts combat, spends supplies, or changes progression.

The deprecated Command Deck cannot be opened from production service panels. `ui/main_menu.tscn` remains a compatibility redirect. Production returns and the bounded resource cache use `scenes/home_base.tscn` directly.

## Authored motion and rendering

The complete GLB contains 183,624 triangles and sixteen transform-animation clips on a twenty-second timeline. Station corrections, flexible cable sleeves, traffic routes, robotic arms, scanners, cooling rotors, navigation lights and correction exhaust all play together. Parked ships inherit their station's motion instead of drifting away from their couplers.

Godot's importer adds rest-pose tracks for channels owned by other clips. `systems/crescent_harbor_visuals.gd` combines the authored moving tracks into one private synchronized loop, choosing animated channels over those filler tracks. Imported source animations and shared materials remain unchanged. The adapter advances only during active flight; pause and local services freeze its phase. Reduced Motion freezes the authored environmental movement at its current pose and resumes it when disabled.

The thirteen imported material roles retain their original 64×64 pixel-plating textures embedded in the GLB. Runtime presentation keeps their base-color and emission maps, flat voxel faces, and the existing scene lighting. Station structures and spacecraft cast shadows; 130 cable meshes and 24 correction-exhaust meshes omit shadow casting to reduce rendering work. No generated replacement material or procedural circular traffic overrides the authored composition.

## Source and integration

- `assets/models/wayfarer_crescent/source/wayfarer_crescent.blend`: editable Blender source.
- `assets/models/wayfarer_crescent/meshes/wayfarer_crescent.glb`: complete production composition.
- `systems/crescent_harbor_visuals.gd`: synchronized imported animation adapter.
- `systems/crescent_harbor_layout.gd`: shared scale, flight bounds, placement, clearance and camera framing.
- `systems/home_port_sections.gd`: six physical service berths.
- `assets/models/wayfarer_crescent/docs/README.md`: rebuild commands and delivery inventory.

All meshes and pixel textures were authored locally in Blender 5.2.1 from the approved Crescent concept. No third-party meshes or paid generation services were used. The asset remains independently editable and exportable; runtime integration does not rewrite its GLBs or Blender source.

## Verification

`python3 tools/check_crescent_harbor.py` checks the delivered geometry, bounds, UVs, materials, embedded image data, sixteen animation clips, scene groups and recorded asset hashes. The delivery also retains independent Blender source/re-import, cable attachment, parked-fleet, loop and camera-route reports. The authored traffic report checks all fourteen ships at 1,921 quarter-frame samples with no intersections; that is sampled source-geometry evidence, not a continuous collision proof or a runtime performance result.

After importing in Godot, run `python3 tools/run_smoke_tests.py home_base_smoke home_base_ui_smoke` with `GODOT_PATH` set to the configured executable. Tests use private save profiles. Runtime checks preserve movement, boost, remaps, camera framing, six proximity services, local panel routing, pause/focus, safe quitting and unchanged progression. Crescent checks cover the complete composition, fourteen fleet roots, nine moving routes, actual target movement from all sixteen clips, parked berth attachment, clear service approaches, and reduced-motion/pause behavior. The separate UI test covers both input families and 130% text at 1280×720.

The final integration checks passed five focused scenes: `home_base_smoke`, `home_base_ui_smoke`, `menu_boot_smoke`, `resource_cache_smoke`, and `input_handoff_smoke`. The home-port rerun includes the final lamp-post blockers and connected flight access to all six service berths. The Crescent asset validator passed with no warnings, and the native-transition resource check passed across 392 files.

Live review used Godot 4.6.3 Forward+ on Metal, on an A18 Pro at 2560×1440. Keyboard interaction opened the nearby Launch Bay, the local Hangar rendered correctly, and Escape returned to flight. No new runtime errors appeared during that review. A single observation during animation was approximately 43 fps at 1440p; this is a snapshot, not a repeatable benchmark or a performance target.

Headless checks verify behavior and resource integration. Live Blender and Godot review establish appearance; they do not constitute a target-hardware performance certification.
