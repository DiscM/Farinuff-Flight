"""Original editable voxel service islands for Wayfarer's crescent harbour.

All geometry is modelled locally with Z up. Deck top is Z=4; callers place and
rotate each returned root. Static details are batched while moving mechanisms
remain named, parented objects. No assets or textures are downloaded.
"""

from math import cos, sin, pi

try:
    from .geometry import MeshBuilder, root_empty, rotation_loop, oscillate
except ImportError:
    from geometry import MeshBuilder, root_empty, rotation_loop, oscillate


def _grid_window(b, center, width, height, axis="y", color="amber", rows=3):
    """Recessed luminous pane array, dark backing, and chunky edge mullions."""
    x, y, z = center
    count = max(2, int(width / 0.55))
    if axis == "y":
        # The backing embeds into the wall; panes sit on its exposed face.
        b.box((x, y, z), (width + .36, .34, height + .3), "black")
        for column in range(count):
            for row in range(rows):
                b.box((x - width / 2 + (column + .5) * width / count,
                       y - .19, z - height / 2 + (row + .5) * height / rows),
                      (width / count * .65, .07, height / rows * .58), color)
        b.box((x, y - .08, z + height / 2 + .2), (width + .52, .42, .22), "ivory")
        b.box((x, y - .08, z - height / 2 - .2), (width + .52, .4, .22), "copper")
    else:
        b.box((x, y, z), (.34, width + .36, height + .3), "black")
        for column in range(count):
            for row in range(rows):
                b.box((x + .19, y - width / 2 + (column + .5) * width / count,
                       z - height / 2 + (row + .5) * height / rows),
                      (.07, width / count * .65, height / rows * .58), color)
        b.box((x + .08, y, z + height / 2 + .2), (.42, width + .52, .22), "ivory")
        b.box((x + .08, y, z - height / 2 - .2), (.4, width + .52, .22), "copper")


def _vent(b, x, y, z, w=2, d=1.2, vertical=False):
    b.box((x, y, z), (w + .25, d + .25, .3), "black")
    count = max(3, int(w / .33))
    for i in range(count):
        b.box((x - w / 2 + (i + .5) * w / count, y, z + .23),
              (.14, d, .2 if not vertical else .48), "steel")


def _mast(b, x, y, z, height=3, color="red"):
    b.box((x, y, z + .23), (.8, .8, .7), "armor")
    b.cylinder((x, y, z + height / 2), .105, height, "steel", vertices=8)
    b.box((x, y, z + height - .15), (.26, .26, .45), color)
    b.box((x, y, z + height - .47), (.36, .36, .12), "black")


def _pipe(b, points, radius=.22, color="copper", collars=True):
    b.tube(points, radius, color, segments=8)
    if collars:
        for p in (points[0], points[-1]):
            b.box(p, (radius * 3.2, radius * 3.2, radius * 3.2), "steel")


def _deck(b, w, d):
    """Stepped pressure hull, armoured rim, ribs, thrusters and live service edge."""
    b.box((0, 0, .2), (w - 3.2, d - 3.2, 3.4), "navy")
    b.box((0, 0, 1.5), (w - 1.2, d - 3.6, 2.2), "steel")
    b.box((0, 0, 2.7), (w - 1.6, d, 1.8), "ivory")
    b.box((0, 0, 2.7), (w, d - 1.6, 1.8), "ivory")
    b.box((0, 0, 3.75), (w - 1.2, d - 1.2, .5), "armor")
    b.box((0, 0, 3.94), (w - 3.2, d - 3.2, .16), "steel")

    # Alternating deck panels stay shallow enough to preserve a useful surface.
    for ix in range(int((w - 3) / 2)):
        for iy in range(int((d - 3) / 2)):
            x = -w / 2 + 2.5 + ix * 2
            y = -d / 2 + 2.5 + iy * 2
            b.box((x, y, 4.025), (1.92, 1.92, .07),
                  "armor" if (ix + iy) % 5 else "ivory")

    # Repeating bulkhead segments produce a hand assembled voxel silhouette.
    for x in range(-int(w / 2) + 2, int(w / 2) - 1, 3):
        for sy in (-1, 1):
            y = sy * (d / 2 - .12)
            b.box((x, y, 2.5), (2.1, .34, 1.6), "ivory")
            b.box((x, y + sy * .22, 2.4), (.38, .16, .32), "steel")
            b.box((x, y + sy * .23, 3.1), (.18, .16, .18), "black")
            b.box((x, sy * (d / 2 - 1), .05), (.5, .55, 3.9), "steel")
            b.box((x, sy * (d / 2 - 1.02), -1.85), (.8, .8, .4), "armor")
    for y in range(-int(d / 2) + 2, int(d / 2) - 1, 3):
        for sx in (-1, 1):
            b.box((sx * (w / 2 - 1), y, .05), (.55, .5, 3.9), "steel")
            b.box((sx * (w / 2 - .06), y, 2.5), (.3, 2.1, 1.65), "ivory")
            b.box((sx * (w / 2 + .1), y, 2.4), (.14, .4, .3), "black")

    # Warm windows and underslung machinery give the outer edge a lived-in scale.
    for x in (-w * .25, w * .2):
        _grid_window(b, (x, -d / 2 - .15, 2), min(2.8, w * .2), 1.2, rows=3)
    _grid_window(b, (w / 2 + .12, d * .16, 2), min(2.8, d * .22), 1.3, axis="x")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 2), sy * (d / 2 - 2)
            b.box((x, y, -1.2), (1.5, 1.5, 1.7), "armor")
            b.ring((x, y, -2.03), .61, .38, .27, "copper", vertices=8)
            b.cylinder((x, y, -2.13), .36, .17, "cyan", vertices=8)
            b.box((x, y, 4.17), (.7, .7, .42), "black")
            b.box((x, y, 4.42), (.45, .45, .15), "amber")
    # Heavy side receptacles accept the independent multi-cable network.
    for sx in (-1, 1):
        for y in (-2, 2):
            b.box((sx * (w / 2 - .08), y, 1.8), (.7, 1.25, 1.45), "black")
            b.box((sx * (w / 2 + .3), y, 1.8), (.55, .95, 1.12), "copper")
            b.box((sx * (w / 2 + .62), y, 1.8), (.2, .66, .72), "steel")

    # Bolted rim and short equipment rails, not terrestrial pedestrian fences.
    for x in range(-int(w / 2) + 2, int(w / 2) - 1, 2):
        for sy in (-1, 1):
            b.box((x, sy * (d / 2 - .5), 3.95), (.26, .26, .18), "black")
    for x in (-w / 2 + 1.7, w / 2 - 1.7):
        b.box((x, d / 2 - 1.4, 4.15), (1.2, .35, .4), "copper")


def _electronics(b, x, y, z, w=2.2, d=1.6, h=1.5):
    b.box((x, y, z - .05), (w + .16, d + .16, .2), "black")
    b.box((x, y, z + h / 2), (w, d, h), "ivory")
    b.box((x, y - d / 2 - .04, z + h / 2), (w * .78, .1, h * .64), "navy")
    for i in range(3):
        b.box((x - w * .27 + i * w * .27, y - d / 2 - .11, z + h * .68),
              (w * .16, .05, .15), "cyan" if i < 2 else "amber")
    _vent(b, x, y, z + h + .08, w * .65, d * .63)


def _dish(root, location, name, size=1.6):
    # Only the antenna head scans. Its fixed pedestal remains bolted to the deck.
    x, y, z = location
    head_z = z + .78
    support = MeshBuilder(name + "_fixed_pedestal")
    support.box((x, y, 4.12), (1.1, 1.1, .34), "armor")
    support.cylinder((x, y, (4.2 + head_z) / 2), .3,
                     head_z - 4.2 + .08, "steel", vertices=8)
    support.ring((x, y, head_z - .16), .45, .27, .2, "copper", vertices=12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            support.box((x + sx * .37, y + sy * .37, 4.31), (.12, .12, .12), "steel")
    support.finish(parent=root)
    pivot = root_empty(name + "_tracking_pivot", (x, y, head_z))
    pivot.parent = root
    b = MeshBuilder(name)
    b.box((0, 0, 0), (.6, .6, .5), "copper")
    b.cylinder((0, 0, .24), .23, .6, "steel", vertices=8)
    b.cylinder((0, 0, .42), size, .22, "ivory", vertices=12)
    b.cylinder((0, 0, .56), size * .82, .13, "steel", vertices=12)
    b.ring((0, 0, .69), size * .67, size * .43, .1, "darkglass", vertices=12)
    b.cylinder((0, 0, .7), size * .3, .16, "cyan", vertices=12)
    for a in (0, 2 * pi / 3, 4 * pi / 3):
        b.beam((cos(a) * size * .8, sin(a) * size * .8, .62),
               (0, 0, 1.35), .1, "steel")
    b.box((0, 0, 1.3), (.24, .24, .3), "copper")
    b.finish(parent=pivot)
    pivot.rotation_euler[0] = .32
    rotation_loop(pivot, axis=2, frames=480, degrees=360, name=name + "_scan")
    return pivot


def _beacon(root):
    b = MeshBuilder("beacon_island_static")
    _deck(b, 10, 10)
    b.cylinder((0, 0, 4.475), 3.2, .95, "black", vertices=8)
    b.cylinder((0, 0, 5.0), 2.9, .55, "ivory", vertices=8)
    b.box((0, 0, 7.5), (3.5, 3.4, 4.8), "navy")
    b.box((0, 0, 10.0), (4.0, 3.8, .6), "ivory")
    for x in (-1.7, 1.7):
        for y in (-1.65, 1.65):
            b.box((x, y, 7.5), (.5, .5, 4.9), "armor")
    _grid_window(b, (0, -1.76, 7.5), 2.3, 3.4, color="cyan", rows=7)
    _grid_window(b, (1.76, 0, 7.5), 2.2, 3.4, axis="x", color="cyan", rows=7)
    b.box((-.4, .2, 11.4), (2.3, 2.4, 2.4), "ivory")
    b.box((-.4, -1.06, 11.5), (1.4, .12, 1.35), "navy")
    b.box((-.4, -1.15, 11.5), (.8, .08, .84), "cyan")
    b.box((-.4, -1.2, 11.5), (.3, .1, .4), "ivory")
    b.box((-.4, .2, 12.75), (2.65, 2.7, .38), "steel")
    _mast(b, -.5, .2, 12.8, 3.7)
    _mast(b, 1.2, 1.0, 10.3, 3)
    _mast(b, -1.6, 1.0, 10.3, 2.0, "amber")
    _electronics(b, -3.1, 2.8, 4, 1.8, 1.4, 1.3)
    _electronics(b, 2.8, -2.8, 4, 1.7, 1.5, 1.2)
    _pipe(b, [(-3.1, 2.8, 4.6), (-3.1, .6, 4.6), (-2, .6, 5.4)], .23)
    b.finish(parent=root)
    _dish(root, (-3, -2.6, 4.4), "beacon_direction_finder", .85)


def _power(root):
    b = MeshBuilder("power_relay_static")
    _deck(b, 20, 16)
    # Four unequal, densely finned transformer stacks communicate the role.
    for i, (x, y, h) in enumerate([(-6, 2, 6.6), (-2.2, 3, 8.4),
                                  (1.6, 3.5, 5.8), (5.6, 2.8, 7.2)]):
        b.box((x, y, 4.25), (3.15, 3.4, .5), "black")
        b.box((x, y, 4.5 + h / 2), (2.5, 2.8, h), "navy")
        b.box((x, y, 4.65), (3, 3.25, .44), "copper")
        b.box((x, y - 1.52, 4.6 + h / 2), (.72, .45, h + .1), "navy")
        for z in range(int(h / .55)):
            b.box((x, y, 5 + z * .55), (2.9, 3.15, .18), "steel")
        for sx in (-1, 1):
            b.box((x + sx * 1.1, y - 1.53, 4.6 + h / 2),
                  (.3, .3, h + .15), "ivory")
        b.box((x, y, h + 4.72), (3.1, 3.4, .46), "ivory")
        b.box((x, y, h + 5), (1.3, 1.55, .2), "black")
        b.box((x, y - .1, h + 5.15), (.85, .95, .18), "copper")
        for light in range(max(3, int(h / .6))):
            b.box((x, y - 1.8, 5.2 + light * .55),
                  (.34, .14, .3), "cyan" if i != 2 else "amber")
    # Visible high current busbars and chunky isolators.
    for y in (-2.1, -3.4):
        _pipe(b, [(-7, y, 5.4), (-6.4, y, 6.0), (6.1, y, 6.0),
                  (7, y, 5.4)], .34)
        for x in (-6, -2, 2, 6):
            b.box((x, y, 4.15), (1.1, 1.2, .3), "steel")
            b.box((x, y, 5.0), (.75, .9, 1.7), "ivory")
            for z in (5, 5.3, 5.6):
                b.box((x, y, z), (1.05, 1.1, .17), "steel")
            b.box((x, y, 6.05), (.58, .7, .8), "copper")
    _electronics(b, 2, -5.4, 4, 3.4, 1.6, 2.3)
    _electronics(b, -6.7, -5.2, 4, 2.1, 1.6, 1.8)
    b.box((7.4, -1.0, 4.6), (2.1, 3.2, 1.2), "ivory")
    _vent(b, 7.4, -1.0, 5.3, 1.65, 2.6)
    b.box((-7.6, 4.9, 7.0), (1.5, 1.7, 6.0), "ivory")
    _mast(b, -7.6, 4.9, 10, 3.8)
    _mast(b, 6.8, 5.5, 4, 3.5)
    b.finish(parent=root)
    _dish(root, (7.3, -5.6, 5), "power_telemetry", 1.05)


def _pod(b, x, y, z, color="orange", length=3.3):
    """Sealed vacuum freight cell with endcap, locks and service markings."""
    # Interlocking feet bridge both the deck seam and the gap between stacked pods.
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((x + sx * (length / 2 - .4), y + sy * .67, z),
                  (.3, .4, .5), "steel")
    b.box((x, y, z + .1), (length + .1, 2, .22), "black")
    b.box((x, y, z + 1), (length, 2.05, 1.75), color)
    b.box((x, y, z + 1.9), (length - .45, 1.8, .22), "ivory")
    b.box((x, y, z + 1), (length + .22, 1.5, 1.25), "ivory")
    b.box((x, y - 1.04, z + 1), (length - .5, .15, 1.1), color)
    b.box((x + length / 2 + .14, y, z + 1), (.13, 1.25, .85), "steel")
    b.box((x, y - 1.14, z + 1.22), (.6, .09, .34), "steel")
    b.box((x + .84, y - 1.15, z + .75), (.2, .1, .44), "amber")
    for sx in (-1, 1):
        b.box((x + sx * (length / 2 - .38), y - 1.17, z + 1),
              (.18, .22, 1.8), "copper")
        b.box((x + sx * (length / 2 - .4), y, z + 2.05),
              (.4, .65, .15), "steel")


def _robot(root, location, name, yaw=0):
    assembly = root_empty(name + "_base", location)
    assembly.parent = root
    assembly.rotation_euler[2] = yaw
    b = MeshBuilder(name + "_upper_arm")
    foot_bottom = 3.98 - location[2]
    b.box((0, 0, (foot_bottom + .055) / 2),
          (2.7, 2.7, .055 - foot_bottom), "steel")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * 1.12, sy * 1.12, .09), (.22, .22, .16), "copper")
    b.box((0, 0, .28), (2.3, 2.3, .5), "black")
    b.cylinder((0, 0, .65), .8, .8, "copper", vertices=12)
    b.cylinder((0, 0, 1.05), .95, .18, "steel", vertices=12)
    b.beam((0, 0, 1.0), (.95, 0, 4.8), .58, "orange", depth=.88)
    b.beam((-.4, -.46, 1.3), (.55, -.46, 4.5), .15, "steel")
    b.beam((-.4, -.46, 1.3), (-.25, -.1, 1.1), .18, "steel")
    b.box((.95, 0, 4.8), (1.3, 1.3, .9), "steel")
    b.box((.95, -.71, 4.8), (.6, .2, .6), "copper")
    b.box((.95, -.83, 4.8), (.23, .12, .23), "cyan")
    _pipe(b, [(0, .5, 1.1), (-.25, .6, 2.5), (.9, .5, 4.8)], .09, "black", False)
    b.finish(parent=assembly)
    forearm = root_empty(name + "_articulated_forearm", (.95, 0, 4.8))
    forearm.parent = assembly
    arm = MeshBuilder(name + "_forearm_and_gripper")
    arm.beam((0, 0, 0), (3.6, 0, -1.0), .5, "orange", depth=.75)
    arm.beam((0, -.44, -.2), (3.1, -.44, -1.05), .14, "steel")
    arm.box((3.2, -.32, -1.0), (.5, .35, .28), "steel")
    arm.box((3.6, 0, -1.12), (.7, .8, .7), "steel")
    arm.box((3.6, 0, -1.67), (.6, 1.1, .6), "black")
    for sy in (-1, 1):
        arm.beam((3.6, sy * .55, -1.5), (3.6, sy * .95, -2.3), .22, "copper")
        arm.box((3.6, sy * .68, -2.46), (.5, .6, .24), "ivory")
    arm.box((3.64, 0, -1.99), (.25, .42, .16), "cyan")
    _pipe(arm, [(0, .42, .1), (2.4, .42, -.6), (3.4, .4, -1.35)], .07, "black", False)
    arm.finish(parent=forearm)
    oscillate(forearm, axis=2, amount=.20, frames=480, name=name + "_handling_cycle")
    return assembly


def _cargo(root):
    b = MeshBuilder("cargo_exchange_static")
    _deck(b, 28, 19)
    # Closed freight modules on magnetic handling pallets, deliberately uneven.
    for x, y, z, color, length in [(-7, 0, 4.1, "orange", 3.5),
                                  (-3, 0, 4.1, "armor", 3.5),
                                  (-7, 3, 4.1, "ivory", 3.5),
                                  (-7, 3, 6.3, "orange", 3.5),
                                  (-3, 3, 4.1, "copper", 3.5),
                                  (5.7, 1.8, 4.1, "orange", 4.5),
                                  (5.7, 4.5, 4.1, "armor", 4.5),
                                  (5.7, 4.5, 6.3, "ivory", 4.5)]:
        _pod(b, x, y, z, color, length)
    # An open central exchange lane with pale guide lights and track hardware.
    for x in (-1, 2):
        b.box((x, -1.4, 4.12), (.22, 11.9, .2), "black")
        for y in (-6, -4.5, -3, -1.5, 0, 1.5, 3.0):
            b.box((x, y, 4.26), (.28, .6, .15), "cyan")
    for y in (-6.5, -4):
        for x in (-9.3, -6.2, -3.1, 3.5, 6.5, 9.5):
            b.box((x, y, 4.075), (2.65, 1.85, .19), "black")
            b.box((x, y, 4.25), (2.5, 1.7, .32), "steel")
            b.box((x, y - .86, 4.44), (1.25, .16, .1), "amber")
    # Compact cargo control cabin, asymmetric rather than a pair of towers.
    b.box((9.7, 4.5, 5.7), (3.2, 3.5, 3.3), "ivory")
    _grid_window(b, (9.7, 2.7, 5.9), 2.15, 1.8, rows=4)
    _grid_window(b, (11.34, 4.5, 5.9), 2.2, 1.8, axis="x", rows=4)
    b.box((9.7, 4.5, 7.55), (3.65, 3.95, .5), "navy")
    _vent(b, 9.7, 4.5, 7.91, 2.25, 2.35)
    b.box((10.1, 5.0, 8.04), (.95, .95, .5), "steel")
    _mast(b, 10.1, 5.0, 8.2, 3)
    _mast(b, -11.4, 6.1, 4.1, 3.5)
    _electronics(b, -10.7, -5.9, 4.1, 2.5, 1.7, 1.8)
    _electronics(b, 9.8, -5.9, 4.1, 2.7, 1.7, 1.5)
    b.finish(parent=root)
    _robot(root, (-10.8, 3.6, 4.1), "cargo_arm_west", yaw=-1.1)
    _robot(root, (4, 6.6, 4.55), "cargo_arm_east", yaw=-1.4)


def _control(root):
    b = MeshBuilder("traffic_control_static")
    _deck(b, 12, 12)
    b.cylinder((0, 0, 4.5), 3.5, .9, "black", vertices=8)
    b.cylinder((0, 0, 5.1), 3.15, .55, "ivory", vertices=8)
    b.box((0, 0, 6.75), (4.0, 4.0, 3.0), "navy")
    _grid_window(b, (0, -2.05, 6.75), 2.9, 2.1, rows=4)
    _grid_window(b, (2.05, 0, 6.75), 2.9, 2.1, axis="x", rows=4)
    for x in (-2, 2):
        for y in (-2, 2):
            b.box((x, y, 6.75), (.55, .55, 3.2), "ivory")
    b.cylinder((0, 0, 8.42), 3.2, .5, "ivory", vertices=8)
    b.cylinder((0, 0, 8.75), 2.8, .26, "copper", vertices=8)
    b.box((-.5, .4, 8.92), (3.3, 3.3, .2), "navy")
    b.box((-.5, .4, 9.8), (3.2, 3.2, 1.7), "darkglass")
    _grid_window(b, (-.5, -1.25, 9.8), 2.6, .85, color="cyan", rows=2)
    _grid_window(b, (1.15, .4, 9.8), 2.6, .85, axis="x", color="cyan", rows=2)
    b.box((-.5, .4, 10.91), (3.75, 3.75, .55), "ivory")
    b.box((-.5, .4, 11.25), (2.6, 2.6, .25), "steel")
    _mast(b, -.9, 1.1, 11.3, 4.3)
    _mast(b, .2, .4, 11.3, 2.8, "amber")
    b.beam((-1.6, 1.7, 8.4), (-2.3, 2.6, 8.4), .7, "steel")
    b.beam((-1.5, 1.5, 7.5), (-2.3, 2.6, 8.4), .25, "copper")
    _mast(b, -2.3, 2.6, 8.7, 3.2)
    _electronics(b, -3.8, -2.5, 4.1, 1.6, 1.7, 1.7)
    _electronics(b, 3.7, 2.6, 4.1, 1.8, 1.5, 1.25)
    for y in (2.5, 0):
        b.box((-4, y, 4.45), (.65, .65, .9), "steel")
    b.box((-2.08, 0, 5.9), (.4, .8, .8), "ivory")
    _pipe(b, [(-4, 2.5, 4.8), (-4, 0, 4.8), (-1.8, 0, 5.9)], .23)
    b.finish(parent=root)
    _dish(root, (3.65, -3.45, 4.2), "traffic_tracking_dish", 1.2)


def _tank(b, x, y, z, radius=2.9, height=6.5):
    b.cylinder((x, y, z + .19), radius + .4, .7, "black", vertices=16)
    b.cylinder((x, y, z + .7), radius + .15, .6, "steel", vertices=16)
    b.cylinder((x, y, z + height / 2 + .5), radius, height - .8, "ivory", vertices=16)
    for h in (1.4, height - 1.3):
        b.cylinder((x, y, z + h), radius + .08, .35, "orange", vertices=16)
    for a in range(0, 16, 2):
        angle = a * 2 * pi / 16
        b.box((x + cos(angle) * radius, y + sin(angle) * radius, z + height / 2),
              (.28, .28, height - 1.2), "steel")
    b.cylinder((x, y, z + height), radius * .86, .9, "ivory", vertices=16)
    b.cylinder((x, y, z + height + .55), radius * .61, .42, "armor", vertices=12)
    b.ring((x, y, z + height + .84), radius * .36, radius * .21, .3, "steel", vertices=12)
    b.cylinder((x, y, z + height + .83), radius * .2, .19, "black", vertices=12)
    _grid_window(b, (x, y - radius - .1, z + height / 2), .6, 1.7,
                 color="cyan", rows=4)


def _service(root):
    b = MeshBuilder("refuel_and_repair_static")
    _deck(b, 24, 21)
    _tank(b, -5.3, 3.8, 4.1, 3.0, 6.8)
    _tank(b, 3.0, 4.8, 4.1, 3.25, 7.5)
    # Bundled pressure lines descend from the tanks to the exposed service rack.
    for x in (-5.9, -4.7, 2.4, 3.6):
        source_y = 1.0 if x < 0 else 1.9
        _pipe(b, [(x, source_y, 9.8), (x, .35, 9.8), (x, -.2, 9.0),
                  (x, -.2, 5.0), (x, -2.6, 5.0)], .21)
        b.box((x, -2.6, 4.8), (.9, .9, 1.6), "ivory")
        b.box((x, -.2, 6.5), (.65, .7, .65), "steel")
        b.box((x, -.61, 6.5), (.4, .2, .4), "copper")
    # Ship repair cradle is open to vacuum and deliberately unroofed.
    for sx in (-1, 1):
        x = sx * 4.1
        b.box((x, -5.3, 4.25), (1.1, 7.2, .6), "navy")
        b.box((x, -5.3, 4.63), (.58, 6.7, .18), "steel")
        for y in (-7.9, -3.0):
            b.box((x, y, 5.3), (1.1, 1.0, 1.5), "ivory")
            b.beam((x, y, 5.2), (sx * 2.3, y, 6.2), .4, "copper")
            b.box((sx * 2.1, y, 6.2), (.6, 1.2, .45), "steel")
            b.box((x, y - .52, 5.5), (.5, .13, .65), "cyan")
    for y in (-8, -6.5, -5, -3.5):
        b.box((0, y, 4.06), (2.4, .44, .16), "black")
        b.box((0, y, 4.18), (2.2, .28, .15), "amber")
    b.box((-9.2, -5.5, 4.07), (2.7, 4.7, .18), "black")
    b.box((-9.2, -5.5, 4.8), (2.5, 4.5, 1.5), "ivory")
    _vent(b, -9.2, -5.5, 5.65, 1.8, 3.4)
    _electronics(b, 8.5, 4.6, 4.1, 2.3, 2.7, 2.3)
    _electronics(b, 8.5, -3.2, 4.1, 2.3, 2.3, 1.8)
    _mast(b, -9.4, 7.4, 4.1, 4.5)
    _mast(b, 8.7, 7.5, 4.1, 3.2)
    b.finish(parent=root)
    _robot(root, (8.5, -7.3, 4.1), "repair_manipulator", yaw=2.7)


BUILDERS = {
    "beacon": _beacon,
    "power": _power,
    "cargo": _cargo,
    "control": _control,
    "service": _service,
}


def build_relay(kind, name):
    """Create a detailed relay island at the origin and return its editable root."""
    if kind not in BUILDERS:
        raise ValueError("Unknown relay kind: " + kind)
    root = root_empty(name)
    root["asset_role"] = "Wayfarer " + kind + " island"
    root["deck_surface_z"] = 4.0
    root["design_note"] = "Original voxel spacecraft service infrastructure; vacuum exterior."
    BUILDERS[kind](root)
    return root
