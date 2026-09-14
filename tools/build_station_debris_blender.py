"""Author the pixel-forged station wreckage in Blender; export isolated GLBs.

Run with Blender Python. Creates a new scene without clearing existing work.
The game supplies the shared PixelPlanets spatial shader; these material roles
and broad, flat facets are its inputs. No textures, lights or physics exported.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/models/frontier/station_debris"
SOURCE = ROOT / "assets/models/frontier/sources/station_debris.blend"
PALETTE = [
    ("Station | slate armor", "687b96"),
    ("Station | pale cut edges", "9cacc0"),
    ("Station | violet recess", "30344e"),
    ("Station | faded cyan inlay", "639eab"),
    ("Station | weathered brass", "a48a68"),
]


def setup():
    scene = bpy.data.scenes.new("Pixel-forged Station Debris")
    bpy.context.window.scene = scene
    materials = []
    for name, hex_color in PALETTE:
        srgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*linear, 1)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*linear, 1)
        bsdf.inputs["Metallic"].default_value = 0
        bsdf.inputs["Roughness"].default_value = 1
        materials.append(mat)
    scene.world = bpy.data.worlds.new("Station Debris | Indigo")
    scene.world.color = (0.012, 0.016, 0.035)
    scene.view_settings.view_transform = "Standard"
    return scene, materials


class Mesh:
    def __init__(self):
        self.vertices, self.faces, self.roles = [], [], []

    def face(self, indices, role):
        self.faces.append(tuple(indices))
        self.roles.append(role)

    def prism(self, points, bottom, top, role=0, bevel=0.06, edge=1):
        points = [Vector(p) for p in points]
        area = sum(a.x * b.y - b.x * a.y for a, b in zip(points, points[1:] + points[:1]))
        if area < 0:
            points.reverse()
        center = sum(points, Vector((0, 0))) / len(points)
        inset = [p + (center - p).normalized() * bevel for p in points]
        start, n = len(self.vertices), len(points)
        for ring, z in ((points, bottom), (points, top - bevel), (inset, top)):
            self.vertices.extend([(p.x, p.y, z) for p in ring])
        self.face([start + i for i in reversed(range(n))], 2)
        self.face([start + 2 * n + i for i in range(n)], role)
        for i in range(n):
            j = (i + 1) % n
            self.face([start + i, start + j, start + n + j, start + n + i], role)
            self.face([start + n + i, start + n + j, start + 2 * n + j, start + 2 * n + i], edge)

    def plate(self, x, y, width, height, bottom, top, role=0, clip=0.12, bevel=0.05):
        w, h = width / 2, height / 2
        c = min(clip, w * 0.4, h * 0.4)
        points = [(x - w + c, y - h), (x + w - c, y - h),
                  (x + w, y - h + c), (x + w, y + h - c),
                  (x + w - c, y + h), (x - w + c, y + h),
                  (x - w, y + h - c), (x - w, y - h + c)]
        self.prism(points, bottom, top, role, bevel, 1 if role == 0 else role)

    def beam(self, a, b, width=0.16, depth=0.18, role=1):
        a, b = Vector(a), Vector(b)
        direction = (b - a).normalized()
        side = direction.cross(Vector((0, 0, 1)))
        if side.length < 0.01:
            side = Vector((1, 0, 0))
        side = side.normalized() * width / 2
        up = side.normalized().cross(direction) * depth / 2
        start = len(self.vertices)
        for point in (a, b):
            self.vertices.extend([tuple(point - side - up), tuple(point + side - up),
                                  tuple(point + side + up), tuple(point - side + up)])
        for face in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                     (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.face([start + i for i in face], role)

    def arc(self, inner, outer, start, end, bottom, top, role=0, steps=4):
        for i in range(steps):
            a = start + (end - start) * i / steps
            b = start + (end - start) * (i + 1) / steps
            self.prism([(inner * math.cos(a), inner * math.sin(a)),
                        (outer * math.cos(a), outer * math.sin(a)),
                        (outer * math.cos(b), outer * math.sin(b)),
                        (inner * math.cos(b), inner * math.sin(b))],
                       bottom, top, role, min(0.04, (outer - inner) / 6), role if role else 1)

    def append(self, other, offset=(0, 0, 0), angle=0, scale=1):
        start = len(self.vertices)
        c, s = math.cos(angle), math.sin(angle)
        for x, y, z in other.vertices:
            self.vertices.append(((x * c - y * s) * scale + offset[0],
                                  (x * s + y * c) * scale + offset[1], z * scale + offset[2]))
        self.faces.extend([tuple(start + i for i in face) for face in other.faces])
        self.roles.extend(other.roles)

    def object(self, name, materials):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for material in materials:
            mesh.materials.append(material)
        for polygon, role in zip(mesh.polygons, self.roles):
            polygon.material_index = role
            polygon.use_smooth = False
        # Recalculate closed part normals before export, including all bevels.
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        return obj


def armor_plate():
    mesh = Mesh()
    mesh.prism([(-1.45, -.8), (.9, -1.05), (1.5, -.25), (1.1, .25),
                (1.2, .72), (.25, 1.0), (-1.3, .75)], -.16, .18, bevel=.1)
    mesh.prism([(-1.15, -.55), (.65, -.72), (.96, -.26), (.61, .51),
                (-1.0, .5)], .18, .24, 0, .035, 2)
    mesh.plate(-.52, -.05, .3, .9, .24, .28, 3, bevel=.015)
    mesh.plate(.6, -.52, .37, .14, .24, .28, 4, bevel=.01)
    # Exposed ribs terminate at the torn edge instead of floating alongside it.
    mesh.beam((.3, .55, -.08), (.75, 1.12, -.04), .14, .18, 2)
    mesh.beam((.82, .32, -.08), (1.33, .69, -.03), .14, .18, 1)
    return mesh


def solar_wing():
    mesh = Mesh()
    mesh.prism([(-1.8, -.95), (1.6, -.95), (1.88, -.64), (1.31, -.1),
                (1.52, .37), (1.15, 1.05), (-1.8, 1.05)], -.11, .05, 2, .04, 0)
    for column in range(3):
        for row in range(2):
            if (column, row) == (2, 1):
                continue
            mesh.plate(-1.24 + column * 1.0, -.44 + row * .97, .88, .83,
                       .05, .1, 0 if column == 0 else 2, clip=.07, bevel=.015)
            mesh.plate(-1.24 + column * 1.0, -.44 + row * .97, .65, .1,
                       .1, .12, 3, bevel=.005)
    mesh.beam((-1.87, -1, .06), (-1.87, 1.1, .06), .15, .18)
    mesh.beam((-1.87, -1, .06), (1.62, -1, .06), .15, .18)
    mesh.beam((-1.87, 1.1, .06), (.95, 1.1, .06), .15, .18)
    mesh.beam((-2.45, .05, -.05), (-1.05, .05, -.05), .26, .24, 0)
    mesh.plate(-2.25, .05, .5, .5, -.2, .17, 4)
    return mesh


def truss():
    mesh = Mesh()
    mesh.beam((-2.2, -.59, -.05), (1.75, -.59, -.05), .22, .26, 0)
    mesh.beam((-2.2, .59, -.05), (1.05, .59, -.05), .22, .26, 0)
    for i in range(4):
        x = -2.05 + i * .85
        mesh.beam((x, -.55, -.04), (x + .8, .55, -.04), .14, .15, 1)
        if i < 3:
            mesh.beam((x + .8, -.55, -.04), (x + .8, .55, -.04), .13, .15, 2)
    mesh.plate(-1.85, 0, .45, 1.55, -.23, .22, 0)
    mesh.plate(-1.85, 0, .22, .77, .22, .27, 3, bevel=.015)
    mesh.beam((1.05, .59, -.05), (1.57, .86, .1), .22, .26, 0)
    mesh.beam((1.75, -.59, -.05), (2.22, -.79, -.18), .22, .26, 0)
    return mesh


def habitat():
    mesh = Mesh()
    mesh.prism([(-1.9, -.58), (-1.55, -.85), (1.2, -.85), (1.53, -.53),
                (1.14, -.1), (1.67, .16), (1.26, .76), (-1.62, .76), (-1.9, .49)],
               -.36, .39, 0, .16)
    mesh.plate(-.4, -.02, 2.35, 1.08, .39, .48, 0, bevel=.08)
    for x in (-1.27, -.37, .53):
        mesh.plate(x, -.04, .2, 1.49, .38, .58, 1, bevel=.035)
        mesh.plate(x + .34, -.17, .39, .44, .48, .51, 2, bevel=.01)
        mesh.plate(x + .34, -.17, .28, .1, .51, .53, 3, bevel=.005)
    mesh.plate(-1.84, 0, .17, 1.1, -.3, .34, 2)
    mesh.beam((1.04, -.54, -.04), (1.99, -.49, -.08), .17, .2, 1)
    mesh.beam((1.06, .45, -.04), (1.67, .59, -.17), .17, .2, 2)
    mesh.plate(-.73, -.57, .4, .19, .48, .52, 4, bevel=.01)
    return mesh


def ring_section():
    mesh = Mesh()
    mesh.arc(2.5, 3.5, math.radians(24), math.radians(110), -.26, .3, steps=6)
    mesh.arc(2.45, 2.62, math.radians(28), math.radians(106), .29, .36, 3, steps=6)
    for degrees in (36, 66, 96):
        angle = math.radians(degrees)
        a = (2.4 * math.cos(angle), 2.4 * math.sin(angle), .12)
        b = (3.73 * math.cos(angle), 3.73 * math.sin(angle), .12)
        mesh.beam(a, b, .24, .6, 0)
    mesh.beam((2.9, 1.35, 0), (3.42, 1.0, -.12), .15, .17, 1)
    # Center the shard itself, not the center of its former station ring.
    low = Vector(tuple(min(v[i] for v in mesh.vertices) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in mesh.vertices) for i in range(3)))
    center = (low + high) / 2
    mesh.vertices = [tuple(Vector(v) - center) for v in mesh.vertices]
    return mesh


def relay():
    mesh = Mesh()
    count = 16
    for sector in range(count):
        if sector in (0, 1, 2, 10):
            continue
        a, b = sector * math.tau / count + .025, (sector + 1) * math.tau / count - .025
        mesh.arc(5.15, 6.05, a, b, -.32, .31, steps=3)
        mesh.arc(5.1, 5.26, a + .01, b - .01, .31, .37, 3, steps=3)
        if sector % 2 == 0:
            mid = (a + b) / 2
            mesh.beam((4.94 * math.cos(mid), 4.94 * math.sin(mid), .13),
                      (6.3 * math.cos(mid), 6.3 * math.sin(mid), .13), .28, .77, 0)
    # Broken central pressure hub: an open hexagon, no glowing core.
    mesh.arc(.73, 1.32, math.radians(58), math.radians(342), -.45, .36, steps=5)
    for degrees in (130, 202, 284):
        angle = math.radians(degrees)
        direction, side = Vector((math.cos(angle), math.sin(angle))), Vector((-math.sin(angle), math.cos(angle)))
        for sign in (-1, 1):
            start, end = direction * 1.0 + side * .23 * sign, direction * 5.25 + side * .23 * sign
            mesh.beam((*start, -.08), (*end, -.08), .22, .24, 0)
        for r in (2.0, 3.0, 4.0):
            start, end = direction * r + side * .25, direction * (r + .75) - side * .25
            mesh.beam((*start, -.08), (*end, -.08), .12, .16, 1)
    for degrees in (90, 179, 293):
        angle = math.radians(degrees)
        mesh.append(habitat(), (6.1 * math.cos(angle), 6.1 * math.sin(angle), .11), angle, .65)
    mesh.append(solar_wing(), (-6.2, -2.6, -.05), math.radians(-27), .83)
    # Torn service mast and a cable conduit terminate in the missing quadrant.
    mesh.beam((1.86, 5.2, -.1), (2.72, 4.15, -.18), .22, .24, 1)
    mesh.beam((1.98, 5.51, -.16), (3.10, 4.68, -.26), .12, .13, 2)
    return mesh


BUILDERS = {
    "shattered_orbital_relay": relay,
    "station_ring_section": ring_section,
    "station_habitat_wreck": habitat,
    "station_solar_wing": solar_wing,
    "station_truss": truss,
    "station_armor_plate": armor_plate,
}


def build_assets(materials):
    return {name: builder().object(name, materials) for name, builder in BUILDERS.items()}


def export_assets(scene, assets):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = []
    for name, obj in assets.items():
        obj.location = (0, 0, 0)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (name + ".glb")),
                                  export_format="GLB", use_selection=True, use_active_scene=True,
                                  export_yup=True, export_animations=False, export_cameras=False,
                                  export_lights=False, export_extras=False)
        obj.data.calc_loop_triangles()
        report.append({"asset": name + ".glb", "triangles": len(obj.data.loop_triangles),
                       "sha256": hashlib.sha256((OUTPUT / (name + ".glb")).read_bytes()).hexdigest(),
                       "dimensions_blender": [round(v, 3) for v in obj.dimensions],
                       "materials": len(set(p.material_index for p in obj.data.polygons))})
    (OUTPUT / "manifest.json").write_text(json.dumps({
        "authoring": "Original Blender geometry for Farinuff Flight", "blender_version": bpy.app.version_string,
        "source": "assets/models/frontier/sources/station_debris.blend",
        "rebuild": "tools/build_station_debris_blender.py", "units": "meters", "export_up_axis": "Y",
        "style_sources": ["design/pixel-enemies/README.md", "design/void-frontier/README.md"],
        "style_profile": {
            "id": "pixel-forged-station", "name": "Pixel-forged station wreckage", "source": "written",
            "brief": "Faceted slate station wreckage with the fleet's three-band PixelPlanets shading.",
            "application": "Apply the shared spatial shader to every exported material role in Godot.",
            "must_preserve": ["Clipped armor, exposed ribs and attached broken conduits", "Subdued scenery exposure"],
            "reference_images": [],
        },
        "style_lock": {
            "medium": "Original flat-shaded Blender geometry with a Godot spatial shader",
            "rendering": "Three palette bands, quantized terrain, narrow checker dithering",
            "palette": ["Slate armor", "Pale cut edges", "Violet recesses", "Faded cyan inlays", "Weathered brass"],
            "must_not_change": ["No specular glare or emissive cores", "No detached attached components",
                                "No collision or shadows", "Grid moves with the mesh"],
        },
        "palette": [{"role": name, "srgb": "#" + color} for name, color in PALETTE], "assets": report,
    }, indent=2) + "\n")
    # Arrange the editable source only after exporting every asset at its origin.
    assets["shattered_orbital_relay"].location = (-9, 0, 0)
    for i, obj in enumerate(list(assets.values())[1:]):
        obj.location = (2.5 + (i % 2) * 6.5, 4.5 - (i // 2) * 4.5, 0)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.region_3d.view_distance = 34
                space.region_3d.view_location = Vector((-2, 0, 0))
                space.region_3d.view_rotation = Quaternion((1, 0, 0), math.radians(22))
                space.region_3d.view_perspective = "ORTHO"
                space.shading.type = "SOLID"
                space.shading.color_type = "MATERIAL"
                space.overlay.show_overlays = False
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    # Save a clean asset-only library; unrelated open scenes are not included.
    bpy.data.libraries.write(str(SOURCE), {scene}, fake_user=True)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    asset_scene, palette = setup()
    objects = build_assets(palette)
    export_assets(asset_scene, objects)
