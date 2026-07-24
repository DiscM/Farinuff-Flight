# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-05-24

### Added
- **Visual Elite Upgrades:** All ten elite upgrades now add cumulative, procedural ship hardware with synchronized front/rear layers, functional lighting, real weapon muzzle origins, installation reveals, card previews, and cached composite boost trails.
- **Visual Upgrade Developer Controls:** Expanded Dev Tools with scrollable sections, reversible elite and power-state toggles, Grant All/Clear All actions, and overlays for the visual envelope, attachment anchors, muzzle origins, and collision capsule.
- **Persistent Settings and Save Data:** Added automatic persistence for high scores and player preferences in `user://save_data.json`, including master volume, screen shake, CRT scanlines, and distortion settings.
- **Settings Menus:** Added an in-game settings overlay accessible from both the title screen and pause menu; visual options update during active runs.
- **Sniper Enemy:** Added a ranged enemy archetype that enters the playfield, holds a lateral firing lane, aims high-speed shots at the player, and then withdraws.
- **Boss Archetypes:** Regular bosses now rotate through Assault Wing, Bulwark Array, and Tempest Core encounters, each with distinct health values, bullet colors, and attack sequencing.
- **Sweep Attack Pattern:** Added a rotating fan-pattern boss attack used by Tempest and Elite encounters.

### Changed
- **Wave Pacing Balance:** Reduced late-game enemy speed and spawn acceleration, raised the extra-life orb cost from `10` to `12`, and reduced starting try-again stocks from `3` to `2`.
- **Health Scaling Balance:** Corrected per-wave enemy health calculation so low-health enemies no longer gain a full extra hit point on every wave.
- **Scaling Pass:** Slightly increased milestone stat bonuses and softened boss health scaling so late encounters stay threatening without turning into sponges.
- **Elite Upgrade Balance:** Adjusted Hull Plating to grant `+1` life, Shield Burst to trigger every `10` seconds, Overclock to last `2.5` seconds every `16` seconds, and Afterburner to provide a more controlled mobility boost.
- **Milestone Stat Balance:** Fire-rate and speed allocations now grow by `4.5%` per point with a `45%` cap to protect late-run tuning.
- **Projectile Variety:** Bomber, sniper, tank, and boss projectiles now use bounded speed variation, including staggered tank bullet rings, for less uniform attack timing.
- **Shift Dash Rework:** Shift dash now launches from the ship's current movement direction, travels a normalized distance, and accepts fine directional steering while active.
- **Reflect Rewarding:** Reflecting enemy projectiles now shortens dash cooldown, scales down further for each additional reflect, and unlocks chained dash continuation after three successful reflects.
- **Projectile Ownership Color:** Player-fired bullets now use a single consistent green, and reflected enemy bullets convert to that same player-fire color for immediate readability.

### Fixed
- **Background Planet Loading:** Corrected the asteroid resource path and removed an unavailable moon entry from random background selection.
- **Background Planet Stability:** Planet shader materials are now localized per instance so spawning a new planet cannot change the palette or terrain seed of planets already visible.
- **Background Flicker:** Removed animated full-screen CRT brightness and scanline movement that made hit-heavy moments read as background flashing.
- **Elite Upgrade Feedback:** Selecting an elite transformation now highlights the chosen card and briefly confirms installation before play resumes.
- **Damage Screen Shake:** Enemy-hit effects no longer shake the whole scene; player damage now triggers a reduced shake only after losing two lives within five seconds.

## [Unreleased] - 2026-03-21

### Added
- **Boss Telegraph System:** Bosses and Elite Bosses now project a 3-second explicit telegraph before moving. A spinning red crosshair will appear exactly at their next destination, locking the boss in place as a stationary turret for 3 seconds before they execute the maneuver.
- **CRT Post-Processing Shader:** A brand new full-screen post-processing layer (`crt_overlay.gdshader`) that adds authentic retro monitor visuals (barrel distortion, vignette, chromatic aberration, scanlines).
- **Procedural Nebula Background:** A dynamically scrolling background shader (`scrolling_bg.gdshader`) utilizing fractal noise to create drifting space dust and parallax stars.
- **Sleek Ship Redesign:** The player's ship procedural drawing algorithm has been completely overhauled from a basic chunky triangle into a sleek, swept-wing titanium stealth fighter with glowing cyan racing lines.
- **5 New Elite Upgrades:** Added Spread Shot, Shield Burst, Orb Magnet, Overclock, and Rear Gunner to the Wave 10 elite boss reward pool (increasing options from 5 to 10).
- **Elite Upgrade Uniqueness:** Boss upgrade choices are now tracked—once selected, an upgrade is permanently removed from all future Wave 10 pools during the current run.
- **Developer Testing Menu:** Added an embedded Dev Tools panel to the pause menu for quick testing (add orbs, clear enemies, spawn bosses, trigger UI popups, god mode, full power).
### Changed
- **Orb-Based Wave Progression:** The wave progression system has been entirely overhauled. Waves are no longer cleared by a flat "enemies killed" metric. They are now cleared by the total value of XP Orbs collected (`10 + Wave * 1.30`), directly incentivizing players to assassinate high-value targets.
- **Economy & HP Rebalance:** 
  - The HP bar now correctly respects orb values (12 accumulated value = 1 Extra Life).
  - Tank Enemy orb value raised from `2` \-\> `3`.
  - Bomber Enemy orb value solidified to `2`.
  - Regular Boss orb value raised from `3` \-\> `5`.
  - Elite Boss orb value raised from `3` \-\> `10` (yielding an entire extra life upon pickup).
- **Player Movement Scaling:** Increased the player ship's base `speed` (from 280 to 420) and `acceleration` (from 8 to 12) so it can comfortably keep pace with escalating enemy speeds.
- **HUD Safepoints:** Pulled the top and bottom UI elements inward by 25 pixels to prevent the new CRT screen-bending shader from distorting vital text and healthbars.
- **Boss Base Health Buffs:** Raised Elite Boss health to 125 and rebalanced regular boss archetypes upward to support the new boss variants.
- **Enemy Scaling Trimmed:** Halved the procedural wave-by-wave speed and spawn-interval acceleration of standard enemies to keep ultra-late game playable.
- **Boss Telegraph Consistency:** Reworked boss movement logic so bosses accurately dash to the exact telegraphed spot before beginning their Hover swaying or Strafe orbiting patterns.
### Fixed
- **Shader Injection Reliability:** Resolved issues where standalone `.gdshader` files wouldn't reliably compile when attached via pure `.tscn` text. All shaders are now safely dynamically initialized and rendered through GDScript directly in `game.gd`'s `_ready()` function.
- **Boss Spawning Glitch:** Fixed a critical bug where regular enemies would inadvertently continue to spawn *during* a Boss wave if the player previously died and used a Try-Again stock.
- **Elite Boss Despawn Bug:** Fixed an issue where the Elite Boss visual would persist instead of despawning after death due to a signal timing bug pausing the tree prematurely.
- **Upgrade Menu Pause Issue:** Fixed a logical bug where enemies would resume spawning while the elite upgrade popup was open.
- **Boss Teleport Jitter:** Resolved a single-frame visual teleport jitter that occurred the exact moment a boss finished its movement phase.
- **Pause Menu Layout:** Completely rewrote the pause menu to use dynamic scaling instead of absolute anchor presets, resolving issues where it would render off-center or off-screen.
- **Rear Gun Modifier Inheritance:** Fixed a bug where the Rear Gunner upgrade was only firing a single bullet; it now mirrors all forward cannon behaviors including Spread Shot and Twin Cannons.
- **Popup Unpausing:** Unified pause state management to prevent the game from silently unpausing behind active popup menus if triggered unexpectedly.
