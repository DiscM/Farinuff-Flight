# Farinuff Flight — Voxel Frontier 1.0.0

An original Blender-authored fleet and debris set for Farinuff Flight: five animated voxel enemies, six space-debris assets, and one shared 256 × 256 surface atlas. Shapes preserve the game's class silhouettes and role colors; small emissive accents sit over dark structural cores and stepped armor.

Authored with Blender 5.2.1 and integrated into the project's Godot 4.6.3 native 3D runtime. The editable `.blend` includes an organized collection/contact-sheet studio and individual export scenes; studio lights, camera, and labels are excluded from the game GLBs.

## Contents

| Asset | Runtime role | Palette / visual identity |
| --- | --- | --- |
| `basic_enemy.glb` | Basic enemy | Scarlet and ember; compact arrowhead |
| `fast_enemy.glb` | Fast enemy | Warm orange; narrow interceptor |
| `bomber_enemy.glb` | Bomber | Sage green and lime; broad carrier |
| `tank_enemy.glb` | Tank | Violet; heavy block armor |
| `sniper_enemy.glb` | Sniper | Cyan-blue, warm reactor; long weapon body |
| `relay_fragment.glb` | Ambient debris | Broken communications hardware |
| `solar_fragment.glb` | Ambient debris | Broken photovoltaic array |
| `cargo_wreck.glb` | Ambient debris | Armored cargo module |
| `engine_wreck.glb` | Ambient debris | Detached engine hardware |
| `hull_fragment.glb` | Ambient debris | Fractured plating and exposed structure |
| `asteroid_cluster.glb` | Ambient debris | Stepped stone and ore |

Stable IDs and role metadata live in `assets/models/voxel_frontier/docs/catalog.json`. The generated `validation.json` gives exact scene-space dimensions, vertices, triangles, surfaces, material names, clip durations, image hashes, and file sizes for each delivered GLB. Measurements are taken from the delivered bytes, not estimated from the source scene.

The archive preserves project-relative paths:

- `assets/models/voxel_frontier/meshes/`: portable GLBs with embedded atlas images.
- `assets/models/voxel_frontier/source/voxel_frontier.blend`: editable Blender source.
- `assets/models/voxel_frontier/textures/voxel_surface_atlas.png`: external, editable RGB atlas.
- `assets/models/voxel_frontier/docs/`: tile UV metadata, asset catalog, provenance, rights, and this guide.
- `tools/build_voxel_frontier_blender.py`: Blender authoring recipe.
- `tools/build_combat_motion_blender.py`: shared animation recipe imported by the Blender authoring script.
- `tools/build_voxel_frontier_atlas.py`: deterministic atlas recipe; requires Python 3 and Pillow.
- `tools/package_voxel_frontier.py`: standard-library static audit, ZIP build, and package verification.
- `effects/rendering/` and `effects/shaders/models/`: runtime material adapters and shader references.
- `design/voxel-frontier/`: review captures and runtime evidence when included in the delivery manifest.

## Coordinates, scale, and animation

Blender source uses +Z up and +Y forward. Standard glTF Y-up export converts this to +Y up and −Z forward, matching Godot. One source unit is one glTF unit. The origin uses a central hull datum; geometric bounds may be asymmetric. Enemy scenes apply the game's established per-role presentation scale. Compare `dimensions_xyz` in `validation.json` before applying a new scale.

Each enemy uses four rigid bones and the clips `cruise`, `hit`, `windup`, and `attack`. Rigid weighting keeps voxel parts square as weapons and wings articulate. The debris exports are static; runtime code owns tumble, drift, spawn density, and culling. The GLBs contain no collision meshes, cameras, or lights. Game scenes continue to own combat collision, health, effects, audio, and movement.

## Texture and shader contract

The atlas contains 16 original 64 × 64 tiles: armor, vents, reactor cells, hull stripes, solar cells, cargo hatch, fractured cuts, stone, ore, truss, wiring, warnings, engine grille, heavy armor, and edge panels. Its RGB channels are neutral grayscale; the glTF material factor supplies the class color. This separation preserves recognizable enemy colors and allows the same atlas to serve all 11 assets.

Every render surface has `TEXCOORD_0` UVs and an embedded base-color texture. Tile bounds in `docs/atlas_tiles.json` are inset from neighboring cells. Use nearest filtering to preserve the broad pixel details. The PNG top row corresponds to Blender UV v near 1.

In Farinuff Flight, `effects/rendering/enemy_surface_materials.gd` reads each imported material's base-color factor, atlas texture, metallic/roughness, and emission, then creates the runtime shader material. Preserve those values when replacing an imported material: assigning a generic shader without transferring its texture can silently remove the authored panel detail. All five enemy classes use the Pixel Planets shader by default; the authored-alloy shader remains available as a review alternative. Both paths sample the atlas. Damage and combat feedback remain controlled by the existing game code. The scenery adapter delegates to the same material bridge with a dimmer presentation.

For a new Godot project, copy the `assets/models/voxel_frontier/` folder and import a GLB directly; its embedded atlas and PBR material factors work without the game scripts. To use the optional Pixel Planets material treatment, also copy the included material adapter, both referenced shaders, and the scoped MIT notice, preserving their `res://` paths. Apply the material bridge after adding the model to the scene tree:

```gdscript
const SurfaceLibrary = preload("res://effects/rendering/enemy_surface_materials.gd")

func _ready() -> void:
    var model = load("res://assets/models/voxel_frontier/meshes/basic_enemy.glb").instantiate()
    add_child(model)
    SurfaceLibrary.apply_to(model, SurfaceLibrary.Style.PIXEL_PLANET)
```

To inspect the game integration, run the repository's `scenes/voxel_frontier_review.tscn` fixture. Its controls are R: rotation, A: attack, F: hit flash, S: switch material style, T: atlas comparison. The review scene depends on game scripts and resources outside this asset pack; it is a project QA fixture, not a standalone sample game.

Included enemy wrapper scenes, ship catalog, and background integration files are references for this repository and likewise depend on the full game. The portable art deliverables are the GLBs, atlas, and Blender source.

## Rebuild and audit

From the project root, with the required tools available:

```sh
python3 tools/build_voxel_frontier_atlas.py
blender --background --python tools/build_voxel_frontier_blender.py
blender --background assets/models/voxel_frontier/source/voxel_frontier.blend --python tools/build_voxel_frontier_blender.py -- --finalize-source
python3 tools/package_voxel_frontier.py --validate-only
```

The Blender recipe requires the Blender version documented in the source build record. Rebuilding writes the set's generated source/export files; retain your hand-edited source under a different name before regeneration.

To re-render the contact sheet from the finished source file, use:

```sh
blender --background assets/models/voxel_frontier/source/voxel_frontier.blend --scene 'Voxel Frontier | Collection' --render-frame 1
```

The packaging command is recorded separately in `docs/package_command.txt`. It includes the authoring recipes, shaders, adapters, and any review evidence in addition to the asset directory. To verify a delivered archive independently:

```sh
python3 tools/package_voxel_frontier.py --verify path/to/Farinuff_Flight_Voxel_Frontier_1.0.0.zip
```

`manifest.json` lists every payload file with a SHA-256 digest. `MANIFEST.sha256` additionally hashes the manifest itself. The `.zip.sha256` sidecar hashes the whole archive. The archive is checked after writing and is replaced only after the temporary archive passes validation.

## Validation and rights

Static validation checks the actual GLB header, buffers, valid indices, finite geometry, unit-like normals, nondegenerate triangles, finite in-range UVs, UV area, valid material assignments and color factors, embedded PNG CRCs and decoded pixels, external/embedded atlas pixel equality, skeleton weights, animation channels, scene bounds, and collisionless export. Policy budgets are 20,000 triangles, 40,000 vertices, and a maximum texture dimension of 4096 per asset. Actual delivered counts are recorded in `validation.json`.

Static validation cannot establish the final game appearance. Runtime texture-toggle captures and pixel-difference evidence, when present, are separate evidence that the imported atlas reaches each rendered asset through the assigned shader. Visual quality is reviewed at both gallery and gameplay scale.

See `RIGHTS.md` and `docs/provenance.json` for the original request and provenance. No public redistribution license is invented by this package; the project owner controls release terms.
