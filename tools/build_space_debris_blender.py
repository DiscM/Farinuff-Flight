"""Build six original drifting props with the station's Blender material palette.

Run inside Blender. A new scene preserves open work; exports have identity
transforms, flat normals, embedded materials and no physics or lights.
"""
import bpy
import bmesh
import hashlib
import json
import math
import runpy
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
STATION = runpy.run_path(str(ROOT / "tools/build_station_debris_blender.py"),
                         run_name="station_geometry")
Mesh = STATION["Mesh"]
OUTPUT = ROOT / "assets/models/frontier/space_debris"
SOURCE = ROOT / "assets/models/frontier/sources/space_debris.blend"


def satellite():
    mesh = Mesh()
    mesh.plate(0, 0, 1.65, 1.8, -.48, .43, clip=.25, bevel=.13)
    mesh.plate(0, 0, 1.25, 1.35, .43, .49, 2)
    mesh.plate(0, -.23, .77, .27, .49, .52, 3, bevel=.015)
    mesh.beam((-2.5, 0, -.1), (1.75, 0, -.1), .24, .24, 1)
    mesh.append(STATION["solar_wing"](), (-2.2, 0, -.02), scale=.58)
    # Only one attached cell survives on the torn starboard boom.
    mesh.prism([(1.17, -.61), (2.01, -.61), (1.87, -.14),
                (2.13, .21), (1.72, .7), (1.17, .7)], -.1, .03, 2, .04, 1)
    mesh.plate(1.54, -.16, .43, .1, .03, .05, 3, bevel=.005)
    mesh.beam((0, .5, .23), (.19, 1.62, .42), .12, .13, 4)
    mesh.beam((-.35, 1.53, .4), (.69, 1.69, .43), .1, .12, 1)
    return mesh


def cargo_pod():
    mesh = Mesh()
    mesh.prism([(-1.57, -.88), (-1.25, -1.15), (1.36, -1.15),
                (1.61, -.76), (1.31, -.22), (1.58, .23),
                (1.3, 1.11), (-1.29, 1.11), (-1.57, .84)], -.55, .53, bevel=.15)
    mesh.plate(-.05, 0, 2.22, 1.7, .53, .57, 2, bevel=.05)
    for x in (-1.12, .9):
        mesh.plate(x, 0, .25, 2.22, .51, .68, 1, bevel=.035)
    for y in (-.59, .56):
        mesh.plate(-.1, y, 1.57, .24, .57, .62, 0, bevel=.03)
    mesh.plate(-.41, -.02, .52, .39, .57, .62, 4, bevel=.025)
    mesh.plate(.25, -.03, .13, .7, .57, .61, 3, bevel=.01)
    mesh.beam((1.1, -.6, -.28), (1.81, -.62, -.33), .13, .15, 2)
    return mesh


def fuel_tank():
    mesh = Mesh()
    rings = [(-1.88, .29), (-1.55, .77), (-1.17, .84),
             (1.17, .84), (1.55, .77), (1.88, .29)]
    sides = 10
    for y, radius in rings:
        mesh.vertices.extend([(math.cos(a * math.tau / sides) * radius, y,
                               math.sin(a * math.tau / sides) * radius) for a in range(sides)])
    mesh.face(list(reversed(range(sides))), 2)
    mesh.face([(len(rings) - 1) * sides + a for a in range(sides)], 1)
    for row in range(len(rings) - 1):
        for a in range(sides):
            b = (a + 1) % sides
            mesh.face([row * sides + a, row * sides + b,
                       (row + 1) * sides + b, (row + 1) * sides + a], 0)
    for y in (-1.05, 1.05):
        # Sturdy octagonal restraint bands, connected across the tank silhouette.
        band = Mesh()
        band.arc(.81, .94, 0, math.tau, -.12, .12, 1, steps=10)
        band.vertices = [(x, y + z, -v) for x, v, z in band.vertices]
        mesh.append(band)
    mesh.plate(0, .02, .41, 1.09, .8, .87, 3, bevel=.025)
    mesh.beam((0, 1.83, 0), (.15, 2.12, .04), .27, .26, 4)
    mesh.beam((.15, 2.12, .04), (.59, 2.04, .1), .18, .2, 2)
    return mesh


def engine_bell():
    mesh = Mesh()
    # Closed shell with a recessed, unlit mouth; no bright engine core.
    rings = [(-.7, .48), (-.32, .61), (.55, 1.25), (.68, 1.27),
             (.68, 1.07), (-.28, .4)]
    sides = 12
    for z, radius in rings:
        mesh.vertices.extend([(math.cos(a * math.tau / sides) * radius,
                               math.sin(a * math.tau / sides) * radius, z) for a in range(sides)])
    for row in range(len(rings)):
        next_row = (row + 1) % len(rings)
        for a in range(sides):
            b = (a + 1) % sides
            mesh.face([row * sides + a, row * sides + b,
                       next_row * sides + b, next_row * sides + a],
                      1 if row in (2, 3) else 2 if row >= 4 else 0)
    mesh.plate(0, 0, 1.3, 1.3, -.9, -.71, 2)
    for side in (-1, 1):
        mesh.plate(side * 1.29, -.27, .38, 1.18, -.57, -.09, 0)
        mesh.beam((side * .42, 0, -.65), (side * 1.35, -.12, -.26), .24, .22, 4)
    mesh.beam((-.6, 1.0, .31), (-.75, 1.44, .2), .17, .2, 2)
    return mesh


def broken_dish():
    mesh = Mesh()
    # Wedges each have a back and closed torn edge, with two sectors missing.
    for i in range(10):
        a, b = math.tau * (i + .04) / 12, math.tau * (i + .97) / 12
        points = [(r * math.cos(t), r * math.sin(t), .14 * r * r)
                  for r, t in ((.35, a), (1.78, a), (1.78, b), (.35, b))]
        start = len(mesh.vertices)
        mesh.vertices.extend([(x, y, z - .11) for x, y, z in points] + points)
        for face, role in [((0, 3, 2, 1), 2), ((4, 5, 6, 7), 0),
                           ((0, 1, 5, 4), 1), ((1, 2, 6, 5), 1),
                           ((2, 3, 7, 6), 1), ((3, 0, 4, 7), 2)]:
            mesh.face([start + j for j in face], role)
    mesh.plate(0, 0, .74, .74, -.25, .16, 4)
    for degrees in (30, 150, 270):
        a = math.radians(degrees)
        mesh.beam((1.3 * math.cos(a), 1.3 * math.sin(a), .26),
                  (0, 0, .96), .095, .11, 1)
    mesh.plate(0, 0, .3, .38, .9, 1.14, 2)
    mesh.beam((0, -.3, -.2), (.1, -2.0, -.4), .27, .29, 0)
    mesh.plate(.1, -1.85, .67, .55, -.59, -.2, 0)
    return mesh


def asteroid():
    mesh = Mesh()
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.5)
    bm.verts.ensure_lookup_table()
    for i, vertex in enumerate(bm.verts):
        scale = .88 + .18 * math.sin(i * 7.17)
        x, y, z = vertex.co * scale
        mesh.vertices.append((x * 1.3, y * .84, z * .72))
    for i, face in enumerate(bm.faces):
        mesh.face([v.index for v in face.verts], 2 if i % 11 == 0 else 4 if i % 17 == 0 else 0)
    bm.free()
    return mesh


BUILDERS = {"derelict_satellite": satellite, "ruptured_cargo_pod": cargo_pod,
            "spent_fuel_tank": fuel_tank, "discarded_engine_bell": engine_bell,
            "broken_survey_dish": broken_dish, "faceted_asteroid": asteroid}


def setup():
    scene, materials = STATION["setup"]()
    scene.name = "Pixel-forged Space Debris"
    scene.world.name = "Space Debris | Indigo"
    return scene, materials


def build_assets(materials):
    assets = {}
    for name, builder in BUILDERS.items():
        mesh = builder()
        low = Vector(tuple(min(v[i] for v in mesh.vertices) for i in range(3)))
        high = Vector(tuple(max(v[i] for v in mesh.vertices) for i in range(3)))
        center = (low + high) / 2
        mesh.vertices = [tuple(Vector(v) - center) for v in mesh.vertices]
        assets[name] = mesh.object(name, materials)
    return assets


def export_assets(scene, assets):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = []
    for name, obj in assets.items():
        obj.location = (0, 0, 0)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        path = OUTPUT / (name + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                                  use_selection=True, use_active_scene=True, export_yup=True,
                                  export_animations=False, export_cameras=False, export_lights=False)
        obj.data.calc_loop_triangles()
        report.append({"asset": path.name, "triangles": len(obj.data.loop_triangles),
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                       "dimensions_blender": [round(v, 3) for v in obj.dimensions]})
    manifest = {"authoring": "Original Blender geometry for Farinuff Flight",
                "blender_version": bpy.app.version_string,
                "source": str(SOURCE.relative_to(ROOT)), "rebuild": str(Path(__file__).relative_to(ROOT)),
                "style_reference": "design/station-debris/STYLE_REFERENCE.md",
                "shader": "effects/shaders/models/pixel_planet_enemy_3d.gdshader",
                "units": "meters", "export_up_axis": "Y",
                "palette": [{"role": name, "srgb": "#" + color} for name, color in STATION["PALETTE"]],
                "assets": report}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for index, obj in enumerate(assets.values()):
        obj.location = ((index % 3 - 1) * 6.3, 3.1 - (index // 3) * 6.2, 0)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.region_3d.view_distance = 26
                space.region_3d.view_location = Vector((0, 0, 0))
                space.region_3d.view_rotation = Quaternion((1, 0, 0), math.radians(18))
                space.region_3d.view_perspective = "ORTHO"
                space.shading.type = "SOLID"
                space.shading.color_type = "MATERIAL"
                space.overlay.show_overlays = False
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    bpy.data.libraries.write(str(SOURCE), {scene}, fake_user=True)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    scene, materials = setup()
    export_assets(scene, build_assets(materials))
