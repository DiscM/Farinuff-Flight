"""Editable voxel spacecraft and greenhouse details for Crescent Harbor.

Craft use Blender Z up, point along local -Y, and have their origin near their
center of mass. No geometry is created while this module is imported.
"""

import math

from mathutils import Matrix

try:
    from .geometry import MeshBuilder, root_empty, rotation_loop
except ImportError:
    from geometry import MeshBuilder, root_empty, rotation_loop


def _circle_xz(center, radius, vertices=12):
    x, y, z = center
    return [(x + math.cos(i * math.tau / vertices) * radius,
             y, z + math.sin(i * math.tau / vertices) * radius)
            for i in range(vertices + 1)]


def _collar(m, center, radius=0.55, material="steel"):
    """Docking collar perpendicular to the Y axis, with a sealed dark hatch."""
    x, y, z = center
    m.box((x, y, z), (radius * 1.25, 0.13, radius * 1.25), "navy")
    m.tube(_circle_xz((x, y - 0.08, z), radius), 0.13, material, segments=6)
    m.tube(_circle_xz((x, y - 0.13, z), radius * 0.76), 0.05, "amber", segments=5)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        m.box((x + math.cos(a) * radius, y - 0.17,
               z + math.sin(a) * radius), (0.17, 0.15, 0.17), "ivory")
    m.box((x, y - 0.18, z), (0.10, 0.06, radius * 0.80), "steel")


def _engine(m, x, y, z, radius=0.40, on=True):
    """Stepped open engine bell. Aft exhaust points along local +Y."""
    m.box((x, y - 0.22, z), (radius * 1.70, 0.85, radius * 1.70), "navy")
    rings = ((-0.30, 0.65), (0.02, 0.78), (0.35, 0.97), (0.53, 1.04))
    for offset, scale in rings:
        m.tube(_circle_xz((x, y + offset, z), radius * scale),
               radius * 0.18, "steel" if offset > 0.1 else "copper", segments=6)
    for i in range(8):
        a = i * math.tau / 8
        m.beam((x + math.cos(a) * radius * 0.66, y - 0.25,
                z + math.sin(a) * radius * 0.66),
               (x + math.cos(a) * radius, y + 0.48,
                z + math.sin(a) * radius), radius * 0.12, "armor")
    # Dark inner throat makes the bell read as an opening even without exhaust.
    m.box((x, y - 0.12, z), (radius * 1.04, 0.10, radius * 1.04), "black")
    m.tube(_circle_xz((x, y + 0.14, z), radius * 0.48),
           radius * 0.14, "cyan" if on else "navy", segments=6)
    if on:
        m.box((x, y + 0.22, z), (radius * 0.51, 0.32, radius * 0.51), "cyan")
        m.box((x, y + 0.67, z), (radius * 0.30, 0.42, radius * 0.30), "cyan")


def _rcs(m, center, size=0.24, lit=False):
    x, y, z = center
    m.box(center, (size * 1.8, size * 1.8, size * 1.8), "ivory")
    for s in (-1, 1):
        m.box((x + s * size, y, z), (size * 0.35, size, size), "black")
        m.box((x, y + s * size, z), (size, size * 0.35, size), "black")
    m.box((x, y, z + size), (size * 0.64, size * 0.64, size * 0.24),
          "cyan" if lit else "steel")


def _radiator(m, center, length=2.8, width=1.0):
    x, y, z = center
    m.box(center, (width, length, 0.12), "steel")
    m.box((x, y, z + 0.08), (width - 0.15, length - 0.15, 0.07), "navy")
    for j in range(max(3, int(length / 0.30))):
        v = y - length / 2 + 0.16 + j * (length - 0.32) / max(2, int(length / 0.30) - 1)
        m.box((x, v, z + 0.13), (width - 0.19, 0.045, 0.05), "copper")


def _courier(m, engines_on):
    # Stepped pressure shell and tall, forward-facing cockpit, without a keel.
    m.box((0, -0.04, 0), (1.27, 2.82, 0.83), "ivory")
    m.box((0, -1.36, -0.02), (0.84, 0.61, 0.59), "armor")
    m.box((0, -1.69, 0), (0.46, 0.22, 0.36), "ivory")
    m.box((0, -0.49, 0.45), (1.00, 1.04, 0.42), "navy")
    m.box((0, -0.67, 0.70), (0.77, 0.65, 0.14), "glass")
    m.box((0, -1.00, 0.52), (0.78, 0.12, 0.38), "glass")
    m.box((0, -0.68, 0.78), (0.08, 0.70, 0.05), "ivory")
    m.box((0, 0.65, 0.51), (0.97, 0.55, 0.23), "orange")
    m.box((0, 1.04, 0.45), (0.60, 0.19, 0.13), "steel")
    for x in (-0.96, 0.96):
        m.box((x, 0.17, 0.0), (0.58, 2.42, 0.68), "armor")
        m.box((x, -0.29, 0.39), (0.49, 1.20, 0.15), "ivory")
        m.box((x, 0.17, -0.34), (0.46, 1.62, 0.13), "navy")
        m.box((x, -0.86, 0.05), (0.59, 0.22, 0.41), "orange")
        m.box((x, -1.02, 0.15), (0.20, 0.06, 0.13), "cyan")
        m.box((x / 2, 0.53, 0), (0.85, 0.36, 0.28), "steel")
        _engine(m, x, 1.37, 0, radius=0.34, on=engines_on)
        _rcs(m, (x, -0.86, -0.38), 0.10)
        m.box((x * 1.36, 0.68, 0.0), (0.23, 0.70, 0.08), "navy")
    m.box((-0.75, 0.42, 0.56), (0.12, 0.12, 0.15), "red")
    m.box((0.75, 0.42, 0.56), (0.12, 0.12, 0.15), "cyan")
    m.box((0, 0.18, -0.49), (0.67, 0.83, 0.14), "navy")


def _sealed_pod(m, center, length=2.35, variant=0):
    x, y, z = center
    stripe = ("orange", "copper", "armor")[variant % 3]
    m.box(center, (1.14, length, 0.96), "ivory")
    m.box((x, y, z + 0.51), (0.91, length - 0.17, 0.14), "armor")
    m.box((x, y, z - 0.51), (0.91, length - 0.17, 0.14), "steel")
    for end in (-1, 1):
        m.box((x, y + end * (length / 2 + 0.05), z), (0.90, 0.16, 0.76), stripe)
        m.box((x, y + end * (length / 2 + 0.14), z), (0.59, 0.10, 0.48), "navy")
        m.box((x, y + end * (length / 2 + 0.20), z), (0.36, 0.035, 0.23), "steel")
    for side in (-1, 1):
        m.box((x + side * 0.59, y, z), (0.08, 0.55, 0.46), stripe)
        m.box((x + side * 0.64, y - 0.20, z + 0.05), (0.025, 0.33, 0.20), "navy")
        m.box((x + side * 0.665, y - 0.24, z + 0.05), (0.025, 0.13, 0.10), "cyan")


def _podcarrier(m, engines_on):
    # Axial truss: cargo on port, starboard, dorsal AND ventral racks.
    m.box((0, 0, 0), (0.72, 8.80, 0.72), "navy")
    for x in (-0.40, 0.40):
        for z in (-0.40, 0.40):
            m.beam((x, -4.5, z), (x, 4.15, z), 0.12, "steel")
    for y in (-3.3, -0.6, 2.1):
        for x, z in ((-1.15, 0), (1.15, 0), (0, 1.18), (0, -1.18)):
            _sealed_pod(m, (x, y, z), 2.12, int((y + 4) / 2) + int(x + z))
            m.beam((0, y, 0), (x, y, z), 0.24, "copper")
        for s in (-1, 1):
            m.box((s * 1.8, y, 0), (0.14, 0.18, 0.90), "steel")
    # Pressure cabin at one end, propulsion/service collar at the other.
    m.box((0, -4.55, 0), (1.40, 1.25, 1.36), "ivory")
    m.box((0, -4.70, 0.80), (0.96, 0.66, 0.24), "armor")
    _collar(m, (0, -5.25, 0), 0.57)
    m.box((0, -4.82, 0.93), (0.72, 0.31, 0.055), "glass")
    for s in (-1, 1):
        m.box((s * 0.74, -4.47, 0.15), (0.09, 0.59, 0.29), "glass")
        _radiator(m, (s * 2.35, 0.40, 0.42), 4.3, 0.88)
        m.beam((s * 0.35, -1.50, 0.35), (s * 2.2, -1.50, 0.35), 0.16, "copper")
        m.beam((s * 0.35, 2.20, 0.35), (s * 2.2, 2.20, 0.35), 0.16, "copper")
    m.box((0, 4.10, 0), (2.12, 0.74, 1.63), "ivory")
    m.box((0, 4.48, 0), (1.85, 0.24, 1.41), "navy")
    for x in (-0.58, 0.58):
        _engine(m, x, 4.74, 0, radius=0.49, on=engines_on)
    for y in (-4.65, 4.0):
        for s in (-1, 1):
            _rcs(m, (s * 1.00, y, s * 0.60), 0.19, lit=engines_on)
    m.beam((0, -4.29, 0.78), (0, -4.29, 1.79), 0.07, "steel")
    m.box((0, -4.29, 1.83), (0.16, 0.16, 0.14), "red")


def _tug(m, engines_on):
    m.box((0, 0.27, 0), (1.56, 2.30, 0.93), "orange")
    m.box((0, 0.46, 0.52), (1.31, 1.02, 0.27), "ivory")
    m.box((0, -0.34, 0.66), (0.86, 0.78, 0.35), "navy")
    m.box((0, -0.49, 0.87), (0.71, 0.48, 0.10), "glass")
    m.box((0, -0.75, 0.68), (0.72, 0.10, 0.32), "glass")
    m.box((0, 0.82, 0.73), (0.83, 0.34, 0.16), "steel")
    _collar(m, (0, -0.93, 0), 0.47, "copper")
    for s in (-1, 1):
        m.box((s * 1.03, 0.44, 0), (0.53, 2.25, 0.66), "ivory")
        _engine(m, s * 1.03, 1.64, 0, radius=0.34, on=engines_on)
        m.box((s * 0.88, -0.77, 0), (0.37, 0.43, 0.42), "steel")
        m.beam((s * 0.92, -0.77, 0), (s * 1.35, -1.84, 0), 0.22, "orange")
        m.box((s * 1.35, -1.84, 0), (0.40, 0.34, 0.39), "steel")
        m.beam((s * 1.35, -1.84, 0), (s * 0.83, -2.31, 0), 0.18, "ivory")
        m.box((s * 0.79, -2.29, 0), (0.23, 0.48, 0.55), "navy")
        m.box((s * 0.69, -2.36, 0), (0.10, 0.26, 0.29), "amber")
        _rcs(m, (s * 1.08, 0.43, -0.48), 0.15)
    m.box((0, 0.49, -0.57), (1.03, 1.04, 0.14), "navy")


def _drone(m, engines_on):
    m.box((0, 0, 0), (0.97, 0.88, 0.67), "ivory")
    m.box((0, 0, 0.40), (0.76, 0.64, 0.19), "orange")
    m.box((0, -0.49, 0), (0.76, 0.14, 0.44), "navy")
    m.box((0, -0.58, 0), (0.34, 0.08, 0.24), "cyan")
    for s in (-1, 1):
        _rcs(m, (s * 0.59, 0.14, 0), 0.18, lit=engines_on)
        # Two distinct elbow bends and small two-finger tools are modeled.
        m.beam((s * 0.52, -0.17, -0.18), (s * 1.00, -0.45, -0.39), 0.12, "copper")
        m.box((s * 1.00, -0.45, -0.39), (0.22, 0.22, 0.22), "steel")
        m.beam((s * 1.00, -0.45, -0.39), (s * 0.79, -1.09, -0.18), 0.11, "ivory")
        for dz in (-0.12, 0.12):
            m.beam((s * 0.79, -1.09, -0.18), (s * 0.79, -1.31, -0.18 + dz), 0.065, "navy")
        _engine(m, s * 0.35, 0.62, -0.11, radius=0.19, on=engines_on)
    m.box((0, 0.03, -0.41), (0.63, 0.57, 0.16), "navy")


def build_ship(kind, name, engines_on=True):
    """Build a craft as one batched hull plus an optional animated scanner."""
    builders = {"courier": _courier, "podcarrier": _podcarrier,
                "tug": _tug, "drone": _drone}
    if kind not in builders:
        raise ValueError("Unknown spacecraft kind: %s" % kind)
    root = root_empty(name)
    root["asset_kind"] = kind
    root["forward_axis"] = "-Y"
    root["role"] = {"courier": "Crew transfer / arriving and departing traffic",
                    "podcarrier": "Sealed multi-axis cargo transport",
                    "tug": "Docking and external maintenance",
                    "drone": "Hull inspection and repair"}[kind]
    m = MeshBuilder(name + "_Hull")
    builders[kind](m, engines_on)
    m.finish(parent=root)
    if kind == "drone":
        scanner_pivot = root_empty(name + "_Scanner", (0, 0.02, 0.51))
        scanner_pivot.parent = root
        scanner = MeshBuilder(name + "_ScannerHead")
        scanner.box((0, 0, 0.13), (0.27, 0.22, 0.26), "navy")
        scanner.box((0, -0.14, 0.15), (0.18, 0.06, 0.14), "cyan")
        scanner.finish(parent=scanner_pivot)
        rotation_loop(scanner_pivot, axis=2, frames=240, degrees=360, name=name + "_InspectionSweep")
    return root


def build_greenhouse(name, length=10, width=5):
    """Stepped, glazed garden conservatory with visible hydroponic plants."""
    root = root_empty(name)
    root["role"] = "Habitat hydroponics and oxygen garden"
    m = MeshBuilder(name + "_FrameAndPlanting")
    length, width = float(length), float(width)
    half_l, half_w = length / 2, width / 2
    eave = width * 0.43
    ridge = eave + width * 0.30
    m.box((0, 0, 0.17), (length + 0.50, width + 0.50, 0.34), "navy")
    m.box((0, 0, 0.40), (length + 0.27, width + 0.27, 0.20), "copper")
    m.box((0, 0, 0.54), (length - 0.20, width - 0.15, 0.10), "steel")
    # Transparent panels remain their own mesh for straightforward editing.
    glass = MeshBuilder(name + "_Glazing")
    for s in (-1, 1):
        glass.box((0, s * half_w, (eave + 0.61) / 2),
                  (length - 0.13, 0.04, eave - 0.61), "glass")
        m.beam((-half_l, s * half_w, 0.57), (half_l, s * half_w, 0.57), 0.15, "ivory")
        m.beam((-half_l, s * half_w, eave), (half_l, s * half_w, eave), 0.12, "copper")
    # Two sloped rectangular roof planes, never a smooth plastic dome.
    rise = ridge - eave
    slope_length = math.sqrt(half_w ** 2 + rise ** 2)
    angle = math.atan2(rise, half_w)
    for s in (-1, 1):
        glass.box((0, s * half_w / 2, eave + rise / 2),
                  (length - 0.10, slope_length, 0.04), "glass",
                  rotation=Matrix.Rotation(-s * angle, 3, "X"))
    m.beam((-half_l, 0, ridge), (half_l, 0, ridge), 0.15, "ivory")
    bays = max(4, round(length / 1.35))
    for i in range(bays + 1):
        x = -half_l + length * i / bays
        for s in (-1, 1):
            m.beam((x, s * half_w, 0.55), (x, s * half_w, eave), 0.11, "ivory")
            m.beam((x, s * half_w, eave), (x, 0, ridge), 0.11, "ivory")
            m.box((x, s * (half_w + 0.04), 0.66), (0.21, 0.18, 0.19), "copper")
    # End windows and central rib. Narrow gap at one end identifies an airlock.
    for s in (-1, 1):
        glass.box((s * half_l, 0, (eave + 0.65) / 2),
                  (0.04, width - 0.14, eave - 0.65), "glass")
        m.beam((s * half_l, 0, 0.56), (s * half_l, 0, ridge), 0.13, "ivory")
        for side in (-1, 1):
            m.beam((s * half_l, side * half_w / 2, eave),
                   (s * half_l, side * half_w / 2, eave + rise / 2), 0.09, "copper")
    # Long trays flank a clear walkway. Leaves are deliberately voxel clusters.
    for row in (-1, 1):
        y = row * width * 0.29
        m.box((0, y, 0.73), (length - 0.77, width * 0.25, 0.23), "ivory")
        m.box((0, y, 0.87), (length - 1.00, width * 0.21, 0.12), "black")
        m.box((0, y - row * width * 0.12, 0.94), (length - 0.93, 0.05, 0.09), "cyan")
        for i in range(bays):
            x = -half_l + (i + 0.5) * length / bays
            height = 0.35 + (i % 3) * 0.12
            m.beam((x, y, 0.94), (x, y, 1.00 + height), 0.065, "green")
            m.box((x, y, 1.09 + height * 0.6), (0.56, 0.45, height), "green")
            m.box((x - 0.18, y + 0.13, 1.06 + height), (0.40, 0.36, 0.26), "green")
            if i % 3 == 0:
                m.box((x + 0.23, y - 0.09, 1.06 + height), (0.12, 0.12, 0.14), "amber")
    m.box((-half_l - 0.18, 0, 0.88), (0.50, width * 0.29, 0.62), "ivory")
    m.box((-half_l - 0.45, 0, 0.94), (0.07, width * 0.20, 0.37), "glass")
    m.finish(parent=root)
    glass.finish(parent=root)
    return root
