"""Portable rigid animation: station keeping, mounted lights and flexible tethers.

All moving parts use baked transforms, so the same motion survives GLB export.
The cable spans are short articulated sleeves; their sockets stay on the hulls.
"""
import math

import bpy
from mathutils import Matrix, Vector

from .geometry import MeshBuilder, root_empty, rotation_loop, _finish_loop, enum_set

FRAMES = tuple(range(1, 482, 8))
PERIOD = 480


def station_keeping(stations):
    for index, station in enumerate(stations):
        location = station.location.copy()
        angles = station.rotation_euler.copy()
        station['rest_location'] = list(location)
        station['rest_rotation'] = list(angles)
        station['animation_role'] = 'Slow station-keeping translation and attitude correction'
        phase = index * .79
        amplitude = .24 if index == 0 else .55
        for frame in FRAMES:
            t = math.tau * (frame - 1) / PERIOD
            station.location = location + Vector((
                amplitude * (math.sin(t + phase) - math.sin(phase)),
                amplitude * .55 * (math.sin(t - phase) + math.sin(phase)),
                amplitude * .4 * (1 - math.cos(t))))
            station.rotation_euler = angles.copy()
            station.rotation_euler.z += math.radians(.18 if index == 0 else .55) * (math.sin(t + phase) - math.sin(phase))
            station.rotation_euler.x += math.radians(.10) * math.sin(t)
            station.keyframe_insert(data_path='location', frame=frame)
            station.keyframe_insert(data_path='rotation_euler', frame=frame)
        _finish_loop(station, 'orbital_correction')
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def _pulse(obj, phase, cycles=5, jet=False):
    for frame in range(1, 482, 4):
        t = math.tau * cycles * (frame - 1) / PERIOD + phase
        power = (.5 + .5 * math.cos(t)) ** (5 if jet else 8)
        if jet:
            obj.scale = (.65 + power * .35, .65 + power * .35, .025 + power * 1.75)
        else:
            # The lens contracts into its dark socket between flashes. This
            # preserves pulsing light in engines without material animation.
            size = .12 + power * .88
            obj.scale = (size, size, size)
        obj.keyframe_insert(data_path='scale', frame=frame)
    _finish_loop(obj, 'correction_thrusters' if jet else 'navigation_lights')


def _beacon(root, position, name, phase, role='red'):
    mount = root_empty(name + ' / fixture', position)
    mount.parent = root
    body = MeshBuilder(name + ' / bolted lamp housing')
    body.box((0, 0, .06), (.44, .44, .16), 'navy')
    body.cylinder((0, 0, .28), .10, .42, 'steel', vertices=8)
    body.cylinder((0, 0, .51), .23, .14, 'black', vertices=8)
    body.cylinder((0, 0, .74), .23, .08, 'ivory', vertices=8)
    for x in (-.17, .17):
        body.beam((x, 0, .48), (x, 0, .76), .04, 'steel')
    body.finish(parent=mount)
    lens = MeshBuilder(name + ' / flashing lens')
    lens.cylinder((0, 0, 0), .18, .16, role, vertices=8)
    obj = lens.finish(parent=mount)
    obj.location.z = .62
    obj['animation_role'] = 'Mounted emissive navigation lamp'
    _pulse(obj, phase)


def _jet(root, position, name, phase, nozzle=True):
    mount = root_empty(name + ' / RCS socket', position)
    mount.parent = root
    if nozzle:
        body = MeshBuilder(name + ' / thrust housing')
        body.box((0, 0, .62), (.78, .78, 1.3), 'navy')
        body.ring((0, 0, .08), .40, .24, .24, 'copper', vertices=8)
        body.finish(parent=mount)
    plume = MeshBuilder(name + ' / correction exhaust')
    plume.cylinder((0, 0, -.18), .15, .40, 'cyan', vertices=8)
    plume.cylinder((0, 0, -.46), .075, .25, 'cyan', vertices=8)
    obj = plume.finish(parent=mount)
    obj['animation_role'] = 'Short station-keeping thruster bursts'
    _pulse(obj, phase, cycles=2, jet=True)


def _fan(root, position, name):
    mount = root_empty(name + ' / housing', position)
    mount.parent = root
    body = MeshBuilder(name + ' / fixed grille rim')
    body.box((0, 0, .17), (1.9, 1.9, .34), 'navy')
    body.ring((0, 0, .43), .90, .73, .40, 'ivory', vertices=12)
    body.cylinder((0, 0, .32), .25, .32, 'steel', vertices=12)
    body.finish(parent=mount)
    rotor = root_empty(name + ' / rotor', (0, 0, .46))
    rotor.parent = mount
    blades = MeshBuilder(name + ' / blades')
    blades.cylinder((0, 0, 0), .24, .16, 'copper', vertices=12)
    for n in range(4):
        angle = math.tau * n / 4
        blades.box((math.cos(angle) * .44, math.sin(angle) * .44, 0), (.65, .16, .12), 'steel', rotation=angle)
    blades.finish(parent=rotor)
    rotation_loop(rotor, frames=240, name='cooling_rotors')


def service_animation(stations):
    core = stations[0]
    for i in range(8):
        a = i * math.tau / 8 + math.pi / 8
        x, y = round(math.cos(a) * 42) / 2, round(math.sin(a) * 42) / 2
        _beacon(core, (x + 2, y, 9.48), 'Core navigation ' + str(i + 1), i * .6, 'red' if i % 2 else 'cyan')
    for i, (x, y) in enumerate(((23, 0), (0, 23), (-23, 0), (0, -23))):
        _jet(core, (x, y, 2.79), 'Core RCS ' + str(i + 1), i * math.pi / 2)
    sizes = [(10, 10), (20, 16), (28, 19), (12, 12), (24, 21)]
    for index, (station, (w, d)) in enumerate(zip(stations[1:], sizes)):
        for n, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
            # Inboard rim is free of the existing corner landing lamps.
            _beacon(station, (sx * (w / 2 - .9), sy * (d / 2 - .9), 3.98),
                    station.name + ' navigation ' + str(n + 1), index * .7 + n * .6,
                    'red' if n % 2 else 'cyan')
            _jet(station, (sx * (w / 2 - 2), sy * (d / 2 - 2), -2.21),
                 station.name + ' RCS ' + str(n + 1), index * .7 + n * math.pi / 2, nozzle=False)
    _fan(stations[2], (-2.8, -5.5, 4.04), 'Power / coolant pump')
    _fan(stations[5], (-9.8, 3.9, 4.04), 'Service / coolant pump')


def flexible_bundle(name, station_a, local_a, station_b, local_b, segments=24):
    """Articulated rigid sleeves preserve all four cable paths during correction."""
    root = root_empty(name)
    root['role'] = 'Four-strand armored power umbilical with hull-mounted sockets'
    root['station_a'] = station_a.name
    root['station_b'] = station_b.name
    root['local_a'] = list(local_a)
    root['local_b'] = list(local_b)
    root['segments'] = segments
    starts = station_a.matrix_world @ local_a
    ends = station_b.matrix_world @ local_b
    root['start'], root['end'] = list(starts), list(ends)
    sockets = []
    for station, local, other, tag in ((station_a, local_a, ends, 'A'), (station_b, local_b, starts, 'B')):
        point = station.matrix_world @ local
        across = Vector((-(other - point).y, (other - point).x, 0)).normalized()
        across_local = station.matrix_world.to_3x3().inverted() @ across
        angle = math.atan2(across_local.y, across_local.x)
        socket = MeshBuilder(name + ' / socket ' + tag)
        socket.box((0, 0, 0), (4.5, 1.6, 1.55), 'navy')
        socket.box((0, 0, .83), (4.65, 1.7, .18), 'ivory')
        socket.box((0, 0, -.83), (4.65, 1.7, .18), 'steel')
        obj = socket.finish(parent=root)
        obj['anchor_station'] = station.name
        obj['anchor_local'] = list(local)
        sockets.append((obj, station, local, angle))
    sleeves = []
    for n in range(segments):
        mesh = MeshBuilder(name + ' / sleeve %02d' % (n + 1))
        for strand in range(4):
            x = (strand - 1.5) * .96
            mesh.cylinder((x, 0, 0), .40, 1, 'black', vertices=8)
            mesh.cylinder((x, 0, 0), .435, .13, 'copper' if n % 6 == 0 else 'steel', vertices=8)
        obj = mesh.finish(parent=root)
        enum_set(obj, 'rotation_mode', 'QUATERNION')
        obj['cable_segment'] = n
        sleeves.append(obj)
    for frame in FRAMES:
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        a, b = station_a.matrix_world @ local_a, station_b.matrix_world @ local_b
        across = Vector((-(b - a).y, (b - a).x, 0)).normalized()
        points = []
        for n in range(segments + 1):
            t = n / segments
            p = a.lerp(b, t) + across * (math.sin(t * math.pi) * 1.1)
            p.z -= math.sin(t * math.pi) * 2.85
            points.append(p)
        for n, obj in enumerate(sleeves):
            p, q = points[n:n + 2]
            tangent = (q - p).normalized()
            right = Vector((-tangent.y, tangent.x, 0)).normalized()
            up = tangent.cross(right).normalized()
            rotation = Matrix((right, up, tangent)).transposed()
            obj.location = (p + q) / 2
            quaternion = rotation.to_quaternion()
            if frame > 1 and obj.rotation_quaternion.dot(quaternion) < 0:
                quaternion.negate()
            obj.rotation_quaternion = quaternion
            # Overlapping sleeve ends prevent hairline cracks on bends.
            obj.scale = (1, 1, (q - p).length + .13)
            for path in ('location', 'rotation_quaternion', 'scale'):
                obj.keyframe_insert(data_path=path, frame=frame)
        for obj, station, local, angle in sockets:
            obj.location = station.matrix_world @ local
            obj.rotation_euler = (station.matrix_world.to_quaternion() @
                                  Matrix.Rotation(angle, 3, 'Z').to_quaternion()).to_euler()
            for path in ('location', 'rotation_euler'):
                obj.keyframe_insert(data_path=path, frame=frame)
    for obj in sleeves + [entry[0] for entry in sockets]:
        _finish_loop(obj, 'orbital_correction')
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    return root


def attach_docked_ship(ship, station):
    world = ship.matrix_world.copy()
    ship.parent = station
    ship.matrix_parent_inverse = Matrix.Identity(4)
    ship.matrix_basis = station.matrix_world.inverted() @ world
    bpy.context.view_layer.update()
    ship['docked_to'] = station.name
    ship['docked_local_matrix'] = [v for row in ship.matrix_local for v in row]


def berth_connections(stations, fleet):
    """Continuous pressure couplers and hull-contact saddles for parked craft."""
    for ship, station in ((fleet[0], stations[3]), (fleet[1], stations[5]),
                          (fleet[2], stations[0]), (fleet[3], stations[2]),
                          (fleet[13], stations[5])):
        attach_docked_ship(ship, station)
    for ship, station, nose, edge in (
        (fleet[0], stations[3], (0, -5.25, 0), -9.5),
        (fleet[1], stations[5], (0, -5.25, 0), -10.5),
        (fleet[3], stations[2], (0, -.93, 0), -8),
    ):
        collar = station.matrix_world.inverted() @ ship.matrix_world @ Vector(nose)
        root = Vector((collar.x, edge + .25, 3.3))
        elbow = Vector((collar.x, edge + .25, collar.z))
        hardware = MeshBuilder(ship.name + ' / connected pressure berth')
        hardware.box(root, (1.8, 1.1, 1.1), 'navy')
        hardware.beam(root, elbow, .86, 'ivory')
        hardware.tube([elbow, collar], .43, 'steel', segments=12)
        direction = (collar - elbow).normalized()
        hardware.tube([collar - direction * .2, collar + direction * .08], .61, 'copper', segments=12)
        for offset in (-.75, .75):
            hardware.beam(root + Vector((offset, 0, 0)), collar + Vector((offset, 0, -.22)), .17, 'navy')
        hardware.finish(parent=station)
    # Clamp shoes meet the courier nacelles; every strut starts in the apron.
    for ship, station, deck_z in ((fleet[2], stations[0], 5.50), (fleet[13], stations[5], 4.03)):
        hardware = MeshBuilder(ship.name + ' / locking saddles')
        inv = station.matrix_world.inverted()
        for x in (-.96, .96):
            for y in (-.4, .65):
                contact = inv @ ship.matrix_world @ Vector((x, y, -.38))
                base = Vector((contact.x, contact.y, deck_z))
                hardware.box(base + Vector((0, 0, .08)), (.65, .65, .22), 'navy')
                hardware.beam(base, contact, .27, 'steel')
                hardware.box(contact, (.48, .46, .16), 'copper')
        hardware.finish(parent=station)
