# Game Design Document

Status: canonical gameplay reference

## Player fantasy

The player is a lone pilot making an impossible return flight through a hostile CRT-like universe. The ship is fragile enough that movement matters, but expressive enough that skilled boost timing can turn incoming fire into an attack.

## Game at a glance

The player learns the core controls, launches a run, survives increasingly demanding waves, collects XP orbs, defeats bosses, chooses upgrades, and banks salvage for future runs. The first authored objective is to defeat the Tempest Core at Wave 20. A successful Expedition may continue into Endless play.

## Moment-to-moment play

- Move within the visible combat space.
- Aim freely with mouse movement or a right stick.
- Hold fire to attack continuously.
- Use boost to reposition, drift, and reflect eligible enemy projectiles.
- Destroy enemies, collect XP orbs, and choose power-ups or upgrades.
- Read telegraphs and preserve lives through movement rather than waiting for passive defense.

## Run structure

1. The first launch opens Flight School; later launches open the Launch Bay.
2. The player chooses a ship variant, challenge modifiers, and any armed field supply.
3. The run begins with the selected loadout and its derived starting values.
4. Normal waves end when the wave orb target is met.
5. Every fifth wave is a boss wave.
6. Clearing a fifth-wave milestone offers stat allocation.
7. Wave 10 is the first elite-boss milestone and offers an elite upgrade choice.
8. Wave 20 ends the authored Expedition with a choice between Endless and the Hangar.
9. If lives are exhausted, available try-again stocks are offered before final game over.
10. Final game over awards salvage, updates lifetime records, and returns the player to the Hangar/title flow.

## Progression scopes

### Momentary

- Boost state and drift
- Active projectile and hazard state
- Invulnerability windows
- Temporary power-ups
- Combo and current wave meter

### Run-long

- Stat allocation
- Elite upgrades
- Chosen upgrade exclusion
- Current ship build
- Run salvage and modifier multiplier

### Persistent

- High score and best wave
- Salvage wallet
- Hangar unlocks and blueprints
- Ship ownership and selected ship
- Challenge modifier ownership and selection
- Consumable stockpiles
- Lifetime statistics
- Settings and first-run onboarding state

## Controls

The portable action names are the contract. Physical bindings are implementation/profile settings.

| Action | Default keyboard/mouse | Default controller | Intent |
|---|---|---|---|
| `move` | WASD or arrow keys | Left stick | Navigate the Combat Space |
| `shoot` | Hold Space | A or right trigger | Continuous base attack |
| `boost` | Shift | B or left trigger | Burst movement and reflection |
| `aim` | Mouse movement | Right stick | Set firing direction |
| `pause` | Escape | Profile-specific menu button | Pause without consuming an adjacent selection |

An alternate control scheme may use left mouse for `shoot` and Space for `boost`, provided both actions remain unambiguous.

## Difficulty philosophy

Difficulty should come from readable patterns, movement demands, timing, and encounter composition before raw health inflation. Endless mode may add gentle late-game pressure, but it must preserve safe gaps and meaningful player counterplay.

## Feedback philosophy

Every high-value state change should have at least two independent channels of confirmation:

- Boss arrival: warning cue plus banner/telegraph
- Damage: distinct player hit feedback plus life/HUD change
- Deflection: projectile transformation plus metallic/audio confirmation
- Upgrade choice: clear selected state plus build preview or description
- Victory: dedicated presentation and final result state

## Content vocabulary

Use stable terms consistently: **Player Craft**, **Enemy Craft**, **Projectile**, **Combat Space**, **Interaction Range**, **XP Orb**, **Power-Up**, **Run Upgrade**, **Elite Upgrade**, **Salvage**, **Ship Variant**, **Challenge Modifier**, **Expedition**, and **Endless**.

## Out of scope for the first rebuild

- Multiplayer or networked simulation
- Vertical maneuvering
- Permanent visual damage states
- A second unrelated musical identity before the Return Signal motif is established
- Large-scale procedural campaign generation in place of authored encounters
