# Enemy art and attack animation sweep

October 2, 2026. Shipping native 3D character assets were inspected, expanded and exercised through the production combat systems.

## Asset inventory and findings

The live regular-enemy scenes use `assets/models/voxel_frontier/meshes`, including the Fast hull shared by Courier. The five bosses and their detached weapon pods use `assets/models/voxel_bosses/meshes`. Older `assets/models/animated` and mockup models are historical sources, not the shipping enemy appearance. No new geometry or external asset license is needed.

All 11 live model files already had a four-bone rigid rig, atlas texture, sockets, and cruise/hit/windup/attack clips. Boss poses differed by hull, but each boss used the same warning/release for every attack family. Ordinary archetypes also reused generic anticipation/release across their specialized actions. That concealed the distinction between a charge brace, a mine deployment, a broad radial volley and a precision rail shot.

## Changes

Added 64 clips across the live models: nine each on the five bosses and their weapon-pod asset, plus two each on the five regular enemy hulls. Bosses now have 13 clips apiece; regular hulls have six.

| Hull | Attack articulation |
| --- | --- |
| Assault Commander | Inward aerodynamic armor lock for charge; broad slam brace; weapon-bank volley opening; reverse-sweep alternate volley |
| Iron Bulwark | Compact charge brace, wide heavy slam, opening firing banks, reversed armor-bank alternate volley |
| Tempest | Swept vanes for charge; wide impact brace; counter-sweeping primary and reverse-sweeping alternate volleys |
| Void Harbinger | Contracted crown for charge; wide slam anticipation; claw unfurl for primary fire; reversed crown contraction for alternate fire |
| Tempest Core | Closed propulsion brace; wide impact petals; opening aperture/deep weapon recoil; reversed aperture sweep for alternate fire |
| Weapon pod | Smaller versions of each family brace/recoil, synchronized only while the pod is active |
| Basic | Folded charge anticipation and thrust release |
| Fast | Inward phase-dash brace followed by a rapid reverse unfold |
| Bomber | Payload-bay opening and mine/bomb deployment impulse |
| Tank | Broad radial-fire brace and bank recoil |
| Sniper | Rail extension/steady brace followed by barrel recoil |

Each boss also has a reactor/panel phase-shift sequence. All poses are authored in `tools/enemy_attack_motion.py` and exported into the existing editable Blender sources. The incremental builder preserves geometry and rig binding; full original rebuild recipes also include the new clips.

The combat executor selects the correct family at commitment, holds its warning pose, releases it at the gameplay event, and fits projectile recoil to burst spacing or charge motion to charge duration. Alternate projectiles select a separate clip. The boss phase state triggers phase-shift articulation. Animations never dispatch damage, choose attacks or alter collider transforms. Hit feedback cannot replace custom warnings or phase shifts. Cancellation resets held poses; recovery preserves the final recoil.

Regular scenes now declare their archetype explicitly, so their specialized clip selection also works when instantiated outside the encounter director. Bomber, Tank and Sniper emission functions trigger the corresponding specialized releases. Generic clips remain available for tactical maneuvers and legacy integration.

## Verification

- `tools/audit_enemy_attack_assets.py`: all 11 live files pass exact geometry/UV/weight/index preservation, palette preservation, embedded-texture, four-bone, socket and nonstatic-animation checks against the pre-change Git assets. Results: [asset audit](../design/attack-motion/asset-audit.json).
- Existing package validators pass the new exact clip inventories and original topology/UV/texture/bone/socket policies. Boss validation checks all four family handoffs, release-to-neutral returns and phase endpoints. Current catalogs, manifests and validation files were refreshed. Existing delivery ZIPs remain historical snapshots.
- `enemy_attack_animation_smoke`: all five bosses × four attack families run through the actual executor; checks visible articulation, matching warning/release poses, synchronized pods, firing sockets, unchanged colliders, interruption and phase behavior. Also checks state-specific clips on all five regular hulls.
- Existing combat motion, boss AI, boss patterns, voxel boss materials, enemy flight motion, enemy FSM, maneuver attack and pixel-enemy material checks verify integration. The ten standard smoke scenes also pass, including the assisted Expedition journey matrix.
- GPU evidence uses Godot 4.6.3 Forward+ on Metal. The production gameplay scene is used with frozen actors and manually stepped production executors to capture repeatable poses. These are staged visual checks, not natural difficulty or full-session playtests. Test profiles are disposable. Renderer cleanup diagnostics occur at process shutdown; no script errors occur in passing checks.

## Rendered review

Each sheet has three columns: neutral, held anticipation, released impulse. Boss rows: Assault, Bulwark, Tempest, Harbinger, Core. Regular rows: Basic, Fast, Bomber, Tank, Sniper; those frames use a closer crop for detail. Phase columns show pre-transition and two moments in the phase sequence.

- [Primary volley](../design/attack-motion/volley.png)
- [Alternate volley](../design/attack-motion/alternate.png)
- [Charge](../design/attack-motion/charge.png)
- [Slam](../design/attack-motion/slam.png)
- [Phase shift](../design/attack-motion/phase.png)
- [Regular enemies](../design/attack-motion/regular.png)

Reproduce static audits with `python3 tools/audit_enemy_attack_assets.py`, `python3 tools/package_voxel_bosses.py --validate-only`, and `python3 tools/package_voxel_frontier.py --validate-only`.

Run focused gameplay checks with `python3 tools/run_smoke_tests.py --godot /Applications/Godot.app/Contents/MacOS/Godot enemy_attack_animation_smoke combat_motion_smoke boss_ai_smoke boss_patterns_smoke voxel_boss_material_smoke enemy_flight_motion_smoke enemy_fsm_smoke enemy_maneuver_attacks_smoke pixel_enemy_material_smoke`.

Regenerate rendered evidence with `python3 tools/run_attack_motion_preview.py --godot /Applications/Godot.app/Contents/MacOS/Godot`. Re-export authored clips with Blender's background mode and `tools/build_attack_motion_blender.py`.
