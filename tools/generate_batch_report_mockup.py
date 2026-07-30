#!/usr/bin/env python3
"""Compose the "implemented batches" report mockup from real in-game frames.

The frames are captured by tools/capture_gameplay_screenshots.gd (run the
Godot binary windowed, not headless) and live in mockups_v6/. This script
arranges them with pixel-zoom insets and the batch checklist into a single
presentation sheet: mockups_v6/implemented_batches_report_v6.png.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

import generate_pixel_style_mockups as px


ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / "mockups_v6"
OUT = SHOTS / "implemented_batches_report_v6.png"


def _zoom(img: Image.Image, box: tuple[int, int, int, int], factor: int) -> Image.Image:
    crop = img.crop(box)
    return crop.resize((crop.width * factor, crop.height * factor), Image.Resampling.NEAREST)


def main() -> None:
    early = Image.open(SHOTS / "implemented_wave_early.png").convert("RGB")
    mid = Image.open(SHOTS / "implemented_wave_mid.png").convert("RGB")
    late = Image.open(SHOTS / "implemented_wave_late.png").convert("RGB")

    W, H = 1600, 900
    img = Image.new("RGB", (W, H), px.VOID_BG)
    draw = px.ImageDraw.Draw(img)
    px.text(draw, (60, 34), "IMPLEMENTED - REAL IN-GAME FRAMES", 28, px.UI_TEXT)
    px.text(
        draw,
        (60, 80),
        "batches 1-3 live in the build: pixel toon 3d, half-res viewport, void outlines, pixel projectiles",
        13, px.UI_DIM,
    )
    draw.line((60, 108, W - 60, 108), fill=px.VOID_HI, width=2)

    shots = [(early, "WAVE 1 - 3s"), (mid, "WAVE 1 - 12s"), (late, "WAVE 1 - 24s")]
    x = 60
    for shot, caption in shots:
        frame = shot.resize((324, 576), Image.Resampling.LANCZOS)
        px._panel(draw, (x - 8, 132, x + 332, 724), px.UI_CYAN)
        img.paste(frame, (x, 140))
        px.text(draw, (x + 8, 700), caption, 11, px.UI_YELLOW)
        x += 374

    # right column: batch checklist
    px._panel(draw, (1180, 132, 1540, 420), px.UI_GREEN)
    px.text(draw, (1204, 148), "SHIPPED IN BATCHES", 14, px.UI_GREEN)
    batches = [
        "1  pixel_toon_3d.gdshader",
        "   banded n.l + dither + glow",
        "1b shipviewport 1/2 res",
        "   nearest upscale, msaa off",
        "2  pixel_outline + trail",
        "   void rim, banded fade",
        "3  bolt / plasma / xp orb",
        "   posterized + chunky grid",
    ]
    for i, line in enumerate(batches):
        px.text(draw, (1204, 182 + i * 27), line, 11, px.UI_TEXT)

    px._panel(draw, (1180, 444, 1540, 724), px.UI_YELLOW)
    px.text(draw, (1204, 460), "VERIFIED", 14, px.UI_YELLOW)
    checks = [
        "8/8 headless smoke tests",
        "hit flash + evolution params",
        "screen_to_world mapping",
        "upgrade socket compositing",
        "",
        "NEXT",
        "- pixel hud panels (v6)",
        "- power-up chips",
        "- boss black hole stays",
    ]
    for i, line in enumerate(checks):
        px.text(draw, (1204, 494 + i * 25), line, 11, px.UI_TEXT if not line.isupper() else px.UI_CYAN)

    # bottom row: pixel zoom insets proving the grid matches the planets'
    px.text(draw, (60, 744), "ACTUAL PIXELS - the ship grid now matches the planet grid:", 13, px.UI_DIM)
    insets = [
        ("PLAYER (3D GLB, LIVE)", _zoom(early, (201, 676, 249, 724), 2)),
        ("ENEMY (3D GLB, LIVE)", _zoom(late, (162, 108, 210, 156), 2)),
        ("PLAYER BOLT", _zoom(mid, (212, 296, 228, 328), 3)),
        ("PIXELPLANET LIMB", _zoom(mid, (162, 162, 210, 210), 2)),
    ]
    ix = 60
    for label, inset in insets:
        px._panel(draw, (ix, 776, ix + 238, 886), px.VOID_HI)
        img.paste(inset, (ix + (238 - inset.width) // 2, 778 + (70 - inset.height) // 2))
        px.text(draw, (ix + 10, 864), label, 10, px.UI_TEXT)
        ix += 262

    img.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
