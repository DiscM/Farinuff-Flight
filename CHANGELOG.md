# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-03-21

### Added
- **CRT Post-Processing Shader:** A brand new full-screen post-processing layer (`crt_overlay.gdshader`) that adds authentic retro monitor visuals (barrel distortion, vignette, chromatic aberration, scanlines).
- **Procedural Nebula Background:** A dynamically scrolling background shader (`scrolling_bg.gdshader`) utilizing fractal noise to create drifting space dust and parallax stars.
- **Sleek Ship Redesign:** The player's ship procedural drawing algorithm has been completely overhauled from a basic chunky triangle into a sleek, swept-wing titanium stealth fighter with glowing cyan racing lines.

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

### Fixed
- **Shader Injection Reliability:** Resolved issues where standalone `.gdshader` files wouldn't reliably compile when attached via pure `.tscn` text. All shaders are now safely dynamically initialized and rendered through GDScript directly in `game.gd`'s `_ready()` function.
- **Boss Spawning Glitch:** Fixed a critical bug where regular enemies would inadvertently continue to spawn *during* a Boss wave if the player previously died and used a Try-Again stock.
