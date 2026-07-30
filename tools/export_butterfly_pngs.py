#!/usr/bin/env python3
"""Export standalone PNG mockups of the butterfly player design.

Unlike the presentation sheets, these are clean transparent-background
renders at useful sizes, plus one full in-game scene mockup with the
butterfly flying as the player.

Outputs (mockups_v6/butterfly/):

- lacewing / morpho / monarch _512.png   presentation-size colorway renders
- loadout_assault / loadout_aegis _512.png  elite-module combos
- lacewing_gamesize.png                  the true 30px combat-size sprite
- butterfly_ingame_v6.png                portrait gameplay scene mockup
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image

import generate_hybrid_mockups as hy
import generate_pixel_style_mockups as px


ROOT = Path(__file__).resolve().parents[1]
REDESIGN_DIR = ROOT / "assets" / "models" / "redesign"
OUT_DIR = ROOT / "mockups_v6" / "butterfly"

GLBS = {
    "lacewing": REDESIGN_DIR / "player_butterfly.glb",
    "morpho": REDESIGN_DIR / "player_butterfly_morpho.glb",
    "monarch": REDESIGN_DIR / "player_butterfly_monarch.glb",
}

LOADOUTS = {
    "loadout_assault": ["twin_cannons", "rear_gunner", "hull_plating"],
    "loadout_aegis": ["shield_burst", "magnet_field", "spread_shot"],
}


def export_clean_renders() -> None:
    for name, glb in GLBS.items():
        sprite = hy.render_model(hy.load_glb(glb), 128, pixel_style=True)
        px.upscale(sprite, 4).save(OUT_DIR / f"{name}_512.png")
        print(f"wrote mockups_v6/butterfly/{name}_512.png")

    hull = hy.load_glb(GLBS["lacewing"])
    for loadout, modules in LOADOUTS.items():
        combo = hull
        for module in modules:
            combo = combo + hy.load_glb(hy.MODELS_DIR / f"player_upgrade_{module}.glb")
        sprite = hy.render_model(combo, 128, pixel_style=True)
        px.upscale(sprite, 4).save(OUT_DIR / f"{loadout}_512.png")
        print(f"wrote mockups_v6/butterfly/{loadout}_512.png")

    # True combat-size sprite, no upscale: this is what the game shows.
    small = hy.render_model(hull, 30, pixel_style=True)
    small.save(OUT_DIR / "lacewing_gamesize.png")
    print("wrote mockups_v6/butterfly/lacewing_gamesize.png (30px, 1x)")


def build_ingame_scene(player_extra_prims: list | None = None) -> Image.Image:
    """The portrait gameplay mockup with the butterfly as the player.

    player_extra_prims: optional elite-module primitive lists merged onto the
    hull before rendering (the assault/aegis loadouts)."""
    scene = Image.new("RGBA", (px.GAME_W, px.GAME_H), px.VOID_BG)
    px._nebula(scene, seed=9.3)
    draw = px.ImageDraw.Draw(scene)
    rng = random.Random(7)
    px._starfield(draw, rng, 110)

    moon = px.render_planet(46, px.RAMP_ROCK, seed=2.1, noise_scale=7.0)
    px._paste(scene, moon, 336, 140)
    gas = px.render_planet(120, px.RAMP_GAS, seed=4.2, banded=True, ring=px.RAMP_TEMPEST)
    px._paste(scene, gas, 66, 640)

    bullet_p = px.render_bullet_p()
    bullet_e = px.render_bullet_e()
    orb = px.render_xp_orb()

    boss = hy.render_model(hy.model("tempest"), 56, yaw=180.0)
    px._paste(scene, boss, 180, 150)
    for ring_r, count in ((60, 10), (88, 14)):
        for i in range(count):
            ang = math.radians(i * 360 / count + ring_r)
            px._paste(scene, bullet_e, 180 + ring_r * math.cos(ang), 150 + ring_r * math.sin(ang) * 0.92)

    enemies = [
        ("basic", 62, 252, 180.0), ("basic", 130, 220, 172.0), ("basic", 238, 234, 188.0),
        ("fast", 294, 268, 205.0), ("fast", 88, 306, 155.0),
        ("bomber", 268, 356, 182.0),
        ("sniper", 44, 392, 168.0),
    ]
    sizes = {"basic": 26, "fast": 24, "bomber": 30, "sniper": 26}
    for name, ex, ey, yaw in enemies:
        px._paste(scene, hy.render_model(hy.model(name), sizes[name], yaw=yaw), ex, ey)

    for ox, oy in [(116, 342), (134, 358), (104, 372), (146, 344), (126, 388)]:
        px._paste(scene, orb, ox, oy)
    px._paste(scene, px.render_explosion(30, 0.6), 128, 356)

    # The butterfly as the player: twin engine trails from the streamer tips,
    # shots from the antenna clubs.
    px._paste(scene, px.render_engine_trail(18, px.RAMP_BULLET_P[3], px.RAMP_BULLET_P[1]), 169, 604)
    px._paste(scene, px.render_engine_trail(18, px.RAMP_BULLET_P[3], px.RAMP_BULLET_P[1]), 189, 604)
    butterfly_prims = hy.load_glb(GLBS["lacewing"])
    for extra in player_extra_prims or []:
        butterfly_prims = butterfly_prims + extra
    butterfly = hy.render_model(butterfly_prims, 34, yaw=0.0)
    px._paste(scene, butterfly, 180, 590)
    for dx in (-5, 5):  # antenna-club muzzle origins
        for step in range(3):
            px._paste(scene, bullet_p, 180 + dx + dx * 0.6 * step, 556 - step * 36, angle=dx * 1.2)
    drone = hy.render_model(hy.model("drone"), 14, yaw=0.0)
    px._paste(scene, drone, 150, 574)
    px._paste(scene, drone, 210, 574)
    px._paste(scene, px.render_powerup("spread", px.UI_YELLOW), 312, 470)

    hy._draw_hud(scene)

    out = px.upscale(scene, 2).convert("RGB")
    px._crt_pass(out)
    return out


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    export_clean_renders()
    scene = build_ingame_scene()
    scene.save(OUT_DIR / "butterfly_ingame_v6.png")
    print(f"wrote mockups_v6/butterfly/butterfly_ingame_v6.png ({scene.width}x{scene.height})")


if __name__ == "__main__":
    main()
