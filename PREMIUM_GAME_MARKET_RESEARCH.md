# Farinuff Flight: Premium Game Market and Release Research

**Research date:** 2026-08-04

**Product model:** Premium, single-purchase indie action roguelite / survivor-style arcade game

**Purpose:** Product and release direction for the next major compilation update

**Integrated release plan:** [`COMPILATION_RELEASE_UPDATE.md`](COMPILATION_RELEASE_UPDATE.md)

**Implementation note:** This research informed the 0.5.0 productization slice. The repository now has the Farinuff Flight identity, Flight School briefing, Wave-20 victory/Endless choice, resilient save writes, release metadata, CI artifact packaging, and a third-party notice register. The gaps in this report remain the next validation queue rather than completed claims.

## Executive decision

Farinuff Flight already has a credible mechanical hook: free aiming and held fire, momentum-heavy movement, a boost that doubles as offense and defense through drifting, projectile reflection, and chaining, plus a readable wave structure. It also has more engineering maturity than its presentation suggests: object pooling, spawn-safety logic, threat limits, controller input, persistent progression, reduced-flashing and fullscreen settings, audio buses, and automated smoke checks are all present in the repository ([README.md](README.md), [GAME_DESIGN.md](GAME_DESIGN.md), [CHANGELOG.md](CHANGELOG.md)).

At the research snapshot, the main commercial risk was not the lack of another upgrade or enemy. The game still read as an endless prototype rather than a finished premium journey: a player could improve a score and buy permanent power, but there was no authored completion target, final confrontation, ending, or clear promise for what “beating the game” meant. Nova Drift's developer identified the absence of an ending and final boss as a specific reason that game was not yet 1.0; its eventual release added a final boss and ending while retaining Endless as an unlockable mode ([Nova Drift 1.0 retrospective](https://store.steampowered.com/news/posts/?appgroupname=Nova+Drift&appids=858210&enddate=1744121944&feed=steam_community_announcements)). That is the most directly relevant first-party precedent for Farinuff Flight.

**Recommended product direction:** make the next compilation release a complete, replayable premium game built around a finite first-clear journey, then preserve the current endless score chase as post-clear mastery.

- Add a standard campaign/run with a final boss and ending. Treat a roughly 20–30 minute clear as the first playtest target, not a locked specification. Unlock Endless after the first clear, or keep it visible but clearly label it as an alternate score mode.
- Position the game around its differentiator: **an active-aim butterfly starfighter roguelite where boosting, drifting, and reflecting fire are the build engine**. Do not lead with the generic “space shooter” or “survivor-like” label.
- Rebalance progression toward horizontal possibility—ships, upgrade branches, build-enabling blueprints, challenge modifiers, and cosmetic mastery—rather than letting permanent damage-adjacent stats become the dominant answer to difficulty.
- Complete the premium trust layer before release: onboarding, remapping, readable/scalable UI, independent sound controls, dynamic controller prompts, save migration and backup, Steam Cloud, achievements, a polished demo, and a tested Steam Deck path.
- Market with the actual game. Steam explicitly recommends leading with gameplay, showing the HUD, assuming a muted viewer may leave in under ten seconds, and using at least five real gameplay screenshots ([Steam trailer guidance](https://partner.steamgames.com/doc/store/trailer), [Steam graphical asset guidance](https://partner.steamgames.com/doc/store/assets/standard)). Farinuff Flight's boost/reflection chain should be visible in the first seconds of its trailer and first screenshot set.

This report does **not** claim that a feature guarantees sales. Official sources can establish platform requirements, discoverability mechanisms, and observable product choices; only playtests, store-page tests, demo behavior, wishlists, conversion, reviews, and retention can establish whether this particular game has product-market fit.

## Evidence and confidence conventions

- **Observed:** directly present in the repository or stated on an official store/developer/platform page.
- **Inference:** interpretation of observed facts. It is labeled so it is not confused with market evidence.
- **High confidence:** supported by direct platform requirements, multiple relevant first-party examples, or a clear mismatch in the current build.
- **Medium confidence:** a strong product hypothesis that still needs playtesting or commercial testing.
- **Low confidence:** useful option, but evidence is insufficient to choose it without a test.

Prices, feature lists, language counts, and store features are snapshots from official pages on 2026-08-04. Store review counts are intentionally not used as sales estimates.

## 1. Current-product audit

### 1.1 Current promise and loop

The documented loop is: move and aim freely, hold fire, boost/dash for speed and defense, collect orbs and temporary powers, face a boss every five waves, spend stat points, choose an elite upgrade every ten waves, die or use a limited try-again, then spend salvage on permanent progression ([README.md](README.md), [GAME_DESIGN.md](GAME_DESIGN.md), [autoloads/game_manager.gd](autoloads/game_manager.gd)). Three ship variants and five challenge modifiers add starting-rule variation. The modifier stack can raise the score multiplier to 1.90×, creating an understandable risk/reward layer ([GAME_DESIGN.md](GAME_DESIGN.md)).

The distinctive verbs are stronger than the genre summary. Active aiming, momentum, drifting, projectile deflection, and chained boosts create a player-authored movement rhythm instead of an entirely automatic survivor loop. This is the feature set the store page should communicate.

### 1.2 What is already commercially useful

| Area | Repository evidence | Commercial implication |
|---|---|---|
| Mechanical identity | Held fire plus free aim; boost, drift, deflection, and boost chaining ([README.md](README.md)) | A marketable active-skill contrast with auto-attack survivor games. |
| Run cadence | Boss every 5 waves; stat allocation every 5; elite upgrade every 10 ([GAME_DESIGN.md](GAME_DESIGN.md)) | Clear milestones, but the spacing and total run duration need validation. |
| Content variation | Three ships, five challenge modifiers, six temporary powers, ten base elite upgrades plus three blueprint unlocks, multiple enemy generations ([GAME_DESIGN.md](GAME_DESIGN.md)) | Enough to test build identity, but not yet evidence of durable replayability. |
| Fairness engineering | Spawn-distance rerolls, threat management, telegraphs, and later-wave scaling are implemented ([CHANGELOG.md](CHANGELOG.md), [systems/enemy_spawner.gd](systems/enemy_spawner.gd)) | A sound foundation for challenge that feels authored rather than arbitrary. |
| Performance work | Object pooling, CI smoke tests, and spawn/performance changes are recorded ([CHANGELOG.md](CHANGELOG.md)) | Good release groundwork; deep-run hardware testing is still required. |
| Controller support | Keyboard and controller actions exist for movement, shooting, and boost ([project.godot](project.godot)) | Necessary but not sufficient for full controller or Steam Deck readiness. |
| Accessibility start | Fullscreen, reduced flashing, screen shake, CRT/distortion, alternate controls, and volume settings persist ([autoloads/save_manager.gd](autoloads/save_manager.gd), [ui/settings_menu.gd](ui/settings_menu.gd)) | Good intent and useful toggles, with several high-impact gaps remaining. |
| Persistent progression | Salvage, milestones, permanent upgrades, blueprints, consumables, variants, and modifiers are implemented ([GAME_DESIGN.md](GAME_DESIGN.md)) | A retention layer exists, but permanent power and save durability need revision. |

### 1.3 Release-critical gaps

| Gap | Evidence | Why it matters | Confidence |
|---|---|---|---|
| No finite completion arc | Current mode is documented as endless; no victory/ending is present ([GAME_DESIGN.md](GAME_DESIGN.md), [autoloads/game_manager.gd](autoloads/game_manager.gd)) | A premium 1.0 needs a legible completion promise even if replayability is endless. | **High** |
| Sparse authored build decisions | Stat points arrive every five waves and elite choices every ten; temporary powers are pickups ([GAME_DESIGN.md](GAME_DESIGN.md)) | A large upgrade pool does not create build expression if most runs expose few choices. | **Medium–High** |
| Onboarding unfinished | Tutorial/onboarding remains high priority in the design backlog ([GAME_DESIGN.md](GAME_DESIGN.md)) | The unique boost/reflection system cannot sell the game if players do not understand it quickly. | **High** |
| Input remapping absent | It remains a high-priority backlog item; current actions are fixed in project configuration ([GAME_DESIGN.md](GAME_DESIGN.md), [project.godot](project.godot)) | This blocks an important accessibility baseline and weakens controller support. | **High** |
| UI/readability risk | Several programmatic screens use small type and fixed dimensions around a portrait-oriented 360×720 viewport ([project.godot](project.godot), [ui/settings_menu.gd](ui/settings_menu.gd), [ui/launch_bay.gd](ui/launch_bay.gd), [ui/hangar_menu.gd](ui/hangar_menu.gd)) | Desktop/Deck readability and aspect-ratio behavior need explicit testing and responsive layout work. | **High** |
| Save migration and recovery risk | A version mismatch falls back rather than migrating; progress and machine-specific settings share `user://save_data.json` ([autoloads/save_manager.gd](autoloads/save_manager.gd)) | A major update must not wipe progression; Cloud should not roam inappropriate display preferences. | **High** |
| Steam product layer absent/unverified | No Steam integration or release configuration was found in the inspected project; the research snapshot predates the 0.5.0 identity/export metadata pass ([project.godot](project.godot), [export_presets.cfg](export_presets.cfg)) | Achievements, Cloud, store identity, Deck verification, and release operations remain work, not polish. | **High** |
| Full-run validation unfinished | The design backlog explicitly calls out a full-run smoke test ([GAME_DESIGN.md](GAME_DESIGN.md)) | Endless scaling defects and save/progression failures often appear beyond a short CI boot test. | **High** |

## 2. What a premium single-purchase game must promise

### 2.1 The premium value contract

A single-purchase game asks the player to believe that the product has enough authored value now, not after recurring purchases. Steam's Early Access rules are useful even if Farinuff Flight does not use Early Access: Valve says an Early Access build must already be playable and worth its current price, must stand on its own, and must not use future promises as a substitute for current value; a 1.0 release is generally expected to be stable and complete ([Steam Early Access rules](https://partner.steamgames.com/doc/store/earlyaccess)).

For Farinuff Flight, “complete” should mean:

1. A new player can learn the unique movement/combat language without outside help.
2. A standard run has a clear goal, escalation, climax, ending, and result screen.
3. Failure feels attributable and immediately invites another attempt.
4. Builds meaningfully change play, rather than only raising numbers.
5. Permanent progression opens possibility and softens learning without making early runs intentionally joyless.
6. The game is stable, readable, controllable, save-safe, and honest about its content.
7. Endless play, challenges, ships, achievements, and score mastery extend the completed game rather than substitute for an ending.

This does not require hundreds of upgrades. Nova Drift advertises over 200 modular upgrades and Soulstone Survivors advertises over 350 skills, but those larger official counts reflect those products' identities and production histories ([Nova Drift official store page](https://store.steampowered.com/app/858210/Nova_Drift/), [Soulstone Survivors official store page](https://store.steampowered.com/app/2066020/Soulstone_Survivors/Official)). Farinuff Flight can compete through coherence, tactile control, strong transformations, and replayable challenge at a smaller scope.

### 2.2 Ethical meta-progression

The current game uses earned salvage rather than real-money purchases, banks boss rewards immediately, provides milestone bonuses, and supports permanent upgrades, blueprints, consumables, ships, and modifiers ([GAME_DESIGN.md](GAME_DESIGN.md)). That is a healthy starting point for a premium game.

The design risk is that permanent lives, speed, fire rate, and retries can make the unupgraded game feel like a deliberately weakened version. Current maximum permanent stat effects include additional lives/retries and speed/fire-rate gains ([autoloads/game_manager.gd](autoloads/game_manager.gd)). The best premium progression model for this game should follow these principles:

- **Baseline competence:** the starting ship must already feel responsive, lethal, and capable of a first clear in skilled hands.
- **Horizontal-first late progression:** after a short comfort ramp, emphasize new ships, blueprints, upgrade interactions, challenges, visual rewards, and mastery goals.
- **No paid power or mandatory consumables:** every gameplay-affecting item is earned by playing; consumables are optional accelerators or experiments, not an expected tax on each attempt.
- **Transparent economy:** show what salvage does, what unlock is next, whether an item is permanent or run-only, and expected milestone paths.
- **Free respec/refund:** allow players to undo permanent-stat purchases without grind. Vampire Survivors' official page explicitly says power-ups can be refunded for free, a relevant precedent for experimentation without punishment ([Vampire Survivors official store page](https://store.steampowered.com/app/1794680/Vampire_Survivors/?curator_clanid=45564888)).
- **Difficulty integrity:** assist options can reduce barriers without affecting standard-mode achievements or challenge standings if competitive meaning is important. Accessibility should not be treated as cheating.

**Recommendation — High confidence:** add a free permanent-upgrade refund/respec; cap vertical power early; make later unlocks primarily horizontal. Whether current permanent bonuses are too strong is a **playtest unknown**, not something the repository alone can establish.

## 3. Official comparison set

The comparison uses seven premium games whose official pages expose different solutions to the same product questions. “Observed facts” are claims on official Steam/developer pages. “Implication” is analysis for Farinuff Flight, not a claim by the cited developer.

| Game | Observed premium/product facts | Observable design structure | Inference for Farinuff Flight |
|---|---|---|---|
| **Vampire Survivors** | Official base price observed at **US$4.99**; supports achievements and Steam Cloud; its page describes mouse, keyboard, controller, and touch support and free power-up refunds ([official store page](https://store.steampowered.com/app/1794680/Vampire_Survivors/?curator_clanid=45564888)). | Minimal-input time survival; collect gold, buy persistent upgrades, choose characters, and combine run upgrades. The store page now presents a broad, update-expanded package. | The low entry price is paired with extreme simplicity and accumulated breadth. Farinuff should not imitate passivity; it should make active control visibly worth the attention cost. Free respec is directly reusable. |
| **Brotato** | Official base price observed at **US$4.99**; achievements, Cloud, Workshop, and local cooperative play are listed ([official store page](https://store.steampowered.com/app/1942280/Brotato/)). | Runs are described as under 30 minutes, with 20–90 second waves, shopping between waves, dozens of characters, hundreds of items/weapons, six held weapons, auto-fire by default, and manual aim as an option. Enemy health, damage, and speed sliders are advertised. | Short, explicit wave units make pacing and decision frequency legible. Farinuff can keep action uninterrupted but should benchmark how often the player receives a meaningful build choice and offer granular challenge assists. |
| **Halls of Torment** | Official base price observed at **US$6.66**; achievements and Cloud are listed ([official store page](https://store.steampowered.com/app/2218750/Halls_of_Torment/)). | The page promises 30-minute runs, six stages, 11 characters, large trait/ability/item pools, quests, bosses, extracted items, and both a defined Lord objective and continuing high-end challenge. | The useful pattern is a bounded run and explicit content promise backed by a long mastery tail. Farinuff needs a smaller but equally clear statement of stages/bosses/ships/build paths at launch. |
| **20 Minutes Till Dawn** | Official base price observed at **US$4.99**; achievements and Cloud are listed ([official store page](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/)). | The title and page state a 20-minute survival target, directional aiming and active firing, 50+ upgrades, characters/weapons, boss rewards, and persistent runes purchased with earned souls. | This is the closest control-model benchmark: active aim needs a crisp, time-bounded promise. Current mixed recent versus very-positive lifetime review labels are observable, but official sources do not establish their cause. |
| **Deep Rock Galactic: Survivor** | Official base price observed at **US$12.99**; achievements and Cloud are listed ([official store page](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/)). | Auto-shooting is combined with mining, terrain carving, objectives, procedural caves, upgrades, and extraction. | A higher-priced survivor game can justify attention through a second systemic verb and recognizable world. Farinuff's equivalent second verb is movement-as-defense/offense; boost reflection must affect routes, builds, and bosses—not just feel good. |
| **Nova Drift** | Official base price observed at **US$17.99**; a demo, achievements, Cloud, and leaderboards are listed ([official store page](https://store.steampowered.com/app/858210/Nova_Drift/)). | Quick arcade runs, active shooting/movement, body/weapon/shield gear, 200+ modular upgrades, and “super mod” combinations. The developer says 1.0 added a final boss and ending, made Endless unlock after a first win, and added assist/high-visibility options ([developer retrospective](https://store.steampowered.com/news/posts/?appgroupname=Nova+Drift&appids=858210&enddate=1744121944&feed=steam_community_announcements)). | This is the strongest structural precedent. Use a finite ending plus Endless, build upgrade families and visible synergies, and avoid a flat pool that overwhelms players or makes desired combinations mostly chance. |
| **Soulstone Survivors** | Official base price observed at **US$14.99**; a demo, achievements, stats, and Cloud are listed. Its official page advertises 350+ skills, 100+ craftable weapons, many characters, curses, modes, and bosses ([official store page](https://store.steampowered.com/app/2066020/Soulstone_Survivors/Official)). | Large-scale build crafting, persistent skill tree, crafted starting gear, escalating curses, multiple maps/modes, and boss progression. | Its price is supported by conspicuous breadth. Farinuff should not price-match this tier until its official content promise and presentation support the comparison. A tighter game should sell precision and identity, not raw counts. |

### Comparison conclusions

1. **Bounded runs are easy to explain.** Official pages in the set explicitly use 20 minutes, 30 minutes, or “under 30 minutes.” Farinuff's session length is currently unverified. A 20–30 minute first-clear target is therefore a reasonable prototype range, not proof of an optimal duration.
2. **A clear end and an endless tail coexist.** Halls of Torment and Nova Drift demonstrate finite objectives alongside deeper replayability. The Nova Drift retrospective is unusually direct evidence that finishing the arc mattered to 1.0.
3. **Content counts support, but do not create, value.** The higher-priced comparison pages make their breadth conspicuous. Farinuff's defensible alternative is a smaller set of strongly interacting systems and polished tactile play.
4. **Active control is a position, not a burden to hide.** 20 Minutes Till Dawn and Nova Drift explicitly sell aiming/shooting/build crafting. Farinuff should make its extra input produce visible agency unavailable in auto-shooters.
5. **Accessibility can be part of the store promise.** Brotato advertises enemy health/damage/speed controls, while Nova Drift's developer highlights Assist Mode and High Visibility in 1.0. Farinuff should disclose its assists and presentation toggles before purchase.

## 4. Recommended game design for the compilation release

### 4.1 A complete run architecture

**High-confidence recommendation:** introduce a standard finite route with an ending, then retain Endless.

A testable first version:

| Segment | Intended job | Candidate content |
|---|---|---|
| Opening | Teach movement and establish confidence | Contextual move/aim/fire/boost prompts; forgiving first enemy set; first temporary power. |
| First exam | Confirm the boost/reflection language | Wave 5 boss designed around one clearly reflectable pattern; first stat allocation. |
| Build commitment | Turn pickups into a plan | First major upgrade choice no later than roughly one-third of the target run; show upgrade family and possible synergy. |
| Mid-run twist | Demand adaptation | New enemy generation, one authored hazard or movement constraint, second boss pattern. |
| Build payoff | Let the player feel transformed | Upgrade fusion/super-state or a strong branch capstone; denser but readable combat. |
| Finale | Test the whole learned language | Final boss with movement, reflect, target-priority, and build-damage checks; no arbitrary one-shot surprise. |
| Resolution | Make completion legible | Ending beat, run summary, unlock reveal, salvage/accounting, Endless availability, next mastery goal. |

The exact wave count must follow measured time. “Wave 30 final boss” is a plausible implementation because the existing cadence puts bosses every five waves and elite choices every ten, but it is only good if median successful runs land in the target duration and expose enough build decisions. Do not preserve wave numbers at the expense of pacing.

**Unknowns to measure:** median first-run duration; time to first boss; first-clear attempt count; quit points; proportion of runs reaching each build decision; boss time-to-kill by ship/build; and whether the final run phase is readable at minimum and maximum effects settings.

### 4.2 Core-loop clarity and onboarding

The current game asks players to understand conventional shooting plus uncommon boost behavior. A first-run tutorial should be contextual and playable, not a text wall:

1. Move and aim at a safe target.
2. Fire and collect one orb.
3. Boost through a telegraphed lane.
4. Reflect one slow, unmistakable projectile into an enemy.
5. Chain a second boost and show the resource/recharge response.
6. Explain lives, temporary powers, and the next boss marker only when relevant.

The first reflection should create an exaggerated but accessibility-safe confirmation: shape/color change, distinctive sound, impact response, and a short label such as “REFLECT.” All instructions must remain available in a controls/help page. Use controller-aware glyphs and swap them immediately when input changes; Steam Input's guidance recommends separate menu action sets, dynamic prompts, and allowing mixed input rather than locking one device family ([Steam Input documentation](https://partner.steamgames.com/doc/features/steam_controller), [Steam Input developer guide](https://partner.steamgames.com/doc/features/steam_controller/getting_started_for_devs)).

**Success gates — High confidence:** at least 90% of fresh external testers can explain boost, reflection, run upgrades, and salvage after one run without developer help; at least 80% intentionally reflect a projectile during onboarding; no critical action depends on reading a paragraph during combat. The percentages are proposed internal gates, not external benchmarks.

### 4.3 Build variety and replayability

Nova Drift's developer describes an instructive progression: a large flat pool created an information dump and made desired builds too dependent on chance; mini-trees and combination-based super mods created a middle ground between determinism and randomness ([Nova Drift developer retrospective](https://store.steampowered.com/news/posts/?appgroupname=Nova+Drift&appids=858210&enddate=1744121944&feed=steam_community_announcements)). Farinuff currently has ten base elite upgrades, three blueprint additions, stat allocation, temporary powers, ships, and modifiers, but major elite choice arrives only every ten waves ([GAME_DESIGN.md](GAME_DESIGN.md)).

Recommended structure:

- Group elite upgrades into visible families such as **Wing**, **Sting**, **Drift**, and **Cocoon**—names should match final fiction. A first pick reveals a small branch rather than adding the whole pool to later rolls.
- Give each family a mechanical thesis: projectile offense, reflection conversion, movement/boost chaining, and survivability/control.
- Create a small number of cross-family capstones. Example hypothesis: reflected shots mark targets; boosting through a marked target detonates the mark. This reinforces the marketable core rather than adding an unrelated subsystem.
- Show future compatibility in concise language: “Pairs with Drift upgrades” or a simple synergy icon. Avoid requiring an external wiki to understand basic combinations.
- Offer one reroll or branch lock earned through play, not through premium currency. Randomness should redirect a plan, not routinely erase it.
- Ensure ships change decisions, not just starting stats. Interceptor and Bulwark currently alter speed/fire/lives ([GAME_DESIGN.md](GAME_DESIGN.md)); each should also alter a rule or upgrade preference that is visible in the first minute.
- Keep challenge modifiers as opt-in mastery and score tools. Add them after the player understands the baseline unless external tests show that early visibility motivates rather than confuses.

**Medium-confidence hypothesis:** expose a meaningful build decision more often than every ten current waves. Test a cadence of one substantial choice every 3–5 minutes, with smaller stat/pickup decisions between. The correct cadence depends on actual wave time and cognitive load.

### 4.4 Challenge, fairness, and failure

The existing spawn-distance checks, telegraphs, enemy generations, threat limits, and late scaling are valuable ([CHANGELOG.md](CHANGELOG.md), [systems/enemy_spawner.gd](systems/enemy_spawner.gd)). Preserve them as design invariants.

For release:

- Every damaging event needs clear ownership, travel/read time appropriate to its threat, and a distinguishable shape or motion—not color alone.
- New rules should appear in isolation before combinations. A generation change should not introduce an unfamiliar enemy, denser projectile pattern, and arena constraint simultaneously.
- A death summary should identify the final damage source, wave, build, elapsed time, and one actionable learning clue. Do not falsely imply a single cause when attrition was the issue.
- Bosses should test learned verbs. At least one phase should reward reflection, but no valid build should become impossible because it did not specialize in reflection damage.
- Standard mode should be beatable with an unupgraded account by skilled players. Meta progression may improve consistency, not serve as a hidden mandatory level gate.
- Assist settings should include enemy damage, enemy speed, and possibly projectile density or game-speed controls. Xbox's accessibility guidance recommends difficulty options that enable more players to enjoy and complete a game, recognizing that difficulty barriers differ by player ([Xbox Accessibility Guideline 108](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/108)).

The current try-again prompt has a time-limited decision path. Timed UI should be extendable or disableable; Microsoft's guidance calls for adequate time to read and interact with timed content ([Xbox Accessibility Guideline 116](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116)).

### 4.5 Feedback and “juice” without visual overload

Screen shake, hit stop, CRT effects, distortion, flashing reduction, and audio infrastructure already exist or are recorded in the project ([CHANGELOG.md](CHANGELOG.md), [autoloads/save_manager.gd](autoloads/save_manager.gd)). The design backlog correctly identifies distinct hit, death, reward, and boss cues as incomplete ([GAME_DESIGN.md](GAME_DESIGN.md)).

Prioritize information-bearing feedback:

1. Player damage and life loss.
2. Successful reflection and reflected-hit impact.
3. Boost ready, boost chain, and failed boost attempt.
4. Boss telegraph, phase change, vulnerability, and defeat.
5. Upgrade acquired and build transformation.
6. Salvage banked and milestone unlocked.

Give each event a consistent visual, audio, and motion signature. Then apply an intensity budget so common hits cannot drown out boss or player-danger cues. Retain independent screen-shake, flashing, CRT, and distortion controls. Microsoft's motion/distraction guidance recommends allowing players to stop or customize moving, blinking, scrolling, and auto-updating presentation ([Xbox Accessibility Guideline 117](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117)).

### 4.6 Accessibility and input baseline

The following are release requirements, not optional stretch polish:

| Requirement | Current status | Release action and evidence |
|---|---|---|
| Full remapping | Missing/backlogged | Remap gameplay and menu actions, including analog/digital alternatives and axis inversion. Microsoft's input guidance calls for remapping all controls and treating broader access needs beyond simple button swaps ([XAG 107](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107)). |
| Independent audio controls | Partial | Keep master/music and add gameplay SFX, UI, and any voice/narration categories used. XAG 105 recommends independent control for materially different audio categories ([XAG 105](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/105)). |
| Text size/readability | At risk | Replace fixed small labels with responsive styles and a text-scale option; test at target display sizes. XAG 101 calls for readable defaults and configurable text presentation ([XAG 101](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101)). |
| Contrast/non-color cues | Unverified | Test UI, projectiles, rarity, damage, and telegraphs; pair color with shape, animation, or label. XAG 102 covers sufficient contrast and configurability ([XAG 102](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102)). |
| Effects reduction | Partial/strong start | Keep reduced flashing, shake, CRT, and distortion choices; add a single low-intensity preset and verify all bosses. |
| Timed interactions | At risk | Let players disable or extend the try-again timer; never auto-spend a resource. |
| Difficulty assists | Missing/unverified | Add granular enemy damage/speed and consider projectile-density or game-speed controls; explain achievement/score behavior clearly. |
| Feature disclosure | Missing | List accessibility features and limitations on the store page and in a public support note. XAG 121 recommends pre-purchase accessibility documentation ([XAG 121](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/121)). |

### 4.7 Controller and Steam Deck readiness

Steam Deck Verified expectations include accessing all content with default controller configuration, showing correct controller glyphs, avoiding keyboard/mouse prompts during controller play, running at a playable frame rate with appropriate resolution behavior, and presenting legible text. Valve identifies 1280×800 as a preferred Deck target and specifies 30 FPS at 800p as a compatibility threshold; its published text guidance sets a minimum and recommends larger/configurable text ([Steam Deck compatibility documentation](https://partner.steamgames.com/doc/steamhardware/compat)).

Farinuff Flight has gameplay actions for controller, but full readiness requires:

- Controller-only navigation through title, settings, hangar, launch bay, gameplay, pause, upgrade selection, results, credits, and exit confirmation.
- Dynamic Xbox/PlayStation/Nintendo/Steam Deck glyph support through the chosen input layer.
- Responsive layout tests at 1280×800, 1280×720, 1920×1080, ultrawide, and the current portrait/internal viewport behavior.
- Readability tests at handheld distance. Existing small fixed font sizes should be treated as failures until verified, not assumed acceptable.
- A 30-FPS minimum stress test and a 60-FPS quality target during peak waves, boss patterns, pickups, and effects on representative low-power hardware.
- No launcher, keyboard-only name entry, or manual configuration requirement.
- Suspend/resume, disconnect/reconnect, and controller-order tests.

**High confidence:** Deck work should be part of UI architecture now. Retrofitting responsive layout and prompt systems after store assets and localization are complete is costlier and riskier.

### 4.8 Performance, stability, and saves

Object pooling and automated smoke checks are good foundations ([CHANGELOG.md](CHANGELOG.md)), but the release gate must include long-session behavior:

- Automated deterministic runs through the finite ending with multiple seeds/ships/builds.
- Manual and instrumented soak runs beyond intended Endless milestones.
- Frame-time, object-count, allocation, and audio-voice budgets under worst-case effects.
- Pause/resume, focus loss, display-mode change, controller reconnect, and quit-during-save tests.
- Crash-free startup and clean shutdown across supported Windows configurations; add other platforms only when fully tested.

The save system currently stores progress and presentation settings together in `user://save_data.json`, validates types, and falls back when data is malformed or the schema version differs ([autoloads/save_manager.gd](autoloads/save_manager.gd)). For a major progression update:

1. Add explicit migrations from every shipped schema; never treat a normal old version as corruption.
2. Write atomically through a temporary file, validate it, replace the live file, and retain a rolling backup.
3. Add a recovery path that preserves as much valid progression as possible and tells the player what happened.
4. Separate roaming progression/profile data from machine-specific display settings, or exclude machine-specific fields from Cloud sync. Steam warns against roaming machine-specific configuration and supports Auto-Cloud path mapping without custom integration code ([Steam Cloud documentation](https://partner.steamgames.com/doc/features/cloud)).
5. Test offline play, two-device conflict behavior, demo-to-full migration, and downgrade handling.

**High-confidence release blocker:** no compilation update should ship until existing save data migrates successfully in automated fixtures and manual upgrade tests.

## 5. Packaging and positioning

### 5.1 Positioning statement

Recommended working statement:

> **Farinuff Flight is a fast, active-aim space roguelite where a butterfly starfighter turns enemy fire into momentum. Drift through swarms, reflect volleys, chain boosts, and assemble a build strong enough to break the final formation—or push beyond it in Endless.**

This is intentionally specific about player verbs and the finite/endless structure. It avoids claiming content scale that is not yet present.

Potential short-description draft for testing:

> Drift, boost, and reflect enemy fire in a precision space roguelite. Build a butterfly starfighter across a complete arcade run, defeat the final boss, then chase riskier ships, modifiers, and Endless scores.

Steam says the short description should be concise, while store descriptions must follow its content and formatting rules ([Steam store-description documentation](https://partner.steamgames.com/doc/store/page/description)). Final copy should be revised after the run structure and exact feature set are locked.

### 5.2 Product identity cleanup

- Change the player-facing project name from the generic `Space Shooter` to the final title before builds, crash logs, screenshots, and Steam integration are locked ([project.godot](project.godot)). This audit recommendation is now satisfied by the 0.5.0 Farinuff Flight identity pass; store and platform identity still need final lock.
- Create a one-sentence genre label used consistently in the executable, store page, press kit, trailer, and community posts.
- Establish a visual key: butterfly silhouette, luminous wing trails, and a visibly reflected enemy volley. A static ship over a generic starfield will not explain the mechanic.
- Use content counts only when they are stable and impressive enough to be maintained. Prefer “four build families with transformative combinations” over a padded count of minor stat nodes.
- Do not call the game “relaxing” or “casual” if active aiming and high-density projectile reading are essential. Promise the actual attention level.

### 5.3 Price hypothesis

The official comparison pages span observed base prices from US$4.99 to US$17.99, but they do not establish an optimal Farinuff Flight price. The higher-priced pages also advertise substantially larger content surfaces, established intellectual property, or both. Price therefore remains a **market-test unknown**.

**Medium/low-confidence test range:** after adding a finite campaign, polished onboarding, stronger build structure, save/Steam features, and a high-quality demo, test **US$7.99 versus US$9.99** as working anchors. This is not a recommendation to publish either price now. Test perceived value with fresh target players shown the real trailer, store page, demo, and launch content list. If the game remains endless-only with its current content presentation, even that range may overstate the completion promise; if the compilation release adds substantial bosses, environments, build families, and polish, it may understate it.

Never use a future roadmap to rationalize a price the current build does not support. Steam's Early Access guidance explicitly says the current build should be worth the current price and stand on its own ([Steam Early Access rules](https://partner.steamgames.com/doc/store/earlyaccess)).

## 6. Steam discovery and store readiness

### 6.1 Store assets that explain the game

Current required Steam store assets include Header, Small, Main, and Vertical capsules, plus library assets; Valve publishes the exact current dimensions in its asset documentation ([Steam graphical asset overview](https://partner.steamgames.com/doc/store/assets)). Capsule base art is restricted to the game's artwork, name, and any official subtitle, and the logo must remain readable; noncompliant assets can lose visibility or official-sale eligibility ([Steam graphical asset rules](https://partner.steamgames.com/doc/store/assets/rules)).

Current production targets from that documentation are:

| Asset | Pixels |
|---|---:|
| Header capsule | 920×430 |
| Small capsule | 462×174 |
| Main capsule | 1232×706 |
| Vertical capsule | 748×896 |
| Library capsule | 600×900 |
| Library hero | 3840×1240 |
| Gameplay screenshots | At least 1920×1080, 16:9 |

Reconfirm dimensions in Steamworks immediately before final export because platform specifications can change.

Recommended creative brief:

- **Capsule:** one unmistakable butterfly craft banking through a reflected fan of projectiles; high-contrast title; no review scores, discount copy, awards, or feature list in base art.
- **First trailer:** within the first three seconds, show boost → reflect → chain → enemy detonation. Within ten seconds, show a build choice changing that interaction. Keep the real HUD visible. Steam warns that viewers may leave in under ten seconds and may watch muted; the first trailer should primarily show gameplay ([Steam trailer guidance](https://partner.steampowered.com/doc/store/trailer)).
- **Screenshots:** at least five real gameplay screenshots, with representative UI and different readable situations. Steam recommends actual gameplay rather than concept art, pre-rendered cinematics, or marketing copy and asks for a minimum of five ([Steam standard asset guidance](https://partner.steampowered.com/doc/store/assets/standard)).
- **Screenshot sequence:** core boost/reflection; build-choice screen; transformed build; boss readability; launch bay/meta choice; optional Endless challenge.
- **GIFs/description:** short loops showing the same input becoming more expressive under different builds. Keep text factual and localized.

### 6.2 Tags and category language

Steam recommends at least five tags and up to 20; the top 20 inform similar-game and recommendation relationships ([Steam tags documentation](https://partner.steampowered.com/doc/store/tags)). Use only tags the shipped experience earns.

Candidate ordered set for validation:

1. Action Roguelike
2. Shoot 'Em Up
3. Roguelite
4. Bullet Hell
5. Twin Stick Shooter
6. Arcade
7. Space
8. Difficult
9. Score Attack
10. Controller
11. 2D
12. Singleplayer

“Survivor-like” or “Bullet Heaven” should be included only if current Steam tag availability and target-player testing show the game's enemy-density/build cadence meets that expectation. Because active aiming and held fire are central, over-indexing on automatic survivor tags could attract the wrong expectations and produce avoidable review friction.

### 6.3 Demo strategy

Steam describes a demo as a small playable portion that demonstrates core mechanics, helps the purchase decision, and leaves the player excited for more; Valve advises balancing enough content to be compelling against giving away too much ([Steam demo documentation](https://partner.steampowered.com/doc/store/application/demos)). A demo can share Cloud data with the full game, link directly to the full product, and has a one-time release-notification option for base-game wishlisters.

Recommended demo hypothesis:

- Include onboarding, one complete early build transformation, the first major boss, one ship, a curated subset of upgrades, and a result/teaser screen.
- Target 12–20 minutes for a successful first completion, but let failed attempts restart instantly.
- Do not require meta grind to reach the best demonstration of boost/reflection.
- Isolate demo saves unless migration is deliberately designed and tested. If progress transfers, state exactly what transfers.
- End after a satisfying climax, then show what the full game adds: complete route/final boss, all ships, build families, challenges, progression, achievements, and Endless.
- Add an in-demo full-game link and wishlist/purchase call to action through Steam's supported flow.

Steam Next Fest participation is available only once per title and requires an eligible public store page and playable demo; Valve frames it as an audience- and feedback-building opportunity and leaves demo length to the developer ([Steam Next Fest documentation](https://partner.steampowered.com/doc/marketing/upcoming_events/nextfest)). The October 19–26, 2026 event exists on the current official schedule ([October 2026 Next Fest page](https://partner.steampowered.com/doc/marketing/upcoming_events/nextfest/2026october)).

**Decision:** enter October 2026 only if registration eligibility is already satisfied and the demo passes external onboarding, stability, controller, and performance gates well before submission. Otherwise use a later eligible event. A weak demo consumes the one-title opportunity and teaches the wrong audience expectation.

### 6.4 Coming Soon, wishlists, and release timing

Steam requires a public Coming Soon page for at least two weeks before release. Store and build reviews commonly take 3–5 business days, and Valve advises submitting at least seven business days ahead ([Steam release process](https://partner.steampowered.com/doc/store/releasing), [Steam release types](https://partner.steampowered.com/doc/store/types)). For this project, two weeks should be treated as a legal minimum, not a marketing plan.

Steam says wishlists primarily matter because wishlisters receive launch and qualifying-discount notifications; wishlists are generally not a direct algorithmic visibility factor. Purchases, play, language support, and tags contribute to visibility, while raw page traffic and conversion are not direct visibility factors; review-score visibility impact is mainly severe at very low scores ([Steam visibility documentation](https://partner.steampowered.com/doc/marketing/visibility)).

Recommended sequence:

1. Lock title, hook, visual identity, standard-run structure, and supported platforms.
2. Publish Coming Soon when trailer/capsules/screenshots truthfully represent near-final play—not merely as early as technically possible.
3. Run private fresh-player tests and a controlled public demo release.
4. Participate in one Next Fest when the demo is at its strongest.
5. Use Steam announcements for meaningful development milestones, not repetitive calls to wishlist. Steam provides announcements, events, festivals, discounts, and update-visibility tools ([Steam marketing tools](https://partner.steampowered.com/doc/marketing/tools)).
6. Set the launch date only after save migration, full-run, Deck/controller, and store/build review buffers are green.
7. Reserve the first major post-launch update-visibility round for a substantial player-facing update, not emergency completion work.

### 6.5 Reviews and community

Steam's review documentation describes reviews as feedback on whether a game meets player expectations. Developers may respond officially but may not solicit reviews inside the game or exchange rewards for them; Valve advises against arguing or responding to every review ([Steam user-review documentation](https://partner.steampowered.com/doc/store/reviews)).

Operational recommendations:

- Make the store promise conservative and concrete so negative sentiment is not caused by expectation mismatch.
- Provide a visible bug-report path, accessibility contact, known-issues note, and save-recovery instructions.
- Triage reviews by recurring topic: crashes/save loss, control/readability, unclear mechanics, fairness, content/value, and feature expectation.
- Respond publicly when a factual clarification, workaround, or shipped fix helps many readers. Do not debate taste.
- Convert common confusion into onboarding/store copy changes. Convert repeated technical reports into tracked release blockers.
- Never gate rewards on reviews or show an in-game “please review” prompt.

### 6.6 Achievements, Cloud, localization, and optional features

**Achievements.** Steam achievements and stats persist and roam, can provide additional objectives, and are localizable. Valve initially limits many new applications to 100 achievements until profile-feature eligibility is reached ([Steam achievements documentation](https://partner.steampowered.com/doc/features/achievements)). Ship a concise launch set, approximately 25–40, covering onboarding, first clear, ship identities, build synergies, bosses, modifiers, and mastery. Avoid achievements that reward unattended grind, inaccessible color-only challenges, or unstable extreme Endless thresholds.

**Steam Cloud.** Configure and test Auto-Cloud for progression, with platform-appropriate root/path handling, and do not roam machine-specific display settings ([Steam Cloud documentation](https://partner.steampowered.com/doc/features/cloud)). Cloud is a release requirement for a progression-heavy premium game unless a documented technical blocker exists.

**Localization.** Steam supports 29 languages and says more than 60% of Steam users use a language other than English. Store-page and in-game localization are separate, and Valve recommends using regional wishlist data to prioritize; in-game language support also affects visibility ([Steam localization documentation](https://partner.steampowered.com/doc/store/localization)). Externalize every string, avoid text baked into art, support expansion, and separate nouns from sentence fragments now. Start with high-quality English and prioritize later languages using wishlist geography and demo demand; do not machine-publish unsupported translations as finished localization.

**Leaderboards.** They fit score attack, but are optional for the compilation release. Add them only after score rules, modifier multipliers, versioning, offline submission behavior, and obvious tamper cases are designed. A local/personal-best board is enough for launch if online integrity would delay higher-value work.

## 7. Prioritized compilation roadmap

### Gate 0 — Define the sellable game

**Must complete before more breadth is added:**

- Final title and one-sentence promise.
- Standard finite run, final boss, ending, and relationship to Endless.
- Target session-time range and build-decision cadence, validated with instrumentation.
- Four or fewer coherent upgrade families with an explicit interaction map.
- Launch content promise: ships, bosses, environments/wave phases, build families, modifiers, achievements, and modes.

### Gate 1 — Make the first hour excellent

- Contextual onboarding and replayable controls/help.
- First boss teaches reflection and provides a satisfying victory beat.
- First meaningful build transformation appears in the first run.
- Clear distinction between temporary power, run upgrade, and permanent unlock.
- Instant restart, useful result screen, and transparent salvage/progression.
- External tests with players unfamiliar with the project.

### Gate 2 — Premium trust and accessibility

- Full input remapping and dynamic prompts.
- Responsive UI and text scaling; contrast and non-color cue audit.
- Independent audio controls; reduced-intensity preset; timed-prompt settings.
- Granular assists and clear score/achievement behavior.
- Save migration, atomic writes, backups, recovery, and Cloud separation.
- Controller-only and Steam Deck test matrix.

### Gate 3 — Content, balance, and production validation

- At least three distinct viable build identities per ship in external tests; overlap is acceptable, identical optimal paths are not.
- Every boss tested against low-power, defensive, movement, reflection, and generalist builds.
- Full-run automation and manual stress/soak tests.
- Performance budgets met at peak density with all effects and reduced effects.
- Achievement and localization-ready string implementation.
- Credits, legal notices, privacy/telemetry disclosure if telemetry is shipped, and support documentation.

### Gate 4 — Store and demo

- Compliant capsule family and library art.
- Gameplay-first trailer and at least five representative gameplay screenshots.
- Validated tags and concise feature copy.
- Demo passes fresh-player, controller, save, performance, and purchase-intent tests.
- Coming Soon page, wishlists/followers, announcements, and appropriate Next Fest timing.
- Store/build review submissions buffered beyond Steam's minimum processing advice.

### Post-launch candidates

- Additional ship with a rule-changing mechanic.
- New upgrade branch and cross-family combination.
- Boss/environment variant.
- Online leaderboards after score integrity work.
- Additional localizations selected from real demand.
- A substantial free update using Steam's update visibility, only after launch stability.

## 8. Validation plan and decision thresholds

### 8.1 Playtest cohorts

Use at least three distinct cohorts:

- **Genre-aware:** players of survivor-likes/action roguelites who can assess build cadence and value.
- **Arcade/twin-stick aware:** players who understand active aim and movement mastery but may not expect meta progression.
- **Fresh/casual:** players who reveal onboarding, readability, and difficulty barriers.

Developers and existing followers should not be the only testers; familiarity hides the highest-risk communication failures.

### 8.2 Instrumentation questions

Collect only data needed to answer decisions, disclose it, and avoid personally identifying collection unless necessary. Useful events:

- First-run tutorial step completion and skip.
- Time to first reflection, first damage, first boss, first death, and first build choice.
- Run duration, wave reached, ship/modifiers, offered/chosen upgrades, damage source, and quit/restart.
- Salvage earned/spent, first purchases, respec use, and time to first horizontal unlock.
- Frame-time percentiles and peak entity/effect counts by wave.
- Save/load/migration result and crash-free session.
- Demo completion, return sessions, store-link use, and wishlist/purchase behavior available through approved platform analytics.

### 8.3 Unknowns that cannot be resolved by research

| Question | Test | Decision signal | Confidence before test |
|---|---|---|---|
| Is 20–30 minutes the right standard-run length? | Compare two internally complete pacing builds with fresh players. | Completion intent, fatigue, perceived value, retry desire, and final-phase readability. | **Medium** |
| How many major upgrade choices are enough? | Test current cadence against a 3–5 minute cadence. | Ability to describe a build, meaningful choice rate, choice time, and run-to-run differentiation. | **Medium** |
| Is permanent power undermining fairness? | Blind-test fresh accounts, partially upgraded accounts, and respec availability. | Skilled first-clear viability, perceived grind, and whether purchases feel mandatory. | **Medium–High risk** |
| Which store framing converts the right audience? | Test active-aim/reflect framing against broader survivor framing using the same polished footage. | Qualified demo starts, wishlists, completion, and expectation-match interviews—not clicks alone. | **Medium** |
| What price supports the actual package? | Show finalized assets/content list and demo, then test willingness and compare conversion after launch-date disclosure. | Perceived value and purchase intent across candidate prices; do not infer from competitor prices alone. | **Low** |
| Are three ships meaningfully different? | Track upgrade choices, movement behavior, and qualitative descriptions by ship. | Different successful decisions and player language, not only win-rate variation. | **Medium** |
| Is the game Deck-ready? | Full controller-only playthrough and stress test on Deck-class hardware. | All content accessible, legible UI, correct prompts, stable frame time, suspend/resume and Cloud success. | **High that work is needed** |
| Does the demo sell the full game? | Observe unprompted demo sessions and follow-up interviews. | Players can state the hook, want another build/run, understand full-game additions, and do not feel the demo is either trivial or exhaustive. | **Medium** |

Internal targets should be set before each test to prevent post-hoc rationalization. The suggested percentages and timing ranges in this report are product gates to test, not published genre benchmarks.

## 9. Recommended scope statement for the next compilation release

The release should be described internally as:

> Turn the current endless arcade foundation into a complete premium action roguelite: a taught and finishable standard run, transformative build families centered on boost/reflection, fair horizontal progression, release-grade accessibility/controller/saves, and a Steam-ready demo/store package. Endless, ships, modifiers, achievements, and score mastery become the post-clear value tail.

The release is **not** complete merely when every existing backlog item is checked. It is complete when an unfamiliar target player can discover the hook, finish a fair arc, understand why another run will differ, trust the save and controls, and accurately describe what they bought.

## 10. Source register

### Local product sources

- [README.md](README.md) — player-facing premise, controls, current feature summary, target/build notes.
- [GAME_DESIGN.md](GAME_DESIGN.md) — pillars, loop, enemies, waves, upgrades, progression, variants, modifiers, and backlog.
- [CHANGELOG.md](CHANGELOG.md) — implemented accessibility, input, performance, spawning, meta, UI, and testing changes.
- [project.godot](project.godot) — current project name, viewport/rendering, and configured input actions.
- [autoloads/game_manager.gd](autoloads/game_manager.gd) — run cadence, upgrades, stats, retries, and progression behavior.
- [autoloads/save_manager.gd](autoloads/save_manager.gd) — schema, validation, persistence location, and saved settings.
- [systems/enemy_spawner.gd](systems/enemy_spawner.gd) — spawn-safety and scaling behavior.
- [ui/settings_menu.gd](ui/settings_menu.gd), [ui/launch_bay.gd](ui/launch_bay.gd), and [ui/hangar_menu.gd](ui/hangar_menu.gd) — programmatic UI, available settings, and layout evidence.

### Steamworks and platform-holder guidance

- [Steam graphical asset overview](https://partner.steampowered.com/doc/store/assets) — current required asset types and dimensions.
- [Steam graphical asset rules](https://partner.steampowered.com/doc/store/assets/rules) — capsule content/compliance rules.
- [Steam standard graphical assets](https://partner.steampowered.com/doc/store/assets/standard) — gameplay screenshot and art guidance.
- [Steam trailer guidance](https://partner.steampowered.com/doc/store/trailer) — first-seconds, muted viewing, gameplay/HUD, and microtrailer implications.
- [Steam store description guidance](https://partner.steampowered.com/doc/store/page/description) — short/long description requirements.
- [Steam tags](https://partner.steampowered.com/doc/store/tags) — tag count and recommendation relationships.
- [Steam visibility](https://partner.steampowered.com/doc/marketing/visibility) — launch visibility, signals, wishlist notifications, and review-score behavior.
- [Steam marketing tools](https://partner.steampowered.com/doc/marketing/tools) — Coming Soon, announcements, festivals, discounts, and update visibility.
- [Steam release process](https://partner.steampowered.com/doc/store/releasing) and [release types](https://partner.steampowered.com/doc/store/types) — reviews, timing, and Coming Soon minimum.
- [Steam demos](https://partner.steampowered.com/doc/store/application/demos) — demo purpose, configuration, notifications, and full-game links.
- [Steam Next Fest](https://partner.steampowered.com/doc/marketing/upcoming_events/nextfest) and [October 2026 event](https://partner.steampowered.com/doc/marketing/upcoming_events/nextfest/2026october) — eligibility, one-event rule, purpose, and current event date.
- [Steam Early Access](https://partner.steampowered.com/doc/store/earlyaccess) — present-value, transparency, and completion expectations.
- [Steam user reviews](https://partner.steampowered.com/doc/store/reviews) — review conduct and developer responses.
- [Steam Cloud](https://partner.steampowered.com/doc/features/cloud) — Auto-Cloud, path handling, demo sharing, and machine-specific file cautions.
- [Steam achievements](https://partner.steampowered.com/doc/features/achievements) — persistence, localization, design, and initial application limits.
- [Steam localization](https://partner.steampowered.com/doc/store/localization) — supported languages, user-language share, visibility, and prioritization.
- [Steam Input](https://partner.steampowered.com/doc/features/steam_controller) and [developer guide](https://partner.steampowered.com/doc/features/steam_controller/getting_started_for_devs) — action sets, glyphs, and mixed input.
- [Steam Deck compatibility](https://partner.steampowered.com/doc/steamhardware/compat) — controller access, prompts, display, frame-rate, launcher, and readability criteria.
- [Xbox Accessibility Guidelines: text](https://learn.microsoft.com/gaming/accessibility/xbox-accessibility-guidelines/101), [contrast](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102), [audio](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/105), [input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107), [difficulty](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/108), [time limits](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116), [motion/distractions](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117), and [accessibility feature documentation](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/121).

### Official game and developer sources

- [Vampire Survivors official Steam page](https://store.steampowered.com/app/1794680/Vampire_Survivors/?curator_clanid=45564888).
- [Brotato official Steam page](https://store.steampowered.com/app/1942280/Brotato/).
- [Halls of Torment official Steam page](https://store.steampowered.com/app/2218750/Halls_of_Torment/).
- [20 Minutes Till Dawn official Steam page](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/).
- [Deep Rock Galactic: Survivor official Steam page](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/).
- [Nova Drift official Steam page](https://store.steampowered.com/app/858210/Nova_Drift/).
- [Nova Drift developer 1.0 retrospective and postmortem](https://store.steampowered.com/news/posts/?appgroupname=Nova+Drift&appids=858210&enddate=1744121944&feed=steam_community_announcements).
- [Soulstone Survivors official Steam page](https://store.steampowered.com/app/2066020/Soulstone_Survivors/Official).
