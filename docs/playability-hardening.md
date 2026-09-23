# Playability hardening — September 22, 2026

This pass builds on the existing combat and campaign refinements. It addresses
reproducible input, training, recovery, and dense-combat failures.

## Controls

The first fire or boost press now works when switching between keyboard and
controller, including analog triggers and toggle fire. Releasing a button on
the previous device no longer changes the active device or clears toggle fire.
Pause and binding changes still require held actions to be released; a stale
boost press cannot survive a remap.

## Flight School

Live practice acknowledges movement and firing separately, remembers completed
movement, previews the three incoming shots for 0.75 seconds, and distinguishes
charging from the moment to reflect. The live chain cue asks for a second press
when the actual production player has earned a follow-up boost.

Training volleys start 170 baseline pixels away and turn inward near the edge.
Collection targets stay still, do not expire, and are brought back inside the
arena if the viewport changes. The practice wave meter agrees with the
twelve-point collection target. Completion offers **Prepare Expedition**, which
opens ship selection. Controller focus moves to that action after fire/accept
is released. Practice continues to consume no supplies and bank no salvage.

## Recovery and menus

Ending a recoverable run now uses the same confirmation and optional one-second
hold as ending a run from pause. Cancel keeps the run and its continues intact.
Nested Settings and Change Controls suspend focus on covered controls, restore
it on return, and clean up even if their containing page is removed.

## Projectile capacity

The enemy manager warmed 1,024 shots, but the shared pool retained only 512 per
scene. Firing beyond that could instantiate replacements without collision,
flight-space, and hit-signal setup. Prewarmed managers now declare their retained
capacity, warmup verifies the instances survived, and combat firing uses cached
instances only. Saturation safely rejects an extra shot. The generic default
of 512 and global retained limit of 2,048 remain in place.

## Verification

- Godot 4.6.3: **27/27 extended scenes passed**. The final practice-counter
  adjustment was followed by another practice and boss-practice regression run.
- Python tooling: **30 tests passed**. Resource/reference validation passed for
  **381 source/resources**; `git diff --check` passed.
- New input tests use real keyboard, pad-button, and trigger events. New recovery
  tests cover duplicate activation, interrupted holds, cancel/continue, depleted
  stocks, and forward/reverse traversal through nested dialogs.
- Native completion now exhausts and reuses all 1,024 enemy shots twice, verifies
  damage routing from the last shot, and checks saturation, pending returns, and
  an unexpected cache miss.
- Practice tests exercise real reflection/chain signals and orb actors, warning
  pause behavior, corner spawn distance, enduring/reachable supplies, completion
  focus, large text, and menu routing.
- Live Forward+ review used an isolated profile at a logical 1280×720 viewport.
  Held movement/boost inputs reflected all three training shots and chained the
  extra boost. Collection completion, 130% text/HUD, ship-selection routing, and
  recovery confirmation/cancel were also exercised with staged state.

The live checks and assisted tests establish behavior, not natural completion
time or audience enjoyment. Existing Godot shutdown ObjectDB/resource/RID
diagnostics remain in the logs; no GDScript errors occurred in the passing runs.
Player saves were not used for verification.

Local logs and presentation captures are under
`.godot/refinement-2026-09-22/`, with scene logs in `.godot/smoke-logs/`.
Run the full suite with:

```sh
python3 tools/run_smoke_tests.py --godot "$GODOT_PATH" --suite extended
```
