# Expedition review captures

September 16, 2026, Godot 4.6.3, macOS Metal/Forward+, 1280×720. These seven staged
captures support production slice 06. The working tree includes existing copy
edits. The directory is excluded from Godot import and release packages.

## Boss phase references

The Interceptor carries Homing Shots, Piercing Rounds, and Twin Cannons. Developer
invulnerability is enabled and ordinary enemy spawning is disabled. Each boss is
placed relative to the player, damaged to 20% health, and allowed to run its actual
AI and arena pressure at normal speed for about 3.5 seconds. Pods remain active;
short scripted movement precedes each capture. Reduced flashing is enabled.

| Boss | Wave | Phase 3 capture | Review question |
| --- | --- | --- | --- |
| Assault Commander | 5 | [View](captures/assault-phase3-reduced-flashing.png) | Charge commitment, baiting, and punish window |
| Iron Bulwark | 10 | [View](captures/bulwark-phase3-reduced-flashing.png) | Pod priority and the safer lane created by its loss |
| Tempest | 15 | [View](captures/tempest-phase3-reduced-flashing.png) | Rotating gaps and reflection crossings |
| Tempest Core | 20 | [View](captures/core-phase3-reduced-flashing.png) | Stopped/released shots and interruption under pressure |
| Void Harbinger | 25 | [View](captures/harbinger-phase3-reduced-flashing.png) | Echo bait, return path, and Endless escalation |

These are snapshots of phase 3, not recordings of complete fights or all attack
types. The staged boss position overlaps parts of the upper combat header in some
frames; camera placement and warning visibility need normal-play review. The
existing boss scenes exercise phase mechanics separately. Neither source proves
human readability, full-build viability, or minimum-spec performance.

## Route and ending

- [Interceptor route dossier](captures/route-interceptor-720-large.png): menu text
  scale 1.3, Ghost Lanes selected. The corrected ship row identifies Interceptor.
  The content scrolls; confirmation extends below this initial view.
- [Wave-20 victory](captures/victory-720-large.png): menu text scale 1.3, staged
  route completion and precision build. Both ending actions remain visible.
  Currency is zero because this layout fixture skipped combat and settlement.

The final live inspection reported existing script/bridge warnings and no runtime
script errors. The game was stopped and its disposable profile removed. See the
[validation protocol](../../docs/expedition-playtest.md) for the automated matrix
and the natural playtests still needed for M2.
