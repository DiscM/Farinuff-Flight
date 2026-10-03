"""Refine canonical boss meshes in Blender without replacing rigs, clips or sockets.
Run after the original builder, or against the current editable source.
"""
from pathlib import Path
import json
import sys
import bpy
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import build_voxel_bosses_blender as base


def geometry(role):
    """Retain the shipped hulls; shape only their upper armor edges."""
    g,_ = base.geometry(role)
    original=dict(g.cells)
    # Recess the outer lip of raised armor by one voxel. Lower hulls,
    # weapon rails, reactors and engine collars retain their original forms.
    for (x,y,z),(part,color,tile) in original.items():
        if z<2 or color not in (0,1) or part not in ('Body','Port','Starboard'):
            continue
        exposed=sum((x+dx,y+dy,z) not in original for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
        if exposed>=2 and (x,y,z-1) in original:
            del g.cells[x,y,z]
    # Restrained recessed vents on the broad armor. These remain inset in
    # the existing volume, with no change to hull outline or articulation.
    for side,part in [(-1,'Port'),(1,'Starboard')]:
        xcenter={'assault':10,'bulwark':13,'tempest':11,'void_harbinger':11,'tempest_core':12,'section':5}[role]*side
        ycenter={'assault':-2,'bulwark':-1,'tempest':10,'void_harbinger':0,'tempest_core':-1,'section':-2}[role]
        for y in range(ycenter-2,ycenter+3,2):
            for x in range(xcenter-1,xcenter+2):
                zs=[z for xx,yy,z in g.cells if xx==x and yy==y and g.cells[xx,yy,z][0]==part]
                if not zs: continue
                z=max(zs)
                if g.cells[x,y,z][1] in (0,1): g.put(x,y,z,part,2,2)
    return g


def refine():
    manifest=json.loads((base.PACK/'build_manifest.json').read_text())
    measurements=[]
    for asset,role in zip(base.IDS,base.ROLES):
        scene=bpy.data.scenes[base.PREFIX+asset]
        bpy.context.window.scene=scene
        old={o['rigid_part']:o for o in scene.objects if o.type=='MESH' and 'rigid_part' in o}
        mats=list(old['Body'].data.materials)
        generated=geometry(role).mesh_objects(scene,asset+'_refined',mats)
        for new in generated:
            target=old[new['rigid_part']]
            # Reduce slab depth moderately, retaining the original layered mass.
            for vertex in new.data.vertices:
                vertex.co.z *= .82
            previous=target.data
            # Studio copies share the original mesh data, so update every instance.
            for obj in bpy.data.objects:
                if obj.type=='MESH' and obj.data==previous: obj.data=new.data
            bone=new['rigid_part'] if new['rigid_part'] in base.motion.BONES else 'Body'
            for obj in bpy.data.objects:
                if obj.type=='MESH' and obj.data==new.data:
                    for vg in list(obj.vertex_groups): obj.vertex_groups.remove(vg)
                    obj.vertex_groups.new(name=bone).add(list(range(len(new.data.vertices))),1,'REPLACE')
            bpy.data.objects.remove(new,do_unlink=True)
        rig=next(o for o in scene.objects if o.type=='ARMATURE')
        for t in rig.animation_data.nla_tracks: t.mute=False
        scene.frame_set(0)
        bpy.ops.object.select_all(action='SELECT')
        record=next(r for r in manifest['assets'] if r['id']==asset)
        sockets={name:((0,0,0),bone) for name,bone in record['sockets'].items()}
        result=base.export_asset(scene,asset,role,sockets)
        record.update(result)
        record['voxel_size']=.28
        for t in rig.animation_data.nla_tracks: t.mute=t.name!='cruise'
        points=[v.co for o in old.values() for v in o.data.vertices]
        measurements.append({'asset':asset,'dimensions':[max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)],'triangles':sum(len(o.data.polygons)*2 for o in old.values())})
    manifest['geometry_revision']='original-hull-polish-2026-10-02'
    (base.PACK/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    board=bpy.data.scenes[base.PREFIX+'Collection']
    bpy.context.window.scene=board
    board.render.filepath=str(ROOT/'design/voxel-bosses/blender/refined_collection.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(base.SOURCE))
    (ROOT/'design/voxel-bosses/refinement.json').write_text(json.dumps(measurements,indent=2)+'\n')
    print(json.dumps(measurements))

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(base.SOURCE))
    refine()
