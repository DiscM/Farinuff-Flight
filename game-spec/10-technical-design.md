# Technical Design Contract

Status: engine-neutral architecture contract

This document defines boundaries that should remain stable when the game moves between engines or presentation formats. Concrete APIs belong in `implementations/`.

## Layer boundaries

```text
Input adapters
      ↓ abstract actions
Simulation / run state  ←→  Content data and seeded randomness
      ↓ events and read models
Presentation adapters: renderer, UI, audio, VFX, camera
      ↓
Platform services: save, files, timing, analytics, export
```

### Simulation owns

- Player and Enemy Craft state
- Projectiles, hazards, collisions, timers, cooldowns, and damage
- Waves, bosses, rewards, upgrades, and progression
- Run seed, run state, and finalization guards
- Serializable persistent state changes

### Presentation owns

- Sprites, models, animation playback, camera, particles, shaders, and screen effects
- HUD and menu layout
- Audio playback, mixing, and variation
- Input-device plumbing after it has been converted to portable actions

Presentation objects must not become the authoritative source of score, lives, wave state, collision, or persistent progression.

## Input contract

Define actions once and map physical devices to them in one adapter:

`move`, `aim`, `shoot`, `boost`, `pause`, `confirm`, `cancel`, `next`, `previous`, and `toggle_help`.

The action layer must support held, pressed, released, analog value, and pointer position where relevant. A port may use different physical bindings, but the action meanings must remain stable.

## Content and asset loading

- Load content through stable IDs and a manifest/catalog.
- Keep tuning data separate from scene/prefab/actor definitions.
- Prepare or import assets offline when possible.
- Avoid a synchronous first-use load during combat.
- Warm pools and expensive shader/material paths before the first encounter that needs them.
- Make development previews use the same content definitions as production.

## Collision and interaction

- Use simplified, dedicated Gameplay Hitboxes.
- Keep visual geometry and collision geometry separate.
- Define collision ownership so one event has one damage authority.
- Define interaction ranges and arming rules separately from draw/camera range.
- Ensure pause and reset disable active interactions consistently.

## Randomness and determinism

- Store or expose a run seed for reproducible tests.
- Do not use presentation-only randomness to determine simulation outcomes.
- Separate random streams for content selection, encounter behavior, drops, and cosmetic variation where practical.
- Provide a debug mode that can freeze or force specific content without corrupting persistent state.

## UI and accessibility boundary

- Keep text-heavy and accessibility-sensitive UI outside the playfield renderer by default.
- UI reads simulation state through events or read models.
- Modal state owns focus, selection, confirmation, and input capture.
- A paused run cannot advance because an interface animation or background process continues independently.

## Persistence boundary

- Save persistent state, not renderer objects or live scene graphs.
- Version every serialized payload.
- Use complete-write then promote semantics with a recoverable backup.
- Preserve unsupported future versions rather than overwriting them.
- Add a migration for every supported schema change.

## Debug and performance surfaces

Every implementation should be able to inspect, at minimum:

- Current state and wave
- Player lives, upgrades, modifiers, and cooldowns
- Active enemies, Projectiles, hazards, and pooled objects
- Run seed and random stream state where applicable
- Frame time, memory, object count, and pool growth
- Save schema/version and last persistence result

## Portability acceptance

- A headless or simulation-only runner can execute the core acceptance scenarios.
- Replacing the renderer does not require rewriting wave, reward, or save rules.
- Replacing the engine does not change portable content IDs.
- Any exception is documented in the target implementation profile.
