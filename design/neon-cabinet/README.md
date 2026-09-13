# Neon Cabinet

Selected direction: B, Neon Cabinet. The concept board is `approved-direction.png`. Captures alongside this document show the actual Godot implementation using the existing game art.

## UI decisions

- Bold italic headings, cyan outlines, near-black panels, yellow commit actions, and white focus outlines. Body text stays upright.
- Play launches the saved hull and challenge configuration directly. Route details, loadout, and Flight School remain optional supporting pages. Hangar, Settings, and Archives remain accessible in the compact navigation bar.
- Loadout decisions stay visible below the scrolling ship and modifier list.
- Score and wave progress sit at the top; lives, life restoration, and effects share a bottom strip, with boost immediately below. CRT and distortion affect the game world below the UI.
- Upgrade selection is reversible. A checked yellow card identifies the choice; Install & Continue commits it exactly once.
- Pause and result screens reuse the same typography and primary-action treatment.

## Validation

Godot 4.6.3 on macOS. Navigation smoke tests and native completion smoke tests passed. The native suite reports resource/RID cleanup warnings at shutdown. The focused `neon_cabinet_smoke.tscn` passes with a clean exit and verifies changing the pending upgrade plus duplicate-install protection.

Live checks cover direct launch, 1280×720 and 960×600 menu layouts, the combat HUD, selected upgrade presentation, and the pause overlay. The pause capture is a UI review mounted over the loadout page. New artwork in the concept board is illustrative; existing ships and backdrops are retained in the game. System-font rendering may differ on other operating systems.
