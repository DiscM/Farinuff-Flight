"""Audit the saved traffic animation without changing the Blender source.

Run Blender --background --factory-startup --python-exit-code 1
    --python tools/crescent_harbor/verify_traffic_camera.py

Every authored frame is evaluated. Conservative projected mesh bounding boxes
check visibility and hidden returns; world-space velocity checks nose alignment
and visible speed continuity. The authored scene's own route properties identify
return intervals. This is a camera/animation audit, not a collision checker.
"""

import bpy, math, json, sys, hashlib
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'tools'))
from crescent_harbor.traffic import _path
source=root/'assets/models/wayfarer_crescent/source/wayfarer_crescent.blend'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene;scene.frame_set(1);bpy.context.view_layer.update()
cam=scene.camera;inverse=cam.matrix_world.inverted();width=cam.data.ortho_scale;height=width*scene.render.resolution_y/scene.render.resolution_x
ships={o.name:o for o in scene.objects if o.get('flight_state')=='through traffic'}
assert len(ships)==9, 'Expected nine through-traffic craft'
paths={}
for name,ship in ships.items():
 flat=list(ship['route_waypoints_uvz']);waypoints=[tuple(flat[i:i+3]) for i in range(0,len(flat),3)]
 phase=ship['route_phase'];side=ship['route_return_side']
 samples,distances=_path(waypoints,side,int(ship.get('route_return_lane',0)))
 paths[name]=(phase,distances[(len(waypoints)-1)*64]/distances[-1])
records={name:[] for name in ships}
for frame in range(1,482):
 scene.frame_set(frame);bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get()
 for name,ship in ships.items():
  current=ship.evaluated_get(dep)
  points=[]
  for obj in ship.children_recursive:
   if obj.type=='MESH':
    evaluated=obj.evaluated_get(dep);matrix=inverse@evaluated.matrix_world
    points.extend(matrix@Vector(p) for p in evaluated.bound_box)
  bounds=(min(p.x for p in points),max(p.x for p in points),min(p.y for p in points),max(p.y for p in points))
  visible=not(bounds[1]<-width/2 or bounds[0]>width/2 or bounds[3]<-height/2 or bounds[2]>height/2)
  phase,hidden_start=paths[name];fraction=(phase+(frame-1)/480)%1
  records[name].append({'position':current.matrix_world.translation.copy(),'forward':(current.matrix_world.to_3x3()@Vector((0,-1,0))).normalized(),'visible':visible,'hidden':fraction>=hidden_start,'bounds':bounds})
issues=[];warnings=[];results=[]
for name,frames in records.items():
 visible=[f['visible'] for f in frames[:480]]
 entries=[i+1 for i in range(480) if visible[i] and not visible[(i-1)%480]]
 exits=[i+1 for i in range(480) if not visible[i] and visible[(i-1)%480]]
 hidden_visible=[i+1 for i,f in enumerate(frames[:480]) if f['hidden'] and f['visible']]
 heading=[];steps=[];position_closure=(frames[480]['position']-frames[0]['position']).length
 nose_closure=(frames[480]['forward']-frames[0]['forward']).length
 for i,f in enumerate(frames[:480]):
  velocity=frames[(i+1)%480]['position']-frames[(i-1)%480]['position']
  if f['visible'] and velocity.length>1e-6:
   heading.append(math.degrees(math.acos(max(-1,min(1,f['forward'].dot(velocity.normalized()))))))
  if f['visible'] and frames[(i+1)%480]['visible']:
   steps.append((frames[(i+1)%480]['position']-f['position']).length)
 median=sorted(steps)[len(steps)//2] if steps else 0
 report={'ship':name,'visible_frames':sum(visible),'entry_frames':entries,'exit_frames':exits,'hidden_return_visible_frames':hidden_visible,'max_visible_heading_error_degrees':round(max(heading or [0]),4),'mean_visible_heading_error_degrees':round(sum(heading)/len(heading),4) if heading else None,'max_visible_step':round(max(steps or [0]),5),'median_visible_step':round(median,5),'visible_max_median_step_ratio':round(max(steps or [0])/median,5) if median else None,'position_loop_closure':round(position_closure,7),'nose_loop_closure':round(nose_closure,7)}
 results.append(report)
 if not entries or not exits:issues.append(name+': does not enter and exit')
 if len(entries)>1 or len(exits)>1:warnings.append(name+': route briefly leaves and re-enters a camera edge')
 if hidden_visible:issues.append(name+': hidden return enters camera')
 if max(heading or [0])>15:issues.append(name+': visible nose/velocity disagreement')
 if median and max(steps)/median>2.0:issues.append(name+': visible speed discontinuity')
 if max(position_closure,nose_closure)>1e-4:issues.append(name+': loop seam')
if hashlib.sha256(source.read_bytes()).hexdigest()!=source_hash:issues.append('Source changed on disk during verification')
report={'passed':not issues,'source_sha256':source_hash,'sample_frames':481,'camera':{'width':width,'height':height,'name':cam.name},'ships':results,'issues':issues,'warnings':warnings}
path=root/'assets/models/wayfarer_crescent/docs/camera-traffic-verification.json';path.write_text(json.dumps(report,indent=2)+'\n')
print('TRAFFIC_CAMERA_AUDIT '+json.dumps(report),flush=True)

if issues:
 raise RuntimeError('Traffic camera verification failed: '+'; '.join(issues))
