"""Audit shipping enemy GLBs and compare geometry/palette with the pre-change Git bytes."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def document(blob):
    size = struct.unpack_from('<I', blob, 12)[0]
    return json.loads(blob[20:20+size]), blob[28+size:]


def accessor_bytes(doc, binary, index):
    accessor = doc['accessors'][index]
    view = doc['bufferViews'][accessor['bufferView']]
    width = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}[accessor['type']]
    unit = {5120:1, 5121:1, 5122:2, 5123:2, 5125:4, 5126:4}[accessor['componentType']]*width
    offset = view.get('byteOffset',0)+accessor.get('byteOffset',0)
    stride = view.get('byteStride',unit)
    return b''.join(binary[offset+i*stride:offset+i*stride+unit] for i in range(accessor['count']))


def geometry(doc, binary):
    # Mesh ordering is irrelevant; exact positions, UVs, rigid weights and indices are not.
    result=[]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            fields={key:hashlib.sha256(accessor_bytes(doc,binary,index)).hexdigest()
                    for key,index in primitive['attributes'].items()}
            fields['indices']=hashlib.sha256(accessor_bytes(doc,binary,primitive['indices'])).hexdigest()
            result.append(fields)
    return sorted(result,key=lambda x:json.dumps(x,sort_keys=True))


def audit():
    roles=['basic','fast','bomber','tank','sniper']
    files=[ROOT/'assets/models/voxel_frontier/meshes'/f'{role}_enemy.glb' for role in roles]
    files+=list(sorted((ROOT/'assets/models/voxel_bosses/meshes').glob('*.glb')))
    result=[]
    for path in files:
        relative=path.relative_to(ROOT).as_posix()
        blob=path.read_bytes(); doc,binary=document(blob)
        old_blob=subprocess.check_output(['git','show','HEAD:'+relative]); old,old_binary=document(old_blob)
        animations=doc.get('animations',[])
        checks={
            'geometry_unchanged': geometry(doc,binary)==geometry(old,old_binary),
            'four_rigid_bones': all(len(skin['joints'])==4 for skin in doc.get('skins',[])) and bool(doc.get('skins')),
            'palette_unchanged': sorted([m.get('pbrMetallicRoughness',{}).get('baseColorFactor') for m in doc['materials']])==sorted([m.get('pbrMetallicRoughness',{}).get('baseColorFactor') for m in old['materials']]),
            'texture_embedded': all('bufferView' in image for image in doc.get('images',[])) and bool(doc.get('images')),
            'sockets_preserved': {node['name'] for node in old['nodes'] if node.get('name','').startswith('Socket_')}.issubset({node.get('name','') for node in doc['nodes']}),
        }
        varied=[]
        for animation in animations:
            changing=False
            for sampler in animation['samplers']:
                accessor=doc['accessors'][sampler['output']]
                values=accessor_bytes(doc,binary,sampler['output'])
                unit=len(values)//accessor['count']
                changing |= any(values[i:i+unit]!=values[:unit] for i in range(unit,len(values),unit))
            if changing:varied.append(animation['name'])
        checks['clips_animate']=len(varied)==len(animations)
        result.append(dict(file=relative,bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest(),
                           meshes=len(doc['meshes']),clips=[a['name'] for a in animations],checks=checks))
    return {'scope':'All shipping regular enemy, boss and destructible boss-pod GLBs. Courier shares Fast. Historical animated/mockup exports are not used by shipping enemy scenes.',
            'passed':all(all(item['checks'].values()) for item in result),'assets':result}


if __name__=='__main__':
    report=audit()
    out=ROOT/'design/attack-motion/asset-audit.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    (out.parent/'.gdignore').write_text('')
    out.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'passed':report['passed'],'assets':len(report['assets']),
                      'failed':[(r['file'],[k for k,v in r['checks'].items() if not v]) for r in report['assets'] if not all(r['checks'].values())]},indent=2))
    raise SystemExit(0 if report['passed'] else 1)
