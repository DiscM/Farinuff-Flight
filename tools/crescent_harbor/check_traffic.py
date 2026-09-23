"""Read-only sampled ship collision audit for the authored Crescent Harbor scene.

Blender --background --factory-startup --python-exit-code 1 \
    --python tools/crescent_harbor/check_traffic.py -- --step 1 --report /tmp/traffic.json

Uses transformed mesh bounds followed by triangle BVH overlap. Nearby ship
vertices and triangle centers are also tested for clearance; containment is
confirmed with three independent signed-crossing rays. The
clearance figure is a sampled surface distance, not a continuous-time swept
volume guarantee. Only a docked ship's own named saddle/pressure berth is an
allowed contact; the remaining station, cables, and other ships are obstacles.
No scene, mesh, animation, or export is saved or changed.
"""

import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import sys
import time

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / 'assets/models/wayfarer_crescent/source/wayfarer_crescent.blend'


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--step', type=int, default=1)
    parser.add_argument('--substeps', type=int, default=1,
                        help='Additional evenly spaced samples within each frame interval')
    parser.add_argument('--start', type=int, default=1)
    parser.add_argument('--end', type=int, default=481)
    parser.add_argument('--clearance', type=float, default=.3)
    parser.add_argument('--ships', nargs='*', help='Optional exact ship-root names')
    return parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])


def bounds(points):
    return tuple(min(p[a] for p in points) for a in range(3)), tuple(max(p[a] for p in points) for a in range(3))


def bounds_distance(a, b):
    return math.sqrt(sum(max(a[0][i] - b[1][i], b[0][i] - a[1][i], 0.) ** 2 for i in range(3)))


def spans(frames, step):
    result = []
    for frame in sorted(set(frames)):
        if result and frame <= result[-1][1] + step:
            result[-1][1] = frame
        else:
            result.append([frame, frame])
    return result


def owner(obj, ship_names):
    while obj:
        if obj.name in ship_names:
            return obj.name, 'ship'
        if obj.name == 'Wayfarer_Core' or obj.get('service_kind'):
            return obj.name, 'station'
        if obj.name.startswith('PowerBundle_') and obj.type == 'EMPTY':
            return obj.name, 'cable'
        obj = obj.parent
    return None, None


def rigid_shared_root(a, b):
    """Return a root when both relative branches have no animated transforms.

    Docked hulls and their static station share one moving root, so repeating
    their exact triangle/containment test at every subframe adds no evidence.
    Only top-level roots with uniform scale qualify for distance reuse.
    """
    ancestors = set()
    current = a
    while current:
        ancestors.add(current)
        current = current.parent
    common = b
    while common and common not in ancestors:
        common = common.parent
    if (common is None or common.parent is not None or common.constraints
            or (common.animation_data and common.animation_data.drivers)
            or max(common.scale)-min(common.scale) > 1e-6):
        return None
    for obj in (a, b):
        while obj != common:
            if obj.constraints or (obj.animation_data and (obj.animation_data.action
                    or obj.animation_data.nla_tracks or obj.animation_data.drivers)):
                return None
            obj = obj.parent
    return common


class Geometry:
    def __init__(self, obj, group, kind):
        self.obj, self.group, self.kind = obj, group, kind
        mesh = obj.data
        if obj.modifiers or mesh.shape_keys:
            raise ValueError('Traffic audit requires rigid source meshes: ' + obj.name)
        mesh.calc_loop_triangles()
        self.vertices = [v.co.copy() for v in mesh.vertices]
        self.triangles = [tuple(t.vertices) for t in mesh.loop_triangles]
        self.corners = [Vector(c) for c in obj.bound_box]
        parents = list(range(len(self.vertices)))
        def find(index):
            while parents[index] != index:
                parents[index] = parents[parents[index]]
                index = parents[index]
            return index
        for triangle in self.triangles:
            root = find(triangle[0])
            for index in triangle[1:]:
                parents[find(index)] = root
        self.face_components = [find(t[0]) for t in self.triangles]
        self.component_probes = {find(t[0]): t[0] for t in self.triangles}


class Pose:
    def __init__(self, geometry, matrix):
        self.geometry, self.matrix = geometry, matrix
        self.bounds = bounds([matrix @ v for v in geometry.corners])
        self._vertices = self._bvh = None

    @property
    def vertices(self):
        if self._vertices is None:
            self._vertices = [self.matrix @ v for v in self.geometry.vertices]
        return self._vertices

    @property
    def bvh(self):
        if self._bvh is None:
            self._bvh = BVHTree.FromPolygons(self.vertices, self.geometry.triangles, all_triangles=True, epsilon=1e-6)
        return self._bvh

    def probes(self):
        # Exact unique vertices plus centers cover small fixtures as well as
        # coarse hull panels. They supplement triangle intersections only.
        seen = set()
        for point in self.vertices:
            key = tuple(round(v, 6) for v in point)
            if key not in seen:
                seen.add(key)
                yield point
        for tri in self.geometry.triangles:
            yield sum((self.vertices[i] for i in tri), Vector()) / 3


def contact(a, b, clearance):
    pairs = a.bvh.overlap(b.bvh) if bounds_distance(a.bounds, b.bounds) <= 1e-6 else []
    result = {'triangle_pairs': len(pairs), 'minimum_sampled_clearance': None,
              'inside_probes': 0, 'obstacle_inside_ship_probes': 0}
    witness = None
    if pairs:
        ia, ib = pairs[0]
        pa = [a.vertices[i] for i in a.geometry.triangles[ia]]
        pb = [b.vertices[i] for i in b.geometry.triangles[ib]]
        ba, bb = bounds(pa), bounds(pb)
        witness = [(max(ba[0][i], bb[0][i]) + min(ba[1][i], bb[1][i])) / 2 for i in range(3)]
        return {**result, 'collision': True, 'witness_xyz': witness, 'minimum_sampled_clearance': 0.0}
    # Measure clearance on the small ship, never every vertex of a station.
    for point in a.probes():
        if any(point[i] < b.bounds[0][i] - clearance or point[i] > b.bounds[1][i] + clearance for i in range(3)):
            continue
        nearest, normal, face, distance = b.bvh.find_nearest(point)
        if nearest is None:
            continue
        if result['minimum_sampled_clearance'] is None or distance < result['minimum_sampled_clearance']:
            result['minimum_sampled_clearance'] = distance
    # Without any triangle crossing, each connected surface component is
    # entirely inside or outside. One vertex per component is sufficient, and
    # an unrelated nested shell's nearest normal must not veto containment.
    for index in a.geometry.component_probes.values():
        point = a.vertices[index]
        if any(point[i] <= b.bounds[0][i] or point[i] >= b.bounds[1][i] for i in range(3)):
            continue
        nearest, normal, face, distance = b.bvh.find_nearest(point)
        if distance > 1e-4 and contained(point, b):
            result['inside_probes'] += 1
            return {**result, 'collision': True, 'witness_xyz': list(point)}
    # A small fixture can be entirely inside a large carrier without crossing
    # either surface. Query nearby obstacle triangles instead of walking every
    # vertex of a large station to check the reverse containment direction.
    center = (Vector(a.bounds[0]) + Vector(a.bounds[1])) / 2
    radius = (Vector(a.bounds[1]) - center).length + 1e-4
    nearby = {hit[2] for hit in b.bvh.find_nearest_range(center, radius)}
    components = {b.geometry.face_components[face] for face in nearby}
    vertex_ids = {b.geometry.component_probes[component] for component in components}
    for i in vertex_ids:
        point = b.vertices[i]
        if any(point[axis] <= a.bounds[0][axis] or point[axis] >= a.bounds[1][axis] for axis in range(3)):
            continue
        nearest, normal, face, distance = a.bvh.find_nearest(point)
        if distance > 1e-4 and contained(point, a):
            result['obstacle_inside_ship_probes'] += 1
            return {**result, 'collision': True, 'witness_xyz': list(point)}
    result['collision'] = bool(pairs or result['inside_probes'] or result['obstacle_inside_ship_probes'])
    result['witness_xyz'] = witness
    return result


def contained(point, pose):
    """Test the union of outward-oriented primitives using signed crossings.

    Odd/even parity would incorrectly cancel overlapping closed primitives.
    Preserve separate component contributions at coincident boundaries while
    deduplicating the triangles of one shell. Opposite internal faces cancel.
    Three non-axis-aligned rays guard against numerical shared-edge hits.
    """
    votes = 0
    directions = ((.8161, .4313, .3847), (-.3721, .8573, .3569), (.2939, -.4271, .8551))
    for values in directions:
        direction = Vector(values).normalized()
        origin, winding = point.copy(), 0
        for _ in range(256):
            location, normal, face, distance = pose.bvh.ray_cast(origin, direction)
            if location is None:
                break
            crossings = set()
            for hit in pose.bvh.find_nearest_range(location, 2e-5):
                face_index = hit[2]
                triangle = pose.geometry.triangles[face_index]
                p, q, r = (pose.vertices[i] for i in triangle)
                dot = (q-p).cross(r-p).dot(direction)
                if abs(dot) > 1e-12:
                    crossings.add((pose.geometry.face_components[face_index], 1 if dot > 0 else -1))
            winding += sum(sign for component, sign in crossings)
            origin = location + direction * 1e-4
        else:
            raise RuntimeError('Containment ray exceeded 256 crossings: ' + pose.geometry.obj.name)
        votes += winding > 0
    return votes >= 2


def main():
    opts = arguments()
    if opts.step < 1 or opts.substeps < 1 or opts.end < opts.start or opts.clearance < 0:
        raise ValueError('Invalid sampling interval or clearance')
    started = time.monotonic()
    source_digest = hashlib.sha256(opts.source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(opts.source.resolve()))
    scene = bpy.context.scene
    ships = {o.name: o for o in scene.objects if o.get('asset_kind') in ('courier','podcarrier','tug','drone')}
    if not ships:
        raise ValueError('No fleet roots in source scene')
    selected = set(opts.ships or ships)
    if not selected <= ships.keys():
        raise ValueError('Unknown selected ship root')
    geometry = []
    for obj in scene.objects:
        group, kind = owner(obj, ships)
        if group and obj.type == 'MESH':
            geometry.append(Geometry(obj, group, kind))
    interval = opts.step / opts.substeps
    frames = sorted({round(opts.start + i * interval, 6)
                     for i in range(math.floor((opts.end-opts.start) / interval) + 1)} | {opts.end})
    events, near, allowed = {}, {}, defaultdict(list)
    rigid_pairs, contact_cache = {}, {}
    candidates = narrow = 0
    for n, frame in enumerate(frames):
        scene.frame_set(math.floor(frame), subframe=frame-math.floor(frame))
        bpy.context.view_layer.update()
        dep = bpy.context.evaluated_depsgraph_get()
        poses = [Pose(g, g.obj.evaluated_get(dep).matrix_world.copy()) for g in geometry]
        ship_poses = [p for p in poses if p.geometry.kind == 'ship' and p.geometry.group in selected]
        for a in ship_poses:
            ship = a.geometry.group
            for b in poses:
                if a.geometry.group == b.geometry.group:
                    continue
                if b.geometry.kind == 'ship' and b.geometry.group in selected and a.geometry.group > b.geometry.group:
                    continue
                candidates += 1
                if bounds_distance(a.bounds, b.bounds) > opts.clearance:
                    continue
                narrow += 1
                key = (ship, a.geometry.obj.name, b.geometry.obj.name)
                if key not in rigid_pairs:
                    rigid_pairs[key] = rigid_shared_root(a.geometry.obj, b.geometry.obj)
                shared = rigid_pairs[key]
                scale = tuple(shared.scale[i] * shared.delta_scale[i] for i in range(3)) if shared else None
                cached = contact_cache.get(key)
                if shared and cached and cached[0] == scale:
                    c = cached[1]
                else:
                    c = contact(a, b, opts.clearance)
                    if shared:
                        contact_cache[key] = (scale, c)
                intentional = (b.geometry.obj.name in (ship + ' / connected pressure berth', ship + ' / locking saddles')
                               and ships[ship].get('docked_to') == b.geometry.group)
                if c['collision'] and intentional:
                    allowed[' / '.join(key)].append(frame)
                    continue
                if c['collision']:
                    position = ships[ship].evaluated_get(dep).matrix_world.translation
                    if key not in events:
                        print('TRAFFIC_CONTACT ' + json.dumps({'frame': frame, 'ship': ship,
                              'ship_mesh': a.geometry.obj.name, 'obstacle': b.geometry.obj.name,
                              'triangle_pairs': c['triangle_pairs'], 'witness_xyz': c['witness_xyz']}), flush=True)
                    event = events.setdefault(key, {'ship': ship, 'ship_mesh': a.geometry.obj.name,
                        'obstacle': b.geometry.obj.name, 'obstacle_group': b.geometry.group,
                        'obstacle_kind': b.geometry.kind, 'frames': [], 'max_triangle_pairs': 0,
                        'max_inside_probes': 0, 'max_obstacle_inside_ship_probes': 0,
                        'first_witness_xyz': c['witness_xyz'],
                        'first_witness_obstacle_local_xyz': list(b.matrix.inverted() @ Vector(c['witness_xyz'])),
                        'first_ship_position_xyz': list(position),
                        'first_ship_planar_uvz': [.8 * position.x + .6 * position.y,
                                                 -.6 * position.x + .8 * position.y, position.z]})
                    event['frames'].append(frame)
                    event['max_triangle_pairs'] = max(event['max_triangle_pairs'], c['triangle_pairs'])
                    event['max_inside_probes'] = max(event['max_inside_probes'], c['inside_probes'])
                    event['max_obstacle_inside_ship_probes'] = max(event['max_obstacle_inside_ship_probes'], c['obstacle_inside_ship_probes'])
                elif c['minimum_sampled_clearance'] is not None and c['minimum_sampled_clearance'] < opts.clearance:
                    finding = near.setdefault(key, {'ship': ship, 'ship_mesh': a.geometry.obj.name,
                        'obstacle': b.geometry.obj.name, 'obstacle_group': b.geometry.group,
                        'frames': [], 'minimum_sampled_clearance': math.inf})
                    finding['frames'].append(frame)
                    finding['minimum_sampled_clearance'] = min(finding['minimum_sampled_clearance'], c['minimum_sampled_clearance'])
        if n % 24 == 0:
            print('TRAFFIC_PROGRESS ' + json.dumps({'frame': frame, 'sample': n+1, 'total': len(frames),
                                                   'collision_pairs': len(events), 'seconds': round(time.monotonic()-started, 2)}), flush=True)
    for collection in (events, near):
        for result in collection.values():
            result['frame_spans'] = spans(result.pop('frames'), interval)
    report = {'schema_version': 1, 'source': str(opts.source.resolve()),
        'source_sha256': source_digest,
        'evidence': 'Sampled rigid source geometry: AABB broad phase, triangle BVH overlap, union containment confirmed by three signed-crossing rays; not continuous swept collision.',
        'sample_frames': frames, 'sample_interval_frames': interval,
        'fps': scene.render.fps, 'clearance_threshold': opts.clearance,
        'ships': [{'name': name, 'flight_state': ships[name].get('flight_state'),
                   'docked_to': ships[name].get('docked_to')} for name in sorted(selected)],
        'mesh_count': len(geometry), 'broadphase_pairs': candidates, 'narrowphase_pairs': narrow,
        'invariant_shared_root_pairs': len(contact_cache),
        'collisions': list(events.values()), 'near_clearances': list(near.values()),
        'allowed_berth_contacts': [{'pair': key, 'frame_spans': spans(value, interval)} for key, value in allowed.items()],
        'passed': not events, 'seconds': round(time.monotonic()-started, 2)}
    if opts.report:
        opts.report.parent.mkdir(parents=True, exist_ok=True)
        opts.report.write_text(json.dumps(report, indent=2) + '\n')
    print('TRAFFIC_RESULT ' + json.dumps(report), flush=True)
    if events:
        raise RuntimeError('Ship collision audit found %d intersecting mesh pairs' % len(events))


if __name__ == '__main__':
    main()
