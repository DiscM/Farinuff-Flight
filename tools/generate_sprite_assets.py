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


GENERATION_ACCENTS: dict[int, Color] = {
    1: rgba(255, 255, 255),
    2: rgba(255, 190, 52),
    3: rgba(255, 64, 52),
    4: rgba(255, 48, 196),
}


def draw_hostile_flare(
    base: Image.Image,
    x: float,
    y: float,
    phase: float,
    generation: int,
    power: float = 1.0,
) -> None:
    accent = GENERATION_ACCENTS[generation]
    size = 5.0 + generation * 0.45 + math.sin(phase * 2.0) * 1.0
    glow_circle(base, (x, y), size, (*accent[:3], int(115 * power)), blur=3.2)
    glow_circle(base, (x, y + 1.5), size * 0.48, rgba(255, 232, 184, int(150 * power)), blur=1.8)


def draw_accent_seam(
    base: Image.Image,
    points: list[tuple[float, float]],
    generation: int,
    *,
    width: int = 2,
    glow: bool = True,
) -> None:
    accent = GENERATION_ACCENTS[generation]
    if glow:
        overlay = make_overlay(base.size)
        overlay_draw = ImageDraw.Draw(overlay)
        overlay_draw.line(points, fill=(*accent[:3], 125), width=width + 3, joint="curve")
        base.alpha_composite(overlay.filter(ImageFilter.GaussianBlur(3.0)))
    ImageDraw.Draw(base).line(points, fill=accent, width=width, joint="curve")


def draw_basic_generation(raw: Image.Image, phase: float, generation: int) -> None:
    if generation == 1:
        draw_basic(raw, phase)
        return

    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase) * 1.8
    lean = math.sin(phase * 1.2) * 2.5
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    accent = GENERATION_ACCENTS[generation]

    engine_fins = [
        (center[0] - 13, center[1] + 12),
        (center[0] - 29 - generation * 3, center[1] + 27),
        (center[0] - 22, center[1] + 37 + generation * 2),
        (center[0] - 7, center[1] + 23),
    ]
    engine_fins_right = [(center[0] * 2 - x, y) for x, y in engine_fins]
    engine_fins = transform_points(engine_fins, center, rotate_degrees=lean)
    engine_fins_right = transform_points(engine_fins_right, center, rotate_degrees=lean)
    draw_ship_outline(draw, engine_fins, rgba(58, 18, 25), tint(accent, 0.72), width=2)
    draw_ship_outline(draw, engine_fins_right, rgba(58, 18, 25), tint(accent, 0.72), width=2)

    if generation >= 3:
        prow = [
            (center[0], center[1] - 48 - generation * 2),
            (center[0] + 11, center[1] - 24),
            (center[0] + 7, center[1] - 8),
            (center[0] - 7, center[1] - 8),
            (center[0] - 11, center[1] - 24),
        ]
        prow = transform_points(prow, center, rotate_degrees=lean)
        draw_ship_outline(draw, prow, rgba(76, 19, 31), tint(accent, 0.85), width=2)
        glow_polygon(raw, prow, (*accent[:3], 54), blur=4.0)

    if generation == 4:
        split_left = [
            (center[0] - 4, center[1] - 28),
            (center[0] - 23, center[1] - 17),
            (center[0] - 16, center[1] + 4),
            (center[0] - 4, center[1] - 3),
        ]
        split_right = [(center[0] * 2 - x, y) for x, y in split_left]
        split_left = transform_points(split_left, center, rotate_degrees=lean)
        split_right = transform_points(split_right, center, rotate_degrees=lean)
        draw_ship_outline(draw, split_left, rgba(14, 12, 23), rgba(255, 48, 196), width=2)
        draw_ship_outline(draw, split_right, rgba(14, 12, 23), rgba(255, 48, 196), width=2)

    draw_basic(raw, phase)

    seam_left = transform_points(
        [
            (center[0] - 7, center[1] - 19),
            (center[0] - 13 - generation * 2, center[1] + 3),
            (center[0] - 9, center[1] + 18),
        ],
        center,
        rotate_degrees=lean,
    )
    seam_right = [(center[0] * 2 - x, y) for x, y in seam_left]
    draw_accent_seam(raw, seam_left, generation)
    draw_accent_seam(raw, seam_right, generation)
    if generation == 4:
        core = transform_points([(center[0], center[1] - 5)], center, rotate_degrees=lean)[0]
        glow_circle(raw, core, 10.0, rgba(255, 48, 196, 175), blur=4.0)
        draw.ellipse((core[0] - 4, core[1] - 4, core[0] + 4, core[1] + 4), fill=rgba(255, 208, 244))
    draw_hostile_flare(raw, center[0] - 10, center[1] + 29, phase, generation, 0.9)
    draw_hostile_flare(raw, center[0] + 10, center[1] + 29, phase + 0.7, generation, 0.9)


def draw_fast_generation(raw: Image.Image, phase: float, generation: int) -> None:
    if generation == 1:
        draw_fast(raw, phase)
        return

    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 1.2) * 1.4
    lean = math.sin(phase * 1.1 + 0.3) * 7.0
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    accent = GENERATION_ACCENTS[generation]

    wing_left = [
        (center[0] - 10, center[1] - 7),
        (center[0] - 31 - generation * 5, center[1] + 3),
        (center[0] - 28 - generation * 3, center[1] + 14),
        (center[0] - 8, center[1] + 8),
    ]
    wing_right = [(center[0] * 2 - x, y) for x, y in wing_left]
    wing_left = transform_points(wing_left, center, rotate_degrees=lean)
    wing_right = transform_points(wing_right, center, rotate_degrees=lean)
    draw_ship_outline(draw, wing_left, rgba(68, 31, 15), tint(accent, 0.85), width=2)
    draw_ship_outline(draw, wing_right, rgba(68, 31, 15), tint(accent, 0.85), width=2)

    if generation >= 3:
        vanes = [
            [
                (center[0] - 18, center[1] + 8),
                (center[0] - 38, center[1] + 22),
                (center[0] - 29, center[1] + 31),
                (center[0] - 11, center[1] + 15),
            ],
            [
                (center[0] + 18, center[1] + 8),
                (center[0] + 38, center[1] + 22),
                (center[0] + 29, center[1] + 31),
                (center[0] + 11, center[1] + 15),
            ],
        ]
        for vane in vanes:
            transformed = transform_points(vane, center, rotate_degrees=lean)
            draw_ship_outline(draw, transformed, rgba(24, 20, 24), accent, width=2)

    if generation == 4:
        phase_blades = [
            [
                (center[0] - 6, center[1] - 28),
                (center[0] - 17, center[1] - 42),
                (center[0] - 12, center[1] - 8),
            ],
            [
                (center[0] + 6, center[1] - 28),
                (center[0] + 17, center[1] - 42),
                (center[0] + 12, center[1] - 8),
            ],
        ]
        for blade in phase_blades:
            transformed = transform_points(blade, center, rotate_degrees=lean)
            draw_ship_outline(draw, transformed, rgba(12, 11, 22), rgba(255, 48, 196), width=2)
            glow_polygon(raw, transformed, rgba(255, 48, 196, 60), blur=4.0)

    draw_fast(raw, phase)
    spine = transform_points(
        [(center[0], center[1] - 31), (center[0], center[1] + 22)],
        center,
        rotate_degrees=lean,
    )
    draw_accent_seam(raw, spine, generation, width=3)
    draw_hostile_flare(raw, center[0], center[1] + 29, phase, generation, 1.1)
    if generation == 4:
        trail = [
            (center[0] - 7, center[1] + 15),
            (center[0] + 7, center[1] + 15),
            (center[0] + 2, center[1] + 55),
            (center[0] - 2, center[1] + 55),
        ]
        trail = transform_points(trail, center, rotate_degrees=lean)
        glow_polygon(raw, trail, rgba(255, 48, 196, 90), blur=5.0)


def draw_tank_generation(raw: Image.Image, phase: float, generation: int) -> None:
    if generation == 1:
        draw_tank(raw, phase)
        return

    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.7) * 1.3
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    accent = GENERATION_ACCENTS[generation]

    shoulder_left = [
        (center[0] - 25, center[1] - 27),
        (center[0] - 48 - generation * 2, center[1] - 17),
        (center[0] - 52 - generation * 2, center[1] + 17),
        (center[0] - 27, center[1] + 26),
    ]
    shoulder_right = [(center[0] * 2 - x, y) for x, y in shoulder_left]
    draw_ship_outline(draw, shoulder_left, rgba(44, 19, 63), tint(accent, 0.78), width=3)
    draw_ship_outline(draw, shoulder_right, rgba(44, 19, 63), tint(accent, 0.78), width=3)

    if generation >= 3:
        ring_points: list[tuple[float, float]] = []
        for i in range(12):
            angle = math.tau * i / 12.0
            radius = 54.0 if i % 2 == 0 else 48.0
            ring_points.append((center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius))
        draw.line(ring_points + [ring_points[0]], fill=accent, width=3, joint="curve")
        for i in range(0, 12, 2):
            x, y = ring_points[i]
            glow_circle(raw, (x, y), 5.0, (*accent[:3], 120), blur=2.5)

    if generation == 4:
        for dx in (-40, 40):
            stabilizer = [
                (center[0] + dx - 7, center[1] + 14),
                (center[0] + dx + 7, center[1] + 14),
                (center[0] + dx + 13, center[1] + 54),
                (center[0] + dx, center[1] + 65),
                (center[0] + dx - 13, center[1] + 54),
            ]
            draw_ship_outline(draw, stabilizer, rgba(13, 11, 21), rgba(255, 48, 196), width=2)
            glow_polygon(raw, stabilizer, rgba(255, 48, 196, 42), blur=4.0)

    draw_tank(raw, phase)
    for dx in (-28, 28):
        draw_accent_seam(
            raw,
            [(center[0] + dx, center[1] - 22), (center[0] + dx, center[1] + 23)],
            generation,
            width=3,
        )
    if generation == 4:
        core = (center[0], center[1] + 2)
        glow_circle(raw, core, 17.0, rgba(255, 48, 196, 190), blur=5.0)
        draw.ellipse((core[0] - 7, core[1] - 7, core[0] + 7, core[1] + 7), fill=rgba(255, 210, 245))


def draw_bomber_generation(raw: Image.Image, phase: float, generation: int) -> None:
    if generation == 1:
        draw_bomber(raw, phase)
        return

    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.9) * 1.9
    lean = math.sin(phase * 0.8 + 0.2) * 3.0
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    accent = GENERATION_ACCENTS[generation]

    rack_left = [
        (center[0] - 31, center[1] - 8),
        (center[0] - 58 - generation * 2, center[1] - 2),
        (center[0] - 60 - generation * 2, center[1] + 20),
        (center[0] - 28, center[1] + 15),
    ]
    rack_right = [(center[0] * 2 - x, y) for x, y in rack_left]
    rack_left = transform_points(rack_left, center, rotate_degrees=lean)
    rack_right = transform_points(rack_right, center, rotate_degrees=lean)
    draw_ship_outline(draw, rack_left, rgba(22, 52, 29), tint(accent, 0.84), width=2)
    draw_ship_outline(draw, rack_right, rgba(22, 52, 29), tint(accent, 0.84), width=2)

    pod_count = generation
    for side in (-1, 1):
        for idx in range(pod_count):
            x = center[0] + side * (34 + idx * 8)
            y = center[1] + 6 + idx * 6
            pod = [
                (x - 5, y - 9),
                (x + 5, y - 9),
                (x + 7, y + 9),
                (x, y + 14),
                (x - 7, y + 9),
            ]
            pod = transform_points(pod, center, rotate_degrees=lean)
            fill = rgba(13, 12, 18) if generation == 4 else rgba(52, 61, 31)
            draw_ship_outline(draw, pod, fill, accent, width=2)

    if generation >= 3:
        bay_frame = [
            (center[0] - 18, center[1] - 2),
            (center[0] + 18, center[1] - 2),
            (center[0] + 22, center[1] + 31),
            (center[0], center[1] + 43),
            (center[0] - 22, center[1] + 31),
        ]
        bay_frame = transform_points(bay_frame, center, rotate_degrees=lean)
        draw_ship_outline(draw, bay_frame, rgba(18, 22, 18), accent, width=2)

    draw_bomber(raw, phase)
    seam = transform_points(
        [(center[0] - 18, center[1] - 8), (center[0], center[1] + 26), (center[0] + 18, center[1] - 8)],
        center,
        rotate_degrees=lean,
    )
    draw_accent_seam(raw, seam, generation, width=3)
    if generation == 4:
        for dx in (-24, 24):
            core = transform_points([(center[0] + dx, center[1] + 4)], center, rotate_degrees=lean)[0]
            glow_circle(raw, core, 9.0, rgba(255, 48, 196, 150), blur=3.8)


def draw_sniper_generation(raw: Image.Image, phase: float, generation: int) -> None:
    if generation == 1:
        draw_sniper(raw, phase)
        return

    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.9) * 1.5
    lean = math.sin(phase * 0.8) * 1.4
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)
    accent = GENERATION_ACCENTS[generation]

    vane_left = [
        (center[0] - 13, center[1] - 18),
        (center[0] - 35 - generation * 3, center[1] - 30),
        (center[0] - 31 - generation * 2, center[1] - 7),
        (center[0] - 12, center[1] + 3),
    ]
    vane_right = [(center[0] * 2 - x, y) for x, y in vane_left]
    vane_left = transform_points(vane_left, center, rotate_degrees=lean)
    vane_right = transform_points(vane_right, center, rotate_degrees=lean)
    draw_ship_outline(draw, vane_left, rgba(11, 43, 58), tint(accent, 0.82), width=2)
    draw_ship_outline(draw, vane_right, rgba(11, 43, 58), tint(accent, 0.82), width=2)

    if generation >= 3:
        for dx in (-9, 9):
            rail = [
                (center[0] + dx - 3, center[1] - 25),
                (center[0] + dx + 3, center[1] - 25),
                (center[0] + dx + 4, center[1] - 62 - generation * 3),
                (center[0] + dx - 4, center[1] - 62 - generation * 3),
            ]
            rail = transform_points(rail, center, rotate_degrees=lean)
            fill = rgba(13, 13, 22) if generation == 4 else rgba(25, 67, 76)
            draw_ship_outline(draw, rail, fill, accent, width=2)
            glow_polygon(raw, rail, (*accent[:3], 48), blur=3.5)

    if generation == 4:
        rear_prongs = [
            [
                (center[0] - 10, center[1] + 13),
                (center[0] - 24, center[1] + 42),
                (center[0] - 12, center[1] + 35),
            ],
            [
                (center[0] + 10, center[1] + 13),
                (center[0] + 24, center[1] + 42),
                (center[0] + 12, center[1] + 35),
            ],
        ]
        for prong in rear_prongs:
            prong = transform_points(prong, center, rotate_degrees=lean)
            draw_ship_outline(draw, prong, rgba(12, 11, 20), rgba(255, 48, 196), width=2)

    draw_sniper(raw, phase)
    barrel_seam = transform_points(
        [(center[0], center[1] - 72 if generation >= 3 else center[1] - 52), (center[0], center[1] + 18)],
        center,
        rotate_degrees=lean,
    )
    draw_accent_seam(raw, barrel_seam, generation, width=3)
    target = transform_points([(center[0], center[1] - 7)], center, rotate_degrees=lean)[0]
    glow_circle(raw, target, 10.0 + generation, (*accent[:3], 155), blur=4.0)
    draw_hostile_flare(raw, center[0], center[1] + 28, phase, generation, 0.8)


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
    draw_ship_outline(draw, chassis, rgba(14, 12, 24), rgba(255, 48, 196), width=2)
    glow_polygon(raw, chassis, rgba(255, 36, 184, 48), blur=8.0)

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
    draw.polygon(left_blade, fill=rgba(45, 18, 67))
    draw.polygon(right_blade, fill=rgba(45, 18, 67))
    draw.line(left_blade + [left_blade[0]], fill=rgba(255, 190, 52), width=2)
    draw.line(right_blade + [right_blade[0]], fill=rgba(255, 190, 52), width=2)

    # Side emitters
    for dx, dy, r in [(-20, -2, 6), (20, -2, 6), (-18, 22, 5), (18, 22, 5)]:
        glow_circle(raw, (center[0] + dx, center[1] + dy), r, rgba(255, 176, 48, 145), blur=3.2)
        draw.ellipse(
            (center[0] + dx - 2, center[1] + dy - 2, center[0] + dx + 2, center[1] + dy + 2),
            fill=rgba(255, 235, 180),
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
    glow_circle(raw, core, 18.0, rgba(255, 48, 196, int(175 * pulse)), blur=5.5)
    glow_circle(raw, core, 8.0, rgba(255, 198, 235, 170), blur=2.5)
    draw.ellipse((core[0] - 6, core[1] - 6, core[0] + 6, core[1] + 6), fill=rgba(255, 216, 240))

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


def draw_boss_assault(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.72) * 2.2
    roll = math.sin(phase * 0.8) * 3.0
    pulse = 0.72 + 0.28 * math.sin(phase * 2.6)
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)

    rear_left = [
        (center[0] - 18, center[1] + 10),
        (center[0] - 49, center[1] + 32),
        (center[0] - 34, center[1] + 50),
        (center[0] - 10, center[1] + 28),
    ]
    rear_right = [(center[0] * 2 - x, y) for x, y in rear_left]
    rear_left = transform_points(rear_left, center, rotate_degrees=roll)
    rear_right = transform_points(rear_right, center, rotate_degrees=roll)
    draw_ship_outline(draw, rear_left, rgba(61, 18, 22), rgba(255, 121, 42), width=3)
    draw_ship_outline(draw, rear_right, rgba(61, 18, 22), rgba(255, 121, 42), width=3)

    spear = [
        (center[0], center[1] - 72),
        (center[0] + 18, center[1] - 29),
        (center[0] + 25, center[1] + 24),
        (center[0], center[1] + 48),
        (center[0] - 25, center[1] + 24),
        (center[0] - 18, center[1] - 29),
    ]
    spear = transform_points(spear, center, rotate_degrees=roll)
    draw_ship_outline(draw, spear, rgba(154, 28, 39), rgba(255, 73, 51), width=3)
    glow_polygon(raw, spear, rgba(255, 58, 35, 40), blur=6.0)

    blade_left = [
        (center[0] - 17, center[1] - 18),
        (center[0] - 61, center[1] - 6),
        (center[0] - 47, center[1] + 11),
        (center[0] - 21, center[1] + 5),
    ]
    blade_right = [(center[0] * 2 - x, y) for x, y in blade_left]
    blade_left = transform_points(blade_left, center, rotate_degrees=roll)
    blade_right = transform_points(blade_right, center, rotate_degrees=roll)
    draw_ship_outline(draw, blade_left, rgba(88, 21, 27), rgba(255, 142, 45), width=2)
    draw_ship_outline(draw, blade_right, rgba(88, 21, 27), rgba(255, 142, 45), width=2)

    spine = transform_points(
        [(center[0], center[1] - 59), (center[0], center[1] + 34)],
        center,
        rotate_degrees=roll,
    )
    draw_accent_seam(raw, spine, 3, width=4)
    for dx in (-13, 13):
        muzzle = transform_points([(center[0] + dx, center[1] - 27)], center, rotate_degrees=roll)[0]
        glow_circle(raw, muzzle, 7.0, rgba(255, 126, 38, int(170 * pulse)), blur=3.0)
        draw.ellipse((muzzle[0] - 3, muzzle[1] - 3, muzzle[0] + 3, muzzle[1] + 3), fill=rgba(255, 230, 172))
    draw_hostile_flare(raw, center[0] - 19, center[1] + 46, phase, 3, 1.2)
    draw_hostile_flare(raw, center[0] + 19, center[1] + 46, phase + 0.8, 3, 1.2)


def draw_boss_bulwark(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.48) * 1.6
    pulse = 0.7 + 0.3 * math.sin(phase * 1.9 + 0.5)
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)

    shield_left = [
        (center[0] - 27, center[1] - 39),
        (center[0] - 72, center[1] - 23),
        (center[0] - 76, center[1] + 26),
        (center[0] - 43, center[1] + 50),
        (center[0] - 23, center[1] + 24),
    ]
    shield_right = [(center[0] * 2 - x, y) for x, y in shield_left]
    draw_ship_outline(draw, shield_left, rgba(54, 22, 78), rgba(255, 190, 52), width=3)
    draw_ship_outline(draw, shield_right, rgba(54, 22, 78), rgba(255, 190, 52), width=3)
    glow_polygon(raw, shield_left, rgba(255, 177, 43, 32), blur=6.0)
    glow_polygon(raw, shield_right, rgba(255, 177, 43, 32), blur=6.0)

    hull = [
        (center[0], center[1] - 56),
        (center[0] + 39, center[1] - 34),
        (center[0] + 45, center[1] + 24),
        (center[0] + 20, center[1] + 49),
        (center[0], center[1] + 57),
        (center[0] - 20, center[1] + 49),
        (center[0] - 45, center[1] + 24),
        (center[0] - 39, center[1] - 34),
    ]
    draw_ship_outline(draw, hull, rgba(75, 25, 111), rgba(174, 68, 228), width=3)

    for y, half_w in [(-27, 31), (-8, 38), (13, 39), (33, 27)]:
        draw.line(
            [(center[0] - half_w, center[1] + y), (center[0] + half_w, center[1] + y)],
            fill=rgba(27, 10, 38),
            width=3,
        )
    for dx, dy in [(-54, -10), (54, -10), (-49, 26), (49, 26)]:
        glow_circle(raw, (center[0] + dx, center[1] + dy), 8.0, rgba(255, 190, 52, int(150 * pulse)), blur=3.5)
        draw.ellipse(
            (center[0] + dx - 3, center[1] + dy - 3, center[0] + dx + 3, center[1] + dy + 3),
            fill=rgba(255, 235, 170),
        )
    core = (center[0], center[1] + 5)
    glow_circle(raw, core, 17.0, rgba(255, 166, 45, int(145 * pulse)), blur=5.0)
    draw.ellipse((core[0] - 7, core[1] - 7, core[0] + 7, core[1] + 7), fill=rgba(255, 220, 150))


def draw_boss_tempest(raw: Image.Image, phase: float) -> None:
    draw = ImageDraw.Draw(raw)
    bob = math.sin(phase * 0.62) * 2.0
    twist = math.sin(phase * 0.9) * 2.5
    pulse = 0.65 + 0.35 * math.sin(phase * 2.2)
    center = (RAW_CENTER[0], RAW_CENTER[1] + bob)

    arm_templates = [
        [
            (center[0] - 11, center[1] - 22),
            (center[0] - 49, center[1] - 59),
            (center[0] - 67, center[1] - 37),
            (center[0] - 25, center[1] - 5),
        ],
        [
            (center[0] + 11, center[1] - 22),
            (center[0] + 49, center[1] - 59),
            (center[0] + 67, center[1] - 37),
            (center[0] + 25, center[1] - 5),
        ],
        [
            (center[0] - 19, center[1] + 8),
            (center[0] - 63, center[1] + 34),
            (center[0] - 48, center[1] + 58),
            (center[0] - 12, center[1] + 29),
        ],
        [
            (center[0] + 19, center[1] + 8),
            (center[0] + 63, center[1] + 34),
            (center[0] + 48, center[1] + 58),
            (center[0] + 12, center[1] + 29),
        ],
    ]
    for index, arm in enumerate(arm_templates):
        direction = -1.0 if index % 2 == 0 else 1.0
        arm = transform_points(arm, center, rotate_degrees=twist * direction)
        draw_ship_outline(draw, arm, rgba(13, 11, 22), rgba(255, 48, 196), width=3)
        glow_polygon(raw, arm, rgba(255, 45, 194, 42), blur=5.0)

    inner = [
        (center[0], center[1] - 43),
        (center[0] + 30, center[1] - 18),
        (center[0] + 23, center[1] + 30),
        (center[0], center[1] + 44),
        (center[0] - 23, center[1] + 30),
        (center[0] - 30, center[1] - 18),
    ]
    draw_ship_outline(draw, inner, rgba(22, 12, 33), rgba(132, 39, 168), width=2)
    core = (center[0], center[1] + 1)
    glow_circle(raw, core, 24.0, rgba(255, 48, 196, int(175 * pulse)), blur=7.0)
    glow_circle(raw, core, 10.0, rgba(255, 184, 228, 170), blur=3.0)
    draw.ellipse((core[0] - 6, core[1] - 6, core[0] + 6, core[1] + 6), fill=rgba(255, 218, 243))
    for angle in (phase, phase + math.tau / 3.0, phase + math.tau * 2.0 / 3.0):
        point = polar(core, angle, 35.0)
        glow_circle(raw, point, 5.0, rgba(255, 181, 55, 135), blur=2.7)
        draw.ellipse((point[0] - 2, point[1] - 2, point[0] + 2, point[1] + 2), fill=rgba(255, 232, 166))


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
        glow_circle(raw, (center[0] + dx, center[1] + dy), 6.0, rgba(255, 178, 49, 145), blur=3.0)
        draw.ellipse(
            (center[0] + dx - 3, center[1] + dy - 3, center[0] + dx + 3, center[1] + dy + 3),
            fill=rgba(255, 229, 169),
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


def first_frame(strip: Image.Image, frame_index: int = 0) -> Image.Image:
    left = frame_index * FRAME_SIZE
    return strip.crop((left, 0, left + FRAME_SIZE, FRAME_SIZE))


def build_evolution_preview(
    evolution_rows: list[tuple[str, list[Image.Image]]],
    player_strip: Image.Image,
) -> Image.Image:
    label_w = 150
    cell_w = 150
    header_h = 106
    row_h = 148
    width = label_w + cell_w * 4 + 24
    height = header_h + row_h * len(evolution_rows) + 24
    sheet = Image.new("RGBA", (width, height), rgba(10, 12, 22))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    stage_names = ["GEN I · STANDARD", "GEN II · AUGMENTED", "GEN III · WARFORM", "GEN IV · APEX"]
    stage_colors = [rgba(122, 136, 164), GENERATION_ACCENTS[2], GENERATION_ACCENTS[3], GENERATION_ACCENTS[4]]

    draw.rounded_rectangle((8, 8, width - 8, height - 8), radius=16, outline=rgba(70, 83, 121), width=2)
    draw.text((20, 18), "HOSTILE EVOLUTION · GAMEPLAY-SCALE FIRST FRAMES", fill=rgba(235, 240, 255), font=font)
    draw.text(
        (20, 35),
        "Player reference and projectile palette remain cool/green; hostile tiers progress warm.",
        fill=rgba(152, 169, 202),
        font=font,
    )

    player = first_frame(player_strip)
    player.thumbnail((54, 54), RESAMPLING)
    sheet.paste(player, (20, 48), player)
    draw.ellipse((82, 67, 92, 77), fill=rgba(51, 255, 153), outline=rgba(218, 255, 233), width=1)
    draw.text((100, 67), "PLAYER / FRIENDLY", fill=rgba(92, 255, 177), font=font)

    for column, (stage_name, stage_color) in enumerate(zip(stage_names, stage_colors)):
        x = label_w + column * cell_w
        draw.rounded_rectangle((x + 6, 57, x + cell_w - 8, 95), radius=8, fill=rgba(18, 22, 36), outline=stage_color, width=2)
        draw.text((x + 13, 69), stage_name, fill=stage_color, font=font)

    for row_index, (label, frames) in enumerate(evolution_rows):
        top = header_h + row_index * row_h
        draw.rounded_rectangle(
            (14, top + 4, width - 14, top + row_h - 6),
            radius=12,
            fill=rgba(17, 21, 34),
            outline=rgba(37, 46, 70),
            width=1,
        )
        draw.text((27, top + 59), label.upper(), fill=rgba(230, 237, 255), font=font)
        draw.text((27, top + 76), "128 px cells", fill=rgba(130, 149, 185), font=font)
        for column, frame in enumerate(frames):
            x = label_w + column * cell_w + (cell_w - FRAME_SIZE) // 2
            y = top + 8
            sheet.paste(frame, (x, y), frame)

    return sheet


def add_boss_damage_preview(frame: Image.Image, severity: int) -> Image.Image:
    if severity <= 0:
        return frame.copy()
    damaged = frame.copy()
    draw = ImageDraw.Draw(damaged)
    crack_color = rgba(255, 182, 67, 235) if severity == 1 else rgba(255, 61, 75, 245)
    crack_sets = [
        [(61, 38), (56, 49), (62, 58), (55, 70)],
        [(78, 48), (70, 56), (77, 67), (68, 78)],
        [(44, 59), (52, 66), (47, 79), (56, 91)],
        [(84, 74), (75, 83), (82, 96)],
    ]
    for crack in crack_sets[: severity + 1]:
        draw.line(crack, fill=crack_color, width=2, joint="curve")
    for index in range(3 + severity * 2):
        x = 39 + (index * 17) % 54
        y = 38 + (index * 23) % 61
        glow_circle(damaged, (x, y), 3.0 + severity, (*crack_color[:3], 95), blur=2.2)
        draw.line([(x, y), (x + 3 + severity, y - 5)], fill=rgba(255, 224, 148, 230), width=1)
    if severity >= 2:
        smoke = make_overlay(damaged.size)
        smoke_draw = ImageDraw.Draw(smoke)
        smoke_draw.ellipse((73, 21, 102, 55), fill=rgba(42, 34, 51, 105))
        smoke_draw.ellipse((80, 9, 116, 43), fill=rgba(27, 25, 36, 75))
        damaged.alpha_composite(smoke.filter(ImageFilter.GaussianBlur(6.0)))
    return damaged


def build_boss_preview(bosses: list[tuple[str, Image.Image]]) -> Image.Image:
    label_w = 130
    cell_w = 142
    header_h = 82
    row_h = 148
    width = label_w + cell_w * len(bosses) + 24
    height = header_h + row_h * 3 + 24
    sheet = Image.new("RGBA", (width, height), rgba(10, 12, 22))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    row_labels = ["INTACT", "HULL BREACH", "CRITICAL"]

    draw.rounded_rectangle((8, 8, width - 8, height - 8), radius=16, outline=rgba(70, 83, 121), width=2)
    draw.text((20, 18), "BOSS VARIANTS · SILHOUETTES AND RUNTIME DAMAGE PREVIEW", fill=rgba(235, 240, 255), font=font)
    draw.text(
        (20, 35),
        "Damage rows preview shared overlays; final effects remain runtime-driven.",
        fill=rgba(152, 169, 202),
        font=font,
    )
    for column, (label, _) in enumerate(bosses):
        x = label_w + column * cell_w
        draw.text((x + 12, 60), label, fill=rgba(255, 190, 93), font=font)

    for row, row_label in enumerate(row_labels):
        top = header_h + row * row_h
        draw.rounded_rectangle(
            (14, top + 4, width - 14, top + row_h - 6),
            radius=12,
            fill=rgba(17, 21, 34),
            outline=rgba(37, 46, 70),
            width=1,
        )
        draw.text((26, top + 65), row_label, fill=rgba(225, 232, 250), font=font)
        for column, (_, strip) in enumerate(bosses):
            frame = add_boss_damage_preview(first_frame(strip), row)
            x = label_w + column * cell_w + (cell_w - FRAME_SIZE) // 2
            y = top + 8
            sheet.paste(frame, (x, y), frame)
    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    player_spec = SpriteSpec("player_idle", "player_idle_strip.png", 92, 8, draw_player)
    archetypes = [
        ("basic", "BASIC", [68, 74, 80, 85], 8, draw_basic_generation),
        ("fast", "FAST", [64, 69, 75, 80], 10, draw_fast_generation),
        ("tank", "TANK", [90, 98, 105, 112], 7, draw_tank_generation),
        ("bomber", "BOMBER", [94, 101, 110, 118], 7, draw_bomber_generation),
        ("sniper", "SNIPER", [70, 76, 82, 88], 8, draw_sniper_generation),
    ]
    evolution_specs: list[tuple[str, list[SpriteSpec]]] = []
    for slug, label, extents, fps, draw_fn in archetypes:
        generation_specs: list[SpriteSpec] = []
        for generation in range(1, 5):
            generation_specs.append(
                SpriteSpec(
                    f"{slug}_enemy_gen{generation}_idle",
                    f"{slug}_enemy_gen{generation}_idle_strip.png",
                    extents[generation - 1],
                    fps,
                    lambda raw, phase, generation=generation, draw_fn=draw_fn: draw_fn(raw, phase, generation),
                )
            )
        evolution_specs.append((label, generation_specs))

    boss_specs = [
        SpriteSpec("boss_assault_idle", "boss_assault_idle_strip.png", 118, 7, draw_boss_assault),
        SpriteSpec("boss_bulwark_idle", "boss_bulwark_idle_strip.png", 120, 6, draw_boss_bulwark),
        SpriteSpec("boss_tempest_idle", "boss_tempest_idle_strip.png", 120, 8, draw_boss_tempest),
        SpriteSpec("boss_void_harbinger_idle", "boss_void_harbinger_idle_strip.png", 120, 7, draw_boss),
        SpriteSpec("boss_tempest_core_idle", "boss_tempest_core_idle_strip.png", 120, 8, draw_tempest_core),
    ]
    specs = [player_spec]
    for _, generation_specs in evolution_specs:
        specs.extend(generation_specs)
    specs.extend(boss_specs)

    manifest: dict[str, object] = {
        "frame_size": FRAME_SIZE,
        "raw_size": RAW_SIZE,
        "anchor": {"x": FINAL_CENTER[0], "y": FINAL_CENTER[1]},
        "frames": FRAMES,
        "assets": [],
    }

    preview_rows: list[tuple[SpriteSpec, Image.Image, dict[str, float | int]]] = []
    rendered: dict[str, Image.Image] = {}

    for spec in specs:
        strip, info = render_strip(spec)
        out_path = OUT_DIR / spec.filename
        strip.save(out_path)
        rendered[spec.name] = strip
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

    evolution_rows: list[tuple[str, list[Image.Image]]] = []
    for label, generation_specs in evolution_specs:
        evolution_rows.append((label, [first_frame(rendered[spec.name]) for spec in generation_specs]))
    evolution_preview = build_evolution_preview(evolution_rows, rendered[player_spec.name])
    evolution_preview.save(OUT_DIR / "enemy_evolution_preview_sheet.png")

    boss_preview = build_boss_preview(
        [
            ("ASSAULT", rendered["boss_assault_idle"]),
            ("BULWARK", rendered["boss_bulwark_idle"]),
            ("TEMPEST", rendered["boss_tempest_idle"]),
            ("HARBINGER", rendered["boss_void_harbinger_idle"]),
            ("CORE", rendered["boss_tempest_core_idle"]),
        ]
    )
    boss_preview.save(OUT_DIR / "boss_variant_preview_sheet.png")

    with (OUT_DIR / "sprite_manifest.json").open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")

    print(f"Generated {len(specs)} sprite strips in {OUT_DIR}")


if __name__ == "__main__":
    main()
