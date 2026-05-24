from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "sprites" / "generated"
FRAME_SIZE = 128
RAW_SIZE = 192
RAW_CENTER = (RAW_SIZE / 2.0, RAW_SIZE / 2.0)
FINAL_CENTER = (FRAME_SIZE / 2.0, FRAME_SIZE / 2.0)
FRAMES = 4
RESAMPLING = Image.Resampling.LANCZOS


Color = tuple[int, int, int, int]


@dataclass(frozen=True)
class SpriteSpec:
    name: str
    filename: str
    target_extent: int
    fps: int
    draw_fn: Callable[[Image.Image, float], None]


def rgba(r: int, g: int, b: int, a: int = 255) -> Color:
    return (r, g, b, a)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def polar(point: tuple[float, float], angle_radians: float, length: float) -> tuple[float, float]:
    return (
        point[0] + math.cos(angle_radians) * length,
        point[1] + math.sin(angle_radians) * length,
    )


def rotate_point(point: tuple[float, float], center: tuple[float, float], degrees: float) -> tuple[float, float]:
    radians = math.radians(degrees)
    px = point[0] - center[0]
    py = point[1] - center[1]
    cos_v = math.cos(radians)
    sin_v = math.sin(radians)
    return (
        center[0] + px * cos_v - py * sin_v,
        center[1] + px * sin_v + py * cos_v,
    )


def transform_points(
    points: list[tuple[float, float]],
    center: tuple[float, float],
    *,
    translate: tuple[float, float] = (0.0, 0.0),
    rotate_degrees: float = 0.0,
    scale: float = 1.0,
) -> list[tuple[float, float]]:
    transformed: list[tuple[float, float]] = []
    for point in points:
        x = point[0] - center[0]
        y = point[1] - center[1]
        x *= scale
        y *= scale
        if rotate_degrees:
            radians = math.radians(rotate_degrees)
            cos_v = math.cos(radians)
            sin_v = math.sin(radians)
            x, y = x * cos_v - y * sin_v, x * sin_v + y * cos_v
        transformed.append((center[0] + x + translate[0], center[1] + y + translate[1]))
    return transformed


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def union_bbox(boxes: list[tuple[int, int, int, int] | None]) -> tuple[int, int, int, int] | None:
    xs0: list[int] = []
    ys0: list[int] = []
    xs1: list[int] = []
    ys1: list[int] = []
    for box in boxes:
        if box is None:
            continue
        xs0.append(box[0])
        ys0.append(box[1])
        xs1.append(box[2])
        ys1.append(box[3])
    if not xs0:
        return None
    return (min(xs0), min(ys0), max(xs1), max(ys1))


def padded_bbox(box: tuple[int, int, int, int], pad: int, limit: int) -> tuple[int, int, int, int]:
    return (
        max(0, box[0] - pad),
        max(0, box[1] - pad),
        min(limit, box[2] + pad),
        min(limit, box[3] + pad),
    )


def tint(color: Color, factor: float) -> Color:
    return (
        int(clamp(color[0] * factor, 0, 255)),
        int(clamp(color[1] * factor, 0, 255)),
        int(clamp(color[2] * factor, 0, 255)),
        color[3],
    )


def make_overlay(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def glow_circle(base: Image.Image, center: tuple[float, float], radius: float, color: Color, blur: float = 4.0) -> None:
    overlay = make_overlay(base.size)
    draw = ImageDraw.Draw(overlay)
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(overlay)


def glow_polygon(base: Image.Image, points: list[tuple[float, float]], color: Color, blur: float = 5.0) -> None:
    overlay = make_overlay(base.size)
    draw = ImageDraw.Draw(overlay)
    draw.polygon(points, fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(overlay)


def draw_ship_outline(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], fill: Color, outline: Color, width: int = 2) -> None:
    draw.polygon(points, fill=fill)
    draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def draw_engine_flare(base: Image.Image, x: float, y: float, phase: float, power: float = 1.0) -> None:
    size = 5.5 + math.sin(phase * 2.0) * 1.1
    glow_circle(base, (x, y), size, rgba(80, 245, 255, int(130 * power)), blur=3.5)
    glow_circle(base, (x, y + 2.0), size * 0.55, rgba(255, 255, 255, int(160 * power)), blur=2.0)


def draw_player(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase) * 2.5
    roll = math.sin(phase * 0.85) * 4.0
    core_pulse = 0.75 + 0.25 * math.sin(phase * 2.0 + 0.5)
    wing_breath = 1.0 + 0.02 * math.sin(phase * 2.0)

    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    hull = [
        (center[0], center[1] - 40),
        (center[0] + 18, center[1] - 6),
        (center[0] + 14, center[1] + 25),
        (center[0], center[1] + 33),
        (center[0] - 14, center[1] + 25),
        (center[0] - 18, center[1] - 6),
    ]
    hull = transform_points(hull, center, rotate_degrees=roll)
    draw_ship_outline(draw, hull, rgba(215, 224, 235), rgba(55, 72, 96), width=2)

    wings_left = [
        (center[0] - 18, center[1] - 7),
        (center[0] - 44, center[1] + 4),
        (center[0] - 34, center[1] + 18),
        (center[0] - 15, center[1] + 10),
    ]
    wings_right = [(center[0] * 2 - x, y) for x, y in wings_left]
    wings_left = transform_points(wings_left, center, rotate_degrees=roll * 0.9, scale=wing_breath)
    wings_right = transform_points(wings_right, center, rotate_degrees=roll * 0.9, scale=wing_breath)
    draw.polygon(wings_left, fill=rgba(110, 120, 132))
    draw.polygon(wings_right, fill=rgba(110, 120, 132))
    draw.line(wings_left + [wings_left[0]], fill=rgba(42, 52, 70), width=2)
    draw.line(wings_right + [wings_right[0]], fill=rgba(42, 52, 70), width=2)

    cockpit = [
        (center[0] - 5, center[1] - 20),
        (center[0] + 5, center[1] - 20),
        (center[0] + 4, center[1] - 5),
        (center[0] - 4, center[1] - 5),
    ]
    cockpit = transform_points(cockpit, center, rotate_degrees=roll)
    draw.polygon(cockpit, fill=rgba(18, 20, 45))
    glow_polygon(raw, cockpit, rgba(160, 80, 255, 80), blur=3.0)

    spine_left = [
        (center[0] - 2, center[1] - 2),
        (center[0] - 5, center[1] + 22),
        (center[0] - 1, center[1] + 28),
        (center[0] + 1, center[1] + 28),
        (center[0] + 5, center[1] + 22),
        (center[0] + 2, center[1] - 2),
    ]
    draw.polygon(transform_points(spine_left, center, rotate_degrees=roll), fill=rgba(64, 194, 255))

    draw_engine_flare(raw, center[0], center[1] + 32, phase, power=1.0)
    glow_circle(raw, (center[0], center[1] + 16), 8.0, rgba(56, 230, 255, int(140 * core_pulse)), blur=4.0)


def draw_basic(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase) * 1.8
    lean = math.sin(phase * 1.2) * 2.5
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    body = [
        (center[0], center[1] - 31),
        (center[0] + 19, center[1] + 6),
        (center[0], center[1] + 28),
        (center[0] - 19, center[1] + 6),
    ]
    body = transform_points(body, center, rotate_degrees=lean)
    draw_ship_outline(draw, body, rgba(214, 53, 76), rgba(110, 20, 36), width=2)

    wings = [
        (center[0] - 19, center[1] - 2),
        (center[0] - 39, center[1] + 5),
        (center[0] - 31, center[1] + 15),
        (center[0] - 18, center[1] + 10),
    ]
    wings_right = [(center[0] * 2 - x, y) for x, y in wings]
    wings = transform_points(wings, center, rotate_degrees=lean)
    wings_right = transform_points(wings_right, center, rotate_degrees=lean)
    draw.polygon(wings, fill=rgba(120, 25, 38))
    draw.polygon(wings_right, fill=rgba(120, 25, 38))

    eye = [
        (center[0] - 5, center[1] - 11),
        (center[0] + 5, center[1] - 11),
        (center[0] + 4, center[1] - 2),
        (center[0] - 4, center[1] - 2),
    ]
    draw.polygon(transform_points(eye, center, rotate_degrees=lean), fill=rgba(246, 207, 71))
    glow_circle(raw, (center[0], center[1] - 6), 5.0, rgba(255, 240, 120, 140), blur=2.5)

    draw_engine_flare(raw, center[0] - 8, center[1] + 24, phase, power=0.85)
    draw_engine_flare(raw, center[0] + 8, center[1] + 24, phase + 0.8, power=0.85)


def draw_fast(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 1.2) * 1.4
    lean = math.sin(phase * 1.1 + 0.3) * 7.0
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    diamond = [
        (center[0], center[1] - 28),
        (center[0] + 18, center[1] - 4),
        (center[0], center[1] + 24),
        (center[0] - 18, center[1] - 4),
    ]
    diamond = transform_points(diamond, center, rotate_degrees=lean)
    draw_ship_outline(draw, diamond, rgba(255, 137, 41), rgba(130, 42, 0), width=2)

    stripe = [
        (center[0] - 3, center[1] - 18),
        (center[0] + 3, center[1] - 18),
        (center[0] + 2, center[1] + 18),
        (center[0] - 2, center[1] + 18),
    ]
    stripe = transform_points(stripe, center, rotate_degrees=lean)
    draw.polygon(stripe, fill=rgba(48, 48, 48))

    core = (center[0], center[1] - 2)
    glow_circle(raw, core, 6.0, rgba(66, 255, 255, 190), blur=2.8)
    draw.ellipse((core[0] - 3, core[1] - 3, core[0] + 3, core[1] + 3), fill=rgba(245, 255, 255))
    draw_engine_flare(raw, center[0], center[1] + 24, phase, power=1.15)

    trail = [
        (center[0] - 4, center[1] + 8),
        (center[0] + 4, center[1] + 8),
        (center[0] + 1, center[1] + 38),
        (center[0] - 1, center[1] + 38),
    ]
    glow_polygon(raw, trail, rgba(255, 198, 80, 80), blur=4.0)


def draw_sniper(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.9) * 1.5
    lean = math.sin(phase * 0.8) * 1.4
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    hull = [
        (center[0], center[1] - 31),
        (center[0] + 16, center[1] - 10),
        (center[0] + 12, center[1] + 22),
        (center[0], center[1] + 28),
        (center[0] - 12, center[1] + 22),
        (center[0] - 16, center[1] - 10),
    ]
    hull = transform_points(hull, center, rotate_degrees=lean)
    draw_ship_outline(draw, hull, rgba(30, 168, 215), rgba(7, 61, 99), width=2)

    barrel = [
        (center[0] - 3, center[1] - 31),
        (center[0] + 3, center[1] - 31),
        (center[0] + 3, center[1] - 48),
        (center[0] - 3, center[1] - 48),
    ]
    barrel = transform_points(barrel, center, rotate_degrees=lean)
    draw.polygon(barrel, fill=rgba(118, 240, 255))
    glow_circle(raw, (center[0], center[1] - 44), 5.0, rgba(140, 255, 255, 160), blur=2.6)

    target = (center[0], center[1] - 6)
    charge = 0.6 + 0.4 * math.sin(phase * 2.0)
    glow_circle(raw, target, 8.5, rgba(255, 102, 64, int(140 * charge)), blur=3.0)
    draw.ellipse((target[0] - 4, target[1] - 4, target[0] + 4, target[1] + 4), fill=rgba(255, 159, 91))
    draw_engine_flare(raw, center[0], center[1] + 24, phase, power=0.8)


def draw_tank(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.7) * 1.3
    pulse = 0.9 + 0.1 * math.sin(phase * 2.0)
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    hull = [
        (center[0], center[1] - 38),
        (center[0] + 28, center[1] - 18),
        (center[0] + 30, center[1] + 20),
        (center[0], center[1] + 38),
        (center[0] - 30, center[1] + 20),
        (center[0] - 28, center[1] - 18),
    ]
    draw_ship_outline(draw, hull, rgba(128, 53, 189), rgba(64, 16, 99), width=2)

    plate_lines = [
        [(center[0] - 24, center[1] - 6), (center[0] + 24, center[1] - 6)],
        [(center[0] - 26, center[1] + 8), (center[0] + 26, center[1] + 8)],
        [(center[0] - 18, center[1] + 22), (center[0] + 18, center[1] + 22)],
    ]
    for line in plate_lines:
        draw.line(line, fill=rgba(36, 11, 52, 220), width=2)

    rivets = [
        (center[0] - 12, center[1] - 7),
        (center[0] + 12, center[1] - 7),
        (center[0] - 16, center[1] + 8),
        (center[0] + 16, center[1] + 8),
        (center[0] - 8, center[1] + 23),
        (center[0] + 8, center[1] + 23),
    ]
    for x, y in rivets:
        draw.ellipse((x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=rgba(220, 160, 240))

    gun_left = [
        (center[0] - 18, center[1] + 10),
        (center[0] - 8, center[1] + 10),
        (center[0] - 8, center[1] + 43),
        (center[0] - 18, center[1] + 43),
    ]
    gun_right = [(center[0] * 2 - x, y) for x, y in gun_left]
    draw.polygon(gun_left, fill=rgba(88, 88, 101))
    draw.polygon(gun_right, fill=rgba(88, 88, 101))
    glow_circle(raw, (center[0] - 13, center[1] + 42), 4.0, rgba(255, 218, 96, int(160 * pulse)), blur=2.0)
    glow_circle(raw, (center[0] + 13, center[1] + 42), 4.0, rgba(255, 218, 96, int(160 * pulse)), blur=2.0)

    core = (center[0], center[1] + 2)
    glow_circle(raw, core, 10.0, rgba(255, 105, 255, 150), blur=4.0)
    draw.ellipse((core[0] - 6, core[1] - 6, core[0] + 6, core[1] + 6), fill=rgba(255, 255, 255))


def draw_bomber(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.9) * 1.9
    lean = math.sin(phase * 0.8 + 0.2) * 3.0
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)

    body = [
        (center[0], center[1] - 26),
        (center[0] + 24, center[1] - 10),
        (center[0] + 26, center[1] + 12),
        (center[0], center[1] + 24),
        (center[0] - 26, center[1] + 12),
        (center[0] - 24, center[1] - 10),
    ]
    body = transform_points(body, center, rotate_degrees=lean)
    draw_ship_outline(draw, body, rgba(63, 146, 56), rgba(30, 62, 29), width=2)

    wing_left = [
        (center[0] - 24, center[1] - 8),
        (center[0] - 48, center[1] + 1),
        (center[0] - 39, center[1] + 18),
        (center[0] - 20, center[1] + 11),
    ]
    wing_right = [(center[0] * 2 - x, y) for x, y in wing_left]
    wing_left = transform_points(wing_left, center, rotate_degrees=lean * 0.8)
    wing_right = transform_points(wing_right, center, rotate_degrees=lean * 0.8)
    draw.polygon(wing_left, fill=rgba(36, 95, 40))
    draw.polygon(wing_right, fill=rgba(36, 95, 40))

    bay_left = [
        (center[0] - 10, center[1] + 3),
        (center[0] - 2, center[1] + 3),
        (center[0] - 3, center[1] + 20),
        (center[0] - 11, center[1] + 20),
    ]
    bay_right = [(center[0] * 2 - x, y) for x, y in bay_left]
    draw.polygon(bay_left, fill=rgba(20, 20, 20))
    draw.polygon(bay_right, fill=rgba(20, 20, 20))

    bay_stripe_a = [
        (center[0] - 10, center[1] + 5),
        (center[0] - 2, center[1] + 5),
        (center[0] - 3, center[1] + 8),
        (center[0] - 11, center[1] + 8),
    ]
    bay_stripe_b = [(center[0] * 2 - x, y) for x, y in bay_stripe_a]
    draw.polygon(bay_stripe_a, fill=rgba(245, 202, 42))
    draw.polygon(bay_stripe_b, fill=rgba(245, 202, 42))

    cockpit = [
        (center[0] - 5, center[1] - 18),
        (center[0] + 5, center[1] - 18),
        (center[0] + 4, center[1] - 8),
        (center[0] - 4, center[1] - 8),
    ]
    draw.polygon(transform_points(cockpit, center, rotate_degrees=lean), fill=rgba(194, 216, 94))
    glow_circle(raw, (center[0], center[1] - 13), 5.5, rgba(255, 255, 220, 120), blur=2.2)

    engine_y = center[1] + 24
    draw_engine_flare(raw, center[0] - 14, engine_y, phase, power=0.9)
    draw_engine_flare(raw, center[0] - 4, engine_y + 2, phase + 0.2, power=0.8)
    draw_engine_flare(raw, center[0] + 4, engine_y + 2, phase + 0.4, power=0.8)
    draw_engine_flare(raw, center[0] + 14, engine_y, phase + 0.6, power=0.9)


def draw_boss(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.5) * 2.4
    sway = math.sin(phase * 0.75) * 5.0
    pulse = 0.6 + 0.4 * math.sin(phase * 2.4 + 0.3)
    center = (RAW_CENTER[0] + sway, RAW_CENTER[1] + bob)

    # Base chassis: broad, armored, and asymmetrical enough to read as a different boss.
    chassis = [
        (center[0], center[1] - 38),
        (center[0] + 22, center[1] - 30),
        (center[0] + 38, center[1] - 10),
        (center[0] + 34, center[1] + 16),
        (center[0] + 14, center[1] + 40),
        (center[0], center[1] + 48),
        (center[0] - 14, center[1] + 40),
        (center[0] - 34, center[1] + 16),
        (center[0] - 38, center[1] - 10),
        (center[0] - 22, center[1] - 30),
    ]
    draw_ship_outline(draw, chassis, rgba(14, 16, 30), rgba(107, 231, 255), width=2)
    glow_polygon(raw, chassis, rgba(28, 147, 255, 44), blur=8.0)

    # Crown spines
    crown = [
        (center[0] - 30, center[1] - 46),
        (center[0] - 20, center[1] - 66),
        (center[0] - 10, center[1] - 44),
        (center[0], center[1] - 70),
        (center[0] + 10, center[1] - 44),
        (center[0] + 20, center[1] - 66),
        (center[0] + 30, center[1] - 46),
        (center[0] + 18, center[1] - 36),
        (center[0] + 8, center[1] - 44),
        (center[0], center[1] - 32),
        (center[0] - 8, center[1] - 44),
        (center[0] - 18, center[1] - 36),
    ]
    draw.polygon(crown, fill=rgba(80, 30, 160))
    draw.line(crown + [crown[0]], fill=rgba(255, 102, 228), width=2, joint="curve")

    # Split wing-blades that angle forward.
    left_blade = [
        (center[0] - 26, center[1] - 12),
        (center[0] - 58, center[1] - 2),
        (center[0] - 66, center[1] + 16),
        (center[0] - 40, center[1] + 22),
        (center[0] - 24, center[1] + 8),
    ]
    right_blade = [(center[0] * 2 - x, y) for x, y in left_blade]
    draw.polygon(left_blade, fill=rgba(18, 90, 110))
    draw.polygon(right_blade, fill=rgba(18, 90, 110))
    draw.line(left_blade + [left_blade[0]], fill=rgba(91, 247, 255), width=2)
    draw.line(right_blade + [right_blade[0]], fill=rgba(91, 247, 255), width=2)

    # Side emitters
    for dx, dy, r in [(-20, -2, 6), (20, -2, 6), (-18, 22, 5), (18, 22, 5)]:
        glow_circle(raw, (center[0] + dx, center[1] + dy), r, rgba(126, 215, 255, 135), blur=3.2)
        draw.ellipse(
            (center[0] + dx - 2, center[1] + dy - 2, center[0] + dx + 2, center[1] + dy + 2),
            fill=rgba(245, 250, 255),
        )

    # Core pillar
    core = (center[0], center[1] + 3)
    core_shape = [
        (core[0] - 9, core[1] - 26),
        (core[0] + 9, core[1] - 26),
        (core[0] + 12, core[1] + 20),
        (core[0], core[1] + 30),
        (core[0] - 12, core[1] + 20),
    ]
    draw.polygon(core_shape, fill=rgba(39, 15, 75))
    glow_circle(raw, core, 18.0, rgba(94, 255, 245, int(165 * pulse)), blur=5.5)
    glow_circle(raw, core, 8.0, rgba(255, 255, 255, 160), blur=2.5)
    draw.ellipse((core[0] - 6, core[1] - 6, core[0] + 6, core[1] + 6), fill=rgba(255, 255, 255))

    # Rear thruster fin and exhaust plume.
    tail = [
        (center[0] - 7, center[1] + 34),
        (center[0] + 7, center[1] + 34),
        (center[0] + 12, center[1] + 58),
        (center[0], center[1] + 66),
        (center[0] - 12, center[1] + 58),
    ]
    draw.polygon(tail, fill=rgba(18, 19, 30))
    glow_polygon(raw, tail, rgba(255, 96, 224, 70), blur=5.0)
    glow_circle(raw, (center[0], center[1] + 58), 7.0, rgba(255, 143, 59, int(170 * pulse)), blur=3.0)


def draw_tempest_core(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.58) * 2.2
    pulse = 0.7 + 0.3 * math.sin(phase * 2.0 + 0.4)
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)

    hull = [
        (center[0], center[1] - 46),
        (center[0] + 34, center[1] - 24),
        (center[0] + 40, center[1] + 12),
        (center[0] + 18, center[1] + 37),
        (center[0], center[1] + 44),
        (center[0] - 18, center[1] + 37),
        (center[0] - 40, center[1] + 12),
        (center[0] - 34, center[1] - 24),
    ]
    draw_ship_outline(draw, hull, rgba(41, 12, 72), rgba(161, 55, 242), width=2)
    glow_polygon(raw, hull, rgba(183, 54, 255, 48), blur=7.0)

    for y in (-22, -8, 8, 22):
        draw.line(
            [(center[0] - 27, center[1] + y), (center[0] + 27, center[1] + y)],
            fill=rgba(94, 30, 132),
            width=2,
        )

    for dx, dy in [(-23, -14), (23, -14), (-23, 13), (23, 13)]:
        glow_circle(raw, (center[0] + dx, center[1] + dy), 6.0, rgba(71, 216, 255, 135), blur=3.0)
        draw.ellipse(
            (center[0] + dx - 3, center[1] + dy - 3, center[0] + dx + 3, center[1] + dy + 3),
            fill=rgba(214, 247, 255),
        )

    eye_left = [(center[0] - 30, center[1] - 12), (center[0] - 8, center[1] - 8), (center[0] - 11, center[1] - 3)]
    eye_right = [(center[0] * 2 - x, y) for x, y in eye_left]
    draw.polygon(eye_left, fill=rgba(255, 54, 153))
    draw.polygon(eye_right, fill=rgba(255, 54, 153))

    core = (center[0], center[1] + 3)
    glow_circle(raw, core, 19.0, rgba(255, 56, 235, int(170 * pulse)), blur=5.0)
    glow_circle(raw, core, 10.0, rgba(255, 255, 255, 145), blur=2.5)
    draw.ellipse((core[0] - 6, core[1] - 6, core[0] + 6, core[1] + 6), fill=rgba(255, 255, 255))


def normalize_frames(raw_frames: list[Image.Image], target_extent: int) -> tuple[list[Image.Image], dict[str, float | int]]:
    boxes = [alpha_bbox(frame) for frame in raw_frames]
    union = union_bbox(boxes)
    if union is None:
        raise RuntimeError("No opaque pixels were drawn for a sprite strip.")

    union = padded_bbox(union, 8, RAW_SIZE)
    crop_w = union[2] - union[0]
    crop_h = union[3] - union[1]
    scale = target_extent / float(max(crop_w, crop_h))

    normalized: list[Image.Image] = []
    for frame in raw_frames:
        crop = frame.crop(union)
        resized_size = (
            max(1, int(round(crop.width * scale))),
            max(1, int(round(crop.height * scale))),
        )
        resized = crop.resize(resized_size, RESAMPLING)
        anchor_x = (RAW_CENTER[0] - union[0]) * scale
        anchor_y = (RAW_CENTER[1] - union[1]) * scale
        paste_x = int(round(FINAL_CENTER[0] - anchor_x))
        paste_y = int(round(FINAL_CENTER[1] - anchor_y))
        final = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        final.paste(resized, (paste_x, paste_y), resized)
        normalized.append(final)

    info = {
        "raw_bbox_x": union[0],
        "raw_bbox_y": union[1],
        "raw_bbox_w": crop_w,
        "raw_bbox_h": crop_h,
        "scale": round(scale, 4),
        "frame_size": FRAME_SIZE,
        "raw_size": RAW_SIZE,
    }
    return normalized, info


def render_strip(spec: SpriteSpec) -> tuple[Image.Image, dict[str, float | int]]:
    raw_frames: list[Image.Image] = []
    for index in range(FRAMES):
        phase = math.tau * (index / FRAMES)
        raw = Image.new("RGBA", (RAW_SIZE, RAW_SIZE), (0, 0, 0, 0))
        spec.draw_fn(raw, phase)
        raw_frames.append(raw)

    normalized, info = normalize_frames(raw_frames, spec.target_extent)
    strip = Image.new("RGBA", (FRAME_SIZE * FRAMES, FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        strip.paste(frame, (index * FRAME_SIZE, 0), frame)
    info.update(
        {
            "name": spec.name,
            "fps": spec.fps,
            "frames": FRAMES,
            "target_extent": spec.target_extent,
        }
    )
    return strip, info


def build_preview(strips: list[tuple[SpriteSpec, Image.Image, dict[str, float | int]]]) -> Image.Image:
    label_w = 236
    row_h = FRAME_SIZE + 28
    width = label_w + FRAME_SIZE * FRAMES + 24
    height = 24 + len(strips) * row_h + 24
    sheet = Image.new("RGBA", (width, height), rgba(12, 14, 24))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    draw.rounded_rectangle((10, 10, width - 10, height - 10), radius=16, outline=rgba(62, 82, 120), width=2)
    draw.text((24, 18), "Sprite normalization preview", fill=rgba(230, 238, 255), font=font)

    for row, (spec, strip, info) in enumerate(strips):
        top = 56 + row * row_h
        draw.rounded_rectangle((18, top - 6, width - 18, top + FRAME_SIZE + 14), radius=14, fill=rgba(18, 23, 38), outline=rgba(34, 44, 68), width=1)
        draw.text((32, top + 42), spec.name, fill=rgba(230, 238, 255), font=font)
        draw.text(
            (32, top + 58),
            f"{FRAME_SIZE}px strip | extent {info['target_extent']} | scale {info['scale']}",
            fill=rgba(155, 173, 205),
            font=font,
        )
        sheet.paste(strip, (label_w, top), strip)

    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    specs = [
        SpriteSpec("player_idle", "player_idle_strip.png", 92, 8, draw_player),
        SpriteSpec("basic_enemy_idle", "basic_enemy_idle_strip.png", 68, 8, draw_basic),
        SpriteSpec("fast_enemy_idle", "fast_enemy_idle_strip.png", 64, 10, draw_fast),
        SpriteSpec("sniper_enemy_idle", "sniper_enemy_idle_strip.png", 70, 8, draw_sniper),
        SpriteSpec("tank_enemy_idle", "tank_enemy_idle_strip.png", 90, 7, draw_tank),
        SpriteSpec("bomber_enemy_idle", "bomber_enemy_idle_strip.png", 94, 7, draw_bomber),
        SpriteSpec("boss_enemy_idle", "boss_enemy_idle_strip.png", 114, 6, draw_boss),
        SpriteSpec("tempest_core_idle", "tempest_core_idle_strip.png", 116, 8, draw_tempest_core),
    ]

    manifest: dict[str, object] = {
        "frame_size": FRAME_SIZE,
        "raw_size": RAW_SIZE,
        "anchor": {"x": FINAL_CENTER[0], "y": FINAL_CENTER[1]},
        "frames": FRAMES,
        "assets": [],
    }

    preview_rows: list[tuple[SpriteSpec, Image.Image, dict[str, float | int]]] = []

    for spec in specs:
        strip, info = render_strip(spec)
        out_path = OUT_DIR / spec.filename
        strip.save(out_path)
        preview_rows.append((spec, strip, info))
        manifest["assets"].append(
            {
                "name": spec.name,
                "file": spec.filename,
                "fps": spec.fps,
                "frames": FRAMES,
                "frame_size": FRAME_SIZE,
                "target_extent": spec.target_extent,
                "scale": info["scale"],
            }
        )

    preview = build_preview(preview_rows)
    preview.save(OUT_DIR / "sprite_preview_sheet.png")

    with (OUT_DIR / "sprite_manifest.json").open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")

    print(f"Generated {len(specs)} sprite strips in {OUT_DIR}")


if __name__ == "__main__":
    main()
