"""Original Wayfarer Harbor voxel art; run inside Blender 5.x.

Creates a separate scene and never removes the user's existing scene.
Geometry uses exposed voxel faces, a hand-authored pixel atlas, and rigid loops.
"""
import bpy
import math
import json
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/models/home_base'
CELL = 0.5
SCENE = 'Wayfarer Harbor | Asset Workshop'
PALETTE = [
    (0.055, .085, .14), (.13, .21, .30), (.29, .39, .47),
    (.70, .76, .73), (.91, .89, .77), (.78, .36, .16),
    (.10, .34, .43), (.12, .73, .83), (.94, .63, .25),
    (.09, .17, .32), (.19, .37, .58), (.11, .20, .21),
    (.29, .58, .40), (.94, .94, .82), (.36, .18, .15),
    (.42, .49, .55),
]
NAMES = ['Void', 'Structure', 'Steel', 'Armor', 'Ivory', 'Copper',
         'Glass', 'Cyan', 'Windows', 'Solar', 'SolarCell', 'Garden',
         'Leaf', 'Light', 'Heat', 'Panel']


def enum_set(obj, prop, wanted):
    values = [x.identifier for x in obj.bl_rna.properties[prop].enum_items]
    if wanted not in values:
        raise ValueError(f'{prop}: {wanted} unavailable; {values}')
    setattr(obj, prop, wanted)


def make_atlas():
    size, tile = 256, 32
    albedo, emission = [], []
    for y in range(size):
        for x in range(size):
            role = ((y // tile) * 8 + x // tile) % 16
            u, v = x % tile, y % tile
            base = PALETTE[role]
            variation = 1.0 + (((u * 13 + v * 7 + role * 19) % 17) - 8) * .003
            # Recessed seams and sparse fasteners, at a deliberate pixel scale.
            if u in [0, 1, 30, 31] or v in [0, 1, 30, 31]:
                variation *= .66
            if (u in [4, 5, 26, 27]) and (v in [4, 5, 26, 27]):
                variation *= 1.15
            glow = 0.0
            if role == 9:
                variation *= .6 if u % 8 == 0 or v % 8 == 0 else 1.0
            if role == 10:
                variation *= .55 if u % 8 in [0, 1] or v % 8 in [0, 1] else 1.0
            if role == 5 and 9 <= u <= 22 and 9 <= v <= 22:
                variation *= .88
            if role == 6:
                variation *= 1.2 if abs(u-v) <= 2 else .8
            if role in [7, 8, 13]:
                glow = .95 if 3 < u < 28 and 3 < v < 28 else .04
                if role == 8 and (u in [10, 11, 20, 21] or v in [15, 16]):
                    glow = .04
                    variation *= .4
            if role == 14 and v % 7 < 2:
                base = PALETTE[8]
                glow = .2
            color = tuple(min(1.0, c * variation) for c in base)
            albedo.extend((*color, 1.0))
            emission.extend((base[0]*glow, base[1]*glow, base[2]*glow, 1.0))
    images = []
    for name, data in [('homeport_atlas', albedo), ('homeport_emission', emission)]:
        img = bpy.data.images.new(name, width=size, height=size, alpha=True)
        enum_set(img.colorspace_settings, 'name', 'sRGB')
        img.pixels.foreach_set(data)
        img.filepath_raw = str(ASSETS / 'textures' / (name + '.png'))
        enum_set(img, 'file_format', 'PNG')
        img.save()
        img.pack()
        images.append(img)
    material = bpy.data.materials.new('Homeport | painted alloy + luminous inlays')
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Metallic'].default_value = .32
    bsdf.inputs['Roughness'].default_value = .72
    bsdf.inputs['Emission Strength'].default_value = 2.2
    for img, socket in zip(images, ['Base Color', 'Emission Color']):
        tex = material.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = img
        enum_set(tex, 'interpolation', 'Closest')
        material.node_tree.links.new(tex.outputs['Color'], bsdf.inputs[socket])
    return material


class Voxels:
    def __init__(self, cell=CELL):
        self.cell, self.cells = cell, {}

    def box(self, center, size, role):
        starts = [round((center[a] - size[a]/2)/self.cell) for a in range(3)]
        ends = [max(starts[a] + 1, round((center[a] + size[a]/2)/self.cell)) for a in range(3)]
        ranges = [range(starts[a], ends[a]) for a in range(3)]
        for x in ranges[0]:
            for y in ranges[1]:
                for z in ranges[2]:
                    self.cells[x, y, z] = role
        return self

    def ring(self, outer, inner, bottom, top, role, octagonal=False):
        extent = math.ceil(outer/self.cell)
        for x in range(-extent, extent):
            for y in range(-extent, extent):
                px, py = (x+.5)*self.cell, (y+.5)*self.cell
                r = math.hypot(px, py)
                outside = max(abs(px), abs(py)) > outer or abs(px)+abs(py) > outer*1.43 if octagonal else r > outer
                inside = max(abs(px), abs(py)) < inner and abs(px)+abs(py) < inner*1.43 if octagonal else r < inner
                if outside or (inner > 0 and inside):
                    continue
                for z in range(round(bottom/self.cell), round(top/self.cell)):
                    self.cells[x, y, z] = role
        return self

    def radial_box(self, angle, radius, size, bottom, role):
        # Aligned blocks keep the construction visibly voxel-made.
        return self.box((round(math.cos(angle)*radius*2)/2,
                         round(math.sin(angle)*radius*2)/2,
                         bottom+size[2]/2), size, role)

    def mesh(self, name, material, parent=None):
        verts, faces, roles = [], [], []
        sides = [((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),
                 ((-1,0,0),[(0,1,0),(0,0,0),(0,0,1),(0,1,1)]),
                 ((0,1,0),[(1,1,0),(0,1,0),(0,1,1),(1,1,1)]),
                 ((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),
                 ((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]),
                 ((0,0,-1),[(0,1,0),(1,1,0),(1,0,0),(0,0,0)])]
        for cell, role in self.cells.items():
            for normal, corners in sides:
                if tuple(cell[a]+normal[a] for a in range(3)) in self.cells:
                    continue
                i = len(verts)
                verts.extend(tuple((cell[a]+corner[a])*self.cell for a in range(3)) for corner in corners)
                faces.append((i,i+1,i+2,i+3))
                roles.append(role)
        mesh = bpy.data.meshes.new(name + 'Geometry')
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        uv = mesh.uv_layers.new(name='HomeportAtlas')
        for polygon, role in zip(mesh.polygons, roles):
            tx, ty = role % 8, role // 8
            for loop, corner in zip(polygon.loop_indices, [(0,0),(1,0),(1,1),(0,1)]):
                uv.data[loop].uv = ((tx*32+1+corner[0]*30)/256,
                                    (ty*32+1+corner[1]*30)/256)
            polygon.use_smooth = False
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        return obj


def empty(name, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def loop(obj, axis=2, duration=480, degrees=360, action_name='station_idle'):
    for f in [1, duration//4+1, duration//2+1, duration*3//4+1, duration+1]:
        obj.rotation_euler[axis] = math.radians(degrees) * (f-1)/duration
        obj.keyframe_insert(data_path='rotation_euler', frame=f)
    action = obj.animation_data.action
    action.name = action_name + '_' + obj.name
    # Blender 5 actions use layered/channel-bag storage.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:
                        enum_set(k, 'interpolation', 'LINEAR')
    track = obj.animation_data.nla_tracks.new()
    track.name = action_name
    track.strips.new(action_name, 1, action)
    obj.animation_data.action = None
    return action


def build_station(mat):
    root = empty('WayfarerStation')
    v = Voxels()
    # Terraced service core, with a real underside and readable glazed crown.
    v.ring(6.5,0,-3,0,1,True).ring(8,0,0,2,2,True)
    v.ring(9,0,2,3.5,3,True).ring(7.5,0,3.5,4.5,4,True)
    v.ring(6.5,0,4.5,8,1,True).ring(6.5,0,6,7,8,True)
    v.ring(6.5,5.5,7,8,3,True).ring(5.5,0,8,9,4,True)
    v.ring(5,0,9,11.5,6,True).ring(5.5,0,11.5,12.5,4,True)
    v.ring(4,0,12.5,13.5,3,True).ring(2.5,0,13.5,14.5,5,True)
    for i in range(8):
        a = i*math.tau/8
        v.radial_box(a,6.5,(1,1,4),4.5,4)
        v.radial_box(a,8.5,(1,1,.5),3.5,7)
        v.radial_box(a,5,(.5,.5,3),9,4)
    # Elevated radial bridges and octagonal housing ring: open flight beneath.
    v.ring(23.5,19.5,4,5,1,True).ring(24,19,5,6,3,True)
    v.ring(23.5,20,6,6.5,4,True)
    v.ring(20,19.5,6.5,7,7,True)
    for a in range(4):
        if a % 2 == 0:
            v.box((15 if a == 0 else -15,0,4),(15,3,2),1)
            v.box((15 if a == 0 else -15,0,5.25),(15,2,.5),4)
            v.box((15 if a == 0 else -15,.75,5.75),(14,.5,.5),7)
        else:
            v.box((0,15 if a == 1 else -15,4),(3,15,2),1)
            v.box((0,15 if a == 1 else -15,5.25),(2,15,.5),4)
            v.box((.75,15 if a == 1 else -15,5.75),(.5,14,.5),7)
    # Eight neighborhoods: ivory roofs, copper radiators, lit windows.
    for i in range(8):
        a = i*math.tau/8 + math.pi/8
        x,y = round(math.cos(a)*21*2)/2,round(math.sin(a)*21*2)/2
        v.box((x,y,7.5),(4.5,4.5,3),1)
        v.box((x,y,8),(5,5,1),8)
        v.box((x,y,9),(4.5,4.5,1),4)
        v.box((x,y,9.75),(3.5,3.5,.5),3)
        v.box((x-1.75,y,8),(1,5,3),3)
        v.box((x+1.75,y,8),(1,5,3),3)
        v.box((x,y,10.25),(2,2,.5),5 if i%3 == 0 else 6)
        for j in [-1,1]:
            v.box((x+j,y,10.75),(.5,2.5,.5),2)
    # East/west solar farms: repeated crisp photovoltaic tiles on a brass frame.
    for side in [-1,1]:
        v.box((side*28,0,4.5),(9,2,2),2)
        for row in [-1,1]:
            cy=row*10
            v.box((side*30,cy,5.25),(11,13,.5),5)
            v.box((side*30,cy,5.75),(10,12,.5),9)
            for sx in range(5):
                for sy in range(6):
                    v.box((side*30-4+sx*2,cy-5+sy*2,6.25),(1.5,1.5,.5),10)
            v.box((side*30,cy,6.75),(.5,13,.5),3)
            v.box((side*30,cy,4.5),(1,15,1),1)
        v.box((side*35,0,6),(1,2,2),7)
    # North freight annex and southern arrival berth (Blender -Y -> Godot +Z).
    v.box((0,29,4.5),(3,12,2),1).box((0,30,6),(8,9,1),3)
    for x in [-2.5,2.5]:
        v.box((x,31,7.5),(3,5,2),5)
        for y in [29.5,31,32.5]:
            v.box((x,y,8.75),(3.5,.5,.5),4)
    v.box((0,-29.5,3.75),(5,15,1.5),1)
    v.box((0,-31,4.75),(12,12,.5),3)
    v.box((0,-31,5.25),(10,11,.5),0)
    v.box((0,-30,5.75),(4,5,.5),2)
    # Large recognizable H, directional lane, and spaced warning blocks.
    for x in [-1.25,1.25]:
        v.box((x,-31,6),(.5,3,.5),13)
    v.box((0,-31,6),(2.5,.5,.5),13)
    for x in [-5.5,5.5]:
        v.box((x,-30.5,6),(1,11,1),4)
        for y in [-35,-33,-31,-29,-27]:
            v.box((x,y,6.75),(.5,1,.5),7)
    for y in [-36,-34,-28,-26]:
        for x in [-3.5,3.5]:
            v.box((x,y,5.75),(1,.5,.5),8)
    # Communications mast: ivory step silhouettes with warm status bulbs.
    v.box((-4,3,14),(.5,.5,6),2).box((-4,3,17.25),(1,1,.5),8)
    v.box((3,3,14.25),(.5,.5,4.5),2).box((3,3,16.75),(1,1,.5),7)
    v.mesh('StationHull',mat,root)
    rotor=Voxels().ring(8,7,8,8.5,2,True)
    for i in range(8):
        rotor.radial_box(i*math.tau/8,7.5,(1,1,1),8.5,7)
        rotor.radial_box(i*math.tau/8+.12,7.5,(1,1,.5),9.5,5)
    rotor_obj=rotor.mesh('ReactorRotor',mat,root)
    loop(rotor_obj,duration=480)
    dish=Voxels()
    dish.box((0,0,0),(.5,.5,2),1)
    for x in range(-4,5):
        for y in range(-3,4):
            if x*x+y*y<23:
                z=.5+(abs(x)+abs(y))*.25
                dish.box((x*.5,y*.5,z),(.5,.5,.5),4 if (x+y)%3 else 3)
    dish.box((0,0,2),(.5,.5,2),7)
    dish_obj=dish.mesh('RadarDish',mat,root)
    dish_obj.location=(0,0,15)
    loop(dish_obj,duration=480,degrees=-360)
    return root


def build_drone(mat):
    root=empty('ServiceDrone')
    v=Voxels(.25)
    v.box((0,0,0),(1.5,1.5,.75),1).box((0,0,.5),(1,1,.5),4)
    v.box((0,-.75,.125),(1,.25,.25),7)
    for x in [-1,1]:
        v.box((x,0,-.125),(.5,1,.5),5)
        v.box((x,.5,-.125),(.5,.25,.5),7)
        v.box((x,-.75,-.5),(.25,1,.25),2)
    v.mesh('DroneHull',mat,root)
    scan=Voxels(.25).box((0,0,0),(1.5,.25,.25),3).box((.75,0,.25),(.25,.25,.25),7).mesh('DroneScanner',mat,root)
    scan.location.z=.875
    loop(scan,duration=120,action_name='service_idle')
    return root


def build_tug(mat):
    root=empty('CargoTug')
    v=Voxels(.25)
    v.box((0,0,0),(2.5,4,.75),1).box((0,-1.25,.5),(2,1.5,1),4)
    v.box((0,-1.75,.75),(1.5,.5,.5),6)
    v.box((0,.75,.75),(1.75,2.25,1.5),5)
    for y in [0,.75,1.5]:
        v.box((0,y,1.625),(2,.25,.25),3)
    for x in [-1.5,1.5]:
        v.box((x,.75,0),(.5,2,.75),2)
        v.box((x,1.875,0),(.5,.25,.5),7)
        v.box((x,-1.375,.25),(.5,.25,.25),13)
    v.mesh('TugHull',mat,root)
    beacon=Voxels(.25).box((0,0,0),(.75,.25,.25),8).mesh('TugBeacon',mat,root)
    beacon.location=(0,-1,1.125)
    loop(beacon,duration=120,action_name='service_idle')
    return root


def build_buoy(mat):
    root=empty('NavigationBuoy')
    v=Voxels(.25)
    v.box((0,0,-.25),(.75,.75,2),1)
    v.box((0,0,-1),(1.5,1.5,.5),5)
    v.box((0,0,0),(1.25,1.25,.75),3)
    v.box((0,0,.625),(.75,.75,.5),7)
    v.box((0,0,1),(.25,.25,.5),13)
    for x in [-1,1]:
        v.box((x,0,-.25),(.75,1.5,.25),9)
        v.box((x,0,0),(.5,1.25,.25),10)
    v.mesh('BuoyMast',mat,root)
    rotor=Voxels(.25).box((0,0,0),(1.5,.25,.25),5)
    for x in [-.75,.75]:
        rotor.box((x,0,0),(.25,.5,.5),8)
    obj=rotor.mesh('BuoyBeacon',mat,root)
    obj.location.z=1.25
    loop(obj,duration=120,action_name='service_idle')
    return root


def build():
    if bpy.data.scenes.get(SCENE):
        raise RuntimeError('Workshop already exists; do not overwrite it blindly.')
    scene=bpy.data.scenes.new(SCENE)
    bpy.context.window.scene=scene
    scene.render.fps=24
    scene.frame_start=1
    scene.frame_end=481
    mat=make_atlas()
    roots=[build_station(mat),build_drone(mat),build_tug(mat),build_buoy(mat)]
    for root,offset in zip(roots[1:],[(43,0,2),(43,7,2),(43,-7,2)]):
        root.location=offset
    scene.frame_set(1)
    print(json.dumps({'scene':scene.name,'objects':len(scene.objects),'roots':[r.name for r in roots],
                      'triangles':sum(len(o.data.polygons)*2 for o in scene.objects if o.type=='MESH')}))
    return roots


def setup_preview():
    scene=bpy.context.scene
    try:
        scene.render.engine='CYCLES'
    except TypeError as error:
        raise RuntimeError(str(error))
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1600
    scene.render.resolution_y=1200
    scene.render.resolution_percentage=100
    enum_set(scene.render.image_settings,'file_format','PNG')
    world=bpy.data.worlds.new('Homeport Navy Environment')
    world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.10,.14,.23,1)
    bg.inputs['Strength'].default_value=.4
    scene.world=world
    for name,loc,power,color,size in [
        ('Harbor Softbox',(-26,-32,55),18000,(.78,.89,1),35),
        ('Amber Rim',(32,15,28),12000,(1,.56,.26),28),
        ('Cyan Bounce',(-25,27,16),9000,(.23,.62,1),25)]:
        valid=[i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items]
        assert 'AREA' in valid
        light=bpy.data.lights.new(name,'AREA')
        light.energy=power
        light.color=color
        light.shape='DISK' if 'DISK' in [i.identifier for i in light.bl_rna.properties['shape'].enum_items] else light.shape
        light.size=size
        obj=bpy.data.objects.new(name,light)
        scene.collection.objects.link(obj)
        obj.location=loc
        obj.rotation_euler=(Vector((0,0,3))-obj.location).to_track_quat('-Z','Y').to_euler()
    camera=bpy.data.cameras.new('Harbor Portrait')
    enum_set(camera,'type','ORTHO')
    camera.ortho_scale=93
    camera.lens=50
    obj=bpy.data.objects.new('Harbor Portrait',camera)
    scene.collection.objects.link(obj)
    obj.location=(66,-88,87)
    obj.rotation_euler=(Vector((0,0,4))-obj.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=obj
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_distance=95
                area.spaces.active.region_3d.view_location=(0,0,4)
                area.spaces.active.region_3d.view_rotation=obj.rotation_euler.to_quaternion()
                enum_set(area.spaces.active.shading,'type','MATERIAL')
    scene.render.filepath=str(ROOT/'design/home-base/wayfarer-station.png')


def export_assets():
    scene=bpy.context.scene
    names={'WayfarerStation':'wayfarer_station','ServiceDrone':'service_drone',
           'CargoTug':'cargo_tug','NavigationBuoy':'navigation_buoy'}
    props=bpy.ops.export_scene.gltf.get_rna_type().properties
    valid_modes=[v.identifier for v in props['export_animation_mode'].enum_items]
    assert 'NLA_TRACKS' in valid_modes
    manifest=[]
    for root_name,filename in names.items():
        root=bpy.data.objects[root_name]
        location=root.location.copy()
        root.location=(0,0,0)
        for obj in scene.objects:
            obj.select_set(False)
        objects=[root,*root.children_recursive]
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        scene.frame_end=481 if filename=='wayfarer_station' else 121
        scene.frame_set(1)
        output=ASSETS/'meshes'/f'{filename}.glb'
        # GLB is the export operator's default format; its dynamic enum is empty in RNA.
        bpy.ops.export_scene.gltf(filepath=str(output),use_selection=True,use_active_scene=True,
            export_animations=True,export_animation_mode='NLA_TRACKS',
            export_frame_range=True,export_force_sampling=True,
            export_yup=True,export_materials='EXPORT')
        root.location=location
        manifest.append({'asset':filename,'bytes':output.stat().st_size,
                         'objects':[o.name for o in objects],
                         'triangles':sum(len(o.data.polygons)*2 for o in objects if o.type=='MESH')})
    scene.frame_end=481
    scene.frame_set(1)
    (ASSETS/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(ASSETS/'source/home_base.blend'))
    print(json.dumps(manifest))
