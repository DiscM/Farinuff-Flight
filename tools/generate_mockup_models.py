#!/usr/bin/env python3
"""Generate the Farinuff Flight high-quality 3D mockup fleet.

The output is a set of self-contained glTF 2.0 binary files with:

- continuous lofted hulls instead of stacked triangular shards;
- beveled, closed wing and armor meshes;
- welded indexed vertices and weighted smooth normals;
- embedded PBR/emissive materials; and
- named empty nodes for gameplay sockets.

The GLB exporter uses only Python's standard library. Pillow is optional and
is used for the checked-in antialiased preview renders when available.
"""

from __future__ import annotations

import json
import math
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "models" / "mockups"
PREVIEW_DIR = OUTPUT_DIR / "previews"
TAU = math.tau
EPSILON = 1.0e-9

Vec2 = tuple[float, float]
Vec3 = tuple[float, float, float]


def vec_add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vec_sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vec_cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def vec_dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def vec_length(v: Vec3) -> float:
    return math.sqrt(max(vec_dot(v, v), EPSILON))


def vec_normalize(v: Vec3) -> Vec3:
    length = vec_length(v)
    return (v[0] / length, v[1] / length, v[2] / length)


def vec_scale(v: Vec3, factor: float) -> Vec3:
    return (v[0] * factor, v[1] * factor, v[2] * factor)


def scale_footprint(
    points: Sequence[Vec2],
    factor: float,
    center: Vec2 | None = None,
) -> list[Vec2]:
    if center is None:
        center = (
            sum(point[0] for point in points) / len(points),
            sum(point[1] for point in points) / len(points),
        )
    return [
        (
            center[0] + (point[0] - center[0]) * factor,
            center[1] + (point[1] - center[1]) * factor,
        )
        for point in points
    ]


def mirrored(points: Sequence[Vec2]) -> list[Vec2]:
    return [(-x, z) for x, z in reversed(points)]


def rotated(points: Sequence[Vec2], angle: float) -> list[Vec2]:
    """Rotate a footprint around the origin without changing its winding."""
    cosine = math.cos(angle)
    sine = math.sin(angle)
    return [
        (x * cosine - z * sine, x * sine + z * cosine)
        for x, z in points
    ]


@dataclass(frozen=True)
class Material:
    name: str
    color: tuple[float, float, float]
    metallic: float = 0.35
    roughness: float = 0.48
    emission: tuple[float, float, float] = (0.0, 0.0, 0.0)


MATERIALS = {
    "ivory": Material("IvoryHull", (0.76, 0.84, 0.93), 0.72, 0.27),
    "steel": Material("Gunmetal", (0.20, 0.27, 0.37), 0.82, 0.29),
    "silver": Material("SilverTrim", (0.50, 0.59, 0.70), 0.88, 0.22),
    "dark": Material("VoidMetal", (0.025, 0.035, 0.065), 0.78, 0.24),
    "cyan": Material("CyanEnergy", (0.035, 0.58, 0.86), 0.18, 0.21, (0.01, 0.42, 0.72)),
    "blue": Material("BlueGlass", (0.025, 0.10, 0.38), 0.28, 0.15, (0.005, 0.03, 0.13)),
    "red": Material("CrimsonHull", (0.62, 0.025, 0.075), 0.60, 0.32),
    "scarlet": Material("ScarletTrim", (0.92, 0.035, 0.09), 0.42, 0.27, (0.15, 0.002, 0.008)),
    "orange": Material("SolarOrange", (0.95, 0.20, 0.015), 0.50, 0.29, (0.22, 0.012, 0.0)),
    "yellow": Material("ReactorGold", (0.94, 0.65, 0.035), 0.30, 0.22, (0.36, 0.18, 0.004)),
    "green": Material("BomberGreen", (0.035, 0.25, 0.075), 0.58, 0.38),
    "lime": Material("ToxicLime", (0.30, 0.76, 0.075), 0.24, 0.25, (0.07, 0.29, 0.004)),
    "purple": Material("BulwarkPurple", (0.24, 0.035, 0.48), 0.66, 0.31),
    "violet": Material("VioletArmor", (0.42, 0.065, 0.70), 0.55, 0.29, (0.035, 0.002, 0.08)),
    "magenta": Material("MagentaEnergy", (0.84, 0.025, 0.48), 0.24, 0.20, (0.38, 0.002, 0.19)),
    "white": Material("HotCore", (0.96, 0.98, 1.0), 0.0, 0.14, (0.62, 0.70, 0.82)),
}


@dataclass
class Triangle:
    points: tuple[Vec3, Vec3, Vec3]
    normal: Vec3
    weighted_normal: Vec3
    material: str
    part: str
    smooth_group: str | None


@dataclass
class Model:
    name: str
    display_name: str
    triangles: list[Triangle] = field(default_factory=list)
    sockets: dict[str, Vec3] = field(default_factory=dict)

    def add_triangle(
        self,
        points: tuple[Vec3, Vec3, Vec3],
        material: str,
        part: str,
        smooth_group: str | None = None,
    ) -> None:
        weighted_normal = vec_cross(vec_sub(points[1], points[0]), vec_sub(points[2], points[0]))
        if vec_dot(weighted_normal, weighted_normal) <= EPSILON:
            return
        self.triangles.append(
            Triangle(
                points=points,
                normal=vec_normalize(weighted_normal),
                weighted_normal=weighted_normal,
                material=material,
                part=part,
                smooth_group=smooth_group,
            )
        )

    def add_face(
        self,
        points: Iterable[Vec3],
        material: str,
        part: str,
        smooth_group: str | None = None,
    ) -> None:
        vertices = tuple(points)
        for index in range(1, len(vertices) - 1):
            self.add_triangle(
                (vertices[0], vertices[index], vertices[index + 1]),
                material,
                part,
                smooth_group,
            )

    def add_quad(
        self,
        points: Sequence[Vec3],
        material: str,
        part: str,
        smooth_group: str | None = None,
    ) -> None:
        self.add_triangle((points[0], points[1], points[2]), material, part, smooth_group)
        self.add_triangle((points[0], points[2], points[3]), material, part, smooth_group)

    def add_beveled_plate(
        self,
        footprint: Sequence[Vec2],
        bottom: float,
        top: float,
        material: str,
        part: str,
        cap_scale: float = 0.88,
    ) -> None:
        """Add a closed three-ring plate with crisp, artifact-free bevels."""
        center = (
            sum(point[0] for point in footprint) / len(footprint),
            sum(point[1] for point in footprint) / len(footprint),
        )
        cap = scale_footprint(footprint, cap_scale, center)
        bottom_ring = [(x, bottom, z) for x, z in cap]
        outer_ring = [(x, (bottom + top) * 0.5, z) for x, z in footprint]
        top_ring = [(x, top, z) for x, z in cap]

        self.add_face(bottom_ring, material, part)
        self.add_face(reversed(top_ring), material, part)
        count = len(footprint)
        for index in range(count):
            next_index = (index + 1) % count
            self.add_quad(
                [
                    bottom_ring[index],
                    outer_ring[index],
                    outer_ring[next_index],
                    bottom_ring[next_index],
                ],
                material,
                part,
            )
            self.add_quad(
                [
                    outer_ring[index],
                    top_ring[index],
                    top_ring[next_index],
                    outer_ring[next_index],
                ],
                material,
                part,
            )

    def add_loft(
        self,
        sections: Sequence[tuple[float, float, float, float]],
        material: str,
        part: str,
        radial_segments: int = 12,
        center_x: float = 0.0,
    ) -> None:
        """Add a smooth closed fuselage running along Z.

        Each section is ``(z, half_width_x, center_y, half_height_y)``.
        """
        rings: list[list[Vec3]] = []
        for z, radius_x, center_y, radius_y in sections:
            rings.append(
                [
                    (
                        center_x + math.cos(TAU * index / radial_segments) * radius_x,
                        center_y + math.sin(TAU * index / radial_segments) * radius_y,
                        z,
                    )
                    for index in range(radial_segments)
                ]
            )
        smooth_group = f"{part}:loft"
        for section_index in range(len(rings) - 1):
            current = rings[section_index]
            following = rings[section_index + 1]
            for index in range(radial_segments):
                next_index = (index + 1) % radial_segments
                self.add_quad(
                    [
                        current[index],
                        current[next_index],
                        following[next_index],
                        following[index],
                    ],
                    material,
                    part,
                    smooth_group,
                )
        self.add_face(reversed(rings[0]), material, part, f"{part}:front_cap")
        self.add_face(rings[-1], material, part, f"{part}:rear_cap")

    def add_engine(
        self,
        center_x: float,
        center_y: float,
        front_z: float,
        length: float,
        radius: float,
        energy_material: str,
        part: str,
    ) -> None:
        """Add an efficient six-sided Z-axis casing and emissive exhaust cap."""
        casing_sections = [
            (front_z, radius * 0.82, center_y, radius * 0.82),
            (front_z + length, radius * 0.88, center_y, radius * 0.88),
        ]
        self.add_loft(casing_sections, "steel", f"{part}_casing", 6, center_x)
        energy_ring = [
            (
                center_x + math.cos(TAU * index / 6) * radius * 0.46,
                center_y + math.sin(TAU * index / 6) * radius * 0.46,
                front_z + length + 0.006,
            )
            for index in range(6)
        ]
        self.add_face(
            energy_ring,
            energy_material,
            f"{part}_energy",
        )

    def add_ellipsoid(
        self,
        center: Vec3,
        radii: Vec3,
        material: str,
        part: str,
        rings: int = 7,
        segments: int = 14,
    ) -> None:
        grid: list[list[Vec3]] = []
        for ring_index in range(rings + 1):
            latitude = -math.pi * 0.5 + math.pi * ring_index / rings
            cos_latitude = math.cos(latitude)
            sin_latitude = math.sin(latitude)
            grid.append(
                [
                    (
                        center[0] + radii[0] * cos_latitude * math.cos(TAU * index / segments),
                        center[1] + radii[1] * sin_latitude,
                        center[2] + radii[2] * cos_latitude * math.sin(TAU * index / segments),
                    )
                    for index in range(segments)
                ]
            )
        smooth_group = f"{part}:ellipsoid"
        for ring_index in range(rings):
            current = grid[ring_index]
            following = grid[ring_index + 1]
            for index in range(segments):
                next_index = (index + 1) % segments
                self.add_quad(
                    [
                        current[index],
                        following[index],
                        following[next_index],
                        current[next_index],
                    ],
                    material,
                    part,
                    smooth_group,
                )

    def add_socket(self, name: str, position: Vec3) -> None:
        self.sockets[name] = position

    def scale_uniform(self, factor: float) -> None:
        """Bake a positive uniform scale into geometry and socket positions."""
        if factor <= 0.0:
            raise ValueError("Model scale must be positive")
        for triangle in self.triangles:
            triangle.points = tuple(
                vec_scale(point, factor) for point in triangle.points
            )  # type: ignore[assignment]
            triangle.weighted_normal = vec_scale(
                triangle.weighted_normal, factor * factor
            )
        self.sockets = {
            name: vec_scale(position, factor)
            for name, position in self.sockets.items()
        }

    def validate(self) -> None:
        if not self.triangles:
            raise ValueError(f"{self.name} contains no triangles")
        seen = set()
        for triangle in self.triangles:
            if vec_dot(triangle.weighted_normal, triangle.weighted_normal) <= EPSILON:
                raise ValueError(f"{self.name}/{triangle.part} contains a degenerate triangle")
            values = tuple(round(value, 7) for point in triangle.points for value in point)
            if not all(math.isfinite(value) for value in values):
                raise ValueError(f"{self.name}/{triangle.part} contains a non-finite vertex")
            canonical = tuple(sorted(tuple(round(value, 6) for value in point) for point in triangle.points))
            duplicate_key = (triangle.material, canonical)
            if duplicate_key in seen:
                raise ValueError(f"{self.name}/{triangle.part} contains duplicate coplanar geometry")
            seen.add(duplicate_key)


def add_engine_pair(
    model: Model,
    x: float,
    y: float,
    front_z: float,
    length: float,
    radius: float,
    energy_material: str,
    part: str,
) -> None:
    for side, suffix in ((-1.0, "Left"), (1.0, "Right")):
        engine_x = x * side
        model.add_engine(
            engine_x,
            y,
            front_z,
            length,
            radius,
            energy_material,
            f"{part}_{suffix.lower()}",
        )
        model.add_socket(f"Socket_Engine{suffix}", (engine_x, y, front_z + length + 0.03))


def build_player() -> Model:
    model = Model("player_ship_mockup", "PLAYER // STARLANCE Mk II")
    model.add_loft(
        [
            (-2.42, 0.045, 0.00, 0.045),
            (-1.78, 0.26, 0.04, 0.20),
            (-0.82, 0.46, 0.06, 0.30),
            (0.22, 0.43, 0.04, 0.29),
            (1.10, 0.34, 0.01, 0.24),
            (1.58, 0.18, 0.00, 0.15),
        ],
        "ivory",
        "player_fuselage",
        6,
    )
    wing = [(0.31, -0.72), (1.84, 0.05), (1.66, 0.66), (1.20, 1.02), (0.38, 0.61)]
    model.add_beveled_plate(wing, -0.18, 0.10, "steel", "player_wing_right")
    model.add_beveled_plate(mirrored(wing), -0.18, 0.10, "steel", "player_wing_left")
    model.add_loft(
        [
            (-1.43, 0.05, 0.27, 0.035),
            (-1.05, 0.20, 0.33, 0.14),
            (-0.30, 0.24, 0.37, 0.18),
            (0.42, 0.15, 0.32, 0.12),
            (0.70, 0.04, 0.27, 0.035),
        ],
        "blue",
        "player_canopy",
        6,
    )
    spine = [(-0.10, 0.02), (0.10, 0.02), (0.13, 1.14), (0.0, 1.39), (-0.13, 1.14)]
    model.add_beveled_plate(spine, 0.25, 0.35, "cyan", "player_energy_spine", 0.78)
    add_engine_pair(model, 0.27, -0.02, 1.08, 0.52, 0.18, "cyan", "player_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.08, -2.48))
    model.add_socket("Socket_MuzzleLeft", (-1.01, 0.18, -0.42))
    model.add_socket("Socket_MuzzleRight", (1.01, 0.18, -0.42))
    model.add_socket("Socket_UpgradeLeft", (-1.25, 0.18, 0.28))
    model.add_socket("Socket_UpgradeRight", (1.25, 0.18, 0.28))
    return model


def build_player_upgrade_twin_cannons() -> Model:
    """Build a paired, identity-aligned cannon kit for the player hull."""
    model = Model(
        "player_upgrade_twin_cannons",
        "PLAYER UPGRADE // TWIN CANNONS",
    )
    cannon = [
        (0.76, -1.74),
        (1.02, -1.74),
        (1.08, -0.62),
        (0.73, -0.62),
    ]
    model.add_beveled_plate(
        cannon,
        0.16,
        0.32,
        "steel",
        "twin_cannon_right",
        0.88,
    )
    model.add_beveled_plate(
        mirrored(cannon),
        0.16,
        0.32,
        "steel",
        "twin_cannon_left",
        0.88,
    )
    model.add_beveled_plate(
        [(-0.42, -1.05), (0.42, -1.05), (0.34, -0.72), (-0.34, -0.72)],
        0.22,
        0.30,
        "yellow",
        "twin_cannon_power_bus",
        0.88,
    )
    model.add_socket("Socket_MuzzleLeft", (-0.899, 0.28, -1.733))
    model.add_socket("Socket_MuzzleRight", (0.899, 0.28, -1.733))
    return model


def build_player_upgrade_auto_aim() -> Model:
    """Build the fixed dorsal sensor used by the Auto-Aim upgrade."""
    model = Model(
        "player_upgrade_auto_aim",
        "PLAYER UPGRADE // AUTO-AIM CORE",
    )
    sensor = [
        (0.0, -2.64),
        (0.38, -2.34),
        (0.34, -1.92),
        (0.0, -1.72),
        (-0.34, -1.92),
        (-0.38, -2.34),
    ]
    model.add_beveled_plate(
        sensor,
        0.36,
        0.52,
        "green",
        "auto_aim_sensor",
        0.86,
    )
    model.add_socket("Socket_AimSensor", (0.0, 0.56, -2.18))
    return model


def build_player_upgrade_hull_plating() -> Model:
    """Build paired armor shells that remain inside the legacy visual envelope."""
    model = Model(
        "player_upgrade_hull_plating",
        "PLAYER UPGRADE // HULL PLATING",
    )
    armor = [
        (0.52, -0.94),
        (2.15, -0.34),
        (2.34, 0.42),
        (1.42, 1.32),
        (1.10, 0.72),
    ]
    model.add_beveled_plate(
        armor,
        -0.24,
        0.06,
        "silver",
        "hull_plating_right",
        0.91,
    )
    model.add_beveled_plate(
        mirrored(armor),
        -0.24,
        0.06,
        "silver",
        "hull_plating_left",
        0.91,
    )
    model.add_socket("Socket_ArmorLeft", (-1.64, 0.18, 0.28))
    model.add_socket("Socket_ArmorRight", (1.64, 0.18, 0.28))
    return model


def build_player_upgrade_afterburner() -> Model:
    """Build the paired auxiliary engines for the Afterburner upgrade."""
    model = Model(
        "player_upgrade_afterburner",
        "PLAYER UPGRADE // AFTERBURNER",
    )
    add_engine_pair(
        model,
        0.72,
        -0.18,
        0.72,
        1.58,
        0.22,
        "orange",
        "afterburner_booster",
    )
    return model


def build_player_upgrade_spread_shot() -> Model:
    """Build fixed wing-tip emitters for the permanent spread-shot kit."""
    model = Model(
        "player_upgrade_spread_shot",
        "PLAYER UPGRADE // SPREAD EMITTERS",
    )
    emitter = [
        (1.82, -0.24),
        (2.92, -0.16),
        (3.06, 0.12),
        (1.88, 0.30),
    ]
    model.add_beveled_plate(
        emitter,
        0.14,
        0.26,
        "magenta",
        "spread_emitter_right",
        0.88,
    )
    model.add_beveled_plate(
        mirrored(emitter),
        0.14,
        0.26,
        "magenta",
        "spread_emitter_left",
        0.88,
    )
    model.add_socket("Socket_MuzzleLeft", (-3.081, 0.20, 0.064))
    model.add_socket("Socket_MuzzleRight", (3.081, 0.20, 0.064))
    return model


def build_player_upgrade_shield_burst() -> Model:
    """Build paired dorsal shield projectors."""
    model = Model(
        "player_upgrade_shield_burst",
        "PLAYER UPGRADE // SHIELD PROJECTORS",
    )
    projector = [
        (1.12, -0.62),
        (1.90, -0.34),
        (2.04, 0.24),
        (1.58, 0.64),
        (1.14, 0.32),
    ]
    model.add_beveled_plate(
        projector,
        0.32,
        0.44,
        "cyan",
        "shield_projector_right",
        0.88,
    )
    model.add_beveled_plate(
        mirrored(projector),
        0.32,
        0.44,
        "cyan",
        "shield_projector_left",
        0.88,
    )
    model.add_socket("Socket_ShieldLeft", (-1.72, 0.40, 0.18))
    model.add_socket("Socket_ShieldRight", (1.72, 0.40, 0.18))
    return model


def build_player_upgrade_magnet_field() -> Model:
    """Build angular induction rails for the permanent magnet field."""
    model = Model(
        "player_upgrade_magnet_field",
        "PLAYER UPGRADE // MAGNET RAILS",
    )
    rail = [
        (1.58, 0.72),
        (2.68, 0.92),
        (2.82, 1.24),
        (1.64, 1.08),
    ]
    model.add_beveled_plate(
        rail,
        0.14,
        0.26,
        "yellow",
        "magnet_rail_right",
        0.88,
    )
    model.add_beveled_plate(
        mirrored(rail),
        0.14,
        0.26,
        "yellow",
        "magnet_rail_left",
        0.88,
    )
    model.add_socket("Socket_MagnetLeft", (-2.30, 0.29, 1.08))
    model.add_socket("Socket_MagnetRight", (2.30, 0.29, 1.08))
    return model


def build_player_upgrade_overclock() -> Model:
    """Build a compact dorsal reactor with a coherent closed housing."""
    model = Model(
        "player_upgrade_overclock",
        "PLAYER UPGRADE // OVERCLOCK REACTOR",
    )
    housing = [
        (0.0, -0.02),
        (0.48, 0.26),
        (0.46, 1.02),
        (0.20, 1.42),
        (-0.20, 1.42),
        (-0.46, 1.02),
        (-0.48, 0.26),
    ]
    model.add_beveled_plate(
        housing,
        0.34,
        0.48,
        "lime",
        "overclock_reactor",
        0.88,
    )
    model.add_socket("Socket_OverclockCore", (0.0, 0.52, 0.80))
    return model


def build_player_upgrade_rear_gunner() -> Model:
    """Build a single rear-facing cannon in full player-local coordinates."""
    model = Model(
        "player_upgrade_rear_gunner",
        "PLAYER UPGRADE // REAR GUNNER",
    )
    gunner = [
        (0.0, 2.90),
        (0.34, 2.46),
        (0.30, 1.66),
        (0.0, 1.52),
        (-0.30, 1.66),
        (-0.34, 2.46),
    ]
    model.add_beveled_plate(
        gunner,
        0.16,
        0.30,
        "scarlet",
        "rear_gunner",
        0.88,
    )
    model.add_socket("Socket_MuzzleRear", (0.0, 0.34, 2.888))
    return model


def build_player_drone_escort() -> Model:
    """Build the standalone escort craft as a low-poly gameplay proxy."""
    model = Model(
        "player_drone_escort",
        "PLAYER UPGRADE // DRONE ESCORT",
    )
    model.add_loft(
        [
            (-0.72, 0.04, 0.00, 0.04),
            (-0.34, 0.24, 0.05, 0.17),
            (0.58, 0.12, 0.00, 0.10),
        ],
        "cyan",
        "drone_fuselage",
        6,
    )
    wing = [(0.16, -0.22), (0.72, 0.08), (0.54, 0.50)]
    model.add_beveled_plate(
        wing,
        -0.10,
        0.08,
        "steel",
        "drone_wing_right",
        0.78,
    )
    model.add_beveled_plate(
        mirrored(wing),
        -0.10,
        0.08,
        "steel",
        "drone_wing_left",
        0.78,
    )
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.10, -0.76))
    model.add_socket("Socket_Engine", (0.0, -0.02, 0.62))
    return model


def build_basic() -> Model:
    model = Model("basic_enemy_mockup", "BASIC // REDJACK Mk II")
    model.add_loft(
        [
            (-1.78, 0.04, 0.00, 0.04),
            (-1.20, 0.28, 0.02, 0.20),
            (-0.30, 0.54, 0.04, 0.31),
            (0.62, 0.35, 0.01, 0.25),
            (1.18, 0.10, 0.00, 0.10),
        ],
        "red",
        "basic_fuselage",
        6,
    )
    wing = [(0.32, -0.48), (1.40, 0.05), (1.23, 0.59), (0.44, 0.39)]
    model.add_beveled_plate(wing, -0.15, 0.09, "red", "basic_wing_right")
    model.add_beveled_plate(mirrored(wing), -0.15, 0.09, "red", "basic_wing_left")
    core = [(0.0, -0.92), (0.28, -0.30), (0.22, 0.12), (0.0, 0.30), (-0.22, 0.12), (-0.28, -0.30)]
    model.add_beveled_plate(core, 0.27, 0.48, "yellow", "basic_reactor", 0.75)
    add_engine_pair(model, 0.25, -0.01, 0.72, 0.42, 0.15, "magenta", "basic_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.08, -1.84))
    return model


def build_fast() -> Model:
    model = Model("fast_enemy_mockup", "FAST // RAZOR Mk II")
    model.add_loft(
        [
            (-2.30, 0.025, 0.00, 0.025),
            (-1.58, 0.16, 0.03, 0.13),
            (-0.42, 0.34, 0.05, 0.24),
            (0.78, 0.24, 0.01, 0.18),
            (1.62, 0.07, 0.00, 0.07),
        ],
        "orange",
        "fast_fuselage",
        6,
    )
    wing = [(0.18, -0.70), (1.48, 0.46), (1.19, 0.84), (0.28, 0.39)]
    model.add_beveled_plate(wing, -0.13, 0.06, "dark", "fast_wing_right")
    model.add_beveled_plate(mirrored(wing), -0.13, 0.06, "dark", "fast_wing_left")
    edge = [(0.31, -0.39), (1.26, 0.47), (1.13, 0.60), (0.39, 0.15)]
    model.add_beveled_plate(edge, 0.07, 0.14, "scarlet", "fast_edge_right", 0.80)
    model.add_beveled_plate(mirrored(edge), 0.07, 0.14, "scarlet", "fast_edge_left", 0.80)
    model.add_loft(
        [
            (-1.38, 0.025, 0.21, 0.02),
            (-0.92, 0.12, 0.27, 0.09),
            (-0.12, 0.14, 0.29, 0.11),
            (0.40, 0.035, 0.22, 0.025),
        ],
        "cyan",
        "fast_canopy",
        6,
    )
    add_engine_pair(model, 0.15, -0.01, 1.12, 0.44, 0.13, "orange", "fast_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.07, -2.36))
    return model


def build_bomber() -> Model:
    model = Model("bomber_enemy_mockup", "BOMBER // MANTIS Mk II")
    model.add_loft(
        [
            (-1.70, 0.05, 0.00, 0.05),
            (-1.12, 0.40, 0.03, 0.24),
            (-0.18, 0.68, 0.06, 0.35),
            (0.84, 0.54, 0.01, 0.30),
            (1.42, 0.20, -0.01, 0.16),
        ],
        "green",
        "bomber_fuselage",
        8,
    )
    wing = [(0.38, -0.90), (2.20, -0.12), (2.02, 0.76), (1.50, 1.08), (0.50, 0.53)]
    model.add_beveled_plate(wing, -0.21, 0.09, "green", "bomber_wing_right")
    model.add_beveled_plate(mirrored(wing), -0.21, 0.09, "green", "bomber_wing_left")
    model.add_ellipsoid((0.0, 0.35, -0.45), (0.28, 0.16, 0.48), "lime", "bomber_canopy", 4, 8)
    for side, suffix in ((-1.0, "left"), (1.0, "right")):
        x = 0.54 * side
        bay = [(x - 0.13, 0.48), (x + 0.13, 0.48), (x + 0.12, 1.03), (x - 0.12, 1.03)]
        model.add_beveled_plate(bay, -0.31, -0.12, "yellow", f"bomber_bay_{suffix}")
    add_engine_pair(model, 0.33, -0.02, 0.98, 0.47, 0.18, "lime", "bomber_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.08, -1.78))
    model.add_socket("Socket_BombBayLeft", (-0.54, -0.34, 0.74))
    model.add_socket("Socket_BombBayRight", (0.54, -0.34, 0.74))
    return model


def build_tank() -> Model:
    model = Model("tank_enemy_mockup", "TANK // BULWARK Mk II")
    body = [
        (0.0, -1.58),
        (0.92, -1.08),
        (1.38, -0.32),
        (1.38, 0.86),
        (0.72, 1.52),
        (-0.72, 1.52),
        (-1.38, 0.86),
        (-1.38, -0.32),
        (-0.92, -1.08),
    ]
    model.add_beveled_plate(body, -0.34, 0.36, "purple", "tank_main_hull", 0.84)
    armor = [(0.88, -0.88), (1.76, -0.58), (1.84, 0.96), (1.26, 1.40), (0.92, 0.74)]
    model.add_beveled_plate(armor, -0.39, 0.26, "violet", "tank_armor_right", 0.84)
    model.add_beveled_plate(mirrored(armor), -0.39, 0.26, "violet", "tank_armor_left", 0.84)
    model.add_beveled_plate(
        [(-0.86, -0.48), (0.86, -0.48), (0.76, 0.36), (-0.76, 0.36)],
        0.37,
        0.54,
        "dark",
        "tank_core_mount",
        0.86,
    )
    model.add_ellipsoid((0.0, 0.62, -0.05), (0.38, 0.25, 0.38), "white", "tank_reactor", 4, 8)
    rail = [(0.96, -0.66), (1.20, -0.61), (1.22, 0.48), (0.98, 0.52)]
    model.add_beveled_plate(rail, 0.27, 0.43, "magenta", "tank_rail_right")
    model.add_beveled_plate(mirrored(rail), 0.27, 0.43, "magenta", "tank_rail_left")
    add_engine_pair(model, 0.50, -0.08, 1.20, 0.46, 0.20, "magenta", "tank_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.46, -1.66))
    model.add_socket("Socket_ArmorLeft", (-1.75, 0.03, 0.22))
    model.add_socket("Socket_ArmorRight", (1.75, 0.03, 0.22))
    return model


def build_sniper() -> Model:
    model = Model("sniper_enemy_mockup", "SNIPER // LONGBOW Mk II")
    model.add_loft(
        [
            (-1.52, 0.04, 0.00, 0.04),
            (-1.02, 0.24, 0.03, 0.18),
            (-0.18, 0.50, 0.04, 0.28),
            (0.82, 0.38, 0.01, 0.24),
            (1.46, 0.12, 0.00, 0.10),
        ],
        "cyan",
        "sniper_fuselage",
        6,
    )
    model.add_loft(
        [
            (-2.56, 0.025, 0.18, 0.025),
            (-2.18, 0.10, 0.20, 0.08),
            (-1.12, 0.13, 0.20, 0.10),
            (-0.86, 0.11, 0.18, 0.08),
        ],
        "silver",
        "sniper_barrel",
        6,
    )
    wing = [(0.30, -0.42), (1.18, 0.52), (0.91, 0.92), (0.39, 0.53)]
    model.add_beveled_plate(wing, -0.14, 0.08, "steel", "sniper_wing_right")
    model.add_beveled_plate(mirrored(wing), -0.14, 0.08, "steel", "sniper_wing_left")
    model.add_ellipsoid((0.0, 0.34, -0.30), (0.25, 0.16, 0.34), "orange", "sniper_optic", 4, 8)
    model.add_beveled_plate(
        [(-0.11, -1.55), (0.11, -1.55), (0.13, -0.84), (-0.13, -0.84)],
        0.24,
        0.36,
        "dark",
        "sniper_barrel_shroud",
        0.82,
    )
    add_engine_pair(model, 0.23, -0.01, 1.10, 0.40, 0.14, "cyan", "sniper_engine")
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.20, -2.64))
    model.add_socket("Socket_LaserOrigin", (0.0, 0.20, -2.64))
    return model


def build_boss_assault() -> Model:
    """Build the long spearhead silhouette used by the Assault Wing boss."""
    model = Model("boss_assault_mockup", "BOSS // ASSAULT WING")
    model.add_loft(
        [
            (-3.20, 0.045, 0.00, 0.045),
            (-2.48, 0.30, 0.05, 0.21),
            (-1.34, 0.66, 0.08, 0.38),
            (-0.12, 0.82, 0.07, 0.44),
            (1.04, 0.58, 0.02, 0.34),
            (1.88, 0.20, -0.02, 0.16),
        ],
        "red",
        "boss_assault_fuselage",
        8,
    )
    main_wing = [
        (0.50, -1.16),
        (2.62, -0.34),
        (2.42, 0.55),
        (1.46, 1.32),
        (0.62, 0.64),
    ]
    model.add_beveled_plate(
        main_wing, -0.25, 0.10, "red", "boss_assault_main_wing_right", 0.87
    )
    model.add_beveled_plate(
        mirrored(main_wing),
        -0.25,
        0.10,
        "red",
        "boss_assault_main_wing_left",
        0.87,
    )
    strike_wing = [(0.60, -1.62), (1.84, -1.10), (1.56, -0.52), (0.64, -0.84)]
    model.add_beveled_plate(
        strike_wing, 0.09, 0.24, "orange", "boss_assault_strike_wing_right", 0.82
    )
    model.add_beveled_plate(
        mirrored(strike_wing),
        0.09,
        0.24,
        "orange",
        "boss_assault_strike_wing_left",
        0.82,
    )
    for side, suffix in ((-1.0, "left"), (1.0, "right")):
        model.add_loft(
            [
                (-1.94, 0.055, 0.03, 0.055),
                (-1.58, 0.18, 0.06, 0.15),
                (-0.46, 0.14, 0.01, 0.12),
            ],
            "steel",
            f"boss_assault_cannon_{suffix}",
            6,
            1.36 * side,
        )
    spine = [
        (0.0, -2.18),
        (0.20, -1.34),
        (0.24, 0.70),
        (0.0, 1.22),
        (-0.24, 0.70),
    ]
    model.add_beveled_plate(
        spine, 0.38, 0.53, "scarlet", "boss_assault_energy_spine", 0.78
    )
    add_engine_pair(
        model, 0.43, -0.04, 1.30, 0.62, 0.25, "orange", "boss_assault_engine"
    )
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.10, -3.28))
    model.add_socket("Socket_MuzzleLeft", (-1.36, 0.06, -2.02))
    model.add_socket("Socket_MuzzleRight", (1.36, 0.06, -2.02))
    model.add_socket("Socket_WingHardpointLeft", (-2.10, 0.10, -0.24))
    model.add_socket("Socket_WingHardpointRight", (2.10, 0.10, -0.24))
    model.add_socket("Socket_Core", (0.0, 0.48, -0.18))
    model.scale_uniform(1.90)
    return model


def build_boss_bulwark() -> Model:
    """Build the broad layered shield hull used by the Bulwark Array boss."""
    model = Model("boss_bulwark_mockup", "BOSS // BULWARK ARRAY")
    body = [
        (0.0, -1.58),
        (1.12, -1.35),
        (2.18, -0.76),
        (2.44, 0.42),
        (1.62, 1.28),
        (0.0, 1.58),
        (-1.62, 1.28),
        (-2.44, 0.42),
        (-2.18, -0.76),
        (-1.12, -1.35),
    ]
    model.add_beveled_plate(
        body, -0.38, 0.28, "purple", "boss_bulwark_main_hull", 0.88
    )
    side_armor = [
        (1.28, -1.18),
        (2.62, -0.70),
        (2.72, 0.58),
        (1.78, 1.26),
        (1.38, 0.44),
    ]
    model.add_beveled_plate(
        side_armor, 0.24, 0.47, "violet", "boss_bulwark_armor_right", 0.86
    )
    model.add_beveled_plate(
        mirrored(side_armor),
        0.24,
        0.47,
        "violet",
        "boss_bulwark_armor_left",
        0.86,
    )
    shield_rail = [(1.70, -0.82), (2.32, -0.55), (2.34, 0.54), (1.82, 0.82)]
    model.add_beveled_plate(
        shield_rail, 0.48, 0.61, "yellow", "boss_bulwark_shield_rail_right", 0.80
    )
    model.add_beveled_plate(
        mirrored(shield_rail),
        0.48,
        0.61,
        "yellow",
        "boss_bulwark_shield_rail_left",
        0.80,
    )
    core_mount = [
        (0.0, -1.02),
        (0.86, -0.52),
        (0.78, 0.62),
        (0.0, 1.04),
        (-0.78, 0.62),
        (-0.86, -0.52),
    ]
    model.add_beveled_plate(
        core_mount, 0.30, 0.52, "dark", "boss_bulwark_core_mount", 0.84
    )
    model.add_ellipsoid(
        (0.0, 0.70, -0.12),
        (0.48, 0.28, 0.52),
        "white",
        "boss_bulwark_reactor",
        4,
        8,
    )
    gun_rail = [(0.86, -1.30), (1.15, -1.22), (1.18, 0.58), (0.90, 0.66)]
    model.add_beveled_plate(
        gun_rail, 0.50, 0.65, "magenta", "boss_bulwark_gun_rail_right", 0.80
    )
    model.add_beveled_plate(
        mirrored(gun_rail),
        0.50,
        0.65,
        "magenta",
        "boss_bulwark_gun_rail_left",
        0.80,
    )
    forehead = [(0.0, -1.42), (0.72, -0.92), (0.58, -0.48), (0.0, -0.28), (-0.58, -0.48)]
    model.add_beveled_plate(
        forehead, 0.53, 0.69, "silver", "boss_bulwark_forehead", 0.78
    )
    add_engine_pair(
        model, 0.62, -0.10, 1.12, 0.52, 0.24, "magenta", "boss_bulwark_engine"
    )
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.66, -1.66))
    model.add_socket("Socket_MuzzleLeft", (-1.04, 0.66, -1.34))
    model.add_socket("Socket_MuzzleRight", (1.04, 0.66, -1.34))
    model.add_socket("Socket_ShieldEmitterLeft", (-2.48, 0.58, -0.08))
    model.add_socket("Socket_ShieldEmitterRight", (2.48, 0.58, -0.08))
    model.add_socket("Socket_Core", (0.0, 0.76, -0.12))
    model.scale_uniform(1.85)
    return model


def build_boss_tempest() -> Model:
    """Build the four swept vanes of the Tempest Fork boss."""
    model = Model("boss_tempest_mockup", "BOSS // TEMPEST FORK")
    model.add_ellipsoid(
        (0.0, 0.18, 0.0),
        (0.84, 0.40, 0.96),
        "dark",
        "boss_tempest_central_hull",
        4,
        8,
    )
    blade = [(-0.32, 0.68), (0.32, 0.68), (0.52, 2.56), (0.0, 2.86), (-0.52, 2.56)]
    connector = [(-0.26, 0.46), (0.26, 0.46), (0.30, 1.14), (-0.30, 1.14)]
    for index, angle in enumerate((math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75)):
        model.add_beveled_plate(
            rotated(blade, angle),
            -0.19,
            0.10,
            "purple",
            f"boss_tempest_blade_{index + 1}",
            0.88,
        )
        model.add_beveled_plate(
            rotated(connector, angle),
            0.12,
            0.27,
            "magenta",
            f"boss_tempest_connector_{index + 1}",
            0.82,
        )
    core = [
        (0.0, -0.56),
        (0.48, -0.28),
        (0.48, 0.28),
        (0.0, 0.56),
        (-0.48, 0.28),
        (-0.48, -0.28),
    ]
    model.add_beveled_plate(core, 0.39, 0.59, "white", "boss_tempest_reactor", 0.75)
    add_engine_pair(
        model, 0.34, -0.06, 0.58, 0.58, 0.21, "magenta", "boss_tempest_engine"
    )
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.56, -1.04))
    model.add_socket("Socket_EmitterFrontLeft", (-1.95, 0.14, -1.95))
    model.add_socket("Socket_EmitterFrontRight", (1.95, 0.14, -1.95))
    model.add_socket("Socket_EmitterRearLeft", (-1.95, 0.14, 1.95))
    model.add_socket("Socket_EmitterRearRight", (1.95, 0.14, 1.95))
    model.add_socket("Socket_Core", (0.0, 0.60, 0.0))
    model.scale_uniform(2.20)
    return model


def build_boss_void_harbinger() -> Model:
    """Build the elite crowned hull and triple-core Harbinger identity."""
    model = Model("boss_void_harbinger_mockup", "ELITE BOSS // VOID HARBINGER")
    model.add_loft(
        [
            (-2.34, 0.06, 0.00, 0.055),
            (-1.66, 0.42, 0.04, 0.26),
            (-0.72, 0.86, 0.08, 0.48),
            (0.36, 0.78, 0.06, 0.46),
            (1.30, 0.50, 0.01, 0.32),
            (2.14, 0.12, -0.03, 0.12),
        ],
        "dark",
        "boss_harbinger_fuselage",
        8,
    )
    wing = [
        (0.62, -0.96),
        (2.68, -0.48),
        (2.98, 0.46),
        (2.44, 1.22),
        (1.30, 0.98),
        (0.72, 0.34),
    ]
    model.add_beveled_plate(
        wing, -0.26, 0.10, "purple", "boss_harbinger_wing_right", 0.87
    )
    model.add_beveled_plate(
        mirrored(wing), -0.26, 0.10, "purple", "boss_harbinger_wing_left", 0.87
    )
    crown_left = [(0.24, 1.08), (0.88, 2.38), (1.30, 1.12)]
    crown_center = [(-0.36, 1.20), (0.0, 2.70), (0.36, 1.20)]
    model.add_beveled_plate(
        crown_left, 0.05, 0.24, "violet", "boss_harbinger_crown_right", 0.78
    )
    model.add_beveled_plate(
        mirrored(crown_left),
        0.05,
        0.24,
        "violet",
        "boss_harbinger_crown_left",
        0.78,
    )
    model.add_beveled_plate(
        crown_center, 0.09, 0.31, "magenta", "boss_harbinger_crown_center", 0.76
    )
    chest = [
        (0.0, -1.10),
        (0.70, -0.52),
        (0.62, 0.54),
        (0.0, 0.98),
        (-0.62, 0.54),
        (-0.70, -0.52),
    ]
    model.add_beveled_plate(
        chest, 0.36, 0.54, "violet", "boss_harbinger_chest_armor", 0.82
    )
    model.add_ellipsoid(
        (0.0, 0.71, -0.10),
        (0.39, 0.22, 0.43),
        "white",
        "boss_harbinger_main_core",
        4,
        8,
    )
    model.add_ellipsoid(
        (-0.46, 0.61, 0.46),
        (0.20, 0.13, 0.22),
        "yellow",
        "boss_harbinger_core_left",
        3,
        6,
    )
    model.add_ellipsoid(
        (0.46, 0.61, 0.46),
        (0.20, 0.13, 0.22),
        "yellow",
        "boss_harbinger_core_right",
        3,
        6,
    )
    add_engine_pair(
        model, 0.42, -0.07, 1.34, 0.64, 0.24, "magenta", "boss_harbinger_engine"
    )
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.68, -2.44))
    model.add_socket("Socket_MuzzleLeft", (-0.68, 0.20, -1.02))
    model.add_socket("Socket_MuzzleRight", (0.68, 0.20, -1.02))
    model.add_socket("Socket_Core", (0.0, 0.74, -0.10))
    model.add_socket("Socket_CrownLeft", (-0.82, 0.25, 1.82))
    model.add_socket("Socket_CrownRight", (0.82, 0.25, 1.82))
    model.scale_uniform(1.68)
    return model


def build_boss_tempest_core() -> Model:
    """Build the faceted command core used by the Wave 20 encounter."""
    model = Model("boss_tempest_core_mockup", "WAVE 20 // TEMPEST CORE")
    body = [
        (0.0, -2.10),
        (1.56, -1.52),
        (2.12, -0.46),
        (1.92, 1.12),
        (0.0, 1.82),
        (-1.92, 1.12),
        (-2.12, -0.46),
        (-1.56, -1.52),
    ]
    model.add_beveled_plate(
        body, -0.40, 0.30, "purple", "boss_tempest_core_main_hull", 0.88
    )
    inner = [
        (0.0, -1.42),
        (1.06, -1.02),
        (1.40, -0.22),
        (1.18, 0.78),
        (0.0, 1.20),
        (-1.18, 0.78),
        (-1.40, -0.22),
        (-1.06, -1.02),
    ]
    model.add_beveled_plate(
        inner, 0.29, 0.50, "dark", "boss_tempest_core_inner_armor", 0.84
    )
    model.add_ellipsoid(
        (0.0, 0.75, -0.26),
        (0.48, 0.25, 0.50),
        "white",
        "boss_tempest_core_reactor",
        4,
        8,
    )
    for index, (x, z) in enumerate(((-0.88, -0.78), (0.88, -0.78), (0.0, 0.72))):
        model.add_ellipsoid(
            (x, 0.65, z),
            (0.20, 0.13, 0.22),
            "yellow",
            f"boss_tempest_core_node_{index + 1}",
            3,
            6,
        )
    side_armor = [(1.24, -1.48), (2.20, -0.78), (2.30, 0.40), (1.70, 1.10), (1.34, 0.46)]
    model.add_beveled_plate(
        side_armor, 0.28, 0.48, "violet", "boss_tempest_core_armor_right", 0.86
    )
    model.add_beveled_plate(
        mirrored(side_armor),
        0.28,
        0.48,
        "violet",
        "boss_tempest_core_armor_left",
        0.86,
    )
    hardpoint = [(-0.18, 1.02), (0.18, 1.02), (0.0, 1.48)]
    for index, angle in enumerate((0.0, math.pi * 0.5, math.pi, math.pi * 1.5)):
        model.add_beveled_plate(
            rotated(hardpoint, angle),
            0.49,
            0.64,
            "magenta",
            f"boss_tempest_core_section_hardpoint_{index + 1}",
            0.75,
        )
    add_engine_pair(
        model, 0.50, -0.09, 1.20, 0.58, 0.24, "magenta", "boss_tempest_core_engine"
    )
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.70, -2.18))
    model.add_socket("Socket_MuzzleLeft", (-0.90, 0.65, -1.00))
    model.add_socket("Socket_MuzzleRight", (0.90, 0.65, -1.00))
    model.add_socket("Socket_Core", (0.0, 0.78, -0.26))
    model.add_socket("Socket_SectionFront", (0.0, 0.66, -3.00))
    model.add_socket("Socket_SectionRear", (0.0, 0.66, 3.00))
    model.add_socket("Socket_SectionLeft", (-3.00, 0.66, 0.0))
    model.add_socket("Socket_SectionRight", (3.00, 0.66, 0.0))
    model.scale_uniform(2.20)
    return model


def build_tempest_section() -> Model:
    """Build one reusable destructible orbital module for the Tempest Core."""
    model = Model("tempest_section_mockup", "TEMPEST CORE // ORBITAL SECTION")
    body = [
        (0.0, -2.05),
        (0.62, -0.88),
        (0.58, 1.54),
        (0.0, 2.14),
        (-0.58, 1.54),
        (-0.62, -0.88),
    ]
    model.add_beveled_plate(
        body, -0.22, 0.20, "dark", "tempest_section_hull", 0.84
    )
    vane = [(0.44, -0.46), (1.18, 0.02), (0.66, 0.98)]
    model.add_beveled_plate(
        vane, -0.16, 0.10, "violet", "tempest_section_vane_right", 0.78
    )
    model.add_beveled_plate(
        mirrored(vane),
        -0.16,
        0.10,
        "violet",
        "tempest_section_vane_left",
        0.78,
    )
    model.add_ellipsoid(
        (0.0, 0.34, -0.42),
        (0.26, 0.14, 0.32),
        "magenta",
        "tempest_section_energy_core",
        3,
        6,
    )
    model.add_socket("Socket_Attach", (0.0, 0.0, 2.14))
    model.add_socket("Socket_MuzzleCenter", (0.0, 0.34, -2.10))
    model.add_socket("Socket_Core", (0.0, 0.36, -0.42))
    return model


def pack_floats(values: Iterable[float]) -> bytes:
    values = tuple(values)
    return struct.pack(f"<{len(values)}f", *values)


def pack_uint16(values: Iterable[int]) -> bytes:
    values = tuple(values)
    return struct.pack(f"<{len(values)}H", *values)


def align4(data: bytearray) -> None:
    while len(data) % 4:
        data.append(0)


def rounded_vec(vector: Vec3, digits: int = 6) -> Vec3:
    return tuple(round(value, digits) for value in vector)  # type: ignore[return-value]


def build_indexed_primitive(model: Model, material_name: str):
    triangles = [triangle for triangle in model.triangles if triangle.material == material_name]
    smooth_candidates: dict[tuple[str, Vec3], list[Triangle]] = {}
    for triangle in triangles:
        if triangle.smooth_group is None:
            continue
        for point in triangle.points:
            key = (triangle.smooth_group, rounded_vec(point))
            smooth_candidates.setdefault(key, []).append(triangle)

    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    vertices: dict[tuple[Vec3, Vec3], int] = {}
    for triangle in triangles:
        for point in triangle.points:
            if triangle.smooth_group is None:
                normal = triangle.normal
            else:
                accumulator = (0.0, 0.0, 0.0)
                for candidate in smooth_candidates[
                    (triangle.smooth_group, rounded_vec(point))
                ]:
                    # Keep smoothing within a 75-degree crease. This prevents
                    # a large acute neighbor from pulling a corner normal
                    # behind the face and producing a dark shard.
                    if vec_dot(triangle.normal, candidate.normal) >= 0.258819:
                        accumulator = vec_add(accumulator, candidate.weighted_normal)
                normal = vec_normalize(accumulator)
                if vec_dot(triangle.normal, normal) <= 0.10:
                    normal = triangle.normal
            if vec_dot(triangle.normal, normal) <= 0.0:
                raise ValueError(
                    f"{model.name}/{triangle.part} produced a backfacing vertex normal"
                )
            vertex_key = (rounded_vec(point), rounded_vec(normal, 5))
            if vertex_key not in vertices:
                vertices[vertex_key] = len(vertices)
                positions.extend(point)
                normals.extend(normal)
            indices.append(vertices[vertex_key])
    return positions, normals, indices


def export_glb(model: Model, path: Path) -> dict[str, int]:
    model.validate()
    used_materials = sorted({triangle.material for triangle in model.triangles})
    material_indices = {name: index for index, name in enumerate(used_materials)}
    binary = bytearray()
    buffer_views = []
    accessors = []
    primitives = []
    vertex_total = 0

    def add_view(payload: bytes, target: int) -> int:
        align4(binary)
        offset = len(binary)
        binary.extend(payload)
        index = len(buffer_views)
        buffer_views.append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(payload), "target": target}
        )
        return index

    def add_accessor(
        view: int,
        component_type: int,
        count: int,
        accessor_type: str,
        minimum=None,
        maximum=None,
    ) -> int:
        accessor = {
            "bufferView": view,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if minimum is not None:
            accessor["min"] = minimum
        if maximum is not None:
            accessor["max"] = maximum
        accessors.append(accessor)
        return len(accessors) - 1

    for material_name in used_materials:
        positions, normals, indices = build_indexed_primitive(model, material_name)
        vertex_count = len(positions) // 3
        vertex_total += vertex_count
        vectors = list(zip(*(iter(positions),) * 3))
        minimum = [min(vector[axis] for vector in vectors) for axis in range(3)]
        maximum = [max(vector[axis] for vector in vectors) for axis in range(3)]
        position_accessor = add_accessor(
            add_view(pack_floats(positions), 34962),
            5126,
            vertex_count,
            "VEC3",
            minimum,
            maximum,
        )
        normal_accessor = add_accessor(
            add_view(pack_floats(normals), 34962),
            5126,
            vertex_count,
            "VEC3",
        )
        index_accessor = add_accessor(
            add_view(pack_uint16(indices), 34963),
            5123,
            len(indices),
            "SCALAR",
            [0],
            [vertex_count - 1],
        )
        primitives.append(
            {
                "attributes": {"POSITION": position_accessor, "NORMAL": normal_accessor},
                "indices": index_accessor,
                "material": material_indices[material_name],
                "mode": 4,
            }
        )

    materials = []
    for name in used_materials:
        source = MATERIALS[name]
        material = {
            "name": source.name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [*source.color, 1.0],
                "metallicFactor": source.metallic,
                "roughnessFactor": source.roughness,
            },
            "doubleSided": False,
        }
        if any(source.emission):
            material["emissiveFactor"] = list(source.emission)
        materials.append(material)

    nodes = [
        {
            "name": model.display_name,
            "mesh": 0,
            "children": [],
            "extras": {"farinuff_model_version": 2, "quality": "high"},
        }
    ]
    for socket_name, translation in sorted(model.sockets.items()):
        nodes[0]["children"].append(len(nodes))
        nodes.append(
            {
                "name": socket_name,
                "translation": list(translation),
                "extras": {"farinuff_role": "socket"},
            }
        )

    gltf = {
        "asset": {"version": "2.0", "generator": "Farinuff Flight model generator v2"},
        "scene": 0,
        "scenes": [{"name": model.display_name, "nodes": [0]}],
        "nodes": nodes,
        "meshes": [{"name": f"{model.name}_mesh", "primitives": primitives}],
        "materials": materials,
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
    }

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4:
        json_bytes += b" "
    align4(binary)
    total_length = 12 + 8 + len(json_bytes) + 8 + len(binary)
    payload = bytearray(struct.pack("<III", 0x46546C67, 2, total_length))
    payload.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
    payload.extend(json_bytes)
    payload.extend(struct.pack("<II", len(binary), 0x004E4942))
    payload.extend(binary)
    path.write_bytes(payload)
    return {
        "triangles": len(model.triangles),
        "vertices": vertex_total,
        "materials": len(materials),
        "socket_count": len(model.sockets),
        "bytes": len(payload),
    }


def render_preview(model: Model, path: Path, size: tuple[int, int] = (640, 480)) -> None:
    try:
        from PIL import Image, ImageDraw, ImageFilter, ImageFont
    except ImportError:
        return

    supersample = 2
    width, height = size
    render_size = (width * supersample, height * supersample)
    image = Image.new("RGB", render_size, (4, 7, 20))
    draw = ImageDraw.Draw(image)
    for y in range(render_size[1]):
        blend = y / max(render_size[1] - 1, 1)
        color = (int(4 + 7 * blend), int(7 + 7 * blend), int(20 + 17 * blend))
        draw.line((0, y, render_size[0], y), fill=color)

    # Match the game's top-down view. Apart from being more representative,
    # a depth order based primarily on Y avoids the false cut-throughs that
    # the former oblique painter preview produced at intersecting parts.
    camera = (0.0, 8.0, 0.0)
    forward = (0.0, -1.0, 0.0)
    right = (1.0, 0.0, 0.0)
    up = (0.0, 0.0, -1.0)

    def projected(point: Vec3):
        relative = vec_sub(point, camera)
        return (vec_dot(relative, right), vec_dot(relative, up), vec_dot(relative, forward))

    projected_points = [
        projected(point) for triangle in model.triangles for point in triangle.points
    ]
    minimum_x = min(point[0] for point in projected_points)
    maximum_x = max(point[0] for point in projected_points)
    minimum_y = min(point[1] for point in projected_points)
    maximum_y = max(point[1] for point in projected_points)
    scale = min(
        (render_size[0] - 120 * supersample) / (maximum_x - minimum_x),
        (render_size[1] - 150 * supersample) / (maximum_y - minimum_y),
    )
    center_x = (minimum_x + maximum_x) * 0.5
    center_y = (minimum_y + maximum_y) * 0.5

    def screen(point: Vec3):
        px, py, depth = projected(point)
        return (
            render_size[0] * 0.5 + (px - center_x) * scale,
            render_size[1] * 0.54 - (py - center_y) * scale,
            depth,
        )

    shadow_layer = Image.new("RGBA", render_size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    shadow_draw.ellipse(
        (
            render_size[0] * 0.20,
            render_size[1] * 0.79,
            render_size[0] * 0.80,
            render_size[1] * 0.92,
        ),
        fill=(0, 0, 0, 175),
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(10 * supersample))
    image.paste(shadow_layer, (0, 0), shadow_layer)
    draw = ImageDraw.Draw(image)

    light = vec_normalize((-0.42, 1.0, -0.62))
    visible_triangles = [
        triangle
        for triangle in model.triangles
        if vec_dot(triangle.normal, (0.0, 1.0, 0.0)) >= -0.001
    ]
    sorted_triangles = sorted(
        visible_triangles,
        key=lambda triangle: sum(screen(point)[2] for point in triangle.points) / 3.0,
        reverse=True,
    )
    for triangle in sorted_triangles:
        source = MATERIALS[triangle.material]
        lighting = 0.52 + 0.48 * max(0.0, vec_dot(triangle.normal, light))
        color = tuple(
            min(
                255,
                int(
                    255
                    * (
                        source.color[index] * lighting
                        + source.emission[index] * 0.22
                    )
                ),
            )
            for index in range(3)
        )
        polygon = [(screen(point)[0], screen(point)[1]) for point in triangle.points]
        draw.polygon(polygon, fill=color)

    try:
        title_font = ImageFont.truetype(
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf", 25 * supersample
        )
        small_font = ImageFont.truetype(
            "/System/Library/Fonts/Supplemental/Arial.ttf", 15 * supersample
        )
    except OSError:
        title_font = ImageFont.load_default()
        small_font = title_font
    draw.text(
        (26 * supersample, 24 * supersample),
        model.display_name,
        fill=(226, 242, 255),
        font=title_font,
    )
    draw.text(
        (28 * supersample, 58 * supersample),
        f"{len(model.triangles):04d} triangles  //  {len(model.sockets):02d} sockets  //  GLB v2",
        fill=(89, 198, 231),
        font=small_font,
    )
    image.resize(size, Image.Resampling.LANCZOS).save(path)


def make_contact_sheet(models: list[Model]) -> None:
    try:
        from PIL import Image
    except ImportError:
        return
    cell_size = (640, 480)
    columns = 3
    rows = math.ceil(len(models) / columns)
    sheet = Image.new(
        "RGB", (cell_size[0] * columns, cell_size[1] * rows), (4, 7, 20)
    )
    for index, model in enumerate(models):
        preview = Image.open(PREVIEW_DIR / f"{model.name}.png")
        sheet.paste(
            preview,
            ((index % columns) * cell_size[0], (index // columns) * cell_size[1]),
        )
    sheet.save(PREVIEW_DIR / "mockup_fleet_contact_sheet.png")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    models = [
        build_player(),
        build_player_upgrade_twin_cannons(),
        build_player_upgrade_auto_aim(),
        build_player_upgrade_hull_plating(),
        build_player_upgrade_afterburner(),
        build_player_upgrade_spread_shot(),
        build_player_upgrade_shield_burst(),
        build_player_upgrade_magnet_field(),
        build_player_upgrade_overclock(),
        build_player_upgrade_rear_gunner(),
        build_player_drone_escort(),
        build_basic(),
        build_fast(),
        build_bomber(),
        build_tank(),
        build_sniper(),
        build_boss_assault(),
        build_boss_bulwark(),
        build_boss_tempest(),
        build_boss_void_harbinger(),
        build_boss_tempest_core(),
        build_tempest_section(),
    ]
    manifest = []
    for model in models:
        model_path = OUTPUT_DIR / f"{model.name}.glb"
        stats = export_glb(model, model_path)
        render_preview(model, PREVIEW_DIR / f"{model.name}.png")
        manifest.append(
            {
                "name": model.name,
                "display_name": model.display_name,
                "file": model_path.name,
                **stats,
                "sockets": {
                    name: [round(value, 4) for value in position]
                    for name, position in model.sockets.items()
                },
            }
        )
        print(
            f"Wrote {model_path.relative_to(ROOT)} "
            f"({stats['triangles']} tris, {stats['vertices']} welded vertices)"
        )
    (OUTPUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    make_contact_sheet(models)


if __name__ == "__main__":
    main()
