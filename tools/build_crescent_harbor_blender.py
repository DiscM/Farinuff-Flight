"""Build the selected Crescent Harbor mockup as editable original Blender geometry.

Run: Blender --background --factory-startup --python tools/build_crescent_harbor_blender.py -- --preview
The original home_base source and runtime models are never overwritten.
"""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from crescent_harbor.geometry import MeshBuilder, initialize_materials, root_empty, rotation_loop, enum_set
from crescent_harbor.relays import build_relay
from crescent_harbor.fleet import build_ship, build_greenhouse
from crescent_harbor.detailing import add_station_detail
from crescent_harbor.animation import station_keeping, service_animation, flexible_bundle, berth_connections
from crescent_harbor.traffic import through_traffic
from build_home_base_blender import Voxels

ASSET = ROOT / 'assets/models/wayfarer_crescent'
PREVIEW = ROOT / 'design/home-base/blender-crescent'
REFERENCE = 'design/home-base/detail-mockups/asymmetric-layouts/01-crescent-harbor-v2-spacecraft.png'
SCENE_NAME = 'Wayfarer / Crescent Harbor / Detailed Spaceport'
ROLES = ['black','navy','steel','armor','ivory','copper','darkglass','cyan',
         'amber','navy','steel','green','green','white','orange','armor']


def planar(u, v, z=0):
    """Ground-plane basis aligned to the presentation camera, Blender Z up."""
    return Vector((u*.8-v*.6, u*.6+v*.8, z))


def build_main():
    root = root_empty('Wayfarer_Core', planar(-24,-20))
    root.scale = (1.3,)*3
    root['role'] = 'Habitation, port control, passenger arrivals and flight school'
    v = Voxels(.5)
    # Voxel-made core retains the source model's stepped/octagonal architecture.
    v.ring(6.5,0,-3,0,1,True).ring(8,0,0,2,2,True)
    v.ring(9,0,2,3.5,3,True).ring(7.5,0,3.5,4.5,4,True)
    v.ring(6.5,0,4.5,8,1,True).ring(6.5,0,6,7,8,True)
    v.ring(6.5,5.5,7,8,3,True).ring(5.5,0,8,9,4,True)
    v.ring(5,0,9,11.5,6,True).ring(5.5,0,11.5,12.5,4,True)
    v.ring(4,0,12.5,13.5,3,True).ring(2.5,0,13.5,14.5,5,True)
    v.ring(23.5,19.5,4,5,1,True).ring(24,19,5,6,3,True)
    v.ring(23.5,20,6,6.5,4,True).ring(20,19.5,6.5,7,7,True)
    for i in range(8):
        a = i*math.tau/8
        v.radial_box(a,6.5,(1,1,4),4.5,4)
        v.radial_box(a,8.5,(1,1,.5),3.5,7)
        v.radial_box(a,5,(.5,.5,3),9,4)
        v.radial_box(a,9,(.5,.5,1),2,5)
    for axis in range(4):
        if axis % 2 == 0:
            x = 15 if axis == 0 else -15
            v.box((x,0,4),(15,3,2),1).box((x,0,5.25),(15,2,.5),4)
            v.box((x,.75,5.75),(14,.5,.5),7)
        else:
            y = 15 if axis == 1 else -15
            v.box((0,y,4),(3,15,2),1).box((0,y,5.25),(2,15,.5),4)
            v.box((.75,y,5.75),(.5,14,.5),7)
    for i in range(8):
        a = i*math.tau/8 + math.pi/8
        x, y = round(math.cos(a)*21*2)/2, round(math.sin(a)*21*2)/2
        v.box((x,y,7.5),(4.5,4.5,3),1)
        v.box((x,y,8),(5,5,1),8).box((x,y,9),(4.5,4.5,1),4)
        v.box((x,y,9.75),(3.5,3.5,.5),3)
        for offset in (-1.75,1.75):
            v.box((x+offset,y,8),(1,5,3),3)
        # Multiple chunky mullions, rooftop cabinets and layered radiators.
        for offset in (-.75,.75):
            v.box((x+offset,y,8),(.5,5.25,1.5),2)
        # A continuous plenum prevents half-cell rounding from leaving
        # separate radiator fins touching the roof only at an edge.
        v.box((x,y,10.25),(3,3,.5),3)
        v.box((x,y,10.25),(2,2,.5),5 if i%3 == 0 else 6)
        for offset in (-1,1):
            v.box((x+offset,y,10.75),(.5,3,.5),2)
        for offset in (-1,0,1):
            v.box((x,y+offset,11.0),(3,.5,.5),3)
        # Habitation pods tucked below perimeter.
        v.box((x,y,2.8),(3.5,3.5,2),1)
        v.box((x,y,3),(4,4,.5),8)
        v.box((x,y,1.5),(4,4,.5),4)
        for offset in (-1,1):
            v.box((x+offset,y,2.5),(.5,4.25,2),3)
    # Reinforced front apron; zero-G clamp fixture is added below, no H marking.
    v.box((0,-29.5,3.75),(5,15,1.5),1)
    v.box((0,-31,4.75),(12,12,.5),3).box((0,-31,5.25),(10,11,.5),0)
    for x in (-5.5,5.5):
        # Solid feet bridge the half-unit gap between apron plate and curbs.
        v.box((x,-30.5,5.25),(1,11,.5),3)
        v.box((x,-30.5,6),(1,11,1),4)
        for y in (-35,-33,-31,-29,-27):
            v.box((x,y,6.75),(.5,1,.5),7)
    for y in (-36,-34,-28,-26):
        for x in (-3.5,3.5):
            v.box((x,y,5.75),(1,.5,.5),8)
    v.box((0,26,4.5),(5,8,2),1).box((0,28,6),(10,8,1),3)
    v.box((-4,3,14),(.5,.5,6),2).box((-4,3,17.25),(1,1,.5),8)
    v.box((3,3,14.25),(.5,.5,4.5),2).box((3,3,16.75),(1,1,.5),7)
    MeshBuilder('Core voxel hull').voxels(v.cells,v.cell,ROLES).finish(parent=root)
    g = MeshBuilder('Core / installed service detail')
    g.ring((0,-31,5.57),2.2,2.05,.12,'cyan',vertices=16)
    for i in range(8):
        a=i*math.tau/8
        g.box((math.cos(a)*2.4,-31+math.sin(a)*2.4,5.64),(.48,.32,.18),'ivory',rotation=a)
    # Seat plating on the real voxel deck; square-grid rows used to continue
    # into empty space beyond the octagon's chamfered corners.
    def supported_panel(x, y, width, depth, angle=0):
        co, si = math.cos(angle), math.sin(angle)
        for dx, dy in ((-width/2,-depth/2),(-width/2,depth/2),
                       (width/2,-depth/2),(width/2,depth/2),(0,0)):
            px, py = x+co*dx-si*dy, y+si*dx+co*dy
            if (math.floor(px/v.cell), math.floor(py/v.cell), 12) not in v.cells:
                return False
        return True

    def promenade_panel(x, y, angle=0):
        if not supported_panel(x, y, 1.65, 1.5, angle):
            return
        g.box((x,y,6.515),(1.65,1.5,.06),'armor',rotation=angle)
        g.box((x,y,3.72),(.28,3.35,.94),'steel',rotation=angle)

    for along in range(-16,17,2):
        for side in (-1,1):
            promenade_panel(along,side*22)
            promenade_panel(side*22,along,math.pi/2)
    # Continue the panel rhythm around all four diagonal facets instead of
    # leaving unsupported plates where the old square-grid corners were.
    for quadrant in range(4):
        angle=quadrant*math.pi/2
        co,si=math.cos(angle),math.sin(angle)
        for along in (-7,-5,-3,-1,1,3,5,7):
            x,y=15.6+along/math.sqrt(2),15.6-along/math.sqrt(2)
            promenade_panel(co*x-si*y,si*x+co*y,angle-math.pi/4)
    for side in (-1,1):
        # The utility pipe follows the chamfer rather than floating beyond it.
        points=[(side*15.4,-17.4,3.92),(side*22.8,-10,3.92),
                (side*22.8,10,3.92),(side*15.4,17.4,3.92)]
        g.tube(points,.17,'copper')
        for a,b in zip(points,points[1:]):
            for step in range(5):
                t=step/4
                x,y=a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t
                g.box((x,y,4.03),(.48,.40,.56),'ivory')
    for x in (-3,0,3):
        g.box((x,28,7),(2.4,4,1.4),'orange')
        for y in (26.5,28,29.5):
            g.box((x,y,7.76),(2.6,.18,.16),'ivory')
    # Perimeter vacuum docking armatures: airlocks, clamps and service umbilicals.
    for x,y,angle in [(23,0,0),(10,-22,-math.pi/2),(-21,-8,math.pi)]:
        out=Vector((math.cos(angle),math.sin(angle),0))
        p=Vector((x,y,5.3))
        transverse=Vector((-out.y,out.x,0))
        # Both clamp rails bolt to a common saddle; the outer rail at a
        # chamfer previously began beyond the hull and had no attachment.
        g.beam(p-out*.2-transverse*1.9,p-out*.2+transverse*1.9,.50,'steel',depth=.60)
        g.beam(p,p+out*4,.8,'navy',depth=1.1)
        g.tube([p+out*2,p+out*3.2,p+out*4.5],.5,'steel',segments=12)
        for side in (-1,1):
            perp=Vector((-out.y,out.x,0))*side
            g.beam(p+perp*1.6,p+out*5+perp*1.6,.28,'ivory')
            g.beam(p+out*5+perp*1.6,p+out*5+perp*.7,.24,'copper')
    # Follow the actual stepped voxel surface instead of a smooth radius;
    # the old constant-radius strips floated in front of cardinal glass faces.
    def surface_radius(angle,z):
        radius=0.0
        for step in range(1,181):
            r=step*.05
            cell=(math.floor(math.cos(angle)*r/v.cell),
                  math.floor(math.sin(angle)*r/v.cell),math.floor(z/v.cell))
            if cell in v.cells:
                radius=r
        return max(0.0,radius-.035)

    for i in range(16):
        a=i*math.tau/16
        radius=surface_radius(a,5.9)
        g.box((math.cos(a)*radius,math.sin(a)*radius,5.9),(.22,.22,1.9),'steel')
        radius=surface_radius(a,10.3)
        g.box((math.cos(a)*radius,math.sin(a)*radius,10.3),(.15,.15,1.7),'ivory')
    # Greenhouses sit on dedicated curbs with short knees into the ring deck.
    # Their decks intentionally overhang the octagonal rim, but are supported.
    for x,y,width,depth in [(-22,0,4.10,8.5),(7,-21.5,8.5,4.10)]:
        g.box((x,y,6.48),(width,depth,.12),'steel')
        if x < -20:
            for offset in (-3.0,0,3.0):
                g.beam((-22.5,y+offset,5.95),(-23.9,y+offset,6.44),.22,'ivory')
        else:
            for offset in (-3.0,0,3.0):
                g.beam((x+offset,-22.4,5.95),(x+offset,-23.45,6.44),.22,'ivory')
    g.finish(parent=root)
    for index,position in enumerate([(-22,0,6.49),(7,-21.5,6.49)]):
        greenhouse=build_greenhouse('Core_Greenhouse_'+str(index+1),length=8,width=3.6)
        greenhouse.parent=root
        greenhouse.location=position
        greenhouse.rotation_euler.z=math.pi/2 if index==0 else 0
    radar=root_empty('Core / rotating communications crown')
    radar.parent=root
    radar.location=(0,0,14.48)
    dish=MeshBuilder('Core / tracking radar')
    dish.cylinder((0,0,.7),.45,1.4,'steel')
    for i in range(-3,4):
        dish.box((i*.38,0,1.5+abs(i)*.12),(.36,1.4,.25),'ivory')
    dish.beam((0,0,1.5),(0,0,2.5),.12,'steel')
    dish.box((0,0,2.55),(.22,.22,.22),'cyan')
    dish.finish(parent=radar)
    rotation_loop(radar,frames=480,name='harbor_machinery')
    return root


def make_scene():
    if bpy.data.scenes.get(SCENE_NAME):
        raise RuntimeError('Crescent scene already exists; run in a fresh Blender process.')
    scene=bpy.data.scenes.new(SCENE_NAME)
    bpy.context.window.scene=scene
    scene.render.fps=24
    scene.frame_start=1
    scene.frame_end=481
    scene['selected_reference']=REFERENCE
    scene['description']='Crescent Harbor: original editable station, five functional relays, four-strand power cables and orbital service fleet.'
    initialize_materials(ASSET/'textures')
    core=build_main()
    add_station_detail(core)
    layouts=[('beacon','Relay_01_TrafficMast',-42,34,2),
             ('power','Relay_02_PowerDistribution',-10,51,3),
             ('cargo','Relay_03_OrbitalLogistics',36,55,2),
             ('control','Relay_04_PortApproach',63,30,1),
             ('service','Relay_05_RefuelRepair',64,-14,0)]
    stations=[core]
    for index,(kind,name,u,v,z) in enumerate(layouts):
        relay=build_relay(kind,name)
        relay.location=planar(u,v,z)
        relay.rotation_euler.z=math.radians((-10,7,-6,15,-8)[index])
        relay['service_kind']=kind
        stations.append(relay)
    station_keeping(stations)
    service_animation(stations)
    scene.frame_set(1)
    bpy.context.view_layer.update()
    sizes=[(24,24),(5,5),(10,8),(14,9.5),(6,6),(12,10.5)]
    def cable_anchor(index,toward):
        root=stations[index]
        direction=root.matrix_world.inverted() @ toward
        direction.z=0
        direction.normalize()
        hx,hy=sizes[index]
        distance=min(hx/max(abs(direction.x),.0001),hy/max(abs(direction.y),.0001))
        if index==0:
            distance=min(distance,34.32/(abs(direction.x)+abs(direction.y)))
        point=direction*distance
        point.z=5.3 if index==0 else 2.2
        return root.matrix_world @ point
    cables=[]
    for index in range(5):
        a=cable_anchor(index,stations[index+1].location)
        b=cable_anchor(index+1,stations[index].location)
        local_a=stations[index].matrix_world.inverted() @ a
        local_b=stations[index+1].matrix_world.inverted() @ b
        cables.append(flexible_bundle('PowerBundle_'+str(index+1), stations[index], local_a, stations[index+1], local_b))
    fleet=[]
    # Berths are actual static service poses; engine emission is omitted.
    docked=[('podcarrier','Ship_01_BerthedCarrier',36,40,6,math.pi/2,1),
            ('podcarrier','Ship_02_RefuelingCarrier',63,-23,5,.7,.8),
            ('courier','Ship_03_ArrivalsShuttle',-32,-40,8,.5,1),
            ('tug','Ship_04_ChargingTug',-5,41,7,2.4,1)]
    for kind,name,u,v,z,heading,scale in docked:
        ship=build_ship(kind,name,engines_on=False)
        ship.location=planar(u,v,z)
        ship.rotation_euler.z=heading
        ship.scale=(scale,)*3
        ship['flight_state']='docked'
        fleet.append(ship)
    fleet[0].location=stations[3].matrix_world @ Vector((0,-15,5.1))
    fleet[0].rotation_euler.z=stations[3].rotation_euler.z+math.pi
    fleet[1].location=stations[5].matrix_world @ Vector((0,-15.8,4.8))
    fleet[1].rotation_euler.z=stations[5].rotation_euler.z+math.pi
    fleet[2].location=core.matrix_world @ Vector((.5,-31,6.1))
    fleet[2].rotation_euler.z=.35
    fleet[3].location=stations[2].matrix_world @ Vector((3,-11.2,4.8))
    fleet[3].rotation_euler.z=stations[2].rotation_euler.z+math.pi
    moving=[('podcarrier','Ship_05_ArrivingCarrier',1.0),
            ('courier','Ship_06_PassengerArrival',1.3),
            ('courier','Ship_07_DepartingCourier',1.2),
            ('tug','Ship_08_CargoTug',.9),
            ('courier','Ship_09_RelayTransfer',.85),
            ('drone','Ship_10_CableInspector',1),
            ('drone','Ship_11_RepairDrone',1),
            ('drone','Ship_12_StationMaintenance',1),
            ('courier','Ship_13_PracticeCourier',.7)]
    for kind,name,scale in moving:
        ship=build_ship(kind,name,engines_on=True)
        ship.scale=(scale,)*3
        through_traffic(ship)
        fleet.append(ship)
    ship=build_ship('courier','Ship_14_RepairCradle',engines_on=False)
    ship.location=stations[5].matrix_world @ Vector((0,-5.3,5.8))
    ship.rotation_euler.z=stations[5].rotation_euler.z
    ship.scale=(1.25,)*3
    ship['flight_state']='clamped in service cradle'
    fleet.append(ship)
    bpy.context.view_layer.update()
    berth_connections(stations, fleet)
    # Frame-accurate repair-arm/scanner loops supplement traffic motion.
    scene.frame_set(1)
    bpy.context.view_layer.update()
    return scene,stations,cables,fleet


def presentation(scene):
    try:
        scene.render.engine='CYCLES'
    except TypeError as error:
        raise RuntimeError(str(error))
    scene.cycles.samples=48
    scene.cycles.use_denoising=True
    # CPU works in background on all supported hosts; device is not silently changed globally.
    enum_set(scene.cycles,'device','CPU')
    scene.render.resolution_x=2200
    scene.render.resolution_y=1240
    scene.render.resolution_percentage=100
    enum_set(scene.render.image_settings,'file_format','PNG')
    enum_set(scene.render.image_settings,'color_mode','RGBA')
    world=bpy.data.worlds.new('Crescent / deep space')
    world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.004,.010,.024,1)
    bg.inputs['Strength'].default_value=.35
    scene.world=world
    camera_data=bpy.data.cameras.new('Crescent / isometric overview')
    enum_set(camera_data,'type','ORTHO')
    camera_data.clip_end=1500
    camera=bpy.data.objects.new('Crescent / isometric overview',camera_data)
    scene.collection.objects.link(camera)
    target=planar(8,12,3)
    camera.location=target+Vector((150,-200,180))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=camera
    # Preserve the approved framing even when traffic starts offscreen.
    # Its fixed projection is u along the right vector, q along the up vector.
    orientation=camera.rotation_euler.to_matrix()
    right=orientation @ Vector((1,0,0))
    up=orientation @ Vector((0,1,0))
    camera.location += right*(9.3375-camera.location.dot(right))
    camera.location += up*(7.4415-camera.location.dot(up))
    camera_data.ortho_scale=160.175
    aspect=scene.render.resolution_x/scene.render.resolution_y
    def light(name,kind,position,energy,color,size=0):
        assert kind in [e.identifier for e in bpy.types.Light.bl_rna.properties['type'].enum_items]
        data=bpy.data.lights.new(name,kind)
        data.energy=energy
        data.color=color
        if kind=='AREA':
            data.size=size
        if kind=='SUN':
            data.angle=math.radians(8)
        obj=bpy.data.objects.new(name,data)
        scene.collection.objects.link(obj)
        obj.location=position
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
    light('Crescent / warm stellar key','SUN',(-60,-85,150),3.5,(1,.89,.72))
    light('Crescent / cool fill','AREA',(-55,-90,95),65000,(.38,.64,1),100)
    light('Crescent / soft rim','AREA',(50,110,110),85000,(1,.68,.42),90)
    star_root=root_empty('Presentation / distant stars')
    stars=MeshBuilder('Presentation / starfield')
    random.seed(260922)
    matrix=camera.rotation_euler.to_matrix()
    for i in range(430):
        x=random.uniform(-.55,.55)*camera_data.ortho_scale
        y=random.uniform(-.55,.55)*camera_data.ortho_scale/aspect
        p=camera.location+matrix@Vector((x,y,-650))
        s=random.choice([.024,.035,.05,.075,.11])
        stars.box(p,(s,s,s),'white' if i%4 else 'cyan')
    stars.finish(parent=star_root)
    # A compositor glow is optional and does not affect any exported asset.
    scene.use_nodes=True
    tree=scene.compositing_node_group if hasattr(scene,'compositing_node_group') else None
    if tree is None and hasattr(scene,'node_tree'):
        tree=scene.node_tree
    if tree is not None:
        layer=next((n for n in tree.nodes if n.type=='R_LAYERS'),None)
        composite=next((n for n in tree.nodes if n.type=='COMPOSITE'),None)
        if layer and composite:
            glare=tree.nodes.new('CompositorNodeGlare')
            enum_set(glare,'glare_type','FOG_GLOW')
            tree.links.new(layer.outputs['Image'],glare.inputs['Image'])
            tree.links.new(glare.outputs['Image'],composite.inputs['Image'])
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                region=area.spaces.active.region_3d
                region.view_location=target
                region.view_distance=camera_data.ortho_scale
                region.view_rotation=camera.rotation_euler.to_quaternion()
                enum_set(region,'view_perspective','CAMERA')
                enum_set(area.spaces.active.shading,'type','MATERIAL')
                area.spaces.active.shading.use_scene_world=True
                area.spaces.active.shading.use_scene_lights=True
                area.spaces.active.overlay.show_overlays=False
    scene.render.filepath=str(PREVIEW/'crescent-harbor-overview.png')
    return camera


def export_file(path, roots, animation=True):
    scene=bpy.context.scene
    for obj in scene.objects:
        obj.select_set(False)
    objects=[]
    for root in roots:
        objects.extend([root,*root.children_recursive])
    objects=list(dict.fromkeys(objects))
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=roots[0]
    props=bpy.ops.export_scene.gltf.get_rna_type().properties
    mode='NLA_TRACKS'
    assert mode in [v.identifier for v in props['export_animation_mode'].enum_items]
    assert 'EXPORT' in [v.identifier for v in props['export_materials'].enum_items]
    bpy.ops.export_scene.gltf(filepath=str(path),use_selection=True,use_active_scene=True,
        export_animations=animation,export_animation_mode=mode,export_frame_range=True,
        export_force_sampling=True,export_frame_step=2,export_yup=True,export_materials='EXPORT',export_extras=True)
    tris=0
    for obj in objects:
        if obj.type=='MESH':
            obj.data.calc_loop_triangles()
            tris+=len(obj.data.loop_triangles)
    return {'path':str(path.relative_to(ASSET)),'triangles':tris,'objects':len(objects),'bytes':path.stat().st_size}


def save_manifest(scene,stations,cables,fleet,exports):
    source=ASSET/'source/wayfarer_crescent.blend'
    scene.frame_set(1)
    # The authored checkpoint is saved before export. Keep those exact source
    # bytes for collision verification and preview provenance.
    if not source.is_file():
        raise RuntimeError('Save the authored Blender checkpoint before packaging')
    outputs=[]
    for folder in ('meshes','textures','source'):
        for path in sorted((ASSET/folder).glob('*')):
            if path.suffix not in ('.glb','.png','.blend'):
                continue
            outputs.append({'path':str(path.relative_to(ASSET)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size})
    manifest={'schema_version':1,'full_scene':'meshes/wayfarer_crescent.glb',
              'blender_version':bpy.app.version_string,'reference_image':REFERENCE,
              'reference_sha256':hashlib.sha256((ROOT/REFERENCE).read_bytes()).hexdigest(),
              'major_roots':[o.name for o in stations], 'ship_roots':[o.name for o in fleet],
              'cable_roots':[o.name for o in cables], 'exports':exports,'outputs':outputs,
              'animation':{'fps':24,'first_frame':1,'last_frame':481,'duration_seconds':20,
                           'clips':sorted({track.name for obj in scene.objects if obj.animation_data
                                           for track in obj.animation_data.nla_tracks})},
              'source_scripts':['tools/build_crescent_harbor_blender.py','tools/crescent_harbor/geometry.py',
                                'tools/crescent_harbor/relays.py','tools/crescent_harbor/fleet.py',
                                'tools/crescent_harbor/detailing.py','tools/crescent_harbor/animation.py',
                                'tools/crescent_harbor/traffic.py'],
              'provenance':'Original local Blender geometry and procedural pixel textures, derived from the user-approved image-generation concept. No third-party mesh or paid generation service.',
              'engine_integration':'Production home port uses the complete composition through systems/crescent_harbor_visuals.gd; service locations and player clearance use systems/home_port_sections.gd and systems/crescent_harbor_layout.gd.', 'previews':[]}
    for path in sorted(PREVIEW.glob('*.png')):
        manifest['previews'].append({'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (ASSET/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


def export_module(path, root):
    """Export reusable local coordinates, retaining child machinery animations."""
    excluded=set()
    for child in root.children_recursive:
        if child.get('flight_state'):
            excluded.update([child,*child.children_recursive])
    originals=[obj for obj in [root,*root.children_recursive] if obj not in excluded]
    copies={}
    for original in originals:
        clone=original.copy()
        clone.name=original.name+' / module'
        bpy.context.scene.collection.objects.link(clone)
        copies[original]=clone
    for original,clone in copies.items():
        clone.parent=copies.get(original.parent)
    local_root=copies[root]
    local_root.animation_data_clear()
    local_root.location=(0,0,0)
    local_root.rotation_euler=(0,0,0)
    local_root.rotation_quaternion=(1,0,0,0)
    local_root.scale=root.matrix_world.to_scale()
    bpy.context.view_layer.update()
    result=export_file(path,[local_root])
    for clone in reversed(list(copies.values())):
        bpy.data.objects.remove(clone,do_unlink=True)
    return result


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--draft',action='store_true')
    parser.add_argument('--skip-export',action='store_true')
    options=parser.parse_args(args)
    for directory in (ASSET/'source',ASSET/'meshes',ASSET/'textures',ASSET/'docs',PREVIEW):
        directory.mkdir(parents=True,exist_ok=True)
    scene,stations,cables,fleet=make_scene()
    camera=presentation(scene)
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(ASSET/'source/wayfarer_crescent.blend'))
    print('CRESCENT_BUILT '+json.dumps({'objects':len(scene.objects),'station_roots':[o.name for o in stations],'ships':len(fleet)}),flush=True)
    exports=[]
    if not options.skip_export:
        exports.append(export_file(ASSET/'meshes/wayfarer_crescent.glb',stations+cables+fleet))
        for index,root in enumerate(stations):
            exports.append(export_module(ASSET/'meshes'/('wayfarer_core.glb' if index==0 else root['service_kind']+'_relay.glb'),root))
        for root in [fleet[0],fleet[2],fleet[3],fleet[9]]:
            exports.append(export_module(ASSET/'meshes'/(root.name.lower()+'.glb'),root))
    manifest=save_manifest(scene,stations,cables,fleet,exports)
    if options.preview:
        if options.draft:
            scene.cycles.samples=16
            scene.render.resolution_percentage=65
        bpy.ops.render.render(write_still=True)
        save_manifest(scene,stations,cables,fleet,exports)
    print('CRESCENT_DELIVERY '+json.dumps({'source':str(ASSET/'source/wayfarer_crescent.blend'),'exports':exports,'preview':scene.render.filepath}),flush=True)


if __name__=='__main__':
    main()
