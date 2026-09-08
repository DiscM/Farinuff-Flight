#!/usr/bin/env python3
"""Build the Farinuff Kestrel interceptor in Blender.

Run with Blender, not the system Python:

    /Applications/Blender.app/Contents/MacOS/Blender \
      --background --python tools/build_farinuff_kestrel_blender.py

The Blender source keeps selected shipped ships in a hidden reference
collection. Only the Kestrel asset collection is exported to GLB.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
BLEND_PATH = ROOT / "assets/models/redesign/farinuff_kestrel_interceptor.blend"
GLB_PATH = ROOT / "assets/models/redesign/farinuff_kestrel_interceptor.glb"
PREVIEW_PATH = ROOT / "renders/drafts/farinuff_kestrel_interceptor_preview.png"
TOP_PATH = ROOT / "renders/drafts/farinuff_kestrel_interceptor_top.png"

REFERENCE_MODELS = [
    ROOT / "assets/models/mockups/player_ship_mockup.glb",
    ROOT / "assets/models/redesign/player_redesign_a.glb",
    ROOT / "assets/models/redesign/player_redesign_b.glb",
    ROOT / "assets/models/redesign/player_butterfly.glb",
    ROOT / "assets/models/mockups/basic_enemy_mockup.glb",
    ROOT / "assets/models/mockups/tank_enemy_mockup.glb",
]


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def collection(name: str) -> bpy.types.Collection:
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def move_to_collection(obj: bpy.types.Object, target: bpy.types.Collection) -> None:
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    target.objects.link(obj)


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(material)


def make_material(
    name: str,
    base: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission: tuple[float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = base
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input is not None:
            emission_input.default_value = (*emission, 1.0)
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input is not None:
            strength_input.default_value = emission_strength
    return mat


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 1) -> None:
    if width <= 0:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("HardSurfaceBevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def finish_mesh(
    obj: bpy.types.Object,
    target: bpy.types.Collection,
    parent: bpy.types.Object | None,
    material: bpy.types.Material,
    bevel: float = 0.0,
) -> bpy.types.Object:
    move_to_collection(obj, target)
    obj.parent = parent
    assign_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    if obj.scale != Vector((1.0, 1.0, 1.0)):
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.select_set(False)
    apply_bevel(obj, bevel)
    return obj


def make_prism(
    name: str,
    points: list[tuple[float, float]],
    z_bottom: float,
    z_top: float,
    material: bpy.types.Material,
    target: bpy.types.Collection,
    parent: bpy.types.Object,
    bevel: float = 0.0,
) -> bpy.types.Object:
    count = len(points)
    vertices = [(x, y, z_bottom) for x, y in points]
    vertices += [(x, y, z_top) for x, y in points]
    faces: list[tuple[int, ...]] = []
    faces.append(tuple(reversed(range(count))))
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    obj.parent = parent
    assign_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    apply_bevel(obj, bevel)
    return obj


def mirrored(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return [(-x, y) for x, y in reversed(points)]


def make_ridged_hull(
    name: str,
    sections: list[tuple[float, float, float, float, float]],
    material: bpy.types.Material,
    target: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    """Create a faceted hull from y, half-width, side-z, ridge-z, bottom-z."""
    vertices: list[tuple[float, float, float]] = []
    for y, width, side_z, ridge_z, bottom_z in sections:
        vertices.extend(
            [
                (-width, y, side_z),
                (0.0, y, ridge_z),
                (width, y, side_z),
                (-width, y, bottom_z),
                (width, y, bottom_z),
            ]
        )
    faces: list[tuple[int, ...]] = []
    for index in range(len(sections) - 1):
        a = index * 5
        b = (index + 1) * 5
        faces.extend(
            [
                (a + 0, b + 0, b + 1, a + 1),
                (a + 1, b + 1, b + 2, a + 2),
                (a + 3, b + 3, b + 0, a + 0),
                (a + 2, b + 2, b + 4, a + 4),
                (a + 3, a + 4, b + 4, b + 3),
            ]
        )
    faces.append((0, 1, 2, 4, 3))
    last = (len(sections) - 1) * 5
    faces.append((last + 3, last + 4, last + 2, last + 1, last + 0))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    obj.parent = parent
    assign_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    apply_bevel(obj, 0.025)
    return obj


def make_box(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    rotation: tuple[float, float, float],
    material: bpy.types.Material,
    target: bpy.types.Collection,
    parent: bpy.types.Object,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_mesh(obj, target, parent, material, bevel)


def make_cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    target: bpy.types.Collection,
    parent: bpy.types.Object,
    vertices: int = 10,
    rotation: tuple[float, float, float] = (math.radians(90.0), 0.0, 0.0),
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, target, parent, material, bevel)


def make_ico(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    target: bpy.types.Collection,
    parent: bpy.types.Object,
    subdivisions: int = 2,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_mesh(obj, target, parent, material)


def make_engine(
    name: str,
    x: float,
    y: float,
    z: float,
    radius: float,
    length: float,
    asset: bpy.types.Collection,
    root: bpy.types.Object,
    gunmetal: bpy.types.Material,
    void: bpy.types.Material,
    cyan: bpy.types.Material,
) -> None:
    make_cylinder(
        f"{name}_Housing",
        (x, y, z),
        radius,
        length,
        gunmetal,
        asset,
        root,
        vertices=10,
        bevel=0.035,
    )
    make_cylinder(
        f"{name}_Nozzle",
        (x, y - length * 0.52, z),
        radius * 0.78,
        0.12,
        void,
        asset,
        root,
        vertices=10,
    )
    make_cylinder(
        f"{name}_Core",
        (x, y - length * 0.58, z),
        radius * 0.48,
        0.14,
        cyan,
        asset,
        root,
        vertices=10,
    )


def make_socket(
    name: str,
    location: tuple[float, float, float],
    asset: bpy.types.Collection,
    root: bpy.types.Object,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    asset.objects.link(obj)
    obj.parent = root
    obj.location = location
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.18
    obj["socket"] = True
    return obj


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def build_asset(asset: bpy.types.Collection) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    root = bpy.data.objects.new("PLAYER // KESTREL Mk I", None)
    asset.objects.link(root)
    root["asset_name"] = "Farinuff Kestrel Interceptor"
    root["asset_role"] = "player_interceptor_candidate"
    root["license"] = "project-original"
    root["art_direction"] = (
        "Farinuff native-3D fleet: compact low-poly faceted hull, ivory/cyan player palette, "
        "dark occlusion panels, readable swept-wing silhouette, restrained emission"
    )
    root["reference_models"] = ", ".join(str(path.relative_to(ROOT)) for path in REFERENCE_MODELS)

    ivory = make_material("IvoryHull", (0.76, 0.84, 0.93, 1.0), 0.72, 0.27)
    silver = make_material("SilverTrim", (0.50, 0.59, 0.70, 1.0), 0.88, 0.22)
    gunmetal = make_material("Gunmetal", (0.20, 0.27, 0.37, 1.0), 0.82, 0.29)
    void = make_material("VoidMetal", (0.025, 0.035, 0.065, 1.0), 0.78, 0.24)
    glass = make_material(
        "BlueGlass",
        (0.025, 0.10, 0.38, 1.0),
        0.28,
        0.15,
        (0.005, 0.03, 0.13),
        1.0,
    )
    cyan = make_material(
        "CyanEnergy",
        (0.035, 0.58, 0.86, 1.0),
        0.18,
        0.21,
        (0.01, 0.42, 0.72),
        6.0,
    )
    hot = make_material(
        "HotCore",
        (0.96, 0.98, 1.0, 1.0),
        0.0,
        0.14,
        (0.62, 0.70, 0.82),
        8.0,
    )

    created: list[bpy.types.Object] = []

    hull = make_ridged_hull(
        "Kestrel_MainHull",
        [
            (2.62, 0.035, 0.08, 0.12, -0.12),
            (2.08, 0.30, 0.18, 0.28, -0.18),
            (1.22, 0.53, 0.28, 0.42, -0.24),
            (0.10, 0.66, 0.30, 0.46, -0.28),
            (-0.92, 0.56, 0.23, 0.36, -0.25),
            (-1.78, 0.38, 0.14, 0.24, -0.20),
            (-2.24, 0.22, 0.07, 0.13, -0.14),
        ],
        ivory,
        asset,
        root,
    )
    created.append(hull)

    wing_right = [
        (0.42, 1.18),
        (1.44, 0.86),
        (2.20, 0.18),
        (2.04, -0.62),
        (1.42, -1.42),
        (0.72, -0.78),
        (0.52, -0.12),
    ]
    created.append(make_prism("Kestrel_Wing_R", wing_right, -0.18, 0.12, gunmetal, asset, root, 0.045))
    created.append(make_prism("Kestrel_Wing_L", mirrored(wing_right), -0.18, 0.12, gunmetal, asset, root, 0.045))

    armor_right = [
        (0.50, 1.06),
        (1.30, 0.78),
        (1.91, 0.22),
        (1.72, -0.34),
        (0.72, -0.15),
    ]
    created.append(make_prism("Kestrel_WingArmor_R", armor_right, 0.10, 0.23, ivory, asset, root, 0.025))
    created.append(make_prism("Kestrel_WingArmor_L", mirrored(armor_right), 0.10, 0.23, ivory, asset, root, 0.025))

    inset_right = [
        (0.68, 0.70),
        (1.27, 0.50),
        (1.60, 0.18),
        (1.42, -0.05),
        (0.74, 0.06),
    ]
    created.append(make_prism("Kestrel_WingInset_R", inset_right, 0.225, 0.265, void, asset, root, 0.012))
    created.append(make_prism("Kestrel_WingInset_L", mirrored(inset_right), 0.225, 0.265, void, asset, root, 0.012))

    silver_edge_right = [
        (1.77, 0.30),
        (2.20, 0.18),
        (2.04, -0.62),
        (1.84, -0.38),
    ]
    created.append(make_prism("Kestrel_LeadingEdge_R", silver_edge_right, 0.10, 0.20, silver, asset, root, 0.02))
    created.append(make_prism("Kestrel_LeadingEdge_L", mirrored(silver_edge_right), 0.10, 0.20, silver, asset, root, 0.02))

    canard_right = [(0.36, 1.72), (0.98, 1.40), (1.18, 1.12), (0.48, 1.28)]
    created.append(make_prism("Kestrel_Canard_R", canard_right, -0.02, 0.10, silver, asset, root, 0.018))
    created.append(make_prism("Kestrel_Canard_L", mirrored(canard_right), -0.02, 0.10, silver, asset, root, 0.018))

    tail_right = [(0.46, -0.72), (1.36, -1.42), (1.22, -1.72), (0.52, -1.24)]
    created.append(make_prism("Kestrel_Tailplane_R", tail_right, -0.10, 0.12, silver, asset, root, 0.025))
    created.append(make_prism("Kestrel_Tailplane_L", mirrored(tail_right), -0.10, 0.12, silver, asset, root, 0.025))

    spine = [(-0.10, 1.58), (0.10, 1.58), (0.14, -1.48), (0.0, -1.78), (-0.14, -1.48)]
    created.append(make_prism("Kestrel_EnergySpine", spine, 0.43, 0.50, cyan, asset, root, 0.016))

    spine_hot = [(-0.045, 0.92), (0.045, 0.92), (0.065, -0.62), (-0.065, -0.62)]
    created.append(make_prism("Kestrel_EnergyCore", spine_hot, 0.50, 0.535, hot, asset, root, 0.008))

    cockpit = make_ico("Kestrel_Cockpit", (0.0, 0.68, 0.48), (0.39, 0.78, 0.22), glass, asset, root, 2)
    cockpit.rotation_euler.z = math.radians(2.0)
    created.append(cockpit)
    created.append(make_ico("Kestrel_CockpitCore", (0.0, 0.37, 0.67), (0.12, 0.23, 0.065), cyan, asset, root, 1))

    shoulder_right = [(0.48, 0.62), (0.82, 0.50), (0.88, -0.42), (0.55, -0.58)]
    created.append(make_prism("Kestrel_Shoulder_R", shoulder_right, 0.24, 0.36, gunmetal, asset, root, 0.02))
    created.append(make_prism("Kestrel_Shoulder_L", mirrored(shoulder_right), 0.24, 0.36, gunmetal, asset, root, 0.02))

    for side, x in (("L", -0.88), ("R", 0.88)):
        created.append(
            make_box(
                f"Kestrel_CannonHousing_{side}",
                (x, 0.63, 0.34),
                (0.16, 0.40, 0.14),
                (0.0, 0.0, 0.0),
                gunmetal,
                asset,
                root,
                0.05,
            )
        )
        created.append(
            make_cylinder(
                f"Kestrel_CannonBarrel_{side}",
                (x, 1.14, 0.35),
                0.075,
                0.70,
                void,
                asset,
                root,
                vertices=8,
            )
        )
        created.append(
            make_cylinder(
                f"Kestrel_CannonEmitter_{side}",
                (x, 1.50, 0.35),
                0.048,
                0.08,
                cyan,
                asset,
                root,
                vertices=8,
            )
        )

    for side, x in (("L", -1.13), ("R", 1.13)):
        make_engine(f"Kestrel_Engine_{side}", x, -1.42, 0.05, 0.28, 0.74, asset, root, gunmetal, void, cyan)
    make_engine("Kestrel_Engine_C", 0.0, -1.90, -0.02, 0.23, 0.62, asset, root, gunmetal, void, hot)

    strip_right = [(1.70, 0.12), (1.78, 0.06), (1.51, -0.48), (1.43, -0.39)]
    created.append(make_prism("Kestrel_WingLight_R", strip_right, 0.26, 0.295, cyan, asset, root, 0.008))
    created.append(make_prism("Kestrel_WingLight_L", mirrored(strip_right), 0.26, 0.295, cyan, asset, root, 0.008))

    for side, sign in (("L", -1.0), ("R", 1.0)):
        for index, y in enumerate((-0.38, -0.62, -0.86)):
            created.append(
                make_box(
                    f"Kestrel_Vent_{side}_{index + 1}",
                    (sign * (0.73 + index * 0.025), y, 0.365),
                    (0.055, 0.10, 0.028),
                    (0.0, 0.0, sign * math.radians(8.0)),
                    void,
                    asset,
                    root,
                )
            )

    make_socket("Socket_MuzzleCenter", (0.0, 2.68, 0.18), asset, root)
    make_socket("Socket_MuzzleLeft", (-0.88, 1.57, 0.35), asset, root)
    make_socket("Socket_MuzzleRight", (0.88, 1.57, 0.35), asset, root)
    make_socket("Socket_EngineLeft", (-1.13, -1.84, 0.05), asset, root)
    make_socket("Socket_EngineRight", (1.13, -1.84, 0.05), asset, root)
    make_socket("Socket_EngineCenter", (0.0, -2.26, -0.02), asset, root)
    make_socket("Socket_UpgradeLeft", (-0.68, 0.0, 0.42), asset, root)
    make_socket("Socket_UpgradeRight", (0.68, 0.0, 0.42), asset, root)

    return root, created


def import_references(target: bpy.types.Collection) -> None:
    positions = [(-10.0, 4.0, 0.0), (-5.0, 4.0, 0.0), (0.0, 4.0, 0.0), (5.0, 4.0, 0.0), (10.0, 4.0, 0.0), (15.0, 4.0, 0.0)]
    for path, position in zip(REFERENCE_MODELS, positions):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        imported = [obj for obj in bpy.context.scene.objects if obj not in before]
        reference_root = bpy.data.objects.new(f"REF // {path.stem}", None)
        target.objects.link(reference_root)
        reference_root.location = position
        reference_root["source_path"] = str(path.relative_to(ROOT))
        for obj in imported:
            move_to_collection(obj, target)
            if obj.parent is None:
                obj.parent = reference_root
            obj.hide_render = True
    target.hide_render = True
    target.hide_viewport = True


def add_area_light(
    name: str,
    location: tuple[float, float, float],
    color: tuple[float, float, float],
    energy: float,
    size: float,
    target: bpy.types.Collection,
) -> bpy.types.Object:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    target.objects.link(obj)
    obj.location = location
    look_at(obj, (0.0, 0.0, 0.0))
    return obj


def setup_presentation(target: bpy.types.Collection) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    world = bpy.data.worlds.new("Farinuff Deep Space")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.004, 0.008, 0.025, 1.0)
    background.inputs["Strength"].default_value = 0.10
    scene.world = world

    platform_mat = make_material("PreviewPlatform", (0.008, 0.016, 0.045, 1.0), 0.25, 0.38)
    bpy.ops.mesh.primitive_plane_add(size=40.0, location=(0.0, 0.0, -0.34))
    plane = bpy.context.object
    plane.name = "Preview Ground"
    move_to_collection(plane, target)
    assign_material(plane, platform_mat)

    camera_data = bpy.data.cameras.new("Kestrel Preview Camera")
    camera = bpy.data.objects.new("Kestrel Preview Camera", camera_data)
    target.objects.link(camera)
    camera.location = (6.6, -7.8, 7.6)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 6.8
    camera_data.lens = 58.0
    look_at(camera, (0.0, 0.05, 0.06))
    scene.camera = camera

    add_area_light("Cyan Key", (-4.0, -2.0, 8.0), (0.36, 0.80, 1.0), 1150.0, 5.0, target)
    add_area_light("Violet Fill", (5.0, -1.0, 4.0), (0.44, 0.16, 1.0), 850.0, 4.0, target)
    add_area_light("Cool Rim", (0.0, 6.0, 5.0), (0.15, 0.58, 1.0), 1000.0, 3.0, target)
    add_area_light("Soft Top", (0.0, 0.0, 10.0), (0.72, 0.87, 1.0), 700.0, 6.0, target)

    return camera


def export_asset(asset: bpy.types.Collection) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.all_objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
        export_materials="EXPORT",
    )
    bpy.ops.object.select_all(action="DESELECT")


def render_previews(camera: bpy.types.Object) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.filepath = str(PREVIEW_PATH)
    camera.location = (6.6, -7.8, 7.6)
    camera.data.ortho_scale = 6.8
    look_at(camera, (0.0, 0.05, 0.06))
    bpy.ops.render.render(write_still=True)

    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.filepath = str(TOP_PATH)
    camera.location = (0.0, 0.0, 12.0)
    camera.data.ortho_scale = 6.25
    look_at(camera, (0.0, 0.08, 0.0))
    bpy.ops.render.render(write_still=True)


def mesh_stats(asset: bpy.types.Collection) -> tuple[int, int, int]:
    meshes = [obj for obj in asset.all_objects if obj.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    return len(meshes), sum(len(obj.data.vertices) for obj in meshes), triangles


def main() -> None:
    for path in (BLEND_PATH.parent, GLB_PATH.parent, PREVIEW_PATH.parent, TOP_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)

    reset_scene()
    asset = collection("KESTREL_ASSET")
    references = collection("REFERENCE_MODELS // Toggle viewport visibility to compare")
    presentation = collection("PRESENTATION // Not exported")

    root, _created = build_asset(asset)
    import_references(references)
    camera = setup_presentation(presentation)

    scene = bpy.context.scene
    scene["asset_name"] = "Farinuff Kestrel Interceptor"
    scene["asset_spec"] = "Original project-local low-poly player interceptor; reference-derived, not a replacement"
    scene["canonical_export"] = str(GLB_PATH.relative_to(ROOT))
    scene["reference_collection"] = references.name
    scene["orientation"] = "Blender +Y nose; glTF export uses standard Y-up conversion"
    scene["units"] = "Godot game units / meters"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    export_asset(asset)
    render_previews(camera)

    # Leave the useful three-quarter camera active when the .blend opens.
    camera.location = (6.6, -7.8, 7.6)
    camera.data.ortho_scale = 6.8
    look_at(camera, (0.0, 0.05, 0.06))
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.filepath = str(PREVIEW_PATH)
    scene.camera = camera
    bpy.context.view_layer.objects.active = root
    root.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    mesh_count, vertices, triangles = mesh_stats(asset)
    print(f"KESTREL_BLEND={BLEND_PATH}")
    print(f"KESTREL_GLB={GLB_PATH}")
    print(f"KESTREL_PREVIEW={PREVIEW_PATH}")
    print(f"KESTREL_TOP={TOP_PATH}")
    print(f"KESTREL_STATS=meshes:{mesh_count},vertices:{vertices},triangles:{triangles}")


if __name__ == "__main__":
    main()
