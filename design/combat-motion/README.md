# Combat motion and enemy readability

The approved faceted fleet now uses rigid articulated panels, with short anticipation, an attack impulse, and a controlled recovery. The existing pixel planets and PixelPlanets-inspired enemy materials remain the visual reference.

## Readability

| Enemy | Hull size increase | Contact envelope increase |
| --- | ---: | ---: |
| Redjack / basic | 50% | 35% |
| Razorwing / fast (including courier) | 65% | 40% |
| Verdant / bomber | 45% | 30% |
| Bastion / tank | 30% | 22% |
| Lancer / sniper | 55% | 40% |

The contact envelopes remain inset and keep their existing world alignment. Animation never changes a hitbox. Tank armor orbits move outward by 30% to clear the larger hull. Bosses retain their established scale and receive the new articulation.

## Motion and triggers

- Basic: panel tuck during the existing 0.55-second charge warning, then a folded charge pose.
- Fast/courier: restrained wing movement in flight; fast enemies fold during phase warnings and snap into their dash or sidestep.
- Bomber: bay panels open 0.4 seconds before a bomb, release on the actual drop, then close. Mine drops also trigger release motion.
- Tank: armor braces before ordinary bursts and overload warnings; recoil follows each emitted volley.
- Sniper: rails spread during the aim warning and recoil on the actual shot. The pooled rail beam drives its release frame too.
- Bosses: all five variants articulate during their own warnings and volleys; interrupted core charges and phase transitions clear the held pose.
- Player: all three hulls have a quiet wing cycle, weapon recoil, folded boost flight, recoil while boosting, and an upgrade flourish.
- Upgrades: all 13 modules deploy when installed. Mounted modules copy the hull's blended bone pose, keeping armor and engines attached. Shield burst and overclock pulse when their gameplay abilities activate.

The actor's physics clock advances the clips. Windups hold until gameplay releases them; animation does not determine damage or spawn a projectile. Damage feedback cannot overwrite a held warning. Rapid fire restarts recoil immediately, and pause/reset stops or clears the motion. Muzzle and engine wrappers resolve the current bone transform before projectile emission, avoiding deferred attachment updates.

## Editable assets

`assets/models/animated/sources/farinuff_combat_motion.blend` contains 26 asset scenes: five regular enemies, five bosses, three player hulls, and 13 modules. Each scene contains an editable four-bone rig with NLA clips. The geometry and palettes come from the project's existing GLBs; every connected hard-surface part has a single rigid bone weight. Mesh counts are unchanged.

Rebuild inside Blender with `tools/build_combat_motion_blender.py`. It writes the animated GLBs and their manifest into `assets/models/animated/`. The approved static model sources remain available. The source directory is excluded from Godot import with `.gdignore`.

## Review and validation

Run `res://scenes/combat_motion_review.tscn` for a repeating motion lineup; Space pauses it. The top row is explicitly magnified 2.2× and the player examples 2.8×. `motion-preview.gif` captures one deterministic four-second cycle. `combat-1080p.png` shows the actual gameplay scale with 15 active enemies; `boss-windup.png` shows the Tempest rig in game.

Validated on Godot 4.6.3, Metal Forward+, at 1920×1080. The 15-enemy combat sample held 60 FPS. This is a local visual check, not a maximum-load benchmark.

`tests/combat_motion_smoke.tscn` covers real enemy release events, moving sockets, stable hitboxes, all three player hulls, boost/recoil, rapid fire, module alignment, shield/overclock activation, pause and reset. It runs in CI alongside the existing native completion and visual smoke tests. Existing ObjectDB/resource/DummyShader shutdown warnings remain in the headless native harness.
