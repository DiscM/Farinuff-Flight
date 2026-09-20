# Clean sci-fi typography

The active game theme now pairs Oxanium SemiBold headings/actions with IBM Plex Sans body text. Plex Sans SemiBold supplies HUD data and bold passages; its tabular numerals keep counters stable. Matching italic resources keep narrative emphasis in the same family.

Font sources, license texts, pinned revisions, and checksums live in `assets/fonts/`. The fonts are local game resources. Both export presets include the new license files, and release packaging copies the complete notices alongside the build.

## Verification

- `command-deck.png`: live menu at 2560 × 1440, with the final 600-weight heading and action typography.
- `settings-large-text-1280.png`: settings at 1280 × 720 and 130% menu text. Scrolling and the Close action remain available.
- `combat-hud.png`: production Flight Practice HUD at 2560 × 1440.
- `font-rendering.json`: font coordinates read back from Godot's text renderer after a fresh launch. Oxanium retains “ExtraLight” in its upstream default face metadata; the actual rendered heading coordinate is weight 600. Plex's empty regular coordinates mean its default 400-weight, 100-width instance. Both five-digit samples have equal width.
- `qa/`: passing frontend navigation, menu boot, and combat readability smokes. These include enlarged text, HUD fit, and multiple window aspect ratios. Existing intentional save-failure warnings and headless renderer teardown diagnostics remain in the relevant logs; no GDScript errors occurred.
- All eight existing release-tool unit tests passed; downloaded font/license hashes match their manifests. No full release export was performed for this typography change.

All live checks finished with the normal saved window and text preferences intact.
