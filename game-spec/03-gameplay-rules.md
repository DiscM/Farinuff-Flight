# Gameplay Rules and Simulation Contract

Status: canonical rules with values carried from the reference build

This document describes simulation behavior without assuming a particular engine, physics API, or renderer.

## Units and coordinate mapping

- Use **design units** for portable tuning.
- The current reference treats baseline screen pixels as design units at a 1280×720 reference display.
- A port may map design units to world units, tile units, or a virtual canvas, but movement ratios, timings, and hitbox relationships must remain equivalent.
- The Combat Space is bounded. Visual height or presentation depth must not create an additional gameplay axis unless the design is explicitly revised.

## Player movement

Reference tuning:

| Parameter | Value | Meaning |
|---|---:|---|
| Base speed | 280 design units/s | Terminal movement speed |
| Acceleration | 12 | Normal acceleration factor |
| Drag | 14 | Normal velocity decay |
| Brake threshold | 0.1 input | Minimum opposing input to brake |
| Brake minimum speed | 100 design units/s | Speed required for braking behavior |
| Brake drag | 22 | Opposing-input drag |
| Aim stick deadzone | 0.4 | Right-stick deadzone |
| Aim reticle distance | 60 design units | Reference facing marker distance |

Movement must be frame-rate independent, bounded to the visible Combat Space, and independent of cursor position when using keyboard or left-stick movement.

## Boost and reflection

| Parameter | Value |
|---|---:|
| Boost duration | 0.68 s |
| Reference boost distance | 340 design units |
| Boost steering rate | 10 |
| Boost cooldown | 0.85 s |
| Reflection radius | 74 design units |
| Reflection cooldown | 0.35 s |
| Reflection cooldown reduction per prior reflection | 0.08 s |
| Minimum reflection cooldown | 0.10 s |
| Chain threshold | 3 reflections |
| Chain window | 0.18 s |
| Post-boost slide duration | 0.40 s |

Rules:

- Boost provides burst movement and a temporary reflection opportunity.
- Only eligible incoming Projectiles within Interaction Range can be reflected.
- A Projectile is reflected at most once per reflection interaction.
- A reflected Projectile becomes player-aligned and may damage Enemy Craft through the normal projectile damage route.
- Reflected speed is `max(incoming_speed × 1.35, 560 design units/s)`.
- Reflection must not alter the Player Craft gameplay hitbox.
- Boost, reflection cooldown, and chain windows freeze while paused.

## Weapons and damage

Reference base weapon tuning:

| Parameter | Value |
|---|---:|
| Base fire interval | 0.22 s |
| Base damage | 1 |
| Minimum fire interval | 0.05 s |
| Projectile speed | 800 design units/s |
| Muzzle clearance | 3 design units |

- Held `shoot` produces repeated fire at the current fire interval.
- Fire-rate bonuses reduce the interval, subject to the minimum.
- A collision applies damage through one authoritative route; the same hit must never be counted twice.
- Gameplay Hitboxes are independent from visual meshes/sprites and remain stable when upgrades add hardware or effects.
- Projectiles, hazards, and reward objects should be pooled or reused when the implementation benefits from it, but pooling must not change observable behavior.

## Damage and invulnerability

Reference damage windows:

| Source | Invulnerability |
|---|---:|
| Player contact | 3.0 s |
| Enemy projectile | 2.0 s |
| Hostile ordnance/hazard | 2.0 s |
| Shield-protected hit | 1.5 s |

- An accepted hit consumes exactly one life and resets the combo.
- A fatal hit emits `game_over` exactly once.
- Active invulnerability rejects additional damage without creating extra life loss or duplicate events.
- The Player Craft remains observable after a fatal hit until the result flow decides what to do.

## Score, combo, and XP

- Each Enemy Craft has base points.
- On a kill, `score += base_points × current_combo` after incrementing the combo for that kill.
- Player damage resets combo to zero.
- Enemies may drop XP Orbs based on their content data.
- Collecting XP Orbs fills the wave meter and the life meter.
- Every 12 collected orb-value units grants one life; excess carries over.

## Waves and generations

- A wave completes when its orb target is reached, unless a boss is active.
- Orb target: `floor(10 + wave_number × 1.30)` before challenge modifiers.
- Surplus orb progress carries to the next wave, capped at half of the next wave's target.
- Every fifth wave is a boss wave.
- Clearing a fifth-wave milestone grants three stat allocation points.
- Regular enemy generations change after Waves 5, 10, and 15:
  - Gen I / Standard: Waves 1–5
  - Gen II / Augmented: Waves 6–10
  - Gen III / Warform: Waves 11–15
  - Gen IV / Apex: Wave 16 onward
- Endless pressure after Wave 16 adds up to ×2.0 regular-enemy health and ×1.30 regular-enemy speed through gentle per-wave drift.
- Spawn interval: `max(1.55 - (wave_number - 1) × 0.045, 0.48)` seconds before modifiers.

## Upgrades and power-up scope

- Temporary Power-Ups affect the current run and normally have a duration or one-shot effect.
- Run Upgrades remain active for the run and may alter weapon count, targeting, defense, mobility, companions, or collection.
- Elite Upgrades are milestone choices and are excluded after selection for the remainder of that run.
- Persistent Hangar purchases affect future runs and remain separate from run allocation levels.
- Enabling an upgrade repeatedly is idempotent. Disabling a developer override restores the exact prior baseline.

## Randomness and reproducibility

- Use an explicit run seed for ports and deterministic test scenarios.
- Random choices must be sampled from named domains where practical: spawn selection, boss pattern selection, drop selection, and upgrade selection.
- A debug seed may reproduce a scenario without changing normal player-facing randomness.
- A port may use a different random-number generator, but the acceptance scenario must still produce the same stated outcome.

## Pause, restart, and finalization

- Pause freezes all run simulation and input-consuming gameplay timers.
- Restart clears run-scoped state and begins a new run from the selected loadout.
- Try Again consumes one stock and restores the run's recorded starting lives, not a hard-coded value.
- Finalization awards end-of-run salvage and lifetime statistics once, after the try-again decision is resolved.
