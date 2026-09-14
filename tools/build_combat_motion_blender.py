#!/usr/bin/env python3
"""Blender-authored rigid spacecraft animation, preserving the approved meshes.

Run build_all() inside Blender. Original GLBs remain the geometry/palette source;
four rigid bones add articulation without extra mesh instances or soft bending.
All distances are authored in Blender (+Y nose, Z up), then exported as Y-up GLB.
"""
from pathlib import Path
import json
import math
import re
import struct

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/animated"
FPS = 30
BONES = ("Body", "Port", "Starboard", "Weapon")
ENEMIES = ("basic", "fast", "bomber", "tank", "sniper")
PLAYERS = ("player_butterfly", "player_butterfly_morpho", "player_butterfly_monarch")
MODULES = ("twin_cannons", "auto_aim", "drone_escort", "hull_plating", "afterburner",
           "spread_shot", "shield_burst", "magnet_field", "overclock", "rear_gunner")
BOSSES = ("assault", "bulwark", "tempest", "void_harbinger", "tempest_core")


def sources():
    entries = [(f"{role}_enemy", f"redesign/next_round/{role}_enemy.glb", role) for role in ENEMIES]
    entries += [(name, f"redesign/{name}.glb", "player") for name in PLAYERS]
    entries += [(f"bf_elite_{name}", f"redesign/butterfly_elites/bf_elite_{name}.glb", "module") for name in MODULES]
    entries += [(f"upgrade_{name}", f"native/upgrade_{name}.glb", "module") for name in ("orbitals", "piercing", "explosive")]
    entries += [(f"boss_{name}", f"mockups/boss_{name}_mockup.glb", "boss") for name in BOSSES]
    return entries


def components(mesh):
    """Connect coincident split normals as well as indexed polygon vertices."""
    parent = list(range(len(mesh.vertices)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    def join(a, b):
        parent[find(a)] = find(b)
    positions = {}
    for v in mesh.vertices:
        key = tuple(round(c, 5) for c in v.co)
        if key in positions:
            join(v.index, positions[key])
        else:
            positions[key] = v.index
    for polygon in mesh.polygons:
        for i in polygon.vertices[1:]:
            join(polygon.vertices[0], i)
    groups = {}
    for v in mesh.vertices:
        groups.setdefault(find(v.index), []).append(v.index)
    return groups.values()


def part_bone(lo, hi, role, width):
    center = (lo + hi) * 0.5
    if role in ("player", "module"):
        # Antennae and forward gun upgrades recoil separately from the wings.
        if lo.y > 1.15:
            return "Weapon"
        if lo.x > 0.12 and center.x > 0.3:
            return "Starboard"
        if hi.x < -0.12 and center.x < -0.3:
            return "Port"
    else:
        threshold = width * {"basic": 0.12, "fast": 0.10, "tank": 0.15,
                             "bomber": 0.13, "sniper": 0.12, "boss": 0.12}[role]
        if lo.x > 0.02 and center.x > threshold:
            return "Starboard"
        if hi.x < -0.02 and center.x < -threshold:
            return "Port"
        if role == "sniper" and lo.y > 0.25:
            return "Weapon"
    return "Body"


def pose(fold=0.0, sweep=0.0, spread=0.0, recoil=0.0, pitch=0.0, lift=0.0, scale=1.0):
    return dict(fold=fold, sweep=sweep, spread=spread, recoil=recoil, pitch=pitch, lift=lift, scale=scale)


def clips(role):
    """Key poses: anticipation, impulse, overshoot and settle, in seconds/degrees."""
    player = role in ("player", "module")
    idle = 4.0 if player else {"basic": 2.5, "fast": 3.5, "tank": 1.2, "bomber": 1.5, "sniper": 1.0, "boss": 1.0}[role]
    result = {
        "cruise": [(0, pose()), (.65, pose(fold=idle)), (1.3, pose()), (1.95, pose(fold=-idle*.5)), (2.6, pose())],
        "hit": [(0, pose()), (.05, pose(pitch=-3, recoil=.08)), (.13, pose(pitch=1)), (.26, pose())],
    }
    if player:
        result.update({
            "attack": [(0, pose()), (.035, pose(recoil=.14, fold=2)), (.09, pose(recoil=-.025)), (.18, pose())],
            "boost": [(0, pose(fold=17, sweep=12)), (.2, pose(fold=21, sweep=14)), (.4, pose(fold=17, sweep=12))],
            "boost_attack": [(0, pose(fold=17,sweep=12)), (.035,pose(fold=19,sweep=12,recoil=.14)), (.18,pose(fold=17,sweep=12))],
            "upgrade": [(0, pose()), (.14, pose(fold=-10, spread=.06)), (.32, pose(fold=5)), (.65, pose())],
            "deploy": [(0, pose(scale=.82,lift=.3)), (.28,pose(scale=1.045,lift=.03)), (.52,pose())],
        })
    else:
        anticipation = {
            "basic": pose(fold=20,sweep=12), "fast": pose(fold=28,sweep=16),
            "tank": pose(fold=-9,spread=.20), "bomber": pose(fold=-20,spread=.16),
            "sniper": pose(fold=-12,spread=.16,recoil=-.22),
            "boss": pose(fold=-8,spread=.22),
        }[role]
        impulse = {
            "basic": pose(fold=26,sweep=18,pitch=3), "fast": pose(fold=34,sweep=20),
            "tank": pose(fold=5,spread=.28,recoil=.14), "bomber": pose(fold=-24,spread=.24,recoil=.08),
            "sniper": pose(fold=5,recoil=.5),
            "boss": pose(fold=5,spread=.32),
        }[role]
        result["windup"] = [(0,pose()), (.38,anticipation), (.55,anticipation)]
        result["attack"] = [(0,anticipation), (.045,impulse), (.12,impulse), (.34,pose())]
    return result


def key_pose(rig, values, frame):
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0,0,0)
        pb.rotation_euler = (0,0,0)
        pb.scale = (1,1,1)
    body = rig.pose.bones["Body"]
    body.location.z = values["lift"]
    body.rotation_euler.x = math.radians(values["pitch"])
    body.scale = (values["scale"],)*3
    for name, side in (("Port",-1), ("Starboard",1)):
        pb = rig.pose.bones[name]
        pb.rotation_euler.y = math.radians(-side * values["fold"])
        pb.rotation_euler.z = math.radians(-side * values["sweep"])
        pb.location.x = side * values["spread"]
    rig.pose.bones["Weapon"].location.y = -values["recoil"]
    for pb in rig.pose.bones:
        for prop in ("location","rotation_euler","scale"):
            pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)


def build_asset(name, source, role):
    previous = bpy.data.scenes.get(f"Motion | {name}")
    if previous is not None:
        bpy.data.scenes.remove(previous)
    scene = bpy.data.scenes.new(f"Motion | {name}")
    bpy.context.window.scene = scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1,79
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models" / source))
    objects = list(scene.objects)
    meshes = [o for o in objects if o.type == "MESH"]
    points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    width = max(v.x for v in points)-min(v.x for v in points)
    hinge = .18 if role in ("player","module") else width*.10
    arm = bpy.data.armatures.new(f"{name} Rigid Rig")
    rig = bpy.data.objects.new("MotionRig",arm)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, head in (("Body",(0,0,0)), ("Port",(-hinge,0,0)), ("Starboard",(hinge,0,0)), ("Weapon",(0,1.2,0))):
        bone = arm.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = Vector(head)+Vector((0,.35,0))
        if bone_name != "Body":
            bone.parent = arm.edit_bones["Body"]
    bpy.ops.object.mode_set(mode="OBJECT")
    counts = {b:0 for b in BONES}
    # Bake object transforms before binding; the neutral export is identical.
    for obj in meshes:
        transform = obj.matrix_world.copy()
        obj.parent = None
        obj.data.transform(transform)
        obj.matrix_world = Matrix.Identity(4)
        groups = {b:obj.vertex_groups.new(name=b) for b in BONES}
        for indices in components(obj.data):
            coords = [obj.data.vertices[i].co for i in indices]
            lo = Vector([min(v[a] for v in coords) for a in range(3)])
            hi = Vector([max(v[a] for v in coords) for a in range(3)])
            bone_name = part_bone(lo,hi,role,width)
            groups[bone_name].add(indices,1.0,"REPLACE")
            counts[bone_name] += len(indices)
        mod = obj.modifiers.new("Rigid articulation","ARMATURE")
        mod.object = rig
        obj.parent = rig
    # Markers follow the same rigid part; Godot wrappers copy these transforms.
    for obj in objects:
        if obj.type != "EMPTY" or not obj.name.startswith("Socket_"):
            continue
        matrix = obj.matrix_world.copy()
        p = matrix.translation
        bone_name = part_bone(p,p,role,width)
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
        bpy.context.view_layer.update()
        obj.matrix_world = matrix
    # Empty import hierarchy is unnecessary after baking mesh transforms.
    for obj in objects:
        if obj.type == "EMPTY" and not obj.name.startswith("Socket_"):
            bpy.data.objects.remove(obj,do_unlink=True)
    rig.animation_data_create()
    for clip, keys in clips(role).items():
        action = bpy.data.actions.new(f"{name}__{clip}")
        rig.animation_data.action = action
        for seconds, values in keys:
            key_pose(rig,values,1+seconds*FPS)
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip,1,action)
        strip.name = clip
        # Smooth custom authored curves retain a brisk attack impulse.
        for layer in action.layers:
            for strip_data in layer.strips:
                for bag in strip_data.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = "BEZIER"
                            key.handle_left_type = key.handle_right_type = "AUTO_CLAMPED"
        rig.animation_data.action = None
    scene.frame_set(1)
    bpy.ops.object.select_all(action="SELECT")
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f"{name}.glb"),export_format="GLB",
        use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,export_frame_range=False,export_skins=True,
        export_def_bones=True,export_anim_single_armature=False,
        export_optimize_animation_size=True,export_yup=True)
    # Blender names are globally unique across studio scenes. glTF node names
    # are local to each asset, so restore the original socket lookup contract.
    path = OUT/f"{name}.glb"
    data = path.read_bytes()
    json_size = struct.unpack_from("<I",data,12)[0]
    document = json.loads(data[20:20+json_size])
    for node in document["nodes"]:
        if "name" in node:
            node["name"] = re.sub(r"\.\d+$","",node["name"])
    encoded = json.dumps(document,separators=(",",":")).encode()
    encoded += b" "*((-len(encoded))%4)
    tail = data[20+json_size:]
    path.write_bytes(struct.pack("<4sII",b"glTF",2,20+len(encoded)+len(tail))+
                     struct.pack("<I4s",len(encoded),b"JSON")+encoded+tail)
    # The source opens on the cruise loop, with every action editable in the NLA.
    for track in rig.animation_data.nla_tracks:
        track.mute = track.name != "cruise"
    scene.frame_set(1)
    scene["source_asset"] = source
    scene["motion_notes"] = "Rigid panels; no mesh stretching. Attack clips are driven by live gameplay events."
    return dict(asset=name,source=source,role=role,bones=counts,meshes=len(meshes),clips=list(clips(role)))


def build_all():
    records = [build_asset(*entry) for entry in sources()]
    source_dir = OUT/"sources"
    source_dir.mkdir(exist_ok=True)
    (source_dir/".gdignore").write_text("")
    scenes = {s for s in bpy.data.scenes if s.name.startswith("Motion | ")}
    bpy.data.libraries.write(str(source_dir/"farinuff_combat_motion.blend"),scenes,fake_user=True,compress=True)
    (OUT/"manifest.json").write_text(json.dumps({"authoring":"Blender rigid four-bone rigs", "fps":FPS,"assets":records},indent=2)+"\n")
    bpy.context.window.scene = next(s for s in scenes if s.name == "Motion | player_butterfly")
    print("COMBAT_MOTION_EXPORTED",len(records),records)


if __name__ == "__main__":
    build_all()
