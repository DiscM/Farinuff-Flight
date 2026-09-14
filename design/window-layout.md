# Larger gameplay window

The default window is now **1920×1080**, up from 1280×720. The 1280×720 logical layout and combat camera framing remain the gameplay reference; Godot renders the larger window at its actual pixel resolution. Enemy silhouettes therefore occupy 50% more pixels in each dimension at 1080p, with 2.25× the rendered pixel area.

Settings → Display now offers 1280×720, 1600×900, 1920×1080, and Fit display. Preferences persist through SaveManager. Requested windows are fitted into 90% of the current display's usable area and centered, so a smaller monitor can accommodate the larger default. Fullscreen uses the display and restores the previous window on exit. Selecting a different size while fullscreen sets the window used on return. Unrelated preference changes preserve manual resizing and maximization.

The native combat CRT shader now also performs the optional barrel distortion, avoiding a second full-screen filter. Both screen samplers use linear filtering without generating unused mipmaps. All four CRT/distortion toggle combinations were verified: zero passes with both disabled, one pass otherwise. This recovered 60 FPS in the local 1080p review after the initial larger-window sample ran below 60.

## Verification

- Godot 4.6.3 / Forward+ / Metal on Apple A18 Pro: native window and captured frame both 1920×1080; logical viewport 1280×720; camera-derived playfield bounds matched the 720p baseline exactly.
- Verified all four size presets against desktop, small laptop, portrait, and negative-origin secondary-display rectangles. Fullscreen restored a manually resized 1700×950 window. The actual Display picker applied Fit display and then restored/saved 1920×1080.
- Window preference save/load and invalid-value checks passed within the existing autoload smoke. Menu boot and frontier visual smoke scenes passed. Native static resource checks and `git diff --check` passed.
- The complete autoload smoke still fails seven campaign/boss assertions, including expectations of save schema v3 while the project uses v6. Re-running the original HEAD SaveManager and original smoke test in a temporary project reproduced the identical failures. Its malformed-JSON fixture diagnostics are expected. The visual smoke also retains the previously observed two DummyShader RID shutdown diagnostics.
- The 60 FPS sample is a small local review, not a worst-case performance guarantee.

The final [1080p gameplay capture](void-frontier/combat-1080p.png) uses the existing enemy models and materials. No camera zoom, model scale, collision, movement, or encounter tuning was needed for this window change.

Godot documents the physical window override separately from the logical viewport in its [ProjectSettings reference](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-display-window-size-window-width-override).
