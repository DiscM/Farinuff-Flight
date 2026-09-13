## Addition — Expanded boss arenas and layered arena attacks

Boss encounters now use a fixed arena 2.2 times the ordinary width and height (4.84 times the area). The rendered camera follows the player with a soft dead zone and easing, clamped to the arena; the stable projection keeps movement speed, mouse aim, and arena bounds consistent. Normal framing returns after the encounter. Arena boundaries, a faint world grid, a small arena map, and an offscreen boss arrow support navigation.

Bosses reposition around the player between volleys and can attack from outside the camera view. Existing signature attacks overlap a separate, slower arena-pressure sequence:

- **Commander:** alternating lateral crosswinds with a broad open band, layered with lances and arena-edge charges.
- **Bulwark:** opposed gate rows with a marked corridor and delayed mines along its flanks.
- **Tempest:** staggered diagonal ribbons from two distant storm fronts, layered with its orbital storm.
- **Harbinger:** a three-sided closing projectile box with one open face, layered with player-position echoes.
- **Core:** alternating reactor cells release delayed projectile flowers, layered with its interruptible beam and stop-release volleys.

Arena warnings precede releases by at least 1.8 seconds. Cyan shots remain non-deflectable. Later phases add delayed position traps to Commander, Tempest, and Harbinger; mines can leave temporary plasma denial zones. New emitters skip releases within 110 baseline pixels of the player. Phase changes cancel pending arena attacks and hazards. Enemy shot lifetime and Core beam range support the expanded arena, and cached player/projectile/hazard/pickup bounds refresh when encounter size changes.

Implementation only; no automated checks or gameplay validation were run for this addition.

---

# Gameplay improvements implementation plan

Status: gameplay features implemented; verification and balance review remain in progress. The original proposal below is preserved as the design record.

## Mechanical differentiation correction — remove shared attack scaffolding

Player feedback found that different mechanics still looked too similar because most hulls added the same fans and rings. This correction removes the generic perimeter layer and shared pod support shots and replaces the remaining common patterns:

- Commander retains aimed accelerating lances between physical charges; it no longer adds an unrelated outer ring.
- Bulwark fires parallel projectile walls from spaced origins, with a three-slot doorway. Later phases alternate doorway position. Only the outer wall rails are cyan; siege-pod mines remain its secondary mechanic.
- Tempest deploys its persistent orbit without aimed fan follow-ups.
- Harbinger's marked echoes now launch returning shots: 0.8 seconds outward, 0.3 seconds suspended, then the same route inward. Cyan shots keep their straight flight. Reflected shots cancel the return behavior.
- Core replaces its rings/crescents with paired cardinal pulse lanes. Projectiles travel slowly for 0.65 seconds, stop and flash for 0.7 seconds, then release along their original axes. Phase 2 rotates the axes; its interruptible reactor beam remains the other attack. Reflection cancels the stop/release schedule and clears the flash.

The correction changes geometry and motion, not health or damage. Shot counts remain modest. No runtime validations were run; readability and maneuvering room still require play feedback.

## Fix — elite reward stalls with preinstalled upgrades

Reward availability and complete-build checks now use the union of recorded draft selections and the live ship's installed upgrades. Preinstalled modules can no longer appear as unowned cards that reject selection. The run controller resolves the supply fallback again when the reward opens, removes the empty-choice branch that could leave interlude processing stalled, and always presents a completable panel. The supply/continue button receives keyboard/controller focus. Claim locking remains in place.

No runtime validations were run for this fix.

## Iteration — attack facing, deliberate fan gaps, and complete-build rewards

Boss model containers now smoothly turn toward the player. During a Commander charge they face the locked charge path. Rotation is visual-only so collider alignment, pod locations, and locked attack telegraphs are not rotated accidentally.

Tiny Rogues inspiration: the community [Banshee pattern description](https://roguepedia.net/w/Banshee) describes an even fan whose center can be safe, with changed projectile spacing in its next phase. Harbinger echoes now use that general spacing principle: an eight-ray even fan initially leaves a central opening, while later phases offset alternating echoes by half a slot. These replace its radial echo bursts rather than adding another layer. This is an adaptation of the documented pattern idea, not a claim to have played or reproduced the source fight.

At elite reward milestones, a player who owns every elite in the current unlocked pool now receives an explicit supply claim instead of silently losing the reward. Claiming awards 50 orb value through normal orb progression and five additional health; orb healing remains additive. A pending flag and selection lock prevent repeat claims. New runs clear pending rewards, and practice cannot claim them. Locked blueprints do not prevent completing the current available collection.

No tests or runtime validations were run for this iteration.

## Boss mechanic rework — Tempest orbiting storm

Tempest now deploys a three-second orbit of projectiles around a fixed center, at a 140-pixel radius, rather than another outward pinwheel. Two opposite openings rotate with the formation. Reflected projectiles immediately leave orbit, so a controlled boost can carve a crossing while ordinary movement can follow a gap. Sparse aimed follow-ups discourage remaining stationary.

Phase 1 rotates one direction; Phase 2 reverses; Phase 3 alternates direction between deployments and slightly increases orbital speed. Deployment is announced before release, and no projectile materializes within 75 pixels of the player's current position. The orbit uses existing projectile sweeps and bounded pools; phase transitions clear it with the other enemy projectiles. No runtime validations were performed.

## Boss mechanic rework — Harbinger echo traps

Harbinger volleys now mark the player's current location with a rose ring. After 1.6 seconds, that fixed location releases an outward burst from the ring's edge. It does not chase or retarget the player. Players can bait placements away from their intended route, leave the mark, or return to its empty center after release.

At most three marks can exist; marks within 90 pixels of an existing mark merge by suppressing the new placement. Phase 1 uses eight reflectable rays; later phases add two rays per phase and sparse cyan shots. Two adjacent rays are always omitted. The old generic perimeter/pincer layer is removed from this boss, leaving one small aimed fan at the start of each sequence alongside the echo mechanic. Phase transitions and death remove pending marks before they fire.

No runtime validations were performed. Tempest’s subsequent orbiting-storm entry replaces its rotating-arm implementation.

## Boss mechanic rework — Bulwark siege pods

At the start of each Bulwark volley sequence, up to two surviving pods deploy destructible mines into flanking lanes. Mines retain the existing fuse telegraph, shot/boost defusing behavior, and shared hazard admission limits. They never spawn within 100 screen pixels of the player. Phase 2 spreads the deployment farther outward; Phase 3 uses cluster mines, without persistent plasma.

Destroying a pod immediately removes its still-active deployed mines and prevents that pod from deploying more. Destroying the mines instead buys temporary space while preserving the pod threat. Phase transitions and boss death clear owned mines; return-to-pool callbacks remove ownership references before reuse. Reduced hull HP and existing armor-breaking rules remain. No runtime validations were performed.

## Boss mechanic rework — Commander charge and recovery

The Commander alternates projectile attacks with a physical charge. A translucent orange lane marks its locked path for 1.1 seconds. It then travels along that path over 0.7 seconds, stops, and exposes a 1.8-second recovery opportunity before resuming attacks. Charge distance grows from 220 to 260 to 300 screen pixels across phases, with the destination constrained inside the arena. It does not steer after the warning begins or fire volleys during the charge/recovery.

The player can bait the path, leave it sideways, and counterattack at the destination. Existing craft-contact damage applies; the lane is a warning rather than a new invisible damage field. Phase changes and destruction cancel charge motion and hide the lane. No runtime validations were performed.

## Boss mechanic rework — Core reactor interruption

The earlier palette/silhouette pass did not establish sufficiently distinct fights. This rework starts adding interactive mechanics, rather than treating shapes as unique attacks.

The Tempest Core alternates its phase-specific projectile sequence with a two-second reactor charge. Dealing 8/12/16 actual hull damage during that charge (by phase) interrupts it, cancels the attack, and creates a 2.5-second firing opportunity. Destroying armor pods helps meet the interrupt threshold because existing armor still reduces hull damage. Failed interruption releases a hazard-managed rail beam along the previously locked aim line, with the beam's own visible lane warning before damage. Players choose between committing fire to interrupt or moving out of the lane.

Phase transitions and boss destruction cancel the reactor weapon and any owned beam. A return-to-pool callback releases the beam reference so later boss cleanup cannot cancel a rail reused by another enemy. This retains the reduced HP and projectile density. No runtime validations were performed. Other bosses still need equivalent mechanical differentiation; this entry does not claim the entire rework is finished.

## Balance addition — unique bosses and explicit phase transitions

Boss hull HP is reduced by another 20%, using a cumulative 0.64 multiplier on the pre-reduction formula before rounding. Default Commander HP is now 358 and Bulwark HP is 530. Weapon-pod health is unchanged.

Each boss now uses its own three-phase attack progression rather than sharing five generic attack families:

| Boss | Reflectable-shot palette | Phase 1 | Phase 2 | Phase 3 |
| --- | --- | --- | --- | --- |
| Assault Commander | Orange | Spearhead: accelerating aimed fans | Flank Assault: split lance wings | Breakthrough: sweeping broad lances |
| Iron Bulwark | Gold | Battlement: slow perimeter walls | Siege Gates: alternating lane shutters | Last Redoubt: alternating braking and steady shells |
| Tempest | Lavender | Pinwheel: four rotating spokes | Counterwinds: alternating curved arms | Cyclone: six spiral arms |
| Void Harbinger | Rose | Ambush: offset pincers | Echo Trap: braking bait followed by accelerating replies | Void Bloom: curved rings alternating with pincers |
| Tempest Core | Ivory | Reactor Pulse: decelerating shells | Polarity Shift: opposing curved crescents | Core Collapse: pulse rings alternating with accelerating jets |

At two-thirds and one-third HP, the boss cancels pending attacks, clears the enemy projectile field, announces its new named phase, and pulses its warning for 1.5 seconds. A short recovery and a fresh attack telegraph follow. Bosses remain damageable during the transition. Destruction cancels transition state. The boss HUD persistently displays the phase number and name, with the health bar colored to match that boss’s reflectable projectile palette.

Each boss also has a dedicated reflectable projectile silhouette: Commander spear wedges, Bulwark box shells, Tempest open rings, Harbinger flattened seeds, and Core hexagonal wafers. Meshes are shared and reuse restores the default projectile geometry; cyan diamonds override boss styles.

New braking projectiles slow to 45% of launch speed after an initial travel period. Accelerating shots use an elongated silhouette; braking shots have a broader silhouette. Boss palettes apply only to reflectable projectiles: cyan diamonds always retain their fixed non-deflectable appearance, and reflected shots retain their green feedback. Pooled reuse restores the original shape and colors.

The recent lower-density direction remains: modest shot counts, 0.8–1.2-second burst spacing, shared escape corridors, and no extra perimeter layer for bosses already firing rings. Phase progression changes geometry and motion rather than merely adding bullets.

No tests or runtime validations were run for this pass.

## Balance correction — less overlap and 20% lower boss HP

Player feedback found the dense version impossible to maneuver through. This correction supersedes the density and health values below.

- Boss hull health is reduced by 20% before final integer rounding: Commander 448 HP, Bulwark 662 HP at default difficulty. Pod health remains unchanged.
- Primary volleys have roughly one-third fewer projectiles with wider spacing. Surrounding rings drop to 32–40 slots and fire only at the start of each sequence, instead of every burst.
- Standard burst spacing increases from 0.38 to 0.70 seconds; shifting gates from 0.80 to 1.15 seconds; delayed replies use 1.20 seconds initially and 0.85 seconds thereafter.
- Recovery between sequences increases to 1.60/1.35/1.10 seconds across health phases. The shared escape corridor widens from 0.36 to 0.44 radians.
- Mixed cyan/normal projectile behavior remains, preserving controlled boosting without the previous level of overlap.

No tests or runtime validations were run for this correction.

## Balance addition — durable bosses and dense mixed fire

Latest player feedback calls for bosses that withstand basic builds and denser arena coverage. This pass supersedes earlier boss HP and sparse-volley values below.

- Boss hull HP is `(400 + wave × 32) × enemy health multiplier`, with the existing 1.15 Bulwark/Core multiplier: Commander 560 HP, Bulwark 828 HP at default difficulty. Pod health retains its previous formula.
- Lances, crossfire, shutters and spiral rings have denser spacing and more shots. Every burst also emits a slower 48–64-slot surrounding ring to pressure previously empty flanks. Recovery between sequences is shorter.
- All layers omit a shared 0.36-radian escape corridor, offset from locked player aim. Shutters alternate its side between bursts. Curving shots receive extra clearance so their bend cannot enter that corridor; pod and pincer offsets widen their excluded firing angles conservatively to protect the corridor beyond the boss’s 120-pixel near zone, rather than checking a single reference distance.
- Every sixth projectile slot becomes a straight cyan boost-breaker, alternating placement between bursts. Most fire remains reflectable, but steering matters during the boost. Delayed replies also mix normal and cyan shots.
- The bounded enemy projectile pool increases from 256 to 1024 to accommodate the overlapping layers; firing still cannot allocate past its warmed capacity.

No tests or validations were run. Full-fight difficulty, corridor usability at different distances, and rendering performance need player assessment.

## Balance addition — shifting gates and delayed replies

Boss attack cycles now contain five families: lances, hull-specific crossfire, shifting gates, bait-and-reply volleys, and curved rings. Existing phase-based burst limits and bounded projectile pools still apply.

- **Shifting gates:** a broad fan leaves a three-slot opening on one side, then switches the opening to the other side after 0.8 seconds. Equal projectile speeds maintain separation between successive gates. Players can move between openings or escape beyond the fan's outer edge.
- **Bait and reply:** the opening fan leaves a center pocket. After 0.95 seconds, a narrow three-shot reply targets that original pocket, catching a boost spent immediately on the opening. Later phases add replies at 0.55-second intervals. Aim stays locked throughout, so moving off the original line avoids the follow-up.
- Eligible bosses use cyan, non-reflectable replies with an explicit delayed-cyan warning. The opening fan remains reflectable. The Commander introduces cyan shots only after its first phase transition.
- Pods do not add shots to either new family, keeping their intended openings clear. Attack instructions describe the lane change or delayed reply before the sequence starts.

No tests or validations were run. Pattern difficulty and readability remain subject to player feedback.

## Balance addition — boost-breaking projectiles

Boss lance sequences now mix in cyan diamond projectiles that cannot be deflected. They retain hostile collision and damage during a boost; normal shields and post-hit invulnerability still apply. Round amber/violet shots retain their existing reflection behavior.

The Commander introduces these shots after its first health phase; subsequent boss hulls use them from their opening phase. On alternating bursts, one center lance is replaced with a straight-flying cyan diamond, producing one or two boost-breakers per sequence. The rest of the volley remains reflectable. The charge lasts 0.85 seconds and announces “CYAN DIAMONDS · DODGE, CANNOT REFLECT.” Ring escape lanes are unchanged.

The projectile uses the existing bounded pool, shared diamond geometry, and per-instance colors. Pool activation restores the normal shape, colors, and reflection behavior before applying the next projectile profile. No tests or validations were run for this addition.

## Balance addition — boost reflection follow-up

Further player feedback identified boost reflection as a likely source of excess power while a fire-rate build already supplied sufficient weapon DPS. Weapon fire rate remains unchanged.

- A three-reflection boost earns one chained follow-up. The follow-up cannot earn another chain and always ends with the full 0.85-second recharge.
- Ordinary reflection cooldown is now 0.70 seconds after one reflection, decreasing by 0.05 per extra reflection to a 0.55-second floor (previously 0.35 down to 0.10).
- Letting the chain input window expire no longer leaves boost fully recharged. Recharge runs during that window; projectile protection ends with the actual dash.
- Reflection radius decreases from 74 to 48 screen pixels. Boost duration, travel distance, and steering remain unchanged.
- Reflected projectiles deal one damage independently of weapon damage upgrades, through their own hit handler. They no longer also trigger normal weapon damage.
- The HUD labels the final chained boost, and Flight School explains the single follow-up limit.

No tests or validation runs were performed for this pass. These changes need player feedback on defensive timing and boss pacing.

## Balance addition — 2026-09-12: interception and boss attack cycles

Player feedback: ordinary enemies lose pressure before the second boss, and bosses die too quickly with repetitive attacks. This addition changes native combat code; the original proposal below is preserved.

- Ordinary enemy health is unchanged. Generation II+ basic pursuers lead player velocity, approach along opposite flanking lanes, converge near the player, and turn more effectively while retaining bounded steering.
- Generation II+ fast ships combine their changing weave with intermittent interception turns: at most 22.5 degrees per decision and 45 degrees from their entry direction, retaining a forward exit. Trajectory changes preserve position. Generation II+ bombers reconsider lateral drift every 1.1 seconds to cross the player’s projected route, with a dead band to avoid jitter and their original boundary handling. Neither role gains speed or health.
- Generation II+ snipers alternate direct shots with predictive aim. Every third eligible shot brackets the locked center with two slower side shots; all three paths are telegraphed before release. Existing Generation IV rail attacks remain.
- Boss hull HP is now `(80 + wave × 12) × enemy health multiplier`, with an additional 1.15 multiplier for Bulwark and Core. At the default multiplier the first boss has 140 HP and the second has 230 HP, previously 60 and 75. Weapon-pod health keeps its previous formula, preserving a practical armor-breaking objective.
- Bosses cycle accelerating lance bursts, hull-specific crossfire, and curved spiral rings. Crossfire distinguishes the Commander’s sweeping fan, Bulwark’s layered rings, Tempest’s rotating arms, and Harbinger/Core pincers. Each charge announces its attack family and locks aim; health phases increase sequences from two to three to four bursts, separated by 0.38 seconds.
- Amber accelerating projectiles begin slowly and reach 1.85× launch speed; violet curved projectiles bend for 1.2 seconds, then fly straight. Both use existing bounded projectile pools and remain reflectable. Reflection cancels special motion; reuse resets motion and visual overrides.
- Rings leave three adjacent projectile slots empty. Pods only supplement lance attacks, keeping ring escape wedges clear of pod fire.
- Bosses hold position through each charge and burst sequence, then smoothly resume patrol. Phase and ring geometry are captured when the warning begins, preventing damage thresholds or pod destruction from unexpectedly changing an attack already in progress. Warnings describe the actual hull-specific pattern and a dodge response. Destroyed pods stop firing immediately.

No tests or validation runs were added or performed for this balance pass. These values are an initial response to player feedback; difficulty and readability still need player assessment.

## Implementation addition — 2026-09-11

The implementation now includes boost/chain and separate orb-progress feedback, interactive Flight School, elite drafts after Waves 5/10/15, role-aware upgrade choices and build summaries, campaign route integration and authored encounters, optional courier interception, and boss-pod feedback with discovered-boss practice. The supporting menu work includes the expedition map, archives, remappable controls, interface settings, and coordinated reward/story/route interludes.

Live checks used a temporary project overlay with SaveManager writes disabled. No test files were added. Campaign progression was exercised through the Wave-20 victory decision and Wave-21 continuation using existing development controls. A focused repeat of boss cleanup and elite → allocation → story → route → arrival returned to active, unpaused Wave 6 with an empty interlude queue and no runtime errors.

An intermittent Forward+ null-material error was reproduced in seeded Wave-1 combat. Retaining removed enemies' materials prevented it; the implementation now shares immutable converted materials by source resource instead of allocating them per enemy. The previously failing seeded run, twenty enemy activations/removals covering five archetypes across all four generations, and return-to-menu teardown subsequently completed without errors. The cache remained at 65 entries. These checks do not establish balance, new-player comprehension, or complete controller/accessibility coverage. The acceptance criteria below remain review goals, not claims that every criterion has passed.

Courier cleanup now runs whenever a run interlude opens, including ordinary-wave allocation screens. A live check started a Wave-3 courier, opened allocation, and confirmed the courier was removed, its indicator hidden, and a late completion callback awarded no score. The check produced no runtime errors and kept save writes disabled.

The four sector briefings now meet the 45–70-word copy budget with route, reflection, and boss-targeting context. A live Wave-20 practice session retained zero score, stayed active at one life after repeated hits, and applied no permanent speed/fire-rate bonuses. Injected kill/boss events and run finalization left tracked supplies, salvage, records, milestones, boss discovery, and campaign state unchanged in memory. Save writes remained disabled throughout; this checks practice isolation, not normal save persistence.

## Completion audit addition — 2026-09-12

The implementation is not yet signed off. Verified results and remaining acceptance work are listed separately below:

| Requirement | Current evidence | Remaining work |
| --- | --- | --- |
| New-player boost/chain comprehension and route identity | Production practice and route-dependent encounters exist; isolated practice progression checks passed. | Player observation and feedback; automated state changes cannot prove comprehension or enjoyment. |
| Earlier-build balance across three hulls | Milestone and continuation sequencing exercised with development controls. | Representative complete runs across hulls and challenge combinations, with pacing and damage observations. |
| Stable rendering during production combat | Shared enemy-material caching resolved the seeded reproduction; generation coverage and menu teardown stayed clean with a stable cache size. | Longer representative combat runs to broaden coverage beyond the known reproduction. |
| Controller and 720p accessibility | Controls/map scrolling and reward/confirmation focus were corrected. The allocation screen was visually checked at 720p/130%; injected gamepad events completed hold-to-confirm. | Physical-device play and full-session usability observations. |
| Durable progression compatibility | Approved disposable disk round trips, version-2/version-4 migration, corrupt-primary recovery, and future-version preservation passed. Practice leaves tracked progression unchanged in memory. | No outstanding defect from these checks. |

Additional focused results: Supply Blockade courier completion awarded exactly 500 score once, spawned no power-up, added no wave orbs, and rejected a second attempt in that sector. Story Off now discards story panels already waiting behind rewards without marking them read, and preserves immediate encounter warnings. The departure cue is one two-second bar on the shared 120 BPM transport. No new test files were created for these checks.

The allocation popup was also inspected in a rendered 1280×720 screenshot at 130% text scale: its heading, point count, three stat rows, and Confirm control were legible and did not overlap. Its first stat button receives focus, spending the final point focuses Confirm, and repeated confirmation applies the allocation only once. This is a focused reward-screen result, not complete interface accessibility coverage.

After explicit approval, 100 runtime drafts from the current unlocked pool produced no duplicate cards or role-diversity failures. With all but one available upgrade marked owned in temporary memory, the selector offered exactly the remaining card. The original selection state was restored, save writes remained disabled, and no runtime errors occurred. This does not substitute for full-unlock balance comparisons.

Injected gamepad events exposed missing A/B menu accept/cancel bindings; explicit wildcard-device safety bindings now supply them. D-pad navigation and a held A press subsequently completed the confirmation dialog through the input path. Runtime inspection confirmed left-stick movement, trigger fire/boost, and D-pad/left-stick menu navigation. Flight pause uses the separate `pause` action or keyboard Escape, so adding B as menu cancel does not also bind it to flight pause. Physical-device and complete gameplay coverage remain outstanding.

On 2026-09-12, an explicitly approved disposable save/reload check under `/tmp` preserved controls, boss discovery, salvage, and recovered-but-unread fragments across a process restart. Corrupt-primary recovery exposed a backup-rotation bug: the next save replaced the healthy backup with the corrupt primary. SaveManager now rotates only a valid compatible primary and preserves the backup when replacing an invalid primary. Repeating recovery and saving retained the healthy backup and produced a valid primary. Godot logged the expected JSON parse errors for the deliberately corrupted primary; no script errors occurred. The real player save was not used for these writes; legacy migration coverage remains separate.

Disposable legacy saves were subsequently loaded through normal startup: a version-2 save retained score/salvage, migrated a flat purchased unlock to level 1, supplied empty campaign/boss/control defaults, and saved as version 6 without runtime errors. A version-4 viewed fragment migrated to recovered status while retaining its read marker and appeared in Archives.

A disposable unsupported version-99 primary remained byte-for-byte unchanged after changing a setting and requesting a save. The build loaded its compatible backup with the future-version read-only guard active.

## Original proposal

### Original review context

Review date: 2026-09-10. Basis: current working-tree design documents and GDScript, with Godot 4.6.3 confirmed. This is a design/code review, not a live playtest; balance and enjoyment claims below are hypotheses to validate.

## Recommendation

Build the next gameplay milestone around three outcomes: players learn to use boost reflection deliberately, establish a distinctive build earlier, and encounter different tactical situations between bosses. Preserve the Wave-20 Expedition and optional Endless structure.

Complete the existing Return Signal route integration as a prerequisite to route-specific gameplay. This supplements `docs/additional-features-plan.md`; it does not replace its story/menu scope or propose that work again as a new feature.

## Findings from the current build

| Evidence | Design implication |
| --- | --- |
| `GAME_DESIGN.md` describes a 2D runtime and lists already completed work among pending improvements. `README.md` and native scripts establish the current 3D baseline. | Refresh the design baseline during implementation; do not use the old pending list as the backlog. |
| `native_encounter_director.gd::_pick_kind()` uses a fixed archetype array after Wave 2. Authored route profiles and `ExpeditionManager.get_current_route_profile()` exist, but this director does not consume them. The production run has no campaign milestone/route interlude integration. | Campaign foundations are present, but route-dependent combat is unfinished. Integration is prerequisite work, not a new campaign system. |
| `game_manager.gd::_on_boss_died()` grants elite rewards on multiples of 10, with Wave 20 returning through victory before that branch. | The finite Expedition offers one elite transformation, at Wave 10. Thirteen supported abilities provide substantially more variety than a single finite run can express. The comment mentioning Wave 15 does not match the condition. |
| Player boost tracks reflections, reduced cooldown, and a three-reflection chain threshold. The shared gameplay scene already renders boost/chain status text. | Improve timing feedback and teach mastery using the existing mechanic. Do not add another dash system. |
| Flight School is five briefing pages. The HUD's orb meter shows life recovery; wave advancement tracks a separate orb total. | Interactive practice and explicitly separate progress displays would help players understand decisions already available. |
| Boss pods already reduce incoming volleys; active pods protect Bulwark/Core through damage resistance. | Make existing target-selection consequences clearer before adding more boss hulls. |
| ThreatDirector limits enemy count, weighted pressure, and light-enemy composition. | New encounter content must respect these limits rather than adding a second unrestricted spawner. |

## Prioritized feature proposals

### 1. Boost mastery and combat clarity — first playable slice

**Player experience:** a compact indicator near the craft or reticle shows boost recharge, three reflection pips, and the remaining chain opportunity. Distinct shape/audio cues accompany readiness. The HUD separately labels “Next wave” and “Next life,” switching wave progress to a boss objective during boss encounters.

Add a replayable, skippable practice drill: move/aim, reflect a slow volley, chain a second boost, then collect enough orbs to demonstrate the two meters. Practice uses the production player/projectile rules and cannot bank salvage, consume supplies, alter best scores, or advance the campaign.

**Implementation:** expose a read-only boost-state projection from `player_3d.gd`; replace/extend the status presentation in `native_3d_gameplay.gd` and `ui/hud.gd`. Add a small practice scene/controller and a Flight School entry. Read actual timer state so “chain ready” is not inferred solely from a historical reflection count. Keep the existing chain timing initially; tune only after observing practice attempts.

**Acceptance:** a new player can intentionally reflect and chain without coaching, distinguish life progress from wave progress, and understand ready versus recharging states. Verify keyboard/controller, pause/resume, revive, reduced flashing, and 720p visibility. Confirm practice leaves durable progression and armed supplies unchanged.

**Effort:** medium. Main risk: adding visual clutter around the craft; offer a restrained HUD-only presentation.

### 2. Earlier and more coherent run builds

**Player experience:** prototype elite choices after Waves 5, 10, and 15, allowing a build to develop across the Expedition. Wave 20 remains the victory decision. Preserve the existing Endless cadence initially.

Improve cards with short role labels and specific stacking explanations: for example, spread plus temporary spread produces the existing five-shot central fan. Add a pause-screen build summary. Use role-aware three-card drafting to avoid offering three near-identical roles when alternatives exist; preserve unlock restrictions and unowned-only selection. Defer rerolls until playtests show they are needed.

**Implementation:** make milestone rewards an explicit policy in `game_manager.gd`; retain native capability filtering in `native_player_upgrades.gd`. Put offer generation behind a small testable selector shared by the reward UI. Add role/stacking metadata to the upgrade catalog. Coordinate rewards through the same interlude owner needed by the Return Signal plan.

**Acceptance:** exactly one transformation choice at each proposed milestone; no duplicate, locked, or unsupported offers; correct behavior with a nearly exhausted pool. Test elite → allocation ordering and simultaneous boss death/player death. Compare boss clear time, damage taken, and completion rates with the current cadence before committing balance changes.

**Effort:** medium. Main risk: three transformations substantially increase player power. Treat the schedule as a balance prototype; avoid automatically compensating with blanket enemy HP increases.

### 3. Route identity and authored encounter rhythms

**Player experience:** Iron Wake favors deliberate armor/mine clearing; Ghost Lanes favors interception and crossfire movement. Within a sector, brief encounter patterns interrupt the otherwise continuous random stream: a fast interception group, a protected tank advance, or a sniper crossfire with a clear escape lane.

**Prerequisite:** finish the existing campaign slice: real route selection, production lifecycle calls, safe interlude sequencing, and passing the selected profile to combat. Existing shell placeholders are not completion evidence.

**Implementation:** resolve profile weights in `native_encounter_director.gd`; retain early-wave restrictions and ThreatDirector admission. Define small encounter resources describing composition, entry lanes, telegraphs, and maximum duration. Start with Iron Wake/Ghost Lanes and two encounter patterns. Encounter groups replace part of the ambient budget; they do not stack extra enemies on top. If a planned group cannot be admitted, defer briefly or cancel it rather than accumulating a burst queue.

**Acceptance:** seeded sampling verifies profile weighting while respecting the minimum light-enemy rule; active pressure may change realized proportions. Playtesters can distinguish routes without reading their names. Every pattern has an escape opportunity, respects special-attack limits, and clears safely at a boss transition. Keep route economy/HP/spawn multipliers neutral as specified in the existing plan.

**Effort:** large including unfinished campaign integration; medium for encounter content after that prerequisite.

### 4. Optional field objectives — subsequent slice

**Player experience:** occasionally intercept a courier before it exits or recover a drifting signal cache while regular combat continues. These create short risk/reward decisions without making ordinary wave completion depend on a side objective.

**Initial scope:** one courier objective, at most once per sector on a non-boss wave. Announce it clearly, show remaining opportunity, and allow it to expire harmlessly. Reward a capped score bonus and a short-lived combat pickup; under Supply Blockade provide score only. Avoid adding life/orb rewards until the existing recovery economy is measured.

**Implementation:** a scene-owned objective controller uses encounter admission and owns start/success/failure/cleanup. Mark completion once, cancel on boss/interlude/abandon, and prevent retries or repeated callbacks from duplicating rewards. Add one results-summary line. Reuse an existing craft for the prototype before commissioning art.

**Acceptance:** completion is optional, rewards occur once, timeout cannot strand a wave, and the objective respects challenge modifiers. Measure whether players pursue it and whether doing so meaningfully changes movement.

**Effort:** medium. Depends on encounter scheduling from proposal 3. Scope expansion beyond the existing route MVP should be a separate follow-up milestone.

### 5. Boss targeting feedback and focused practice

**Player experience:** active weapon pods have readable targeting cues; destroying one clearly communicates reduced fire or broken armor. After first encountering a boss, players can practice it from Flight School with a standardized loadout and no progression rewards.

**Implementation:** surface pod-state changes from `boss_section_3d.gd`/`boss_enemy_3d.gd` to the HUD and audio presentation. Reuse the practice isolation from proposal 1 and the existing authored boss IDs. Persist encountered-boss discovery only if this unlock rule is adopted, with save migration coverage.

**Acceptance:** players can explain the value of attacking pods; cues remain legible during full-build combat. Practice cannot consume supplies or bank score/salvage. Preserve the authored Wave-20 boss and Wave-25 revelation.

**Effort:** small for feedback; medium for the practice extension. Boss practice can ship independently of optional objectives.

## Delivery sequence and validation gates

| Stage | Deliverable | Exit gate |
| --- | --- | --- |
| 0 — baseline | Reconcile design docs; add lightweight local run diagnostics for wave duration, damage source, reflections/chains, upgrade selections, and boss duration. | Record representative fresh-profile and upgraded-profile runs. Establish baseline distributions before choosing numeric pacing targets. |
| 1 — immediate review build | Proposal 1: boost/orb clarity and interactive practice. | New-player practice observation plus isolation and input checks. |
| 2 — build experiment | Proposal 2: Wave 5/10/15 drafting, role-aware offers, stacking summary. | Full Expedition comparison across three hulls; no duplicate reward or victory/continue regressions. Decide whether to keep the proposed cadence. |
| 3 — route vertical slice | Finish Return Signal dependencies; integrate two route profiles and two encounter patterns. | Route choice demonstrably changes combat; no pressure-limit violations or interlude races. Then extend to remaining authored routes. |
| 4 — targeted expansion | Courier objective and boss feedback/practice, delivered separately. | Optional-objective/reward lifecycle checks and boss target comprehension tests. |

Effort labels are relative engineering scope, not delivery dates; they include focused validation but exclude bespoke art/audio production. Stage 3 is the largest dependency because campaign integration remains unfinished.

For each gameplay stage run relevant existing native completion, autoload, expedition progression, and frontend navigation smoke scenes, adding behavior tests only for new rules. Manual coverage should include fresh/upgraded profiles, all three hulls, Supply Blockade, Energy Drought, a combined-modifier stress run, boss death with player death, continue/retry, abandon, Wave-20 victory, and Wave-21 Endless continuation. Test a representative full build for readability and frame-time regressions.

## Defer until these changes are evaluated

- More enemy archetypes or boss hulls: first extract more variety from existing enemies, pods, and encounter compositions.
- Additional permanent stat tiers: assess whether the current economy already overwhelms early difficulty.
- New active abilities, weapon crafting, or large synergy trees: earlier access to existing transformations should establish whether more systems are needed.
- Leaderboards and seeded challenge modes: stabilize reward cadence and scoring before creating comparison-sensitive modes.
- Mid-run suspend/resume: useful potential follow-up, but intentionally outside the current session-scoped campaign contract and a separate persistence project.

Recommended initial approval scope: stages 0–2. Review the resulting combat/build experience before expanding into new objective content.
