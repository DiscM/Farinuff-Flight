# Run balance research: a challenging 10–20 minute Expedition

Research date: October 2, 2026. Scope: the shipping native 3D Expedition through Wave 20; Endless is separate. This is a code audit and sourced design proposal, not a measured playthrough or an implemented retune. All proposed numbers below are starting hypotheses for testing.

## Recommendation

Keep the four-sector, four-boss structure. Target roughly 15 minutes from launch to victory, including ordinary reward and route choices. First bound healing and normalize fire-rate stacking; then tune wave income and boss duration. Use attenuation narrowly if excessive boss burst remains. Preserve the pleasure of becoming powerful late in a run while keeping dodging, aiming, reflection, and target selection necessary.

## What the current game actually does

Local source links refer to the code inspected for this report.

| Finding | Evidence | Balance implication |
| --- | --- | --- |
| Every 12 orb units grants a life, with no maximum | [GameManager](../autoloads/game_manager.gd), `_on_orb_collected` | The same resource advances waves and restores health. Efficient killing and collection can simultaneously accelerate progression and remove attrition. |
| Permanent cannons give three levels of 8%; Interceptor adds 10% | [MetaProgression](../autoloads/meta_progression.gd), shop and ship catalogs | The first frame can already have substantial offensive advantage. |
| Fire-rate bonuses subtract from shot interval | [Player](../entities/player/player_3d.gd), `_update_shooting`; [weapon constants](../entities/player/player_weapon_tuning.gd) | A nominal 24% bonus produces 1 / 0.76 = 1.32× firing frequency, not 1.24×. With Interceptor, 1 / 0.66 = 1.52× before earning any run upgrade. |
| Rapid Fire multiplies interval by 0.4; Overclock divides the already-clamped interval by three | Same player method | Rapid Fire is 2.5× frequency. The 0.05-second floor becomes 0.0167 seconds during Overclock: a nominal 60 volleys/second, subject to physics/timer scheduling. Put the final floor after all modifiers. |
| Twin Cannons adds two full shots; Spread adds two central rays, or four with the temporary pickup | Player `_get_fire_directions`, `_emit_muzzle_shot` | Either permanent upgrade alone can triple emitted shots. Together they emit five shots, seven during temporary Spread. These are projectile counts, not measured DPS: aim, overlap, travel and overkill matter. |
| Homing, piercing and explosive behavior extend across emitted shots | [Projectile manager](../systems/projectile_manager_3d.gd), `_fire`; [gameplay](../scenes/native_3d_gameplay.gd), `_on_explosive_impact` | Extra shots combine with better hit reliability and splash. Explosions exclude their direct primary target but deal 2 damage to nearby targets; crowded encounters amplify the combination. |
| Elite choices occur after bosses 5, 10 and 15; availability has no wave tier filter | GameManager `offers_elite_reward`, `get_upgrade_pool`; [upgrade draft](../entities/player/native_player_upgrades.gd) | The comment describing Wave-10 upgrades does not enforce a gate. Unlocked piercing/explosive blueprints and all base elites can enter the first draft. Only three permanent choices occur before the finale, so retain early build identity. |
| Armored boss cores halve damage with `max(1, ceil(amount * 0.5))` while pods live | [Boss actor](../entities/enemies/boss_enemy_3d.gd), `take_damage` | Damage 1 → 1, 2 → 1, 3 → 2. The defense does nothing to ordinary bullets and disproportionately reduces reflected 2-damage shots. This is fixed reduction with integer rounding, not a DPS attenuation system. |
| Ordinary spawns, threat admission and formations all affect orb throughput | [Encounter director](../systems/native_encounter_director.gd), [threat director](../systems/threat_director.gd), [generation resources](../entities/enemies/enemy_generation_stats.gd) | Changing HP or drop chances also changes run length. Pressure and duration cannot be tuned independently through HP alone. |

At allocation maximum, permanent cannons maximum and Interceptor, the interval factor is 1 − 0.45 − 0.24 − 0.10 = 0.21. The 0.05-second floor limits ordinary fire to 20 volleys/second, about 4.4× baseline, before projectile-count and splash effects. Allocation provides only nine points before the finale, so all ten fire-rate levels are not naturally reachable within the finite Expedition; with all nine invested, the interval factor is 0.255 and firing frequency is about 3.92× baseline. The ten-level example describes the ceiling, not a normal Wave-20 build.

The 16 ordinary wave thresholds sum to 360 orb units before carry-over and boss contributions. Those units would grant 30 lives over time under current healing. This is a structural warning, not an estimate of observed lives: boss-time collection, surplus carry, deaths and retries change the actual total. Simply increasing wave quotas would also grant more healing.

## Research that informs the proposal

Digital Extremes describes attenuation failures as long kill times and diminished build impact, and changed its scaling to account for maximum health. Its goal includes avoiding both instant kills and drawn-out encounters. [Warframe Update 40](https://www.warframe.com/en/patch-notes/pc/40-0-0).

The subsequent hotfix removed the broad attenuation change from ordinary objective enemies and confined it to true bosses after feedback about increased kill difficulty. This is a useful caution against applying a boss solution throughout Farinuff's ordinary wave economy. [Warframe Hotfix 40.0.2](https://www.warframe.com/en/patch-notes/pc/40-0-2).

Mega Crit's balance presentation emphasizes iterative testing, giving each option a useful place without allowing it to warp the game, and interpreting metrics alongside feedback. Its discussion of skill separation supports analyzing experienced and inexperienced players separately. Applying that method here is an inference, not proof of any particular numerical target. [Anthony Giovannetti, GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

Brotato uses 20–90 second waves with shopping between them. This demonstrates a short-wave structure with explicit breaks; it does not establish that Farinuff should copy its wave durations. [Official Brotato description](https://store.steampowered.com/app/1942280/Brotato/).

## First tuning pass

### 1. Separate recovery from advancement

Keep orb collection for progression, but make its life reward a repair up to a hull capacity. Start by testing capacity equal to starting lives, with Hull Plating adding one capacity as well as its repair. Health allocation should explicitly increase capacity and repair one, so its opportunity cost remains meaningful. Preserve permanent hull purchases and ship differences in that capacity.

When full, orb units still advance the wave; avoid storing a large repair reserve that heals every later hit automatically. Test a separate repair cadence of 20–24 units instead of 12 only if the capacity change still leaves near-continuous recovery. Change capacity first so the effect can be isolated. Track repairs actually received, overflow and time at full capacity.

Do not shorten invulnerability windows in the same pass. The current 2–3 seconds provide time to recover from a mistake; removing that while reducing healing could produce abrupt deaths. Treat continues separately: current stockpiles and permanent reserves can make a session much longer. Measure run time including accepted retries and offer an optional stricter challenge after the base mode works.

### 2. Make fire-rate bonuses mean what the UI says

Use a frequency bonus: `interval = base_interval / (1 + allocation_bonus + meta_bonus + ship_bonus)`. Apply temporary frequency multipliers, then clamp the final interval. This gives each point a predictable contribution and removes the subtraction formula's increasing marginal returns.

Start testing Rapid Fire at 1.75–2× and Overclock at 1.75–2×. Test a combined temporary multiplier ceiling of 3×, with a final interval floor of 0.05 seconds. This is a tuning hypothesis: compare felt responsiveness and boss duration before adopting it. Overclock's duty cycle is 2.5/16, so distinguish its short burst from average output. Its current theoretical average multiplier is 1.3125× when continuously firing, despite a 3× burst.

The interval-floor fix alone does not solve Twin/Spread/splash synergies. Measure projectile throughput and effective damage separately.

### 3. Stage synergy without removing the first meaningful choice

Keep a distinct weapon identity at the first boss reward. Test additional cannon/fan rays at reduced damage, aiming for roughly 1.5–1.8× single-target output when all rays connect, rather than automatically giving 3×. Preserve their coverage advantage.

Delay the strongest combinations, not every interesting upgrade. One candidate: make explosive rounds enter the pool at Wave 10 while keeping homing or piercing as early alternatives. Show eligibility in the blueprint description. With only three elite picks, avoid prerequisites that routinely prevent players completing any coherent build.

The code uses integer health and fixed gameplay damage callbacks. Fractional satellite-shot damage requires a deliberate payload change through the firing signal and hit callback, plus float health or a damage accumulator. Merely attaching a fractional property to a projectile will not change the current ordinary-hit damage path. Preserve fractional carry so small hits do not round back to full damage or disappear.

### 4. Preserve demanding encounters

Build difficulty through readable attack combinations, positioning and priority targets. Keep light enemies quick to destroy; tune heavy enemies and bosses separately. Preserve the threat budget and rolling light-enemy guarantee while testing compositions. Increasing the on-screen cap is not a substitute for meaningful attacks and can undermine readability.

Use pods as a visible strategic advantage: destroying them already removes volley contributions. Repair core reduction so it applies consistently across hit sizes, then test whether it adds a useful target decision. Do not stack stronger pod armor and new attenuation before measuring each separately. Keep reflection rewarding, since aiming a counterattack requires a deliberate defensive action.

## Damage attenuation: conditional second pass

Do not attenuate ordinary enemies or reduce player damage based on how well the player is doing. Start with the preceding deterministic rules. Add boss-only protection if optimized builds still eliminate meaningful phases.

If needed, test a monotonic soft cap on sustained player DPS:

`effective_DPS = raw_DPS` when `raw_DPS <= knee`

`effective_DPS = knee + 0.5 * (raw_DPS - knee)` above the knee.

For a knee of 10, raw DPS of 5/10/20/40 becomes 5/10/15/25. Stronger builds always deal more; doubling beyond the knee still matters. The knee must come from observed encounter damage, not these example values. This is our proposed curve, not Warframe's formula.

Use one shared accounting path for core damage from direct shots, drones, splash, orbitals and reflection. Resolve attacks within the same simulation step without letting call order arbitrarily favor a weapon. Maintain fractional damage, and reset history on pause, retry, boss death and encounter change. Smooth over a short active-time window if estimating sustained DPS; compare sustained fire, burst-rest-burst and low-frequency heavy hits so estimator recovery cannot become a dominant exploit. Decide explicitly whether a skillful reflected hit gets a limited exception, and test it against dense volleys.

A hard per-second ceiling makes every strong build converge on the same kill time. Hidden armor that increases with measured player power cancels progression. Avoid both. If attack phases vanish, first consider a short readable transition with hostile-shot cleanup, but count any protected time in the session budget; do not force long waits merely to showcase every pattern.

## Budget a complete run

Suggested central budget, including ordinary choices but excluding deliberate long pauses:

| Portion | Budget |
| --- | ---: |
| 16 ordinary waves, averaging 35 seconds | 9 min 20 sec |
| Boss 5 / 10 / 15 / 20 | 45 / 55 / 65 / 80 sec |
| Reward choices, route choices, transitions and ending | 90 sec |
| Total | 14 min 55 sec |

Allow strong runs to finish near 10–12 minutes and cautious successful runs near 18–20. This is a distribution target, not a mandatory timer or guaranteed completion. Challenge modifiers and Endless should have separately communicated expectations. Count accepted continues in ordinary session duration.

Current baseline quotas and spawn intervals yield a simplified ordinary-wave supply estimate of `sum(quota * interval / collected_orb_units_per_spawn)`: 10.61 minutes at 0.6 units/spawn, 6.36 at 1.0, or 5.30 at 1.2. This sensitivity calculation assumes stationary yield, no blocked spawns, immediate kills/collection, no carry-over and no formation overhead. It is neither a lower bound nor an observed completion time. Later tanks/snipers can yield multiple guaranteed units, whereas missed drops and enemies escaping lower collection. Measure yield per sector and route.

Boss core HP is approximately 224 / 331 / 352 / 478 at Waves 5/10/15/20 without the armored-fleet modifier. Baseline firing is 4.55 one-damage shots/second: ideal continuous core-hit times are about 49 / 73 / 77 / 105 seconds, excluding pods, dodging, reflections and temporary powers. Later builds may cut those dramatically. Retune HP from actual hit DPS and desired phase exposure, not emitted bullets.

Retain performance-based wave advancement initially. Adjust quotas/drop value against measured throughput after healing is separated. If highly optimized builds make waves too short, test a modest encounter-duration floor with continuing threats and a clear objective; avoid empty waiting once collection finishes. If weak runs stall, examine escape losses, missed pickups and threat-admission blocks before adding generic health scaling.

## Validation and implementation order

1. Capture a natural baseline using [opening metrics](../systems/opening_metrics.gd). The current implementation records wave timings, all boss completions and upgrade offers/installations; the older [Expedition playtest document](expedition-playtest.md) understates its later-boss coverage. Add victory/session completion, damage dealt by source, repairs, lives over time, orb yield, blocked spawn slots and phase durations.
2. Change healing capacity alone. Then normalize fire-rate mathematics and move the final clamp. Keep source balance values centralized and update UI descriptions.
3. Tune first-reward output and synergy eligibility. Compare precision, coverage and reflection builds, including builds assembled from imperfect offers.
4. Tune ordinary-wave quotas and boss HP to the session budget. Test attenuation only if excessive burst persists.

Start with a small diagnostic sample: three hulls × base/full permanent progression × two experience groups = 12 conditions; seek three unassisted attempts each, rotate all route combinations, and retain failures. This is 36 exploratory attempts, not statistically conclusive proof. Repeat across routes and input devices where results suggest a problem. Separate first-clear economy from repeat runs, and record selected build and offered alternatives.

Acceptance hypotheses: most successful standard sessions fall within 10–20 minutes; experienced-player median is about 14–16; no permanent purchase is required to clear; first-reward builds do not routinely bypass the second boss's meaningful attacks; optimized builds kill bosses noticeably faster than weaker builds; healing does not erase repeated positioning errors. Define a desired win rate after observing both experience groups rather than inventing one now.

Use focused implementation checks for final firing interval, capped repair, retained wave progression at full health, fractional damage equivalence across hit sizes, boss accounting, reset behavior and unchanged reward settlement. Existing scripted Expedition checks verify progression contracts; they cannot establish challenge or real session length.


## First implementation pass

Implemented October 2, 2026:

- Orb repair stops at loadout-based hull capacity and discards progress at full hull. Wave progress remains independent. Allocation and Hull Plating add one capacity and repair one life. Continues retain their original starting-life restoration contract; capacity persists across a continue.
- Fire-rate bonuses now add to frequency. Rapid Fire and Overclock each grant 2× frequency, combine up to 3×, and respect the final 0.05-second interval floor.
- Explosive Rounds enters the eligible reward pool at boss 10. The blueprint catalog remains available for collection/completion checks.
- HUD shows current lives/capacity, and allocation, module, supply and blueprint descriptions reflect the new rules.

This pass preserves ordinary quotas, boss HP, integer projectile damage, Twin/Spread output and existing armor reduction. Those need natural-run measurements or a separate damage-payload change before retuning. The 10–20 minute target is still unverified.

Validation: Godot 4.6.3 passed all ten standard smoke scenes and five focused scenes (gameplay refinement, reflection mastery, recovery decisions, cohesion, developer commands). The Expedition matrix passed all 24 assisted hull/route/progression journeys. A first attempt exposed empty early reward drafts in the test's direct reward invocation; eligibility now gates only explicitly staged modules, and the matrix rerun passed. Tests emit resource-cleanup diagnostics at headless shutdown. These checks do not measure natural completion time or player difficulty.
