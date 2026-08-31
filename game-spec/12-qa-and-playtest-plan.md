# QA and Playtest Plan

Status: reusable validation plan

## Test layers

### Simulation tests

Run without a renderer where possible:

- Movement bounds and frame-rate independence
- Fire interval and modifier stacking
- Boost, Interaction Range, reflection, and chain windows
- Damage/invulnerability and duplicate-event protection
- Wave thresholds, surplus carry-over, and generation transitions
- Boss phase transitions and reward ownership
- Upgrade idempotence and exclusion
- Salvage formulas and milestone claims
- Save validation, migrations, backups, and future-version handling

### Flow tests

Run with the target UI and input adapters:

- First launch → Flight School → Launch Bay → run
- Pause → settings → resume
- Milestone allocation and Elite Choice completion
- Try Again acceptance and decline
- Wave-20 Victory → Endless or Hangar
- Game Over → salvage summary → Hangar
- Controller-only navigation across all screens

### Presentation tests

- Threat readability at reference gameplay scale
- Player and enemy silhouette identity
- Projectile and telegraph visibility under combat load
- Audio event priority and mix separation
- Reduced-flashing and reduced-effects behavior
- Minimum viewport and supported aspect ratios

### Performance tests

- Cold start and first gameplay transition
- First encounter of every enemy role
- Fully upgraded Player Craft under maximum firing and boost load
- Boss with hazards, Projectiles, UI, and VFX active
- 30-, 60-, and 120-minute Endless soak

Record frame time, memory, active object count, pool size/growth, load hitches, and orphan/leak indicators where available.

## Manual playtest script

1. Start from a fresh profile.
2. Complete or skip Flight School and note comprehension.
3. Launch the default ship and test movement, aim, fire, boost, and reflection.
4. Reach the first milestone and describe the meaning of each choice without outside explanation.
5. Take damage, pause, resume, and verify recovery.
6. Continue until a boss, an Elite Choice, or game over.
7. Inspect salvage, build summary, and persistent records.
8. Repeat with a controller and reduced-effects settings.
9. Record confusion, unfairness, unreadability, input errors, and performance symptoms separately.

## Bug report template

```md
## Summary

## Build / platform / input device

## Seed or reproduction setup

## Steps to reproduce

## Expected portable behavior

## Actual behavior

## Frequency

## Evidence

## Severity and suggested owner
```

## Exit gates

- [ ] All P0/P1 gameplay issues closed or explicitly accepted.
- [ ] Core acceptance scenarios pass.
- [ ] New-player onboarding has been observed, not only reviewed by the team.
- [ ] Controller and accessibility paths are usable.
- [ ] Performance meets the target platform budget.
- [ ] A complete clean-profile run reaches the intended result flow.
