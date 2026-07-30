#!/usr/bin/env python3
"""Generate the Farinuff Flight "cohesive pixel" mockup set (mockups_v6).

The current game mixes three art languages:

- PixelPlanets shader backgrounds (chunky pixels, posterized light bands,
  checkerboard dithering, 3-6 color ramps);
- smooth vector/neon gameplay sprites (gradients, glow, antialiasing);
- a 3D-rendered neon player ship.

This script renders mockups of every layer of the game re-drawn through the
PixelPlanets shader recipe so the whole screen reads as one art style:

1. everything is rasterized on a chunky low-resolution pixel grid;
2. light comes from a single origin and is posterized into discrete bands
   (no smooth gradients anywhere);
3. band boundaries transition through checkerboard dithering;
4. every entity uses a small fixed color ramp (dark side -> highlight);
5. every sprite carries a 1px void-colored outline, like the dark limb of
   the shader planets.

Outputs (written to mockups_v6/):

- style_guide_v6.png        the five style rules, illustrated
- fleet_sprite_sheet_v6.png the full gameplay roster in the new style
- in_game_pixel_style_v6.png a full portrait gameplay screen w/ pixel HUD
- style_comparison_v6.png   before/after against the current assets

Only the Python standard library and Pillow are used.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "mockups_v6"
FONT_PATH = ROOT / "effects" / "shaders" / "PixelPlanets" / "slkscre.ttf"
GENERATED_SPRITES = ROOT / "assets" / "sprites" / "generated"


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------


def hx(code: str) -> tuple[int, int, int, int]:
    """'#RRGGBB' -> (r, g, b, 255)."""
    return (
        int(code[1:3], 16),
        int(code[3:5], 16),
        int(code[5:7], 16),
        255,
    )


# Shared "void" space colors — sampled from the PixelPlanets backdrop.
VOID_BG = hx("#070A14")
VOID_PANEL = hx("#0D1224")
VOID_MID = hx("#182036")
VOID_HI = hx("#25304E")
OUTLINE = hx("#04050B")
STAR_WHITE = hx("#E8F4FF")

# UI accent colors (kept from the current HUD so state color-coding survives).
UI_CYAN = hx("#56E0F0")
UI_GREEN = hx("#54E88A")
UI_YELLOW = hx("#F5C542")
UI_PINK = hx("#F063C8")
UI_TEXT = hx("#D9ECF8")
UI_DIM = hx("#7A8BA8")

# Entity ramps, ordered dark -> light. Ramp length = number of light bands.
RAMP_PLAYER = [hx(c) for c in ("#1B4556", "#2E7288", "#6FBFD4", "#EAFBFF")]
RAMP_BASIC = [hx(c) for c in ("#4A0B22", "#8C1430", "#D9393F", "#FF7A66")]
RAMP_FAST = [hx(c) for c in ("#5A2A06", "#A34E0C", "#F08A24", "#FFC44D")]
RAMP_TANK = [hx(c) for c in ("#2E1550", "#5B2E96", "#9B5FD0", "#D3AEF5")]
RAMP_BOMBER = [hx(c) for c in ("#123A1C", "#25682C", "#4FA844", "#93E473")]
RAMP_SNIPER = [hx(c) for c in ("#0F2A52", "#1D4E8F", "#3E8FD4", "#8FD4F8")]
RAMP_TEMPEST = [hx(c) for c in ("#33104E", "#6B2396", "#B84FD4", "#F08CF0")]
RAMP_STAR = [hx(c) for c in ("#7A3E08", "#C47A16", "#FFD94D", "#FFF7C9")]
RAMP_BULLET_P = [hx(c) for c in ("#0E3A46", "#1F8CA6", "#5FDFF0", "#E0FDFF")]
RAMP_BULLET_E = [hx(c) for c in ("#571047", "#A02090", "#F05FD0", "#FFD9F4")]
RAMP_ROCK = [hx(c) for c in ("#232A3D", "#3D4A66", "#6E82A8", "#C2D4EC")]
RAMP_GAS = [hx(c) for c in ("#3D1458", "#7A2AA8", "#C85FD9", "#F2A6E8")]
RAMP_LAVA = [hx(c) for c in ("#3B0D0D", "#8C2413", "#E86A1F", "#FFC44D")]

# One light for the whole universe (PixelPlanets default is ~upper-left).
LIGHT = (0.34, 0.30)


# ---------------------------------------------------------------------------
# Core "shader" — the PixelPlanets recipe in Python
# ---------------------------------------------------------------------------


def _checker(x: int, y: int) -> bool:
    return (x + y) % 2 == 0


def _posterize(value: float, bands: int, x: int, y: int, dither: bool) -> int:
    """floor() the light value into a band index; dithered pixels get a nudge
    so band boundaries break into a checkerboard (should_dither in shaders)."""
    if dither and _checker(x, y):
        value += 0.45 / bands
    return max(0, min(bands - 1, int(value * bands)))


def shade_sprite(
    size: int,
    mask: Image.Image,
    ramp: list[tuple[int, int, int, int]],
    light: tuple[float, float] = LIGHT,
    dither: bool = True,
    outline: bool = True,
) -> Image.Image:
    """Shade a boolean silhouette with a posterized distance-to-light ramp."""
    bands = len(ramp)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    mp = mask.load()
    for y in range(size):
        for x in range(size):
            if not mp[x, y]:
                continue
            u = (x + 0.5) / size
            v = (y + 0.5) / size
            d = math.hypot(u - light[0], v - light[1])
            value = 1.06 - 1.75 * d
            px[x, y] = ramp[_posterize(value, bands, x, y, dither)]
    if outline:
        _add_outline(img, mask)
    return img


def _add_outline(img: Image.Image, mask: Image.Image) -> None:
    """1px void outline on empty pixels adjacent to the silhouette."""
    size = img.width
    px = img.load()
    mp = mask.load()
    edge: list[tuple[int, int]] = []
    for y in range(size):
        for x in range(size):
            if mp[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and mp[nx, ny]:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = OUTLINE


def poly_mask(size: int, *polys: list[tuple[float, float]]) -> Image.Image:
    """Rasterize polygons at native low res — aliased edges ARE the style."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    for poly in polys:
        draw.polygon([(round(px), round(py)) for px, py in poly], fill=255)
    return mask


# --- procedural noise (port of the shaders' rand/value-noise/fbm) -----------


def _hash(ix: int, iy: int, seed: float) -> float:
    t = math.sin(ix * 12.9898 + iy * 78.233 + seed * 3.71) * 43758.5453
    return t - math.floor(t)


def _vnoise(x: float, y: float, seed: float) -> float:
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    return (a + (b - a) * ux) * (1.0 - uy) + (c + (d - c) * ux) * uy


def _fbm(x: float, y: float, seed: float, octaves: int = 4) -> float:
    value = 0.0
    scale = 0.5
    for _ in range(octaves):
        value += _vnoise(x, y, seed) * scale
        x *= 2.0
        y *= 2.0
        scale *= 0.5
    return value


def _spherify(u: float, v: float) -> tuple[float, float]:
    cx, cy = u * 2.0 - 1.0, v * 2.0 - 1.0
    z = math.sqrt(max(1.0 - (cx * cx + cy * cy), 0.0001))
    return cx / (z + 1.0) * 0.5 + 0.5, cy / (z + 1.0) * 0.5 + 0.5


def render_planet(
    size: int,
    ramp: list[tuple[int, int, int, int]],
    seed: float,
    light: tuple[float, float] = LIGHT,
    noise_scale: float = 5.0,
    banded: bool = False,
    ring: list[tuple[int, int, int, int]] | None = None,
) -> Image.Image:
    """Miniature port of the PixelPlanets canvas_item shaders:
    spherified fbm noise, posterized light, checker dither, circular mask."""
    bands = len(ramp)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            u = (x + 0.5) / size
            v = (y + 0.5) / size
            if math.hypot(u - 0.5, v - 0.5) >= 0.5:
                continue
            su, sv = _spherify(u, v)
            if banded:
                # stretched noise -> horizontal cloud bands (GasPlanetLayers)
                n = _fbm(su * noise_scale * 0.6, sv * noise_scale * 2.6, seed)
            else:
                n = _fbm(su * noise_scale, sv * noise_scale, seed)
            light_d = math.hypot(u - light[0], v - light[1])
            value = n * 0.72 + (0.62 - light_d) * 0.95
            px[x, y] = ramp[_posterize(value, bands, x, y, True)]
    if ring:
        _add_ring(img, ring)
    return img


def _add_ring(img: Image.Image, ring_ramp: list[tuple[int, int, int, int]]) -> None:
    """Chunky ellipse ring; the disc covers the far half, the near half of
    the ring crosses in front of the planet (GasPlanetLayers/Ring.gdshader)."""
    size = img.width
    px = img.load()
    cx = cy = (size - 1) / 2.0
    inner, outer = 0.62 * size, 0.86 * size
    tilt = 0.38  # vertical squash of the ring ellipse
    for y in range(size):
        for x in range(size):
            ex = (x - cx) / outer
            ey = (y - cy) / (outer * tilt)
            d_outer = math.hypot(ex, ey)
            ix = (x - cx) / inner
            iy = (y - cy) / (inner * tilt)
            d_inner = math.hypot(ix, iy)
            if d_inner >= 1.0 or d_outer <= 1.0 and d_inner >= 1.0:
                pass
            on_ring = d_outer <= 1.0 and d_inner >= 1.0
            if not on_ring:
                continue
            in_disc = math.hypot(x - cx, y - cy) < size * 0.5
            if in_disc and y < cy:
                continue  # far half hides behind the planet
            t = (math.hypot((x - cx) / outer, (y - cy) / (outer * tilt)))
            band = min(len(ring_ramp) - 1, int(t * len(ring_ramp)))
            if _checker(x, y) and band > 0:
                band -= 1  # dithered ring texture
            px[x, y] = ring_ramp[band]


# ---------------------------------------------------------------------------
# Sprite factory — silhouettes + accents for the whole roster
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class SpriteSpec:
    name: str
    size: int
    ramp: list[tuple[int, int, int, int]]
    polys: tuple[tuple[tuple[float, float], ...], ...]
    accents: tuple[tuple[tuple[tuple[float, float], ...], tuple[int, int, int, int]], ...] = ()
    engine: tuple[int, int] | None = None  # pixel coords of engine glow


def _p(*pts: tuple[float, float]) -> tuple[tuple[float, float], ...]:
    return pts


def _arm(cx: float, cy: float, angle_deg: float, r0: float, r1: float, w: float,
         ) -> tuple[tuple[float, float], ...]:
    """Quad radiating from (cx, cy) — boss limbs."""
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    px_, py_ = -dy, dx
    return (
        (cx + dx * r0 + px_ * w, cy + dy * r0 + py_ * w),
        (cx + dx * r1 + px_ * w, cy + dy * r1 + py_ * w),
        (cx + dx * r1 - px_ * w, cy + dy * r1 - py_ * w),
        (cx + dx * r0 - px_ * w, cy + dy * r0 - py_ * w),
    )


def _pod(cx: float, cy: float, angle_deg: float, r: float, w: float,
         ) -> tuple[tuple[float, float], ...]:
    """Hex pod at the end of a boss limb."""
    a = math.radians(angle_deg)
    px, py = cx + math.cos(a) * r, cy + math.sin(a) * r
    return (
        (px, py - w), (px + w * 0.87, py - w * 0.5), (px + w * 0.87, py + w * 0.5),
        (px, py + w), (px - w * 0.87, py + w * 0.5), (px - w * 0.87, py - w * 0.5),
    )


SPRITES: dict[str, SpriteSpec] = {
    "player": SpriteSpec(
        "player", 24, RAMP_PLAYER,
        (_p((12, 1), (14, 6), (20, 17), (15, 15), (13, 19), (12, 17),
            (11, 19), (9, 15), (4, 17), (10, 6)),),
        accents=(
            (_p((11, 5), (13, 5), (13, 9), (11, 9)), hx("#7FFFD4")),  # cockpit stripe
        ),
        engine=(11, 19),
    ),
    "basic": SpriteSpec(
        "basic", 24, RAMP_BASIC,
        (_p((12, 2), (16, 9), (20, 18), (12, 14), (4, 18), (8, 9)),),
        accents=(
            (_p((11, 8), (13, 8), (13, 11), (11, 11)), hx("#FFC44D")),
        ),
        engine=(11, 16),
    ),
    "fast": SpriteSpec(
        "fast", 24, RAMP_FAST,
        (_p((12, 2), (15, 8), (21, 17), (17, 18), (12, 13), (7, 18), (3, 17), (9, 8)),),
        accents=(
            (_p((11, 7), (13, 7), (13, 10), (11, 10)), hx("#FFF3D6")),
        ),
        engine=(11, 14),
    ),
    "tank": SpriteSpec(
        "tank", 28, RAMP_TANK,
        (_p((14, 3), (22, 8), (22, 20), (14, 25), (6, 20), (6, 8)),),
        accents=(
            (_p((7, 10), (21, 10), (21, 11), (7, 11)), RAMP_TANK[0]),    # plate seam
            (_p((7, 17), (21, 17), (21, 18), (7, 18)), RAMP_TANK[0]),    # plate seam
            (_p((10, 13), (11, 13), (11, 14), (10, 14)), RAMP_TANK[3]),  # rivet
            (_p((17, 13), (18, 13), (18, 14), (17, 14)), RAMP_TANK[3]),  # rivet
            (_p((13, 12), (15, 12), (15, 15), (13, 15)), hx("#FF9DE2")),  # core
        ),
    ),
    "bomber": SpriteSpec(
        "bomber", 28, RAMP_BOMBER,
        (_p((14, 4), (20, 9), (26, 16), (24, 22), (18, 20), (14, 23), (10, 20), (4, 22), (2, 16), (8, 9)),),
        accents=(
            (_p((13, 9), (15, 9), (15, 12), (13, 12)), hx("#FFF3D6")),
            (_p((6, 16), (8, 16), (8, 19), (6, 19)), hx("#FFC44D")),   # bomb pods
            (_p((20, 16), (22, 16), (22, 19), (20, 19)), hx("#FFC44D")),
        ),
    ),
    "sniper": SpriteSpec(
        "sniper", 24, RAMP_SNIPER,
        (_p((12, 1), (14, 6), (14, 17), (18, 21), (12, 19), (6, 21), (10, 17), (10, 6)),),
        accents=(
            (_p((11, 4), (13, 4), (13, 14), (11, 14)), hx("#BEF3FF")),  # rail
        ),
        engine=(11, 20),
    ),
    "tempest": SpriteSpec(
        "tempest", 48, RAMP_TEMPEST,
        (
            # X-shaped limbs with hex pods, matching the original silhouette
            *[_arm(24, 24, ang, 6, 16, 3) for ang in (-45, 45, 135, 225)],
            *[_pod(24, 24, ang, 20, 4.5) for ang in (-45, 45, 135, 225)],
            _p((24, 15), (30, 19), (30, 29), (24, 33), (18, 29), (18, 19)),  # core hex
        ),
        accents=(
            (_p((21, 21), (27, 21), (27, 27), (21, 27)), hx("#FF9DE2")),  # eye
            (_p((23, 23), (26, 23), (26, 26), (23, 26)), hx("#FFF0FB")),
        ),
    ),
}


def render_sprite(spec: SpriteSpec) -> Image.Image:
    mask = poly_mask(spec.size, *[list(poly) for poly in spec.polys])
    img = shade_sprite(spec.size, mask, spec.ramp)
    draw = ImageDraw.Draw(img)
    for poly, color in spec.accents:
        draw.polygon([(round(x), round(y)) for x, y in poly], fill=color)
    if spec.engine is not None:
        ex, ey = spec.engine
        px = img.load()
        px[ex, ey] = RAMP_BULLET_P[3]
        px[ex + 1, ey] = RAMP_BULLET_P[3]
        px[ex, ey + 1] = RAMP_BULLET_P[2]
        px[ex + 1, ey + 1] = RAMP_BULLET_P[2]
    return img


def upscale(img: Image.Image, factor: int) -> Image.Image:
    return img.resize((img.width * factor, img.height * factor), Image.Resampling.NEAREST)


# --- small gameplay pieces ---------------------------------------------------


def render_bullet_p() -> Image.Image:
    img = Image.new("RGBA", (4, 12), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, 3, 11), fill=OUTLINE)
    draw.rectangle((1, 1, 2, 10), fill=RAMP_BULLET_P[2])
    draw.rectangle((1, 1, 2, 3), fill=RAMP_BULLET_P[3])
    return img


def render_bullet_e() -> Image.Image:
    size = 8
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((1, 1, size - 2, size - 2), fill=255)
    return shade_sprite(size, mask, RAMP_BULLET_E, light=(0.35, 0.3))


def render_xp_orb() -> Image.Image:
    size = 9
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((1, 1, size - 2, size - 2), fill=255)
    img = shade_sprite(size, mask, RAMP_STAR, light=(0.36, 0.32))
    px = img.load()
    px[4, 0] = RAMP_STAR[3]
    px[4, 8] = RAMP_STAR[2]
    px[0, 4] = RAMP_STAR[2]
    px[8, 4] = RAMP_STAR[2]
    return img


def render_powerup(icon: str, color: tuple[int, int, int, int]) -> Image.Image:
    """Dark dithered chip with a chunky glyph — power-ups stay color-coded."""
    size = 16
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, size - 1, size - 1), fill=OUTLINE)
    draw.rectangle((1, 1, size - 2, size - 2), fill=VOID_MID)
    for y in range(1, size - 1):
        for x in range(1, size - 1):
            if _checker(x, y):
                img.putpixel((x, y), VOID_HI)
    draw.rectangle((1, 1, size - 2, 2), fill=color)
    if icon == "rapid":
        for i in range(3):
            x0 = 3 + i * 4
            draw.polygon([(x0, 5), (x0 + 2, 8), (x0, 11)], fill=color)
    elif icon == "shield":
        draw.polygon([(8, 4), (12, 6), (12, 10), (8, 13), (4, 10), (4, 6)], outline=color, width=1)
    elif icon == "spread":
        draw.line((8, 12, 8, 5), fill=color, width=1)
        draw.line((8, 12, 4, 6), fill=color, width=1)
        draw.line((8, 12, 12, 6), fill=color, width=1)
    elif icon == "magnet":
        draw.rectangle((4, 5, 6, 11), fill=color)
        draw.rectangle((10, 5, 12, 11), fill=color)
        draw.rectangle((4, 10, 12, 12), fill=color)
        draw.rectangle((4, 5, 6, 6), fill=UI_TEXT)
        draw.rectangle((10, 5, 12, 6), fill=UI_TEXT)
    elif icon == "nuke":
        for ang in (90, 210, 330):
            r = math.radians(ang)
            cx = 8 + int(round(3 * math.cos(r)))
            cy = 8 + int(round(3 * math.sin(r)))
            draw.rectangle((cx - 1, cy - 1, cx + 1, cy + 1), fill=color)
        draw.rectangle((7, 7, 8, 8), fill=color)
    elif icon == "scale":
        draw.polygon([(8, 4), (12, 9), (10, 9), (10, 12), (6, 12), (6, 9), (4, 9)], fill=color)
    return img


def render_explosion(size: int, stage: float = 0.55) -> Image.Image:
    """Posterized ring burst with dithered debris — no soft glow."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = (size - 1) / 2.0
    radius = size * 0.5 * (0.55 + 0.45 * stage)
    ramp = [hx("#8C1430"), hx("#E86A1F"), hx("#FFC44D"), hx("#FFF7C9")]
    rng = random.Random(42)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / max(radius, 0.001)
            if d <= 1.0:
                value = 1.05 - d
                px[x, y] = ramp[_posterize(value, len(ramp), x, y, True)]
            elif d <= 1.45 and _checker(x, y) and rng.random() < 0.4:
                px[x, y] = ramp[1 + (rng.random() < 0.5)]
    return img


def render_engine_trail(length: int, color_hot, color_cool) -> Image.Image:
    """Dithered fading pixel trail below a ship."""
    img = Image.new("RGBA", (4, length), (0, 0, 0, 0))
    px = img.load()
    for y in range(length):
        fade = 1.0 - y / length
        for x in range(1, 3):
            c = color_hot if fade > 0.45 else color_cool
            if fade > 0.7 or not _checker(x, y) and fade > 0.3:
                px[x, y] = (c[0], c[1], c[2], int(255 * max(fade, 0.15)))
    return img


# ---------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------

_font_cache: dict[int, ImageFont.FreeTypeFont] = {}


def font(size: int) -> ImageFont.FreeTypeFont:
    if size not in _font_cache:
        _font_cache[size] = ImageFont.truetype(str(FONT_PATH), size)
    return _font_cache[size]


def text(draw: ImageDraw.ImageDraw, xy, s: str, size: int, color, anchor="la") -> None:
    draw.text(xy, s, font=font(size), fill=color, anchor=anchor)


# ---------------------------------------------------------------------------
# Mockup 1 — style guide
# ---------------------------------------------------------------------------


def _panel(draw: ImageDraw.ImageDraw, box, border, fill=VOID_PANEL, notch: int = 6) -> None:
    """Chunky pixel panel: notched corners, 2px border, flat dark fill."""
    x0, y0, x1, y1 = box
    draw.rectangle((x0 + notch, y0, x1 - notch, y1), fill=fill)
    draw.rectangle((x0, y0 + notch, x1, y1 - notch), fill=fill)
    for i in range(2):
        draw.line((x0 + notch, y0 + i, x1 - notch, y0 + i), fill=border)
        draw.line((x0 + notch, y1 - i, x1 - notch, y1 - i), fill=border)
        draw.line((x0 + i, y0 + notch, x0 + i, y1 - notch), fill=border)
        draw.line((x1 - i, y0 + notch, x1 - i, y1 - notch), fill=border)
    for cx, cy, sx, sy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        for step in range(notch):
            draw.point((cx + sx * (step + 1 if step > 1 else step), cy + sy * step), fill=border)
            draw.point((cx + sx * step, cy + sy * (step + 1 if step > 1 else step)), fill=border)


def _ramp_swatches(draw: ImageDraw.ImageDraw, x: int, y: int, ramp, cell: int = 22) -> None:
    for i, c in enumerate(ramp):
        draw.rectangle((x + i * cell, y, x + (i + 1) * cell - 2, y + cell - 2), fill=c)
        draw.rectangle((x + i * cell, y, x + (i + 1) * cell - 2, y + cell - 2), outline=OUTLINE)


def build_style_guide() -> Image.Image:
    W, H = 1600, 900
    img = Image.new("RGB", (W, H), VOID_BG)
    draw = ImageDraw.Draw(img)
    rng = random.Random(11)
    for _ in range(140):
        x, y = rng.randrange(W), rng.randrange(H)
        c = STAR_WHITE if rng.random() < 0.25 else VOID_HI
        draw.point((x, y), fill=c)

    text(draw, (60, 44), "FARINUFF FLIGHT", 34, UI_TEXT)
    text(draw, (60, 92), "ONE STYLE SYSTEM, BORROWED FROM THE PIXELPLANETS SHADERS", 15, UI_CYAN)
    draw.line((60, 122, W - 60, 122), fill=VOID_HI, width=2)

    rules = [
        ("1 / CHUNKY PIXEL GRID",
         "every sprite is authored at 16-48px and upscaled with NEAREST - no\nantialiasing anywhere, edges stair-step like the planet limbs."),
        ("2 / POSTERIZED LIGHT BANDS",
         "light is floor()ed into 3-4 discrete steps. gradients are banned;\nform comes from band shape, not from blending."),
        ("3 / CHECKERBOARD DITHER",
         "band boundaries and glows break into a 2px checkerboard, the same\ndither() the shaders use, so transitions sparkle like the planets."),
        ("4 / LIMITED COLOR RAMPS",
         "each entity owns one 4-step ramp (dark side -> highlight). gameplay\ncolor cues survive: red=basic, orange=fast, purple=tank..."),
        ("5 / ONE LIGHT, ONE OUTLINE",
         "a single upper-left light origin for ships, planets and UI, plus a\n1px void outline on every silhouette - the dark limb of every planet."),
    ]
    y = 156
    for title, body in rules:
        _panel(draw, (60, y, 940, y + 116), UI_CYAN)
        text(draw, (88, y + 18), title, 17, UI_YELLOW)
        for i, line in enumerate(body.split("\n")):
            text(draw, (88, y + 50 + i * 24), line, 12, UI_TEXT)
        y += 136

    # right column: reference planet + zoom inset + ramps
    _panel(draw, (980, 156, 1540, 516), UI_PINK)
    text(draw, (1006, 174), "THE REFERENCE", 15, UI_PINK)
    planet = render_planet(110, RAMP_GAS, seed=4.2, banded=True, ring=RAMP_TEMPEST)
    img.paste(upscale(planet, 3), (1006, 204), upscale(planet, 3))
    # zoom inset of the limb with grid lines
    limb = planet.crop((64, 8, 88, 32)).resize((24 * 7, 24 * 7), Image.Resampling.NEAREST)
    img.paste(limb, (1360, 200))
    gdraw = ImageDraw.Draw(img)
    for gx in range(25):
        gdraw.line((1360 + gx * 7, 200, 1360 + gx * 7, 368), fill=(255, 255, 255, 30))
    for gy in range(25):
        gdraw.line((1360, 200 + gy * 7, 1360 + 24 * 7, 200 + gy * 7), fill=(255, 255, 255, 30))
    gdraw.rectangle((1360, 200, 1360 + 24 * 7 - 1, 368 - 1), outline=UI_TEXT, width=2)
    text(draw, (1360, 378), "actual pixels", 11, UI_DIM)
    text(draw, (1006, 548 - 116), "", 10, UI_DIM)

    _panel(draw, (980, 536, 1540, 844), UI_YELLOW)
    text(draw, (1006, 554), "THE SHARED RAMPS", 15, UI_YELLOW)
    ramp_rows = [
        ("PLAYER", RAMP_PLAYER), ("BASIC", RAMP_BASIC), ("FAST", RAMP_FAST),
        ("TANK", RAMP_TANK), ("BOMBER", RAMP_BOMBER), ("SNIPER", RAMP_SNIPER),
        ("BOSS", RAMP_TEMPEST), ("ORB/STAR", RAMP_STAR), ("SPACE", [VOID_BG, VOID_PANEL, VOID_MID, VOID_HI]),
    ]
    ry = 592
    for name, ramp in ramp_rows:
        text(draw, (1006, ry + 4), name, 11, UI_TEXT)
        _ramp_swatches(draw, 1110, ry, ramp)
        ry += 28

    text(draw, (60, 868), "MOCKUP V6 - STYLE GUIDE", 11, UI_DIM)
    return img


# ---------------------------------------------------------------------------
# Mockup 2 — fleet sprite sheet
# ---------------------------------------------------------------------------


def build_fleet_sheet() -> Image.Image:
    W, H = 1600, 1000
    img = Image.new("RGB", (W, H), VOID_BG)
    draw = ImageDraw.Draw(img)
    text(draw, (60, 40), "THE FLEET, RE-PIXELATED", 30, UI_TEXT)
    text(draw, (60, 88), "same silhouettes and color cues as the current roster - drawn with the planet recipe", 13, UI_DIM)
    draw.line((60, 116, W - 60, 116), fill=VOID_HI, width=2)

    sections = [
        ("PLAYER", ["player"]),
        ("ENEMIES", ["basic", "fast", "tank", "bomber", "sniper"]),
        ("ELITE BOSS", ["tempest"]),
    ]
    x0, y0 = 60, 150
    cell = 150
    col_x = x0
    for title, names in sections:
        text(draw, (col_x, y0), title, 15, UI_CYAN)
        cx = col_x
        for name in names:
            spec = SPRITES[name]
            sprite = render_sprite(spec)
            scale = 4 if spec.size <= 28 else 2
            big = upscale(sprite, scale)
            bx = cx + (cell - big.width) // 2
            by = y0 + 36 + (120 - big.height) // 2
            _panel(draw, (cx, y0 + 28, cx + cell - 16, y0 + 28 + 124), VOID_HI)
            img.paste(big, (bx, by), big)
            text(draw, (cx + 8, y0 + 160), spec.name.upper(), 11, UI_TEXT)
            _ramp_swatches(draw, cx + 8, y0 + 182, spec.ramp, cell=16)
            cx += cell
        col_x = cx + 30

    # projectiles & pickups row
    y1 = y0 + 250
    text(draw, (x0, y1), "PROJECTILES / PICKUPS", 15, UI_CYAN)
    items = [
        ("PLAYER SHOT", render_bullet_p(), 8),
        ("ENEMY SHOT", render_bullet_e(), 8),
        ("XP ORB", render_xp_orb(), 8),
        ("RAPID", render_powerup("rapid", UI_CYAN), 5),
        ("SHIELD", render_powerup("shield", UI_GREEN), 5),
        ("SPREAD", render_powerup("spread", UI_YELLOW), 5),
        ("MAGNET", render_powerup("magnet", UI_PINK), 5),
        ("NUKE", render_powerup("nuke", hx("#FF7A66")), 5),
    ]
    cx = x0
    for label, sprite, scale in items:
        big = upscale(sprite, scale)
        _panel(draw, (cx, y1 + 28, cx + 128, y1 + 28 + 104), VOID_HI)
        img.paste(big, (cx + (128 - big.width) // 2, y1 + 28 + (104 - big.height) // 2), big)
        text(draw, (cx + 6, y1 + 140), label, 10, UI_TEXT)
        cx += 140

    # FX row
    y2 = y1 + 210
    text(draw, (x0, y2), "FEEDBACK FX", 15, UI_CYAN)
    fx_items = [
        ("EXPLOSION T1", render_explosion(26, 0.35), 4),
        ("EXPLOSION T2", render_explosion(26, 0.7), 4),
        ("ENGINE TRAIL", render_engine_trail(26, RAMP_BULLET_P[3], RAMP_BULLET_P[1]), 4),
    ]
    cx = x0
    for label, sprite, scale in fx_items:
        big = upscale(sprite, scale)
        _panel(draw, (cx, y2 + 28, cx + 148, y2 + 28 + 116), VOID_HI)
        img.paste(big, (cx + (148 - big.width) // 2, y2 + 28 + (116 - big.height) // 2), big)
        text(draw, (cx + 6, y2 + 152), label, 10, UI_TEXT)
        cx += 164

    text(draw, (x0, y2 + 210),
         "readability rule: enemy hue = threat type (unchanged), band count = size class, accents = weak points",
         12, UI_DIM)
    text(draw, (60, H - 34), "MOCKUP V6 - FLEET SHEET", 11, UI_DIM)
    return img


# ---------------------------------------------------------------------------
# Mockup 3 — full in-game screen (portrait, true 360x720 viewport x2)
# ---------------------------------------------------------------------------

GAME_W, GAME_H = 360, 720


def _starfield(draw: ImageDraw.ImageDraw, rng: random.Random, n: int) -> None:
    for _ in range(n):
        x, y = rng.randrange(GAME_W), rng.randrange(GAME_H)
        r = rng.random()
        if r < 0.06:
            c = STAR_WHITE
            draw.point((x, y), fill=c)
            draw.point(((x + 1) % GAME_W, y), fill=VOID_HI)
            draw.point((x, (y + 1) % GAME_H), fill=VOID_HI)
        elif r < 0.3:
            draw.point((x, y), fill=hx("#8FA8D8"))
        else:
            draw.point((x, y), fill=VOID_HI)


def _nebula(base: Image.Image, seed: float) -> None:
    """Posterized 2-band nebula at tiny res, upscaled chunky, alpha-composited."""
    w, h = 120, 240
    small = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = small.load()
    for y in range(h):
        for x in range(w):
            n = _fbm(x * 0.055, y * 0.055, seed, octaves=3)
            band = _posterize(n * 1.1, 3, x, y, True)
            if band == 1:
                px[x, y] = VOID_MID[:3] + (46,)
            elif band == 2:
                px[x, y] = hx("#2B2150")[:3] + (40,)
    big = small.resize((GAME_W, GAME_H), Image.Resampling.NEAREST)
    base.alpha_composite(big)


def _paste(scene: Image.Image, sprite: Image.Image, cx: float, cy: float, angle: float = 0.0) -> None:
    s = sprite
    if angle:
        s = sprite.rotate(angle, resample=Image.Resampling.NEAREST, expand=True)
    scene.alpha_composite(s, (int(cx - s.width / 2), int(cy - s.height / 2)))


def build_in_game() -> Image.Image:
    scene = Image.new("RGBA", (GAME_W, GAME_H), VOID_BG)
    _nebula(scene, seed=9.3)
    draw = ImageDraw.Draw(scene)
    rng = random.Random(7)
    _starfield(draw, rng, 110)

    # background planets (PixelPlanets, unchanged — the anchor of the style)
    moon = render_planet(46, RAMP_ROCK, seed=2.1, noise_scale=7.0)
    _paste(scene, moon, 336, 140)
    gas = render_planet(120, RAMP_GAS, seed=4.2, banded=True, ring=RAMP_TEMPEST)
    _paste(scene, gas, 66, 640)

    # --- gameplay layer -----------------------------------------------------
    bullet_p = render_bullet_p()
    bullet_e = render_bullet_e()
    orb = render_xp_orb()

    boss = render_sprite(SPRITES["tempest"])
    _paste(scene, boss, 180, 148)

    # boss radial bullet rings
    for ring_r, count in ((58, 10), (86, 14)):
        for i in range(count):
            ang = math.radians(i * 360 / count + ring_r)
            _paste(scene, bullet_e, 180 + ring_r * math.cos(ang), 148 + ring_r * math.sin(ang) * 0.92)

    enemies = [
        ("basic", 60, 250, 178), ("basic", 128, 218, 184), ("basic", 240, 232, 176),
        ("fast", 296, 262, 205), ("fast", 88, 300, 158),
        ("tank", 186, 300, 180), ("bomber", 268, 356, 182),
        ("sniper", 44, 392, 168),
    ]
    for name, ex, ey, ang in enemies:
        sprite = render_sprite(SPRITES[name])
        _paste(scene, sprite, ex, ey, angle=ang)
        if name == "fast":
            trail = render_engine_trail(14, spec_ramp(name)[3], spec_ramp(name)[1])
            _paste(scene, trail, ex, ey - 16, angle=ang)

    # xp orbs drifting from a kill
    for i, (ox, oy) in enumerate([(116, 342), (134, 358), (104, 372), (146, 344), (126, 388)]):
        _paste(scene, orb, ox, oy)

    # explosion where the kill happened
    _paste(scene, render_explosion(30, 0.6), 128, 356)

    # player + drones + spread fire
    player = render_sprite(SPRITES["player"])
    _paste(scene, render_engine_trail(20, RAMP_BULLET_P[3], RAMP_BULLET_P[1]), 180, 604)
    _paste(scene, player, 180, 590)
    drone = upscale(render_bullet_e().resize((5, 5), Image.Resampling.NEAREST), 1)
    _paste(scene, drone, 156, 574)
    _paste(scene, drone, 204, 574)
    for dx, ang in ((0, 0), (-14, -14), (14, 14)):
        for step in range(3):
            bx = 180 + dx + (ang * 0.55) * step
            by = 568 - step * 34
            _paste(scene, bullet_p, bx, by, angle=ang)

    # drifting power-up
    _paste(scene, render_powerup("spread", UI_YELLOW), 312, 470)

    # --- HUD ----------------------------------------------------------------
    hud = Image.new("RGBA", (GAME_W, GAME_H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hud)

    def panel(x0, y0, x1, y1, border):
        hd.rectangle((x0 + 2, y0, x1 - 2, y1), fill=VOID_PANEL[:3] + (235,))
        hd.rectangle((x0, y0 + 2, x1, y1 - 2), fill=VOID_PANEL[:3] + (235,))
        hd.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), outline=border)

    # left dock
    panel(6, 8, 108, 30, UI_CYAN)
    text(hd, (12, 12), "SCORE", 6, UI_DIM)
    text(hd, (52, 11), "066,650", 8, UI_TEXT)
    panel(6, 34, 108, 52, UI_CYAN)
    text(hd, (12, 38), "WAVE", 6, UI_DIM)
    text(hd, (52, 37), "21", 8, UI_TEXT)
    panel(6, 56, 108, 74, UI_YELLOW)
    text(hd, (12, 60), "MULT", 6, UI_DIM)
    text(hd, (52, 59), "x5", 8, UI_YELLOW)

    # right dock
    panel(252, 8, 354, 30, UI_GREEN)
    text(hd, (258, 12), "LIVES", 6, UI_DIM)
    for i in range(3):
        lx = 292 + i * 12
        hd.polygon([(lx, 13), (lx + 4, 10), (lx + 8, 13), (lx + 8, 20), (lx, 20)], fill=UI_GREEN)
        hd.polygon([(lx, 13), (lx + 2, 12), (lx + 2, 20), (lx, 20)], fill=hx("#2E8C52"))
    text(hd, (334, 11), "5", 8, UI_TEXT)
    panel(252, 34, 354, 52, UI_CYAN)
    text(hd, (258, 38), "ORB", 6, UI_DIM)
    for i in range(10):
        sx = 284 + i * 6
        c = UI_CYAN if i < 6 else VOID_HI
        hd.rectangle((sx, 39, sx + 4, 46), fill=c)
    text(hd, (346, 38), "", 6, UI_DIM)
    panel(252, 56, 354, 82, UI_YELLOW)
    text(hd, (258, 59), "EFFECTS", 6, UI_DIM)
    for i, (label, c) in enumerate((("RPD", UI_CYAN), ("SHD", UI_GREEN), ("DRN", UI_PINK))):
        cx0 = 258 + i * 32
        hd.rectangle((cx0, 66, cx0 + 28, 77), outline=c)
        text(hd, (cx0 + 3, 68), label, 5, c)

    # boss bar, top center below docks
    panel(64, 88, 296, 116, UI_PINK)
    text(hd, (180, 92), "ELITE BOSS", 6, UI_PINK, anchor="ma")
    text(hd, (180, 99), "TEMPEST CORE - OVERLOAD", 8, UI_TEXT, anchor="ma")
    segs = 24
    for i in range(segs):
        sx = 72 + i * 9
        c = UI_PINK if i < int(segs * 0.42) else VOID_HI
        hd.rectangle((sx, 108, sx + 7, 112), fill=c)
    scene.alpha_composite(hud)

    out = upscale(scene, 2).convert("RGB")
    _crt_pass(out)
    return out


def spec_ramp(name: str):
    return SPRITES[name].ramp


def _crt_pass(img: Image.Image) -> None:
    """Subtle scanlines + vignette — the game's CRT overlay, hinted."""
    px = img.load()
    W, H = img.size
    cx, cy = W / 2, H / 2
    max_d = math.hypot(cx, cy)
    for y in range(H):
        darken = 0.94 if y % 2 == 0 else 1.0
        for x in range(W):
            v = 1.0 - 0.22 * (math.hypot(x - cx, y - cy) / max_d) ** 2
            f = darken * v
            r, g, b = px[x, y]
            px[x, y] = (int(r * f), int(g * f), int(b * f))


# ---------------------------------------------------------------------------
# Mockup 4 — before / after comparison
# ---------------------------------------------------------------------------


def _crop_first_frame(path: Path, frames: int = 4) -> Image.Image | None:
    if not path.exists():
        return None
    sheet = Image.open(path).convert("RGBA")
    fw = sheet.width // frames
    return sheet.crop((0, 0, fw, sheet.height))


def build_comparison() -> Image.Image:
    W, H = 1600, 900
    img = Image.new("RGB", (W, H), VOID_BG)
    draw = ImageDraw.Draw(img)
    text(draw, (60, 40), "BEFORE / AFTER", 30, UI_TEXT)
    text(draw, (60, 88), "left: current smooth-vector sprites - right: the same ships through the planet recipe", 13, UI_DIM)
    draw.line((60, 116, W - 60, 116), fill=VOID_HI, width=2)

    rows = [
        ("PLAYER", "player_idle_strip.png", "player"),
        ("BASIC ENEMY", "basic_enemy_gen1_idle_strip.png", "basic"),
        ("TANK ENEMY", "tank_enemy_gen1_idle_strip.png", "tank"),
        ("TEMPEST CORE", "boss_tempest_idle_strip.png", "tempest"),
    ]
    text(draw, (250, 132), "NOW - vector / neon", 14, UI_DIM, anchor="ma")
    text(draw, (700, 132), "NEXT - pixel planets recipe", 14, UI_CYAN, anchor="ma")

    y = 160
    for label, strip_file, spec_name in rows:
        _panel(draw, (60, y, 940, y + 150), VOID_HI)
        text(draw, (78, y + 12), label, 13, UI_TEXT)
        before = _crop_first_frame(GENERATED_SPRITES / strip_file)
        if before is not None:
            bbox = before.getbbox()
            if bbox:
                before = before.crop(bbox)
            scale = min(110 / before.width, 110 / before.height)
            before = before.resize(
                (max(1, int(before.width * scale)), max(1, int(before.height * scale))),
                Image.Resampling.LANCZOS,
            )
            img.paste(before, (250 - before.width // 2, y + 82 - before.height // 2), before)
        sprite = render_sprite(SPRITES[spec_name])
        scale = 4 if sprite.width <= 28 else 2
        big = upscale(sprite, scale)
        img.paste(big, (700 - big.width // 2, y + 82 - big.height // 2), big)
        y += 168

    # right column: what carries over, what changes
    _panel(draw, (980, 160, 1540, 560), UI_CYAN)
    text(draw, (1006, 178), "WHAT STAYS", 15, UI_GREEN)
    stays = [
        "silhouettes - threats read at a glance",
        "hue = archetype color coding",
        "squash & stretch idle tweens",
        "evolution trims stack on top",
        "pixelplanets backgrounds untouched",
        "CRT overlay (it finally matches!)",
    ]
    for i, s in enumerate(stays):
        text(draw, (1006, 212 + i * 30), "+ " + s, 12, UI_TEXT)
    _panel(draw, (980, 584, 1540, 844), UI_PINK)
    text(draw, (1006, 602), "WHAT CHANGES", 15, UI_PINK)
    changes = [
        "gradients -> 4-step posterized ramps",
        "soft glow -> checkerboard dither",
        "antialiased edges -> chunky pixels",
        "3d neon ship -> flat shaded sprite",
        "rounded ui -> notched pixel panels",
        "procedural bullets -> pixel bolts",
    ]
    for i, s in enumerate(changes):
        text(draw, (1006, 636 + i * 30), "- " + s, 12, UI_TEXT)

    text(draw, (60, 868), "MOCKUP V6 - COMPARISON", 11, UI_DIM)
    return img


# ---------------------------------------------------------------------------


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "style_guide_v6.png": build_style_guide,
        "fleet_sprite_sheet_v6.png": build_fleet_sheet,
        "in_game_pixel_style_v6.png": build_in_game,
        "style_comparison_v6.png": build_comparison,
    }
    for filename, builder in outputs.items():
        img = builder()
        path = OUT_DIR / filename
        img.save(path)
        print(f"wrote {path.relative_to(ROOT)} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
