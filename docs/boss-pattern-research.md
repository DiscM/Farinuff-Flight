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

| Boss | Exclusive attack | Phase progression |
| --- | --- | --- |
| Commander | Accelerating lances plus physical charge | Spearhead, split flanks, breakthrough; longer charge path |
| Bulwark | Parallel siege walls plus pod-owned mines | Fixed doorway, alternating doorway, cluster deployment |
| Tempest | Persistent orbit with moving openings | Forward orbit, reverse orbit, alternating direction |
| Harbinger | Marked origin with outbound/pause/return shots | Even return fan, offset echoes, wider barbed return fan |
| Core | Park-and-release paired axes plus interruptible reactor lance | Cardinal axes, diagonal axes, alternating axes |

This supersedes the earlier generic phase descriptions. Runtime uniqueness/readability and custom-mesh rendering still need observation; no runtime validation was performed.
