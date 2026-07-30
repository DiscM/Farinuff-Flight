#!/usr/bin/env python3
"""Generate the Farinuff Flight "3D x pixel hybrid" mockups (mockups_v6).

The game composites four layers: starfield shader -> PixelPlanets -> a 3D
ship render layer (ship_render_layer_3d.tscn) -> 2D gameplay. The 3D layer
is the odd one out: smooth neon PBR ships over pixel-art planets.

This script proves the middle path: KEEP the GLB fleet (upgrade sockets,
lofted hulls, engine emissives) but render it through the PixelPlanets
recipe — chunky low-res rasterization, N.L posterized into discrete light
bands, checkerboard dither at band boundaries, hue-preserving color ramps,
and a 1px void outline on the silhouette (the dark limb of every planet).

The script contains a self-contained GLB loader and a z-buffered software
rasterizer (standard library + Pillow only). The camera replicates the
in-game ship layer (position 0,45,28.125, pitch -58 degrees, orthographic-
style fit), so what you see is what the real pipeline would produce.

Outputs:

- hybrid_fleet_v6.png     each model: current smooth look vs pixel hybrid
- in_game_hybrid_v6.png   full portrait gameplay screen; planets and
                          starfield untouched, hybrid ships on top
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path

from PIL import Image

import generate_pixel_style_mockups as px


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "mockups_v6"
MODELS_DIR = ROOT / "assets" / "models" / "mockups"

Vec3 = tuple[float, float, float]


# ---------------------------------------------------------------------------
# GLB loading (format written by tools/generate_mockup_models.py)
# ---------------------------------------------------------------------------


def _sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _norm(v: Vec3) -> Vec3:
    length = math.sqrt(max(_dot(v, v), 1e-12))
    return (v[0] / length, v[1] / length, v[2] / length)


def _rot_y(v: Vec3, degrees: float) -> Vec3:
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c)


def _rot_x(v: Vec3, degrees: float) -> Vec3:
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return (v[0], v[1] * c - v[2] * s, v[1] * s + v[2] * c)


class Primitive:
    __slots__ = ("positions", "normals", "indices", "base", "emissive")

    def __init__(self, positions, normals, indices, base, emissive):
        self.positions = positions
        self.normals = normals
        self.indices = indices
        self.base = base
        self.emissive = emissive


def load_glb(path: Path) -> list[Primitive]:
    data = path.read_bytes()
    magic, _version, _total = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, f"{path.name} is not a GLB"
    offset = 12
    json_len, json_type = struct.unpack_from("<II", data, offset)
    assert json_type == 0x4E4F534A
    offset += 8
    gltf = json.loads(data[offset : offset + json_len])
    offset += json_len
    bin_len, bin_type = struct.unpack_from("<II", data, offset)
    assert bin_type == 0x004E4942
    offset += 8
    binary = data[offset : offset + bin_len]

    def read_accessor(index: int) -> list[tuple[float, ...]]:
        accessor = gltf["accessors"][index]
        view = gltf["bufferViews"][accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        count = accessor["count"]
        components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
        fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[accessor["componentType"]]
        element_size = struct.calcsize(fmt) * components
        stride = view.get("byteStride") or element_size
        rows = []
        for i in range(count):
            at = start + i * stride
            rows.append(struct.unpack_from("<" + fmt * components, binary, at))
        return rows

    materials: list[tuple[Vec3, Vec3]] = []
    for material in gltf.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        base = tuple(pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])[:3])
        emissive = tuple(material.get("emissiveFactor", [0.0, 0.0, 0.0]))
        materials.append((base, emissive))

    primitives: list[Primitive] = []
    for primitive in gltf["meshes"][0]["primitives"]:
        positions = read_accessor(primitive["attributes"]["POSITION"])
        normals = read_accessor(primitive["attributes"]["NORMAL"])
        indices = [row[0] for row in read_accessor(primitive["indices"])]
        base, emissive = materials[primitive.get("material", 0)]
        primitives.append(Primitive(positions, normals, indices, base, emissive))
    return primitives


# ---------------------------------------------------------------------------
# Software rasterizer with the pixel-planets shading recipe
# ---------------------------------------------------------------------------

BAND_SCALE = (0.44, 0.68, 0.94, 1.24)
LIGHT_WORLD = _norm((-0.55, 0.80, 0.35))  # upper-left, above, slightly front


class Frame:
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.color = bytearray(width * height * 4)  # RGBA
        self.depth = [math.inf] * (width * height)


def render_model(
    primitives: list[Primitive],
    size: int,
    yaw: float = 0.0,
    pitch: float = 0.0,
    pixel_style: bool = True,
    target_height: float | None = None,
) -> Image.Image:
    """Rasterize the model from the in-game ship camera.

    pixel_style=True  -> low-res posterized bands + dither + void outline.
    pixel_style=False -> smooth supersampled lambertian ("current" look).
    """
    supersample = 1 if pixel_style else 4
    width = size * supersample
    height = size * supersample

    eye: Vec3 = (0.0, 45.0, 28.125)
    forward = _norm(_sub((0.0, 0.0, 0.0), eye))
    right = _norm(_cross(forward, (0.0, 1.0, 0.0)))
    up = _cross(right, forward)
    light_view = (_dot(LIGHT_WORLD, right), _dot(LIGHT_WORLD, up), _dot(LIGHT_WORLD, forward))

    # gather + transform all vertices into view space
    view_tris: list[tuple[list[Vec3], list[Vec3], Vec3, Vec3]] = []
    for prim in primitives:
        for t in range(0, len(prim.indices) - 2, 3):
            pts: list[Vec3] = []
            nrms: list[Vec3] = []
            for k in range(3):
                p = prim.positions[prim.indices[t + k]]
                n = prim.normals[prim.indices[t + k]]
                p = _rot_x(_rot_y(p, yaw), pitch)
                n = _norm(_rot_x(_rot_y(n, yaw), pitch))
                rel = _sub(p, eye)
                pts.append((_dot(rel, right), _dot(rel, up), _dot(rel, forward)))
                n_v = (_dot(n, right), _dot(n, up), _dot(n, forward))
                nrms.append(_norm(n_v))
            view_tris.append((pts, nrms, prim.base, prim.emissive))

    if not view_tris:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # fit projection: scale model bounds to the frame with margin
    fov_scale = 1.0 / math.tan(math.radians(28.0))
    xs: list[float] = []
    ys: list[float] = []
    for pts, _n, _b, _e in view_tris:
        for x, y, z in pts:
            if z > 0.1:
                xs.append(x / z * fov_scale)
                ys.append(y / z * fov_scale)
    span_x = max(xs) - min(xs) or 1.0
    span_y = max(ys) - min(ys) or 1.0
    target = (target_height or 0.86) * height
    scale = min(target / span_y, width * 0.9 / span_x)
    cx = width / 2.0 - scale * (max(xs) + min(xs)) / 2.0
    cy = height / 2.0 + scale * (max(ys) + min(ys)) / 2.0

    frame = Frame(width, height)

    for pts, nrms, base, emissive in view_tris:
        screen = []
        skip = False
        for x, y, z in pts:
            if z <= 0.1:
                skip = True
                break
            screen.append((cx + x / z * fov_scale * scale, cy - y / z * fov_scale * scale, z))
        if skip:
            continue
        (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = screen
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        min_x = max(0, int(math.floor(min(x0, x1, x2))))
        max_x = min(width - 1, int(math.ceil(max(x0, x1, x2))))
        min_y = max(0, int(math.floor(min(y0, y1, y2))))
        max_y = min(height - 1, int(math.ceil(max(y0, y1, y2))))
        glow = sum(emissive) > 0.12
        for py in range(min_y, max_y + 1):
            for pxx in range(min_x, max_x + 1):
                w0 = ((x1 - pxx) * (y2 - py) - (x2 - pxx) * (y1 - py)) / area
                w1 = ((x2 - pxx) * (y0 - py) - (x0 - pxx) * (y2 - py)) / area
                w2 = 1.0 - w0 - w1
                if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
                    continue
                z = w0 * z0 + w1 * z1 + w2 * z2
                idx = py * width + pxx
                if z >= frame.depth[idx]:
                    continue
                frame.depth[idx] = z
                nx = w0 * nrms[0][0] + w1 * nrms[1][0] + w2 * nrms[2][0]
                ny = w0 * nrms[0][1] + w1 * nrms[1][1] + w2 * nrms[2][1]
                nz = w0 * nrms[0][2] + w1 * nrms[1][2] + w2 * nrms[2][2]
                n = _norm((nx, ny, nz))
                if n[2] > 0.0:  # faces pointing away: flip toward the camera
                    n = (-n[0], -n[1], -n[2])
                lam = max(_dot(n, light_view), 0.0)
                if glow:
                    # engine / reactor emissive: full brightness, dither sparkle
                    boost = 1.0 + (0.22 if (pxx + py) % 2 == 0 else 0.0)
                    r = min(1.0, (base[0] * 0.30 + emissive[0] * 1.35) * boost)
                    g = min(1.0, (base[1] * 0.30 + emissive[1] * 1.35) * boost)
                    b = min(1.0, (base[2] * 0.30 + emissive[2] * 1.35) * boost)
                else:
                    light_value = 0.16 + 0.84 * lam
                    if pixel_style:
                        band = px._posterize(light_value, 4, pxx // supersample, py // supersample, True)
                        shade = BAND_SCALE[band]
                    else:
                        shade = 0.22 + 0.95 * light_value
                    r = min(1.0, base[0] * shade)
                    g = min(1.0, base[1] * shade)
                    b = min(1.0, base[2] * shade)
                    if pixel_style and shade == BAND_SCALE[3]:
                        # top band lifts toward white, like a planet's lit limb
                        r = r * 0.88 + 0.12
                        g = g * 0.88 + 0.12
                        b = b * 0.88 + 0.12
                at = idx * 4
                frame.color[at] = int(r * 255)
                frame.color[at + 1] = int(g * 255)
                frame.color[at + 2] = int(b * 255)
                frame.color[at + 3] = 255

    img = Image.frombytes("RGBA", (width, height), bytes(frame.color))
    if pixel_style:
        _silhouette_outline(img)
    elif supersample > 1:
        img = img.resize((size, size), Image.Resampling.LANCZOS)
    return img


def _silhouette_outline(img: Image.Image) -> None:
    """1px void outline on transparent pixels adjacent to the hull."""
    width, height = img.size
    src = img.load()
    edge: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height and src[nx, ny][3]:
                    edge.append((x, y))
                    break
    for x, y in edge:
        img.putpixel((x, y), px.OUTLINE)


# ---------------------------------------------------------------------------
# Model catalog
# ---------------------------------------------------------------------------

MODEL_FILES = {
    "player": "player_ship_mockup.glb",
    "drone": "player_drone_escort.glb",
    "basic": "basic_enemy_mockup.glb",
    "fast": "fast_enemy_mockup.glb",
    "bomber": "bomber_enemy_mockup.glb",
    "sniper": "sniper_enemy_mockup.glb",
    "tempest": "boss_tempest_core_mockup.glb",
    "bulwark": "boss_bulwark_mockup.glb",
}

_cache: dict[str, list[Primitive]] = {}


def model(name: str) -> list[Primitive]:
    if name not in _cache:
        if name == "player_plus":
            # upgrade modules share the player's model space: merging the
            # primitive lists is what socket attachment looks like in-game
            _cache[name] = (
                model("player")
                + load_glb(MODELS_DIR / "player_upgrade_twin_cannons.glb")
                + load_glb(MODELS_DIR / "player_upgrade_afterburner.glb")
            )
        else:
            _cache[name] = load_glb(MODELS_DIR / MODEL_FILES[name])
    return _cache[name]


# ---------------------------------------------------------------------------
# Mockup 1 — hybrid fleet sheet (smooth vs pixel, same GLBs)
# ---------------------------------------------------------------------------


def build_hybrid_fleet() -> Image.Image:
    W, H = 1600, 1030
    img = Image.new("RGB", (W, H), px.VOID_BG)
    draw = px.ImageDraw.Draw(img)
    px.text(draw, (60, 40), "SAME MODELS, NEW LIGHT", 30, px.UI_TEXT)
    px.text(
        draw,
        (60, 88),
        "the existing GLB fleet rendered through the pixelplanets recipe - low-res pass, banded N.L, dither, void outline",
        13, px.UI_DIM,
    )
    draw.line((60, 116, W - 60, 116), fill=px.VOID_HI, width=2)

    px.text(draw, (300, 130), "NOW - smooth neon 3d", 14, px.UI_DIM, anchor="ma")
    px.text(draw, (700, 130), "HYBRID - pixel shader on the same glb", 14, px.UI_CYAN, anchor="ma")

    rows = [
        ("PLAYER", "player", 0.0),
        ("PLAYER // TWIN CANNONS + AFTERBURNER", "player_plus", 0.0),
        ("DRONE ESCORT", "drone", 0.0),
        ("BASIC", "basic", 180.0),
        ("FAST", "fast", 180.0),
        ("BOMBER", "bomber", 180.0),
        ("SNIPER", "sniper", 180.0),
        ("TEMPEST CORE", "tempest", 180.0),
        ("BULWARK ARRAY", "bulwark", 180.0),
    ]
    y = 158
    row_h = 90
    for label, name, yaw in rows:
        px._panel(draw, (60, y, 940, y + row_h - 8), px.VOID_HI)
        px.text(draw, (78, y + 10), label, 12, px.UI_TEXT)
        smooth = render_model(model(name), 64, yaw=yaw, pixel_style=False)
        hybrid = render_model(model(name), 40, yaw=yaw, pixel_style=True)
        img.paste(smooth, (300 - 32, y + row_h // 2 - 34), smooth)
        big = px.upscale(hybrid, 2)
        img.paste(big, (700 - big.width // 2, y + row_h // 2 - big.height // 2), big)
        y += row_h

    px._panel(draw, (980, 158, 1540, 470), px.UI_CYAN)
    px.text(draw, (1006, 176), "THE PIPELINE (UNCHANGED SCENE TREE)", 14, px.UI_CYAN)
    notes = [
        "1. starfield + pixelplanets layers: untouched",
        "2. shipviewport renders at 1/4 res, nearest filter",
        "3. ship materials swap neon_ship_3d for a",
        "   pixel_toon_3d shader: floor(n.l * 4) bands,",
        "   checker dither, emissive engines stay hot",
        "4. silhouette outline in the composite pass",
        "   replaces neon_outline_3d",
    ]
    for i, line in enumerate(notes):
        px.text(draw, (1006, 210 + i * 28), line, 12, px.UI_TEXT)

    px._panel(draw, (980, 494, 1540, 844), px.UI_YELLOW)
    px.text(draw, (1006, 512), "WHY THIS WINS", 14, px.UI_YELLOW)
    wins = [
        "upgrade modules keep their sockets -",
        "  twin cannons / afterburner still bolt on",
        "banking + boss dashes = real 3d rotation,",
        "  re-pixelated every frame, always crisp",
        "engine emissives survive as dithered glow",
        "one shader, whole fleet - no sprite atlas",
        "  to redraw per evolution stage",
        "squash/stretch tweens keep working",
    ]
    for i, line in enumerate(wins):
        px.text(draw, (1006, 546 + i * 30), line, 12, px.UI_TEXT)

    px.text(draw, (60, 998), "MOCKUP V6 - 3D X PIXEL HYBRID FLEET", 11, px.UI_DIM)
    return img


# ---------------------------------------------------------------------------
# Mockup 2 — full in-game screen with hybrid ships
# ---------------------------------------------------------------------------


def build_in_game_hybrid() -> Image.Image:
    scene = Image.new("RGBA", (px.GAME_W, px.GAME_H), px.VOID_BG)
    px._nebula(scene, seed=9.3)
    draw = px.ImageDraw.Draw(scene)
    import random as _random

    rng = _random.Random(7)
    px._starfield(draw, rng, 110)

    # --- background: pixelplanets + starfield, exactly as today --------------
    moon = px.render_planet(46, px.RAMP_ROCK, seed=2.1, noise_scale=7.0)
    px._paste(scene, moon, 336, 140)
    gas = px.render_planet(120, px.RAMP_GAS, seed=4.2, banded=True, ring=px.RAMP_TEMPEST)
    px._paste(scene, gas, 66, 640)

    # --- gameplay: hybrid 3d ships -------------------------------------------
    bullet_p = px.render_bullet_p()
    bullet_e = px.render_bullet_e()
    orb = px.render_xp_orb()

    boss = render_model(model("tempest"), 56, yaw=180.0)
    px._paste(scene, boss, 180, 150)

    for ring_r, count in ((60, 10), (88, 14)):
        for i in range(count):
            ang = math.radians(i * 360 / count + ring_r)
            px._paste(scene, bullet_e, 180 + ring_r * math.cos(ang), 150 + ring_r * math.sin(ang) * 0.92)

    enemies = [
        ("basic", 62, 252, 180.0), ("basic", 130, 220, 172.0), ("basic", 238, 234, 188.0),
        ("fast", 294, 268, 205.0), ("fast", 88, 306, 155.0),
        ("bomber", 268, 356, 182.0),
        ("sniper", 44, 392, 168.0),
    ]
    sizes = {"basic": 26, "fast": 24, "bomber": 30, "sniper": 26}
    for name, ex, ey, yaw in enemies:
        sprite = render_model(model(name), sizes[name], yaw=yaw)
        px._paste(scene, sprite, ex, ey)

    for i, (ox, oy) in enumerate([(116, 342), (134, 358), (104, 372), (146, 344), (126, 388)]):
        px._paste(scene, orb, ox, oy)
    px._paste(scene, px.render_explosion(30, 0.6), 128, 356)

    # player + drones + spread fire
    px._paste(scene, px.render_engine_trail(20, px.RAMP_BULLET_P[3], px.RAMP_BULLET_P[1]), 180, 606)
    player = render_model(model("player"), 30, yaw=0.0)
    px._paste(scene, player, 180, 590)
    drone = render_model(model("drone"), 14, yaw=0.0)
    px._paste(scene, drone, 152, 572)
    px._paste(scene, drone, 208, 572)
    for dx, ang in ((0, 0), (-14, -14), (14, 14)):
        for step in range(3):
            px._paste(scene, bullet_p, 180 + dx + (ang * 0.55) * step, 566 - step * 34, angle=ang)

    px._paste(scene, px.render_powerup("spread", px.UI_YELLOW), 312, 470)

    # --- HUD (same pixel HUD as v6) -------------------------------------------
    _draw_hud(scene)

    out = px.upscale(scene, 2).convert("RGB")
    px._crt_pass(out)
    return out


def _draw_hud(scene: Image.Image) -> None:
    hud = Image.new("RGBA", (px.GAME_W, px.GAME_H), (0, 0, 0, 0))
    hd = px.ImageDraw.Draw(hud)

    def panel(x0, y0, x1, y1, border):
        hd.rectangle((x0 + 2, y0, x1 - 2, y1), fill=px.VOID_PANEL[:3] + (235,))
        hd.rectangle((x0, y0 + 2, x1, y1 - 2), fill=px.VOID_PANEL[:3] + (235,))
        hd.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), outline=border)

    panel(6, 8, 108, 30, px.UI_CYAN)
    px.text(hd, (12, 12), "SCORE", 6, px.UI_DIM)
    px.text(hd, (52, 11), "066,650", 8, px.UI_TEXT)
    panel(6, 34, 108, 52, px.UI_CYAN)
    px.text(hd, (12, 38), "WAVE", 6, px.UI_DIM)
    px.text(hd, (52, 37), "21", 8, px.UI_TEXT)
    panel(6, 56, 108, 74, px.UI_YELLOW)
    px.text(hd, (12, 60), "MULT", 6, px.UI_DIM)
    px.text(hd, (52, 59), "x5", 8, px.UI_YELLOW)

    panel(252, 8, 354, 30, px.UI_GREEN)
    px.text(hd, (258, 12), "LIVES", 6, px.UI_DIM)
    for i in range(3):
        lx = 292 + i * 12
        hd.polygon([(lx, 13), (lx + 4, 10), (lx + 8, 13), (lx + 8, 20), (lx, 20)], fill=px.UI_GREEN)
        hd.polygon([(lx, 13), (lx + 2, 12), (lx + 2, 20), (lx, 20)], fill=px.hx("#2E8C52"))
    px.text(hd, (334, 11), "5", 8, px.UI_TEXT)
    panel(252, 34, 354, 52, px.UI_CYAN)
    px.text(hd, (258, 38), "ORB", 6, px.UI_DIM)
    for i in range(10):
        sx = 284 + i * 6
        hd.rectangle((sx, 39, sx + 4, 46), fill=px.UI_CYAN if i < 6 else px.VOID_HI)
    panel(252, 56, 354, 82, px.UI_YELLOW)
    px.text(hd, (258, 59), "EFFECTS", 6, px.UI_DIM)
    for i, (label, c) in enumerate((("RPD", px.UI_CYAN), ("SHD", px.UI_GREEN), ("DRN", px.UI_PINK))):
        cx0 = 258 + i * 32
        hd.rectangle((cx0, 66, cx0 + 28, 77), outline=c)
        px.text(hd, (cx0 + 3, 68), label, 5, c)

    panel(64, 88, 296, 116, px.UI_PINK)
    px.text(hd, (180, 92), "ELITE BOSS", 6, px.UI_PINK, anchor="ma")
    px.text(hd, (180, 99), "TEMPEST CORE - OVERLOAD", 8, px.UI_TEXT, anchor="ma")
    segs = 24
    for i in range(segs):
        sx = 72 + i * 9
        hd.rectangle((sx, 108, sx + 7, 112), fill=px.UI_PINK if i < int(segs * 0.42) else px.VOID_HI)
    scene.alpha_composite(hud)


# ---------------------------------------------------------------------------


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "hybrid_fleet_v6.png": build_hybrid_fleet,
        "in_game_hybrid_v6.png": build_in_game_hybrid,
    }
    for filename, builder in outputs.items():
        img = builder()
        path = OUT_DIR / filename
        img.save(path)
        print(f"wrote {path.relative_to(ROOT)} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
