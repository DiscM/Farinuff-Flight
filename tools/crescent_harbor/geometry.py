"""Batched hard-surface geometry, original pixel materials and rigid animation."""
import math
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

PALETTE = {
    'ivory': (.81, .79, .67), 'armor': (.53, .61, .63),
    'navy': (.034, .068, .105), 'steel': (.19, .27, .32),
    'copper': (.56, .22, .075), 'glass': (.37, .68, .75),
    'cyan': (.075, .66, .92), 'amber': (1.0, .46, .10),
    'red': (.86, .038, .02), 'black': (.012, .025, .04),
    'green': (.12, .43, .19), 'white': (.90, .94, .86),
    'orange': (.85, .29, .055), 'darkglass': (.018, .105, .16),
}
MATERIALS = {}
GLOW = {'cyan': 4.0, 'amber': 3.0, 'red': 4.5, 'white': .3}


def enum_set(obj, prop, value):
    values = [item.identifier for item in obj.bl_rna.properties[prop].enum_items]
    if value not in values:
        raise RuntimeError(f'Unsupported {prop}={value}; available {values}')
    setattr(obj, prop, value)


def initialize_materials(directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    for role, color in PALETTE.items():
        mat = bpy.data.materials.new('Crescent / ' + role)
        mat.use_nodes = True
        mat.diffuse_color = (*color, 1)
        shader = next(node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
        shader.inputs['Base Color'].default_value = (*color, 1)
        shader.inputs['Metallic'].default_value = .55 if role in ('steel', 'copper', 'navy') else .22
        shader.inputs['Roughness'].default_value = .62
        if role in GLOW:
            shader.inputs['Emission Color'].default_value = (*color, 1)
            shader.inputs['Emission Strength'].default_value = GLOW[role]
        if role in ('glass', 'darkglass'):
            shader.inputs['Metallic'].default_value = .12
            shader.inputs['Roughness'].default_value = .16
            shader.inputs['Transmission Weight'].default_value = .90 if role == 'glass' else .06
            shader.inputs['IOR'].default_value = 1.22 if role == 'glass' else 1.45
        # Baked original pixel plating; all surfaces retain UVs on export.
        pixels = []
        for y in range(64):
            for x in range(64):
                variation = 1 + (((x*13+y*7) % 13)-6)*.003
                if x < 3 or x > 60 or y < 3 or y > 60:
                    variation *= .72
                if role not in GLOW and role not in ('glass', 'darkglass'):
                    if (x in (5, 6, 57, 58)) and (y in (5, 6, 57, 58)):
                        variation *= .59
                    if y == 48 and 10 < x < 28:
                        variation *= .82
                pixels.extend([min(1, value*variation) for value in color] + [1])
        image = bpy.data.images.new('Crescent Pixel ' + role, 64, 64, alpha=True)
        enum_set(image.colorspace_settings, 'name', 'sRGB')
        enum_set(image, 'file_format', 'PNG')
        image.pixels.foreach_set(pixels)
        image.update()
        image.filepath_raw = str(directory / (role + '.png'))
        image.save()
        image.pack()
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = image
        enum_set(tex, 'interpolation', 'Closest')
        mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
        MATERIALS[role] = mat
    return MATERIALS


class MeshBuilder:
    def __init__(self, name='Geometry'):
        self.name = name
        self.vertices = []
        self.faces = []
        self.roles = []

    def _surface(self, vertices, faces, material):
        if material not in PALETTE:
            raise ValueError('Unknown material ' + str(material))
        offset = len(self.vertices)
        self.vertices.extend([tuple(v) for v in vertices])
        self.faces.extend([tuple(offset + i for i in face) for face in faces])
        self.roles.extend([material] * len(faces))
        return self

    def box(self, center, size, material, rotation=None):
        center = Vector(center)
        if isinstance(rotation, (int, float)):
            rotation = Matrix.Rotation(rotation, 3, 'Z')
        points = [Vector((x*size[0]/2, y*size[1]/2, z*size[2]/2))
                  for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                                (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        vertices = [center + (rotation @ p if rotation is not None else p) for p in points]
        return self._surface(vertices, [(0,3,2,1),(4,5,6,7),(0,1,5,4),
                                        (1,2,6,5),(2,3,7,6),(3,0,4,7)], material)

    def cylinder(self, center, radius, depth, material, vertices=12):
        points = []
        for z in (-depth/2, depth/2):
            points.extend([(center[0]+radius*math.cos(i*math.tau/vertices),
                            center[1]+radius*math.sin(i*math.tau/vertices), center[2]+z)
                           for i in range(vertices)])
        faces = [tuple(reversed(range(vertices))), tuple(range(vertices,2*vertices))]
        faces += [(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
        return self._surface(points, faces, material)

    def ring(self, center, outer, inner, depth, material, vertices=16):
        points = []
        for z in (-depth/2, depth/2):
            for radius in (outer, inner):
                points += [(center[0]+radius*math.cos(i*math.tau/vertices),
                            center[1]+radius*math.sin(i*math.tau/vertices), center[2]+z)
                           for i in range(vertices)]
        faces = []
        n = vertices
        for i in range(n):
            j = (i+1)%n
            faces.extend([(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),
                          (2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)])
        return self._surface(points, faces, material)

    def beam(self, a, b, width, material, depth=None):
        a, b = Vector(a), Vector(b)
        vec = b-a
        if vec.length < .00001:
            return self
        matrix = vec.to_track_quat('Z', 'Y').to_matrix()
        return self.box((a+b)/2, (width, depth or width, vec.length), material, matrix)

    def tube(self, points, radius, material, segments=8):
        # A transported frame prevents the 180-degree cross-section flips that
        # occur when a vertical bend switches between arbitrary reference axes.
        cleaned = []
        for point in points:
            point = Vector(point)
            if not cleaned or (point-cleaned[-1]).length > 1e-8:
                cleaned.append(point)
        points = cleaned
        if len(points) < 2 or radius <= 0:
            return self
        if segments < 3:
            raise ValueError('A tube needs at least three radial segments')
        closed = len(points) > 2 and (points[0]-points[-1]).length <= 1e-8
        if closed:
            points.pop()
        if len(points) < (3 if closed else 2):
            return self
        tangents = []
        for i, point in enumerate(points):
            before = points[(i-1) % len(points)] if closed else points[max(0,i-1)]
            after = points[(i+1) % len(points)] if closed else points[min(i+1,len(points)-1)]
            tangent = after-before
            if tangent.length <= 1e-8:
                tangent = after-point if (after-point).length > 1e-8 else point-before
            tangents.append(tangent.normalized())
        ref = Vector((0,0,1)) if abs(tangents[0].z) < .9 else Vector((1,0,0))
        rights = [tangents[0].cross(ref).normalized()]
        lengths = [0.0]
        for i in range(1,len(points)):
            right = tangents[i-1].rotation_difference(tangents[i]) @ rights[-1]
            right -= tangents[i]*right.dot(tangents[i])
            rights.append(right.normalized())
            lengths.append(lengths[-1]+(points[i]-points[i-1]).length)
        if closed:
            # Distribute residual transport twist over the loop, then join the
            # final ring directly to the first: no coincident seam/end caps.
            closing = tangents[-1].rotation_difference(tangents[0]) @ rights[-1]
            twist = math.atan2(tangents[0].dot(closing.cross(rights[0])), closing.dot(rights[0]))
            perimeter = lengths[-1]+(points[-1]-points[0]).length
            for i in range(1,len(points)):
                rights[i] = Matrix.Rotation(twist*lengths[i]/perimeter,3,tangents[i]) @ rights[i]
        vertices, faces = [], []
        for i, p in enumerate(points):
            right = rights[i]
            up = tangents[i].cross(right).normalized()
            for j in range(segments):
                vertices.append(p + radius*(right*math.cos(j*math.tau/segments)+up*math.sin(j*math.tau/segments)))
        if not closed:
            faces.append(tuple(reversed(range(segments))))
        for i in range(len(points) if closed else len(points)-1):
            next_ring = (i+1) % len(points)
            for j in range(segments):
                k = (j+1)%segments
                a,b,c,d = i*segments+j,i*segments+k,next_ring*segments+k,next_ring*segments+j
                # Bent cross sections produce nonplanar quads; explicit
                # triangles retain correct flat normals through GLB export.
                faces.extend(((a,b,c),(a,c,d)))
        if not closed:
            faces.append(tuple(range((len(points)-1)*segments,len(points)*segments)))
        return self._surface(vertices,faces,material)

    def voxels(self, cells, cell, palette):
        sides = [((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),
                 ((-1,0,0),[(0,1,0),(0,0,0),(0,0,1),(0,1,1)]),
                 ((0,1,0),[(1,1,0),(0,1,0),(0,1,1),(1,1,1)]),
                 ((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),
                 ((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]),
                 ((0,0,-1),[(0,1,0),(1,1,0),(1,0,0),(0,0,0)])]
        for key, role in cells.items():
            for normal, corners in sides:
                if tuple(key[a]+normal[a] for a in range(3)) in cells:
                    continue
                coords = [tuple((key[a]+corner[a])*cell for a in range(3)) for corner in corners]
                self._surface(coords, [(0,1,2,3)], palette[role])
        return self

    def finish(self, name=None, parent=None):
        mesh = bpy.data.meshes.new((name or self.name) + ' / mesh')
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        roles = list(dict.fromkeys(self.roles))
        for role in roles:
            mesh.materials.append(MATERIALS[role])
        lookup = {role:i for i,role in enumerate(roles)}
        uv = mesh.uv_layers.new(name='PixelPlatingUV')
        for polygon, role in zip(mesh.polygons, self.roles):
            polygon.material_index = lookup[role]
            polygon.use_smooth = False
            count = len(polygon.loop_indices)
            for i, loop in enumerate(polygon.loop_indices):
                if count == 4:
                    uv.data[loop].uv = ((.015,.015),(.985,.015),(.985,.985),(.015,.985))[i]
                else:
                    uv.data[loop].uv = (.5+.48*math.cos(i*math.tau/count),.5+.48*math.sin(i*math.tau/count))
        obj = bpy.data.objects.new(name or self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        return obj


def root_empty(name, location=(0,0,0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj['asset_authoring'] = 'Original procedural voxel geometry / Blender 5.2.1'
    return obj


def _finish_loop(obj, name):
    action = obj.animation_data.action
    action.name = name + ' / ' + obj.name
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        enum_set(key, 'interpolation', 'LINEAR')
    track = obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    duration = float(action.frame_range[1] - action.frame_range[0])
    if duration > 0 and duration <= 480:
        strip.repeat = 480 / duration
    obj.animation_data.action = None
    return action


def rotation_loop(obj, axis=2, frames=480, degrees=360, name='idle'):
    start = obj.rotation_euler[axis]
    for i in range(5):
        obj.rotation_euler[axis] = start + math.radians(degrees)*i/4
        obj.keyframe_insert(data_path='rotation_euler', frame=1+frames*i/4)
    action = _finish_loop(obj, name)
    obj.rotation_euler[axis] = start
    return action


def oscillate(obj, axis=2, amount=.2, frames=240, name='idle'):
    start = obj.rotation_euler[axis]
    for i, amount_factor in enumerate((0,1,0,-1,0)):
        obj.rotation_euler[axis] = start + amount*amount_factor
        obj.keyframe_insert(data_path='rotation_euler', frame=1+frames*i/4)
    action = _finish_loop(obj, name)
    obj.rotation_euler[axis] = start
    return action
