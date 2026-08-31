# Implementation Profile: Web

Status: porting template; not implemented in this repository

## Recommended mapping

- Runtime: Phaser for a 2D presentation, or Three.js/React Three Fiber for a 3D presentation.
- Simulation: TypeScript modules independent of Canvas/WebGL objects and React components.
- Input: one action mapper for keyboard, pointer, and gamepad APIs.
- UI: DOM overlays for menus, HUD text, settings, and accessibility-sensitive controls.
- Content data: YAML/JSON catalogs converted into typed TypeScript data at build time.
- 3D assets: GLB/glTF with a documented budget; 2D assets use a virtual-resolution policy.
- Audio: Web Audio or the selected engine's audio layer, with separate Music/SFX/UI buses.
- Persistence: versioned localStorage or IndexedDB data with a backup/export option where practical.
- Tests: browser automation plus deterministic simulation tests; capture screenshots only as a supplement to behavior assertions.

## Port-specific decisions to record

- Browser support and minimum GPU/device class
- Virtual resolution and resize behavior
- Pointer-lock or pointer-aim policy
- Autoplay/audio-unlock flow
- Loading and asset-cache strategy
- Tab visibility, pause, and resume behavior
- Offline/PWA behavior if supported

DOM and WebGL state must not compete as separate sources of truth for the same gameplay rule.
