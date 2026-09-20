# Flight polish — September 2026

This pass builds on the existing Void Frontier scenery and Neon Cabinet menus.

- The selected menu ship now banks and floats gently inside a broken cyan orbital
  display. Only the visible showcase refreshes, at a maximum of 30 renders per
  second. Reduce menu motion restores a static pose; Reduce flashes softens the
  framing accents. Other upgrade previews retain their existing behavior.
- The existing engine ribbon surface now also draws tapered nozzle jets, a short
  white ignition core and two small shock diamonds under boost. Jets follow the
  current frame's movement and aim. Chained boosts restart the ignition, which
  fades back into cyan. Geometry stays bounded at 366 vertices on one surface.
- A broken nebula veil and slightly clearer blue gas and stars add depth around
  the playfield perimeter. The shader reuses its existing cloud samples; the
  central firing corridor stays dark. Original pixel planets and scenery remain.
- Flight preparation uses the shared nebula, cabinet heading, actual resource
  progress, and the current fire/boost bindings. Failure hides the progress and
  control hint, changes the heading, and focuses Return to Main Menu.

No movement tuning, combat rules, rewards or collision geometry changed.

## Validation

Godot 4.6.3, Metal Forward+, macOS / Apple A18 Pro:

- Passed `menu_boot_smoke`, `neon_cabinet_smoke`, `frontier_visual_smoke`,
  `combat_motion_smoke`, `background_drift_smoke`, `combat_readability_smoke`.
  Tests used disposable profiles. Headless runs retain the existing resource/RID
  shutdown diagnostics; tests running alongside the live game also report the
  occupied MCP port. The save-failure scenario deliberately emits write warnings.
- `tools/check_native_transition.py`: passed (353 source/resources).
- Live menu inspection at 1920×1080 and 960×600; runtime checks confirm hidden
  showcase processing stops and reduced motion freezes the pose.
- Live keyboard-action firing and boost in Flight Practice at 1280×720, pause
  during boost, ignition decay, boost completion, and an Assault Commander fight.
- Live inspection of preparation and failure layouts; Return receives focus and
  failed preparation hides its progress bar. No new script or shader errors.

`menu.png`, `launch.png`, `boost.png`, and `combat.png` are in-engine captures.
Launch was held for inspection; combat and boost use a practice session with its
lesson panel hidden. These are visual checks, not full-run balance or performance
certification. Captures are excluded from game import by `.gdignore`.
