# Farinuff Flight Portable Game Specification

Status: canonical rebuild reference

This folder describes the game independently from Godot, Unity, Unreal, a web runtime, or a particular asset format. It is the portable contract for recreating Farinuff Flight.

## What belongs here

- Player intent, rules, state transitions, content identity, and acceptance criteria
- Tuning and content data with stable IDs
- UI, visual, and audio intent that should survive a port
- Engine implementation profiles that explain how a specific runtime realizes the contract

## Source-of-truth hierarchy

1. The rules and data in this folder define intended behavior.
2. Acceptance tests define observable outcomes.
3. An implementation profile maps those rules to an engine or platform.
4. Code, scenes, prefabs, imported assets, and tools implement the profile.

When these sources conflict, record the decision in the relevant implementation profile or an ADR; do not silently change the portable rules.

## Status labels

- **Canonical** — approved behavior or content for the rebuild reference.
- **Reference** — observed in the current project and retained as a starting point.
- **Target** — desired behavior that still needs implementation or playtest proof.
- **Legacy reference** — behavior or content still present in the current project, but whose intended acquisition or future role is unresolved.
- **TBD** — intentionally unresolved; do not fill it with an assumption without recording the decision.

## Porting boundary

Keep these concepts portable:

- Abstract actions such as `move`, `shoot`, `boost`, and `pause`
- Simulation state, formulas, cooldowns, collision intent, and progression
- Stable content IDs such as `ENEMY.BASIC` and `UPGRADE.TWIN_CANNONS`
- Player-facing flows, feedback intent, and accessibility requirements

Keep these concepts in an implementation profile:

- Nodes, components, prefabs, actors, scenes, and scripts
- Physics and rendering APIs
- Camera/world-unit conversion
- Input-device APIs
- Asset import settings and packaging
- Platform save locations and export configuration

## Update workflow

1. Change the portable rule or data first.
2. Update the affected implementation profiles.
3. Add or revise an acceptance scenario.
4. Record intentional port-specific differences.
5. Capture evidence in a playtest or release record.

## Current-project references

The existing repository contains useful reference material, but those files remain implementation/history documents rather than replacements for this portable specification:

This portable specification resolves two known reference ambiguities: regular boss rotation uses Tempest Fork while Tempest Core is reserved for Wave 20, and late-game drift first applies at Wave 17 after the Wave-16 generation transition.

- [`GAME_DESIGN.md`](../GAME_DESIGN.md)
- [`CONTEXT.md`](../CONTEXT.md)
- [`STYLE_REFERENCE.md`](../STYLE_REFERENCE.md)
- [`design/audio_direction.md`](../design/audio_direction.md)
- [`docs/3d-migration-checklist.md`](../docs/3d-migration-checklist.md)
- [`COMPILATION_RELEASE_UPDATE.md`](../COMPILATION_RELEASE_UPDATE.md)
