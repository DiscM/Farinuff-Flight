#!/usr/bin/env python3
"""Butterfly-motif player ship redesign mockup (mockups_v6).

One hero direction: the player as a mechanical swallowtail butterfly, built
with the same Model toolkit as the production fleet and rendered through the
shipped pixel pipeline. The motif maps cleanly onto ship anatomy:

- antennae with glowing clubs  -> the twin muzzle hardpoints
- swallowtail hindwing streamers -> the engine pair (trails = streamers)
- wing eyespots                 -> sensor/targeting spots
- segmented abdomen             -> the cyan energy spine
- thorax saddle                 -> the blue canopy glass

Outputs:

- assets/models/redesign/player_butterfly.glb   the candidate hull
- mockups_v6/player_butterfly_v6.png            hero sheet with anatomy
  callouts, in-game scale check, showcase loadout, and colorways
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

import generate_hybrid_mockups as hy
import generate_mockup_models as gm
import generate_pixel_style_mockups as px


ROOT = Path(__file__).resolve().parents[1]
REDESIGN_DIR = ROOT / "assets" / "models" / "redesign"
OUT_DIR = ROOT / "mockups_v6"


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------


def build_butterfly(
    wing_mat: str = "steel",
    tip_mat: str = "silver",
    vein_mat: str = "dark",
    spot_mat: str = "cyan",
    spot_core_mat: str = "white",
    body_mat: str = "ivory",
    name: str = "player_butterfly",
    display: str = "PLAYER // SWALLOWTAIL",
) -> gm.Model:
    model = gm.Model(name, display)

    # Body: slim abdomen + thorax loft, nose (head) at -Z.
    model.add_loft(
        [
            (-1.60, 0.10, 0.04, 0.08),
            (-1.10, 0.17, 0.05, 0.13),
            (-0.40, 0.20, 0.06, 0.15),
            (0.50, 0.16, 0.04, 0.12),
            (1.20, 0.11, 0.02, 0.08),
            (1.90, 0.05, 0.00, 0.04),
        ],
        body_mat,
        "bf_body",
        6,
    )
    # Head + tiny cyan eyes.
    model.add_ellipsoid((0.0, 0.06, -1.62), (0.14, 0.10, 0.16), "dark", "bf_head", 3, 6)
    model.add_ellipsoid((-0.075, 0.13, -1.66), (0.045, 0.035, 0.05), "cyan", "bf_eye_l", 3, 5)
    model.add_ellipsoid((0.075, 0.13, -1.66), (0.045, 0.035, 0.05), "cyan", "bf_eye_r", 3, 5)

    # Antennae: thin plates sweeping forward-outward, glowing club tips.
    antenna = [(0.06, -1.70), (0.10, -1.70), (0.42, -2.62), (0.38, -2.62)]
    model.add_beveled_plate(antenna, 0.02, 0.07, "dark", "bf_antenna_r")
    model.add_beveled_plate(gm.mirrored(antenna), 0.02, 0.07, "dark", "bf_antenna_l")
    model.add_ellipsoid((0.40, 0.055, -2.64), (0.07, 0.05, 0.13), "cyan", "bf_club_r", 3, 6)
    model.add_ellipsoid((-0.40, 0.055, -2.64), (0.07, 0.05, 0.13), "cyan", "bf_club_l", 3, 6)

    # Forewings: big triangular upper wings.
    forewing = [
        (0.18, -0.85), (1.55, -1.30), (2.15, -0.95),
        (2.30, -0.45), (1.95, -0.02), (1.05, 0.28), (0.22, 0.10),
    ]
    model.add_beveled_plate(forewing, -0.06, 0.06, wing_mat, "bf_forewing_r")
    model.add_beveled_plate(gm.mirrored(forewing), -0.06, 0.06, wing_mat, "bf_forewing_l")
    # Forewing tip patch (the pale wing-tip band butterflies carry).
    foretip = [(1.35, -1.22), (2.15, -0.95), (2.30, -0.45), (1.85, -0.18), (1.30, -0.55)]
    model.add_beveled_plate(foretip, 0.06, 0.09, tip_mat, "bf_foretip_r")
    model.add_beveled_plate(gm.mirrored(foretip), 0.06, 0.09, tip_mat, "bf_foretip_l")
    # Two bold veins per forewing.
    vein1 = [(0.30, -0.75), (0.35, -0.72), (1.75, -1.10), (1.70, -1.14)]
    vein2 = [(0.32, -0.45), (0.37, -0.42), (1.85, -0.48), (1.82, -0.55)]
    for i, vein in enumerate((vein1, vein2)):
        model.add_beveled_plate(vein, 0.06, 0.08, vein_mat, f"bf_vein{i}_r")
        model.add_beveled_plate(gm.mirrored(vein), 0.06, 0.08, vein_mat, f"bf_vein{i}_l")

    # Hindwings: rounded lower wings with swallowtail streamers.
    hindwing = [
        (0.16, 0.10), (1.05, 0.28), (1.45, 0.65), (1.42, 1.05),
        (1.12, 1.30), (1.32, 1.85), (1.14, 1.88), (0.82, 1.28), (0.18, 0.90),
    ]
    model.add_beveled_plate(hindwing, -0.05, 0.05, wing_mat, "bf_hindwing_r")
    model.add_beveled_plate(gm.mirrored(hindwing), -0.05, 0.05, wing_mat, "bf_hindwing_l")

    # Eyespots on the hindwings: glowing ring + pale pupil.
    model.add_ellipsoid((0.92, 0.06, 0.85), (0.24, 0.04, 0.24), spot_mat, "bf_spot_r", 4, 8)
    model.add_ellipsoid((0.92, 0.075, 0.85), (0.11, 0.03, 0.11), spot_core_mat, "bf_pupil_r", 3, 6)
    model.add_ellipsoid((-0.92, 0.06, 0.85), (0.24, 0.04, 0.24), spot_mat, "bf_spot_l", 4, 8)
    model.add_ellipsoid((-0.92, 0.075, 0.85), (0.11, 0.03, 0.11), spot_core_mat, "bf_pupil_l", 3, 6)

    # Segmented abdomen = three cyan energy plates with gaps.
    for i, (z0, z1) in enumerate(((0.20, 0.45), (0.62, 0.87), (1.04, 1.29))):
        seg = [(-0.11, z0), (0.11, z0), (0.11, z1), (-0.11, z1)]
        model.add_beveled_plate(seg, 0.13, 0.20, "cyan", f"bf_abdomen_{i}")

    # Thorax saddle: the blue canopy glass.
    model.add_ellipsoid((0.0, 0.17, -0.55), (0.22, 0.14, 0.45), "blue", "bf_canopy", 4, 8)

    # Engines at the swallowtail streamer tips.
    model.add_engine(1.24, 0.0, 1.84, 0.34, 0.09, "cyan", "bf_engine_r")
    model.add_engine(-1.24, 0.0, 1.84, 0.34, 0.09, "cyan", "bf_engine_l")

    # Sockets: antennae clubs are the muzzles; wing roots take elite modules.
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.10, -1.80))
    model.add_socket("Socket_MuzzleLeft", (-0.40, 0.055, -2.72))
    model.add_socket("Socket_MuzzleRight", (0.40, 0.055, -2.72))
    model.add_socket("Socket_UpgradeLeft", (-0.62, 0.10, 0.20))
    model.add_socket("Socket_UpgradeRight", (0.62, 0.10, 0.20))
    model.add_socket("Socket_EngineLeft", (-1.24, 0.0, 2.21))
    model.add_socket("Socket_EngineRight", (1.24, 0.0, 2.21))

    # Bring overall length/span close to the current hull's (~4.2 long).
    model.scale_uniform(0.85)
    return model


COLORWAYS = [
    ("LACEWING", {}),
    ("MORPHO", {"wing_mat": "blue", "tip_mat": "silver", "vein_mat": "dark", "spot_mat": "white", "spot_core_mat": "cyan"}),
    ("MONARCH", {"wing_mat": "orange", "tip_mat": "dark", "vein_mat": "dark", "spot_mat": "white", "spot_core_mat": "yellow"}),
]


# ---------------------------------------------------------------------------
# Sheet
# ---------------------------------------------------------------------------


def build_sheet(butterfly_glb: Path, colorway_glbs: list[tuple[str, Path]]) -> Image.Image:
    W, H = 1600, 1000
    img = Image.new("RGB", (W, H), px.VOID_BG)
    draw = px.ImageDraw.Draw(img)
    px.text(draw, (60, 36), "PLAYER REDESIGN - THE SWALLOWTAIL", 28, px.UI_TEXT)
    px.text(
        draw,
        (60, 82),
        "a butterfly-motif hull, built as real geometry and rendered through the shipped pixel pipeline",
        13, px.UI_DIM,
    )
    draw.line((60, 110, W - 60, 110), fill=px.VOID_HI, width=2)

    # --- hero render with anatomy callouts -----------------------------------
    px._panel(draw, (60, 132, 700, 940), px.UI_CYAN)
    prims = hy.load_glb(butterfly_glb)
    hero = hy.render_model(prims, 120, pixel_style=True)
    hero_big = px.upscale(hero, 4)
    hx, hy_ = 60 + (640 - hero_big.width) // 2, 190
    img.paste(hero_big, (hx, hy_), hero_big)

    # Callouts in sheet coordinates (hand-tuned to the hero render).
    callouts = [
        ("antenna clubs = muzzles", (420, 245), (480, 165), px.UI_CYAN),
        ("forewing + tip band", (208, 375), (85, 300), px.UI_TEXT),
        ("thorax canopy", (360, 388), (85, 445), px.hx("#8FD4F8")),
        ("eyespot sensors", (438, 503), (505, 470), px.hx("#7FFFD4")),
        ("abdomen energy segments", (363, 512), (85, 650), px.UI_CYAN),
        ("swallowtail streamers = engines", (452, 606), (445, 690), px.UI_CYAN),
    ]
    for label, (ax, ay), (tx, ty), color in callouts:
        draw.line((tx, ty, ax, ay), fill=color, width=1)
        draw.rectangle((ax - 2, ay - 2, ax + 2, ay + 2), outline=color)
        px.text(draw, (tx, ty - 6), label, 10, color)

    # --- right column: anatomy map --------------------------------------------
    px._panel(draw, (740, 132, 1540, 420), px.UI_YELLOW)
    px.text(draw, (764, 150), "ANATOMY MAP", 15, px.UI_YELLOW)
    anatomy = [
        "butterfly part        ship function",
        "",
        "antennae + clubs      twin muzzles (shots from the clubs)",
        "forewings             main lift surface, upgrade deck",
        "hindwing eyespots     targeting sensors (glow on lock)",
        "abdomen segments      cyan energy spine, pulse on boost",
        "swallowtail tails     engine pair - trails ARE streamers",
        "thorax saddle         canopy glass, hit-flash surface",
        "wing tip bands        pale counter-shading for readability",
    ]
    for i, line in enumerate(anatomy):
        px.text(draw, (764, 186 + i * 26), line, 11, px.UI_DIM if i < 2 else px.UI_TEXT)

    # --- in-game scale check ---------------------------------------------------
    px._panel(draw, (740, 444, 1130, 700), px.UI_GREEN)
    px.text(draw, (764, 462), "READS AT GAME SIZE", 14, px.UI_GREEN)
    small = hy.render_model(prims, 30, pixel_style=True)
    img.paste(px.upscale(small, 2), (790, 520), px.upscale(small, 2))
    px.text(draw, (790, 600), "wave combat size", 9, px.UI_DIM)
    mid = hy.render_model(prims, 56, pixel_style=True)
    img.paste(px.upscale(mid, 2), (940, 500), px.upscale(mid, 2))
    px.text(draw, (940, 640), "menu / close-up", 9, px.UI_DIM)

    # --- showcase loadout -------------------------------------------------------
    px._panel(draw, (1154, 444, 1540, 700), px.UI_PINK)
    px.text(draw, (1178, 462), "SHOWCASE LOADOUT", 14, px.UI_PINK)
    combo = prims + hy.load_glb(hy.MODELS_DIR / "player_upgrade_twin_cannons.glb") \
        + hy.load_glb(hy.MODELS_DIR / "player_upgrade_shield_burst.glb")
    combo_img = hy.render_model(combo, 62, pixel_style=True)
    combo_big = px.upscale(combo_img, 3)
    img.paste(combo_big, (1154 + (386 - combo_big.width) // 2, 486), combo_big)
    px.text(draw, (1178, 676), "twin cannons + shield burst", 9, px.UI_DIM)

    # --- colorways ----------------------------------------------------------------
    px._panel(draw, (740, 724, 1540, 940), px.VOID_HI)
    px.text(draw, (764, 742), "COLORWAYS (same geometry)", 14, px.UI_TEXT)
    notes = [
        "default - player ivory/cyan",
        "blue wings - calm, icy",
        "orange - bold, but shares fast-enemy hue",
    ]
    for i, ((cname, _params), note) in enumerate(zip(COLORWAYS, notes)):
        glb = butterfly_glb if i == 0 else colorway_glbs[i - 1][1]
        cprims = hy.load_glb(glb)
        sprite = hy.render_model(cprims, 58, pixel_style=True)
        big = px.upscale(sprite, 2)
        bx = 790 + i * 250
        img.paste(big, (bx, 780), big)
        px.text(draw, (bx, 900), cname, 11, px.UI_YELLOW)
        px.text(draw, (bx, 916), note, 9, px.UI_DIM)

    px.text(draw, (60, 962), "MOCKUP V6 - BUTTERFLY PLAYER", 10, px.UI_DIM)
    return img


# ---------------------------------------------------------------------------


def main() -> None:
    REDESIGN_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    hero_path = REDESIGN_DIR / "player_butterfly.glb"
    stats = gm.export_glb(build_butterfly(), hero_path)
    print(f"wrote {hero_path.relative_to(ROOT)} ({stats['triangles']} tris)")

    colorway_glbs: list[tuple[str, Path]] = []
    for cname, params in COLORWAYS[1:]:
        path = REDESIGN_DIR / f"player_butterfly_{cname.lower()}.glb"
        model = build_butterfly(
            name=f"player_butterfly_{cname.lower()}",
            display=f"PLAYER // SWALLOWTAIL {cname}",
            **params,
        )
        gm.export_glb(model, path)
        colorway_glbs.append((cname, path))
        print(f"wrote {path.relative_to(ROOT)}")

    sheet = build_sheet(hero_path, colorway_glbs)
    sheet.save(OUT_DIR / "player_butterfly_v6.png")
    print(f"wrote mockups_v6/player_butterfly_v6.png ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
