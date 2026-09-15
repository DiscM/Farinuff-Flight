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

## Current combat implementation

The current finite-state architecture, phase unlocks, attack resources and counterplay rules are documented in [Boss finite-state AI](boss-ai.md). The standard repertoire is slam, charge (from phase two), primary projectiles, and alternate projectiles (from phase three). The previous adaptive tactic scheduler, independent Core rail attack and pod mine scheduling have been replaced.

`BossProjectilePatterns` preserves each hull's distinct projectile geometry:

| Hull | Primary | Additional phase-three pattern |
| --- | --- | --- |
| Commander | Accelerating lance formations | Alternating slow/fast scissor sweeps |
| Bulwark | Siege walls with open doorways | Rotating parked walls and fast gates |
| Tempest | Orbiting crescents with moving openings | Rotating spokes with braking and parked blades |
| Harbinger | Marked outbound/pause/return fans | Perpendicular echoes and delayed fast releases |
| Core | Park-and-release axes | Six rotating petals with parked and fast layers |

Destroyed pods remove siege wings, storm spokes, echo rays and reactor wings while leaving a core attack active. Shared pooling, collision and cyan safety coding remain infrastructure shared by the patterns.

Enemy launch speeds receive one **1.30×** multiplier in `ProjectileManager3D.fire_enemy_projectile`. Telegraphed attacks receive a further **2.25×** multiplier through `fire_telegraphed_enemy_projectile`. Default slow/fast layers therefore launch at 526.5/1111.5 baseline pixels per second. Motion profiles preserve acceleration, braking, pause and return timing. Each boss attack resource adds a tunable projectile speed scale. Player weapon speed is unchanged.

Optional legacy arena pressure retains marked routes, staggered releases and slow/fast layers, but is disabled in the standard FSM profiles. Slam uses a radius-matched ground warning; charge uses the shared feathered lane shader. Attack presentation is stepped by gameplay timing and freezes when paused.

## Reusable flight patterns

`BossAI/Flight` executes steering and arena safety from supplied target positions. The FSM supplies bounded prediction and requests an engagement distance that can close into melee range after two projectile attacks. The actor is the sole writer of its hull transform.

Profiles under `entities/enemies/flight_profiles/` preserve the authored hull identities:

| Hull | Base speed, pixels/s | Preferred range, pixels | Maneuver sequence |
| --- | --- | --- | --- |
| Commander | 240 | 300 | Flank, weave, orbit, withdraw |
| Bulwark | 170 | 390 | Weave, withdraw, flank, orbit |
| Tempest | 260 | 310 | Orbit, figure eight, weave, orbit, withdraw |
| Harbinger | 220 | 350 | Flank, weave, withdraw, figure eight |
| Core | 190 | 380 | Figure eight, orbit, flank, weave, withdraw |

Arena reentry and contact clearance take priority over requested maneuvers. Steering eases through turns and anticipates edges, including returning from a charge endpoint. Maneuver clocks count only flight time; warnings, attacks and recovery hold the hull. The AI, flight and projectile smoke suites independently cover state behavior, authored routes and actual projectile geometry.
