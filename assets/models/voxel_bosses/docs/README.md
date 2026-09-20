# Farinuff Flight — Voxel Bosses 1.0.0

An original Blender-authored boss collection extending the game's Voxel Frontier art direction: five distinct animated capital enemies and a detachable Tempest section. Each hull uses stepped hard-surface construction, visible panel details, dark structural cores, role-colored armor, and controlled reactor emission.

Authored with Blender 5.2.1 LTS for the project's Godot 4.6.3 native 3D runtime. The source was rebuilt in an isolated directory and reopened successfully with seven scenes, a studio camera, all six rigs, and a packed atlas with a portable external path; see `design/voxel-bosses/rebuild_validation.json`.

## Collection

| Asset | Role | Visual identity |
| --- | --- | --- |
| `boss_assault.glb` | Assault Commander | Scarlet/ember attack craft |
| `boss_bulwark.glb` | Iron Bulwark | Violet/magenta defensive mass |
| `boss_tempest.glb` | Tempest | Storm cyan/blue emitters |
| `boss_void_harbinger.glb` | Void Harbinger | Spectral green crown |
| `boss_tempest_core.glb` | Tempest Core | Amber/gold command core |
| `tempest_section.glb` | Orbital Weapon Pod | Steel-blue armor, amber energy; independent animation rig |

Stable IDs, rig names, bones, clips, and socket bindings are specified in `assets/models/voxel_bosses/docs/catalog.json`. The generated `TECHNICAL_SHEET.md` provides measured geometry counts and dimensions. `validation.json` records the full audit, material factors, atlas hashes, clip durations, moving bones, and socket-to-bone bindings.

## Files and source organization

- `assets/models/voxel_bosses/meshes/`: six portable animated GLBs with the atlas embedded.
- `assets/models/voxel_bosses/source/voxel_bosses.blend`: editable Blender source with six isolated asset scenes and a collection studio.
- `assets/models/voxel_bosses/textures/voxel_surface_atlas.png`: copied original 256 × 256 Voxel Frontier atlas, making this pack independent of the earlier asset directory.
- `assets/models/voxel_bosses/docs/`: catalog, tile UV metadata, exact request, provenance, rights, and build instructions.
- `tools/build_voxel_bosses_blender.py`: boss geometry, rigging, export, and studio recipe.
- `tools/voxel_boss_motion.py`: distinct boss animation poses and timing.
- `tools/build_voxel_frontier_blender.py` and `tools/build_combat_motion_blender.py`: shared geometry/material and key-pose authoring helpers imported by the boss builder.
- `tools/build_voxel_frontier_atlas.py`: original deterministic atlas recipe; requires Python 3 and Pillow.
- `tools/package_voxel_bosses.py` and `tools/package_voxel_frontier.py`: standard-library package builder plus shared read-only GLB/PNG auditor.
- Included engine integration files and `design/voxel-bosses/` evidence retain their project-relative paths.

The Blender contact sheet is `design/voxel-bosses/blender/collection.png`. The accompanying `motion_preview.gif` demonstrates anticipation, release, and settling on the six studio clones from an isolated validated rebuild. Its source hash identifies that rebuilt `.blend`; the archive manifest identifies the delivered `.blend`. Rebuild comparison confirmed identical geometry/animation binary payloads. The GIF uses authored poses in a presentation loop; rendered gameplay verification is separate. `tools/render_voxel_boss_preview.py` reproduces its PNG frame sequence without saving changes to the source file or exports.

The studio camera, lights, labels, and staging are retained in the editable Blender source and omitted from game exports. `.gdignore` markers keep source art, documentation, and review evidence outside Godot's importer.

## Scale, rig, and sockets

Blender uses +Z up and +Y forward; glTF/Godot uses +Y up and −Z forward. One source unit equals one glTF unit. The origin is a central hull datum, so geometric bounds may be asymmetric. The game applies its established per-boss fit scale; collision and gameplay bounds stay in the runtime scenes.

Each exported asset has six mesh parts (`Body`, `Port`, `Starboard`, `Weapon`, `Reactor`, `Engines`) and one four-bone rigid skeleton (`Body`, `Port`, `Starboard`, `Weapon`). Every vertex carries one full-weight bone influence, preserving square voxel forms during articulation. The detached section is an independently animated asset.

All six assets contain `cruise`, `hit`, `windup`, and `attack`. Clip names are stable integration identifiers. Bone movement provides role-specific idle motion, attack anticipation, firing recoil, and damage response. Gameplay code remains responsible for when an attack fires, interruption rules, collision, health, and effects.

Loop `cruise`; play `hit` and `attack` once and return to cruise. Play `windup` once and hold its final charged pose until the gameplay release. Its last pose matches the first attack pose; attack and hit finish at neutral. The packaged playback helper configures these behaviors for the game.

Motion varies by role: Assault braces and punches forward; Bulwark opens heavy armor and settles slowly; Tempest counter-sweeps its vanes; the Harbinger contracts and unfurls its crown; Tempest Core opens an aperture and recoils deeply; the weapon pod makes a restrained fin brace and short recoil. The source motion report gives authored timings, while `validation.json` reports actual exported clip durations.

Every asset exports `Socket_Muzzle`, its compatibility alias `Socket_MuzzleCenter`, `Socket_Core`, and `Socket_EngineLeft`/`Socket_EngineRight`, plus role-specific emitters, section attachments, or hardpoints. Socket names and bone parents are audited against the catalog so their transforms follow the articulated parts. Use the imported socket transforms for muzzle effects and projectiles.

## Texture and material contract

The shared atlas has 16 grayscale tiles covering armor, panel seams, vents, reactor cells, solar cells, cargo hatches, exposed cuts, stone, ore, trusses, wiring, warnings, grilles, heavy armor, and edges. Its neutral values multiply each glTF material's authored color factor. This keeps the Voxel Frontier detail language while preserving distinct boss colors.

Every surface exports `TEXCOORD_0` and an embedded base-color PNG; tile UVs are inset to avoid adjacent cells. Use nearest sampling to retain broad pixel details. The top PNG row maps to Blender UV v near 1.

When replacing imported materials with game shaders, preserve their atlas texture, UV scale/offset, base-color factor, emission, and surface properties. Material replacement that forwards only the color factor discards the authored panel work. The supplied runtime adapters and shader sources demonstrate the game's integration. Engine-specific scenes and review fixtures depend on the full Farinuff Flight project; the standalone art deliverables are the GLBs, atlas, and Blender source.

The shared `effects/ship_motion_3d.gd` helper drives imported animations on the game's physics clock. It stretches anticipation to the gameplay warning duration, holds the charged pose until release, and preserves attack timing. Animated visuals and sockets remain separate from the actor's collision transform.

## Rebuild and package

Run the atlas generator with the new output directory to preserve the previous Voxel Frontier delivery:

```sh
python3 tools/build_voxel_frontier_atlas.py --output-root assets/models/voxel_bosses
blender --background --factory-startup --python tools/build_voxel_bosses_blender.py
blender --background assets/models/voxel_bosses/source/voxel_bosses.blend --python tools/build_voxel_bosses_blender.py -- --finalize-source
python3 tools/package_voxel_bosses.py --validate-only
```

Rebuilding writes this set's generated source/export files; preserve hand-edited source under another name before regeneration. All imported authoring modules are included in the package so rebuilding does not require the earlier ZIP. The finalized source opens on the studio collection; render its contact sheet with:

```sh
blender --background assets/models/voxel_bosses/source/voxel_bosses.blend --scene 'Voxel Bosses | Collection' --render-frame 1
```

The packaging invocation is recorded in `docs/package_command.txt`. It includes runtime sources, review evidence, and any scoped third-party shader notices. Verify a completed archive independently with:

```sh
python3 tools/package_voxel_bosses.py --verify path/to/Farinuff_Flight_Voxel_Bosses_1.0.0.zip
```

`manifest.json` records every payload file's size and SHA-256 digest. `MANIFEST.sha256` also hashes the manifest; the ZIP's `.sha256` sidecar covers the whole archive. The packager verifies a temporary archive before replacing the output.

## Validation and provenance

Static validation reads the delivered GLBs and checks finite geometry and normals, triangle indices, nondegenerate geometry and UV triangles, valid atlas UVs and material tints, embedded PNG CRCs and decoded pixels, external/embedded atlas equality, the named four-bone rig, rigid weights, moving animation clips and authored timing, socket names and bone bindings, collisionless export, and measured bounds. It also checks idle-loop continuity, hit return, the windup-to-attack handoff, and return to idle after recoil. Per-asset budgets are 20,000 triangles and 40,000 vertices.

Rendered texture comparisons and gameplay animation checks are separate evidence. Their captures and structured reports document what was actually tested; static validation alone does not establish rendered appearance, gameplay behavior, or frame-rate performance.

The delivered QA set includes five passing headless checks, 393 static integration assertions, twelve GPU atlas-toggle comparisons, and successful first-attack checks for all five bosses. Pod damage, independent flash, animation, and destruction were checked in the native playfield. See `design/voxel-bosses/qa/README.md` for precise coverage, reproduction steps, and existing teardown diagnostics. Staged presentation images are identified separately from actual AI-driven encounter frames.

`docs/provenance.json` preserves the exact request and the prior Voxel Frontier style/atlas provenance. `RIGHTS.md` records license scope without inventing a public redistribution grant for the original project artwork.
