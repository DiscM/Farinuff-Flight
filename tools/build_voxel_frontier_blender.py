#!/usr/bin/env python3
"""Original, UV-textured voxel fleet and wreckage, authored in Blender.

Run with Blender --background --python tools/build_voxel_frontier_blender.py,
or call build_all() from a Blender console. Existing scenes are never cleared.
Grid cells form closed, hidden-face-culled rigid parts, not thousands of cubes.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import re
import struct
import sys

import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/models/voxel_frontier"
OUT = PACK / "meshes"
SOURCE = PACK / "source/voxel_frontier.blend"
PARTS = ("Body", "Port", "Starboard", "Weapon", "Reactor", "Engines")
PALETTES = {
    "basic": ("bb3d50", "f18479", "252b42", "ed9b65", "ffb77a", "8d7382"),
    "fast": ("d97535", "ffb568", "282c41", "f0d49e", "ffdc87", "a58261"),
    "bomber": ("4f9a62", "a1c87b", "273440", "c4d981", "c3ff85", "a99561"),
    "tank": ("70549b", "b393cf", "28263c", "c978aa", "f18cd5", "a48b86"),
    "sniper": ("407f9e", "8ac7d4", "252d43", "d99b62", "ffbc71", "888aa1"),
    "debris": ("687b96", "9cacc0", "30344e", "639eab", "639eab", "a48a68"),
}
DISPLAY = {
    "basic_enemy": "CINDER / Raider", "fast_enemy": "NEEDLE / Interceptor",
    "bomber_enemy": "MANTIS / Carrier", "tank_enemy": "BASTION / Heavy",
    "sniper_enemy": "LONGBOW / Marksman", "relay_fragment": "Broken relay arc",
    "solar_fragment": "Torn solar array", "cargo_wreck": "Ruptured freight pod",
    "engine_wreck": "Spent ion engine", "hull_fragment": "Sheared armor plate",
    "asteroid_cluster": "Mineral-bearing asteroid",
}


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def linear(hex_color):
    c = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c)


class Voxels:
    def __init__(self, cell=.25):
        self.cell = cell
        self.cells = {}

    def put(self, x, y, z, part="Body", role=0, tile=0):
        self.cells[x, y, z] = (part, role, tile)

    def box(self, x0, x1, y0, y1, z0, z1, part="Body", role=0, tile=0):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.put(x, y, z, part, role, tile)

    def mesh_objects(self, scene, asset_id, materials):
        # Outward counterclockwise quads. Separate face vertices keep hard normals.
        faces = (
            ((1,0,0), ((1,-1,-1),(1,1,-1),(1,1,1),(1,-1,1))),
            ((-1,0,0), ((-1,1,-1),(-1,-1,-1),(-1,-1,1),(-1,1,1))),
            ((0,1,0), ((1,1,-1),(-1,1,-1),(-1,1,1),(1,1,1))),
            ((0,-1,0), ((-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1))),
            ((0,0,1), ((-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))),
            ((0,0,-1), ((-1,1,-1),(1,1,-1),(1,-1,-1),(-1,-1,-1))),
        )
        result = []
        for part in dict.fromkeys(v[0] for v in self.cells.values()):
            verts, polys, slots, tiles = [], [], [], []
            for (x,y,z), (owner, role, tile) in self.cells.items():
                if owner != part:
                    continue
                for normal, corners in faces:
                    adjacent = self.cells.get((x+normal[0],y+normal[1],z+normal[2]))
                    if adjacent is not None and adjacent[0] == part:
                        continue
                    start = len(verts)
                    verts.extend(((x+a*.5)*self.cell,(y+b*.5)*self.cell,(z+c*.5)*self.cell) for a,b,c in corners)
                    polys.append(tuple(range(start,start+4)))
                    # A thin cut-edge palette on selected vertical faces provides
                    # depth without smoothing away the stepped voxel silhouette.
                    slots.append(1 if role == 0 and normal[2] == 0 and (x+y)%5 == 0 else role)
                    tiles.append(tile if normal[2] >= 0 else 10)
            mesh = bpy.data.meshes.new(f"VF_{asset_id}_{part}_mesh")
            mesh.from_pydata(verts, [], polys)
            mesh.update()
            uv = mesh.uv_layers.new(name="UVMap")
            for material in materials:
                mesh.materials.append(material)
            for face, role, tile in zip(mesh.polygons, slots, tiles):
                face.material_index = role
                col, row = tile%4, tile//4
                low_u, high_u = (col*64+2.5)/256, (col*64+61.5)/256
                low_v, high_v = 1-(row*64+61.5)/256, 1-(row*64+2.5)/256
                coords = ((low_u,low_v),(high_u,low_v),(high_u,high_v),(low_u,high_v))
                for loop, coord in zip(face.loop_indices,coords):
                    uv.data[loop].uv = coord
            obj = bpy.data.objects.new(f"VF_{asset_id}_{part}",mesh)
            scene.collection.objects.link(obj)
            obj["rigid_part"] = part
            result.append(obj)
        return result


def enemy_grid(role):
    step = {"basic":.25,"fast":.22,"bomber":.28,"tank":.28,"sniper":.24}[role]
    grid = Voxels(step)
    if role == "basic":
        for y in range(-8,12):
            width = max(0, 4-(y-6)) if y>6 else 2 if y<0 else 3
            grid.box(-width,width,y,y,-1,0,tile=1)
        for sign,part in ((-1,"Port"),(1,"Starboard")):
            for x in range(3,10):
                grid.box(sign*x,sign*x,-6+(x-3)//3,5-(x-3),-1,0,part,0,14)
                grid.put(sign*x,-3,1,part,3,4)
        grid.box(0,0,10,12,0,0,"Weapon",2,2)
        grid.box(-1,1,-1,2,1,1,"Reactor",4,3)
        engines = (-2,2,-9)
    elif role == "fast":
        grid.box(0,0,-16,16,-1,0,tile=1)
        grid.box(-1,1,-12,10,-1,0,tile=1)
        for sign,part in ((-1,"Port"),(1,"Starboard")):
            for x in range(2,6):
                grid.box(sign*x,sign*x,-14+(x-2),4-(x-2)*4,-1,0,part,0,4)
                grid.put(sign*x,-8+(x-2),1,part,1,15)
        grid.box(0,0,15,18,0,0,"Weapon",1,2)
        grid.box(0,0,-3,6,1,1,"Reactor",4,3)
        engines = (-1,1,-18)
    elif role == "bomber":
        grid.box(-3,3,-7,7,-1,0,tile=1)
        grid.box(-2,2,7,9,-1,0,tile=14)
        for sign,part in ((-1,"Port"),(1,"Starboard")):
            for x in range(4,15):
                reach = 6 if x<12 else 5-(x-12)
                grid.box(sign*x,sign*x,-reach,reach,-1,0,part,0,14)
                if x in (7,8,12):
                    grid.box(sign*x,sign*x,-4,4,1,1,part,3,4)
            grid.box(min(sign*8,sign*11),max(sign*8,sign*11),-2,2,1,1,part,2,2)
        grid.box(-1,1,8,9,1,1,"Weapon",3,12)
        for x in range(-2,3):
            for y in range(-2,3):
                if abs(x)+abs(y)<=3:
                    grid.put(x,y,1,"Reactor",4,3)
        engines = (-10,10,-8)
    elif role == "tank":
        grid.box(-4,4,-7,7,-1,1,tile=14)
        grid.box(-3,3,-6,6,2,2,role=2,tile=1)
        for sign,part in ((-1,"Port"),(1,"Starboard")):
            for x in range(5,11):
                reach = 9 if x<9 else 8-(x-9)
                grid.box(sign*x,sign*x,-reach,reach,-1,1,part,0,14)
                if x in (6,9):
                    grid.box(sign*x,sign*x,-6,6,2,2,part,1,4)
            for y in (-5,0,5):
                grid.box(min(sign*7,sign*8),max(sign*7,sign*8),y,y,2,2,part,3,12)
        grid.box(-1,1,7,10,1,1,"Weapon",2,13)
        grid.box(-2,2,-2,2,3,3,"Reactor",4,3)
        engines = (-7,7,-10)
    else:
        grid.box(-1,1,-14,12,-1,0,tile=1)
        grid.box(-2,2,-10,1,-1,0,tile=14)
        for sign,part in ((-1,"Port"),(1,"Starboard")):
            grid.box(min(sign*3,sign*5),max(sign*3,sign*5),-9,-3,-1,0,part,0,14)
            grid.box(sign*3,sign*3,-3,8,-1,0,part,0,4)
            grid.box(sign*5,sign*5,-8,-5,1,1,part,1,15)
        grid.box(0,0,8,18,0,1,"Weapon",3,2)
        grid.box(0,0,-5,1,1,1,"Reactor",4,3)
        engines = (-1,1,-16)
    left,right,rear = engines
    for x in (left,right):
        grid.box(x,x,rear,rear+2,-1,0,"Engines",2,13)
        grid.put(x,rear,0,"Engines",4,3)
    return grid, engines


def debris_grid(asset_id):
    g = Voxels(.28)
    if asset_id == "relay_fragment":
        for x in range(-10,11):
            for y in range(-9,10):
                r = math.hypot(x,y)
                if 7<=r<=10 and (y>0 or x<-5) and not(x>5 and y<5):
                    g.box(x,x,y,y,-1,0,tile=14)
                    if 7<=r<8:
                        g.put(x,y,1,role=3,tile=4)
        g.box(-4,-3,2,7,-1,0,role=2,tile=10)
        g.box(-2,3,1,2,-1,0,tile=6)
        g.box(-1,2,2,4,1,1,role=5,tile=12)
    elif asset_id == "solar_fragment":
        g.box(-8,8,-1,0,-1,0,role=2,tile=10)
        for x in range(-8,9):
            for y in range(-5,6):
                if (x>3 and y>2) or (x==8 and y<-1):
                    continue
                g.put(x,y,0,role=3 if x%4 else 1,tile=5)
        g.box(-2,1,-2,2,1,2,tile=6)
        g.box(-1,0,-1,1,3,3,role=5,tile=12)
    elif asset_id == "cargo_wreck":
        for x in range(-6,7):
            for y in range(-4,5):
                for z in range(-2,3):
                    if abs(x)<5 and abs(y)<3 and abs(z)<2:
                        continue
                    if x>3 and y+z>1:
                        continue
                    g.put(x,y,z,role=1 if x in (-4,3) else 0,tile=6 if z==2 else 1)
        g.box(-2,1,-1,1,2,2,role=5,tile=12)
        g.box(-6,-6,-2,2,-1,1,role=3,tile=4)
    elif asset_id == "engine_wreck":
        for y in range(-6,7):
            outer = 2 if y>2 else 3 if y>-2 else 4
            for x in range(-outer,outer+1):
                for z in range(-outer,outer+1):
                    radius = max(abs(x),abs(z)) + min(abs(x),abs(z))*.35
                    if outer-1.2<=radius<=outer+.3:
                        g.put(x,y,z,role=1 if y in (-5,1) else 0,tile=13)
        g.box(-2,2,5,6,-2,2,role=2,tile=2)
        g.box(-1,1,3,4,3,3,role=5,tile=12)
    elif asset_id == "hull_fragment":
        for x in range(-7,8):
            for y in range(-5,6):
                if abs(x)+abs(y)>10 or (x>2 and y<-2) or (x==0 and y==5):
                    continue
                g.box(x,x,y,y,-1,0,role=0,tile=14)
                if y==1:
                    g.put(x,y,1,role=3,tile=4)
        g.box(-5,-4,-3,3,1,1,role=1,tile=10)
        g.box(2,3,2,4,1,1,role=5,tile=12)
    else:
        for x in range(-6,7):
            for y in range(-5,6):
                for z in range(-4,5):
                    shape = (x/6)**2+(y/5)**2+(z/4)**2
                    shape += .13*math.sin(x*1.7+y*.8+z*2.1)
                    if shape<=1 and not(x>2 and y<-1 and z>1):
                        ore = (x+y*2-z)%17==0
                        g.put(x,y,z,role=5 if ore else 2 if z<0 else 0,tile=9 if ore else 8)
    return g


def make_materials(role, atlas):
    mats = []
    for index, (slot,hex_color) in enumerate(zip(("armor","edge","structure","trim","reactor","brass"),PALETTES[role])):
        mat = bpy.data.materials.new(f"VF_{role}_{slot}")
        mat.diffuse_color = (*linear(hex_color),1)
        mat.use_nodes = True
        nodes,links = mat.node_tree.nodes,mat.node_tree.links
        bsdf = next(n for n in nodes if n.type=="BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*linear(hex_color),1)
        bsdf.inputs["Metallic"].default_value = .0
        bsdf.inputs["Roughness"].default_value = .88
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = atlas
        tex.interpolation = "Closest"
        multiply = nodes.new("ShaderNodeMixRGB")
        multiply.blend_type = "MULTIPLY"
        multiply.inputs[0].default_value = 1
        multiply.inputs[2].default_value = (*linear(hex_color),1)
        links.new(tex.outputs["Color"],multiply.inputs[1])
        links.new(multiply.outputs[0],bsdf.inputs["Base Color"])
        if index==4 and role!="debris":
            bsdf.inputs["Emission Color"].default_value = (*linear(hex_color),1)
            bsdf.inputs["Emission Strength"].default_value = .8
        mats.append(mat)
    return mats


def rig_enemy(scene, asset_id, role, meshes, grid, engines, motion):
    arm = bpy.data.armatures.new(f"VF_{asset_id}_rig")
    rig = bpy.data.objects.new(f"VF_{asset_id}_MotionRig",arm)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    hinge = max(abs(p[0])*grid.cell for p in grid.cells)*.2
    for name,head in (("Body",(0,0,0)),("Port",(-hinge,0,0)),("Starboard",(hinge,0,0)),("Weapon",(0,grid.cell*7,0))):
        b = arm.edit_bones.new(name)
        b.head = head
        b.tail = Vector(head)+Vector((0,.35,0))
        if name!="Body":
            b.parent = arm.edit_bones["Body"]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in meshes:
        part = obj["rigid_part"]
        bone = part if part in motion.BONES else "Body"
        obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,"REPLACE")
        mod = obj.modifiers.new("Rigid voxel panels","ARMATURE")
        mod.object = rig
        obj.parent = rig
    max_y = max(p[1] for p,v in grid.cells.items() if v[0]=="Weapon")+.5
    sockets = {"Socket_Muzzle":((0,max_y*grid.cell,grid.cell*.5),"Weapon")}
    for label,x in (("Left",engines[0]),("Right",engines[1])):
        sockets["Socket_Engine"+label] = ((x*grid.cell,(engines[2]-.5)*grid.cell,0),"Body")
        if role=="bomber":
            sockets["Socket_Payload"+label] = ((x*grid.cell,grid.cell*6,0),"Port" if x<0 else "Starboard")
    for socket,(position,bone) in sockets.items():
        obj = bpy.data.objects.new(socket,None)
        scene.collection.objects.link(obj)
        obj.location = position
        bpy.context.view_layer.update()
        matrix = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = matrix
    rig.animation_data_create()
    for clip,keys in motion.clips(role).items():
        action = bpy.data.actions.new(f"VF_{asset_id}__{clip}")
        rig.animation_data.action = action
        for seconds,pose in keys:
            motion.key_pose(rig,pose,1+seconds*30)
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip,1,action)
        strip.name = clip
        rig.animation_data.action = None
    scene.frame_set(1)
    return rig


def export(scene, asset_id, animated):
    bpy.ops.object.select_all(action="SELECT")
    path = OUT / f"{asset_id}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        use_active_scene=True,export_yup=True,export_animations=animated,
        export_animation_mode="NLA_TRACKS",export_force_sampling=True,export_frame_range=False,
        export_skins=animated,export_def_bones=True,export_anim_single_armature=False,
        export_cameras=False,export_lights=False,export_extras=False,export_image_format="AUTO")
    # Object IDs are global in a .blend; socket IDs are local to each GLB.
    data=path.read_bytes()
    length=struct.unpack_from("<I",data,12)[0]
    doc=json.loads(data[20:20+length])
    # Blender 5.2 exports the shared image but can omit the constant input of
    # its Multiply node. Preserve that authored linear tint explicitly in glTF.
    # This is the same multiplication the editable Blender material performs.
    slots=("armor","edge","structure","trim","reactor","brass")
    for material in doc.get("materials",[]):
        canonical=re.sub(r"\.\d+$","",material["name"])
        _,role,slot=canonical.split("_",2)
        material.setdefault("pbrMetallicRoughness",{})["baseColorFactor"]=[*linear(PALETTES[role][slots.index(slot)]),1.0]
    for node in doc.get("nodes",[]):
        if node.get("name","").startswith("Socket_"):
            node["name"]=re.sub(r"\.\d+$","",node["name"])
    encoded=json.dumps(doc,separators=(",",":")).encode()
    encoded+=b" "*((-len(encoded))%4)
    tail=data[20+length:]
    path.write_bytes(struct.pack("<4sII",b"glTF",2,20+len(encoded)+len(tail))+struct.pack("<I4s",len(encoded),b"JSON")+encoded+tail)
    return {"id":asset_id,"display_name":DISPLAY[asset_id],"file":f"meshes/{asset_id}.glb",
            "category":"enemy" if animated else "debris","bytes":path.stat().st_size,
            "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"animations":[a["name"] for a in doc.get("animations",[])],
            "meshes":len(doc.get("meshes",[])),"embedded_images":len(doc.get("images",[]))}


def create_studio(board):
    """A render-ready contact sheet; studio objects are never exported to GLB."""
    studio = bpy.data.collections.new("Presentation | camera, light and typography")
    board.collection.children.link(studio)

    def surface(name, color, emission=0):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*linear(color), 1)
        bsdf.inputs["Roughness"].default_value = .95
        bsdf.inputs["Emission Color"].default_value = (*linear(color), 1)
        bsdf.inputs["Emission Strength"].default_value = emission
        return mat

    ink = surface("VF_Studio_Ice", "c6e5ef", .7)
    muted = surface("VF_Studio_Slate", "7b9cad", .7)
    accent = surface("VF_Studio_Cyan", "55d4d6", .7)

    def label(name, text, xy, size, material, centered=False):
        data = bpy.data.curves.new(name, "FONT")
        data.body = text
        data.size = size
        data.align_x = "CENTER" if centered else "LEFT"
        obj = bpy.data.objects.new(name, data)
        studio.objects.link(obj)
        obj.location = (*xy, .02)
        obj.data.materials.append(material)
        return obj

    label("Title", "VOXEL FRONTIER", (-25.5, 18.0), 1.7, ink)
    label("Brand", "F A R I N U F F   F L I G H T   /   A S S E T   L I B R A R Y   0 1", (-25.5, 21.0), .5, accent)
    label("Subtitle", "FIVE HOSTILE HULLS   /   SIX SALVAGE FORMS", (-25.5, 16.4), .47, muted)
    for index, asset_id in enumerate(DISPLAY):
        enemy = index < 5
        x = (index - 2) * 10 if enemy else (index - 7.5) * 9
        y = 2.5 if enemy else -12.0
        title = DISPLAY[asset_id].split(" / ")[0].upper()
        label("Caption | " + asset_id, title, (x, y), .51 if enemy else .40, ink, True)
        detail = DISPLAY[asset_id].split(" / ")[-1].upper() if enemy else "SALVAGE  /  %02d" % (index + 1)
        label("Detail | " + asset_id, detail, (x, y - .95), .34, muted, True)
    label("Footer", "ORIGINAL VOXEL GEOMETRY   /   SHARED PIXEL ATLAS   /   ANIMATED COMBAT RIGS", (-25.5, -16.0), .40, muted)
    label("Version", "COLLECTION 1.0", (19, -16.0), .40, accent)

    floor_mesh = bpy.data.meshes.new("VF_Studio_Backdrop_mesh")
    floor_mesh.from_pydata([(-120,-120,-2.4),(120,-120,-2.4),(120,120,-2.4),(-120,120,-2.4)], [], [(0,1,2,3)])
    floor = bpy.data.objects.new("VF_Studio_Backdrop", floor_mesh)
    studio.objects.link(floor)
    floor.data.materials.append(surface("VF_Studio_Midnight", "152636"))
    world = bpy.data.worlds.new("VF_Studio_World")
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (.18,.24,.32,1)
    background.inputs["Strength"].default_value = .55
    board.world = world
    for name, position, power, size in [("Key",(-16,-10,30),4200,22),("Fill",(22,10,23),3000,18)]:
        data = bpy.data.lights.new("VF_Studio_" + name, "AREA")
        data.energy, data.size = power, size
        obj = bpy.data.objects.new(data.name, data)
        studio.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()
    data = bpy.data.cameras.new("VF_Studio_Camera")
    data.type, data.ortho_scale = "ORTHO", 60
    camera = bpy.data.objects.new(data.name, data)
    studio.objects.link(camera)
    camera.location = (0,-33,78)
    camera.rotation_euler = (Vector((0,2,0))-camera.location).to_track_quat("-Z", "Y").to_euler()
    board.camera = camera
    board.render.resolution_x, board.render.resolution_y = 2100, 1400
    board.render.resolution_percentage = 100
    board.render.image_settings.file_format = "PNG"
    board.render.film_transparent = False
    board.view_settings.exposure = .65
    board.render.filepath = str(ROOT / "design/voxel-frontier/blender/collection.png")
    Path(board.render.filepath).parent.mkdir(parents=True, exist_ok=True)


def build_all():
    if bpy.context.object and bpy.context.object.mode!="OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    OUT.mkdir(parents=True,exist_ok=True)
    SOURCE.parent.mkdir(parents=True,exist_ok=True)
    (SOURCE.parent/".gdignore").write_text("")
    atlas_path=PACK/"textures/voxel_surface_atlas.png"
    if not atlas_path.exists():
        raise RuntimeError("Build the texture atlas first")
    atlas=bpy.data.images.load(str(atlas_path),check_existing=False)
    atlas.pack()
    mats={role:make_materials(role,atlas) for role in PALETTES}
    motion=module(ROOT/"tools/build_combat_motion_blender.py","vf_motion")
    scenes,records=[],[]
    for asset_id in DISPLAY:
        scene=bpy.data.scenes.new("Voxel Frontier | "+asset_id)
        bpy.context.window.scene=scene
        scene.render.fps=30
        scene.frame_start,scene.frame_end=1,79
        enemy=asset_id.endswith("_enemy")
        role=asset_id.removesuffix("_enemy") if enemy else "debris"
        if enemy:
            grid,engines=enemy_grid(role)
        else:
            grid=debris_grid(asset_id)
        meshes=grid.mesh_objects(scene,asset_id,mats[role])
        rig=rig_enemy(scene,asset_id,role,meshes,grid,engines,motion) if enemy else None
        record=export(scene,asset_id,enemy)
        record["voxel_size"]=grid.cell
        records.append(record)
        if rig:
            for track in rig.animation_data.nla_tracks:
                track.mute=track.name!="cruise"
        scene.frame_set(1)
        scene["asset_id"]=asset_id
        scene["orientation"]="Blender +Y nose, +Z up; glTF -Z forward, +Y up"
        scene["source"]="Original voxel geometry; hidden faces culled within each rigid part"
        scenes.append(scene)
    # A contact sheet scene shares the editable geometry with isolated assets.
    board=bpy.data.scenes.new("Voxel Frontier | Collection")
    bpy.context.window.scene=board
    for index,scene in enumerate(scenes):
        collection=bpy.data.collections.new("Library | "+scene["asset_id"])
        board.collection.children.link(collection)
        originals=list(scene.objects)
        clones={o:o.copy() for o in originals}
        for old,obj in clones.items():
            collection.objects.link(obj)
            if old.parent:
                obj.parent=clones[old.parent]
            else:
                offset=Vector(((index-2)*10,8,0)) if index<5 else Vector(((index-7.5)*9,-7,0))
                obj.location+=offset
            for mod in obj.modifiers:
                if mod.type=="ARMATURE":
                    mod.object=clones[old.parent]
    board["readme"]="11 original voxel assets. Isolated scenes contain export-ready origin transforms. Shared UV atlas is packed."
    create_studio(board)
    scenes.append(board)
    bpy.data.libraries.write(str(SOURCE),set(scenes),fake_user=True,compress=True)
    (PACK/"build_manifest.json").write_text(json.dumps({"version":"1.0.0","authoring":"Original Blender-authored voxel assets",
        "blender_version":bpy.app.version_string,"atlas":"textures/voxel_surface_atlas.png","assets":records},indent=2)+"\n")
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type in {"VIEW_3D","CONSOLE"}:
            area.type="VIEW_3D"
            view=area.spaces.active
            view.shading.type="MATERIAL"
            view.overlay.show_overlays=False
            view.region_3d.view_distance=52
            view.region_3d.view_location=Vector((0,0,0))
            view.region_3d.view_rotation=Quaternion((1,0,0),math.radians(25))
            view.region_3d.view_perspective="ORTHO"
            break
    print("VOXEL_FRONTIER_EXPORTED",json.dumps(records))
    return records


def finalize_source():
    """Open only the exported library, then save a portable, camera-ready file."""
    if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        raise RuntimeError("Open the generated voxel_frontier.blend before finalizing")
    if any(not scene.name.startswith("Voxel Frontier | ") for scene in bpy.data.scenes):
        raise RuntimeError("Unexpected scene in generated source; refusing to rewrite")
    for scene in bpy.data.scenes:
        scene.name = re.sub(r"\.\d+$", "", scene.name)
    board = bpy.data.scenes["Voxel Frontier | Collection"]
    bpy.context.window.scene = board
    board.render.filepath = "//../../../../design/voxel-frontier/blender/collection.png"
    for atlas in bpy.data.images:
        if atlas.packed_file:
            atlas.filepath = "//../textures/voxel_surface_atlas.png"
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.shading.type = "MATERIAL"
                area.spaces.active.overlay.show_overlays = False
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True, relative_remap=False)
    print("VOXEL_FRONTIER_SOURCE_READY", str(SOURCE))


if __name__=="__main__":
    if "--finalize-source" in sys.argv:
        finalize_source()
    else:
        build_all()
