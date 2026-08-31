# UI and Player Flows

Status: portable interaction contract

## Screen inventory

| Screen | Purpose | Required actions |
|---|---|---|
| Title | Establish identity and route to play | Launch, Hangar, Settings, Flight School/help |
| Flight School | Teach the essential loop | Advance, skip, replay |
| Launch Bay | Configure the next run | Select ship, toggle owned modifiers, review multiplier/supplies, launch |
| Active HUD | Expose combat state | Read score, combo, lives, wave/orb meter, boss health, active Power-Ups |
| Pause | Safely interrupt a run | Resume, restart, settings, return to title |
| Stat Allocation | Spend milestone points | Choose fire rate, health, or speed; confirm completion |
| Elite Choice | Select a run-defining upgrade | Inspect, preview, choose one, confirm |
| Expedition Victory | Resolve Wave-20 climax | Continue to Endless or return to Hangar |
| Try Again | Resolve a fatal run state | Spend stock or decline |
| Game Over | Communicate the completed run | Review score, wave, build, salvage, lifetime records, continue |
| Hangar | Spend persistent Salvage | Inspect, purchase, equip, return |
| Settings | Configure presentation and controls | Audio, display, effects, control scheme, restore defaults where supported |

## Interaction rules

- Every actionable control has a visible focus/selected state.
- Controller navigation must work across every screen, popup, and confirmation state.
- Opening a modal must not also activate the first option.
- Resuming from pause must not consume the resume input as a gameplay action.
- A completed selection remains visibly selected for at least a brief confirmation beat before the modal closes.
- If two milestone panels share one overlay, the overlay closes only after both decisions are complete.
- Destructive or irreversible actions require clear confirmation or an equally clear reversible path.

## HUD requirements

The HUD should expose:

- Score and high-score relationship
- Combo state
- Lives and temporary invulnerability/defense state when relevant
- Current wave and orb progress
- Boss name and health when active
- Active Power-Up identity and remaining duration where relevant
- A compact representation of the current build during pauses, milestone decisions, and final results

## Flight School teaching order

1. Move and remain inside the Combat Space.
2. Aim and hold fire.
3. Boost to reposition and observe drift.
4. Reflect a safe incoming Projectile.
5. Collect XP Orbs and explain life restoration.
6. Choose a build upgrade and explain temporary, run-long, and persistent scopes.
7. State the Expedition goal: defeat the Wave-20 Tempest Core.

The tutorial should teach one action and one success condition at a time. It should be skippable and replayable.

## Accessibility contract

- Do not communicate threat level through color alone.
- Provide reduced flashing and independent controls for shake, CRT/distortion, and other high-intensity effects.
- Provide separate music and SFX volume controls.
- Provide controller-only navigation.
- Use text/UI scale that remains usable at the minimum supported viewport.
- Make input prompts reflect the active input family.
- Preserve important warnings and rewards when reduced-effects settings are enabled.
- Keep all player-facing strings localization-ready.
