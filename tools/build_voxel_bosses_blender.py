#!/usr/bin/env python3
"""Original articulated voxel bosses. Run in Blender; existing scenes are preserved.

Blender +Y nose / +Z up becomes glTF -Z forward / +Y up. All exports use
four rigid bones, a packed shared atlas, and the runtime's four motion clips.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import re
import shutil
import struct
import sys

import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/models/voxel_bosses"
SOURCE = PACK / "source/voxel_bosses.blend"
PREVIEW = ROOT / "design/voxel-bosses/blender/collection.png"
PREFIX = "Voxel Bosses | "
IDS = ("boss_assault", "boss_bulwark", "boss_tempest", "boss_void_harbinger", "boss_tempest_core", "tempest_section")
ROLES = ("assault", "bulwark", "tempest", "void_harbinger", "tempest_core", "section")
TITLES = ("ASSAULT COMMANDER", "IRON BULWARK", "TEMPEST", "VOID HARBINGER", "TEMPEST CORE", "ORBITAL WEAPON POD")
SUBTITLES = ("SCARLET SPEARHEAD", "ARMORED CITADEL", "STORM VANE ARRAY", "SPECTRAL CROWN", "AMBER REACTOR", "DESTRUCTIBLE / ANIMATED")
PALETTES = {
    "assault": ("b43d4b", "ea8069", "26263e", "cf8652", "ffc184", "7f6884"),
    "bulwark": ("795599", "b197cb", "29263e", "ca739e", "ff9fd2", "b5a070"),
    "tempest": ("3e819f", "82cbd6", "252b45", "5c78bd", "9ae8fa", "88809c"),
    "void_harbinger": ("657d43", "b2c97b", "30253e", "7d66a1", "d0ffa0", "a08b60"),
    "tempest_core": ("a87739", "e0bc74", "30283f", "a082ae", "ffe1a1", "a68b70"),
    "section": ("667c96", "afbad1", "29283f", "b89557", "ffe0a0", "85789c"),
}


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


fleet = module("build_voxel_frontier_blender")
motion = module("build_combat_motion_blender")
poses = module("voxel_boss_motion")


def polygon(grid, points, z0, z1, part="Body", role=0, tile=0):
    """Rasterize a crisp polygon to integer cells with no sliver geometry."""
    for x in range(math.floor(min(p[0] for p in points)), math.ceil(max(p[0] for p in points)) + 1):
        for y in range(math.floor(min(p[1] for p in points)), math.ceil(max(p[1] for p in points)) + 1):
            inside = False
            for a, b in zip(points, points[1:] + points[:1]):
                if (a[1] > y) != (b[1] > y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:
                    inside = not inside
            if inside:
                grid.box(x,x,y,y,z0,z1,part,role,tile)


def diamond(grid, cx, cy, radius, z0, z1, part="Body", role=0, tile=0):
    for x in range(cx-radius,cx+radius+1):
        for y in range(cy-radius,cy+radius+1):
            if abs(x-cx)+abs(y-cy) <= radius:
                grid.box(x,x,y,y,z0,z1,part,role,tile)


def stripe(grid, x0, y0, x1, y1, z, part, role=3, tile=4, width=0):
    steps=max(abs(x1-x0),abs(y1-y0),1)
    for step in range(steps+1):
        x=round(x0+(x1-x0)*step/steps)
        y=round(y0+(y1-y0)*step/steps)
        grid.box(x-width,x+width,y-width,y+width,z,z,part,role,tile)


def engines(grid, x, y):
    for side in (-1,1):
        grid.box(side*x-1,side*x+1,y-1,y+2,-1,1,"Engines",2,13)
        grid.box(side*x-1,side*x+1,y-2,y-2,0,1,"Engines",4,13)


def geometry(role):
    g=fleet.Voxels(.28)
    if role == "assault":
        polygon(g,[(-2,-12),(-5,-4),(-5,4),(-2,15),(0,22),(2,15),(5,4),(5,-4),(2,-12)],-2,1,role=2,tile=10)
        polygon(g,[(-2,-11),(-4,0),(-2,13),(0,20),(2,13),(4,0),(2,-11)],2,3,role=0,tile=14)
        for side,part in [(-1,"Port"),(1,"Starboard")]:
            polygon(g,[(side*x,y) for x,y in [(4,7),(17,2),(17,-3),(10,-10),(4,-6)]],-1,1,part,0,0)
            polygon(g,[(side*x,y) for x,y in [(5,4),(15,1),(14,-2),(9,-7),(5,-4)]],2,2,part,1,14)
            stripe(g,side*6,3,side*14,0,3,part,3,4)
            g.box(side*8-1,side*8+1,3,13,1,2,"Weapon",2,2)
            g.box(side*8-1,side*8+1,12,14,2,3,"Weapon",3,13)
        g.box(-1,1,6,21,2,3,"Weapon",0,0)
        g.box(0,0,6,20,4,4,"Weapon",3,4)
        diamond(g,0,0,3,4,4,"Reactor",4,3)
        engines(g,4,-11)
        engine=(4,-13)
    elif role == "bulwark":
        outline=[(-10,-10),(-16,-5),(-17,3),(-12,9),(0,11),(12,9),(17,3),(16,-5),(10,-10)]
        polygon(g,outline,-2,0,role=2,tile=10)
        polygon(g,[(-7,-8),(-9,-1),(-6,7),(0,9),(6,7),(9,-1),(7,-8)],1,2,role=0,tile=14)
        for side,part in [(-1,"Port"),(1,"Starboard")]:
            polygon(g,[(side*x,y) for x,y in [(8,8),(15,6),(17,2),(16,-6),(11,-9),(8,-5)]],1,4,part,0,14)
            g.box(min(side*12,side*14),max(side*12,side*14),-5,5,5,5,part,1,15)
            for y in (-5,0,5):
                g.box(min(side*11,side*15),max(side*11,side*15),y,y,6,6,part,3,4)
            g.box(side*7-1,side*7+1,-4,6,3,4,part,2,2)
            g.box(side*7,side*7,5,8,5,5,part,4,13)
        diamond(g,0,0,6,3,3,role=2,tile=1)
        diamond(g,0,0,3,4,5,"Reactor",4,3)
        polygon(g,[(-4,5),(-3,8),(0,11),(3,8),(4,5)],3,4,"Weapon",1,14)
        g.box(-1,1,8,11,4,5,"Weapon",3,13)
        engines(g,5,-8)
        engine=(5,-10)
    elif role == "tempest":
        diamond(g,0,0,7,-1,1,role=2,tile=10)
        for side,part in [(-1,"Port"),(1,"Starboard")]:
            for end in (-1,1):
                polygon(g,[(side*x,end*y) for x,y in [(3,2),(8,4),(17,13),(17,17),(13,16),(5,8)]],0,2,part,0,0)
                stripe(g,side*6,end*6,side*15,end*15,3,part,1,4)
                g.box(side*14-1,side*14+1,end*14-1,end*14+1,3,3,part,4,3)
                stripe(g,side*7,end*4,side*13,end*10,3,part,3,2)
        diamond(g,0,0,5,2,3,role=1,tile=15)
        diamond(g,0,0,3,4,4,"Reactor",4,3)
        g.box(-2,-1,5,10,1,2,"Weapon",2,13)
        g.box(1,2,5,10,1,2,"Weapon",2,13)
        g.box(-2,2,6,7,3,3,"Weapon",3,12)
        engines(g,3,-5)
        engine=(3,-7)
    elif role == "void_harbinger":
        polygon(g,[(-2,-12),(-5,-6),(-5,2),(-3,10),(0,14),(3,10),(5,2),(5,-6),(2,-12)],-2,1,role=2,tile=10)
        for side,part in [(-1,"Port"),(1,"Starboard")]:
            polygon(g,[(side*x,y) for x,y in [(4,6),(14,5),(18,-1),(15,-7),(8,-9),(4,-4)]],-1,1,part,2,0)
            polygon(g,[(side*x,y) for x,y in [(5,5),(14,3),(16,-1),(14,-5),(9,-6),(5,-3)]],2,3,part,0,14)
            stripe(g,side*8,3,side*14,1,4,part,1,4)
            polygon(g,[(side*x,y) for x,y in [(3,-7),(6,-16),(9,-8),(7,-5)]],1,3,part,3,14)
            stripe(g,side*6,-14,side*6,-8,4,part,0,4)
            diamond(g,side*4,-3,1,4,4,"Reactor",4,3)
        polygon(g,[(-2,-7),(0,-18),(2,-7)],1,3,role=0,tile=14)
        polygon(g,[(-3,5),(0,12),(3,5),(2,-4),(-2,-4)],2,3,"Weapon",0,14)
        g.box(-1,1,8,13,3,3,"Weapon",1,13)
        diamond(g,0,0,2,4,5,"Reactor",4,3)
        engines(g,3,-9)
        engine=(3,-11)
    elif role == "tempest_core":
        polygon(g,[(-10,-13),(-17,-5),(-17,4),(-10,12),(0,16),(10,12),(17,4),(17,-5),(10,-13)],-3,0,role=2,tile=10)
        diamond(g,0,0,14,1,2,role=0,tile=14)
        diamond(g,0,0,10,3,3,role=2,tile=1)
        for side,part in [(-1,"Port"),(1,"Starboard")]:
            polygon(g,[(side*x,y) for x,y in [(9,10),(16,4),(16,-5),(10,-10),(8,-3)]],1,3,part,0,14)
            stripe(g,side*11,7,side*14,3,4,part,1,15)
            stripe(g,side*14,3,side*14,-4,4,part,1,15)
            g.box(side*10-1,side*10+1,-2,2,4,4,part,3,2)
        diamond(g,0,0,6,4,4,role=5,tile=15)
        diamond(g,0,0,4,5,6,"Reactor",4,3)
        diamond(g,0,0,2,7,7,"Reactor",1,3)
        for x,y in [(-6,6),(6,6),(0,-8)]:
            diamond(g,x,y,2,4,4,"Reactor",3,3)
            g.put(x,y,5,"Reactor",4,3)
        polygon(g,[(-3,8),(-2,13),(0,16),(2,13),(3,8)],2,4,"Weapon",1,14)
        g.box(-1,1,12,15,5,5,"Weapon",3,13)
        engines(g,6,-11)
        engine=(6,-13)
    else:
        polygon(g,[(-2,-10),(-4,-6),(-4,5),(0,12),(4,5),(4,-6),(2,-10)],-2,1,role=2,tile=10)
        for side,part in [(-1,"Port"),(1,"Starboard")]:
            polygon(g,[(side*x,y) for x,y in [(3,5),(8,1),(7,-5),(4,-7)]],0,2,part,0,14)
            stripe(g,side*5,2,side*6,-3,3,part,1,4)
        g.box(-2,2,-5,3,2,2,role=0,tile=14)
        diamond(g,0,0,2,3,4,"Reactor",4,3)
        g.box(-1,1,5,11,1,2,"Weapon",3,13)
        engines(g,2,-7)
        engine=(2,-9)
    return g, engine


def socket_definitions(role, grid, engine):
    step=grid.cell
    muzzle=max(p[1] for p,v in grid.cells.items() if v[0]=="Weapon")+.5
    sockets={"Socket_Muzzle":((0,muzzle*step,step*2),"Weapon"),
             "Socket_MuzzleCenter":((0,muzzle*step,step*2),"Weapon"),
             "Socket_Core":((0,0,step*5),"Body")}
    for side,label,part in [(-1,"Left","Port"),(1,"Right","Starboard")]:
        sockets["Socket_Engine"+label]=((side*engine[0]*step,(engine[1]-.5)*step,step*.5),"Body")
        sockets["Socket_Muzzle"+label]=((side*(8 if role=="assault" else 2)*step,(14.5 if role=="assault" else muzzle)*step,step*2),"Weapon")
        if role == "assault":
            sockets["Socket_WingHardpoint"+label]=((side*14*step,step,step*2),part)
        if role == "bulwark":
            sockets["Socket_ShieldEmitter"+label]=((side*14*step,0,step*5),part)
        if role == "tempest":
            for end,fore in [(1,"Front"),(-1,"Rear")]:
                sockets["Socket_Emitter"+fore+label]=((side*14*step,end*14*step,step*3),part)
        if role == "void_harbinger":
            sockets["Socket_Crown"+label]=((side*6*step,-14*step,step*3),part)
    if role == "tempest_core":
        for name,xy in [("Front",(0,16)),("Rear",(0,-13)),("Left",(-17,0)),("Right",(17,0))]:
            sockets["Socket_Section"+name]=((*[v*step for v in xy],step*3),"Body")
    if role == "section":
        sockets["Socket_Attach"]=((0,-10*step,0),"Body")
    return sockets


def rig_asset(scene, asset_id, role, objects, grid, engine):
    arm=bpy.data.armatures.new("VB_"+asset_id+"_Rig")
    rig=bpy.data.objects.new("VB_"+asset_id+"_MotionRig",arm)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    hinge=1.3 if role!="section" else .65
    for name,head in [("Body",(0,0,0)),("Port",(-hinge,0,0)),("Starboard",(hinge,0,0)),("Weapon",(0,1.2,0))]:
        bone=arm.edit_bones.new(name)
        bone.head=head
        bone.tail=Vector(head)+Vector((0,.35,0))
        if name!="Body":
            bone.parent=arm.edit_bones["Body"]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in objects:
        part=obj["rigid_part"]
        bone=part if part in motion.BONES else "Body"
        obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,"REPLACE")
        obj.parent=rig
        obj.modifiers.new("Rigid voxel articulation","ARMATURE").object=rig
    sockets=socket_definitions(role,grid,engine)
    for name,(position,bone) in sockets.items():
        obj=bpy.data.objects.new(name,None)
        scene.collection.objects.link(obj)
        obj.location=position
        bpy.context.view_layer.update()
        transform=obj.matrix_world.copy()
        obj.parent, obj.parent_type, obj.parent_bone=rig,"BONE",bone
        bpy.context.view_layer.update()
        obj.matrix_world=transform
    rig.animation_data_create()
    for clip,keys in poses.clips(role).items():
        action=bpy.data.actions.new("VB_"+asset_id+"__"+clip)
        rig.animation_data.action=action
        for seconds,value in keys:
            # The GLB exporter samples whole frames; an authored fractional
            # endpoint can drop the final settle pose during that sampling.
            motion.key_pose(rig,value,round(seconds*30))
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation="LINEAR"
        track=rig.animation_data.nla_tracks.new()
        track.name=clip
        track.strips.new(clip,0,action).name=clip
        rig.animation_data.action=None
    scene.frame_set(0)
    return rig, sockets


def export_asset(scene, asset_id, role, sockets):
    bpy.ops.object.select_all(action="SELECT")
    path=PACK/"meshes"/(asset_id+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,use_active_scene=True,
        export_yup=True,export_animations=True,export_animation_mode="NLA_TRACKS",export_force_sampling=True,
        export_frame_range=False,export_skins=True,export_def_bones=True,export_anim_single_armature=False,
        export_cameras=False,export_lights=False,export_extras=False,export_image_format="AUTO")
    data=path.read_bytes()
    length=struct.unpack_from("<I",data,12)[0]
    doc=json.loads(data[20:20+length])
    # glTF's constant tint is authored in the multiply material, but Blender's
    # exporter currently omits that node factor. Preserve it explicitly.
    for material in doc["materials"]:
        authored=bpy.data.materials[material["name"]]
        material.setdefault("pbrMetallicRoughness",{})["baseColorFactor"]=list(authored.diffuse_color)
    # Blender datablock names are global; exported asset names are local.
    for group in ("nodes","meshes","materials","skins","images"):
        for item in doc.get(group,[]):
            if "name" in item:
                item["name"]=re.sub(r"\.\d+$","",item["name"])
    encoded=json.dumps(doc,separators=(",",":")).encode()
    encoded+=b" "*((-len(encoded))%4)
    tail=data[20+length:]
    path.write_bytes(struct.pack("<4sII",b"glTF",2,20+len(encoded)+len(tail))+struct.pack("<I4s",len(encoded),b"JSON")+encoded+tail)
    return {"id":asset_id,"role":role,"file":"meshes/"+path.name,"bytes":path.stat().st_size,
            "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"meshes":len(doc["meshes"]),
            "bones":list(motion.BONES),"clips":list(poses.clips(role)),
            "sockets":{name:bone for name,(_,bone) in sockets.items()},"voxel_size":.28}


def studio(scenes):
    board=bpy.data.scenes.new(PREFIX+"Collection")
    bpy.context.window.scene=board
    board.frame_start,board.frame_end=0,126
    board.render.fps=30
    studio=bpy.data.collections.new("Presentation / typography and lighting")
    board.collection.children.link(studio)
    for index,scene in enumerate(scenes):
        collection=bpy.data.collections.new("Asset / "+IDS[index])
        board.collection.children.link(collection)
        clones={obj:obj.copy() for obj in scene.objects}
        offset=Vector(((index%3-1)*19,10 if index<3 else -10,0))
        for old,obj in clones.items():
            collection.objects.link(obj)
            if old.parent:
                obj.parent=clones[old.parent]
            else:
                obj.location+=offset
            for modifier in obj.modifiers:
                if modifier.type=="ARMATURE":
                    modifier.object=clones[old.parent]

    def material(name,color,emission=0):
        mat=bpy.data.materials.new("VB_Studio_"+name)
        mat.use_nodes=True
        bsdf=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
        for key in ("Base Color","Emission Color"):
            bsdf.inputs[key].default_value=(*fleet.linear(color),1)
        bsdf.inputs["Emission Strength"].default_value=emission
        bsdf.inputs["Roughness"].default_value=.9
        return mat
    ink=material("Ice","c6e5ef",.7)
    faint=material("Slate","7b9cad",.7)
    accent=material("Gold","efbd73",.7)
    def text(name,body,location,size,mat,align="LEFT"):
        data=bpy.data.curves.new(name,"FONT")
        data.body,data.size,data.align_x=body,size,align
        obj=bpy.data.objects.new(name,data)
        studio.objects.link(obj)
        obj.location=location
        data.materials.append(mat)
    text("Brand","F A R I N U F F   F L I G H T   /   A S S E T   L I B R A R Y   0 2",(-27,25,.02),.48,accent)
    text("Title","VOXEL BOSSES",(-27,22.3,.02),1.75,ink)
    text("Subtitle","FIVE CAPITAL HULLS   /   ANIMATED WEAPON PODS",(-27,20.6,.02),.46,faint)
    for index in range(6):
        x=(index%3-1)*19
        y=2.5 if index<3 else -17.5
        text("Title / "+IDS[index],TITLES[index],(x,y,.02),.62,ink,"CENTER")
        text("Role / "+IDS[index],SUBTITLES[index],(x,y-1,.02),.36,faint,"CENTER")
    text("Footer","RIGID VOXEL RIGS   /   FOUR MOTION CLIPS PER HULL   /   SHARED PIXEL ATLAS",(-27,-22,.02),.4,faint)
    text("Version","COLLECTION 1.0",(21,-22,.02),.4,accent)
    mesh=bpy.data.meshes.new("VB_Studio_Floor_mesh")
    mesh.from_pydata([(-120,-120,-3.2),(120,-120,-3.2),(120,120,-3.2),(-120,120,-3.2)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new("VB_Studio_Floor",mesh)
    studio.objects.link(floor)
    floor.data.materials.append(material("Midnight","142231"))
    world=bpy.data.worlds.new("VB_Studio_World")
    world.use_nodes=True
    background=next(n for n in world.node_tree.nodes if n.type=="BACKGROUND")
    background.inputs["Color"].default_value=(.18,.24,.32,1)
    background.inputs["Strength"].default_value=.55
    board.world=world
    for name,pos,power,size in [("Key",(-18,-8,32),5400,24),("Fill",(22,10,23),3900,20)]:
        data=bpy.data.lights.new("VB_Studio_"+name,"AREA")
        data.energy,data.size=power,size
        obj=bpy.data.objects.new(data.name,data)
        studio.objects.link(obj)
        obj.location=pos
        obj.rotation_euler=(-obj.location).to_track_quat("-Z","Y").to_euler()
    data=bpy.data.cameras.new("VB_Studio_Camera")
    data.type,data.ortho_scale="ORTHO",65
    camera=bpy.data.objects.new(data.name,data)
    studio.objects.link(camera)
    camera.location=(0,-35,88)
    camera.rotation_euler=(Vector((0,1,0))-camera.location).to_track_quat("-Z","Y").to_euler()
    board.camera=camera
    board.render.resolution_x,board.render.resolution_y=2100,1750
    board.render.resolution_percentage=100
    board.render.image_settings.file_format="PNG"
    board.view_settings.exposure=.8
    board.render.filepath=str(PREVIEW)
    board["readme"]="Six editable original assets. Isolated asset scenes are origin-aligned export sources. Select NLA clips for animation review. Packed atlas with portable external reference."
    return board


def build_all():
    if bpy.context.object and bpy.context.object.mode!="OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for folder in ("meshes","textures","source","docs"):
        (PACK/folder).mkdir(parents=True,exist_ok=True)
    (PACK/"source/.gdignore").write_text("")
    (PACK/"docs/.gdignore").write_text("")
    PREVIEW.parent.mkdir(parents=True,exist_ok=True)
    (PREVIEW.parents[1]/".gdignore").write_text("")
    atlas_path=PACK/"textures/voxel_surface_atlas.png"
    if not atlas_path.exists():
        shutil.copyfile(ROOT/"assets/models/voxel_frontier/textures/voxel_surface_atlas.png",atlas_path)
    atlas=bpy.data.images.load(str(atlas_path),check_existing=False)
    atlas.pack()
    fleet.PALETTES.update(PALETTES)
    mats={role:fleet.make_materials(role,atlas) for role in ROLES}
    for role,values in mats.items():
        for mat in values:
            mat.name=mat.name.replace("VF_","VB_",1)
    scenes,records=[],[]
    for asset_id,role in zip(IDS,ROLES):
        scene=bpy.data.scenes.new(PREFIX+asset_id)
        bpy.context.window.scene=scene
        scene.render.fps=30
        scene.frame_start=0
        scene.frame_end=max(round(keys[-1][0]*30) for keys in poses.clips(role).values())
        grid,engine=geometry(role)
        objects=grid.mesh_objects(scene,asset_id,mats[role])
        for obj in objects:
            obj.name=obj.name.replace("VF_","VB_",1)
        rig,sockets=rig_asset(scene,asset_id,role,objects,grid,engine)
        records.append(export_asset(scene,asset_id,role,sockets))
        for track in rig.animation_data.nla_tracks:
            track.mute=track.name!="cruise"
        scene.frame_set(0)
        scene["asset_id"],scene["role"]=asset_id,role
        scenes.append(scene)
    board=studio(scenes)
    scenes.append(board)
    bpy.data.libraries.write(str(SOURCE),set(scenes),fake_user=True,compress=True)
    (PACK/"build_manifest.json").write_text(json.dumps({"version":"1.0.0","blender_version":bpy.app.version_string,"assets":records},indent=2)+"\n")
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type in {"VIEW_3D","CONSOLE"}:
            area.type="VIEW_3D"
            area.spaces.active.shading.type="MATERIAL"
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_distance=68
            area.spaces.active.region_3d.view_location=Vector((0,1,0))
            area.spaces.active.region_3d.view_rotation=Quaternion((1,0,0),math.radians(25))
            area.spaces.active.region_3d.view_perspective="ORTHO"
            break
    print("VOXEL_BOSSES_EXPORTED",json.dumps(records))
    return records


def finalize_source():
    if Path(bpy.data.filepath).resolve()!=SOURCE.resolve():
        raise RuntimeError("Open the generated voxel_bosses.blend before finalizing")
    if any(not scene.name.startswith(PREFIX) for scene in bpy.data.scenes):
        raise RuntimeError("Unexpected scene in generated source")
    for scene in bpy.data.scenes:
        scene.name=re.sub(r"\.\d+$","",scene.name)
    board=bpy.data.scenes[PREFIX+"Collection"]
    bpy.context.window.scene=board
    board.render.filepath="//../../../../design/voxel-bosses/blender/collection.png"
    for atlas in bpy.data.images:
        if atlas.packed_file:
            atlas.filepath="//../textures/voxel_surface_atlas.png"
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                area.spaces.active.region_3d.view_perspective="CAMERA"
                area.spaces.active.shading.type="MATERIAL"
                area.spaces.active.overlay.show_overlays=False
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),compress=True,relative_remap=False)
    print("VOXEL_BOSSES_SOURCE_READY",str(SOURCE))


if __name__=="__main__":
    finalize_source() if "--finalize-source" in sys.argv else build_all()
