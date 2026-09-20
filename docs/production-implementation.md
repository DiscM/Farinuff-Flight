# Production implementation ledger

Started September 16, 2026 against `bbc6e821` and the existing local copy edits.
Source: [production readiness plan](production-readiness-plan.md). Milestone
acceptance remains separate from completing an engineering slice.

Windows is the working release target. Linux/Deck and macOS support remain
unclaimed until their packages and hardware journeys have been tested. Current
scope is the Wave-20 Expedition, optional Endless, three hulls, and 13 upgrades.

| Slice | Milestone | Deliverable | Status / remaining evidence |
| --- | --- | --- | --- |
| 01 — Repeatable baseline | M0 | Disposable test profiles; frontend, progression, boot, reward, and backdrop checks in CI | Implemented; 20/20 scenes pass locally |
| 02 — Inspectable release package | M0 / M3 | Pinned engine/templates, Windows export, package inventory, checksums, revision and logs | Implemented; clean-checkout, fresh-cache Windows export passes locally; Windows execution and GitHub run pending |
| 03 — Independent sound controls | M1 | Master, Music, SFX, and UI routing, saved controls, regression check | Implemented and tested; listening/mix approval remains external |
| 04 — Combat clarity | M1 | HUD occlusion and bright-backdrop comparison in movement at 720p/1080p | Implemented and captured; fresh-player readability acceptance pending |
| 05 — Opening presentation | M1 | Art reference, bundled licensed typography/icons, reflection teaching and first-upgrade timing | Implemented; 24 review captures plus practice, local timing tool verified; eight fresh-player sessions and visual approval remain open |
| 06 — Whole Expedition | M2 | Hull/route/build matrix, boss phases, economy, ending and Endless validation | Assisted matrix and settlement/dossier fixes implemented; natural runs, balance, boss readability, and victory music remain open |
| 07 — Player trust | M3 | Save fault/rollback tests; local settings separation; graphics/HUD/input/accessibility options | Implemented with save recovery, independent settings, display/HUD/toggle-fire controls and interruption handling; Cloud remains off; exported-package and physical-device acceptance open |
| 08 — Candidate performance | M3 | Repeatable load scenario and release-package hardware measurements | Queued; Windows minimum-spec hardware required |
| 09 — Demo and store | M4 | Tested demo policy, representative capture pack, accurate store copy and disclosures | Queued after opening acceptance; Steam account and asset permissions unresolved |
| 10 — Launch and support | M5 | Candidate promotion/rollback rehearsal, support route and known issues | Queued after release-candidate acceptance; no publication authorized or performed |

## Verification record

September 16, 2026, Godot `4.6.3.stable.official.7d41c59c4`, local macOS:

- `python3 tools/check_native_transition.py`: pass, 344 resources, 11 GLBs,
  13 upgrade modules.
- `python3 tests/check_native_completion.py`: pass, 375 file-only assertions.
- `python3 tests/test_smoke_runner.py`: pass, 8 process-boundary tests.
- `python3 tests/test_release_tools.py`: pass, 7 package-gate tests, including
  corrupt payloads, missing remap targets, and unlisted audio.
- `python3 tools/run_smoke_tests.py --godot "$GODOT_PATH"`: **20/20 pass**;
  logs retained in `.godot/production-smoke-logs/` for this session.
- `python3 tools/export_release.py --godot "$GODOT_PATH" --allow-dirty
  --output builds/production-readiness-fresh-windows`: pass from an empty import
  cache, **3,637 PCK entries** with hashes and remap targets verified. This is a
  local development artifact, accurately marked dirty; it is not a promoted
  release. GitHub's release workflow requires a clean checkout.
  The local invocation used `--git /Library/Developer/CommandLineTools/usr/bin/git`
  because the system Git shim is blocked by an unaccepted Xcode license.
- A second export from a separate, clean checkout of implementation commit
  `da533e57` also passed without `--allow-dirty` or an existing import cache.
  `builds/production-clean-windows/build.json` records `dirty: false`, the exact
  commit and engine. All **3,637 package entries**, remap targets, and **12 artifact
  checksums** verified; the package manifest reports no errors. This establishes
  local reproducibility, not Windows runtime or GitHub Actions acceptance.
- The export now uses the `res://Planets/` alias consistently. The previous
  nested-project paths worked in the source tree but were absent from the PCK.
- The shipping-audio inventory retains 10 preloaded cues and removes 170 unused
  preview samples. Full license documents ship beside the executable; permission
  checks in `THIRD_PARTY_NOTICES.md` remain open.
- Live Metal/Forward+ inspection used a disposable profile. Captures are in
  `.godot/production-captures/`: HUD occlusion and boss backdrop at 720p/1080p.
  The projected-craft test covers camera movement and unchanged combat bounds.
  This is a four-shot engineering comparison, not the eight-shot art approval set.
- Separate Standards and Spec reviews found the remap and unused-audio gaps;
  both were corrected and re-reviewed without remaining actionable findings.

The headless suite still logs existing ObjectDB/resource teardown warnings and
dummy-renderer shader RID diagnostics. Malformed-save and invalid-navigation
fixtures also deliberately emit errors; no GDScript errors occurred in the final
suite. These diagnostics need triage in the repeated-run memory work, rather than
being treated as proof of stability. The exporter permits only the specific
dummy-shader shutdown diagnostic and rejects other import/export errors.

Automated checks do not establish art quality, fresh-player comprehension, a
reviewed audio mix, hardware performance, asset permissions, or storefront
approval. No Windows executable was run on Windows during this macOS session.

### Opening presentation verification

September 16, 2026, same pinned engine and local macOS environment:

- Bundled Barlow body/display fonts and their SIL OFL, with source revision and
  checksums. Added 24 original SVG symbols for 31 catalog/currency IDs.
- [Opening reference](../design/production-opening/README.md): eight surfaces at
  1080p, 720p, and 720p with larger menu text, plus the reflection lesson. These
  are staged engineering captures, not visual acceptance or natural playthroughs.
- `python3 tools/run_smoke_tests.py --godot "$GODOT_PATH"`: **20/20 pass**;
  session logs in `.godot/opening-full-suite/`. No smoke scenes were added.
  The existing combat-readability scene also passed after the final HUD changes.
- Native transition inventory: **346 resources, 11 GLBs, 13 upgrades**, pass.
  Native completion assertions **375**, smoke-runner tests **8**, and release
  tool tests **7**, all pass.
- Fresh-cache Windows development export: **3,697 PCK entries** verified, no
  manifest errors, all artifact checksums valid. All three bundled fonts and
  the OFL are present; the loose OFL matches the source. This package records
  the dirty working tree and is not a promoted candidate.
- A second fresh-cache export from a clean checkout of `506fad4e`, including
  the pinned PixelPlanets submodule, passed with **3,697 entries** and **13
  artifact checksums** verified. `builds/production-opening-clean-windows/`
  records `dirty: false`; the package includes the font remaps, font data, and
  full OFL. Windows runtime testing and GitHub execution remain pending.
- Opt-in [opening timing](opening-playtest.md) verified through actual movement,
  shots, reflection, a reflected hit, and committed upgrade installation.
  Practice reports its actual hull and initial wave. Truncated log records are
  skipped with a warning while earlier observations are retained.
- Standards and Spec reviews completed; timing and practice-copy findings were
  corrected and re-reviewed without remaining actionable findings.

These input-driven checks do not establish human pacing. Wave thresholds and the
first-installation schedule are unchanged. The eight-player M1 cohort, listening
review, and visual approval remain required.

### Whole Expedition engineering verification

September 16, 2026, same pinned engine and local macOS environment:

- Extended the existing Expedition smoke scene with 24 assisted production
  journeys: three hulls, four route combinations, and base/full-meta profiles.
  Twelve return home; twelve continue through the Wave-25 Harbinger. No smoke
  scenes or CI entries were added.
- Fixed score records lost on Return Home or living-run abandonment. Final
  settlement now saves the record and remains safe to repeat. Fixed route
  dossiers that incorrectly fell back to the Swallowtail name.
- The journeys cover reward/allocation commit guards, all five boss identities,
  phase cleanup, courier success/timeout, route fragments, simultaneous final
  boss death and continue, both endings, Endless build retention, and settlement.
  All 13 upgrade IDs appeared among the recorded installations.
- Full existing smoke suite: **20/20 pass**, including **24/24 journeys**;
  session logs in `.godot/expedition-full-suite/`. Native inventory **347
  resources, 11 GLBs, 13 upgrades**; completion assertions **375**, runner tests
  **8**, and release-tool tests **7**, all pass. Existing teardown diagnostics
  remain; no GDScript errors occurred in the final suite.
- [Seven staged captures](../design/production-expedition/README.md) show each
  boss's third phase with reduced flashing, the selected Interceptor dossier,
  and the ending. Live AI ran for the boss captures; god mode and staged health
  make these review references, not natural runs or readability acceptance.
- [Protocol and result records](expedition-playtest.md) separate the repeatable
  engineering evidence from the hull/build/economy playtests still required.
  M2 remains open, including the planned victory music resolution and mix review.
- Standards and Spec reviews finished without remaining actionable findings.
  The courier check was corrected to drive timeout processing and assert actor
  cleanup instead of directly cancelling the objective.

### Player trust engineering verification

September 19, 2026, same pinned engine and local macOS environment:

- Progress schema 7 excludes all preferences and bindings. Version-1 local
  settings migrate before legacy progress is replaced; the two files then save
  independently with backup, interrupted-write, and future-version protection.
  Failed migration reports that both settings and progression are unsaved.
- Added graphics quality, frame cap, VSync, independent combat HUD scale, and
  optional toggle fire. Loading, focus loss, active controller loss, reward
  completion, and OS-close confirmation preserve pause and clear held actions.
  Quit suspends continuation countdowns and defers end-screen focus changes.
- A failed final save keeps the game open with Retry Save or explicit Quit
  Without Saving. Both deterministic and live checks verified retry, settlement
  without duplicate credit, actual quit, and retained score/salvage on reopening.
- Final full existing suite: **20/20 pass**, including **24/24 assisted journeys**;
  command used `--timeout 240`, logs in `.godot/player-trust-final-suite/`.
  An earlier pass caught a motion fixture that pressed fire before observing
  neutral input; it now follows the production held-button contract. The earlier
  Expedition run exceeded 120 seconds while live GPU capture was also running.
  Final testing ran after capture stopped. No smoke scenes were added.
- Native inventory: **350 resources, 11 GLBs, 13 upgrades**; completion checks
  **375**, runner tests **8**, and release-tool tests **7**, all pass. Headless
  import passed without script errors. Existing headless teardown diagnostics
  remain; Metal exit also logged particle-shader/texture cleanup diagnostics.
  These are recorded for slice 08, not treated as evidence of memory stability.
- [Ten staged captures](../design/production-player-trust/README.md) show the
  largest HUD at four aspect/resolution combinations, large-text settings,
  quit confirmation, failed-save recovery, and newer-save protection. Captures
  and geometry checks do not establish cross-aspect combat fairness.
- [Storage and acceptance protocol](player-trust.md) records the decision to
  keep Cloud disabled, the remaining exported-package/physical-device checks,
  and deferred demo/session/localization decisions. [Validation record](validation/player-trust-2026-09-19.json)
  includes capture hashes and the live reopen result. M3 remains open.
- Standards and Spec reviews finished without remaining actionable findings
  after the migration, interruption, quit-retry, and deferred-overlay fixes.

## Next slice

08 — Candidate performance: establish a repeatable high-load scenario and record
frame-time, memory, startup, retry, and transition measurements from an identified
release package. Use that work to investigate the existing teardown diagnostics.
Windows minimum-spec measurements and physical-device acceptance remain required.
Run the M1 cohort and M2 natural-run protocol alongside engineering, and complete
the ending's music resolution. Milestones stay open until their evidence exists.

## External decisions and evidence

- Release owner: repository owner provisionally; confirm production ownership.
- Steam account, App ID, commercial terms and timing: unverified.
- SunGraphica pause textures and selected Shapeforms samplers: exact permissions
  remain unresolved in [third-party notices](../THIRD_PARTY_NOTICES.md).
- Fresh-player cohort, physical controller, Windows hardware, Deck: not available
  from this local macOS session.
- Keep active runs memory-only; measure run duration before choosing a
  suspend/checkpoint schema. Durable progress is now separate from local settings,
  but Cloud stays disabled pending conflict, multi-machine, and account testing.
