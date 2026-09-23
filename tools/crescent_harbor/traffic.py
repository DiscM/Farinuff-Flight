"""Through traffic with visible approach lanes and genuinely offscreen returns."""
import bisect
import math

from mathutils import Vector

from .geometry import _finish_loop, enum_set


# Planar u points right in the overview; v runs towards the relay crescent.
# Routes keep swept hulls clear of the main ring, island equipment and tethers.
ROUTES = {
    'Ship_05_ArrivingCarrier': (
        [(-110,-100,12),(-73,-85,12),(-26,-67,12),(18,-53,13),
         (31,-30,14),(31,1,14),(40,18,16),(81,55,23),(116,85,24)], .12, 'top'),
    'Ship_06_PassengerArrival': (
        [(116,42,20),(90,40,20),(45,30,20),(21,13,20),(19,-20,20),
         (9,-51,18),(-47,-76,16),(-110,-96,16)], .42, 'bottom'),
    'Ship_07_DepartingCourier': (
        [(-110,8,24),(-69,11,24),(-33,20,23),(3,27,23),(31,18,24),
         (39,-10,24),(91,-48,21),(116,-70,21)], .20, 'bottom'),
    'Ship_08_CargoTug': (
        [(-110,43,23),(-62,46,23),(-20,48,23),(32,48,23),
         (78,45,23),(116,31,23)], .48, 'top'),
    'Ship_09_RelayTransfer': (
        [(116,-12,19),(88,6,19),(50,9,19),(25,17,19),(-5,30,20),
         (-54,37,23),(-110,45,23)], .31, 'top'),
    'Ship_10_CableInspector': (
        [(-110,21,24),(-70,25,24),(-45,24,24),(-25,35,26),(10,32,25),
         (41,25,24),(85,10,24),(116,-5,24)], .06, 'top'),
    'Ship_11_RepairDrone': (
        [(116,-68,12),(95,-46,14),(85,-22,15),(86,8,18),(62,13,18),
         (36,-5,17),(22,-44,16),(-26,-69,14),(-110,-96,14)], .24, 'bottom'),
    'Ship_12_StationMaintenance': (
        [(-110,-71,18),(-79,-58,19),(-67,-25,20),(-60,10,21),
         (-39,22,21),(-3,24,21),(36,16,20),(84,-9,19),(116,-31,18)], .17, 'top'),
    'Ship_13_PracticeCourier': (
        [(116,61,26),(87,18,24),(43,-19,23),(12,-54,22),
         (-28,-70,22),(-73,-62,23),(-110,-36,23)], .39, 'bottom'),
}


def planar(point):
    u, v, z = point
    return Vector((u * .8 - v * .6, u * .6 + v * .8, z))


def _catmull(p0, p1, p2, p3, t):
    # Clamped tangents prevent a long hidden-return leg bowing into the port.
    length = (p2 - p1).length
    a, b = (p2 - p0) * .5, (p3 - p1) * .5
    if a.length > length * .65:
        a *= length * .65 / a.length
    if b.length > length * .65:
        b *= length * .65 / b.length
    return ((2*t**3-3*t*t+1)*p1 + (t**3-2*t*t+t)*a +
            (-2*t**3+3*t*t)*p2 + (t**3-t*t)*b)


def _path(visible, side, lane=0):
    first, last = visible[0], visible[-1]
    # Travel along a wide rectangle outside the saved camera before re-entering.
    # Both speed changes and all return turns happen beyond the frame margins.
    outer = 145 + lane * 5
    first_u, last_u = (-outer if first[0] < 0 else outer), (-outer if last[0] < 0 else outer)
    hidden_z = 30 + lane * 5
    q = 100 if side == 'top' else -90
    hidden_v = (q - .8115344 * hidden_z) / .5843046
    points = visible + [(last_u, last[1], hidden_z), (last_u, hidden_v, hidden_z),
                        (first_u, hidden_v, hidden_z), (first_u, first[1], hidden_z)]
    points = [planar(p) for p in points]
    samples, distances = [], [0.0]
    for i in range(len(points)):
        for j in range(64):
            t = j / 64
            point = _catmull(points[(i-1) % len(points)], points[i],
                             points[(i+1) % len(points)], points[(i+2) % len(points)], t)
            if samples:
                # Hidden transit is quicker, keeping most of the loop devoted
                # to the visible approach/departure rather than empty screen.
                weight = 1.0 if i < len(visible)-1 else .12
                distances.append(distances[-1] + (point - samples[-1]).length * weight)
            samples.append(point)
    distances.append(distances[-1] + (samples[0]-samples[-1]).length * .12)
    samples.append(samples[0].copy())
    return samples, distances


def _sample(samples, distances, fraction):
    distance = (fraction % 1) * distances[-1]
    i = min(len(samples)-2, max(0, bisect.bisect_right(distances, distance)-1))
    length = distances[i+1] - distances[i]
    return samples[i].lerp(samples[i+1], (distance-distances[i])/length if length else 0)


def through_traffic(ship):
    visible, phase, side = ROUTES[ship.name]
    lane = int(ship.name.split('_')[1]) - 5
    samples, distances = _path(visible, side, lane)
    ship['flight_state'] = 'through traffic'
    ship['animation_role'] = 'Approach, port flyby and departure; return turns outside overview'
    ship['route_waypoints_uvz'] = [value for point in visible for value in point]
    ship['route_return_side'] = side
    ship['route_phase'] = phase
    ship['route_return_lane'] = lane
    enum_set(ship, 'rotation_mode', 'QUATERNION')
    previous = None
    for frame in range(1, 482, 2):
        fraction = phase + (frame-1)/480
        ship.location = _sample(samples, distances, fraction)
        forward = _sample(samples, distances, fraction+.0001) - _sample(samples, distances, fraction-.0001)
        orientation = forward.normalized().to_track_quat('-Y', 'Z')
        if previous is not None and previous.dot(orientation) < 0:
            orientation.negate()
        ship.rotation_quaternion = orientation
        previous = orientation.copy()
        ship.keyframe_insert(data_path='location', frame=frame)
        ship.keyframe_insert(data_path='rotation_quaternion', frame=frame)
    _finish_loop(ship, 'harbor_traffic')
