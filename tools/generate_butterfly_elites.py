#!/usr/bin/env python3
"""Butterfly-native elite upgrade modules (mockups_v6).

The original elite modules were authored for the angular dart hull; bolted
onto the butterfly they read as industrial spare parts. This script re-expresses
every elite upgrade as butterfly anatomy, so hull and modules share one design
language:

- twin_cannons  -> hornet clubs (bladed antenna tips)
- auto_aim      -> compound eyes
- hull_plating  -> wing-scale shingles (butterfly wings ARE scales)
- afterburner   -> extended streamers with flame tips
- spread_shot   -> marginal wing spots (real butterflies carry margin dots)
- shield_burst  -> warden eyespots (defensive eyespots deflect predators)
- magnet_field  -> feathered antennae (moth pheromone sensors)
- overclock     -> heated thorax (butterflies shiver to warm flight muscles)
- rear_gunner   -> abdomen stinger
- drone_escort  -> mini butterfly companions

Modules are authored in the butterfly hull's model space (and scaled by the
same 0.85) so they composite exactly like the production upgrade GLBs.

Outputs:

- assets/models/redesign/butterfly_elites/*.glb   the module candidates
- mockups_v6/butterfly_elites_v6.png              catalog + loadout sheet
- mockups_v6/butterfly/elites/*.png               standalone PNG renders
- mockups_v6/butterfly/butterfly_ingame_elites_v6.png  loadout in-game scene
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

import export_butterfly_pngs as bf_export
import generate_hybrid_mockups as hy
import generate_mockup_models as gm
import generate_pixel_style_mockups as px
from generate_butterfly_mockup import build_butterfly


ROOT = Path(__file__).resolve().parents[1]
ELITE_DIR = ROOT / "assets" / "models" / "redesign" / "butterfly_elites"
OUT_DIR = ROOT / "mockups_v6"
PNG_DIR = OUT_DIR / "butterfly" / "elites"

BUTTERFLY_SCALE = 0.85  # matches generate_butterfly_mockup.build_butterfly()


# ---------------------------------------------------------------------------
# Module builders (butterfly model space, pre-scale)
# ---------------------------------------------------------------------------


def _finish(model: gm.Model) -> gm.Model:
    model.scale_uniform(BUTTERFLY_SCALE)
    return model


def build_twin_cannons() -> gm.Model:
    """Hornet clubs: bladed antenna tips with gold power rings."""
    model = gm.Model("bf_elite_twin_cannons", "ELITE // HORNET CLUBS")
    blade = [(0.36, -2.58), (0.44, -2.58), (0.47, -3.06), (0.37, -3.06)]
    model.add_beveled_plate(blade, 0.03, 0.09, "steel", "hc_blade_r")
    model.add_beveled_plate(gm.mirrored(blade), 0.03, 0.09, "steel", "hc_blade_l")
    for side, suffix in ((1.0, "r"), (-1.0, "l")):
        model.add_ellipsoid(
            (0.40 * side, 0.055, -2.66), (0.095, 0.06, 0.14), "dark", f"hc_cap_{suffix}", 3, 6
        )
        model.add_ellipsoid(
            (0.40 * side, 0.045, -2.55), (0.10, 0.035, 0.06), "yellow", f"hc_ring_{suffix}", 3, 6
        )
        model.add_socket(f"Socket_Muzzle{'Right' if side > 0 else 'Left'}", (0.42 * side, 0.06, -3.10))
    return _finish(model)


def build_auto_aim() -> gm.Model:
    """Compound eyes: enlarged lime sensor eyes over the head."""
    model = gm.Model("bf_elite_auto_aim", "ELITE // COMPOUND EYES")
    for side, suffix in ((1.0, "r"), (-1.0, "l")):
        model.add_ellipsoid(
            (0.085 * side, 0.155, -1.64), (0.075, 0.055, 0.085), "lime", f"ce_eye_{suffix}", 3, 6
        )
        model.add_ellipsoid(
            (0.085 * side, 0.19, -1.665), (0.03, 0.025, 0.035), "white", f"ce_pupil_{suffix}", 2, 4
        )
    ridge = [(-0.05, -1.52), (0.05, -1.52), (0.05, -1.40), (-0.05, -1.40)]
    model.add_beveled_plate(ridge, 0.16, 0.21, "dark", "ce_ridge")
    return _finish(model)


def build_hull_plating() -> gm.Model:
    """Wing-scale shingles: overlapping silver scales with a violet undercoat."""
    model = gm.Model("bf_elite_hull_plating", "ELITE // WING SCALES")
    scales = [
        [(0.45, -0.68), (0.85, -0.80), (0.88, -0.62), (0.48, -0.50)],
        [(0.82, -0.82), (1.22, -0.94), (1.25, -0.76), (0.85, -0.64)],
        [(1.19, -0.96), (1.58, -1.06), (1.60, -0.88), (1.22, -0.78)],
    ]
    for i, scale in enumerate(scales):
        model.add_beveled_plate(scale, 0.055, 0.068, "violet", f"ws_under_r_{i}")
        model.add_beveled_plate(scale, 0.068, 0.115, "silver", f"ws_scale_r_{i}", 0.92)
        model.add_beveled_plate(gm.mirrored(scale), 0.055, 0.068, "violet", f"ws_under_l_{i}")
        model.add_beveled_plate(gm.mirrored(scale), 0.068, 0.115, "silver", f"ws_scale_l_{i}", 0.92)
    hind = [(0.42, 0.42), (0.78, 0.52), (0.80, 0.68), (0.44, 0.58)]
    model.add_beveled_plate(hind, 0.05, 0.10, "silver", "ws_hind_r", 0.92)
    model.add_beveled_plate(gm.mirrored(hind), 0.05, 0.10, "silver", "ws_hind_l", 0.92)
    return _finish(model)


def build_afterburner() -> gm.Model:
    """Longstreamers: extended tail streamers with orange flame tips."""
    model = gm.Model("bf_elite_afterburner", "ELITE // LONGSTREAMERS")
    streamer = [(1.15, 1.82), (1.33, 1.82), (1.30, 2.34), (1.20, 2.34)]
    model.add_beveled_plate(streamer, -0.02, 0.04, "steel", "ls_tail_r")
    model.add_beveled_plate(gm.mirrored(streamer), -0.02, 0.04, "steel", "ls_tail_l")
    model.add_engine(1.25, 0.0, 2.32, 0.30, 0.105, "orange", "ls_flame_r")
    model.add_engine(-1.25, 0.0, 2.32, 0.30, 0.105, "orange", "ls_flame_l")
    model.add_socket("Socket_EngineLeft", (-1.25, 0.0, 2.65))
    model.add_socket("Socket_EngineRight", (1.25, 0.0, 2.65))
    return _finish(model)


def build_spread_shot() -> gm.Model:
    """Marginal spots: a row of glowing discharge dots on each forewing margin."""
    model = gm.Model("bf_elite_spread_shot", "ELITE // MARGINAL SPOTS")
    for i, (mx, mz) in enumerate(((1.50, -0.70), (1.78, -0.50), (2.02, -0.30))):
        for side, suffix in ((1.0, "r"), (-1.0, "l")):
            model.add_ellipsoid(
                (mx * side, 0.065, mz), (0.075, 0.035, 0.075), "magenta", f"ms_dot_{suffix}_{i}", 3, 6
            )
            model.add_ellipsoid(
                (mx * side, 0.085, mz), (0.032, 0.025, 0.032), "white", f"ms_core_{suffix}_{i}", 2, 4
            )
    model.add_socket("Socket_MuzzleLeft", (-2.02, 0.09, -0.30))
    model.add_socket("Socket_MuzzleRight", (2.02, 0.09, -0.30))
    return _finish(model)


def build_shield_burst() -> gm.Model:
    """Warden eyespots: enlarged defensive eyespots with silver outer rings."""
    model = gm.Model("bf_elite_shield_burst", "ELITE // WARDEN EYESPOTS")
    for side, suffix in ((1.0, "r"), (-1.0, "l")):
        model.add_ellipsoid(
            (0.92 * side, 0.055, 0.85), (0.33, 0.03, 0.33), "silver", f"we_ring_{suffix}", 4, 10
        )
        model.add_ellipsoid(
            (0.92 * side, 0.07, 0.85), (0.24, 0.035, 0.24), "cyan", f"we_iris_{suffix}", 4, 8
        )
        model.add_ellipsoid(
            (0.92 * side, 0.09, 0.85), (0.13, 0.03, 0.13), "white", f"we_pupil_{suffix}", 3, 6
        )
    return _finish(model)


def build_magnet_field() -> gm.Model:
    """Feather antennae: gold sensor barbs along both antennae."""
    model = gm.Model("bf_elite_magnet_field", "ELITE // FEATHER ANTENNAE")
    for i, bz in enumerate((-1.88, -2.08, -2.28, -2.48)):
        barb = [(0.26, bz), (0.46, bz - 0.05), (0.44, bz - 0.10), (0.24, bz - 0.05)]
        model.add_beveled_plate(barb, 0.03, 0.06, "yellow", f"fa_barb_r_{i}")
        model.add_beveled_plate(gm.mirrored(barb), 0.03, 0.06, "yellow", f"fa_barb_l_{i}")
    return _finish(model)


def build_overclock() -> gm.Model:
    """Heated thorax: orange metabolic glow plates over thorax and abdomen."""
    model = gm.Model("bf_elite_overclock", "ELITE // HEATED THORAX")
    thorax = [(-0.16, -0.72), (0.16, -0.72), (0.16, -0.30), (-0.16, -0.30)]
    model.add_beveled_plate(thorax, 0.22, 0.27, "orange", "ht_thorax")
    for i, (z0, z1) in enumerate(((0.22, 0.43), (0.64, 0.85), (1.06, 1.27))):
        seg = [(-0.10, z0), (0.10, z0), (0.10, z1), (-0.10, z1)]
        model.add_beveled_plate(seg, 0.205, 0.235, "yellow", f"ht_abdomen_{i}")
    return _finish(model)


def build_rear_gunner() -> gm.Model:
    """Stinger: a tapered dark spike with a hot scarlet tip at the abdomen end."""
    model = gm.Model("bf_elite_rear_gunner", "ELITE // STINGER")
    spike = [(-0.07, 1.86), (0.07, 1.86), (0.035, 2.36), (-0.035, 2.36)]
    model.add_beveled_plate(spike, -0.02, 0.06, "dark", "st_spike")
    model.add_ellipsoid((0.0, 0.01, 2.38), (0.06, 0.05, 0.10), "scarlet", "st_tip", 3, 5)
    model.add_socket("Socket_MuzzleRear", (0.0, 0.01, 2.46))
    return _finish(model)


def build_drone_escort() -> gm.Model:
    """Mini butterfly companion drones."""
    model = build_butterfly(name="bf_elite_drone_escort", display="ELITE // BUTTERFLY DRONES")
    model.scale_uniform(0.42)  # on top of the hull's 0.85
    return model


MODULES = {
    "twin_cannons": (build_twin_cannons, "hornet clubs", "doubled forward fire"),
    "auto_aim": (build_auto_aim, "compound eyes", "shots track targets"),
    "hull_plating": (build_hull_plating, "wing scales", "+2 max lives armor"),
    "afterburner": (build_afterburner, "longstreamers", "longer, hotter boost"),
    "spread_shot": (build_spread_shot, "marginal spots", "3-way elite spread"),
    "shield_burst": (build_shield_burst, "warden eyespots", "shield on milestone"),
    "magnet_field": (build_magnet_field, "feather antennae", "huge pickup radius"),
    "overclock": (build_overclock, "heated thorax", "+fire rate, +heat"),
    "rear_gunner": (build_rear_gunner, "stinger", "aft cannon"),
    "drone_escort": (build_drone_escort, "mini butterflies", "companion drones"),
}

LOADOUTS = {
    "assault": ["twin_cannons", "rear_gunner", "hull_plating"],
    "aegis": ["shield_burst", "magnet_field", "spread_shot"],
}


def module_glb(name: str) -> Path:
    return ELITE_DIR / f"bf_elite_{name}.glb"


# ---------------------------------------------------------------------------
# Sheet + PNG exports
# ---------------------------------------------------------------------------


def build_sheet(hull_prims: list[hy.Primitive]) -> Image.Image:
    W, H = 1600, 1040
    img = Image.new("RGB", (W, H), px.VOID_BG)
    draw = px.ImageDraw.Draw(img)
    px.text(draw, (60, 36), "BUTTERFLY ELITES - ANATOMY-NATIVE MODULES", 26, px.UI_TEXT)
    px.text(
        draw,
        (60, 80),
        "every elite upgrade re-expressed as butterfly anatomy - hull and modules now share one design language",
        12, px.UI_DIM,
    )
    draw.line((60, 108, W - 60, 108), fill=px.VOID_HI, width=2)

    items = list(MODULES.items())
    cell_w, cell_h = 296, 226
    for i, (name, (_b, anatomy, effect)) in enumerate(items):
        gx = 60 + (i % 5) * cell_w
        gy = 132 + (i // 5) * cell_h
        px._panel(draw, (gx, gy, gx + cell_w - 16, gy + cell_h - 46), px.VOID_HI)
        sprite = hy.render_model(hy.load_glb(module_glb(name)), 54, pixel_style=True)
        big = px.upscale(sprite, 3)
        img.paste(big, (gx + (cell_w - 16 - big.width) // 2, gy + (cell_h - 46 - big.height) // 2), big)
        px.text(draw, (gx + 8, gy + cell_h - 40), f"{anatomy}", 10, px.UI_YELLOW)
        px.text(draw, (gx + 8, gy + cell_h - 24), effect, 10, px.UI_DIM)

    px.text(draw, (60, 606), "LOADOUTS - modules bolt onto the butterfly's own anatomy:", 13, px.UI_CYAN)
    blurbs = {
        "assault": "hornet clubs + stinger + wing scales",
        "aegis": "warden eyespots + feather antennae + marginal spots",
    }
    lx = 60
    for loadout, module_names in LOADOUTS.items():
        px._panel(draw, (lx, 642, lx + 740, 1000), px.UI_YELLOW)
        px.text(draw, (lx + 20, 660), loadout.upper(), 16, px.UI_YELLOW)
        px.text(draw, (lx + 20, 688), blurbs[loadout], 11, px.UI_DIM)
        combo = hull_prims
        for name in module_names:
            combo = combo + hy.load_glb(module_glb(name))
        combo_img = hy.render_model(combo, 82, pixel_style=True)
        big = px.upscale(combo_img, 3)
        img.paste(big, (lx + (740 - big.width) // 2, 712), big)
        lx += 800

    px.text(draw, (60, 1016), "MOCKUP V6 - BUTTERFLY ELITES", 10, px.UI_DIM)
    return img


def main() -> None:
    ELITE_DIR.mkdir(parents=True, exist_ok=True)
    PNG_DIR.mkdir(parents=True, exist_ok=True)

    for name, (builder, _anatomy, _effect) in MODULES.items():
        path = module_glb(name)
        stats = gm.export_glb(builder(), path)
        print(f"wrote {path.relative_to(ROOT)} ({stats['triangles']} tris)")

    hull_prims = hy.load_glb(ROOT / "assets" / "models" / "redesign" / "player_butterfly.glb")

    # standalone module PNGs
    for name in MODULES:
        sprite = hy.render_model(hy.load_glb(module_glb(name)), 64, pixel_style=True)
        px.upscale(sprite, 4).save(PNG_DIR / f"module_{name}.png")
    # loadout PNGs
    for loadout, module_names in LOADOUTS.items():
        combo = hull_prims
        for name in module_names:
            combo = combo + hy.load_glb(module_glb(name))
        sprite = hy.render_model(combo, 128, pixel_style=True)
        px.upscale(sprite, 4).save(PNG_DIR / f"butterfly_{loadout}_512.png")
    print(f"wrote {len(MODULES) + len(LOADOUTS)} standalone PNGs to mockups_v6/butterfly/elites/")

    sheet = build_sheet(hull_prims)
    sheet.save(OUT_DIR / "butterfly_elites_v6.png")
    print(f"wrote mockups_v6/butterfly_elites_v6.png ({sheet.width}x{sheet.height})")

    # in-game scene with the assault loadout
    assault_extra = [hy.load_glb(module_glb(n)) for n in LOADOUTS["assault"]]
    scene = bf_export.build_ingame_scene(player_extra_prims=assault_extra)
    scene.save(OUT_DIR / "butterfly" / "butterfly_ingame_elites_v6.png")
    print("wrote mockups_v6/butterfly/butterfly_ingame_elites_v6.png")


if __name__ == "__main__":
    main()
