# Gameplay improvements implementation plan

Status: proposal for review; no gameplay implementation authorized or performed.

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
