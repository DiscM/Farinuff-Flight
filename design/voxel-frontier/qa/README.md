# Voxel Frontier integration verification

Verified in Godot 4.6.3 on 2026-09-20. Production uses the PixelPlanets material on all five voxel enemies; authored alloy remains an explicit review alternative.

## Automated checks

- `native_completion.log`: PASS, including all five runtime GLB paths, UVs, atlas bindings on every surface, role palettes, fit scales, mesh budgets, emissive surfaces, sockets, existing upgrades, pools, transitions and boss variants.
- `combat_motion.log`: PASS, including anticipation/release, recoil, animated sockets, pause and collision stability.
- `pixel_enemy_material.log`: PASS, including albedo/emission texture forwarding, UV transforms, color-only fallback, immutable sharing, style switching, per-actor generation feedback and hit flash.
- `background_drift.log`: PASS, including all 17 debris variants within 18 instances, wrapping, boss freeze and resume.
- `native_completion_contract.log`: PASS, 380 file-only assertions; also enforces the new GLB paths and production pixel style.
- `../godot/texture_visibility.json`: PASS, 33 framebuffer comparisons (11 assets across production, PixelPlanets and authored-alloy configurations). Every asset changes visibly when its atlas is disabled, from 2,208 to 39,425 affected pixels per comparison.

The headless tests exit successfully. Godot's dummy renderer reports cached shader RIDs at shutdown; native/motion smoke teardown also reports one resource still in use. These are teardown diagnostics, not clean-log claims. The final rendered session had no new errors after interaction checks; startup included existing script lint warnings.

## Rendered practice check

`gameplay_verification.json` records a controlled formation in the actual `scenes/flight_practice.tscn` environment at unchanged native scales. Enemy movement was held for comparison, while production animation, shaders, collision, projectiles, and feedback remained available. The tutorial panel was hidden for the captures. No practice rewards or field supplies were used.

- All five classes loaded the pixel shader and preserved native fit scales.
- Windup articulated each hull by 0.157–0.561 radians; collision transforms remained unchanged.
- Animated wrapper sockets stayed within 0.00000191 world units of their authored anchors.
- A real player projectile reduced the basic enemy's health from 500 to 499; its hit flash reached 0.8 while a peer remained at 0.
- A sniper projectile left the animated muzzle and selected its attack animation.
- The scenery retained its 18-instance limit.
- The MCP project was stopped after verification, and its temporary interaction autoload was removed.

Captures in `../godot/`: `gameplay.png`, `gameplay_windup.png`, `gameplay_impact.png`, plus the six textured/untextured review frames. The formation images supplement automated checks; they do not claim a complete campaign playthrough.
