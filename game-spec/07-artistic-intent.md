# Artistic Intent and Asset Contract

Status: universal visual direction; format-specific requirements belong in implementation profiles

## Visual promise

Farinuff Flight should feel like a small, overdriven fleet moving through a hostile CRT universe: compact role-readable craft, hard faceted construction, deep navy negative space, restrained emissive cores, and strong motion feedback.

## Visual invariants

- Silhouette communicates role before color.
- The Player Craft remains recognizable and readable at gameplay scale.
- Enemy roles have distinct silhouettes, motion signatures, and palette accents.
- Emissive cores, engines, weapon ports, and telegraphs are the brightest points.
- Effects clarify action and danger rather than obscuring safe gaps.
- Collision proxies are authored separately from visual meshes or sprites.
- The backdrop, UI, effects, and text are not baked into gameplay identity assets.

## Palette relationships

- Deep navy and near-black: space, occlusion, and recessed structure
- Ice white and cyan: Player Craft and friendly energy
- Scarlet/ember: basic and assault threats
- Hot orange: fast threats and warning energy
- Toxic green/lime: bomber threats
- Cyan-blue with warm reactor contrast: sniper threats
- Violet/purple: tank and bulwark structure
- Amber/gold: Tempest Core identity
- Acid green: Void Harbinger spectral identity

Saturated colors are accents, not full-surface fills. Value contrast must preserve silhouettes when color perception is reduced.

## Format adapters

### Current 2D reference

- Transparent four-frame horizontal strips
- 128×128 logical cell with a 64×64 anchor
- Crisp nearest-neighbor treatment
- Compact gameplay-scale silhouettes

### Native top-down 3D reference

- Low-poly hard-surface construction
- Canonical GLB/glTF runtime assets
- Hard planar/toon value bands and controlled emission
- Fixed near-top-down camera over a horizontal Combat Plane
- Dedicated primitive collision proxies

### Other engines or formats

Preserve role, silhouette, palette relationship, scale hierarchy, and readability intent. Change topology, texture strategy, animation format, and import settings only as required by the target runtime. Record any loss of fidelity or intentional reinterpretation in the port profile.

## Asset record requirements

Every shipped asset should have:

- Stable content ID
- Display role and owning system
- Source file and author/creator
- License and modification status
- Target format and import settings
- Pivot/origin and scale contract
- Collision-proxy notes
- Approval status and in-game review capture

## Review checklist

- Does the silhouette read at the reference gameplay scale?
- Is the object distinguishable without relying on hue alone?
- Are important cores, weapons, and telegraphs visible during combat load?
- Does the asset remain aligned while moving, aiming, boosting, blinking, and changing effects state?
- Are visual-only parts excluded from gameplay collision?
- Does the asset obey the target format's technical budget?
