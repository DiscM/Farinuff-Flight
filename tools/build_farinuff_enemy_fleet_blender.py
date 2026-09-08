#!/usr/bin/env python3
"""Build the next-round Farinuff enemy fleet in Blender.

Run this file from Blender. It creates a reusable .blend source, five individual
GLB exports, five presentation renders, and one fleet lineup render. The models
translate the approved raster mockups into original low-poly game geometry.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_farinuff_kestrel_blender import (  # noqa: E402
    add_area_light,
    assign_material,
    collection,
    finish_mesh,
    look_at,
    make_box,
    make_cylinder,
    make_ico,
    make_material,
    make_prism,
    make_ridged_hull,
    make_socket,
    mirrored,
    move_to_collection,
    reset_scene,
)


SOURCE_PATH = ROOT / "assets/models/redesign/sources/farinuff_next_round_enemy_fleet.blend"
MODEL_DIR = ROOT / "assets/models/redesign/next_round"
PREVIEW_DIR = ROOT / "renders/drafts/next-round-3d-models"
MANIFEST_PATH = MODEL_DIR / "manifest.json"

REFERENCE_DIR = ROOT / "renders/drafts/next-round-3d-concepts"
REFERENCES = {
    "basic_enemy": REFERENCE_DIR / "basic-enemy.png",
    "fast_enemy": REFERENCE_DIR / "fast-enemy.png",
    "bomber_enemy": REFERENCE_DIR / "bomber-enemy-core-variant.png",
    "sniper_enemy": REFERENCE_DIR / "sniper-enemy.png",
    "tank_enemy": REFERENCE_DIR / "tank-enemy.png",
}

EXPECTED_SOCKET_NAMES = {
    "basic_enemy": {"Socket_EngineLeft", "Socket_EngineRight", "Socket_Muzzle"},
    "fast_enemy": {"Socket_EngineLeft", "Socket_EngineRight", "Socket_Muzzle"},
    "bomber_enemy": {
        "Socket_EngineLeft", "Socket_EngineRight", "Socket_Muzzle",
        "Socket_PayloadLeft", "Socket_PayloadRight",
    },
    "sniper_enemy": {
        "Socket_Aperture", "Socket_EngineLeft", "Socket_EngineRight", "Socket_Muzzle",
    },
    "tank_enemy": {
        "Socket_EngineLeft", "Socket_EngineRight", "Socket_Muzzle",
        "Socket_WeaponLeft", "Socket_WeaponRight",
    },
}


def palette(prefix: str, hull, accent, energy, energy_strength=6.0):
    return {
        "hull": make_material(f"{prefix}_Hull", (*hull, 1.0), 0.72, 0.30),
        "armor": make_material(
            f"{prefix}_Armor",
            tuple(min(1.0, c * 1.18) for c in hull) + (1.0,),
            0.82,
            0.24,
        ),
        "accent": make_material(f"{prefix}_Accent", (*accent, 1.0), 0.52, 0.28),
        "dark": make_material(f"{prefix}_Void", (0.025, 0.035, 0.060, 1.0), 0.80, 0.25),
        "metal": make_material(f"{prefix}_Gunmetal", (0.12, 0.16, 0.22, 1.0), 0.90, 0.24),
        "energy": make_material(
            f"{prefix}_Energy",
            (*energy, 1.0),
            0.10,
            0.16,
            energy,
            energy_strength,
        ),
        "hot": make_material(
            f"{prefix}_HotCore",
            (1.0, 0.92, 0.72, 1.0),
            0.0,
            0.12,
            (1.0, 0.52, 0.08),
            energy_strength + 2.0,
        ),
        "cyan": make_material(
            f"{prefix}_CyanSystems",
            (0.04, 0.55, 0.88, 1.0),
            0.08,
            0.18,
            (0.01, 0.40, 0.82),
            5.0,
        ),
    }


def clear_scene_for_interactive_build():
    """Clear scene data without resetting Blender's active UI/console context."""
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for child in list(bpy.context.scene.collection.children):
        bpy.context.scene.collection.children.unlink(child)
        bpy.data.collections.remove(child)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.worlds,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def root_object(asset, name: str, role: str, reference: Path):
    root = bpy.data.objects.new(name, None)
    asset.objects.link(root)
    root["asset_name"] = name
    root["asset_role"] = role
    root["license"] = "project-original"
    root["reference_image"] = str(reference.relative_to(ROOT))
    root["orientation"] = "+Y nose; XY combat plane; Z height"
    root["art_direction"] = "faceted low-poly hard-surface spacecraft; readable top-down silhouette"
    return root


def torus(name, location, major_radius, minor_radius, material, asset, root, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD",
        major_segments=16,
        minor_segments=6,
        location=location,
        rotation=rotation,
        major_radius=major_radius,
        minor_radius=minor_radius,
    )
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, asset, root, material)


def wedge(name, location, scale, rotation, material, asset, root):
    """A bevelled box kept angular enough to read as layered armor."""
    return make_box(name, location, scale, rotation, material, asset, root, min(scale) * 0.16)


def reactor(name, location, radius, mats, asset, root, color_key="energy"):
    torus(f"{name}_OuterRing", location, radius, radius * 0.17, mats["metal"], asset, root)
    torus(
        f"{name}_GlowRing",
        (location[0], location[1], location[2] + 0.025),
        radius * 0.72,
        radius * 0.10,
        mats[color_key],
        asset,
        root,
    )
    make_ico(
        f"{name}_Core",
        (location[0], location[1], location[2] + 0.035),
        (radius * 0.52, radius * 0.52, radius * 0.24),
        mats["hot"] if color_key == "energy" else mats[color_key],
        asset,
        root,
        2,
    )
    for index in range(8):
        angle = index * math.tau / 8.0
        x = location[0] + math.cos(angle) * radius * 1.15
        y = location[1] + math.sin(angle) * radius * 1.15
        wedge(
            f"{name}_Clamp_{index + 1}",
            (x, y, location[2]),
            (radius * 0.13, radius * 0.24, radius * 0.10),
            (0.0, 0.0, angle + math.pi / 2.0),
            mats["dark"],
            asset,
            root,
        )


def engine(name, x, y, z, radius, length, mats, asset, root, glow="energy"):
    make_cylinder(
        f"{name}_Housing", (x, y, z), radius, length, mats["metal"], asset, root,
        vertices=10, bevel=radius * 0.10,
    )
    make_cylinder(
        f"{name}_Collar", (x, y - length * 0.37, z), radius * 1.07, length * 0.16,
        mats["dark"], asset, root, vertices=10,
    )
    make_cylinder(
        f"{name}_Glow", (x, y - length * 0.55, z), radius * 0.63, length * 0.10,
        mats[glow], asset, root, vertices=10,
    )


def vent_bank(prefix, x, y, z, count, mats, asset, root, horizontal=True):
    for index in range(count):
        if horizontal:
            location = (x, y + index * 0.14, z)
            scale = (0.16, 0.045, 0.025)
        else:
            location = (x + index * 0.14, y, z)
            scale = (0.045, 0.16, 0.025)
        make_box(f"{prefix}_Vent_{index + 1}", location, scale, (0.0, 0.0, 0.0), mats["dark"], asset, root)


def build_basic(asset):
    ref = REFERENCES["basic_enemy"]
    root = root_object(asset, "ENEMY // REDJACK Mk II", "basic_enemy", ref)
    m = palette("Redjack", (0.64, 0.025, 0.035), (1.0, 0.15, 0.015), (1.0, 0.18, 0.01), 6.5)

    make_ridged_hull(
        "Redjack_MainHull",
        [(2.90, 0.03, 0.06, 0.11, -0.12), (2.18, 0.34, 0.18, 0.28, -0.19),
         (1.15, 0.78, 0.30, 0.48, -0.26), (0.10, 0.92, 0.34, 0.54, -0.29),
         (-0.92, 0.68, 0.23, 0.38, -0.25), (-1.78, 0.37, 0.12, 0.23, -0.18),
         (-2.25, 0.18, 0.06, 0.12, -0.12)],
        m["hull"], asset, root,
    )
    wing_r = [(0.62, 1.30), (1.48, 0.90), (2.38, 0.08), (2.12, -0.72), (1.18, -0.28), (0.72, 0.24)]
    make_prism("Redjack_Wing_R", wing_r, -0.19, 0.15, m["hull"], asset, root, 0.045)
    make_prism("Redjack_Wing_L", mirrored(wing_r), -0.19, 0.15, m["hull"], asset, root, 0.045)
    armor_r = [(0.78, 1.06), (1.36, 0.76), (2.02, 0.18), (1.56, -0.22), (0.80, 0.18)]
    make_prism("Redjack_Armor_R", armor_r, 0.15, 0.29, m["armor"], asset, root, 0.025)
    make_prism("Redjack_Armor_L", mirrored(armor_r), 0.15, 0.29, m["armor"], asset, root, 0.025)
    inset_r = [(1.22, 0.68), (1.62, 0.40), (1.95, 0.12), (1.66, -0.08), (1.28, 0.18)]
    make_prism("Redjack_EmberInset_R", inset_r, 0.285, 0.33, m["accent"], asset, root, 0.012)
    make_prism("Redjack_EmberInset_L", mirrored(inset_r), 0.285, 0.33, m["accent"], asset, root, 0.012)
    nose_r = [(0.08, 2.84), (0.25, 2.02), (0.45, 1.28), (0.16, 1.48)]
    make_prism("Redjack_NoseBlade_R", nose_r, 0.26, 0.38, m["accent"], asset, root, 0.018)
    make_prism("Redjack_NoseBlade_L", mirrored(nose_r), 0.26, 0.38, m["accent"], asset, root, 0.018)
    reactor("Redjack_Reactor", (0.0, 0.32, 0.53), 0.48, m, asset, root)
    tail_r = [(0.42, -0.72), (1.02, -1.92), (0.70, -2.28), (0.32, -1.18)]
    make_prism("Redjack_TailSpear_R", tail_r, -0.04, 0.22, m["dark"], asset, root, 0.025)
    make_prism("Redjack_TailSpear_L", mirrored(tail_r), -0.04, 0.22, m["dark"], asset, root, 0.025)
    for side, x in (("L", -0.62), ("R", 0.62)):
        engine(f"Redjack_Engine_{side}", x, -1.42, 0.05, 0.27, 0.72, m, asset, root)
    vent_bank("Redjack", 0.0, -1.18, 0.40, 4, m, asset, root)
    make_socket("Socket_Muzzle", (0.0, 2.98, 0.12), asset, root)
    make_socket("Socket_EngineLeft", (-0.62, -1.84, 0.05), asset, root)
    make_socket("Socket_EngineRight", (0.62, -1.84, 0.05), asset, root)
    return root


def build_fast(asset):
    ref = REFERENCES["fast_enemy"]
    root = root_object(asset, "ENEMY // RAZORWING", "fast_enemy", ref)
    m = palette("Razorwing", (0.86, 0.07, 0.01), (1.0, 0.27, 0.005), (0.10, 0.78, 1.0), 5.5)

    make_ridged_hull(
        "Razorwing_MainDart",
        [(4.15, 0.015, 0.02, 0.06, -0.07), (3.20, 0.16, 0.12, 0.24, -0.14),
         (1.65, 0.34, 0.20, 0.38, -0.20), (0.20, 0.46, 0.24, 0.44, -0.22),
         (-1.55, 0.33, 0.16, 0.30, -0.18), (-3.08, 0.16, 0.08, 0.18, -0.12),
         (-4.12, 0.02, 0.02, 0.05, -0.07)],
        m["hull"], asset, root,
    )
    blade_r = [(0.18, 3.55), (0.62, 1.34), (0.78, -2.86), (0.30, -3.62), (0.16, -0.42)]
    make_prism("Razorwing_SpineBlade_R", blade_r, 0.18, 0.34, m["accent"], asset, root, 0.018)
    make_prism("Razorwing_SpineBlade_L", mirrored(blade_r), 0.18, 0.34, m["hull"], asset, root, 0.018)
    fin_r = [(0.38, 0.62), (1.20, 0.18), (1.24, -0.34), (0.42, -0.10)]
    make_prism("Razorwing_Fin_R", fin_r, -0.10, 0.13, m["accent"], asset, root, 0.025)
    make_prism("Razorwing_Fin_L", mirrored(fin_r), -0.10, 0.13, m["accent"], asset, root, 0.025)
    tail_fin_r = [(0.28, -2.14), (0.88, -2.68), (0.76, -3.02), (0.24, -2.55)]
    make_prism("Razorwing_TailFin_R", tail_fin_r, -0.08, 0.15, m["dark"], asset, root, 0.018)
    make_prism("Razorwing_TailFin_L", mirrored(tail_fin_r), -0.08, 0.15, m["dark"], asset, root, 0.018)
    cockpit_pts = [(-0.24, 1.35), (0.24, 1.35), (0.34, 0.08), (0.0, -0.44), (-0.34, 0.08)]
    make_prism("Razorwing_Cockpit", cockpit_pts, 0.37, 0.47, m["dark"], asset, root, 0.018)
    make_prism("Razorwing_CockpitSlash", [(-0.06, 0.72), (0.10, 0.72), (0.13, 0.34), (-0.10, 0.34)], 0.47, 0.505, m["cyan"], asset, root, 0.006)
    make_prism("Razorwing_Keel", [(-0.08, 3.82), (0.08, 3.82), (0.12, -3.48), (-0.12, -3.48)], 0.43, 0.49, m["accent"], asset, root, 0.008)
    engine("Razorwing_Engine", 0.0, -3.47, 0.0, 0.25, 0.70, m, asset, root, "cyan")
    make_socket("Socket_Muzzle", (0.0, 4.20, 0.08), asset, root)
    make_socket("Socket_EngineLeft", (-0.13, -3.88, 0.0), asset, root)
    make_socket("Socket_EngineRight", (0.13, -3.88, 0.0), asset, root)
    return root


def build_bomber(asset):
    ref = REFERENCES["bomber_enemy"]
    root = root_object(asset, "ENEMY // VERDANT PAYLOAD", "bomber_enemy", ref)
    m = palette("Verdant", (0.16, 0.40, 0.055), (0.62, 0.98, 0.02), (0.24, 1.0, 0.02), 6.0)

    make_ridged_hull(
        "Verdant_CenterHull",
        [(2.82, 0.06, 0.08, 0.16, -0.14), (2.00, 0.38, 0.22, 0.38, -0.24),
         (0.70, 0.66, 0.31, 0.52, -0.30), (-0.55, 0.69, 0.31, 0.55, -0.31),
         (-1.82, 0.52, 0.23, 0.40, -0.27), (-2.48, 0.28, 0.12, 0.24, -0.19)],
        m["hull"], asset, root,
    )
    wing_r = [(0.52, 1.42), (1.70, 1.26), (3.42, 0.50), (3.82, -0.58), (2.98, -0.88), (1.42, -0.42), (0.62, 0.16)]
    make_prism("Verdant_Wing_R", wing_r, -0.22, 0.12, m["hull"], asset, root, 0.05)
    make_prism("Verdant_Wing_L", mirrored(wing_r), -0.22, 0.12, m["hull"], asset, root, 0.05)
    frame_r = [(0.72, 1.18), (1.76, 1.04), (3.32, 0.42), (3.12, 0.02), (1.52, 0.42), (0.70, 0.54)]
    make_prism("Verdant_WingFrame_R", frame_r, 0.11, 0.23, m["accent"], asset, root, 0.025)
    make_prism("Verdant_WingFrame_L", mirrored(frame_r), 0.11, 0.23, m["accent"], asset, root, 0.025)
    for side, sign in (("L", -1.0), ("R", 1.0)):
        x = sign * 1.72
        wedge(f"Verdant_PayloadPod_{side}", (x, 0.25, 0.18), (0.62, 1.25, 0.44), (0.0, 0.0, 0.0), m["metal"], asset, root)
        wedge(f"Verdant_PayloadArmor_{side}", (x, 0.42, 0.60), (0.70, 0.82, 0.13), (0.0, 0.0, 0.0), m["accent"], asset, root)
        make_cylinder(f"Verdant_BombFace_{side}", (x, 1.45, 0.18), 0.40, 0.18, m["dark"], asset, root, vertices=12)
        for index in range(5):
            angle = math.tau * index / 5.0
            make_cylinder(
                f"Verdant_PayloadCell_{side}_{index + 1}",
                (x + math.cos(angle) * 0.20, 1.56, 0.18 + math.sin(angle) * 0.20),
                0.070, 0.12, m["energy"], asset, root, vertices=8,
            )
        engine(f"Verdant_Engine_{side}", x, -1.36, 0.18, 0.38, 0.90, m, asset, root, "cyan")
        vent_bank(f"Verdant_{side}", x, -0.18, 0.67, 4, m, asset, root)
    reactor("Verdant_Reactor", (0.0, 0.02, 0.58), 0.44, m, asset, root)
    nose = [(-0.28, 2.74), (0.28, 2.74), (0.40, 1.14), (0.0, 0.74), (-0.40, 1.14)]
    make_prism("Verdant_NoseArmor", nose, 0.35, 0.50, m["accent"], asset, root, 0.025)
    tip_r = [(3.18, 0.56), (3.84, 0.38), (4.02, -0.36), (3.60, -0.66), (3.38, -0.12)]
    make_prism("Verdant_WingTip_R", tip_r, -0.08, 0.32, m["dark"], asset, root, 0.025)
    make_prism("Verdant_WingTip_L", mirrored(tip_r), -0.08, 0.32, m["dark"], asset, root, 0.025)
    make_socket("Socket_Muzzle", (0.0, 2.90, 0.20), asset, root)
    make_socket("Socket_PayloadLeft", (-1.72, 1.62, 0.18), asset, root)
    make_socket("Socket_PayloadRight", (1.72, 1.62, 0.18), asset, root)
    make_socket("Socket_EngineLeft", (-1.72, -1.92, 0.18), asset, root)
    make_socket("Socket_EngineRight", (1.72, -1.92, 0.18), asset, root)
    return root


def build_sniper(asset):
    ref = REFERENCES["sniper_enemy"]
    root = root_object(asset, "ENEMY // AZURE LANCER", "sniper_enemy", ref)
    m = palette("Lancer", (0.025, 0.28, 0.60), (0.02, 0.72, 1.0), (1.0, 0.10, 0.015), 7.0)

    make_ridged_hull(
        "Lancer_MainHull",
        [(4.20, 0.025, 0.04, 0.08, -0.08), (3.45, 0.17, 0.12, 0.23, -0.13),
         (2.15, 0.31, 0.20, 0.37, -0.19), (0.75, 0.57, 0.28, 0.50, -0.25),
         (-0.45, 0.66, 0.31, 0.54, -0.28), (-2.10, 0.38, 0.18, 0.34, -0.21),
         (-4.05, 0.18, 0.08, 0.17, -0.13)],
        m["hull"], asset, root,
    )
    rail_r = [(0.13, 4.08), (0.34, 3.54), (0.30, 1.42), (0.54, 0.94), (0.38, -3.64), (0.16, -4.02)]
    make_prism("Lancer_Rail_R", rail_r, 0.32, 0.50, m["accent"], asset, root, 0.015)
    make_prism("Lancer_Rail_L", mirrored(rail_r), 0.32, 0.50, m["armor"], asset, root, 0.015)
    shoulder_r = [(0.46, 1.08), (0.88, 0.72), (1.06, -0.78), (0.58, -1.12), (0.44, -0.18)]
    make_prism("Lancer_Shoulder_R", shoulder_r, 0.18, 0.39, m["armor"], asset, root, 0.025)
    make_prism("Lancer_Shoulder_L", mirrored(shoulder_r), 0.18, 0.39, m["armor"], asset, root, 0.025)
    fin_r = [(0.55, 0.10), (1.44, -0.38), (1.34, -0.98), (0.62, -0.58)]
    make_prism("Lancer_Stabilizer_R", fin_r, -0.10, 0.18, m["accent"], asset, root, 0.022)
    make_prism("Lancer_Stabilizer_L", mirrored(fin_r), -0.10, 0.18, m["accent"], asset, root, 0.022)
    aft_r = [(0.28, -2.42), (0.78, -3.18), (0.62, -3.58), (0.26, -3.16)]
    make_prism("Lancer_AftFin_R", aft_r, -0.06, 0.16, m["dark"], asset, root, 0.018)
    make_prism("Lancer_AftFin_L", mirrored(aft_r), -0.06, 0.16, m["dark"], asset, root, 0.018)
    reactor("Lancer_Aperture", (0.0, 0.16, 0.54), 0.43, m, asset, root)
    make_cylinder("Lancer_NoseEmitter", (0.0, 4.14, 0.08), 0.11, 0.30, m["energy"], asset, root, vertices=8)
    for y in (2.92, 2.54, -1.45, -1.86):
        make_prism("Lancer_RedSlash_%.2f" % y, [(-0.06, y + 0.16), (0.06, y + 0.16), (0.07, y - 0.16), (-0.07, y - 0.16)], 0.50, 0.535, m["energy"], asset, root, 0.004)
    engine("Lancer_Engine", 0.0, -3.78, 0.0, 0.27, 0.68, m, asset, root, "accent")
    make_socket("Socket_Muzzle", (0.0, 4.38, 0.08), asset, root)
    make_socket("Socket_Aperture", (0.0, 0.16, 0.62), asset, root)
    make_socket("Socket_EngineLeft", (-0.13, -4.16, 0.0), asset, root)
    make_socket("Socket_EngineRight", (0.13, -4.16, 0.0), asset, root)
    return root


def build_tank(asset):
    ref = REFERENCES["tank_enemy"]
    root = root_object(asset, "ENEMY // VIOLET BASTION", "tank_enemy", ref)
    m = palette("Bastion", (0.18, 0.055, 0.48), (0.45, 0.10, 0.92), (1.0, 0.02, 0.58), 7.0)

    make_ridged_hull(
        "Bastion_CenterHull",
        [(2.82, 0.18, 0.10, 0.20, -0.18), (2.14, 0.62, 0.24, 0.42, -0.28),
         (0.82, 0.92, 0.35, 0.60, -0.36), (-0.72, 1.02, 0.38, 0.65, -0.40),
         (-2.06, 0.84, 0.29, 0.51, -0.34), (-2.72, 0.56, 0.18, 0.34, -0.26)],
        m["hull"], asset, root,
    )
    sponson_r = [(0.76, 2.02), (2.24, 1.82), (3.02, 0.84), (3.06, -1.92), (2.38, -2.52), (1.18, -2.16), (0.90, -0.82)]
    make_prism("Bastion_Sponson_R", sponson_r, -0.30, 0.32, m["hull"], asset, root, 0.075)
    make_prism("Bastion_Sponson_L", mirrored(sponson_r), -0.30, 0.32, m["hull"], asset, root, 0.075)
    armor_r = [(0.92, 1.72), (2.10, 1.52), (2.74, 0.72), (2.64, -0.12), (1.26, 0.22)]
    make_prism("Bastion_UpperArmor_R", armor_r, 0.31, 0.55, m["armor"], asset, root, 0.04)
    make_prism("Bastion_UpperArmor_L", mirrored(armor_r), 0.31, 0.55, m["armor"], asset, root, 0.04)
    lower_r = [(1.08, -0.42), (2.70, -0.20), (2.86, -1.74), (2.30, -2.18), (1.24, -1.82)]
    make_prism("Bastion_LowerArmor_R", lower_r, 0.30, 0.50, m["accent"], asset, root, 0.04)
    make_prism("Bastion_LowerArmor_L", mirrored(lower_r), 0.30, 0.50, m["accent"], asset, root, 0.04)
    prow_r = [(0.16, 2.72), (0.80, 2.18), (1.10, 0.86), (0.48, 0.48), (0.18, 1.12)]
    make_prism("Bastion_Prow_R", prow_r, 0.40, 0.68, m["armor"], asset, root, 0.035)
    make_prism("Bastion_Prow_L", mirrored(prow_r), 0.40, 0.68, m["armor"], asset, root, 0.035)
    reactor("Bastion_Reactor", (0.0, 0.10, 0.68), 0.63, m, asset, root)
    for side, sign in (("L", -1.0), ("R", 1.0)):
        for row, y in enumerate((1.28, -1.10)):
            x = sign * 2.18
            wedge(f"Bastion_Turret_{side}_{row + 1}", (x, y, 0.66), (0.34, 0.50, 0.18), (0.0, 0.0, 0.0), m["metal"], asset, root)
            make_cylinder(f"Bastion_Gun_{side}_{row + 1}", (x, y + 0.56, 0.66), 0.09, 0.62, m["dark"], asset, root, vertices=8)
            make_cylinder(f"Bastion_GunGlow_{side}_{row + 1}", (x, y + 0.89, 0.66), 0.055, 0.06, m["energy"], asset, root, vertices=8)
        engine(f"Bastion_Engine_{side}", sign * 2.28, -2.18, 0.02, 0.48, 0.98, m, asset, root, "cyan")
    engine("Bastion_Engine_C", -0.48, -2.42, -0.02, 0.31, 0.72, m, asset, root, "energy")
    engine("Bastion_Engine_C2", 0.48, -2.42, -0.02, 0.31, 0.72, m, asset, root, "energy")
    vent_bank("Bastion", 0.0, -1.28, 0.58, 5, m, asset, root)
    make_socket("Socket_Muzzle", (0.0, 2.94, 0.40), asset, root)
    make_socket("Socket_EngineLeft", (-2.28, -2.74, 0.02), asset, root)
    make_socket("Socket_EngineRight", (2.28, -2.74, 0.02), asset, root)
    make_socket("Socket_WeaponLeft", (-2.18, 2.20, 0.66), asset, root)
    make_socket("Socket_WeaponRight", (2.18, 2.20, 0.66), asset, root)
    return root


def add_reference_images(target):
    positions = [(-13.0, 7.0), (-6.5, 7.0), (0.0, 7.0), (6.5, 7.0), (13.0, 7.0)]
    for (asset_id, path), (x, y) in zip(REFERENCES.items(), positions):
        image = bpy.data.images.load(str(path), check_existing=True)
        obj = bpy.data.objects.new(f"REF // {asset_id}", None)
        target.objects.link(obj)
        obj.empty_display_type = "IMAGE"
        obj.data = image
        obj.empty_display_size = 5.0
        obj.location = (x, y, 0.0)
        obj.rotation_euler = (0.0, 0.0, 0.0)
        obj["source_path"] = str(path.relative_to(ROOT))
    target.hide_render = True
    target.hide_viewport = True


def setup_presentation(target):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.new("Farinuff Void")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.002, 0.005, 0.018, 1.0)
    background.inputs["Strength"].default_value = 0.08
    scene.world = world

    floor_mat = make_material("FleetPreviewFloor", (0.006, 0.012, 0.035, 1.0), 0.25, 0.38)
    bpy.ops.mesh.primitive_plane_add(size=42.0, location=(0.0, 0.0, -0.48))
    floor = bpy.context.object
    floor.name = "Presentation Ground"
    move_to_collection(floor, target)
    assign_material(floor, floor_mat)

    camera_data = bpy.data.cameras.new("Fleet Preview Camera")
    camera = bpy.data.objects.new("Fleet Preview Camera", camera_data)
    target.objects.link(camera)
    camera_data.type = "ORTHO"
    scene.camera = camera
    add_area_light("Cold Key", (-6.0, -4.0, 10.0), (0.28, 0.72, 1.0), 1250.0, 5.5, target)
    add_area_light("Violet Rim", (7.0, 1.0, 7.0), (0.55, 0.16, 1.0), 1100.0, 5.0, target)
    add_area_light("Warm Front", (0.0, -7.0, 4.0), (1.0, 0.26, 0.08), 650.0, 4.0, target)
    add_area_light("Soft Top", (0.0, 0.0, 12.0), (0.70, 0.84, 1.0), 900.0, 7.0, target)
    return camera


def asset_stats(asset):
    meshes = [obj for obj in asset.all_objects if obj.type == "MESH"]
    empties = [obj for obj in asset.all_objects if obj.type == "EMPTY" and obj.name.startswith("Socket_")]
    vertices = 0
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        vertices += len(obj.data.vertices)
        triangles += len(obj.data.loop_triangles)
    return {"meshes": len(meshes), "vertices": vertices, "triangles": triangles, "sockets": len(empties)}


def export_asset(asset_id, asset):
    path = MODEL_DIR / f"{asset_id}.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.all_objects:
        obj.select_set(True)
    socket_names = {
        obj: obj.name for obj in asset.all_objects if "canonical_socket_name" in obj
    }
    try:
        for obj in socket_names:
            obj.name = obj["canonical_socket_name"]
        bpy.ops.export_scene.gltf(
            filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
            export_yup=True, export_cameras=False, export_lights=False, export_extras=True,
            export_materials="EXPORT",
        )
    finally:
        for obj, name in socket_names.items():
            obj.name = name
        bpy.ops.object.select_all(action="DESELECT")
    return path


def render_single(asset_id, asset, assets, camera):
    scene = bpy.context.scene
    for other in assets.values():
        other.hide_render = other != asset
    camera.location = (6.6, -8.6, 7.5)
    camera.data.ortho_scale = {
        "basic_enemy": 7.0, "fast_enemy": 10.0, "bomber_enemy": 9.0,
        "sniper_enemy": 10.2, "tank_enemy": 8.7,
    }[asset_id]
    look_at(camera, (0.0, 0.0, 0.10))
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    path = PREVIEW_DIR / f"{asset_id}.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path


def render_fleet(assets, roots, camera):
    layout = {
        "basic_enemy": (-5.0, 3.3, 0.0), "fast_enemy": (0.0, 3.4, 0.0),
        "sniper_enemy": (5.0, 3.4, 0.0), "bomber_enemy": (-3.2, -3.5, 0.0),
        "tank_enemy": (3.3, -3.5, 0.0),
    }
    for asset_id, asset in assets.items():
        asset.hide_render = False
        roots[asset_id].location = layout[asset_id]
    camera.location = (11.5, -16.0, 18.0)
    camera.data.ortho_scale = 18.5
    look_at(camera, (0.0, 0.0, 0.0))
    scene = bpy.context.scene
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1000
    path = PREVIEW_DIR / "enemy_fleet_lineup.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    for asset_id, root in roots.items():
        root.location = (0.0, 0.0, 0.0)
        assets[asset_id].hide_render = False
    return path


def validate(asset_id, asset):
    stats = asset_stats(asset)
    errors = []
    if stats["meshes"] < 4 or stats["meshes"] > 8:
        errors.append("runtime mesh count outside 4..8")
    if stats["triangles"] <= 0 or stats["triangles"] > 12000:
        errors.append("triangle count outside 1..12000")
    socket_names = {
        obj.get("canonical_socket_name", obj.name.split(".", 1)[0])
        for obj in asset.all_objects
        if obj.type == "EMPTY" and obj.name.startswith("Socket_")
    }
    if socket_names != EXPECTED_SOCKET_NAMES[asset_id]:
        errors.append(
            f"socket names {sorted(socket_names)} != {sorted(EXPECTED_SOCKET_NAMES[asset_id])}"
        )
    for obj in asset.all_objects:
        if obj.type == "MESH" and len(obj.data.materials) == 0:
            errors.append(f"{obj.name} has no material")
    if errors:
        raise RuntimeError(f"{asset_id} validation failed: {', '.join(errors)}")
    return stats


def consolidate_meshes_by_material(asset_id, asset, root):
    """Reduce each static ship to one draw-call-sized mesh per material."""
    groups = {}
    for obj in list(asset.all_objects):
        if obj.type != "MESH":
            continue
        if len(obj.data.materials) != 1:
            raise RuntimeError(f"{asset_id}: {obj.name} must use exactly one material")
        groups.setdefault(obj.data.materials[0], []).append(obj)

    for material, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = f"{asset_id}__{material.name}"
        joined.parent = root


def namespace_sockets(asset_id, asset):
    """Keep Blender object names unique while preserving canonical GLB socket names."""
    for obj in asset.all_objects:
        if obj.type != "EMPTY" or not obj.name.startswith("Socket_"):
            continue
        canonical_name = obj.name.split(".", 1)[0]
        obj["canonical_socket_name"] = canonical_name
        obj.name = f"{canonical_name}__{asset_id}"


def main():
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    clear_scene_for_interactive_build()

    builders = {
        "basic_enemy": build_basic,
        "fast_enemy": build_fast,
        "bomber_enemy": build_bomber,
        "sniper_enemy": build_sniper,
        "tank_enemy": build_tank,
    }
    assets = {}
    roots = {}
    for asset_id, builder in builders.items():
        asset = collection(f"ASSET // {asset_id}")
        assets[asset_id] = asset
        root = builder(asset)
        roots[asset_id] = root
        namespace_sockets(asset_id, asset)
        consolidate_meshes_by_material(asset_id, asset, root)

    references = collection("ART REFERENCES // Toggle visibility")
    add_reference_images(references)
    presentation = collection("PRESENTATION // Not exported")
    camera = setup_presentation(presentation)

    records = []
    for asset_id, asset in assets.items():
        stats = validate(asset_id, asset)
        glb_path = export_asset(asset_id, asset)
        preview_path = render_single(asset_id, asset, assets, camera)
        records.append({
            "id": asset_id,
            "source_reference": str(REFERENCES[asset_id].relative_to(ROOT)),
            "glb": str(glb_path.relative_to(ROOT)),
            "preview": str(preview_path.relative_to(ROOT)),
            **stats,
        })

    lineup_path = render_fleet(assets, roots, camera)
    scene = bpy.context.scene
    scene["asset_set"] = "Farinuff next-round enemy fleet"
    scene["license"] = "project-original"
    scene["orientation"] = "+Y nose; XY combat plane; Z height"
    scene["source_manifest"] = str((REFERENCE_DIR / "manifest.json").relative_to(ROOT))
    scene["canonical_output_dir"] = str(MODEL_DIR.relative_to(ROOT))
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.camera = camera
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))

    manifest = {
        "schema_version": 1,
        "set_id": "farinuff-next-round-enemy-fleet",
        "status": "blender-built-static-models",
        "license": "project-original",
        "blender_source": str(SOURCE_PATH.relative_to(ROOT)),
        "fleet_preview": str(lineup_path.relative_to(ROOT)),
        "orientation": "+Y nose; XY combat plane; Z height; glTF exported Y-up",
        "topology_budget": "4..8 material meshes and maximum 12000 triangles per ship",
        "assets": records,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"FARINUFF_FLEET_BLEND={SOURCE_PATH}")
    print(f"FARINUFF_FLEET_PREVIEW={lineup_path}")
    print(f"FARINUFF_FLEET_MANIFEST={MANIFEST_PATH}")
    for record in records:
        print(
            "FARINUFF_ASSET=" + record["id"] +
            f" meshes:{record['meshes']} vertices:{record['vertices']} triangles:{record['triangles']} sockets:{record['sockets']}"
        )


if __name__ == "__main__":
    main()
