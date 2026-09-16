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
| 02 — Inspectable release package | M0 / M3 | Pinned engine/templates, Windows export, package inventory, checksums, revision and logs | Implemented; fresh-cache Windows export passes locally; clean Windows execution and GitHub run pending |
| 03 — Independent sound controls | M1 | Master, Music, SFX, and UI routing, saved controls, regression check | Implemented and tested; listening/mix approval remains external |
| 04 — Combat clarity | M1 | HUD occlusion and bright-backdrop comparison in movement at 720p/1080p | Implemented and captured; fresh-player readability acceptance pending |
| 05 — Opening presentation | M1 | Art reference, bundled licensed typography/icons, reflection teaching and first-upgrade timing | Queued; eight fresh-player sessions and approved captures required |
| 06 — Whole Expedition | M2 | Hull/route/build matrix, boss phases, economy, ending and Endless validation | Queued; representative human playthroughs required |
| 07 — Player trust | M3 | Save fault/rollback tests; local settings separation; graphics/HUD/input/accessibility options | Started: recovery followed by save, interrupted writes, and release guards added; remaining options, Cloud decision and physical-device work queued |
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

## Next slice

Continue 05: consolidate the existing art references, bundle licensed display
and body fonts, replace representative hull/upgrade emoji with coherent icons,
and measure the reflection-to-first-upgrade opening before changing pacing.
Then repeat the capture set at 720p/1080p and larger text size, and run the M1
fresh-player cohort. Later milestones stay open until their evidence is recorded.

## External decisions and evidence

- Release owner: repository owner provisionally; confirm production ownership.
- Steam account, App ID, commercial terms and timing: unverified.
- SunGraphica pause textures and selected Shapeforms samplers: exact permissions
  remain unresolved in [third-party notices](../THIRD_PARTY_NOTICES.md).
- Fresh-player cohort, physical controller, Windows hardware, Deck: not available
  from this local macOS session.
- Keep current saves session-scoped; measure run duration before choosing a
  suspend/checkpoint schema. Do not enable Cloud while display settings roam.
