# Opening presentation reference

September 16, 2026. Implements production slice 05; visual approval and the M1
fresh-player cohort remain open. This reference consolidates
[Neon Cabinet](../neon-cabinet/README.md),
[Void Frontier](../void-frontier/README.md),
[combat motion](../combat-motion/README.md), and
[audio direction](../audio_direction.md).

## Shape, material, and hierarchy

- Keep the swept butterfly wings, articulated armor, clipped UI corners, and
  broken orbital structures. Live craft previews show the actual loadout.
- Player hulls use blue-gray alloy with restrained cyan energy. Enemy armor keeps
  its class colors; violet identifies corruption. Warm gold identifies rewards.
- Near-black panels support text. Cyan outlines group related controls; yellow
  marks the primary commit action. White focus outlines must stay visible.
- A selected upgrade remains reversible until **Install & Continue**. Locked
  entries name their salvage cost; owned entries show their level or selection.
- Backgrounds remain quieter than bullets and craft. Cyan diamond hostile shots
  retain their non-reflectable shape. Animation never changes collision geometry.

## Typography

The application theme now loads bundled fonts across menus, practice, and combat.
The fonts are unmodified; the source revision and SHA-256 hashes are in
[`assets/fonts/barlow/manifest.json`](../../assets/fonts/barlow/manifest.json).
The SIL OFL and copyright notice ship in the PCK and beside the executable.

| Role | Font | Baseline logical size |
| --- | --- | --- |
| Main title | Barlow Condensed Bold Italic | 56–64 |
| Screen / section heading | Barlow Condensed Bold Italic | 26–34 / 20–22 |
| Primary / ordinary button | Barlow Condensed Bold Italic | 20 / 16–18 |
| Body / supporting text | Barlow Regular | 16 / 12–14 |
| Compact gameplay values | Barlow SemiBold, upright | 11–14 |

Menu text supports 1.0–1.3 scale through `InterfaceSettings`; scrollable details
must leave the launch decision reachable. Keep compact gameplay values upright:
the condensed display face loses clarity at HUD sizes. Existing HUD scale and
remaining symbol fallbacks are tracked under later accessibility work; menu text
scaling does not establish independent HUD scaling or localization support.

## Catalog icons

[`assets/ui/catalog/`](../../assets/ui/catalog/) contains 24 original SVG symbols,
mapped to 31 catalog/currency IDs by [`ui/catalog_icons.gd`](../../ui/catalog_icons.gd).
They use a 48-unit canvas, three-unit white strokes, transparent backgrounds, and
angular corners. Tint comes from the catalog; shape and adjacent text carry the
meaning independently of color. Show them at 24–32 logical pixels.

Hangar rows, loadout hulls and challenges, and reward cards without ship previews
use these symbols. Unknown IDs use a generic module symbol. Retain live previews
on ordinary upgrade cards. Text-only result summaries use module names without
emoji. The whole-game presentation pass can reuse this family for remaining
currency and control symbols.

The SVG paths were authored directly for this project with Codex. No external
icon pack or raster reference was used. Preserve that provenance when auditing
player-consumed generated material for the store disclosure.

## Teaching and pacing

Practice now shows the current fire/boost binding, states that reflected shots
damage enemies, and acknowledges the first reflection. Its orb lesson explains
wave advancement; completion then explains the life gained at 12 orb points.
The free practice session remains skippable via Return to Flight School.

Keep the current Wave-5/10/15 installation schedule until observations justify a
change. The ordinary opening requires 11, 12, 13, and 15 orb points to reach Wave 5
(51 total, without Energy Drought), followed by the Assault Commander. These are
progression requirements, not elapsed-time measurements.

[`docs/opening-playtest.md`](../../docs/opening-playtest.md) describes the fresh
profile timing command and the eight-player protocol. No human time-to-reflection
or time-to-first-upgrade result has been inferred from staged captures.

## Review captures

The capture set uses actual Godot 4.6.3 Metal/Forward+ rendering on macOS. Each
surface is recorded at 1920×1080, 1280×720, and 1280×720 with menu text at 1.3.
Gameplay views use staged actors and invulnerability; the results view is staged.
These images demonstrate presentation and layout, not balance, performance, or
successful natural completion. The working tree includes existing copy edits.

| Surface | 1080p | 720p | 720p / larger text |
| --- | --- | --- | --- |
| Title | [View](captures/title-1080.png) | [View](captures/title-720.png) | [View](captures/title-720-large.png) |
| Loadout | [View](captures/loadout-1080.png) | [View](captures/loadout-720.png) | [View](captures/loadout-720-large.png) |
| Hangar | [View](captures/hangar-1080.png) | [View](captures/hangar-720.png) | [View](captures/hangar-720-large.png) |
| Ordinary combat | [View](captures/combat-1080.png) | [View](captures/combat-720.png) | [View](captures/combat-720-large.png) |
| Crowded combat | [View](captures/crowded-1080.png) | [View](captures/crowded-720.png) | [View](captures/crowded-720-large.png) |
| Boss warning | [View](captures/boss-warning-1080.png) | [View](captures/boss-warning-720.png) | [View](captures/boss-warning-720-large.png) |
| Upgrade selection | [View](captures/upgrade-1080.png) | [View](captures/upgrade-720.png) | [View](captures/upgrade-720-large.png) |
| Victory / results | [View](captures/results-1080.png) | [View](captures/results-720.png) | [View](captures/results-720-large.png) |

The [reflection lesson](captures/practice-reflection-720-large.png) also has a
720p/larger-text capture showing its success acknowledgement and next instruction.

The source directory is excluded from import and release packages. Review this set
before rolling typography and symbols through the remaining summary surfaces.
