# Farinuff Flight 2.5D Pixel Fleet Style Reference

Status: preserved reference for the verified 2D baseline; superseded for new gameplay assets by the native 3D migration

Primary visual anchor: `references/style/farinuff-25d-pixel-fleet-01-exec-59f3f7d9-9026-4477-9999-6bdaca55f5b0.png`

Supporting visual anchors: current runtime strips under `assets/sprites/generated/` are identity references, not style references.

Visible sprite board: `renders/approved/farinuff-25d-sprite-reference-board.png`

## Native 3D migration scope

This document remains authoritative for the verified 2D rollback baseline and any maintenance of its sprite assets. For the target native 3D runtime, `docs/3d-migration-checklist.md` and ADRs 0001–0002 supersede the sprite-strip, logical-cell, anchor, and nearest-neighbor output requirements below. The role-readable silhouettes, faceted construction, palette relationships, controlled emission, and small-on-screen gameplay readability remain visual direction for the replacement GLBs unless a later approved art reference changes them.

Native 3D craft use canonical GLB assets and render directly at the active backbuffer or viewport resolution. They are not baked into four-frame gameplay strips.

## Style fingerprint

Stylized low-poly 3D spacecraft rendered as compact transparent pixel sprites. The visual target is the supplied 1280x720 gameplay render: hard faceted planes, stepped toon shading, near-black occlusion, restrained CRT/pixel breakup, and bright emissive cores against deep navy space. The supplied screenshot is a style anchor only; its boss, player, escorts, beam, HUD, and composition are not canon identities for the sprite set.

## Verified 2D baseline hard style locks

- Use low-poly 3D hard-surface construction translated into crisp nearest-neighbor pixels.
- Keep silhouettes compact, role-readable, and centered in a 128x128 logical cell with a 64x64 anchor.
- Use hard planar shading, a near-black navy contour/occlusion rim, and tiny controlled emissive halos instead of soft gradients.
- Final gameplay assets are transparent four-frame horizontal strips; no stars, planets, HUD, beams, or text are baked into them.
- Maintain the 1280x720 gameplay scale: the player remains a small, readable playfield object rather than a large character portrait.

## Palette relationships

Deep navy and near-black own the negative space and recessed surfaces. The player uses ice white and cyan energy over dark navy structure. Regular enemies are role-coded: scarlet/ember for basic and assault, hot orange for fast, toxic green/lime for bomber, cyan-blue with warm reactor contrast for sniper, and deep violet/purple for tank. Bosses retain dark-violet structural planes but now have distinct form palettes: assault scarlet/ember, bulwark violet/magenta, Tempest storm cyan/blue, Tempest Core amber/gold, and Void Harbinger spectral acid green. Saturated emissive colors are accents, not full-surface fills; most hull area stays dark or mid-value so the silhouette survives the 1280x720 view.

## Shape and construction language

- Preserve current runtime family silhouettes: compact player interceptor; pointed basic; narrow fast; broad bomber; tall sniper; blocky tank; large, mechanically layered bosses.
- Construct each hull from a few readable faceted masses, inset plates, swept fins, engine blocks, and a centered reactor or weapon aperture.
- Let geometry communicate class before color: width, aspect ratio, wing spread, armor mass, and core placement are identity locks.

## Line, rendering, and texture

Contours are stepped and hard, with a near-black navy outline or occlusion rim. Use 4-5 value bands per material, dark underside planes, selective pixel dithering, and tiny specular pixels on bevels. Emissive cores can bloom a few pixels beyond the source, but the halo must remain controlled. A light CRT scanline breakup is acceptable in the presentation reference; it must not muddy the transparent sprite edges.

## Lighting and staging

Use a cool cyan key from the upper left, deep violet fill/rim from the space environment, and hard planar occlusion. Engines, reactor cores, and weapon ports are the brightest points. Sprite assets are isolated on true transparency with generous margin and stable centering; the 1280x720 camera, starfield, beams, and HUD belong to the game scene, not the sprite texture.

## What may vary

- Idle-frame engine flicker, core pulse, tiny exhaust length, and one-pixel highlight movement.
- Generation-specific armor plates, fins, emissive accents, and controlled scale changes within the current family silhouette.
- Boss-specific radial modules and weapon apertures, provided the existing boss family remains recognizable.
- Exact pixel placement of small bevel highlights when the 64x64 anchor and gameplay readability remain stable.

## What must not be copied

The style anchor controls medium, rendering, palette relationships, edges, texture, lighting, and pixel finish only. Do not copy its exact boss identity, player topology, escort layout, beam placement, HUD, planets, stars, pose, camera composition, object inventory, or screen arrangement into a transparent sprite.

## Reusable prompt block

```text
Apply the approved Farinuff 2.5D Pixel Fleet style as a style anchor only. Transfer low-poly 3D hard-surface construction, faceted planes, stepped nearest-neighbor toon bands, hard pixel edges, near-black occlusion, role-coded emissive palette relationships, sparse dithering, and cool cyan/violet lighting.

Create one isolated transparent game sprite for: [DESCRIBE PLAYER, ENEMY, OR BOSS]. Preserve the existing family silhouette, proportions, core placement, and gameplay role. Keep the subject compact and centered in a 128x128 logical cell with a 64x64 anchor; if an animation strip is requested, use four equal horizontal frames with only subtle idle variation.

Do not copy the reference image's exact identity, topology, pose, composition, HUD, background, beam, planets, stars, or object inventory. Avoid smooth gradients, painterly rendering, anti-aliased vector edges, text, watermarks, and any non-transparent background.
```

## Review checklist

- The silhouette reads correctly at the 1280x720 gameplay scale and remains centered on the 64x64 anchor.
- Faceted low-poly construction and stepped pixel shading are visible without becoming noisy.
- Palette roles remain distinct: cyan-white player, role-coded enemies, and per-form boss colors for assault, bulwark, Tempest, Tempest Core, and Void Harbinger.
- Emissive cores and engines are the brightest points, with controlled halos and hard occlusion.
- Sprite edges are crisp and truly transparent outside the subject; no scene, HUD, beam, or text leaked into the asset.
- Identity/topology review is separate from style review: current family silhouette and runtime role are preserved.

## Project usage

The machine-readable companions are `art-project.json` and `style-profile.json`. Verified 2D baseline assets live under `assets/sprites/generated/`; versioned replacement strips should be recorded in the art-project ledger and wired into the baseline scenes only after visual and import validation. Native 3D asset requirements and validation are tracked by the migration checklist and ADRs.
