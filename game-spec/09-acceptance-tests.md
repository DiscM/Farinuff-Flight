# Cross-Engine Acceptance Tests

Status: canonical observable-behavior contract

These scenarios are deliberately written without engine APIs. Each implementation may use its own test runner, scene, prefab, or harness, but the observable result should match.

## Test conventions

- Use a known run seed where randomness is involved.
- Start from a clean run state unless the scenario says otherwise.
- Record the implementation, build, seed, and display profile.
- Distinguish a design failure from a presentation difference.
- A port may change art, camera, or input plumbing only when the player-facing intent remains intact.

## Core scenarios

### 1. Start a clean run

Given a valid persistent profile and the default ship, starting a run must reset score, combo, wave, orb progress, run upgrades, allocation levels, and active combat objects. Persistent Salvage and unlocks remain intact.

### 2. Move and aim independently

Movement input must move the Player Craft within the Combat Space without depending on cursor position. Aim input must change firing direction without moving the craft.

### 3. Fire continuously

Holding `shoot` for two seconds with base tuning produces repeated Projectiles at the configured interval. The implementation must not create a second action or duplicate firing stream from the same input.

### 4. Reflect an incoming Projectile

Given a Player Craft that begins boosting before an eligible Projectile enters Interaction Range, the Projectile is reflected once, becomes player-aligned, and does not remove a life from the player.

### 5. Reject an out-of-range reflection

An incoming Projectile outside the reflection range remains hostile until it enters the valid interaction condition. The player cannot reflect it merely because boost is held elsewhere in the Combat Space.

### 6. Apply damage once

A single collision consumes one life and starts the correct invulnerability window. Duplicate overlap callbacks for the same contact do not consume additional lives or emit duplicate fatal events.

### 7. Advance a wave

Collecting enough orb value completes the current non-boss wave, preserves only the allowed capped surplus, emits one `wave_cleared`, and starts the next wave once.

### 8. Boss milestone

At every fifth wave, the boss encounter begins with a clear warning, blocks ordinary wave completion while active, and returns to normal progression exactly once after defeat.

### 9. Upgrade idempotence

Enabling the same Run or Elite Upgrade twice does not compound one-time rewards, duplicate modules, or create duplicate firing streams. Clearing the build restores the baseline.

### 10. Pause and resume

Pause freezes movement, cooldowns, Projectiles, hazards, timers, and input-driven review behavior. Resume restores them without consuming the pause/resume input as a gameplay action.

### 11. Try Again

When lives reach zero with stock remaining, accepting Try Again consumes exactly one stock and restores the recorded loadout-derived starting lives. Declining proceeds to final game over.

### 12. Finalize once

Final game over awards boss, score, wave, and milestone Salvage according to the economy rules. Reopening or refreshing the result screen cannot award the same bonus twice.

### 13. Wave-20 completion

Defeating the Tempest Core enters the Expedition Complete state. The player may choose Endless or return to the Hangar; the game must not silently skip the choice.

### 14. Save recovery

A malformed or interrupted primary save must fall back to the last known-good backup or safe defaults without deleting valid persistent progress. A future unsupported save version must not be overwritten.

### 15. Reduced-effects mode

When reduced flashing and visual-effects settings are enabled, the player still receives clear state confirmation for damage, bosses, upgrades, deflections, and victory.

## Visual and audio review scenarios

- Capture the Player Craft baseline, each major upgrade, representative combinations, and the fully upgraded state.
- Verify enemy and boss roles remain readable at gameplay scale.
- Verify each major warning has an audible and visual partner.
- Verify the game remains legible with a full projectile load and active effects.
- Verify controller prompts and navigation across every screen.

## Performance scenarios

- Baseline active run at normal enemy load
- Fully upgraded Player Craft while boosting and firing maximum weapon patterns
- Boss encounter with hazards, Projectiles, UI, and VFX active
- 30-, 60-, and 120-minute Endless soak
- Cold start and first encounter after loading assets

Record frame time, memory, active object counts, pool growth, and orphan/leak indicators where the target platform exposes them.
