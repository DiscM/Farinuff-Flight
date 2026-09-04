# Native 3D Gameplay Transition

**Status:** revised 2026-09-04; supersedes the temporary parallel-actor migration decision.

## Decision

Farinuff Flight is transitioning fully to native 3D gameplay. The native implementation is the development target now. Keeping a working 2D gameplay runtime, maintaining 2D/3D parity, and preserving legacy behavior exactly are no longer requirements.

The [Native 3D Transition Guide](../3d-migration-checklist.md) describes current progress and suggested work. Its ordering is advisory; implementation can combine integration, actor changes, cleanup, and polish when useful.

## Rationale

The parallel migration approach helped establish native actors and flight-space foundations. Continuing to carry parity checks, frozen-reference behavior, isolated approval gates, and compatibility paths now adds work that does not advance the integrated 3D game. Existing code can inform design without constraining the replacement to inherited bugs or obsolete architecture.

Git history preserves the earlier decision, implementation records, and legacy source when historical reference is useful.

## Implementation direction

- Build one native gameplay scene and one set of combat systems, with a `Camera3D`, native actor wrappers, and scene-owned managers.
- Integrate the production spawners, encounters, upgrades, rewards, bosses, and run lifecycle. Move the active gameplay entry to native 3D as part of that work; do not wait for complete legacy feature parity or polished effects.
- Adapt gameplay and timing to the native game. Fix inherited problems, including the Sniper rail cadence conflict, and document meaningful behavior changes.
- Remove obsolete 2D gameplay actors, duplicate coordinators, adapters, proxy rendering, and migration scaffolding as references are replaced. Routine cleanup is part of the transition and has no separate parity or legacy-approval gate. Check dependencies before deletion and retain resources still used by the game.
- Keep menus, HUD, backdrop, and screen-space presentation in 2D where useful. Fully 3D gameplay does not require rebuilding UI as 3D objects.
- Reuse `GameManager`, `SignalBus`, the existing pool lifecycle, and useful shared data. Avoid abstractions whose only purpose is keeping both combat runtimes alive.

## Current technical defaults

Use Forward+, direct native viewport rendering, the existing fixed orthographic camera, and X/Z-plane combat at `Y=0`. `FlightSpace3D` provides input/projection/bounds conversions. Actor wrappers own gameplay collision, GLB visuals, and stable sockets; imported models remain replaceable visual resources.

Use bounded pools for high-churn gameplay objects, shared materials/resources, preloading before combat use, and transition-time warm-up. The established scale, primitive hitboxes, shared lighting, and procedural animation are practical starting points that can evolve with the native game.

Native world events use `Vector3`; UI layout remains `Vector2`. Remove temporary compatibility conversions when native callers replace them. The running game should contain one combat implementation, while retained 2D canvas presentation remains supported.

## Validation and continuation

Validate intended 3D behavior with code inspection, targeted runtime diagnostics, and relevant tests. Focus on the integrated run, collision/damage correctness, progression, pause/retry/transitions, attack cancellation, pooling, resource cleanup, runtime errors, and performance. Target 60 FPS at 1920×1080 in heavy encounters.

A matching 2D run, dedicated migration suite, visual playtest, asset-review scene, or per-slice user approval is not a prerequisite to continue. Record unverified areas honestly and prioritize a functional complete game over procedural migration milestones.
