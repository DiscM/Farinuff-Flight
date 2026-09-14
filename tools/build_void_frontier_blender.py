"""Original Void Frontier assets. Run with Blender's Python, or execute each stage.

Creates a separate scene; preserves existing scenes/objects. GLBs use Blender's
standard Y-up conversion, applied transforms, no cameras, and no collision meshes.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/models/frontier"


def setup():
    scene = bpy.data.scenes.new("Void Frontier Assets")
    bpy.context.window.scene = scene
    scene.world = bpy.data.worlds.new("Frontier Night")
    scene.world.color = (0.018, 0.022, 0.04)
    mats = []
    for name, color, metal, rough, emission in [
        ("Relay | slate ceramic", (0.085, 0.125, 0.18, 1), 0.65, 0.48, 0),
        ("Relay | pale worn edges", (0.28, 0.37, 0.44, 1), 0.6, 0.4, 0),
        ("Relay | dormant cyan", (0.035, 0.37, 0.43, 1), 0.2, 0.35, 0.65),
        ("Relay | warning brass", (0.55, 0.3, 0.09, 1), 0.5, 0.5, 0),
    ]:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = color
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
        mats.append(mat)
    return scene, mats


def mesh_object(name, vertices, faces, materials, indices=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for mat in materials:
        mesh.materials.append(mat)
    if indices:
        for face, index in zip(mesh.polygons, indices):
            face.material_index = index
    return obj


def build_relay(mats):
    verts, faces, indices = [], [], []

    def prism(points, lower, upper, material=0):
        start = len(verts)
        count = len(points)
        verts.extend([(x, y, lower) for x, y in points])
        verts.extend([(x, y, upper) for x, y in points])
        faces.append(tuple(start + i for i in reversed(range(count))))
        faces.append(tuple(start + count + i for i in range(count)))
        indices.extend([material, material])
        for i in range(count):
            j = (i + 1) % count
            faces.append((start+i, start+j, start+count+j, start+count+i))
            indices.append(1 if material == 0 and i % 2 == 0 else material)

    def arc(inner, outer, start, end, low, high, mat=0):
        steps = max(2, round((end-start) * 15))
        for i in range(steps):
            a = start + (end-start) * i/steps
            b = start + (end-start) * (i+1)/steps
            prism([(inner*math.cos(a), inner*math.sin(a)),
                   (outer*math.cos(a), outer*math.sin(a)),
                   (outer*math.cos(b), outer*math.sin(b)),
                   (inner*math.cos(b), inner*math.sin(b))], low, high, mat)

    # A conspicuous missing section and smaller fractures give the silhouette history.
    for sector in range(18):
        if sector in (1, 2, 3, 11):
            continue
        a = sector * math.tau / 18 + 0.015
        b = (sector+1) * math.tau / 18 - 0.015
        arc(5.25, 6.0, a, b, -0.28, 0.28)
        arc(5.17, 5.3, a+0.02, b-0.02, 0.23, 0.32, 2)
        arc(5.85, 6.03, a+0.03, b-0.03, 0.28, 0.43, 1)
        if sector % 3 == 0:
            mid = (a+b)/2
            direction = Vector((math.cos(mid), math.sin(mid)))
            tangent = Vector((-direction.y, direction.x))
            points = [direction*r + tangent*t for r,t in
                      [(5.6,-0.42),(7.3,-0.3),(7.6,0),(7.3,0.3),(5.6,0.42)]]
            prism(points, -0.48, 0.65)
            arc(6.35, 6.75, mid-0.04, mid+0.04, 0.65, 0.68, 3)
    # Two snapped inner supports, deliberately incomplete.
    prism([(-5.35, -0.23), (-2.65, -0.23), (-2.1, 0.04), (-2.7, 0.23), (-5.35, 0.23)], -0.17, 0.15)
    prism([(0.1,-5.4),(0.48,-5.4),(0.3,-3.1),(-0.08,-2.7)], -0.17, 0.15)
    return mesh_object("Broken Orbital Relay", verts, faces, mats, indices)


def build_fragments(mats):
    plate = mesh_object("Hull Fragment", [(-0.42,-0.22,-0.07),(0.37,-0.16,-0.07),
        (0.26,0.29,-0.07),(-0.26,0.22,-0.07),(-0.3,-0.18,0.07),
        (0.36,-0.14,0.07),(0.22,0.24,0.07),(-0.2,0.19,0.07)],
        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
        mats, [0,1,0,3,0,0])
    shard = mesh_object("Void Splinter", [(0,0,0.65),(-0.2,-0.16,0.0),
        (0.18,-0.1,0.05),(0.12,0.18,0.0),(-0.13,0.12,-0.04),(0.03,0,-0.5)],
        [(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)],
        mats, [1,0,1,0,0,1,0,1])
    return plate, shard


def export_assets(scene, relay, plate, shard):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "sources").mkdir(exist_ok=True)
    report = []
    for obj, filename in [(relay, "broken_orbital_relay"), (plate, "hull_fragment"), (shard, "void_splinter")]:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (filename + ".glb")),
            export_format="GLB", use_selection=True, use_active_scene=True, export_yup=True,
            export_animations=False, export_cameras=False, export_lights=False)
        report.append({"asset": filename, "triangles": sum(len(p.vertices)-2 for p in obj.data.polygons)})
    plate.location = (-1.4, 0, 1.2)
    shard.location = (1.4, 0, 1.2)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_distance = 22
                area.spaces.active.region_3d.view_location = Vector((0, 0, 0))
                area.spaces.active.region_3d.view_rotation = Quaternion((1,0,0), math.radians(28))
                area.spaces.active.shading.color_type = "MATERIAL"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "sources/void_frontier.blend"))
    print(report)


if __name__ == "__main__":
    scene, mats = setup()
    relay = build_relay(mats)
    plate, shard = build_fragments(mats)
    export_assets(scene, relay, plate, shard)
