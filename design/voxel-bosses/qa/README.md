# Voxel Bosses — Godot validation

Validated in Godot 4.6.3 on September 20, 2026. Runtime materials use the production PixelPlanets shader, with the authored UV atlas, color factors and emission retained. No boss combat profile, attack definition, health timing, collider, attachment offset or reward policy was changed.

## Automated checks

The final corrected exports were reimported, then all five focused headless scenes exited successfully with their PASS sentinel:

- `voxel_boss_material_smoke`: six imported rigs, UV/texture/material contracts, variant-safe animated muzzle, independent pod hit feedback, synchronized attack motion, destruction/reactivation and fixed colliders.
- `native_completion_smoke`: native game graph and all five milestone boss variants.
- `boss_ai_smoke`: boss decision and telegraph contracts.
- `boss_patterns_smoke`: projectile pattern behavior, including section contribution.
- `boss_flight_smoke`: boss flight and combat behavior.

`tests/check_native_completion.py` passes 393 file-only assertions. The logs in this directory preserve the actual diagnostics. Dummy-renderer shader RID caches and some ObjectDB/resource teardown warnings remain at headless exit; these runs are passing checks, not warning-free logs. Import also reports the pre-existing nested PixelPlanets project directory.

## Rendered texture checks

`../godot/texture_visibility.json` contains 12 passing GPU comparisons on Metal/Forward+: six assets in production PixelPlanets and six in authored alloy. Each comparison renders the same frozen rig with atlas sampling on and off and counts changed pixels inside its asset crop. Every crop changes by 18,561–41,498 pixels. The four `style_*` images preserve both sides of the comparisons. The production gallery was visually inspected for fit, colored plates, seams, silhouette and reactor detail.

## Actual playfield checks

`../godot/gameplay_verification.json` records all five bosses in production Flight Practice. One boss at a time used its native wrapper scale, normal AI, real warning/release path and actual projectile pool. The player was stationary with practice invulnerability; no supplies, rewards or save progression were used. All five reached windup and attack, firing 5, 8, 12, 10 and 12 shots respectively. Both live pods entered windup with their hull. Tempest Core pod hit flash and destruction were also captured; the other pod stayed active.

`*_windup.png` and `*_attack.png` are the actual AI-driven frames. The first three bosses partly overlap the existing health panel because the boss camera follows the player. These honest encounter frames are retained. `*_presentation.png` are separately staged inspection images: the same native-scale actor with its held authored windup is placed below the HUD, with camera follow frozen for the capture. They show the assembled model and pods clearly and do not claim an AI-selected position. `pod_hit.png` and `pod_destroyed.png` show feedback and retirement in the live encounter.

All five silhouettes and assembled pods were visually reviewed in the native playfield. These are focused first-attack and integration checks, not full campaign balance playthroughs. Existing startup lint warnings were present; no runtime asset or shader errors occurred during the successful captures. Godot was stopped and the temporary MCP autoload removed when review finished.

## Reproduce

Run `scenes/voxel_bosses_review.tscn` for the gallery. Press A for windup/release, F for flash, R for rotation, S to switch material style and T to toggle the atlas. Run it with `-- --verify-boss-textures` on a rendered display for the GPU comparison receipt.

Run the five `res://tests/*_smoke.tscn` paths named above with the project Godot binary and `--headless --path <project>`. The optional `tests/voxel_boss_gameplay_capture.gd` helper is invoked against a warmed Flight Practice scene with `await load("res://tests/voxel_boss_gameplay_capture.gd").capture(get_tree().current_scene, index)` for indexes 0–4 in order. Its separate `presentation(scene, index)` method stages the inspection frame after practice setup.
