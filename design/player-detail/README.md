# Butterfly player detail

The Swallowtail, Morpho and Monarch hulls retain the same four-wing butterfly outline, antenna weapons and swallowtail engines. New geometry adds raised wing scales, branching spars, recessed seams, fasteners, cooling vents, concentric eyespot sensors, a framed canopy and a segmented energy spine.

Each hull has 6,660 triangles (previously 828), one skinned mesh, four rigid bones and its original seven or eight material slots. The seven muzzle, engine and upgrade sockets retain their exact exported local transforms. All seven clips remain available: cruise, hit, attack, boost, boost attack, upgrade and deploy.

The editable scenes are in `assets/models/animated/sources/farinuff_combat_motion.blend`. The detail is reproducible through `tools/detail_butterfly_player_blender.py`, called by `tools/build_combat_motion_blender.py` during a player rebuild. Existing static hulls provide the original silhouette and palette.

`detail-hero.png` is a Blender render for close inspection. Runtime models remain at their established gameplay scale.

Validation passed in Godot 4.6.3: `combat_motion_smoke`, `native_completion_smoke` and `home_base_smoke`. The `in-game-*.png` captures show the imported hulls and the Swallowtail boosting with elite upgrades. These inspection captures use a temporary 7-unit orthographic view; normal combat retains its 220-unit camera. `runtime-validation.json` records the imported geometry, bones and animation clips for all three hulls.
