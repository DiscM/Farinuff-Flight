# Farinuff Flight — Premium Compilation Release Update

**Status:** Product and release plan; 0.5.0 release-hardening slice implemented

**Prepared:** 2026-08-04

**Target model:** Premium, single-purchase PC game; Steam-first; no premium currency or paid power

**Evidence companion:** [`PREMIUM_GAME_MARKET_RESEARCH.md`](PREMIUM_GAME_MARKET_RESEARCH.md)

## Executive decision

Farinuff Flight has crossed the line from prototype to a credible commercial foundation. It already has a complete run loop, distinctive movement, five regular enemy archetypes with four evolution generations, regular and elite boss structures, a Wave-20 set piece, thirteen possible elite upgrades, six temporary power-ups, three ship frames, five opt-in challenge modifiers, persistent salvage, a Hangar, controller support, audio/settings, save validation, pooling, and CI smoke tests.

The next compilation should therefore be a **productization release**, not a broad feature dump.

The update should make one promise and prove it:

> **Build a transforming deep-space fighter, master boost-and-deflect combat, defeat the Tempest Core, then push the surviving ship into an endless high-score run.**

The highest-value work is:

1. Give the run a satisfying finite victory arc while retaining endless play.
2. Put a meaningful build decision inside the first few minutes.
3. Teach movement, aiming, boost deflection, orbs, bosses, and upgrades through play.
4. Turn the permanent economy into motivating breadth and measured goals, not a stat grind.
5. Finish accessibility, controller-only navigation, save resilience, packaging, licensing, and platform metadata.
6. Build a demo/store/playtest pipeline early enough to test the promise before content lock.

Commercial success cannot be guaranteed by a design checklist. This plan instead maximizes three controllable qualities: a clear store-page hook, a satisfying first session, and enough trusted replay value to justify a premium purchase.

## 0.5.0 implementation slice

This compilation update now includes the first productization pass: Farinuff Flight identity and version metadata, a replayable Flight School entry flow, an explicit Wave-20 victory with optional Endless continuation, versioned atomic saves with backup recovery and future-save protection, a stale-reference-safe object pool, export exclusions and third-party notices, and CI smoke tests. Release exports remain an open gate alongside interactive tutorial targets, full accessibility/remapping, end-of-run build/debrief presentation, achievements/cloud, external playtests, soak/performance validation, store assets, and final legal confirmation.

## Scope and evidence rules

This report compares three kinds of evidence:

- **Verified implementation:** present in project files or observed in a local Godot run.
- **Documented intent:** described in the README, design document, visual plan, or changelog, but not necessarily validated through external playtesting.
- **Recommendation:** a proposed product decision that must pass playtests or market tests before becoming final.

The audit covered the repository, project/export settings, gameplay and progression scripts, save/settings code, UI, tests, assets, and a short local run under Godot 4.6.3. Market and platform claims are sourced in the companion research report.

## Current product snapshot

| Area | Verified current state | Readiness | Main implication |
| --- | --- | ---: | --- |
| Product identity | Main menu, project metadata, README, design doc, changelog, and Windows export say **Farinuff Flight** with semantic version **0.5.0**. The existing icon still needs final capsule-safe approval. | 4/5 | The product promise is now consistent; final art approval and store surfaces remain. |
| Core play | Drift movement, free aim, held fire, boost, post-boost slide, afterimages, projectile deflection, combo, waves, bosses, recovery, and game over are implemented. | 4/5 | The verbs are differentiated enough to market, but fun and mastery still need external proof. |
| Run builds | Six temporary pickups; ten base elite upgrades plus three blueprint unlocks; numerical allocations every five cleared waves. | 3/5 | There is real build variety, but the strongest decisions arrive late and numerical allocation is less exciting than visible transformation. |
| Encounters | Five regular archetypes, four evolution generations, threat budgeting, coordinated hazards, three rotating regular boss variants, an elite Void Harbinger, and Wave-20 Tempest Core phases. | 3/5 | Content is deeper than the old docs imply; encounter sequencing and repetition need measured playtests. |
| Meta-progression | Salvage, tiered systems, elite blueprints, ship sidegrades, modifiers, consumables, first-clear awards, and lifetime stats persist. | 3/5 | The economy can support premium replay, but prices and permanent power must be tuned against actual run earnings. |
| Onboarding | A replayable five-page Flight School now covers movement, aim, boost reflection, orb/life recovery, build choices, salvage, and the Wave-20 target. It is still a static briefing rather than an interactive Expedition tutorial. | 3/5 | The first-session promise is visible; contextual success states and input-family prompts remain. |
| Accessibility | Master/music volume, screen shake, CRT, distortion, fullscreen, reduced flashing, alternative controls, keyboard, mouse, and gamepad inputs exist. | 2/5 | Strong start, but remapping, prompt switching, text/UI scaling, contrast options, aim assists, and accessibility testing are missing. |
| Technical quality | Typed GDScript, scene composition, pooled high-churn objects, corrupt-save tests, versioned atomic saves with backup recovery, first-party warning cleanup, visual smoke tests, and CI smoke tests are present. | 4/5 | Release exports, soak tests, migration coverage beyond v1/v2, and hardware coverage still need proof. |
| Premium completion | Wave 20 now presents a clear victory state with salvage feedback and an explicit Continue to Endless / End Run choice. | 4/5 | The core arc is framed; first-clear unlock/debrief/build summary and credits remain. |
| Store/platform readiness | Linux and Windows presets now carry product metadata, exclude development/tooling paths, and retain notices; CI release packaging is not currently configured. Achievements, cloud, localization, store kit, demo, and legal confirmation remain open. | 2/5 | The package foundation exists; platform and launch-proof work must continue. |

These scores are planning aids, not review predictions.

## Runtime and repository observations

### Encouraging signals

- Godot identified 58 scenes, 107 scripts, and 1,572 assets in the main project.
- A short local run reached gameplay with no observed push errors or orphan nodes.
- The sampled local frame rate was about 145 FPS on an Apple A18 Pro under the Compatibility renderer. This is only a developer-machine snapshot, not a minimum-spec result.
- The active-play sample reported roughly 496 draw calls and 278 MB static memory after twelve seconds of movement and firing.
- CI runs eight headless smoke scenes covering evolution visuals, VFX, shared rendering, player upgrades, bosses, modal flow, autoloads, saves, meta-progression, and pooling.
- Corrupt, mistyped, pre-version, and unsupported-version save inputs have automated coverage.

### Release risks found

- Runtime script loading no longer emits the previously identified first-party integer-division, material-shadowing, and unused-parameter warnings. Tooling-server warnings remain outside the shipped game and are excluded from export.
- The short run grew from roughly 2,511 objects / 348 nodes to 3,562 objects / 1,158 nodes while enemies and pooled effects accumulated. No orphan nodes were reported, but a 30–60 minute soak is required to distinguish normal pool warm-up from unbounded growth.
- Save writes now use a temp-file flush/close, rotation, and promotion path with a last-known-good backup. Future-version saves are preserved read-only rather than overwritten; only v1/pre-versioning data is currently migrated.
- Linux and Windows export presets retain `all_resources` but now apply explicit include/exclude filters. The repository contains approximately 130 MB of source audio packs and 53 MB of source UI packs while gameplay references only ten audio files and three UI-pack textures, so release-package inspection remains mandatory and a selected-dependency production tree is still a future improvement.
- A local release export could not be produced because Godot export templates were not installed; the CI workflow currently runs smoke tests only, so release export and package inspection remain open work.
- Windows metadata is populated for Farinuff Flight 0.5.0, including product name, version, description, copyright, and icon.
- `THIRD_PARTY_NOTICES.md` now consolidates provenance and license actions; SunGraphica and Shapeforms permissions still require confirmation.

## What a premium single-purchase game must communicate

The premium model changes the design goal. The game is not selling faster progress; it is selling a complete, trusted experience.

The product needs to communicate all of the following quickly:

- **A specific fantasy:** a lone transforming fighter making an impossible return flight.
- **A distinctive verb:** boost-and-deflect survival, not only auto-fire and dodging.
- **An understandable run goal:** reach and defeat the Tempest Core.
- **Visible mastery:** movement lines, safe deflections, readable telegraphs, and score expression.
- **Build ownership:** upgrades visibly and mechanically change the ship.
- **Replay value:** alternative frames, modifiers, blueprints, route/encounter variation, score chasing, and endless continuation.
- **Respect for the buyer:** no real-money currency, no paid power, no manipulative timers, reliable saves, broad controls, and a clean options menu.

Meta-progression is compatible with a premium game when it creates goals and breadth. It becomes a liability when early failure feels deliberately weak, basic comfort is locked behind grind, or consumable sinks delay permanent unlocks. Farinuff Flight should let skill dominate every run while salvage opens alternatives, challenges, and expression.

## Recommended target product

### Positioning sentence

> **Farinuff Flight is a neon deep-space action roguelite where every boost can become a counterattack and every elite upgrade physically transforms your ship. Survive a 20-wave expedition, break the Tempest Core, then continue into endless escalation.**

### Primary audience

- Players who like short-to-medium action roguelite runs, score chasing, build combinations, and readable arcade combat.
- Keyboard/mouse and controller players on PC, including handheld play.
- Players who want a complete premium game rather than a free-to-play progression loop.

### Product modes

1. **Expedition** — the default, teachable, 20-wave run with a clear finale and completion reward.
2. **Endless Flight** — unlocked after the first Tempest Core clear, or entered immediately after victory, preserving the current scaling and high-score identity.
3. **Challenge Flights** — existing modifiers packaged as named score/salvage contracts; daily seeds are a later option, not a launch dependency.

This uses content that already exists. It changes pacing and framing more than architecture.

## Compilation release scope

### Epic 1 — One product identity

**Goal:** every public and binary surface says Farinuff Flight and tells the same story.

- Rename `config/name`, Windows export path, product metadata, README title, design-document title, executable name, and in-game build string.
- Choose a semantic release version and show the same value in-game, in exported file metadata, and in the changelog.
- Replace the generic project icon with approved Farinuff Flight icon/capsule-safe art.
- Write final one-sentence, short, and long descriptions from the positioning sentence.
- Create `THIRD_PARTY_NOTICES.md` and an asset provenance table covering source, author, license, modifications, and whether the asset ships.
- Remove or exclude development packs, mockups, tests, and generator projects from release exports.

**Acceptance gate:** a fresh install, executable properties, title screen, save directory, screenshots, store draft, and documentation use one name and version.

### Epic 2 — First-run flight school

**Goal:** a new player understands the special verb and reaches meaningful play without reading a manual.

Use a short, optional, replayable first-run sequence embedded in a real Expedition:

1. Move and aim at safe targets.
2. Hold fire and collect the first orb.
3. Boost through a telegraphed projectile to demonstrate deflection.
4. Show that orbs fill both wave progress and the life meter.
5. Present the first meaningful build decision.
6. Explain salvage only after the run ends.

Requirements:

- Detect the active input family and switch prompts between keyboard/mouse and controller.
- Never freeze action for a paragraph; use one instruction and one success state at a time.
- Provide “Skip tutorial,” “Replay tutorial,” and a concise controls/help screen.
- Explain temporary versus run-long versus permanent unlocks with distinct terms and colors.
- Add tooltips for stacking, timers, cooldowns, and whether an upgrade is additive or multiplicative.

**Acceptance gate:** at least 80% of first-time external testers can explain boost deflection, orb progress, and the next run goal without developer assistance.

### Epic 3 — A complete Expedition arc

**Goal:** transform “endless until death” into a premium run with a beginning, escalation, climax, and optional continuation.

Proposed 20-wave structure:

| Segment | Purpose | Current content to use | New work |
| --- | --- | --- | --- |
| Waves 1–4 | Learn, establish rhythm, make first build | Basic/Fast introduction, first power-ups | Earlier run-defining choice; authored spawn beats for the first run |
| Wave 5 | First mastery check | Rotating regular boss | Clear reward and transformation beat |
| Waves 6–9 | Add tactical pressure | Generation II, Bomber/Tank/Sniper, hazards | Encounter modifiers and better telegraph teaching |
| Wave 10 | Mid-run peak | Void Harbinger, elite selection | Strong midpoint reward, build summary, pacing reset |
| Waves 11–15 | Test the build | Generation III, second regular boss | More encounter sequencing, fewer repeated combinations |
| Waves 16–19 | Apex pressure | Generation IV and late scaling | Finale foreshadowing and escalating audiovisual state |
| Wave 20 | Victory climax | Multi-phase Tempest Core | Victory state, unlock/reward, credits or debrief, endless choice |

The current elite choice occurs after every tenth-wave boss while numerical allocation occurs every five cleared waves. Prototype one of these cadences:

- **Preferred:** one visible subsystem choice by Wave 3–5, elite transformations at Waves 5/10/15, final build test at Wave 20.
- **Lower-risk:** preserve current elite cadence but add a pre-run starter module and turn Wave-5 allocation into a visually named subsystem choice.

Do not add more upgrade catalogs until tests establish first-choice time, average choices per completed Expedition, dead picks, dominant combinations, and whether players can predict synergies.

**Acceptance gate:** first meaningful build choice in the first five minutes; first boss is reached by most new testers; first clear feels conclusive; endless continuation is obvious but optional.

### Epic 4 — Build clarity and replay value

**Goal:** make the existing upgrade depth legible and expressive.

- Show the current ship build on pause and in the end-of-run report.
- Replace emoji-first upgrade identity with the canonical ship/module preview work already described in the visual implementation plan.
- Use consistent keywords such as `Projectile`, `Fire Rate`, `Area`, `Companion`, `Defense`, `Mobility`, and `Collection`.
- Show exact stacking behavior only where it affects choice quality; keep combat text concise.
- Add a small discovery log for ships, enemies, bosses, elite modules, modifiers, and cleared challenges.
- Give sidegrade ships a distinct starting passive or interaction, not only percentage changes, after balance proves the base profiles.
- Prefer authored encounter combinations, boss mutations, and contracts over simply multiplying enemy health.

**Acceptance gate:** testers can identify their build from the ship and pause summary, understand why an offered upgrade helps it, and name at least two different builds they want to try next.

### Epic 5 — Fair permanent progression

**Goal:** make salvage motivate replay without making the starting ship feel intentionally incomplete.

- Measure salvage per minute, first-purchase time, category completion time, and failure rewards across new, median, and skilled testers.
- Target the first meaningful permanent purchase within roughly the first two completed runs; validate rather than hard-code this assumption.
- Put sidegrades, blueprints, and challenge unlocks ahead of raw permanent power in the shop presentation.
- Cap permanent stat power tightly enough that boss learning and movement skill remain decisive.
- Keep consumables optional and inexpensive; do not let them become the optimal use of early salvage or a tax on retrying.
- Add preview, compare, and confirmation states for purchases.
- Show milestone goals before they are earned and celebrate first clears without overwhelming the run result.

**Acceptance gate:** new players always make visible progress, skilled players can succeed without grinding every stat tier, and no purchase is required to make base controls or readability comfortable.

### Epic 6 — Accessibility and input completion

**Goal:** every screen and run can be completed with a controller, keyboard, or mouse, with comfort options available before play.

Required for the compilation:

- Full action remapping with conflict handling, restore defaults, and per-device prompt display.
- Controller-only navigation across title, settings, Hangar, Launch Bay, pause, upgrades, allocation, try-again, game over, and credits.
- Separate SFX and music sliders; consider additional combat/UI channels after an audio mix pass.
- Text/UI scale options and tests at the smallest supported viewport.
- Independent toggles or sliders for screen shake, CRT, distortion, bloom/flash intensity, and aim assist. If cinematic camera motion is implemented, include a reduced-motion option for it.
- Reduced-flashing audit of every boss, nuke, upgrade, damage, and evolution effect—not only the explosion/effect helpers.
- Color-independent threat communication through silhouette, motion, outline, or icon.
- Pause behavior that never consumes a selection input on resume.

Recommended after the core gate:

- Aim magnetism and right-stick sensitivity/deadzone controls.
- Auto-fire toggle, hold/toggle boost option where mechanically safe, and vibration control if rumble is added.
- Localization-ready strings and layout even if the first release ships in one language.

**Acceptance gate:** complete one Expedition without touching a mouse, all controls can be rebound, and an accessibility test matrix has no progression blocker.

### Epic 7 — Stability, saves, and performance

**Goal:** a premium buyer can trust long runs and persistent progress.

- Change save writes to temp file → flush/close → atomic replace, with a last-known-good backup.
- Add migrations for every future schema version; never silently discard a buyer’s progress because the game updated.
- Add Steam Cloud configuration only after save paths, conflict behavior, and backup recovery are stable.
- Add a deterministic full-run harness covering spawn, boss, reward, upgrade, try-again, finalization, and save reload.
- Add 30-, 60-, and 120-minute soak tests with object/node counts, pool sizes, memory, frame time, and orphan count.
- Profile the fully upgraded player during maximum projectiles, magnet, drone, Shield Burst, Overclock, boost trail, evolved hazards, and a boss.
- Establish low/mid/high PC test machines and handheld-equivalent targets. A fast development Mac is not a minimum specification.
- Treat script warnings in first-party code as build failures on the release branch.
- Build release exports in CI and retain zipped artifacts for manual QA.

Proposed performance gate:

- 60 FPS at the chosen minimum specification during the defined stress scene.
- No sustained frame-time spikes caused by upgrade selection or cache rebuilds.
- No unbounded object, node, or memory growth after pool warm-up.
- Zero first-party errors and zero orphan nodes in the soak log.

### Epic 8 — Shipping and legal hygiene

**Goal:** produce small, reproducible, properly attributed builds.

- Replace `all_resources` with a shipping include/exclude policy or a clean production asset tree.
- Keep only referenced audio clips and UI textures in the shipping project; archive source packs outside the export root where practical.
- Exclude `tests/`, `tools/`, `design/`, `mockups*`, raw PSD/AI/EPS/PDF files, preview captures, and the nested PixelPlanets generator project unless required at runtime.
- Verify every third-party asset permits commercial redistribution in the form used.
- Include required license text in the build and credits.
- Populate Windows executable metadata and add reproducible Linux/Windows release presets.
- Decide whether Linux is a supported launch platform based on QA capacity, not only preset availability.

**Acceptance gate:** a clean checkout can build the exact release artifacts; package contents have been inspected; every shipped third-party file has provenance.

### Epic 9 — Store, demo, and launch proof

**Goal:** test whether strangers understand and want the game before final content lock.

- Draft the Steam page as soon as the positioning sentence and final visual direction are locked.
- Make capsule art communicate ship, threat, and neon-space identity at thumbnail size; avoid relying on small subtitle text.
- Lead the trailer with playable movement, a boost deflection, visible ship transformation, boss escalation, and the Tempest Core—not logos or lore.
- Build a focused demo that reaches the distinctive verb and a boss quickly. Keep the demo representative of final quality and clearly communicate what the full game adds.
- Use the demo to test onboarding, hardware compatibility, retention to first boss, and wishlist intent.
- Add achievements around mastery, discovery, challenge contracts, builds, and Expedition clears; avoid grind-only counters.
- Prepare store screenshots that each communicate a different buyer benefit: movement, transformation, boss, build screen, challenge loadout, and late-run spectacle.
- Define a review/feedback triage process and an update cadence that the team can actually sustain.

**Acceptance gate:** unaided players can describe the game’s differentiator after the trailer or ten minutes of the demo, and the store page has passed external thumbnail/message tests.

## Comparable premium design patterns

The companion research report evaluates relevant single-purchase games from official store and developer sources. The comparison should be used as a pattern library, not as a feature checklist.

| Premium game | Officially presented structure | Direct comparison to Farinuff Flight | Lesson for this compilation |
| --- | --- | --- | --- |
| [Vampire Survivors](https://store.steampowered.com/app/1794680/Vampire_Survivors/) | US$4.99 snapshot; minimal-input survival, characters, run upgrades, persistent power, achievements, Cloud, and free power-up refunds. | Farinuff asks much more of movement and aim, but does not yet offer comparable simplicity or accumulated breadth. | Sell active mastery; add free respec so experimentation is not punished. |
| [Brotato](https://store.steampowered.com/app/1942280/Brotato/) | US$4.99 snapshot; runs under 30 minutes, short waves, frequent shopping, many characters/items, granular enemy assists, achievements, Cloud, Workshop, and local co-op. | Farinuff has fewer interruption points and more physical control, but its major build choices are much farther apart. | Measure choice frequency and keep wave goals/session expectations explicit. |
| [Halls of Torment](https://store.steampowered.com/app/2218750/Halls_of_Torment/) | US$6.66 snapshot; 30-minute runs, stages, characters, quests, bosses, extracted items, achievements, and Cloud. | Farinuff has milestones and meta unlocks but no promoted completion target. | Make the Tempest Core a finite objective and publish a concrete launch-content promise. |
| [20 Minutes Till Dawn](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/) | US$4.99 snapshot; title-level 20-minute promise, directional aim, active fire, upgrades, characters/weapons, boss rewards, runes, achievements, and Cloud. | This is the closest control-model comparison; Farinuff's active aim is paired with deeper momentum and reflection. | A crisp bounded run makes active controls easier to understand and market. |
| [Deep Rock Galactic: Survivor](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/) | US$12.99 snapshot; auto-fire plus mining, terrain, objectives, procedural caves, upgrades, extraction, achievements, and Cloud. | Its second verb and established world make the price/value pitch obvious. Farinuff's equivalent second verb is boost-as-defense-and-offense. | Make reflection affect builds, encounters, and bosses—not remain a subtle movement perk. |
| [Nova Drift](https://store.steampowered.com/app/858210/Nova_Drift/) | US$17.99 snapshot; active arcade control, body/weapon/shield gear, 200+ modular upgrades, demo, achievements, Cloud, and leaderboards. Its [developer retrospective](https://store.steampowered.com/news/posts/?appgroupname=Nova+Drift&appids=858210&enddate=1744121944&feed=steam_community_announcements) says 1.0 added a final boss/ending and made Endless unlock after a win. | It is the closest structural precedent, but with far more upgrade breadth. | Follow the finite-ending plus Endless pattern; organize upgrades into readable families instead of chasing its count. |
| [Soulstone Survivors](https://store.steampowered.com/app/2066020/Soulstone_Survivors/) | US$14.99 snapshot; demo, achievements, stats, Cloud, 350+ skills, 100+ weapons, characters, curses, modes, and bosses. | Its higher price is supported by conspicuous breadth. Farinuff is currently a tighter arcade product. | Compete on coherence and feel; do not price-match content scale the launch package cannot truthfully claim. |

Prices are official-store snapshots from 2026-08-04, not recommended prices or sales estimates. The evidence report recommends testing **US$7.99 versus US$9.99** only after the finite run, onboarding, build structure, saves/platform work, and demo are representative. Final pricing remains a market test, not a conclusion from competitor price alone.

| Pattern to compare | Farinuff Flight now | Compilation response |
| --- | --- | --- |
| Immediate build agency | Temporary drops are random; strongest permanent run choices arrive on later boss milestones. | Put one meaningful choice in the opening segment. |
| Clear run completion | Endless failure is the primary endpoint. | Promote Wave-20 Tempest Core to Expedition victory; retain endless continuation. |
| Character/loadout identity | Three ship frames are percentage sidegrades. | Add carefully tested interaction-level identity after base balance. |
| High build combinatorics | Thirteen elite candidates and projectile stacking already provide combinations. | Improve cadence, previews, keywords, history, and end-of-run build recall before adding quantity. |
| Challenge ladder | Five modifiers multiply salvage and can stack. | Package them as named contracts with completion records and score goals. |
| Premium trust | All currency is earned in-game. | State “single purchase / no paid currency,” protect saves, and avoid grind-balanced sinks. |
| Spectacle with readability | Strong neon/CRT effects and differentiated threats are explicit pillars. | Make reduced-effects modes comprehensive and test late-run occlusion. |
| Broad PC usability | Keyboard, mouse, gamepad, fullscreen, audio, reduced flashing exist. | Finish remapping, controller UI, handheld layouts, UI scale, and platform QA. |

Do not clone the largest competitors’ content counts. Farinuff Flight should compete through movement feel, deflection mastery, cumulative ship transformation, and a clean 20-wave arc.

## Release roadmap

### Phase A — Product truth

- Lock name, positioning, audience, mode structure, and premium promise.
- Prototype Expedition victory and the earlier build choice.
- Instrument local run summaries for playtests.
- Consolidate licensing and clean export scope.
- Produce first store-page copy and capsule/trailer briefs.

**Exit:** the team can explain the game in one sentence, a new tester reaches the hook, and a clean release artifact can be built.

### Phase B — First-session quality

- Implement flight school, input-family prompts, help, remapping, and controller UI.
- Finalize first ten waves, first boss, choice cadence, and early salvage pacing.
- Run repeated blind tests with recordings and structured notes.
- Fix blockers before adding late-game content.

**Exit:** first-session comprehension and first-boss reach gates pass.

### Phase C — Premium value

- Finalize Wave 20 victory/debrief and endless continuation.
- Tune encounters, boss sequencing, build balance, ship identity, contracts, and economy.
- Add discovery log, achievements, credits, and end-of-run build summary.
- Complete audio, visual readability, and accessibility passes.

**Exit:** a representative group completes Expeditions, wants another run for specific reasons, and encounters no dominant build or progression wall.

### Phase D — Demo and release candidate

- Lock demo content and final store assets.
- Run minimum-spec, handheld, multi-resolution, save/cloud, upgrade, and long-soak QA.
- Build signed/versioned release artifacts through CI.
- Freeze features; fix only release blockers and verified balance outliers.

**Exit:** release checklist, package inspection, legal notices, rollback plan, support workflow, and store configuration are complete.

## Playtest scorecard

Every build should record the same small set of outcomes. Numbers below are proposed gates and must be revised after a baseline round.

| Question | Measure | Initial target |
| --- | --- | ---: |
| Do players understand the hook? | Can explain boost deflection and ship transformation after play | ≥80% |
| Does agency arrive quickly? | Time to first meaningful build decision | ≤5 min |
| Is early difficulty fair? | First-time testers reaching first boss | ≥70% |
| Is the run goal visible? | Can state what Wave 20 represents | ≥80% |
| Is completion satisfying? | Completers who choose another run or endless continuation | Track baseline, then improve |
| Are builds diverse? | Pick rate, win rate, and abandonment by upgrade/ship/modifier | No unexplained dominant option |
| Is meta pacing respectful? | Runs/time to first purchase and first blueprint/ship | First useful purchase by ~2 runs |
| Is the game readable? | Deaths testers describe as unclear or visually hidden | <10% of deaths |
| Is controller support complete? | Expedition completion without mouse/keyboard | 100% flow coverage |
| Is the build stable? | Crashes, errors, or lost/corrupt progress | 0 release blockers |
| Is performance stable? | Stress-scene FPS and long-soak growth | 60 FPS min-spec; no unbounded growth |

For each external session, capture build version, device, input method, experience level, run seed, selected ship/modifiers, decision times, death causes, earned/spent salvage, and one unaided “what is this game?” response. Do not collect personal data that is not needed.

## Release acceptance checklist

### Design

- [ ] Expedition has a clear opening, escalation, Tempest Core victory, reward, and endless option.
- [ ] First meaningful build choice occurs within the agreed target.
- [ ] Temporary, run-long, and permanent progression are visually and verbally distinct.
- [ ] Every enemy attack has a readable cue and a learnable response.
- [ ] Economy targets are based on observed run earnings, not developer estimates alone.
- [ ] No required accessibility or comfort feature is locked behind progression.

### Content and presentation

- [ ] Menu, executable, documentation, store page, and save identity all say Farinuff Flight.
- [ ] Trailer and screenshots show actual gameplay and the core differentiator.
- [ ] Ship transformations remain readable in maximum-build combat.
- [ ] Music, combat, UI, boss, and reward moments have an intentional mix.
- [ ] Credits and third-party notices are available in-game and in the package.

### Input and accessibility

- [ ] Full controller-only path has passed.
- [ ] Keyboard/mouse and controller actions can be remapped and restored.
- [ ] Active-device prompts update correctly.
- [ ] Reduced flashing, shake, distortion/CRT, text scale, and aim options pass their test matrix.
- [ ] Critical information is not color-only.

### Engineering and operations

- [ ] All smoke, full-run, save migration, backup recovery, stress, and soak tests pass.
- [ ] CI produces versioned Linux/Windows release artifacts selected for launch.
- [ ] Package audit confirms no development packs, tests, mockups, or unneeded source assets ship.
- [ ] Minimum/recommended requirements come from measured hardware.
- [ ] Update, rollback, save compatibility, and support procedures are documented.

### Store and premium trust

- [ ] Store copy accurately describes current features and supported platforms.
- [ ] Demo quality and controls represent the full game.
- [ ] Achievements and cloud saves pass platform testing if enabled.
- [ ] Price is tested against final scope and comparable base prices; it is not chosen from development time alone.
- [ ] No real-money currency, paid power, or progression-skipping purchase is implied.

## Explicit non-goals for this compilation

- No live-service roadmap as a substitute for launch content.
- No premium currency, paid consumables, battle pass, or real-money progression.
- No multiplayer unless a separate product case and technical plan justify it.
- No large catalog expansion before onboarding, choice cadence, and balance instrumentation work.
- No engine/render-pipeline migration solely for visual novelty.
- No daily challenge backend as a launch blocker; seeded local contracts are sufficient if the mode is valuable.
- No promise of Steam Deck verification before controller, resolution, performance, and platform review are complete.

## Immediate next actions

1. Approve or reject the **20-wave Expedition → Tempest Core victory → optional endless** structure.
2. Prototype and blind-test the two proposed early-choice cadences before producing new upgrades.
3. Rename shipping metadata and establish one version source.
4. Add export exclusions, third-party notices, and a CI release artifact.
5. Add atomic save/backup handling and a full-run/soak harness.
6. Draft the store page and demo slice from the approved positioning sentence.
7. Run a baseline of at least 10 blind first-session tests, then revise every numerical target in this report from evidence.

## Definition of success

The compilation is successful when Farinuff Flight no longer feels like a capable endless prototype with many systems. It feels like one deliberately authored premium game: easy to understand, hard to master, satisfying to finish, compelling to replay, safe to buy, and ready to recommend.
