# Whole Expedition validation

Production slice 06, September 16, 2026. The engineering journey matrix is
implemented; **M2 is not accepted**. Natural playthroughs, encounter readability,
build viability, economy pacing, and the ending's musical resolution remain open.

## Reproduce the engineering check

Import with the pinned Godot 4.6.3 editor, then run the existing Expedition scene:

```sh
python3 tools/run_smoke_tests.py --godot "$GODOT_PATH" expedition_progression_smoke
```

The runner uses disposable save profiles. The existing scene now invokes
`tests/expedition_journey_checks.gd`; no additional smoke scene or CI entry was
created. Its 24 cases instantiate the shipping run and use the real reward,
allocation, route, retry, and ending controls. Ordinary waves advance through the
orb signal; boss damage is scripted, random encounter spawning is disabled, and
the player is invulnerable except for the deliberate retry case. Boss physics is
disabled during phase-transition assertions. These are assisted contract checks,
not successful natural playthroughs or measurements of player skill.

Every route starts at The Far Reach and ends at The Quiet Core:

| Sector 2 | Sector 3 | Swallowtail | Interceptor | Bulwark | Ending exercised |
| --- | --- | --- | --- | --- | --- |
| Iron Wake | Tempest Veil | Base + full | Base + full | Base + full | Return Home |
| Iron Wake | Echo Field | Base + full | Base + full | Base + full | Endless through Wave 25 |
| Ghost Lanes | Tempest Veil | Base + full | Base + full | Base + full | Return Home |
| Ghost Lanes | Echo Field | Base + full | Base + full | Base + full | Endless through Wave 25 |

Base profiles unlock only their selected hull; they have no permanent stat
upgrades, field supplies, or challenges. Full profiles have every permanent shop
item at maximum, three stocked continues, and the supply pod armed. All profiles
begin with zero salvage and unclaimed milestones. Full-profile spending is a
fixture, not evidence that players can afford that state. Story frequency rotates
through all three settings; reduced motion is enabled.

The matrix checks the selected hull model, lives and consumed supplies; all four
Expedition bosses and the Endless Harbinger; phase transitions and hostile-shot
cleanup; three unique upgrade installations and nine committed allocation
points; route dossiers and recovered fragments; two successful couriers and two
courier timeouts; Wave-20 victory; both ending choices; preserved Endless builds;
and single settlement of currency, high scores, and lifetime runs. One journey
kills the player on the same frame as the final boss and accepts a continue,
checking that the ending still resolves.

The [result records](validation/expedition-2026-09-16.json) preserve each case's
installed upgrades and settlement. Across the recorded run, all 13 upgrade IDs
were installed. Selection prefers one of the three build hypotheses when offered
and otherwise accepts an offered card. This does not guarantee a complete recipe
or establish its effectiveness in combat.

## Fixes established by these checks

- Returning Home or abandoning a living Endless run previously failed to save a
  new score record. Final settlement now records it, sharing the defeat path's
  existing record logic. Repeat settlement remains inert.
- Route dossiers read the selected ship's stat profile, which has no display
  name, and fell back to Swallowtail. They now read its catalog entry. The dossier
  assertion checks the ship row specifically, so the Iron Bulwark boss title
  cannot accidentally satisfy the Bulwark ship check.

These cases were observed failing before the corresponding fixes. The courier
failure case drives the controller's elapsed-time path and verifies sealing,
reference cleanup, actor removal, and rejection of another attempt in that sector.
It does not independently test the courier's offscreen escape movement.

## Economy evidence and limits

The fixed fixture awards 180 salvage from four Expedition bosses. Return Home
settles 846 salvage at 31,000 score; continuing through the Wave-25 Harbinger and
then abandoning settles 1,306 at 51,000 score. These include first-clear milestone
bonuses and the final score/wave awards, with only two courier kills and scripted
boss kills. They exclude ordinary combat and have no meaningful elapsed time.
They must not be used as salvage-per-minute or purchase-pacing estimates.

Use separate observations for repeat clears after milestones are claimed. A
first-clear windfall cannot establish the steady-state economy. No hull, upgrade,
orb threshold, shop price, or encounter parameter was retuned from these fixtures.

## Natural run protocol

Use the same hull/route matrix above, separately for base and fully unlocked
profiles. Record the build commit, profile state, platform, input device, display
size, flashing/motion settings, and active challenges. Run at normal speed without
developer assistance. Preserve failures and retries alongside clears; do not
replace unsuccessful samples with only successful ones.

For each session record:

- Wall and active time to each sector, boss, installed upgrade, and final ending;
  each boss attempt's start, phase changes, death or clear, and retry count.
- Every offered upgrade, selection, skipped alternative, and reason. Test the
  reflection, precision, and escort/coverage hypotheses in the production plan
  through actual interactions and opportunity costs.
- Losses by source, whether the cue was noticed, the nearest perceived safe
  route, and whether reflection or an upgrade changed the outcome.
- Starting/ending salvage, each reward category, milestone bonuses, time to the
  first useful purchase, and salvage per active minute. Keep base/full profiles
  and first/repeat clears separate.
- Courier success, failure, interference with the main fight, reward usefulness,
  and whether optional objectives feel mandatory for progression.
- Understanding of the ending, retained build on entering Endless, the reason
  to return home, and score/currency retention after quitting and reopening.

The [opening timing tool](opening-playtest.md) supplies initial milestones and
wave starts. It records only the first boss defeat and first committed upgrade;
later boss durations, offers, purchases, and damage sources need moderator notes
or recording. Do not infer missing observations from the assisted test log.

Repeat the reduced-flashing review with full builds and ordinary enemy pressure.
At 720p and larger menu text, verify route confirmation by scrolling and keyboard
or controller focus; the dossier capture alone does not show its full button.
The [review captures](../design/production-expedition/README.md) are staged macOS
frames, not an exported Windows or physical-controller acceptance run.

## M2 acceptance still required

The production owner must review representative natural runs for each hull and
route combination, boss phases at normal speed, build tradeoffs, and base-profile
clear viability. Check warning lead time from the actual camera, attack overlap,
armor/pod readability, phase cleanup, and recovery windows. No mandatory purchase
or dominant build has been ruled out by the current evidence.

The Wave-20 payoff and Hangar/Endless decision exist mechanically. The planned
victory music resolution is still missing: the ambient Music bed continues, and
the audio direction's `RUN.VICTORY` one-shot remains to be authored and integrated.
Listening approval, cue balance on speakers/headphones, and sampler permissions
also remain open. Do not close M2 on the strength of the engineering matrix.
