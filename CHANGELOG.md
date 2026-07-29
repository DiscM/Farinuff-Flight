# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-07-28

### Added
- **Music and Audio Buses:** Added a looping ambient music bed on a dedicated `Music` audio bus with an independent music-volume slider in Settings, plus UI click sounds on the title, pause, and settings menus.
- **Gamepad Support:** Bound the left stick to movement, A / right trigger to shoot, and B / left trigger to boost (right-stick aim already worked). Settings control-scheme swaps no longer disturb joypad bindings.
- **Accessibility Options:** Added a Fullscreen toggle and a Reduced Flashing toggle (dims and shrinks explosion flash sprites) to Settings.
- **CI Smoke Tests:** Added a GitHub Actions workflow that runs all four headless smoke-test scenes on every push and pull request, and corrected the broken `--script` run commands in the test headers (that mode skips autoloads and never exits).
- **Repository Hygiene:** Added a `.gitignore` and untracked the `.godot/` editor cache (12k+ files), the exported Windows binaries, and `.DS_Store` files.
- **New Record Highlight:** The game-over screen now shows a gold `NEW RECORD` line when the run beat the previous high score, instead of always showing identical score and high-score values.
- **Hit-Stop:** Added brief impact freezes on boss kills, player death, and nuke pickups.
- **Autoload Smoke Test:** New headless coverage for SaveManager (corrupt/hand-edited saves, version handling) and ObjectPool (reuse, double-release, idle cap), wired into CI.
- **Save Schema Version:** Save files now carry a `version` field; mismatched versions fall back to defaults until a migration exists. Pre-versioning saves still load.
- **Try-Again Stock Readout:** Stock count now shows a number alongside the star icons.

### Changed
- **Object Pooling:** XP orbs and power-ups are now pooled through `ObjectPool` like bullets and explosions, removing the highest-churn instantiate/free cycles. The try-again flow now returns pooled bullets and power-ups to the pool instead of `queue_free`-ing them.
- **Boss Movement Bounds:** Boss HOVER sway and STRAFE orbit radius now scale with the live viewport width instead of using fixed 720px-landscape constants, so the boss stays on screen on narrow portrait layouts.
- **Spawn Fairness:** Enemy spawn rolls that land within 160px of the player are re-rolled (up to 6 attempts) so enemies can't materialize on top of the ship.
- **Player Script Split:** Extracted the drone escort into a self-contained `ShipDrone` component and removed the dead `reset_state()` path, dead signals, and other dead code; `player.gd` is ~150 lines lighter.
- **Shared Power-Up Enum:** `power_up.gd` now declares `class_name PowerUp`, and the player, HUD, and spawner all reference `PowerUp.Type` instead of duplicated raw ints.
- **Shared Enemy Fire Helper:** The copy-pasted pooled-bullet spawn block across tank, bomber, sniper, and boss is now a single `BaseEnemy.fire_enemy_bullet()`.
- **Combined Milestone Screen Removed:** Deleted the dead side-by-side elite/allocation screen; the production sequential flow (elite first, allocation after) is now covered by the modal-flow smoke test.
- **Save Validation:** Loaded settings are type-checked against their defaults, so a hand-edited save can no longer invert boolean preferences.
- **Frame-Rate-Independent Bobbing:** XP orb and power-up bob effects are now delta-scaled.
- **Balance Retune (Double-Damage Compensation):** All regular enemy and boss base HP halved (`ceil(old/2)`) to preserve the original hits-to-kill now that bullets correctly deal single damage. Secondary damage sources (drone, orbitals, explosive splash) are intentionally unchanged, so they are relatively stronger than before.
- **Pause Consolidation:** All tree pausing now flows through `_update_pause_state()` (including game-over, via `game_over_shown` as a flag) — no more direct `get_tree().paused` writes that could stomp each other.
- **Orb Carry-Over:** Surplus orb progress now carries into the next wave instead of being reset; orbs farmed during boss waves no longer vanish.
- **Order-Independent Hit Handling:** The player now decides post-hit invincibility before emitting `player_hit`, removing the silent dependence on synchronous signal ordering.
- **Throttled Visual Scans:** Auto-aim/magnet indicator scans refresh at 10 Hz instead of every physics frame, the fast enemy's sidestep bullet scan at ~8 Hz, and the per-frame upgrade-state Dictionary is reused.
- **Audio Voice Stealing:** When all 16 SFX voices are busy, the voice nearest completion is stolen instead of always clipping the same oldest slot.
- **Object Pool Cap:** Idle pooled nodes are capped at 128 per scene; overflow is freed instead of retained forever.

### Fixed
- **Game-Over Soft-Lock:** The game-over screen paused the tree and then awaited a pause-frozen timer, so it never appeared and input was dead. Every run that reached true game-over wedged on a frozen frame.
- **Double Damage:** Enemy and boss `area_entered` handlers applied damage on top of the bullet's own handler, so every bullet dealt roughly twice its designed damage (bosses took double bonus damage too). Bullet damage is now applied solely by the bullet.
- **Invincibility Durations:** Hits always granted 1.5s of invincibility regardless of source, and the try-again flow read a stale leftover duration. Contact hits now grant 3s, bullets/ordnance 2s, and try-again respawns a clean 3s as documented.
- **Boss Spawning After Game Over:** A same-frame wave transition could instantiate a boss during the game-over flow.
- **Bullet Self-Collision:** Player bullets no longer pair-check against each other every physics step.
- **Boss Phase Skip:** The Tempest Core's OVERLOAD phase can no longer be triggered by chip damage during CONDUITS, which silently skipped the EXPOSED phase.
- **Stale Stat Docstrings:** Enemy scripts no longer claim `_ready` sets health/points (those live in evolution-stage scene data).

## [Unreleased] - 2026-05-24

### Added
- **Visual Elite Upgrades:** All ten elite upgrades now add cumulative, procedural ship hardware with synchronized front/rear layers, functional lighting, real weapon muzzle origins, card previews, and cached composite boost trails.
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
- **Milestone Upgrade Flow:** Elite choices apply immediately with a static `SELECTED` confirmation; combined elite/allocation screens remain locked open until both decisions are complete, without an exit fade or ship-drawing transition.
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
