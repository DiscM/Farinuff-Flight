# Farinuff Flight — cohesion and refinement guideline

Design direction, September 21, 2026. Read alongside the [primary-source research](indie-cohesion-research.md). This is the current refinement baseline; historical sections in `GAME_DESIGN.md` are not an implementation backlog.

## The promise

**Read the danger. Turn enemy fire against it. Build a ship worth bringing home.**

The butterfly craft, drifting flight, boost reflection, modular hull, and expedition through the Return Signal belong to one game. New mechanics, art, sound, and UI should support at least one part of that promise and avoid obscuring the others. Adding content is not a substitute for making this loop satisfying.

## Rules we will build by

| Guideline | Applied to this game | Acceptance evidence |
| --- | --- | --- |
| Make the signature action worth learning. | Reflection has a visible offensive payoff and a clear chain opportunity. Normal fire remains dependable. | Measure reflected hits and chains; verify damage and one-follow-up boundaries. Watch a new player explain reflection. |
| Show the next meaningful destination. | Current wave and next boss/reward stay visible during combat and agree with pause. Wave 20 is a finale; Endless is explicitly labeled. | Inspect Waves 1, 5, 15, 20, 21, 25, 30 and practice. Verify actual reward policy matches the displayed promise. |
| Offer an understandable build decision. | A draft can extend an installed weapon interaction while retaining alternative roles. Cards describe real interactions, without hidden synergy bonuses. | Test locked/owned exclusion, exhausted pools, role variety, connected offer availability, and actual projectile behavior. |
| Alternate pressure with room to act. | Formations replace ordinary spawn slots, then briefly stop new arrivals. Existing enemies remain dangerous. Boss rewards are genuine safe boundaries. | Verify active-time recovery, no queued spawn burst, unchanged threat admission and boss timing. Natural play must reveal whether the pauses are useful. |
| Keep recovery deliberate. | Continue screens explain the hit and keep the decision available until chosen. Readable information never races an automatic decline timer. | Wait beyond the former deadline; exercise keyboard, controller, quit confirmation, duplicate clicks, and depleted reserves. |
| Reward knowledge as well as survival. | Pause and results share a factual flight record: reflections, counter-hits, chains, hit count, streak, and active time. Advice follows observed hit category. | Verify accepted hits only, before defeat listeners; no practice contamination or duplicate settlement. Never infer intent or accuracy from these counters. |
| Make useful supplies varied. | Pickup selection cycles through eligible types without adding drops. Boss bags exclude nukes; challenge restrictions still win. | Check full cycles, repeat protection when alternatives remain, boss/field transitions, and Supply Blockade. |
| Let the action retain visual priority. | Extend the existing compact header; reuse existing panel typography, restrained cyan/gold/green hierarchy, and actor previews. Avoid new center-screen banners or decorative shake. | Live 720p and large-HUD review with developed builds; important shapes must remain legible under reduced effects. |
| Tune from play evidence. | Keep authored difficulty and economy unless a concrete hypothesis warrants a change. Separate natural, assisted, practice, base-profile, and upgraded-profile runs. | Logs plus player observations. Green smoke tests are not evidence of enjoyment, popularity, or final balance. |

These rules synthesize Subset's constraint-led readability, Mega Crit's role-based iterative balance, Supergiant's meaningful repeated runs, Celeste's precise forgiveness, and Valve's pacing/readability practices. Specific constants below are Farinuff experiments, not values recommended by those developers. See the research file for citations and source limitations.

## Initial implementation: a connected pass through the run

1. **Combat payoff:** reflected shots deal two damage rather than one, independent of weapon upgrades. This is a bounded tuning experiment: a Gen-I tank with eight HP takes four unarmored returned hits instead of eight. Regular base shots remain one damage; boss armor continues to resolve through its existing rules. Review boss clear time and projectile-heavy fights before calling this final balance.
2. **Build direction:** when the legal offer pool contains an interaction with an installed module, the draft reserves one choice for such an interaction, then fills with differing roles where possible. Extra cannons, fan/rear fire, homing, piercing, and explosive rounds expose their existing combinations on cards. No locked modules are introduced and no automatic choice is made.
3. **Mission continuity:** a shared milestone model supplies the HUD and pause screen. It names the next boss and exact reward type. The pause screen now correctly labels post-victory continuation as Endless rather than relying on the cleared victory-modal flag.
4. **Encounter rhythm and supplies:** completed or expired formations receive a 2.2-second minimum spawn gap; the previous 2.5-second post-boss regroup remains. A shuffle bag supplies pickup variety at the existing drop cadence, with a separate no-nuke boss pool.
5. **Learning from the run:** accepted damage, reflections, counter-hits, chained boosts, streaks, and active time feed a run-local flight record on pause, defeat, and victory. The continue screen names the last damage category and offers a specific response. Removing the ten-second auto-decline preserves the opportunity to read and decide.

## Further refinement roadmap

These are subsequent playtest-driven work, not claims of completed work in this pass.

- **Opening:** observe whether the new Wave 3 firing opportunity produces deliberate reflection and whether its brief cue helps. Do not equate a scripted reflection with player understanding.
- **Build viability:** compare precision, coverage, defense, and mobility across routes. Compare Hull Plating’s new reflection-charged guard against transformative weapon options, using offer context, armor saves, and clear times.
- **Full-run pacing:** use the new per-wave measurements, boss time, abandoned runs, and build offers. Review overlap in Waves 11–20 and Endless separately. Tune one major variable at a time.
- **Art and audio cohesion:** review the actual gameplay camera, not isolated models. Audit enemy silhouettes, friendly/reflected/hostile projectiles, pickup shapes, damage tells, and mix priorities in dense combat and reduced-effects settings.
- **Progression economy:** assess fresh and established profiles without requiring permanent-stat purchases to make the opening fair. Keep ship variants meaningful sidegrades and settlement exactly once.

## Playtest rubric

Use the existing [opening](opening-playtest.md) and [Expedition](expedition-playtest.md) protocols. Preserve individual failures and confusion, not just averages.

Ask after play: What is boost for? What is the next meaningful reward? Why did you choose that module? What hit you? What did this run retain? Can you explain Return Home versus Endless? These are comprehension checks, not a quiz administered during combat.

Record whether the player intentionally reflects, uses the chain cue, understands the build connection, uses formation recovery to reposition or collect, and retries voluntarily. Compare the two-damage reflection hypothesis against boss duration and damage taken. A small formative cohort can reveal problems; it cannot establish that the game will be well liked.

## Completion ledger

Research, guidelines, and the six connected implementation areas above are complete for this initial pass. The roadmap and human playtesting remain future evidence, rather than claims of final balance or popularity.

Verified with Godot 4.6.3:

- **11/11 scenes passed:** the eight standard smoke scenes, `gameplay_refinement_smoke`, `cohesion_smoke`, and `combat_readability_smoke`. The Expedition scene exercised 24 assisted journeys across ship/route/profile combinations. No GDScript errors were reported in the final run. Existing teardown diagnostics and intentionally induced negative-path errors remain in the logs.
- **Focused contracts:** returned-fire damage is independent of weapon bonuses; reflection/chain events are counted; shield/invulnerability do not inflate accepted-hit counts; fatal hit category exists before game-over listeners run; new/practice runs isolate records; legal connected drafts retain alternatives; supply bags cover eligible types and exclude boss nukes; formations leave a recovery interval; continue stays open past ten seconds and duplicate confirmation spends one stock.
- **Live Forward+ review at 1280×720:** milestone header with wave-orb progress, a developed-build draft with its connection explanation, a defeat debrief, and the untimed recovery panel. The flight record was moved above the fold after visual inspection. Retry/continue actions stay fixed while long summaries scroll.
- **Local evidence:** `.godot/cohesion-evidence/` contains `milestone-hud-720p.png`, `build-connections-720p.png`, `debrief-720p.png`, and `recovery-720p.png`. These are staged presentation fixtures, not natural performance samples. Detailed test logs are in `.godot/smoke-logs/`; both directories are local ignored artifacts.

Reproduce the new focused check with `python3 tools/run_smoke_tests.py --godot "$GODOT_PATH" cohesion_smoke`. Run `--suite smoke` for the standard integration suite, and explicitly select `gameplay_refinement_smoke combat_readability_smoke` for the other focused checks.

## September 22 follow-up: reflection mastery

- Wave 3 attempts one early production tank for up to eight active seconds, using
  ordinary spawn slots and threat admission. A seven-second binding-aware cue
  appears on its actual volley, ends on first reflection or wave transition, and
  does not expire during pause. Killing it before it fires is still allowed.
- Hull Plating retains +1 life and gains a one-hit guard after three reflections
  in one boost. A new boost can recharge it; further shots in the same boost
  cannot. Pickup shields are spent first. The HUD shows ARMOR READY, and the
  flight record counts armor saves separately from hull damage.
- Opt-in local metrics now retain per-wave combat deltas, build offers and
  installations, boss duration, initial bonuses, and partial failed/closed waves.
  Assisted events remain marked. See the opening protocol for interpretation.

These are authored tuning hypotheses. Natural player comprehension and defensive
build viability still need human play evidence.

Validation: **12/12 smoke scenes passed** (eight standard scenes plus
`reflection_mastery_smoke`, `cohesion_smoke`, `gameplay_refinement_smoke`, and
`combat_readability_smoke`). The new focused scene checks guard charging,
shield priority, invulnerability, recharge limits, removal/reset behavior,
production tank admission, cue pause/dismissal, wave deltas, and assistance
marking. A staged Forward+ 1280×720 live inspection confirmed the ARMOR READY
chip and contextual boost cue fit the combat header. No GDScript errors were
reported; existing teardown diagnostics remain in the smoke logs.

## September 22 follow-up: build reference and reward readability

- The pause screen’s Ship Upgrades reference now lists each active weapon
  connection once, describes installed modules, and shows actual system-point
  bonuses separately from hull, hangar, and module effects. The list scrolls;
  Back to Pause stays fixed. It reads the same owned-module union as drafts.
- Reward selection includes a compact current-loadout reminder. Its fullscreen
  layout now scrolls the cards while keeping installation fixed, addressing
  clipping observed at 1280×720 with 130% menu text. Focus follows card selection.
- Milestone forecasts show bonus supplies when all available modules are owned;
  point-only milestones and the Expedition finale retain their existing rewards.

Live staged review covered normal and large-text build references, long Hull
Plating copy, connected reward cards, and selecting a card with the fixed install
action. Evidence: `.godot/cohesion-evidence/reward-reference-large-720p.png`.
This pass changes presentation and reward accuracy, not difficulty or economy.

Validation: `cohesion_smoke`, `frontend_navigation_smoke`, and
`native_completion_smoke` passed (3/3). Added checks cover exhausted-pool forecasts,
unique installed connections, unknown/duplicate module IDs, fixed return actions,
large-text install bounds, and selection-to-install behavior. Existing warnings,
intentional negative-path diagnostics, and teardown messages remain; no GDScript
errors occurred in these checks or the live review.

## Final refinement audit — September 22

The implementation pass is complete. Current code and live presentation were
reviewed against the requested mechanics, balance, progression, and polish work.

| Requirement | Current evidence |
| --- | --- |
| Responsive boost with bounded chaining | `gameplay_refinement_smoke`: early input buffering, expiration, reset, reaction window, one follow-up; `combat_motion_smoke`: production movement. |
| Readable opening and pressure recovery | `gameplay_refinement_smoke`: wave-gated ambient and formation rosters, sector delay; `cohesion_smoke`: formation recovery; `reflection_mastery_smoke`: production tank, threat limits, cue lifetime. |
| Reflection payoff and defensive build | `cohesion_smoke`: independent two-damage return fire; `reflection_mastery_smoke`: armor threshold, shield priority, immunity, one refill per boost, removal/reset. |
| Meaningful, honest upgrade choices | `cohesion_smoke`: connected role-varied drafts, owned/locked exclusion, pool exhaustion, actual supply forecast, unique installed connections; `native_completion_smoke`: production upgrade behavior. |
| Bounded stat progression | `gameplay_refinement_smoke`: model/UI caps, pending choices, refunds, exactly-once confirmation; live 720p/130% allocation review with final-point focus. |
| Complete Expedition and Endless flow | `expedition_progression_smoke`: 24 assisted hull/route/profile journeys plus interruption cases; `dev_commands_smoke`: correct Endless briefing after victory flag clears. |
| Deliberate recovery and useful results | `cohesion_smoke`: untimed recovery, duplicate-input guard, damage categories and run isolation; staged debrief/recovery captures; existing expedition retry/settlement checks. |
| Supply variety at existing cadence | `cohesion_smoke`: eligible bags, repeated cycles and boss nuke exclusion; inspected `spawn_pickup()` still rejects Supply Blockade before consuming the bag or spawning. |
| Readable builds and rewards | Live 720p normal/130% build and reward review; `cohesion_smoke`: fixed actions, install bounds, selection behavior. |
| Local tuning evidence | `reflection_mastery_smoke`: wave deltas, pause exclusion, assistance marking; opt-in schema 2 records documented in the opening protocol. |

**24/24 current regression logs pass**, including the complete extended suite.
The first sweep passed 23/24; the one failure was an obsolete developer-test
fixture that set the victory flag on Wave 1. It now exercises Wave 21 after that
flag clears. That scene and the telemetry fixture were rerun successfully. The
telemetry fixture now restores counters after closing its metrics session,
avoiding artificial negative teardown deltas. No gameplay checks were removed.
Existing intentionally induced negative-path errors and engine teardown leak
messages remain; no GDScript errors occurred. These are not leak-free or
hardware-performance certification claims.

Final local evidence includes `final-regression-audit.json`,
`allocation-final-large-720p.png`, and `reward-reference-large-720p.png` under
`.godot/cohesion-evidence/`. Detailed current logs are in `.godot/smoke-logs/`.
No production saves, economy awards, or purchases were needed for verification.

The next product decision should use natural play observations: whether players
reflect deliberately, find defense competitive, and enjoy the later wave pacing.
The existing opening/Expedition protocols describe that work. It is follow-up
validation of the tuning hypotheses, not an unfinished implementation item or a
claim that the game has been audience-tested.
