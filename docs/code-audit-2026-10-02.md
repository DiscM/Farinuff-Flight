# Farinuff Flight code audit — October 2, 2026

Reviewed revision: `d078323f2b55c5d43c99db893aa297af3e4ce163`.
Engine: `4.6.3.stable.official.7d41c59c4`.

## Fix validation — October 2, 2026

All six findings below have been addressed in the working tree:

- Re-exporting the current Blender source into a temporary delivery reproduced all eleven shipped GLBs byte for byte. Updated the source digest/size and refreshed static/Blender verification. Matching hashes are recorded in `assets/models/wayfarer_crescent/docs/source-export-verification.json`; runtime GLBs and textures were unchanged.
- `MetaProgression.settle_run()` updates milestone claims, lifetime statistics, and the wallet before one persistence operation. Failed writes retain the complete in-memory settlement for the existing quit-save retry, and GameManager's finalization guard prevents a duplicate award.
- Projectile sweeps use bounded recasts past non-damageable fields and logically inactive targets. Ignored-target exceptions last only for the current sweep so pooled reactivation remains eligible. Overlap handling uses the same logical-state check.
- Ship Upgrades suspends/restores background focus through ModalFocus, including unexpected removal of the panel.
- The smoke runner rejects unexpected engine errors. Intentional negative-test errors require the expected scene and test backtrace; specific known teardown errors are accepted only after the completion marker.

Regression coverage now includes multiple fields before a target, successive same-frame shots through destroyed tank armor and boss pods, reactivated ignored colliders, corrupt-primary settlement recovery, failed settlement-save retry/idempotence, and forward/reverse Ship Upgrades focus containment/restoration. Runner fixtures verify missing resources fail even with a completion marker, expected errors require attribution, and teardown exceptions are phase-specific.

Validation: **34 Python tests passed; 38/38 Godot extended scenes passed under the stricter runner; all three static resource/asset checks passed; Blender source/GLB verification passed.** Godot import reported no engine/script errors. Known shutdown diagnostics remain allowed and preserved. Full suite logs: `/tmp/farinuff-fix-logs/`; Python log: `/tmp/farinuff-fix-python.log`. Rendered gameplay and Windows execution were not part of this fix validation.

The remaining sections preserve the original audit findings and evidence.

The audit found six actionable issues: one failing CI/release prerequisite, one persistence consistency bug, two projectile collision bugs, one modal focus bug, and one false-positive test gate. The game has substantial runtime coverage, but its current green smoke results do not establish that engine resource loads succeeded.

The original audit reviewed the current project rather than a comparison with an earlier commit, and applied no gameplay fixes during the review itself. The pinned PixelPlanets submodule was initialized to make engine validation meaningful. Player saves were isolated throughout. Temporary reproduction scripts were removed from the working tree; the follow-up fixes and regression tests are described above.

## Findings

### 1. [P1] Crescent Harbor asset manifest fails the required CI check

Location: [build_manifest.json:233](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/assets/models/wayfarer_crescent/build_manifest.json:233), required by [smoke_tests.yml:27](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/.github/workflows/smoke_tests.yml:27).

`python3 tools/check_crescent_harbor.py` exits 1 with `SHA-256 mismatch: source/wayfarer_crescent.blend`. The manifest expects `4080c0449433c906a670334295a9c0d49ba04b82f1fd14a1ca55edea28e86110`; the checked-out source hashes to `10a20b1947c0b29fadf5b29c6f64d2d86b651eb5fe6eba65a995e10e6e52a191`. An independent hash comparison found this mismatch among the manifest's output records.

Impact: the smoke workflow stops before engine validation, and the release-candidate workflow depends on that workflow. This is a reproducible delivery-integrity failure; it does not prove that the shipped GLB is visually or functionally broken.

Fix: establish which Blender source belongs to the accepted export, then regenerate the delivery manifest from that source/export set, or restore the corresponding source. Avoid updating only the digest without checking source/export correspondence. Rerun the complete asset validator.

### 2. [P2] Milestone claims are saved before their salvage payment

Location: [game_manager.gd:525](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/autoloads/game_manager.gd:525), [meta_progression.gd:360](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/autoloads/meta_progression.gd:360).

`finalize_run()` calls `claim_first_clear_milestones()`, which immediately persists claimed IDs. It next persists lifetime statistics, and only afterward credits and persists salvage. The individual JSON writes are guarded, but these related state changes do not form one transaction.

Reproduction scenario: finish a first run clearing Wave 5. A crash or failed write after the claim/stat writes leaves the milestone claimed and its 50 salvage unpaid. Even a successful finalization leaves the backup representing the preceding statistics write: it contains the claimed ID and the pre-award wallet. If the primary later becomes unreadable, backup recovery permanently loses the one-time reward.

Fix: put the milestone IDs, run statistics, and wallet credit into a single settlement operation and persist that complete state once. Define how a failed write affects retry/idempotence. Test interruption and primary-file corruption around settlement, including the backup's internal consistency.

Godot 4.6.3 confirmed this with an isolated profile: after finalizing at Wave 6 with score 0, the primary held wallet 65 and claimed milestones `[5]`, while the backup held wallet 0 and the same claims. Deliberately corrupting the primary recovered wallet 0; claiming Wave 5 again returned 0. Evidence: `/tmp/farinuff-audit-settlement.log`. The 15 wave salvage was also lost in recovery, but the additional defect is that the 50 milestone salvage cannot be earned again.

### 3. [P2] Plasma fields hide valid targets from projectile sweeps

Location: [projectile_3d.gd:363](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/entities/projectiles/projectile_3d.gd:363), sweep continuation at [projectile_3d.gd:333](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/entities/projectiles/projectile_3d.gd:333).

The projectile sweep takes the first collider. `_report_hit()` deliberately ignores non-damageable plasma fields, but does not exclude the field and recast. Only an already-recorded piercing hit triggers the existing continuation. The projectile therefore moves through the full motion segment without testing an enemy behind the field.

Godot reproduction: place a field at z=0, an enemy at z=2, and sweep a player projectile from z=-5 to z=5. Result: `PLASMA_SWEEP hits=0 active=true`. The field was the first collider; the enemy received no hit.

Fix: give ignored colliders a bounded continuation path that excludes them and tests the rest of the motion. Keep collision exceptions/reset behavior safe for pooled reuse. Test an enemy within/behind a field and multiple ignored contacts. Godot documents immediate updates and collision exceptions in [ShapeCast3D](https://docs.godotengine.org/en/4.6/classes/class_shapecast3d.html).

### 4. [P2] Destroyed armor can absorb more shots during the same physics frame

Location: [projectile_3d.gd:356](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/entities/projectiles/projectile_3d.gd:356), [tank_plate_3d.gd:90](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/entities/enemies/tank_plate_3d.gd:90).

Armor immediately clears its logical `is_active` state, while collider removal is deferred. Projectile hit handling checks the projectile's logical state, but not the target's. Another shot in that frame can hit the stale collider, emit a hit whose damage handler returns early, and despawn without damaging a live target. Boss pods and regular enemies also use deferred collider removal.

Godot reproduction against an actual TankPlate3D: perform two sequential sweeps in one physics frame. The first destroys the plate; both projectiles become inactive. Output: `DEAD_PLATE_SWEEP first_active=false second_active=false plate_active=false`.

Fix: reject logically inactive damage targets before committing a hit and continue the sweep past their remaining colliders. A guard alone would still hide valid targets behind the stale collider. Add a volley regression against armor and boss pods.

### 5. [P2] Ship Upgrades lets keyboard focus escape into covered pause controls

Location: [pause_menu.gd:200](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/ui/pause_menu.gd:200).

`_on_build()` mounts BuildReference without suspending the pause menu's controls or constraining the panel's focus cycle. `_on_settings()` already uses the project's ModalFocus helper for this purpose.

Godot reproduction: Pause → Ship Upgrades → Tab. Focus moves from the panel's close button to the covered Resume button; later steps reach Restart, Settings, and End Run. Enter can invoke those background actions. The runtime focus query returned `.../PauseMenu/LeftDock/MenuButtons/ResumeWrap/Button` as the close button's next focus target.

Fix: apply the existing modal focus suspension/restoration helper and constrain forward/backward traversal. Test every pause overlay with Tab, Shift+Tab, controller navigation, accept, and cancel. Godot's [keyboard/controller navigation guide](https://docs.godotengine.org/en/4.6/tutorials/ui/gui_navigation.html) explains focus modes and explicit neighbor paths.

### 6. [P2] Smoke runner accepts unexpected engine errors as passing tests

Location: [run_smoke_tests.py:110](/Users/steve/.codex/worktrees/b922/Farinuff-Flight/tools/run_smoke_tests.py:110).

The runner rejects nonzero exits, `SCRIPT ERROR:`, timeouts, and absent completion markers, but accepts all `ERROR:` messages. A fixture that prints `ERROR: Failed loading resource: res://missing.glb` followed by `POOLING_SMOKE_PASS` exits successfully and reports `Smoke tests: 1/1 passed`.

This also occurred in the initial engine run before PixelPlanets was initialized: missing planet loads were logged while native-completion and progression tests passed. That missing dependency was an environment setup issue, but the green result despite the load failure is a runner defect.

Fix: reject unexpected engine errors during the workload. Allow intentional negative-test diagnostics and known teardown messages explicitly, ideally with test/phase attribution. A blanket rejection would break existing corruption and invalid-navigation tests; a blanket allowance hides real failures. Add runner fixtures for missing resources, expected negative-test errors, and shutdown-only diagnostics.

## Coding practices and architecture

These are maintenance recommendations, not additional confirmed bugs or mandatory engine rules.

| Area | Observation | Recommendation |
| --- | --- | --- |
| Module responsibilities | `basic_enemy_3d.gd` has 1,112 lines and combines movement, combat states, maneuvers, defense, rewards, lifetime, and presentation. `player_3d.gd` has 1,060 lines. | Extract one cohesive responsibility at a time, starting with damage/defense and weapon or maneuver policy. Keep actors responsible for their scene and lifecycle. Preserve existing behavior tests during extraction. |
| UI boundaries | `hosted_menu_page.gd:42` chooses the first PanelContainer by tree order and line 86 accesses `_skip_button`. | Give hosted menus explicit content/actions accessors or scene references. This reduces coupling to private fields and incidental scene layout. |
| Modal policy | Settings and Ship Upgrades implement different focus behavior. | Make one shared modal mounting operation own focus suspension, restoration, duplicate prevention, and input containment. The confirmed focus defect is evidence for this extraction. |
| Persistence boundaries | Atomic file replacement is present, but a single reward is spread over multiple saves. | Treat a gameplay settlement as the persistence boundary; make completion and failure visible to callers. |
| Save schema | Selection sanitization checks ownership without checking the appropriate catalog. Imported unlock levels are not bounded to catalog maxima. | Validate known IDs, category membership, and maximum levels when loading. This is robustness against malformed or obsolete saves, not a demonstrated normal UI path. |
| Typing | Sensitive actors have useful type annotations; catalog/state APIs still pass untyped dictionaries and strings. | Introduce typed snapshots/resources or typed dictionaries at stable boundaries. Keep JSON decoding as a validated boundary rather than assuming decoded data is trustworthy. |
| Formatting | Naming and tabs are generally consistent, but many long conditions/declarations and some tightly spaced methods make large files harder to scan. | Adopt documented formatting defaults incrementally when touching files: consistent member order, two blank lines between functions, and wrapped long expressions. Avoid a repository-wide cosmetic rewrite during bug fixes. |
| Performance | Pools, bounded caches, shared material conversions, instance uniforms, and MultiMesh stars are appropriate existing choices. Projectile peak accounting scans checkouts per shot; orbitals repeatedly build group arrays. | Profile these paths in a rendered dense-combat workload before optimizing. Headless timing cannot establish GPU cost or shipping frame rate. |

The preferred direction is small scene components with explicit dependencies and typed public boundaries. Godot's [scene organization guidance](https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html) discusses self-contained scenes and dependency management. Its [static typing guide](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html) describes error detection and improved editor support.

Use Godot's [GDScript style guide](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_styleguide.html) for GDScript and [PEP 8](https://peps.python.org/pep-0008/) for Python tooling. Both favor consistency and readability; Python indentation rules should not be transplanted into GDScript. Fowler's [code-smell guidance](https://martinfowler.com/bliki/CodeSmell.html) is useful for identifying places to investigate, but file length or duplication alone does not prove a defect. The extraction recommendations above are reviewer judgments grounded in the current responsibilities and coupling.

## Scope and validation

Source review covered combat/player/enemy lifecycles, projectiles and collision layers, boss attacks and destructible sections, pools, hazards, effects and material conversion, projection/cameras, saves/migrations/preferences, progression/campaign settlement, run recovery and transitions, home-port services, practice, UI focus/input, resource loading, export/package checks, CI workflows, and existing regression coverage. Reviewed project settings and documentation against Godot 4.6 references. This is broad source inspection with deeper review of state/lifetime boundaries; it is not a claim that every asset or every source line was independently verified.

Validation performed:

- Python tooling: 31 tests passed.
- Native resource/scene reference checker: passed.
- Home-base asset checker: passed.
- Crescent Harbor asset checker: failed on the source hash described above.
- Godot staged import: exited 0 without engine/script errors after initializing the pinned dependency.
- Full 38-scene extended headless suite: 38/38 passed after dependency initialization. Log review found no script errors or unexpected workload engine errors; intentional negative-test and teardown diagnostics remained.
- Additional isolated Godot reproductions: milestone backup inconsistency, both projectile findings, and the BuildReference focus escape confirmed.
- Smoke-runner process fixture: unexpected resource-loading error accepted as success.

Engine tests use temporary projects and disposable user profiles. Expected negative-test errors and teardown resource/ObjectDB/shader diagnostics remain in logs. They are not equivalent to a clean memory-leak audit. The existing production journey tests explicitly use assistance; their success establishes progression paths rather than combat balance.

Evidence logs are in `/tmp/farinuff-audit-final-logs/`; projectile reproduction and harness are in `/tmp/farinuff-audit-logs/`; UI reproduction is `/tmp/farinuff-ui-audit.log`; settlement reproduction is `/tmp/farinuff-audit-settlement.log`; Python output is `/tmp/farinuff-audit-python.log`. These local temporary paths may be cleaned by the operating system.

No rendered manual playthrough, Windows export execution, target-device performance measurement, or third-party asset permission review was performed. Those remain separate release-acceptance tasks.

## Recommended order

1. Reconcile the asset source/manifest and make the required CI gate pass.
2. Make reward settlement atomic and tighten the smoke runner's error classification.
3. Fix ignored/inactive sweep continuation and Ship Upgrades focus containment, with focused regressions.
4. Re-run the existing suite, then exercise an unassisted rendered run and the Windows candidate on target hardware.
5. Refactor the demonstrated boundaries incrementally and profile dense-combat hot paths before optimizing them.
