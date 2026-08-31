# Product Brief

Status: canonical reference with target decisions to validate

## Product identity

- **Title:** Farinuff Flight
- **Genre:** Top-down arcade survival shooter with run-based progression
- **Business model:** Premium single purchase
- **Primary platform:** Desktop first, with keyboard/mouse and controller support
- **Session shape:** Short-to-medium runs with an authored campaign climax and optional Endless continuation

## Product promise

Farinuff Flight is a fast, readable space shooter where the player survives hostile waves, turns danger into offense through boost-reflection, and builds a visibly transforming ship across an Expedition ending at Wave 20.

## Intended audience

- Players who enjoy arcade shooters, survival runs, score chasing, and build combinations
- Players who value readable telegraphs and high-feedback combat
- Keyboard/mouse and controller players who want a complete premium game rather than a free-to-play progression loop

## Design pillars

1. **Readable action** — threats, safe gaps, pickups, and rewards must remain legible under pressure.
2. **Skillful movement** — movement, drift, boost timing, and reflection should matter more than passive power.
3. **Run-based growth** — each run develops a distinct combat identity.
4. **Strong feedback** — important actions have clear visual, audio, and interface confirmation.
5. **Respect the player** — no paid power, manipulative timers, or progression systems that replace mastery.

## Scope for the first complete rebuild

### Required

- Flight School onboarding
- Launch Bay loadout selection
- Playable Expedition through Wave 20
- Optional Endless mode after the Wave-20 clear
- Player movement, aiming, auto-fire, boost, and projectile reflection
- Temporary power-ups, run upgrades, milestone allocation, and elite choices
- Five regular enemy roles, rotating bosses, and a final Tempest Core encounter
- Try-again recovery and final game-over flow
- Salvage, Hangar purchases, ship variants, challenge modifiers, and persistence
- Controller support, settings, reduced-flashing option, and reliable saves

### Optional after the vertical slice

- Additional enemy roles and boss variants
- More encounter modifiers and discovery content
- Richer 3D animation or presentation effects
- Localization and broader platform support

## Non-goals

- Multiplayer
- Free-flight altitude or six-degree-of-freedom maneuvering
- Real-money currency or paid gameplay advantages
- Permanent power large enough to make boss learning irrelevant
- Replacing readable combat with visual noise

## Success signals

The rebuild is on the right track when:

- A new player can understand movement, boost-reflection, the orb/life economy, and upgrade choices during the first session.
- The player can identify major threats and boss telegraphs without relying on color alone.
- A run feels meaningfully different after its first major upgrade choice.
- Wave 20 feels like an earned campaign climax, while Endless remains an optional mastery space.
- A port can reproduce the acceptance scenarios in `09-acceptance-tests.md` without changing their expected outcomes.

## Open decisions

- Final presentation target: verified 2D baseline, native top-down 3D, or multiple supported presentations.
- Minimum supported hardware and display scale.
- Final release content beyond the current Wave-20 scope.
- Exact target run duration after balance playtests.
