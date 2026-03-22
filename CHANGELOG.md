# Changelog

All notable changes to this project will be documented in this file.

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
- **Orb-Based Wave Progression:** The wave progression system has been entirely overhauled. Waves are no longer cleared by a flat "enemies killed" metric. They are now cleared by the total value of XP Orbs collected (`10 + Wave * 1.20`), directly incentivizing players to assassinate high-value targets.
- **Economy & HP Rebalance:** 
  - The HP bar now correctly respects orb values (10 accumulated value = 1 Extra Life).
  - Tank Enemy orb value raised from `2` \-\> `3`.
  - Bomber Enemy orb value solidified to `2`.
  - Regular Boss orb value raised from `3` \-\> `5`.
  - Elite Boss orb value raised from `3` \-\> `10` (yielding an entire extra life upon pickup).
- **Player Movement Scaling:** Increased the player ship's base `speed` (from 280 to 420) and `acceleration` (from 8 to 12) so it can comfortably keep pace with escalating enemy speeds.
- **HUD Safepoints:** Pulled the top and bottom UI elements inward by 25 pixels to prevent the new CRT screen-bending shader from distorting vital text and healthbars.
- **Boss Base Health Buffs:** Raised Regular Boss health from 40 to 50, and Elite Boss health from 100 to 125 to add a stronger challenge gap.
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
