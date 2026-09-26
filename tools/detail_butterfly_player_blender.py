#!/usr/bin/env python3
"""Add modeled butterfly anatomy to the existing rigid player hull in Blender.

Called by build_combat_motion_blender.py after its original mesh is bound.
The source silhouette, seven sockets, four bones and animation clips survive.
All detail is merged into the original mesh and reuses its material slots.
Authoring coordinates match the original butterfly generator (X, aft, height),
at its original 0.85 scale; Blender stores X, forward, Z-up coordinates.
"""
import math

import bmesh
from mathutils import Vector

REVISION = 1
SCALE = 0.85
TRIANGLE_BUDGET = 9000


class ButterflyDetail:
    def __init__(self, obj):
        self.obj = obj
        self.bm = bmesh.new()
        self.bm.from_mesh(obj.data)
        self.weights = self.bm.verts.layers.deform.verify()
        self.bones = {g.name: g.index for g in obj.vertex_groups}
        assert all(b in self.bones for b in ("Body", "Port", "Starboard", "Weapon"))
        self.inverse = obj.matrix_world.inverted()
        self.materials = {}
        for index, material in enumerate(obj.data.materials):
            self.materials[material.name.split(".")[0]] = index
        self.palette = {
            "dark": "VoidMetal", "metal": "Gunmetal", "ivory": "IvoryHull",
            "glass": "BlueGlass", "energy": "CyanEnergy", "white": "HotCore",
            "trim": "SilverTrim" if "SilverTrim" in self.materials else "IvoryHull",
        }
        self.palette["wing"] = (
            "SolarOrange" if "SolarOrange" in self.materials
            else "BlueGlass" if "morpho" in obj.get("detail_variant", "")
            else "Gunmetal"
        )
        self.added_vertices = 0

    @staticmethod
    def point(point):
        x, aft, height = point
        return Vector((x * SCALE, -aft * SCALE, height * SCALE))

    def vertex(self, point, bone, world=False):
        coordinate = point if world else self.point(point)
        vertex = self.bm.verts.new(self.inverse @ coordinate)
        vertex[self.weights][self.bones[bone]] = 1.0
        self.added_vertices += 1
        return vertex

    def face(self, vertices, material, smooth=False):
        face = self.bm.faces.new(vertices)
        face.material_index = self.materials[self.palette[material]]
        face.smooth = smooth

    def plate(self, polygon, bottom, top, material, bone, bevel=0.08):
        """Closed armor cell with a chamfer around its top and lower edge."""
        points = list(polygon)
        area = sum(a[0] * b[1] - b[0] * a[1]
                   for a, b in zip(points, points[1:] + points[:1]))
        if area > 0:
            points.reverse()
        center = Vector((sum(p[0] for p in points) / len(points),
                         sum(p[1] for p in points) / len(points)))
        rings = []
        for height, shrink in ((bottom, 1.0 - bevel),
                               (bottom + (top - bottom) * 0.32, 1.0),
                               (top, 1.0 - bevel)):
            rings.append([self.vertex((*(center + (Vector(p) - center) * shrink), height), bone)
                          for p in points])
        self.face(list(reversed(rings[0])), "dark")
        for index in range(len(rings) - 1):
            for i in range(len(points)):
                j = (i + 1) % len(points)
                self.face([rings[index][i], rings[index][j],
                           rings[index + 1][j], rings[index + 1][i]], material)
        self.face(rings[-1], material)

    def ribbon(self, points, width, bottom, top, material, bone):
        for a, b in zip(points, points[1:]):
            a, b = Vector(a), Vector(b)
            direction = (b - a).normalized()
            normal = Vector((-direction.y, direction.x)) * width * 0.5
            self.plate([a + normal, b + normal, b - normal, a - normal],
                       bottom, top, material, bone, 0.08)

    def tube(self, start, end, radius, material, bone, segments=8):
        a, b = self.point(start), self.point(end)
        axis = (b - a).normalized()
        guide = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((0, 1, 0))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        rings = []
        for center in (a, b):
            rings.append([self.vertex(center + (u * math.cos(i * math.tau / segments)
                                               + v * math.sin(i * math.tau / segments)) * radius * SCALE,
                                      bone, world=True) for i in range(segments)])
        self.face(list(reversed(rings[0])), material)
        self.face(rings[1], material)
        for i in range(segments):
            j = (i + 1) % segments
            self.face([rings[0][i], rings[0][j], rings[1][j], rings[1][i]], material)

    def ring(self, center, axis, outer, inner, depth, material, bone, segments=16):
        """Hollow machined collar; also used for the butterfly eyespot sensors."""
        center = self.point(center)
        axis = Vector((axis[0], -axis[1], axis[2])).normalized()
        guide = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((0, 1, 0))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        rings = []
        for offset, radius in ((-depth * 0.5, outer), (depth * 0.5, outer),
                               (depth * 0.5, inner), (-depth * 0.5, inner)):
            rings.append([self.vertex(center + axis * offset * SCALE
                                      + (u * math.cos(i * math.tau / segments)
                                         + v * math.sin(i * math.tau / segments)) * radius * SCALE,
                                      bone, world=True) for i in range(segments)])
        for layer in range(4):
            following = (layer + 1) % 4
            for i in range(segments):
                j = (i + 1) % segments
                self.face([rings[layer][i], rings[layer][j],
                           rings[following][j], rings[following][i]], material)

    def finish(self):
        # Only the new component normals need rebuilding; the original hull's
        # face winding and its rigid weights are left intact.
        self.bm.normal_update()
        self.bm.to_mesh(self.obj.data)
        self.bm.free()
        self.obj.data.update()
        self.obj.data.calc_loop_triangles()
        triangles = len(self.obj.data.loop_triangles)
        assert triangles <= TRIANGLE_BUDGET, (triangles, TRIANGLE_BUDGET)
        self.obj.data["butterfly_detail_revision"] = REVISION
        self.obj["detail_notes"] = "Layered wing scales, branching spars, eyespot sensors, thorax canopy, articulated abdomen and tail turbines."
        return {"triangles": triangles, "vertices": len(self.obj.data.vertices),
                "added_vertices": self.added_vertices,
                "materials": len(self.obj.data.materials)}


def add_detail(obj, variant="player_butterfly"):
    """Enhance one bound hull once; no socket or armature transform is changed."""
    if obj.data.get("butterfly_detail_revision") == REVISION:
        obj.data.calc_loop_triangles()
        return {"triangles": len(obj.data.loop_triangles), "already_detailed": True}
    obj["detail_variant"] = variant
    detail = ButterflyDetail(obj)
    fore_center = Vector((0.55, -0.37))
    fore_edge = [(0.38, -0.80), (1.49, -1.18), (2.03, -0.89),
                 (2.16, -0.46), (1.83, -0.12), (1.04, 0.17), (0.34, 0.035)]
    hind_center = Vector((0.63, 0.61))
    hind_edge = [(0.28, 0.25), (0.97, 0.37), (1.30, 0.68),
                 (1.29, 0.98), (1.01, 1.16), (0.78, 1.15), (0.30, 0.85)]
    for side, bone in ((-1, "Port"), (1, "Starboard")):
        def mirror(point):
            return (side * point[0], point[1])

        # The gaps between fan-shaped armor cells expose the original wing.
        # Raised branching spars echo actual butterfly venation.
        for center, edge, base_height in ((fore_center, fore_edge, 0.10),
                                          (hind_center, hind_edge, 0.082)):
            for index in range(len(edge) - 1):
                polygon = [center, Vector(edge[index]), Vector(edge[index + 1])]
                centroid = sum(polygon, Vector((0.0, 0.0))) / 3.0
                inset = [centroid + (p - centroid) * 0.86 for p in polygon]
                material = "trim" if index == 2 else "wing"
                detail.plate([mirror(p) for p in inset], base_height,
                             base_height + 0.075 + 0.012 * (index % 2), material, bone)
            for index, endpoint in enumerate(edge):
                detail.ribbon([mirror(center), mirror(endpoint)], 0.025,
                              base_height - 0.005, base_height + 0.03, "dark", bone)
                if index in (1, 4):
                    tip = center.lerp(Vector(endpoint), 0.7)
                    detail.ribbon([mirror(center), mirror(tip)], 0.009,
                                  base_height + 0.031, base_height + 0.046, "energy", bone)
            for a, b in zip(edge, edge[1:]):
                detail.ribbon([mirror(a), mirror(b)], 0.032,
                              base_height - 0.012, base_height + 0.025, "trim", bone)
                mid = (Vector(a) + Vector(b)) * 0.5
                detail.tube((side * mid.x, mid.y, base_height + 0.027),
                            (side * mid.x, mid.y, base_height + 0.047),
                            0.022, "dark", bone, 6)

        # A vent cassette and a secondary overlap on each broad forewing.
        vent = [(1.48, -0.69), (1.76, -0.72), (1.94, -0.55), (1.60, -0.43)]
        detail.plate([mirror(p) for p in vent], 0.172, 0.195, "dark", bone)
        for index in range(4):
            y = -0.66 + index * 0.045
            detail.ribbon([mirror((1.59, y)), mirror((1.78, y - 0.045))],
                          0.023, 0.195, 0.214, "trim", bone)

        # Eyespots become concentric mechanical sensor irises with radial studs.
        sensor = (side * 0.92, 0.85, 0.14)
        detail.ring(sensor, (0, 0, 1), 0.255, 0.19, 0.08, "dark", bone)
        detail.ring((sensor[0], sensor[1], 0.192), (0, 0, 1),
                    0.211, 0.165, 0.026, "trim", bone)
        detail.ring((sensor[0], sensor[1], 0.204), (0, 0, 1),
                    0.158, 0.096, 0.022, "energy", bone)
        detail.tube((sensor[0], sensor[1], 0.17), (sensor[0], sensor[1], 0.218),
                    0.082, "glass", bone, 12)
        for index in range(6):
            angle = index * math.tau / 6.0
            x = sensor[0] + math.cos(angle) * 0.229
            y = sensor[1] + math.sin(angle) * 0.229
            detail.tube((x, y, 0.18), (x, y, 0.205), 0.018, "trim", bone, 6)

        # Swallowtail streamers retain their location and end in hollow turbines.
        detail.ribbon([mirror((0.78, 1.03)), mirror((1.14, 1.49)), mirror((1.24, 1.91))],
                      0.072, 0.062, 0.135, "metal", bone)
        for aft, radius, inner, material in ((1.78, 0.136, 0.09, "dark"),
                                             (1.90, 0.145, 0.09, "trim"),
                                             (2.045, 0.138, 0.098, "metal"),
                                             (2.17, 0.142, 0.096, "trim")):
            detail.ring((side * 1.24, aft, 0.02), (0, 1, 0),
                        radius, inner, 0.046, material, bone, 12)
        detail.ring((side * 1.24, 2.179, 0.02), (0, 1, 0),
                    0.093, 0.058, 0.014, "energy", bone, 12)
        for offset in (-0.075, 0.075):
            detail.tube((side * 1.24 + offset, 1.80, 0.12),
                        (side * 1.24 + offset, 2.14, 0.12), 0.022, "dark", bone, 6)

        # Wing-root knuckles and antenna collars make the articulation legible.
        detail.ring((side * 0.25, -0.10, 0.13), (0, 0, 1),
                    0.10, 0.056, 0.12, "metal", bone, 12)
        detail.tube((side * 0.25, -0.10, 0.185), (side * 0.25, -0.10, 0.212),
                    0.045, "trim", bone, 8)
        detail.tube((side * 0.11, -1.73, 0.086), (side * 0.37, -2.50, 0.086),
                    0.026, "trim", "Weapon", 8)
        for aft, x in ((-1.90, 0.166), (-2.19, 0.262), (-2.45, 0.348)):
            detail.ring((side * x, aft, 0.086), (side * 0.32, -1, 0),
                        0.045, 0.026, 0.066, "dark", "Weapon", 8)
        detail.ring((side * 0.40, -2.65, 0.055), (0, -1, 0),
                    0.063, 0.04, 0.028, "trim", "Weapon", 10)

    # Raised thorax fairing, glass canopy frame and segmented energy abdomen.
    saddle = [(-0.24, -0.92), (0.0, -1.18), (0.24, -0.92),
              (0.25, -0.22), (0.13, -0.02), (-0.13, -0.02), (-0.25, -0.22)]
    detail.plate(saddle, 0.14, 0.205, "dark", "Body")
    canopy = [(-0.16, -0.98), (0.0, -1.12), (0.16, -0.98),
              (0.18, -0.43), (0.105, -0.18), (-0.105, -0.18), (-0.18, -0.43)]
    detail.plate(canopy, 0.207, 0.30, "glass", "Body", 0.18)
    for side in (-1, 1):
        detail.ribbon([(side * 0.09, -0.19), (side * 0.205, -0.47),
                       (side * 0.182, -0.91), (0.0, -1.13)],
                      0.026, 0.287, 0.32, "trim", "Body")
        detail.ribbon([(side * 0.025, -0.08), (side * 0.065, 0.02)],
                      0.018, 0.205, 0.224, "energy", "Body")
    detail.ribbon([(-0.178, -0.54), (0.178, -0.54)], 0.023, 0.3, 0.323, "metal", "Body")
    for index in range(6):
        aft = 0.20 + index * 0.24
        width = 0.164 - index * 0.015
        polygon = [(-width, aft - 0.055), (width, aft - 0.055),
                   (width * 0.72, aft + 0.115), (-width * 0.72, aft + 0.115)]
        height = 0.205 - index * 0.021
        detail.plate(polygon, height - 0.045, height, "ivory", "Body")
        detail.ribbon([(-width * 0.64, aft + 0.018), (width * 0.64, aft + 0.018)],
                      0.044, height + 0.003, height + 0.028, "energy", "Body")
    for side in (-1, 1):
        detail.tube((side * 0.175, -0.10, 0.085), (side * 0.095, 1.2, 0.03),
                    0.025, "dark", "Body", 8)
    return detail.finish()
