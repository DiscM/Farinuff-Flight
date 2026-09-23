"""Independently audit the authored Blender scene and exported GLB.

Run in an isolated background process from any working directory:
    Blender --background --factory-startup --python-exit-code 1 \
        --python tools/crescent_harbor/verify_blender.py

Only docs/blender-verification.json is written. Source/exports are never saved,
mutated, or rendered. Checks include sampled source motion, 20-second NLA
coverage, GLB sampler endpoints, and actual reimported clip poses.
"""

import bpy, json, math, hashlib, struct
from mathutils import Vector
from pathlib import Path
base=Path(__file__).resolve().parents[2]/'assets/models/wayfarer_crescent'
source=base/'source/wayfarer_crescent.blend'
glb=base/'meshes/wayfarer_crescent.glb'
report={'blender_version':bpy.app.version_string,'source':str(source),'glb':str(glb),'checks':{},'issues':[]}
report['sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,glb)}
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
animated=[o for o in scene.objects if o.animation_data and (o.animation_data.action or len(o.animation_data.nla_tracks))]
# Mix authored keyframes with intermediate frames so attachment checks also
# exercise interpolation, and short beacon pulses cannot hide at quarter turns.
frames=sorted(set(range(1,482,8)) | set(range(4,481,8)))
poses={}
local_poses={}
socket_objects=[o for o in scene.objects if 'anchor_station' in o]
docked_objects=[o for o in scene.objects if o.get('flight_state') in ('docked','clamped in service cradle')]
socket_checks={}
docked_checks={}
for o in socket_objects:
    station=scene.objects.get(o.get('anchor_station',''))
    local=list(o.get('anchor_local',[]))
    if station is None or len(local)!=3 or not all(math.isfinite(v) for v in local):
        report['issues'].append('Socket has invalid anchor metadata: '+o.name)
        continue
    socket_checks[o.name]={'object':o.name,'station':station.name,'anchor_local':local,
                          'max_position_error':0.0,'max_relative_basis_error':0.0}
for o in docked_objects:
    expected=list(o.get('docked_local_matrix',[]))
    if o.parent is None or o.parent.name!=o.get('docked_to') or len(expected)!=16 or not all(math.isfinite(v) for v in expected):
        report['issues'].append('Docked ship has invalid parent/attachment metadata: '+o.name)
        continue
    docked_checks[o.name]={'object':o.name,'station':o.parent.name,'max_relative_matrix_error':0.0}
socket_rest={}
for frame in frames:
    scene.frame_set(frame); bpy.context.view_layer.update()
    dep=bpy.context.evaluated_depsgraph_get()
    poses[frame]={o.name:[float(v) for row in o.evaluated_get(dep).matrix_world for v in row] for o in animated}
    local_poses[frame]={o.name:[float(v) for row in o.evaluated_get(dep).matrix_local for v in row] for o in animated}
    for name,check in socket_checks.items():
        o=scene.objects[name].evaluated_get(dep)
        station=scene.objects[check['station']].evaluated_get(dep)
        expected=station.matrix_world @ Vector(check['anchor_local'])
        error=(o.matrix_world.translation-expected).length
        check['max_position_error']=max(check['max_position_error'],error)
        relative=station.matrix_world.inverted() @ o.matrix_world
        basis=[float(relative[row][column]) for row in range(3) for column in range(3)]
        socket_rest.setdefault(name,basis)
        check['max_relative_basis_error']=max(check['max_relative_basis_error'],max(abs(a-b) for a,b in zip(socket_rest[name],basis)))
    for name,check in docked_checks.items():
        original=scene.objects[name]
        o=original.evaluated_get(dep)
        parent=original.parent.evaluated_get(dep)
        relative=parent.matrix_world.inverted() @ o.matrix_world
        actual=[float(v) for row in relative for v in row]
        check['max_relative_matrix_error']=max(check['max_relative_matrix_error'],max(abs(a-b) for a,b in zip(actual,original['docked_local_matrix'])))
for name,check in socket_checks.items():
    if check['max_position_error']>2e-4 or check['max_relative_basis_error']>2e-4:
        report['issues'].append('Cable socket detaches from its station across the cycle: '+name)
for name,check in docked_checks.items():
    if check['max_relative_matrix_error']>2e-4:
        report['issues'].append('Docked ship changes its station-relative attachment pose: '+name)
if not socket_checks:
    report['issues'].append('No hull-mounted cable sockets found for attachment verification')
if not docked_checks:
    report['issues'].append('No attached docked ships found for attachment verification')
report['source_attachments']={'sample_frames':frames,'tolerance':2e-4,
                              'socket_checks':list(socket_checks.values()),
                              'docked_ship_checks':list(docked_checks.values())}
records=[]
for o in animated:
    samples=[poses[f][o.name] for f in frames]
    local_samples=[local_poses[f][o.name] for f in frames]
    motion=max(max(abs(a-b) for a,b in zip(local_samples[0],sample)) for sample in local_samples[1:-1])
    world_motion=max(max(abs(a-b) for a,b in zip(samples[0],sample)) for sample in samples[1:-1])
    close=max(abs(a-b) for a,b in zip(samples[0],samples[-1]))
    clips=[]
    for track in o.animation_data.nla_tracks:
        for strip in track.strips:
            clips.append({'name':strip.name,'action':strip.action.name if strip.action else None,'start':round(strip.frame_start,3),'end':round(strip.frame_end,3),'repeat':round(strip.repeat,3),'source_action_frames':[round(v,3) for v in strip.action.frame_range] if strip.action else []})
    records.append({'object':o.name,'motion_delta':round(motion,6),'world_motion_delta':round(world_motion,6),'frame_481_closure_delta':round(close,6),'clips':clips})
    if motion<1e-5: report['issues'].append('Source animated object has no sampled local motion: '+o.name)
    if close>2e-4: report['issues'].append('Source loop does not close at frame 481: '+o.name)
    if any(c['start']>1.001 or c['end']<480.999 for c in clips): report['issues'].append('NLA clip does not cover all 20 seconds: '+o.name)
report['source_scene']={'objects':len(scene.objects),'meshes':sum(o.type=='MESH' for o in scene.objects),'materials':len(bpy.data.materials),'animated_objects':len(animated),'fps':scene.render.fps,'frame_range':[scene.frame_start,scene.frame_end],'sample_frames':frames,'animation_checks':records}
# Validate actual GLB clip timelines independently from Blender's importer.
raw=glb.read_bytes(); magic,version,total=struct.unpack_from('<4sII',raw,0); length,typ=struct.unpack_from('<II',raw,12)
data=json.loads(raw[20:20+length]); binary_offset=20+length
binlength,bintype=struct.unpack_from('<II',raw,binary_offset); binary=raw[binary_offset+8:binary_offset+8+binlength]
clips=[]
for anim in data.get('animations',[]):
    mins=[];maxs=[]
    for sampler in anim['samplers']:
        accessor=data['accessors'][sampler['input']]; view=data['bufferViews'][accessor['bufferView']]
        values=struct.unpack_from('<'+'f'*accessor['count'],binary,view.get('byteOffset',0)+accessor.get('byteOffset',0))
        mins.append(min(values));maxs.append(max(values))
    clips.append({'name':anim.get('name',''),'channels':len(anim.get('channels',[])),'seconds':[round(min(mins),5),round(max(maxs),5)]})
report['glb_structure']={'version':version,'meshes':len(data.get('meshes',[])),'materials':len(data.get('materials',[])),'images':len(data.get('images',[])),'animations':clips}
# Compare real exported sampler endpoints. Rotation quaternions may legitimately
# differ only by sign while representing the same orientation.
def accessor_values(index):
    acc=data['accessors'][index]; view=data['bufferViews'][acc['bufferView']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[acc['type']]
    assert acc['componentType']==5126
    stride=view.get('byteStride',width*4)
    offset=view.get('byteOffset',0)+acc.get('byteOffset',0)
    return [struct.unpack_from('<'+'f'*width,binary,offset+i*stride) for i in range(acc['count'])]
endpoint_checks=[]
for anim in data.get('animations',[]):
    errors=[]
    for channel in anim['channels']:
        sampler=anim['samplers'][channel['sampler']]
        vals=accessor_values(sampler['output'])
        if sampler.get('interpolation')=='CUBICSPLINE': vals=vals[1::3]
        delta=max(abs(a-b) for a,b in zip(vals[0],vals[-1]))
        if channel['target']['path']=='rotation':
            delta=min(delta,max(abs(a+b) for a,b in zip(vals[0],vals[-1])))
        errors.append(delta)
    endpoint_checks.append({'clip':anim.get('name',''),'max_endpoint_delta':round(max(errors),7),'closed':max(errors)<2e-4})
    if max(errors)>2e-4: report['issues'].append('Exported GLB sampler endpoints do not close: '+anim.get('name',''))
report['glb_sampler_endpoints']=endpoint_checks

# Fresh in-memory scene; no file is saved or mutated.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
scene=bpy.context.scene
imported_animated=[o for o in scene.objects if o.animation_data and (o.animation_data.action or len(o.animation_data.nla_tracks))]
mesh_objects=[o for o in scene.objects if o.type=='MESH']
report['glb_round_trip']={'objects':len(scene.objects),'mesh_objects':len(mesh_objects),'vertices':sum(len(o.data.vertices) for o in mesh_objects),'polygons':sum(len(o.data.polygons) for o in mesh_objects),'materials':len(bpy.data.materials),'images':len(bpy.data.images),'actions':len(bpy.data.actions),'animated_objects':len(imported_animated)}
# Activate each imported action/slot in isolation, as Blender's glTF animation
# selector does. Imported NLA tracks are stashes, with zero strip influence,
# so merely unmuting a track does not reliably evaluate its animation.
for o in imported_animated:
    o.animation_data.action=None
    for track in o.animation_data.nla_tracks: track.mute=True
pose_checks=[]
for clip in clips:
    active=[]
    for o in imported_animated:
        for track in o.animation_data.nla_tracks:
            names=[track.name]+[st.action.name for st in track.strips if st.action]
            if clip['name'] in names:

                strip=next(st for st in track.strips if st.action)
                o.animation_data.action=strip.action
                o.animation_data.action_slot=strip.action_slot
                o.animation_data.action_influence=1.0
                active.append((o,track))
    affected={o.name:o for o,t in active}
    snapshots=[]
    for frame in frames:
        scene.frame_set(frame);bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get()
        snapshots.append({name:[float(v) for row in o.evaluated_get(dep).matrix_world for v in row] for name,o in affected.items()})
    closure=max([max(abs(a-b) for a,b in zip(snapshots[0][name],snapshots[-1][name])) for name in affected] or [1e9])
    motion=max([max(abs(a-b) for a,b in zip(snapshots[0][name],snap[name])) for name in affected for snap in snapshots[1:-1]] or [0])
    pose_checks.append({'clip':clip['name'],'affected_objects':len(affected),'motion_delta':round(motion,6),'endpoint_pose_delta':round(closure,6),'closed':closure<2e-4})
    if not affected: report['issues'].append('No imported NLA tracks found for clip: '+clip['name'])
    elif closure>2e-4: report['issues'].append('Imported GLB evaluated poses do not close: '+clip['name'])
    elif motion<1e-5: report['issues'].append('Imported GLB clip has no evaluated motion: '+clip['name'])
    for o,track in active: o.animation_data.action=None
report['glb_round_trip']['clip_pose_checks']=pose_checks
for key in ('mesh_objects','vertices','polygons','materials','actions','animated_objects'):
    if report['glb_round_trip'][key]<=0: report['issues'].append('GLB import has no '+key)
if not clips: report['issues'].append('GLB has no animation clips')
report['checks']={'source_has_motion':all(r['motion_delta']>1e-5 for r in records),'source_all_loops_close':all(r['frame_481_closure_delta']<2e-4 for r in records),'source_nla_covers_20_seconds':all(c['start']<=1.001 and c['end']>=480.999 for r in records for c in r['clips']),'glb_round_trip_nonempty':all(report['glb_round_trip'][k]>0 for k in ('mesh_objects','vertices','materials','actions','animated_objects'))}
report['checks']['glb_sampler_endpoints_close']=all(c['closed'] for c in endpoint_checks)
report['checks']['glb_imported_poses_close']=all(c['closed'] and c['motion_delta']>1e-5 for c in pose_checks)
report['checks']['cable_sockets_remain_attached']=bool(socket_checks) and all(c['max_position_error']<=2e-4 and c['max_relative_basis_error']<=2e-4 for c in socket_checks.values())
report['checks']['docked_ships_remain_attached']=bool(docked_checks) and all(c['max_relative_matrix_error']<=2e-4 for c in docked_checks.values())
report['passed']=not report['issues']
output=base/'docs/blender-verification.json'; output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
print('CRESCENT_VERIFICATION '+json.dumps({'passed':report['passed'],'checks':report['checks'],'issues':report['issues'],'round_trip':report['glb_round_trip'],'output':str(output)}),flush=True)

if not report['passed']:
    raise RuntimeError('Crescent Blender verification failed: ' + '; '.join(report['issues']))
