# Implementation Profile: Unity

Status: porting template; not implemented in this repository

## Recommended mapping

- Simulation: plain C# domain classes or systems independent of `MonoBehaviour`.
- Entity presentation: `MonoBehaviour` views/presenters that consume simulation state.
- Content data: `ScriptableObject` assets generated from the portable YAML catalogs.
- Input: Unity Input System actions mapped to the portable action names.
- 2D collision: `Collider2D`; 3D collision: dedicated primitive colliders on the Combat Plane.
- UI: Canvas, UI Toolkit, or an explicitly selected UI layer; keep menus and accessibility-sensitive text outside the playfield renderer.
- Audio: separate Music, SFX, and UI mixer groups with event IDs matching `08-audio-intent.md`.
- Persistence: versioned JSON or binary schema with an atomic-write and backup strategy.
- Tests: Unity Test Framework for domain rules and PlayMode tests for flow/interaction; a deterministic seed controls acceptance scenarios.

## Port-specific decisions to record

- 2D or top-down 3D presentation
- Virtual resolution and camera mapping
- Prefab/scene ownership boundaries
- Addressables or another asset-loading strategy
- Object-pool implementation
- Windows/Linux/controller support matrix

Do not move portable game rules into scene callbacks merely because Unity makes that convenient.
