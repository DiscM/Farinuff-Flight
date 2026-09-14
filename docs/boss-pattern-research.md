# Boss pattern research and projectile art

## Sources and design implications

- [Tiny Rogues: Banshee community documentation](https://roguepedia.net/w/Banshee) describes an even fan with a central opening and a changed second-phase spread. The implemented Harbinger echo fans adapt the spacing principle, without copying art or claiming an exact recreation.
- [Kenta Cho: BulletML](https://www.asahi-net.or.jp/~cs8k-cyu/bulletml/index_e.html) documents a reusable barrage-description approach and cites patterns from Progear, Psyvariar, Gigawing2, G Darius and Xevious. Design inference: author timing, direction changes and speed changes as distinct pattern components rather than treating bullet count as difficulty.
- [Touhou: Phantasmagoria of Flower View official manual](https://cdn.steamstatic.com/steam/apps/1420810/manuals/th09_manual.pdf) was located during research but has not yet been read in detail. No implementation claim is based on it yet. The official PDF is accessible with its timestamp query, but its page contents were not available as readable text in this pass; the community source below supplies the explicitly attributed gameplay findings.

## Touhou phase structure

The community [Perfect Cherry Blossom gameplay guide](https://touhou.fandom.com/wiki/Perfect_Cherry_Blossom/Gameplay) describes separate boss health bars, named spell-card patterns, health-bar markings that indicate a coming pattern change, attack timers, and bullet cancellation when an attack is defeated. This is secondary documentation, not a direct play observation.

Application to Farinuff: retain the implemented named three-phase fights and field clearing, and expose threshold positions on the health bar so players can anticipate a transition. Do not add timed automatic phase completion or spell-capture scoring in this pass: those would change progression and rewards beyond the current request.

## Other bullet-hell pattern construction

[Kenta Cho's BulletML tutorial](https://www.asahi-net.or.jp/~cs8k-cyu/bulletml/) demonstrates firing successive shots at incremented angles with waits, then giving the projectiles delayed direction changes. It explicitly relates one example to Progear's second boss. Our design inference is to distinguish the launch formation from the subsequent motion schedule. Tempest's orbit and Harbinger's delayed emission already explore that separation; future variants should change one timing rule at a time rather than stack more simultaneous fields.

## Authored projectile geometry

The boss projectile factory now constructs custom beveled outlines: an arrowhead with recessed shoulders and split tail, a stepped siege shell, an open hooked crescent, a barbed teardrop, and a four-lobed reactor projectile. These replace the generic primitive boss meshes. Forward is negative Z. The outlines are defined in `assets/models/projectiles/boss_projectile_meshes.gd`; pooled instances share the resulting meshes. Cyan non-deflectable diamonds retain their existing common appearance.

## Remaining work

Inspect the new silhouettes in the game before calling the art finished. Confirm small-scale readability, winding/material appearance, and perceived collision size. Touhou gameplay findings above are explicitly community-sourced; no claim is made to have reviewed the official PDF contents. No runtime validations were run in this pass.

## Exclusive attack ownership

The boss dispatcher now assigns each formation to exactly one hull. The obsolete shared ring generator is removed; Commander-only lance helpers are named accordingly. Shared projectile pooling, collision and cyan safety coding are infrastructure, not additional attack formations.

| Boss | Existing attack | New phase 1 mixup | New phase 2 mixup | New phase 3 mixup |
| --- | --- | --- | --- | --- |
| Commander | Accelerating lances and physical charge | Braking fan followed by fast aimed lances | Slow wide pincers followed by fast inner flanks | Alternating slow/fast scissor sweeps |
| Bulwark | Siege walls and pod-owned mines | Slow gate followed by a fast gate with the same doorway | Oblique gates hinge to alternate sides | Rotating parked walls interleave with fast gates |
| Tempest | Orbiting crescents with moving openings | Radial comet spokes alternate slow and fast lanes | Opposed curved ribbons reverse between beats | Rotating spokes mix fast crescents with braking and parked blades |
| Harbinger | Marked outbound/pause/return fans | Mixed-speed returning fans | Staggered twin marks from surviving pods | Perpendicular echoes overlap returns with fast delayed releases |
| Core | Park-and-release axes and interruptible reactor lance | Slow cardinal pulses followed by fast diagonals | Angled arms alternate braking and fast layers | Six rotating petals alternate parked and fast layers |

Projectile sequences alternate between the existing attack and the phase's new mixup. A separate sequence counter prevents Commander rams and Core charges from starving either projectile family. New mixups receive a 1.15-second windup and lock aim before release. Existing interrupt windows and phase-transition field clears remain in place. Destroyed pods remove siege wings, storm spokes, echo rays/marks, and reactor wings while leaving a core attack active.

Enemy launch speeds now receive a single **1.30×** multiplier in `ProjectileManager3D.fire_enemy_projectile`, including explicit boss, regular enemy, and mine-payload speeds. The default rises from 400 to 520 baseline pixels/second; unwarned slow/fast layers launch at 234/494. Motion profiles retain their acceleration, braking, pause, and return timing. Enemy arena layers additionally alternate authored 0.70×/1.30× speeds, gaining 0.05 per health phase. These are deliberate slow/fast timing choices rather than a minimum-speed clamp. Player weapon speed is unchanged.

`tests/boss_patterns_smoke.tscn` covers all 15 boss/phase combinations through real pooled projectiles, attack alternation across special attacks, slow/fast speeds, motion pause/return behavior, reflection, pod reductions, Commander escape corridors, arena telegraphs, phase cleanup, and pool capacity. It runs in practice mode without banking rewards and is included in the smoke-test workflow. These checks establish behavior; difficulty balance still benefits from player feedback.

Arena telegraphs use smooth layered strokes, tapered ends, and moving direction chevrons; fast layers use double chevrons. Repeated volleys on one path display the next release once, and trap rings fill toward detonation. Charge, sniper, and rail warnings share a feathered lane shader whose edges mark the advertised width. Animation follows attack timers so warnings hold when gameplay pauses. Warning timing, shot directions, and damage windows are unchanged by this presentation pass.

Telegraphed boss volleys, arena lanes, and warned sniper shots receive a further **2.25×** launch-speed multiplier after their warning completes. Boss slow/fast mixups now launch at 526.5/1111.5 baseline pixels/second, and arena lanes range from about 532 to 1331 across phases and speed layers. Warning duration, slow/fast ratios, and motion timing are preserved. Sniper shots that bypass the warning keep their ordinary speed.

## Player pursuit and Commander charge

All five hulls use the `FlightAI` child in `entities/enemies/boss_enemy_3d.tscn`. Its `BossFlightOrchestrator` script in `systems/boss_flight_orchestrator.gd` owns flight decisions and steering; the boss owns its transform, attack schedule, physical ram, and charge cooldown. Steering updates the player's position and capped velocity lead on every flight frame.

The planner prioritizes returning from an arena edge, withdrawing from contact range, and intercepting a distant player. Separate entry and exit distances prevent rapid switching at a threshold. Inside engagement range it advances the hull's authored maneuver sequence. Flight patterns include flanking arcs, breathing orbits, lateral weaves, figure-eight approaches, and arcing withdrawals. These paths follow the live player, with a stable approach axis for each maneuver. Steering eases through turns and anticipates arena edges; returning from an outer-edge ram never snaps the hull inward.

Profiles are editable Godot resources under `entities/enemies/flight_profiles/`, using `systems/boss_flight_profile.gd`:

| Hull | Profile | Base speed (pixels/s) | Preferred range (pixels) | Maneuver sequence |
| --- | --- | --- | --- | --- |
| Assault Commander | `commander.tres` | 240 | 300 | Flank, weave, orbit, withdraw |
| Iron Bulwark | `bulwark.tres` | 170 | 390 | Weave, withdraw, flank, orbit |
| Tempest | `tempest.tres` | 260 | 310 | Orbit, figure eight, weave, orbit, withdraw |
| Void Harbinger | `harbinger.tres` | 220 | 350 | Flank, weave, withdraw, figure eight |
| Tempest Core | `core.tres` | 190 | 380 | Figure eight, orbit, flank, weave, withdraw |

Later health phases increase speed by 8% per phase, reduce preferred range by 20 pixels per phase, shorten maneuvers, and widen weaving. Completed sequence cycles reverse their direction. Profiles also expose velocity lead, its distance cap, steering response, maneuver duration, and pattern amplitude. Assign `profile_override` on the `FlightAI` node to try a custom profile; shared resources contain tuning only, and each controller owns its encounter state.

The boss explicitly steps the orchestrator during free flight. Warnings, volleys, phase transitions, rams, and ram recovery suspend it, keeping advertised attack origins fixed. Maneuver clocks count flight time, so an attack resumes the current maneuver instead of skipping ahead. Phase transitions reset the planner, missing players suspend it, and finishing an encounter shuts it down. `get_debug_state()` exposes the current maneuver, priority reason, held state, phase, flight clock, target prediction, waypoint, and speed. `maneuver_changed` is available for debugging or presentation hooks.

The Commander's physical charge has a **25-second cooldown**, measured from the start of its warning. Regular volleys and pursuit continue during cooldown. Health phase changes can cancel a charge but do not refund its cooldown; pausing gameplay freezes it. A new encounter starts with the charge available. The boss smoke scene covers pursuit, retargeting, moving-player lead, circling, edge recovery, absent-player handling, fixed attack origins, and repeated charge timing across a phase interruption.

`tests/boss_flight_smoke.tscn` exercises the production movement entry point across all 15 hull/phase combinations: distinct paths, maneuver progression, speed limits, tracking a moving player, capped boost prediction, corner recovery, player clearance, pause/phase/lifecycle handling, independent controller state, and custom weave/figure-eight profiles. `tests/boss_patterns_smoke.tscn` additionally verifies that complete attack sequences hold the flight clock and that the Commander continues flying and firing between charges. Both scenes run in practice mode without banking rewards and are included in CI.

Validated on Godot 4.6.3: flight, boss-pattern, and native-completion smoke scenes pass. A live Tempest check in `scenes/flight_practice.tscn` followed a repositioned player from 903 pixels away back to a 299-pixel orbit, with no new runtime errors. Headless shutdown reports renderer/audio resource cleanup diagnostics; verbose output identifies the audio resource as the existing explosion sample.
