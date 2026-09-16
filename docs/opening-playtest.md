# Opening playtest

Use eight fresh target players for the M1 cohort. Obtain consent before recording
a session. The timing tool records gameplay milestones locally; it sends nothing
over the network and collects no names or account identifiers.

## Run a session

Import the project once using the pinned Godot editor, then run:

```sh
python3 tools/measure_opening.py --godot "$GODOT_PATH"
```

This starts the real title-to-flight journey in a disposable save profile. The
player can use Flight School, retry, and install an upgrade normally. Close the
game to finish. Logs and `timings.json` remain under `.godot/opening-sessions/`;
the temporary save profile is then removed. The player's ordinary save is never
opened. Use `--output` to choose a new evidence directory. Keep the build commit,
platform, input device, and display/text settings with the moderator's notes.

For an exported candidate, use its executable with `-- --opening-metrics` and
retain the engine log. Use a separate OS account/profile for fresh-player saves.
Summarize an existing log with:

```sh
python3 tools/measure_opening.py --summarize path/to/godot.log
```

## Interpret events

Each flight or practice session has its own ID. Timing starts after gameplay
preparation, before the opening story. `wall_seconds` includes story, pauses,
reward deliberation, and retry screens. `active_seconds` counts the running
gameplay clock while unpaused and active. Neither measures title-menu dwell or
asset-loading time; observe those separately.

Events cover movement of at least 100 baseline pixels, first shot, first reflected
projectile, first reflected hit on an enemy, wave starts, boss spawns, first boss
defeat, upgrade offer, first committed installation, defeats, and closing the run.
The initial record includes version, hull, challenges, and practice status.

Missing milestones mean **not observed**, not zero seconds or a successful
completion. Separate practice from Expeditions. Reject assisted sessions and
non-1.0 `time_scale` from natural pacing estimates. God mode/generation overrides
mark subsequent events as `developer_assisted`; this cannot detect every possible
debug command, so also record moderator intervention. A hard process kill may
omit `run_closed`; earlier flushed engine-log events can still be inspected.

## Observe without coaching

1. Ask the player to start and learn the game. Record whether they can move, aim,
   and fire during the opening minute; do not suggest controls beyond the game.
2. Observe the first intentional reflection. Afterwards, ask what it did. A
   reflected shot in the log does not by itself establish intention or understanding.
3. Record first boss attempts, upgrade deliberation, committed installation, and
   whether the player notices a visible or behavioral build change afterwards.
4. Observe a defeat and retry. Record hesitation, lost focus, unclear consequences,
   and any interruption that makes a timing sample unsuitable.

Initial hypotheses: intentional reflection around 90 seconds and visible build
change around three minutes. Report individual timings and observed causes of
delay before considering a starter choice or changing the first five waves.
The M1 gate requires six of eight players to reflect deliberately and explain
its value, all eight to launch and retry, and an accepted visual reference set.

## Current evidence

Instrumentation and layout have been checked locally. Scripted actions used to
verify milestone reporting are assisted checks, not participant results. Natural
timings, mix approval, and the eight-player cohort remain pending. Pacing has not
been retuned on the basis of these engineering checks.
