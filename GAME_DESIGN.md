# Farinuff Flight Design Document

This document preserves the design text that existed before the September 10, 2026 gameplay review, then records major additions under separate headers. “Original design” means that preserved document baseline, which already included earlier expansions; it is not a reconstruction of the game's first-ever design.

The original section is historical: its references to the current build, 2D runtime, pending work, and next milestone describe that earlier document. The additions below clarify the reviewed implementation and proposed direction. **Proposed additions are not implemented or approved for implementation.**

## Design evolution index

| Section | Status at the September 10, 2026 review |
| --- | --- |
| Original design — preserved baseline | Historical document text |
| Major addition 1 — Native 3D combat and ship identity | Implemented in the reviewed code |
| Major addition 2 — The Return Signal campaign and command deck | Partially implemented; production integration remains |
| Major addition 3 — Boost mastery and combat clarity | Proposed |
| Major addition 4 — Earlier and more coherent run builds | Proposed |
| Major addition 5 — Route identity and encounter rhythms | Proposed; depends on campaign integration |
| Major addition 6 — Optional field objectives | Proposed |
| Major addition 7 — Boss targeting feedback and practice | Proposed; extends existing boss pods |

Addition numbers organize this document; they do not claim historical implementation dates. Implementation details and validation gates are in [the gameplay improvements plan](docs/gameplay-improvements-plan.md), with existing campaign scope in [The Return Signal plan](docs/additional-features-plan.md).

## Original design — preserved baseline

### Overview

Farinuff Flight is a fast, procedural 2D arcade shooter built in Godot 4. The current build focuses on a compact premium loop:

1. Learn the controls and core loop in Flight School.
2. Survive an authored Expedition through Wave 20.
3. Continue into optional Endless mastery after the first clear.
4. Collect XP orbs to fill the wave meter and earn extra lives.
5. Pick up temporary combat power-ups during the run.
6. Defeat a boss every 5 waves and choose transformative upgrades at elite milestones.
7. Bank salvage from bosses and end-of-run results, then spend it in the Hangar on permanent unlocks for future runs.

The game leans heavily into speed, readability, and high-feedback presentation with shader-driven effects, screen shake, tweened UI, and a retro CRT aesthetic.

### Design Pillars

#### 1. Readable Action

Combat should remain legible even as the screen fills with bullets, enemies, and effects. Enemy types, power-ups, and bosses each use distinct color cues and behavior patterns so the player can identify threats quickly.

#### 2. Run-Based Growth

The player is not just surviving a wave. They are building a ship during the run through:

- Temporary power-ups
- Permanent combat upgrades
- Stat allocation every milestone
- Elite boss transformation choices

#### 3. Strong Feedback

Every major action is paired with a visual response:

- Screen shake for hits, bursts, and nukes
- HUD banners for waves and bosses
- Pulse animations for combo and reward screens
- CRT and distortion layers for the final presentation

#### 4. Modular Godot Architecture

The game uses scene composition, autoload singletons, and a signal bus so the systems stay decoupled:

- `GameManager` owns global state, progression, and balancing values
- `MetaProgression` owns the persistent salvage economy, shop catalog, and purchases
- `SignalBus` routes gameplay events to UI and effects
- The main game scene assembles the player, spawners, camera, HUD, and overlays

### Current Gameplay Loop

#### Start Flow

- The game opens on the main menu.
- The first launch opens a replayable Flight School briefing; later launches go directly to the Launch Bay.
- Pressing Launch loads the main game scene.
- The player starts centered near the bottom of the screen with 3 lives and no upgrades.

#### Moment-to-Moment Play

- The player moves with keyboard or controller.
- The ship can boost for short bursts and uses a drift-based movement model.
- The player can shoot continuously while holding the fire button.
- Free aim is supported through mouse movement and right-stick input.

#### Combat and Progression

- Enemies spawn from the screen edges at a pace that increases over time.
- Killing enemies grants score, combo growth, and XP orb drops.
- XP orbs fill a wave meter and restore lives when enough are collected.
- Surplus orb progress carries into the next wave, capped at half the new wave's threshold — a boss's orb shower is a head start, not a wave skip.
- Power-ups spawn independently and drift down the screen.
- The player can collect power-ups by touch or by shooting them.

#### Wave and Boss Structure

- Normal waves continue until the orb target for the wave is met.
- Every 5th wave triggers a boss encounter.
- Every 10th wave uses an elite boss and unlocks a permanent transformation choice after the boss is defeated.
- Every 5 waves, the player also receives point allocation choices for stat upgrades.
- Defeating the Wave-20 Tempest Core completes the Expedition and presents an explicit choice: continue at Wave 21 in Endless or return to the Hangar.

#### Failure and Recovery

- When lives reach zero, the game enters game over flow.
- If try-again stocks remain, the player can spend one to continue the run, reviving at the loadout's starting lives (hull reinforcement, ship variant, and Damaged Hull already factored in).
- Otherwise, the game over screen shows final score, high score, wave reached against the persisted best, lifetime stats, and the salvage earned during the run.

#### Meta-Progression

- Boss kills bank salvage immediately: 30 for a regular boss, 60 for an elite (Wave-10) boss. Bosses are the primary salvage source.
- When the run truly ends (after the try-again flow resolves), an end-of-run bonus is banked once: diminishing score conversion (√(score ÷ 10), so combo-inflated scores can't dwarf boss rewards) plus 3 per cleared wave. The game-over screen itemizes the earnings (bosses / score / waves / milestones / modifier multiplier).
- First-clear milestones pay flat one-time awards the first time each wave milestone is cleared: 50/100/150/250/400/600 salvage for waves 5/10/15/20/25/30. Milestones are not affected by the modifier multiplier.
- Salvage spends in the Hangar, opened from the main menu:
  - Tiered permanent systems: Hull Reinforcement (+1 life/level), Tuned Thrusters (+8% speed/level), Overcharged Cannons (+8% fire rate/level), Emergency Reserves (+1 try-again stock/level).
  - Elite blueprints: Orbital Array, Piercing Rounds, and Explosive Rounds join the Wave-10 elite upgrade pool once purchased.
  - Ship variants and challenge modifiers (below).
  - Field supply consumables, consumed at the next run's start: Reserve Stock (120, +1 try-again stock, stockpile up to 3) and Pre-Loaded Drop Pod (100, start the next run with a random non-nuke power-up installed).
- Lifetime stats (total runs, total kills, best wave) persist and show on the game-over screen — with a NEW BEST WAVE highlight — and in the Hangar footer.
- The wallet, unlock levels, consumable stockpile, claimed milestones, lifetime stats, and loadout selections persist between sessions through the save file.
- Meta and ship speed/fire-rate bonuses are tracked separately from milestone stat allocation, so the allocation cap is unaffected.

#### Launch Bay and Run Loadout

- START RUN opens the launch bay: the player picks a ship variant, toggles challenge modifiers, reviews the salvage multiplier and any armed field supply, and launches.
- Ship variants are sidegrades on the same hull: Swallowtail (balanced), Interceptor (+15% speed, +10% fire rate, −1 life), Bulwark (+2 lives, −10% speed, −10% fire rate).
- Challenge modifiers raise difficulty for bonus salvage, snapshotted as a run-wide multiplier: Rapid Assault (+20%, 20% faster spawns), Armored Fleet (+30%, regular enemies +30% HP), Damaged Hull (+15%, −1 starting life), Supply Blockade (+25%, no power-up drops), Energy Drought (+25%, waves need 50% more orbs). All five pay ×1.90 salvage.

### Implemented Systems

#### Player Ship

The player currently supports:

- Acceleration-based movement with drag
- Boosting with post-boost slide
- Free aim using mouse or controller
- Auto-fire while the shoot button is held
- Temporary shield, rapid fire, spread shot, magnet, and nuke power-ups
- Permanent in-run upgrades such as orbitals, piercing, explosive rounds, zigzag bullets, rear gun, drone escort, and afterburner
- Elite upgrades including twin cannons, auto-aim, spread shot elite, shield burst, magnet field, overclock, and rear gunner
- Meta-unlockable elite upgrades (Hangar blueprints): orbital array, piercing rounds, and explosive rounds

#### Enemy Roster

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

To keep endless runs from plateauing at Gen IV, the late game adds gentle drift: past wave 16 regular enemies gain +4% health per wave (capped at ×2.0) and +1.5% speed per wave (capped at ×1.30), and past wave 15 the threat director's active cap and threat budget grow +1 per 5 waves (max +3). Boss health scaling per wave is unchanged.

#### Boss Design

Bosses are a major pacing spike and currently include:

- Telegraphing before movement changes
- Hover, dash, strafe, and dive phases
- Multiple bullet patterns such as aimed, radial, shotgun, spiral, cross, and sweep
- Rotating regular archetypes: Assault Wing, Bulwark Array, and Tempest Core
- Regular and elite versions with different health, points, orb values, and pattern mixes

#### Power-Up and Upgrade Economy

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

#### UI and Presentation

The UI currently provides:

- Score and combo display
- Lives display
- Wave banner and boss banner
- Boss health bar
- Orb meter for life restoration
- Power-up pickup notifications
- Pause menu with retry, main menu, and developer tools
- Settings menu from both title and pause screens
- Hangar shop for meta-progression purchases, from the title screen
- Launch bay for pre-run ship and modifier selection
- Game over screen with run-summary salvage breakdown
- Try-again popup
- Stat allocation popup
- Elite upgrade popup

#### Visual Layering

The current presentation stack uses:

- Procedural background stars and nebula layers
- Scrolling background shader effects
- CRT overlay and distortion layers
- Screen shake and tweened popups
- Procedural visual generation for several gameplay elements

### Technical Architecture

#### Scene Structure

The main game scene currently contains:

- Background
- Star field
- Camera
- Player
- HUD
- Enemy spawner
- Power-up spawner

#### Event Flow

Gameplay state is mostly event-driven:

- Enemies emit kill and damage events
- Power-ups emit collection events
- UI listens to score, life, boss, wave, and orb updates
- Game state changes are centralized in `GameManager`
- High scores and player settings are persisted through `SaveManager`

#### Pause and Overlay Handling

The game uses separate CanvasLayer overlays for pause menus, popups, and end-of-run screens. This keeps the gameplay scene intact while dialogs temporarily freeze the tree.

#### Input and Controls

Current bindings support:

- Movement: WASD or arrow keys
- Shoot: Space
- Boost: Shift
- Pause: Escape
- Alt controls (Settings toggle): shoot with Left Mouse Button, boost with Space

### Current Strengths

The current build is already strong in a few important areas:

- The core loop is complete and playable from start to game over.
- Bosses feel like genuine set-piece encounters.
- The upgrade system gives each run a different combat identity.
- The UI communicates state clearly during high-intensity combat.
- The codebase is already organized around reusable scenes and shared signals.

### Pending Improvements

The items below are the most useful next steps based on the current build. These are inferred from the codebase and visible feature gaps rather than from a formal backlog file.

#### High Priority

- Expand settings with input remapping (audio controls and gamepad bindings are now in).
- Add a short tutorial or onboarding flow so the orb meter, boss cadence, and upgrade screens are easier to understand.
- Improve upgrade descriptions and in-game explanation of stacking rules, especially for elite upgrades.
- Continue playtest-driven tuning of wave pacing, boss health, orb thresholds, and life economy. Note: the double-damage fix roughly halved effective player DPS versus what previous tuning assumed, so enemy and boss health likely need a retune.

#### Medium Priority

- Add more enemy archetypes and boss variants beyond the current sniper and archetype rotation.
- Add more wave modifiers or encounter variety so later waves feel less structurally similar.
- Add boss audio cues and dedicated evolution audio cues for transformation banners, charge/phase warnings, mine arming and detonation, armor breaks, rail charge/fire, and boss damage states. (Music, menu feedback, and core combat SFX are in.)
- Add more accessibility improvements such as key rebinding and clearer input prompts for controller users. (Fullscreen, reduced-flashing, and volume sliders are in.)
- Add more distinct death, hit, and reward effects to make combat events easier to parse.

#### Technical Debt / Refactor Candidates

- Continue reducing hardcoded screen-size assumptions (boss movement bounds are now viewport-relative; the parallax repeat region is still a fixed size).
- Consider moving some background spawning and presentation logic out of the main game scene if the scene continues to grow.
- Continue splitting `player.gd` (the drone escort is now a standalone `ShipDrone` component; boost, weapons, and upgrade systems are still inline).
- Continue consolidating overlapping upgrade logic where temporary and permanent systems share similar behavior (magnet pull and enemy-fire boilerplate are now shared).
- Consider pooling enemies themselves if instantiate/free churn shows up in profiling (bullets, orbs, power-ups, explosions, mines, beams, and fields are already pooled).
- Expand headless smoke-test coverage (now running in CI) further: SaveManager corrupt-save handling, ObjectPool cycles, MetaProgression economy/loadout logic, and GameManager wave/score logic are covered; a full simulated run (spawners, bosses, game-over flow) is not.

#### Nice-to-Have Improvements

- Add more visual variety to backgrounds, planets, and enemy silhouettes.
- Add a proper pause-menu layout for toggles and settings, separate from the developer tools.
- Expand meta-progression with new hull art for ship variants, unlockable power-up types, or boss-specific modifiers.
- Add localization support if the game is expected to reach a broader audience.

### Suggested Next Milestone

If the goal is to make the current build feel more complete, the best next milestone would be:

1. Add a settings/save system.
2. Expand enemy and boss variety.
3. Run a balance pass on waves and upgrades.
4. Add sound and accessibility polish.

That sequence improves both moment-to-moment feel and long-term replayability without requiring a major rewrite.

## Major addition 1 — Native 3D combat and ship identity

**Status: implemented in the reviewed code.** This updates the original Overview, Player Ship, Boss Design, Visual Layering, and Technical Architecture sections.

The production game uses native top-down 3D combat on a bounded horizontal combat plane. Depth supports craft geometry, lighting, effects, and presentation; vertical maneuvering is outside the current design. The old 2D combat runtime has been retired, while the HUD and backdrop retain 2D presentation layers.

The Swallowtail butterfly hull anchors the player's visual identity. Acquired upgrade modules appear on the craft and in upgrade-card previews. The native upgrade pool supports thirteen abilities: twin cannons, permanent spread, rear gunner, afterburner, hull plating, drone escort, auto-aim, shield burst, magnet field, overclock, orbitals, piercing, and explosive rounds. Blueprint unlocks continue to restrict access to the corresponding abilities.

Boosting supports projectile reflection, cooldown reduction after reflections, and another boost after reaching the three-reflection chain threshold. The shared gameplay scene already displays boost and chain status text; the proposed mastery addition below improves this existing system.

Boss identities are authored at stable milestones:

| Wave | Boss |
| --- | --- |
| 5 | Assault Commander |
| 10 | Iron Bulwark |
| 15 | Tempest |
| 20 | Tempest Core — Expedition finale |
| 25 | Void Harbinger — first Endless revelation |

Destructible weapon pods reduce boss volleys. Active pods also provide damage resistance to Bulwark and Tempest Core. These mechanics already give players reasons to choose targets.

The reviewed reward code offers an elite transformation at Wave 10 during the finite Expedition. Wave 20 enters victory before the ordinary elite-reward branch. Stat allocation remains at cleared Waves 5, 10, and 15. The original blanket descriptions of rewards every fifth/tenth wave must be read with this finale exception.

The native run uses scene-owned encounter, projectile, collectible, pickup, hazard, and effect managers around the shared player/combat scene. Durable progression is saved; an active run cannot be resumed after process exit. See [README](README.md), [the terminology glossary](CONTEXT.md), and [the 3D transition log](docs/3d-migration-checklist.md) for supporting context.

## Major addition 2 — The Return Signal campaign and command deck

**Status: partially implemented; production integration remains.** This expands the original Start Flow, Wave and Boss Structure, UI and Presentation, and persistence architecture.

The existing campaign proposal divides the Wave-20 Expedition into four five-wave sectors. Route choices at safe milestone boundaries give the journey direction, while short, skippable story beats explain the return signal. The map does not skip waves or replace the resident combat scene with separate missions.

Iron Wake and Ghost Lanes offer contrasting armor/mine versus speed/crossfire pressures. Tempest Veil and Echo Field provide the next sector's alternatives. The MVP changes enemy archetype weights while keeping economy, health, and other route multipliers neutral.

Authored campaign resources, route profiles, campaign state/persistence code, and a front-end navigation shell exist. At the review baseline, the production encounter director does not consume route profiles, the run controller does not integrate campaign milestone interludes, and some shell destinations remain placeholders. Their presence is a foundation, not evidence of a complete playable campaign flow.

The planned command deck brings Launch Bay, Hangar, Flight School, Settings, map, and optional Archives into a shared interface. Campaign discoveries persist independently of the run's enemies, wave, and build. The implementation must coordinate elite rewards, stat allocation, story, and route selection without unpausing combat between unresolved interludes.

Full scope and acceptance criteria remain in [The Return Signal plan](docs/additional-features-plan.md).

## Major addition 3 — Boost mastery and combat clarity

**Status: proposed, not implemented.** This expands Moment-to-Moment Play, Flight School, and UI and Presentation.

Give the existing boost mechanic a compact recharge indicator, three reflection pips, and a visible chain-opportunity timer. Use shape and audio alongside color, with a restrained HUD-only option if a cue near the craft obscures combat. Read current timing state rather than treating an old reflection count as proof a chain is still available.

Add a replayable, skippable practice drill using production movement and projectiles: move and aim, reflect a slow volley, chain a second boost, then collect orbs. Practice must not consume supplies, award salvage, update scores, or advance campaign progress.

Label wave progress and life recovery separately as “Next wave” and “Next life.” During a boss encounter, replace wave progress with the boss objective. Keep boost timing unchanged initially and tune only after observing practice attempts.

**Success criterion:** new players can deliberately reflect and chain, and can explain how the two orb progress values differ.

## Major addition 4 — Earlier and more coherent run builds

**Status: proposed balance experiment, not implemented.** This changes Wave and Boss Structure and the Power-Up and Upgrade Economy.

Prototype elite choices after Waves 5, 10, and 15 so players establish a combat identity earlier and combine abilities before the Expedition finale. Wave 20 remains the victory decision; the existing Endless reward cadence initially stays unchanged.

Add role labels and concrete stacking explanations to upgrade cards, plus a build summary in Pause. When alternatives exist, three-card offers should represent different roles while respecting owned upgrades, blueprint locks, and native capability support. For example, explain the existing five-shot central fan created by combining permanent and temporary spread.

Keep elite selection before stat allocation at a shared milestone. Handle exhausted upgrade pools without duplicate offers or blocked progression. Defer rerolls and larger synergy trees until the existing choices have been evaluated.

**Success criterion:** players form recognizable builds before Wave 20, with exactly one reward per intended milestone. Compare boss duration, damage taken, and completion rates against the current one-transformation baseline before accepting the schedule.

## Major addition 5 — Route identity and encounter rhythms

**Status: proposed; requires completion of addition 2's route integration.** This expands Combat and Progression and Enemy Roster without initially adding archetypes.

First make the authored route weights affect production enemy selection. Then introduce short encounter compositions among ordinary spawns: fast interception groups, protected tank advances, and sniper crossfire with a clear escape lane. Start with two patterns across Iron Wake and Ghost Lanes before extending the remaining routes.

Encounter groups replace part of ambient pressure rather than adding unrestricted enemies. Preserve ThreatDirector's count, weighted budget, and light-enemy requirements, plus applicable special-attack limits. Defer or cancel groups that cannot fit instead of accumulating a later spawn burst. Clear encounter state safely at boss and interlude transitions.

Keep route economy and other MVP multipliers neutral. This addition changes tactical composition and timing, not the Expedition's twenty-wave length.

**Success criterion:** players can distinguish the routes through combat, and authored encounters create different movement/targeting decisions while retaining escape opportunities and pressure limits.

## Major addition 6 — Optional field objectives

**Status: proposed follow-up, not implemented.** This adds short risk/reward decisions to Moment-to-Moment Play and Combat and Progression.

Prototype a courier that the player can intercept before it leaves the combat plane. Offer it at most once per sector on a non-boss wave. Announce the opportunity and its expiry clearly; ignoring or failing it never blocks wave completion.

Award a capped score bonus and a temporary combat pickup. Supply Blockade permits the score reward only. Avoid life or orb rewards until the recovery economy has been measured. A drifting signal-cache recovery objective is a later content option, not part of the first prototype.

The objective uses the encounter pressure budget, resolves rewards once, and cleans up on boss transitions, interludes, abandonment, or expiry. Results summarize its outcome.

**Success criterion:** pursuing the courier changes movement and exposes a meaningful choice without becoming mandatory or allowing repeated reward claims.

## Major addition 7 — Boss targeting feedback and practice

**Status: proposed extension of implemented pod mechanics, not implemented.** This expands Boss Design, Flight School, and UI and Presentation.

Make active weapon pods and their destruction consequences easier to read. Communicate reduced incoming fire and, where applicable, broken damage resistance through clear visual and audio feedback. The purpose is to expose the existing target-selection rules, not add a second boss armor system.

Extend the isolated practice mode to bosses after their first encounter, using a standardized loadout and no progression rewards. Preserve the Wave-20 climax and avoid revealing the Wave-25 boss in advance. If encounter-based unlocks are adopted, persist boss discovery with migration coverage.

**Success criterion:** players understand why attacking a pod helps and can practice a known boss without affecting supplies, scores, or salvage.

## Proposed implementation order

1. Reconcile the documented baseline and collect local run diagnostics for pacing, damage, reflections, builds, and boss duration.
2. Deliver boost/orb clarity and interactive practice (addition 3).
3. Evaluate the earlier-build reward experiment (addition 4).
4. Complete Return Signal production integration, then deliver a route/encounter vertical slice (additions 2 and 5).
5. Deliver optional objectives and boss feedback/practice as separate follow-ups (additions 6 and 7).

Start by reviewing steps 1–3 before expanding content scope. Balance and enjoyment claims are hypotheses from the design/code review, not live-playtest findings. Detailed engineering work, dependencies, risks, and validation gates are maintained in [the implementation plan](docs/gameplay-improvements-plan.md).
