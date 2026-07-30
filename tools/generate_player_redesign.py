#!/usr/bin/env python3
"""Player ship + elite upgrade redesign mockups (mockups_v6).

Three redesign directions for the player hull, built as real geometry with
the same Model toolkit as the production fleet (tools/generate_mockup_models.py),
exported as drop-in GLB candidates (assets/models/redesign/), and rendered
through the pixel-hybrid pipeline (tools/generate_hybrid_mockups.py) so the
mockups show exactly what each direction looks like in the shipped style.

Outputs:

- assets/models/redesign/*.glb        the three candidate hulls
- mockups_v6/player_redesign_v6.png   the three directions, compared
- mockups_v6/elite_upgrades_matrix_v6.png  every elite module in pixel style
  plus three themed loadouts bolted onto the recommended hull
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
# The three redesign directions
# ---------------------------------------------------------------------------


def build_variant_a() -> gm.Model:
    """STARLANCE Mk III — evolution of the current hull. Same footprint and
    socket layout, so every existing elite module bolts on unchanged."""
    model = gm.Model("player_redesign_a", "REDESIGN A // STARLANCE Mk III")
    model.add_loft(
        [
            (-2.60, 0.04, 0.00, 0.04),
            (-2.00, 0.22, 0.03, 0.17),
            (-1.00, 0.40, 0.05, 0.26),
            (0.20, 0.40, 0.03, 0.27),
            (1.10, 0.30, 0.00, 0.22),
            (1.70, 0.14, -0.02, 0.12),
        ],
        "ivory",
        "a_fuselage",
        6,
    )
    # Forward-swept wing tips: the silhouette signature (no enemy sweeps forward).
    wing = [(0.30, -0.45), (1.50, -1.28), (2.00, -0.95), (1.30, 0.60), (0.40, 0.50)]
    model.add_beveled_plate(wing, -0.16, 0.10, "steel", "a_wing_right")
    model.add_beveled_plate(gm.mirrored(wing), -0.16, 0.10, "steel", "a_wing_left")
    # Horizontal stabilizers at the tail.
    stab = [(0.35, 1.05), (1.10, 1.55), (0.95, 1.70), (0.35, 1.40)]
    model.add_beveled_plate(stab, -0.10, 0.02, "silver", "a_stab_right")
    model.add_beveled_plate(gm.mirrored(stab), -0.10, 0.02, "silver", "a_stab_left")
    model.add_loft(
        [
            (-1.55, 0.05, 0.24, 0.035),
            (-1.10, 0.20, 0.32, 0.14),
            (-0.30, 0.24, 0.37, 0.18),
            (0.35, 0.16, 0.33, 0.12),
            (0.62, 0.04, 0.26, 0.035),
        ],
        "blue",
        "a_canopy",
        6,
    )
    spine = [(-0.10, -0.10), (0.10, -0.10), (0.13, 1.20), (0.0, 1.45), (-0.13, 1.20)]
    model.add_beveled_plate(spine, 0.24, 0.34, "cyan", "a_energy_spine", 0.78)
    gm.add_engine_pair(model, 0.27, -0.02, 1.15, 0.55, 0.18, "cyan", "a_engine")
    # Socket layout preserved from the current hull.
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.08, -2.66))
    model.add_socket("Socket_MuzzleLeft", (-1.01, 0.18, -0.42))
    model.add_socket("Socket_MuzzleRight", (1.01, 0.18, -0.42))
    model.add_socket("Socket_UpgradeLeft", (-1.25, 0.18, 0.28))
    model.add_socket("Socket_UpgradeRight", (1.25, 0.18, 0.28))
    return model


def build_variant_b() -> gm.Model:
    """BULWARK RUNNER — twin-boom gunship. H-shaped footprint, broad deck:
    the most upgrade real estate and the chunkiest silhouette."""
    model = gm.Model("player_redesign_b", "REDESIGN B // BULWARK RUNNER")
    model.add_loft(
        [
            (-1.90, 0.06, 0.02, 0.06),
            (-1.30, 0.34, 0.06, 0.24),
            (-0.30, 0.52, 0.08, 0.30),
            (0.70, 0.46, 0.04, 0.26),
            (1.30, 0.22, 0.00, 0.14),
        ],
        "ivory",
        "b_fuselage",
        6,
    )
    # Twin booms flanking the fuselage.
    boom = [(0.85, -1.40), (1.25, -1.40), (1.30, 1.40), (0.90, 1.50)]
    model.add_beveled_plate(boom, -0.12, 0.14, "steel", "b_boom_right")
    model.add_beveled_plate(gm.mirrored(boom), -0.12, 0.14, "steel", "b_boom_left")
    # Broad deck wing bridging fuselage and booms.
    deck = [(0.30, -0.60), (1.30, -0.50), (1.35, 0.50), (0.30, 0.70)]
    model.add_beveled_plate(deck, -0.04, 0.12, "silver", "b_deck_right")
    model.add_beveled_plate(gm.mirrored(deck), -0.04, 0.12, "silver", "b_deck_left")
    # Hardpoint studs on the deck: visible upgrade sockets.
    for sx in (0.62, 1.06):
        for sz in (-0.25, 0.35):
            stud = [(sx - 0.07, sz - 0.07), (sx + 0.07, sz - 0.07),
                    (sx + 0.07, sz + 0.07), (sx - 0.07, sz + 0.07)]
            model.add_beveled_plate(stud, 0.12, 0.19, "dark", f"b_stud_{sx}_{sz}")
            model.add_beveled_plate(gm.mirrored(stud), 0.12, 0.19, "dark", f"b_stud_m{sx}_{sz}")
    model.add_ellipsoid((0.0, 0.30, -0.72), (0.28, 0.16, 0.42), "blue", "b_canopy", 4, 8)
    nose_bus = [(-0.16, -1.62), (0.16, -1.62), (0.12, -1.30), (-0.12, -1.30)]
    model.add_beveled_plate(nose_bus, 0.06, 0.14, "yellow", "b_nose_bus", 0.9)
    gm.add_engine_pair(model, 1.05, 0.01, 1.42, 0.42, 0.20, "cyan", "b_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.10, -1.96))
    model.add_socket("Socket_MuzzleLeft", (-1.05, 0.16, -1.44))
    model.add_socket("Socket_MuzzleRight", (1.05, 0.16, -1.44))
    model.add_socket("Socket_UpgradeLeft", (-0.68, 0.20, 0.05))
    model.add_socket("Socket_UpgradeRight", (0.68, 0.20, 0.05))
    return model


def build_variant_c() -> gm.Model:
    """NEEDLE — minimal long lancer. Longest silhouette, tiny clipped wings,
    rear gyro ring: the elegant outlier."""
    model = gm.Model("player_redesign_c", "REDESIGN C // NEEDLE")
    model.add_loft(
        [
            (-3.40, 0.03, 0.00, 0.03),
            (-2.40, 0.13, 0.02, 0.10),
            (-1.20, 0.24, 0.04, 0.17),
            (-0.10, 0.26, 0.03, 0.18),
            (0.80, 0.20, 0.00, 0.13),
            (1.30, 0.10, -0.02, 0.07),
        ],
        "ivory",
        "c_fuselage",
        6,
    )
    # Tiny clipped delta, far back.
    wing = [(0.22, 0.35), (1.15, 1.25), (0.90, 1.45), (0.26, 1.05)]
    model.add_beveled_plate(wing, -0.08, 0.04, "steel", "c_wing_right")
    model.add_beveled_plate(gm.mirrored(wing), -0.08, 0.04, "steel", "c_wing_left")
    # Gyro ring ahead of the tail (flattened torus reads as a ring top-down).
    model.add_ellipsoid((0.0, 0.02, 0.95), (0.58, 0.07, 0.58), "silver", "c_gyro_ring", 4, 12)
    model.add_ellipsoid((0.0, 0.20, -0.42), (0.20, 0.13, 0.38), "blue", "c_canopy", 4, 8)
    rail = [(-0.07, -2.60), (0.07, -2.60), (0.09, 0.60), (-0.09, 0.60)]
    model.add_beveled_plate(rail, 0.16, 0.24, "cyan", "c_rail", 0.85)
    # Single centerline engine (a pair would overlap at x=0).
    model.add_engine(0.0, -0.02, 1.32, 0.40, 0.15, "cyan", "c_engine")
    model.add_socket("Socket_EngineCenter", (0.0, -0.02, 1.75))
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.06, -3.46))
    model.add_socket("Socket_MuzzleLeft", (-0.60, 0.10, 1.10))
    model.add_socket("Socket_MuzzleRight", (0.60, 0.10, 1.10))
    model.add_socket("Socket_UpgradeLeft", (-0.72, 0.10, 0.70))
    model.add_socket("Socket_UpgradeRight", (0.72, 0.10, 0.70))
    return model


VARIANTS = {
    "a": (build_variant_a, "STARLANCE Mk III", "evolution - keeps every current module",
          "forward-swept tips, twin stabilizers; same sockets, zero code churn"),
    "b": (build_variant_b, "BULWARK RUNNER", "twin-boom gunship - upgrade platform",
          "h-footprint reads chunky at 25px; deck studs show where elites bolt on"),
    "c": (build_variant_c, "NEEDLE", "minimal lancer - speed identity",
          "longest silhouette in the game; gyro ring + rail, fragile-elegant"),
}


# ---------------------------------------------------------------------------
# Primitive helpers for module re-posing on the variant hulls
# ---------------------------------------------------------------------------


def transformed(prims: list[hy.Primitive], sx: float = 1.0, sy: float = 1.0,
                sz: float = 1.0, dx: float = 0.0, dy: float = 0.0, dz: float = 0.0,
                ) -> list[hy.Primitive]:
    out: list[hy.Primitive] = []
    for prim in prims:
        positions = [
            (p[0] * sx + dx, p[1] * sy + dy, p[2] * sz + dz) for p in prim.positions
        ]
        out.append(hy.Primitive(positions, prim.normals, prim.indices, prim.base, prim.emissive))
    return out


def upgrade(name: str) -> list[hy.Primitive]:
    return hy.load_glb(hy.MODELS_DIR / f"player_upgrade_{name}.glb")


UPGRADE_EFFECTS = {
    "twin_cannons": "doubled forward fire",
    "auto_aim": "shots track targets",
    "hull_plating": "+2 max lives armor",
    "afterburner": "longer, hotter boost",
    "spread_shot": "3-way elite spread",
    "shield_burst": "shield on milestone",
    "magnet_field": "huge pickup radius",
    "overclock": "+fire rate, +heat",
    "rear_gunner": "aft cannon",
    "drone_escort": "companion drones",
}


# ---------------------------------------------------------------------------
# Sheet 1 — the three directions
# ---------------------------------------------------------------------------


def build_redesign_sheet(variant_glbs: dict[str, Path]) -> Image.Image:
    W, H = 1600, 1060
    img = Image.new("RGB", (W, H), px.VOID_BG)
    draw = px.ImageDraw.Draw(img)
    px.text(draw, (60, 36), "PLAYER REDESIGN - THREE DIRECTIONS", 28, px.UI_TEXT)
    px.text(
        draw,
        (60, 82),
        "real glb candidates in assets/models/redesign/, rendered through the shipped pixel pipeline",
        13, px.UI_DIM,
    )
    draw.line((60, 110, W - 60, 110), fill=px.VOID_HI, width=2)

    showcases = {
        "a": [("twin_cannons", {}), ("afterburner", {})],
        "b": [("twin_cannons", {"sx": 1.22, "dz": 0.3}), ("hull_plating", {"sx": 1.1, "dz": 0.2})],
        "c": [("twin_cannons", {"sx": 0.55, "dz": 0.9}), ("auto_aim", {"dz": 0.4})],
    }

    col_x = [60, 573, 1086]
    for (key, (_builder, name, tagline, note)), x in zip(VARIANTS.items(), col_x):
        border = px.UI_CYAN if key == "a" else px.VOID_HI
        px._panel(draw, (x, 132, x + 454, 850), border)
        px.text(draw, (x + 22, 150), f"{key.upper()} / {name}", 16, px.UI_YELLOW)
        px.text(draw, (x + 22, 180), tagline, 11, px.UI_CYAN)

        prims = hy.load_glb(variant_glbs[key])
        hull = hy.render_model(prims, 96, pixel_style=True)
        big = px.upscale(hull, 3)
        img.paste(big, (x + (454 - big.width) // 2, 204), big)

        combo = prims
        for module_name, tf in showcases[key]:
            combo = combo + transformed(upgrade(module_name), **tf)
        combo_img = hy.render_model(combo, 96, pixel_style=True)
        combo_big = px.upscale(combo_img, 3)
        px.text(draw, (x + 22, 502), "showcase: " + " + ".join(n for n, _ in showcases[key]).replace("_", " "), 10, px.UI_DIM)
        img.paste(combo_big, (x + (454 - combo_big.width) // 2, 528), combo_big)
        px.text(draw, (x + 22, 822), note, 10, px.UI_TEXT)

    px.text(draw, (60, 880), "SILHOUETTE READ", 14, px.UI_CYAN)
    reads = [
        "A: safe evolution - elongated dart, tips sweep forward (unique vs enemies)",
        "B: heavy platform - widest deck, reads 'gunship', most hardpoint space",
        "C: purist speedform - longest, thinnest; ring reads instantly at 25px",
    ]
    for i, line in enumerate(reads):
        px.text(draw, (60, 912 + i * 28), line, 12, px.UI_TEXT)

    px._panel(draw, (60, 1000, 1540, 1038), px.UI_GREEN)
    px.text(draw, (84, 1010), "RECOMMENDATION: A as the new default hull (zero module rework) + B's deck studs as hardpoint language", 12, px.UI_GREEN)
    px.text(draw, (60, 1046), "MOCKUP V6 - PLAYER REDESIGN", 10, px.UI_DIM)
    return img


# ---------------------------------------------------------------------------
# Sheet 2 — elite upgrade matrix
# ---------------------------------------------------------------------------


def build_upgrades_sheet(variant_glbs: dict[str, Path]) -> Image.Image:
    W, H = 1600, 1040
    img = Image.new("RGB", (W, H), px.VOID_BG)
    draw = px.ImageDraw.Draw(img)
    px.text(draw, (60, 36), "ELITE UPGRADES - THE MODULE CATALOG", 28, px.UI_TEXT)
    px.text(
        draw,
        (60, 82),
        "every elite module rendered in the pixel style, then three themed loadouts on hull A",
        13, px.UI_DIM,
    )
    draw.line((60, 110, W - 60, 110), fill=px.VOID_HI, width=2)

    modules = list(UPGRADE_EFFECTS.items())
    cell_w, cell_h = 296, 226
    grid_x, grid_y = 60, 132
    for i, (module_name, effect) in enumerate(modules):
        gx = grid_x + (i % 5) * cell_w
        gy = grid_y + (i // 5) * cell_h
        px._panel(draw, (gx, gy, gx + cell_w - 16, gy + cell_h - 46), px.VOID_HI)
        if module_name == "drone_escort":
            prims = hy.load_glb(hy.MODELS_DIR / "player_drone_escort.glb")
        else:
            prims = upgrade(module_name)
        sprite = hy.render_model(prims, 54, pixel_style=True)
        big = px.upscale(sprite, 3)
        img.paste(big, (gx + (cell_w - 16 - big.width) // 2, gy + (cell_h - 46 - big.height) // 2), big)
        px.text(draw, (gx + 8, gy + cell_h - 40), module_name.replace("_", " "), 10, px.UI_YELLOW)
        px.text(draw, (gx + 8, gy + cell_h - 24), effect, 10, px.UI_DIM)

    # themed loadouts on hull A
    px.text(draw, (60, 604), "LOADOUTS ON HULL A - modules share the hull's model space, so combos just work:", 13, px.UI_CYAN)
    loadouts = [
        ("ASSAULT", ["twin_cannons", "rear_gunner", "hull_plating"], "double fire + aft cover + armor"),
        ("VELOCITY", ["afterburner", "overclock", "auto_aim"], "boost + fire rate + tracking"),
        ("AEGIS", ["shield_burst", "magnet_field", "spread_shot"], "shield + magnet + 3-way"),
    ]
    hull_prims = hy.load_glb(variant_glbs["a"])
    lx = 60
    for name, module_names, blurb in loadouts:
        px._panel(draw, (lx, 640, lx + 494, 1000), px.UI_YELLOW)
        px.text(draw, (lx + 20, 656), name, 16, px.UI_YELLOW)
        px.text(draw, (lx + 20, 684), blurb, 11, px.UI_DIM)
        combo = hull_prims
        for module_name in module_names:
            combo = combo + upgrade(module_name)
        combo_img = hy.render_model(combo, 82, pixel_style=True)
        big = px.upscale(combo_img, 3)
        img.paste(big, (lx + (494 - big.width) // 2, 712), big)
        px.text(draw, (lx + 20, 972), "+ ".join(n.replace("_", " ") for n in module_names), 10, px.UI_TEXT)
        lx += 524

    px.text(draw, (60, 1014), "MOCKUP V6 - ELITE UPGRADE MATRIX", 10, px.UI_DIM)
    return img


# ---------------------------------------------------------------------------


def main() -> None:
    REDESIGN_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    variant_glbs: dict[str, Path] = {}
    for key, (builder, _name, _tag, _note) in VARIANTS.items():
        model = builder()
        path = REDESIGN_DIR / f"player_redesign_{key}.glb"
        stats = gm.export_glb(model, path)
        print(f"wrote {path.relative_to(ROOT)} ({stats['triangles']} tris)")
        variant_glbs[key] = path

    redesign = build_redesign_sheet(variant_glbs)
    redesign.save(OUT_DIR / "player_redesign_v6.png")
    print(f"wrote mockups_v6/player_redesign_v6.png ({redesign.width}x{redesign.height})")

    matrix = build_upgrades_sheet(variant_glbs)
    matrix.save(OUT_DIR / "elite_upgrades_matrix_v6.png")
    print(f"wrote mockups_v6/elite_upgrades_matrix_v6.png ({matrix.width}x{matrix.height})")


if __name__ == "__main__":
    main()
