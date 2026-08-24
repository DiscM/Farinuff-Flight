# Generated Sprite Assets

This folder contains normalized 2D animation strips for the ship/enemy set.

The `v2p5d_*` files are the approved reference-locked update: low-poly 3D
spacecraft translated into compact nearest-neighbor pixel sprites with hard
faceted shading, near-black occlusion rims, and controlled emissive cores.
The previous files remain in place as legacy identity references.

- Frame size: `128x128`
- Anchor: centered at `64,64`
- Strip layout: `4` horizontal frames per PNG
- Metadata: see `sprite_manifest.json` and `v2p5d_sprite_manifest.json`
- Preview: see `sprite_preview_sheet.png`

The player, regular enemy, and boss scenes now use the `v2p5d_*` strips. Regular
enemy generations intentionally share the new canonical family strip while the
existing `EnemyEvolutionController` shader supplies the generation-specific
outline, circuit, heat, and apex treatment.

Boss palette identities are intentionally separated: Tempest is storm cyan/blue,
Tempest Core is amber/gold, and Void Harbinger is spectral acid green. Their
dark-violet structural planes and silhouettes remain part of the shared boss
family.
