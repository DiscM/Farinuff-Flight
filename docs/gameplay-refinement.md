# Gameplay refinement — September 21, 2026

This pass improves control responsiveness, the opening difficulty ramp, and milestone reward presentation. It builds on the existing Wave-20 Expedition and Wave-5/10/15 elite drafts.

## Flight feel

A fresh boost press is buffered for 120 ms. Pressing just before recharge finishes now starts the dash when it becomes available; a stale press expires. The same buffer can catch the third reflection during a dash. Starting a boost consumes the press, and pause/resume clears it. Holding boost still does not repeat it automatically.

The post-dash reflection-chain window increases from 180 to 240 ms. Three reflections are still required, only one follow-up boost is allowed, and dash distance, speed, invulnerability, and recharge are unchanged.

## Opening and sector pacing

Ambient enemies enter the roster in stages: Basic at Wave 1, Fast at Wave 2, Tank at Wave 3, Bomber at Wave 4, and Sniper at Wave 6. Authored formations obey the same introduction rules. This gives the opening a readable sequence of pursuit, interception, armor, and area denial before precision fire joins the second sector. Route weighting and threat admission remain in effect.

The first ambient spawn after a boss/reward boundary waits 2.5 seconds of active play rather than 0.5 seconds. Paused reward and story screens do not consume this interval. Ordinary wave transitions retain their existing cadence.

## Upgrade choices

The allocation screen now uses a framed panel and distinct stat rows, with per-point descriptions, pending life totals, and visible bonus percentages. Fire rate is accurately described as a reduction in base shot delay; thrust shows its additive speed bonus. These are allocation contributions, before ship, Hangar, and temporary modifiers.

Fire rate and thrust stop accepting points at level 10 (45%). Both the UI and game state enforce the cap, including unconfirmed points. Reset Choices refunds the entire pending allocation before confirmation. Confirmation remains single-use. A capped selection transfers keyboard/controller focus to an available stat; the final point focuses Apply Upgrades.

## Validation

Godot 4.6.3: all eight standard smoke scenes plus the new refinement scene passed in a clean, serial run (9/9). `combat_motion_smoke` also passed separately. The focused `gameplay_refinement_smoke` scene exercises early enemy selection and formation eligibility, sector timing, boost input expiry and consumption, chain limits, pause input reset, capped/pending stat allocation, refunds, and duplicate confirmation. The existing combat-motion and Expedition progression scenes exercise production actors and milestone journeys across hulls/routes. Test execution uses the existing disposable-profile runner.

The allocation screen is also inspected live using Forward+ at a logical 1280×720 viewport, including pending choices and capped stats. Automated and assisted journeys establish behavior and integration; natural player completion times and perceived difficulty still require playtesting. Existing ObjectDB/resource/RID teardown diagnostics remain visible in headless logs.
