# Space Shooter Design Document

## Overview

Space Shooter is a fast, procedural 2D arcade shooter built in Godot 4. The current build focuses on a compact core loop:

1. Survive endless enemy waves.
2. Collect XP orbs to fill the wave meter and earn extra lives.
3. Pick up temporary combat power-ups during the run.
4. Defeat a boss every 5 waves.
5. Choose a permanent elite upgrade after every 10th-wave boss.

The game leans heavily into speed, readability, and high-feedback presentation with shader-driven effects, screen shake, tweened UI, and a retro CRT aesthetic.

## Design Pillars

### 1. Readable Action

Combat should remain legible even as the screen fills with bullets, enemies, and effects. Enemy types, power-ups, and bosses each use distinct color cues and behavior patterns so the player can identify threats quickly.

### 2. Run-Based Growth

The player is not just surviving a wave. They are building a ship during the run through:

- Temporary power-ups
- Permanent combat upgrades
- Stat allocation every milestone
- Elite boss transformation choices

### 3. Strong Feedback

Every major action is paired with a visual response:

- Screen shake for hits, bursts, and nukes
- HUD banners for waves and bosses
- Pulse animations for combo and reward screens
- CRT and distortion layers for the final presentation

### 4. Modular Godot Architecture

The game uses scene composition, autoload singletons, and a signal bus so the systems stay decoupled:

- `GameManager` owns global state, progression, and balancing values
- `SignalBus` routes gameplay events to UI and effects
- The main game scene assembles the player, spawners, camera, HUD, and overlays

## Current Gameplay Loop

### Start Flow

- The game opens on the main menu.
- Pressing Play loads the main game scene.
- The player starts centered near the bottom of the screen with 3 lives and no upgrades.

### Moment-to-Moment Play

- The player moves with keyboard or controller.
- The ship can boost for short bursts and uses a drift-based movement model.
- The player can shoot continuously while holding the fire button.
- Free aim is supported through mouse movement and right-stick input.

### Combat and Progression

- Enemies spawn from the screen edges at a pace that increases over time.
- Killing enemies grants score, combo growth, and XP orb drops.
- XP orbs fill a wave meter and restore lives when enough are collected.
- Power-ups spawn independently and drift down the screen.
- The player can collect power-ups by touch or by shooting them.

### Wave and Boss Structure

- Normal waves continue until the orb target for the wave is met.
- Every 5th wave triggers a boss encounter.
- Every 10th wave uses an elite boss and unlocks a permanent transformation choice after the boss is defeated.
- Every 5 waves, the player also receives point allocation choices for stat upgrades.

### Failure and Recovery

- When lives reach zero, the game enters game over flow.
- If try-again stocks remain, the player can spend one to continue the run.
- Otherwise, the game over screen shows final score, high score, and highest wave reached.

## Implemented Systems

### Player Ship

The player currently supports:

- Acceleration-based movement with drag
- Boosting with post-boost slide
- Free aim using mouse or controller
- Auto-fire while the shoot button is held
- Temporary shield, rapid fire, spread shot, magnet, and nuke power-ups
- Permanent in-run upgrades such as orbitals, piercing, explosive rounds, zigzag bullets, rear gun, drone escort, and afterburner
- Elite upgrades including twin cannons, auto-aim, spread shot elite, shield burst, magnet field, overclock, and rear gunner

### Enemy Roster

The current enemy set includes:

- Basic enemy
- Fast enemy
- Tank enemy
- Bomber enemy
- Sniper enemy
- Boss enemy

Regular enemies evolve immediately after the Wave 5, 10, and 15 boss milestones:

- Gen I — Standard (Waves 1–5)
- Gen II — Augmented (Waves 6–10)
- Gen III — Warform (Waves 11–15)
- Gen IV — Apex (Wave 16 onward)

Each generation uses a distinct silhouette, fixed health/speed profile, score multiplier, and additional archetype behavior. A scene-local threat director reduces simultaneous enemy pressure as generations become more advanced, while a shared attack coordinator caps major telegraphs and deployed hazards. Spawn cadence still scales by wave; regular enemy health and speed do not scale between generation milestones.

### Boss Design

Bosses are a major pacing spike and currently include:

- Telegraphing before movement changes
- Hover, dash, strafe, and dive phases
- Multiple bullet patterns such as aimed, radial, shotgun, spiral, cross, and sweep
- Rotating regular archetypes: Assault Wing, Bulwark Array, and Tempest Core
- Regular and elite versions with different health, points, orb values, and pattern mixes

### Power-Up and Upgrade Economy

Temporary power-ups currently include:

- Scale Up
- Rapid Fire
- Shield
- Spread Shot
- Magnet
- Nuke

Permanent upgrade systems include:

- Milestone stat allocation for fire rate, health, and movement speed
- Elite boss transformation options
- Run-scoped upgrade exclusion so selected elite upgrades do not repeat in the same run

### UI and Presentation

The UI currently provides:

- Score and combo display
- Lives display
- Wave banner and boss banner
- Boss health bar
- Orb meter for life restoration
- Power-up pickup notifications
- Pause menu with retry, main menu, and developer tools
- Settings menu from both title and pause screens
- Game over screen
- Try-again popup
- Stat allocation popup
- Elite upgrade popup

### Visual Layering

The current presentation stack uses:

- Procedural background stars and nebula layers
- Scrolling background shader effects
- CRT overlay and distortion layers
- Screen shake and tweened popups
- Procedural visual generation for several gameplay elements

## Technical Architecture

### Scene Structure

The main game scene currently contains:

- Background
- Star field
- Camera
- Player
- HUD
- Enemy spawner
- Power-up spawner

### Event Flow

Gameplay state is mostly event-driven:

- Enemies emit kill and damage events
- Power-ups emit collection events
- UI listens to score, life, boss, wave, and orb updates
- Game state changes are centralized in `GameManager`
- High scores and player settings are persisted through `SaveManager`

### Pause and Overlay Handling

The game uses separate CanvasLayer overlays for pause menus, popups, and end-of-run screens. This keeps the gameplay scene intact while dialogs temporarily freeze the tree.

### Input and Controls

Current bindings support:

- Movement: WASD or arrow keys
- Shoot: Space
- Boost: Shift
- Pause: Escape

## Current Strengths

The current build is already strong in a few important areas:

- The core loop is complete and playable from start to game over.
- Bosses feel like genuine set-piece encounters.
- The upgrade system gives each run a different combat identity.
- The UI communicates state clearly during high-intensity combat.
- The codebase is already organized around reusable scenes and shared signals.

## Pending Improvements

The items below are the most useful next steps based on the current build. These are inferred from the codebase and visible feature gaps rather than from a formal backlog file.

### High Priority

- Expand settings with input remapping and additional audio controls.
- Add a short tutorial or onboarding flow so the orb meter, boss cadence, and upgrade screens are easier to understand.
- Improve upgrade descriptions and in-game explanation of stacking rules, especially for elite upgrades.
- Continue playtest-driven tuning of wave pacing, boss health, orb thresholds, and life economy.

### Medium Priority

- Add more enemy archetypes and boss variants beyond the current sniper and archetype rotation.
- Add more wave modifiers or encounter variety so later waves feel less structurally similar.
- Add audio polish: music, hit sounds, pickup sounds, boss cues, and menu feedback.
- Add dedicated evolution audio cues for transformation banners, charge/phase warnings, mine arming and detonation, armor breaks, rail charge/fire, and boss damage states.
- Add accessibility improvements such as key rebinding, volume sliders, and clearer input prompts for controller users.
- Add more distinct death, hit, and reward effects to make combat events easier to parse.

### Technical Debt / Refactor Candidates

- Reduce hardcoded screen-size assumptions so the game scales more cleanly across resolutions.
- Consider moving some background spawning and presentation logic out of the main game scene if the scene continues to grow.
- Consolidate overlapping upgrade logic where temporary and permanent systems share similar behavior.
- Consider pooling bullets, orbs, and frequently spawned effects if performance becomes a problem in later waves.
- Add smoke tests or editor-run checks for the main game flow, especially boss transitions, try-again flow, and combined popup handling.

### Nice-to-Have Improvements

- Add more visual variety to backgrounds, planets, and enemy silhouettes.
- Add a proper pause-menu layout for toggles and settings, separate from the developer tools.
- Add meta-progression or unlocks if the game is intended to support longer-term play.
- Add localization support if the game is expected to reach a broader audience.

## Suggested Next Milestone

If the goal is to make the current build feel more complete, the best next milestone would be:

1. Add a settings/save system.
2. Expand enemy and boss variety.
3. Run a balance pass on waves and upgrades.
4. Add sound and accessibility polish.

That sequence improves both moment-to-moment feel and long-term replayability without requiring a major rewrite.
