"""Secondary architecture for the existing voxel Wayfarer core.

All measurements are local to the original core. The caller owns placement and
scale. Details stay on existing roof, facade and apron surfaces; the promenade,
radial walkways, ring openings and docking-clamp center remain unobstructed.
"""

import math

try:
    from .geometry import MeshBuilder, root_empty, rotation_loop
except ImportError:
    from geometry import MeshBuilder, root_empty, rotation_loop


def _wall_box(m, center, angle, tangent, normal, up, size, material):
    """Place a facade part with width along the wall and depth perpendicular."""
    nx, ny = math.cos(angle), math.sin(angle)
    x = center[0] - ny * tangent + nx * normal
    y = center[1] + nx * tangent + ny * normal
    z = center[2] + up
    m.box((x, y, z), size, material, rotation=angle + math.pi / 2)


def _window_bank(m, center, angle, width=3.55, height=1.28,
                 columns=7, rows=2, light="amber"):
    """Individually recessed lit windows inside a chunky dark reveal."""
    # Extend the reveal back into the stepped hull; a thin face alone left
    # several window modules suspended a fraction outside the voxel wall.
    _wall_box(m, center, angle, 0, -0.12, 0, (width, 0.42, height), "navy")
    _wall_box(m, center, angle, 0, 0.10, height / 2 + 0.06,
              (width + 0.26, 0.29, 0.17), "ivory")
    _wall_box(m, center, angle, 0, 0.08, -height / 2 - 0.02,
              (width + 0.18, 0.27, 0.13), "steel")
    for s in (-1, 1):
        _wall_box(m, center, angle, s * (width / 2 + 0.04), 0.09, 0,
                  (0.13, 0.24, height), "ivory")
    cell_w, cell_h = (width - 0.28) / columns, (height - 0.20) / rows
    for col in range(columns):
        for row in range(rows):
            t = (col - (columns - 1) / 2) * cell_w
            u = (row - (rows - 1) / 2) * cell_h
            _wall_box(m, center, angle, t, 0.10, u,
                      (cell_w * 0.67, 0.036, cell_h * 0.66), light)
    for s in (-1, 1):
        _wall_box(m, center, angle, s * (width / 2 - 0.08), 0.16,
                  height / 2 + 0.06, (0.08, 0.045, 0.08), "copper")


def _vent(m, center, width=1.0, length=1.2, height=0.55):
    x, y, z = center
    m.box(center, (width, length, height), "steel")
    m.box((x, y, z + height / 2 + 0.035),
          (width - 0.13, length - 0.12, 0.07), "navy")
    for j in range(5):
        m.box((x, y + (j - 2) * (length - 0.22) / 5, z + height / 2 + 0.10),
              (width - 0.17, 0.07, 0.10), "armor")


def _beacon(m, base, height=1.65, color="red"):
    x, y, z = base
    m.box((x, y, z + 0.10), (0.43, 0.43, 0.20), "navy")
    m.beam((x, y, z + 0.18), (x, y, z + height), 0.095, "steel")
    m.box((x, y, z + height - 0.10), (0.24, 0.24, 0.11), "ivory")
    m.box((x, y, z + height + 0.05), (0.16, 0.16, 0.20), color)


def _roof_equipment(m, x, y, index):
    """Different silhouettes identify eight neighborhoods in the ring."""
    # A perimeter plant room, breaker cabinet and service rails fit around the
    # original central radiator. Larger details remain legible in the wide view.
    _vent(m, (x + 1.18, y + 1.13, 10.285), 0.86, 1.05, 0.59)
    m.box((x - 1.35, y - 0.50, 10.28), (0.54, 0.81, 0.56), "ivory")
    m.box((x - 1.35, y - 0.92, 10.34), (0.33, 0.045, 0.26), "navy")
    m.box((x - 1.35, y - 0.95, 10.35), (0.13, 0.04, 0.15), "cyan")
    m.tube([(x - 1.42, y - 0.05, 10.09), (x - 1.42, y + 1.30, 10.09),
            (x + 0.60, y + 1.30, 10.09)], 0.10, "copper", segments=6)
    for t in (-0.90, 0.05, 0.80):
        m.box((x + t, y + 1.3, 10.10), (0.17, 0.29, 0.26), "ivory")
    variant = index % 3
    if variant == 0:
        # Communications fork with two offset antenna paddles.
        m.box((x - 1.16, y + 1.13, 10.235), (0.58, 0.60, 0.51), "armor")
        for dx, top in ((-0.20, 12.64), (0.22, 12.12)):
            m.beam((x - 1.16 + dx, y + 1.13, 10.40),
                   (x - 1.16 + dx, y + 1.13, top), 0.10, "steel")
            m.box((x - 1.16 + dx, y + 1.13, top), (0.22, 0.37, 0.65), "ivory")
            m.box((x - 1.16 + dx, y + 0.93, top), (0.11, 0.045, 0.40), "cyan")
    elif variant == 1:
        # A taller finned climate-control unit seated on a continuous curb.
        m.box((x - 0.85, y + 1.13, 10.14), (1.20, 0.77, 0.30), "steel")
        m.box((x - 0.85, y + 1.13, 11.0), (1.17, 0.70, 1.43), "ivory")
        m.box((x - 0.85, y + 0.74, 11.08), (0.87, 0.13, 0.94), "navy")
        for row in range(5):
            m.box((x - 0.85, y + 0.65, 10.73 + row * 0.18), (0.84, 0.07, 0.07), "steel")
        m.box((x - 0.85, y + 1.13, 11.77), (1.24, 0.79, 0.13), "armor")
    else:
        # Cylindrical pressure machinery with a bolted support pedestal.
        m.cylinder((x - 0.98, y + 1.04, 10.12), 0.46, 0.28, "steel", vertices=12)
        m.cylinder((x - 0.98, y + 1.04, 11.0), 0.43, 1.67, "ivory", vertices=12)
        for z in (10.30, 11.62):
            m.ring((x - 0.98, y + 1.04, z), 0.47, 0.38, 0.13, "copper", vertices=12)
        m.cylinder((x - 0.98, y + 1.04, 11.90), 0.19, 0.22, "steel", vertices=8)
        m.tube([(x - 0.55, y + 1.04, 11.52), (x + 0.15, y + 1.04, 11.52),
                (x + 0.15, y + 1.04, 10.12)], 0.13, "copper", segments=6)
    _beacon(m, (x + 1.43, y - 1.40, 9.63), height=2.6 if index % 2 else 3.2)
    m.box((x - 1.57, y - 1.45, 10.03), (0.33, 0.33, 0.53), "steel")
    m.box((x - 1.57, y - 1.45, 10.34), (0.24, 0.24, 0.17), "cyan")


def _tower_detail(m):
    # Faceted window modules break the existing uninterrupted light band into
    # individual inhabited rooms and reveal a maintenance level underneath.
    for i in range(8):
        a = i * math.tau / 8
        n = (math.cos(a), math.sin(a))
        radius = 6.59 if i % 2 == 0 else 6.68
        c = (n[0] * radius, n[1] * radius, 6.53)
        _window_bank(m, c, a, width=3.45, height=0.99, columns=7, rows=2)
        # A shaded gallery directly above the warm habitation level.
        _wall_box(m, (n[0] * 6.88, n[1] * 6.88, 7.82), a, 0, 0, 0,
                  (3.30, 1.10, 0.19), "armor")
        # Real access panel and reinforcing girders around the lower collar.
        c = (n[0] * 8.91, n[1] * 8.91, 2.68)
        _wall_box(m, c, a, 0, 0.16, 0, (2.64, 0.18, 0.98), "navy")
        for j in (-1, 0, 1):
            _wall_box(m, c, a, j * 0.79, 0.29, 0, (0.70, 0.15, 0.79), "armor")
            _wall_box(m, c, a, j * 0.79, 0.39, 0.20, (0.32, 0.06, 0.095), "copper")
            _wall_box(m, c, a, j * 0.79, 0.41, -0.23, (0.30, 0.06, 0.07), "steel")
        _wall_box(m, c, a, 0, 0.41, 0.49, (0.25, 0.07, 0.15), "cyan")
        # Upper observation glazing has narrow vertical subdivisions and vents.
        for j in (-1, 0, 1):
            rr = 5.10 if i % 2 == 0 else 5.20
            _wall_box(m, (n[0] * rr, n[1] * rr, 10.29), a,
                      j * 0.87, 0, 0, (0.085, 0.56, 1.72), "copper")
        _wall_box(m, (n[0] * 5.68, n[1] * 5.68, 12.10), a, 0, -0.06, 0,
                  (1.70, 0.42, 0.25), "navy")
        for j in (-0.60, -0.30, 0, 0.30, 0.60):
            _wall_box(m, (n[0] * 5.68, n[1] * 5.68, 12.10), a,
                      j, 0.12, 0, (0.10, 0.08, 0.22), "steel")
        # Copper buttresses beneath the main gallery keep the stepped massing.
        for tangent in (-1.67, 1.67):
            _wall_box(m, (n[0] * 7.5, n[1] * 7.5, 4.0), a,
                      tangent, 0.08, 0, (0.17, 0.70, 0.57), "copper")
    # Short safety rail runs stop before each cardinal bridge opening.
    for quadrant in range(4):
        aa = quadrant * math.pi / 2
        points = []
        for k in range(1, 6):
            a = aa + k * math.pi / 12
            p = (math.cos(a) * 8.8, math.sin(a) * 8.8, 4.13)
            m.beam((p[0], p[1], 3.48), p, 0.09, "steel")
            points.append(p)
            if k in (1, 5):
                m.box((p[0], p[1], 4.21), (0.22, 0.22, 0.20), "cyan")
        for a, b in zip(points, points[1:]):
            m.beam(a, b, 0.07, "armor")
    # Crown instrumentation: small horizontal detector faces and red telltales.
    for i in range(6):
        a = i * math.tau / 6
        x, y = math.cos(a) * 3.24, math.sin(a) * 3.24
        m.box((x, y, 13.62), (0.62, 0.68, 0.39), "navy", rotation=a)
        m.box((x, y, 13.85), (0.49, 0.50, 0.12), "armor", rotation=a)
        m.box((x, y, 13.94), (0.16, 0.18, 0.09), "amber")


def _bridge_detail(m):
    # The four primary spokes get pipe runs, cantilever knees and inset bolted
    # panels. Everything is on their side or underneath, never in the path.
    for i in range(4):
        a = i * math.pi / 2
        nx, ny = math.cos(a), math.sin(a)
        tx, ty = -ny, nx
        for side in (-1, 1):
            start = (nx * 9.4 + tx * 1.48 * side, ny * 9.4 + ty * 1.48 * side, 4.36)
            end = (nx * 19 + tx * 1.48 * side, ny * 19 + ty * 1.48 * side, 4.36)
            m.beam(start, end, 0.095, "copper")
            for radius in (10.2, 13.1, 16.0, 18.2):
                p = (nx * radius + tx * 1.52 * side, ny * radius + ty * 1.52 * side, 4.1)
                m.box(p, (0.31, 0.31, 0.69), "steel")
                m.beam((p[0], p[1], 3.30),
                       (p[0] + nx * 1.04, p[1] + ny * 1.04, 3.86), 0.15, "armor")
                m.box((p[0], p[1], 4.43), (0.26, 0.26, 0.11), "ivory")
        for radius in (10.8, 12.5, 14.2, 15.9, 17.6):
            m.box((nx * radius, ny * radius, 5.515),
                  (1.33, 1.34, 0.055), "armor", rotation=a)


def _apron_detail(m):
    # Only apron edges carry hardware: the central two-meter docking ring stays
    # open. Cable reels, vacuum connectors and arrestor clamps replace seaport
    # furnishings and make this read as an orbital docking/service fixture.
    for side in (-1, 1):
        x = side * 4.32
        for y in (-34.60, -28.35):
            m.box((x, y, 5.73), (0.67, 1.0, 0.48), "navy")
            m.box((x, y, 6.04), (0.78, 0.76, 0.22), "ivory")
            m.box((x - side * 0.19, y, 6.18), (0.32, 0.54, 0.14), "copper")
            m.box((x - side * 0.38, y, 6.22), (0.12, 0.38, 0.14), "amber")
        m.box((side * 4.05, -26.6, 6.04), (0.89, 0.76, 1.10), "ivory")
        m.box((side * 4.05, -27.0, 6.12), (0.56, 0.045, 0.46), "navy")
        m.box((side * 4.05, -27.05, 6.19), (0.28, 0.04, 0.18), "cyan")
        m.tube([(side * 4.14, -26.58, 5.72), (side * 4.63, -27.30, 5.72),
                (side * 4.63, -29.5, 5.72)], 0.14, "black", segments=6)
        for y in (-27.55, -28.20, -28.85):
            m.box((side * 4.63, y, 5.65), (0.33, 0.12, 0.34), "copper")
        # Underside edge racks are the visible zero-G servicing area.
        for y in (-34.5, -32.7, -29.1, -27.3):
            m.box((side * 5.86, y, 4.20), (0.29, 0.85, 0.71), "steel")
            m.box((side * 6.03, y, 4.31), (0.12, 0.47, 0.24), "ivory")
        _beacon(m, (side * 5.64, -35.83, 6.48), height=1.23, color="cyan")
    for x in (-3.6, 3.6):
        m.box((x, -37.06, 4.75), (0.97, 0.18, 0.40), "navy")
        for dx in (-0.30, 0, 0.30):
            m.box((x + dx, -37.175, 4.75), (0.16, 0.055, 0.21), "amber")
    # A paired service ladder is integrated into one exterior apron edge.
    for x in (4.38, 4.91):
        m.beam((x, -37.10, 2.95), (x, -37.10, 5.47), 0.10, "armor")
        m.beam((x, -36.90, 4.75), (x, -37.10, 4.75), 0.12, "steel")
    for z in (3.12, 3.52, 3.92, 4.32, 4.72, 5.12):
        m.beam((4.38, -37.10, z), (4.91, -37.10, z), 0.09, "steel")


def add_station_detail(root):
    """Add one static detail mesh and a small animated traffic radar to root."""
    m = MeshBuilder("Core / detailed architecture and vacuum service fixtures")
    for i in range(8):
        a = i * math.tau / 8 + math.pi / 8
        x, y = round(math.cos(a) * 21 * 2) / 2, round(math.sin(a) * 21 * 2) / 2
        # The square pavilions have two exposed exterior faces. Recessed grids
        # hide the old flat emissive blocks, while retaining their warm palette.
        for angle, center in ((0 if x > 0 else math.pi, (x + (2.65 if x > 0 else -2.65), y, 8.02)),
                              (math.pi / 2 if y > 0 else -math.pi / 2, (x, y + (2.68 if y > 0 else -2.68), 8.02))):
            _window_bank(m, center, angle, width=3.66, height=1.24, columns=7, rows=2)
            # Lower inhabited pods receive their own smaller lit room rows.
            nx, ny = math.cos(angle), math.sin(angle)
            c = (x + nx * 2.20, y + ny * 2.20, 2.95)
            _window_bank(m, c, angle, width=2.55, height=0.84, columns=5, rows=2)
        _roof_equipment(m, x, y, i)
        # Emergency equipment on exterior walls beneath the window fascia.
        out = 1 if abs(x) > abs(y) else 0
        s = 1 if (x if out else y) > 0 else -1
        a = 0 if out and s > 0 else math.pi if out else math.pi / 2 * s
        nx, ny = math.cos(a), math.sin(a)
        c = (x + nx * 2.20, y + ny * 2.20, 6.88)
        _wall_box(m, c, a, 0.55, 0.15, 0, (0.63, 0.26, 0.45), "copper")
        _wall_box(m, c, a, 0.55, 0.30, 0, (0.32, 0.055, 0.23), "navy")
        _wall_box(m, c, a, -0.66, 0.13, 0, (0.75, 0.24, 0.39), "steel")
    _tower_detail(m)
    _bridge_detail(m)
    _apron_detail(m)
    detail = m.finish(parent=root)
    detail["role"] = "Modeled window reveals, HVAC, access hardware, gallery and vacuum docking fittings"
    # This small secondary traffic scanner is distinct from the large crown
    # dish already supplied by the core and has a visible mechanical pivot.
    x, y = -8.0, -19.5
    scanner = root_empty("Core / neighborhood traffic scanner", (x, y, 11.25))
    scanner.parent = root
    r = MeshBuilder("Core / traffic scanner array")
    r.cylinder((0, 0, 0.20), 0.23, 0.40, "steel", vertices=12)
    r.box((0, 0, 0.62), (1.19, 0.28, 0.46), "ivory")
    r.box((0, -0.18, 0.62), (0.98, 0.07, 0.30), "navy")
    for dx in (-0.34, 0, 0.34):
        r.box((dx, -0.23, 0.62), (0.13, 0.045, 0.19), "cyan")
    r.finish(parent=scanner)
    rotation_loop(scanner, frames=480, degrees=360, name="neighborhood_traffic_scan")
    return detail
