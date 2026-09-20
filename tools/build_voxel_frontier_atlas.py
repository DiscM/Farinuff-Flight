#!/usr/bin/env python3
"""Build the original Voxel Frontier panel atlas (Python 3 + Pillow).

Run from any directory: python tools/build_voxel_frontier_atlas.py
The output is deterministic, neutral grayscale RGB. Material factors supply color.
All artwork is drawn on a 32 px tile grid and enlarged with nearest-neighbor
sampling, keeping every feature at least two texture pixels wide.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = REPO_ROOT / "assets/models/voxel_frontier"
TILE_SIZE = 64
ATLAS_SIZE = 256
PALETTE = {"recess": 92, "shadow": 136, "mid": 183, "base": 218, "light": 245}
NAMES = (
    "clean_armor", "inset_plate", "vents", "reactor_cells",
    "hull_stripes", "solar_cells", "cargo_hatch", "broken_cut_face",
    "stone", "stone_ore", "truss", "exposed_wiring",
    "warning_chevrons", "engine_grille", "heavy_armor", "clean_edge",
)
PURPOSES = (
    "Quiet hull panel with stepped highlights and four corner fasteners.",
    "Inset access plate with a thick gasket and a small release latch.",
    "Five deep ventilation slots in a bright armored surround.",
    "Four bright reactor cells inside a divided retaining frame.",
    "Two broad service stripes and a recessed longitudinal hull seam.",
    "Three by four photovoltaic cells with bright conductive bus bars.",
    "Cargo hatch with opposed doors, a center seam, and reinforced hinges.",
    "Stepped fractured cross-section with exposed dark core and bright broken edges.",
    "Angular stone planes with blocky fissures, without fine noise.",
    "Stone planes interrupted by large angular ore veins.",
    "Structural cross brace with a recessed cavity and corner mounting blocks.",
    "Open maintenance channel with three stepped cable runs and bright connectors.",
    "Broad repeating diagonal hazard chevrons inside a quiet panel surround.",
    "Engine intake grille with deep channels and a reinforced bright frame.",
    "Overlapping heavy armor slabs with a central seam and thick corner bolts.",
    "Quiet bright edge panel with a broad chamfer and sparse service marks.",
)


def build_tile(tile_id: int) -> Image.Image:
    image = Image.new("L", (32, 32), PALETTE["base"])
    draw = ImageDraw.Draw(image)

    def rect(box: tuple[int, int, int, int], value: str) -> None:
        draw.rectangle(box, fill=PALETTE[value])

    def poly(points: list[tuple[int, int]], value: str) -> None:
        draw.polygon(points, fill=PALETTE[value])

    def frame(box: tuple[int, int, int, int], fill: str = "base") -> None:
        x0, y0, x1, y1 = box
        rect(box, "shadow")
        rect((x0, y0, x1 - 1, y1 - 1), "light")
        rect((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill)

    def fasteners(points: tuple[tuple[int, int], ...] = ((4, 4), (26, 4), (4, 26), (26, 26))) -> None:
        for x, y in points:
            rect((x, y, x + 1, y + 1), "shadow")
            rect((x, y, x, y), "light")

    if tile_id == 0:
        frame((2, 2, 29, 29))
        rect((8, 7, 23, 8), "light")
        rect((8, 24, 23, 25), "mid")
        fasteners()
        rect((21, 18, 23, 18), "mid")
    elif tile_id == 1:
        frame((2, 2, 29, 29))
        rect((6, 6, 25, 25), "recess")
        frame((7, 7, 24, 24), "mid")
        rect((10, 10, 21, 20), "base")
        rect((19, 22, 22, 23), "light")
        fasteners()
    elif tile_id == 2:
        frame((2, 2, 29, 29))
        for y in (7, 11, 15, 19, 23):
            rect((7, y, 24, y + 1), "recess")
            rect((8, y + 2, 23, y + 2), "light")
        fasteners()
    elif tile_id == 3:
        frame((2, 2, 29, 29))
        rect((6, 6, 25, 25), "shadow")
        for x in (8, 17):
            for y in (8, 17):
                frame((x, y, x + 6, y + 6), "light")
                rect((x + 2, y + 2, x + 4, y + 4), "base")
        fasteners()
    elif tile_id == 4:
        frame((2, 2, 29, 29))
        rect((7, 3, 10, 28), "mid")
        rect((20, 3, 23, 28), "light")
        rect((14, 3, 15, 28), "shadow")
        rect((16, 3, 16, 28), "light")
        fasteners()
    elif tile_id == 5:
        frame((2, 2, 29, 29))
        rect((5, 5, 26, 26), "recess")
        for x in (6, 13, 20):
            for y in (6, 11, 16, 21):
                rect((x, y, x + 5, y + 3), "mid")
                rect((x, y, x + 5, y), "base")
        rect((4, 4, 27, 4), "light")
        rect((4, 27, 27, 27), "light")
    elif tile_id == 6:
        frame((2, 2, 29, 29))
        rect((5, 7, 26, 25), "shadow")
        frame((6, 8, 14, 24))
        frame((17, 8, 25, 24))
        rect((12, 14, 13, 18), "mid")
        rect((18, 14, 19, 18), "mid")
        for y in (10, 21):
            rect((3, y, 6, y + 1), "mid")
            rect((25, y, 28, y + 1), "mid")
        rect((10, 4, 21, 5), "light")
    elif tile_id == 7:
        rect((2, 2, 29, 29), "mid")
        poly([(2, 2), (26, 2), (26, 5), (22, 5), (22, 8), (18, 8), (18, 12), (12, 12), (12, 17), (7, 17), (7, 23), (2, 23)], "light")
        poly([(2, 5), (21, 5), (21, 8), (17, 8), (17, 12), (11, 12), (11, 17), (6, 17), (6, 22), (2, 22)], "base")
        poly([(12, 18), (17, 18), (17, 13), (23, 13), (23, 10), (29, 10), (29, 29), (9, 29), (9, 24), (12, 24)], "shadow")
        rect((19, 21, 25, 26), "recess")
        rect((14, 20, 15, 24), "base")
        rect((23, 15, 27, 16), "base")
    elif tile_id in (8, 9):
        poly([(0, 0), (20, 0), (20, 4), (15, 4), (15, 9), (8, 9), (8, 14), (0, 14)], "light")
        poly([(24, 0), (31, 0), (31, 31), (10, 31), (10, 27), (18, 27), (18, 21), (24, 21)], "mid")
        poly([(3, 19), (8, 19), (8, 16), (13, 16), (13, 18), (10, 18), (10, 22), (5, 22), (5, 27), (3, 27)], "shadow")
        rect((20, 7, 25, 8), "shadow")
        rect((24, 9, 25, 14), "shadow")
        if tile_id == 9:
            poly([(7, 3), (11, 3), (11, 10), (15, 10), (15, 17), (20, 17), (20, 23), (16, 23), (16, 20), (11, 20), (11, 13), (7, 13)], "shadow")
            rect((8, 4, 10, 10), "light")
            rect((12, 11, 14, 17), "light")
            rect((16, 18, 19, 21), "light")
            rect((22, 25, 25, 28), "light")
    elif tile_id == 10:
        frame((2, 2, 29, 29), "mid")
        rect((7, 7, 24, 24), "shadow")
        poly([(5, 5), (9, 5), (26, 22), (26, 26), (22, 26), (5, 9)], "base")
        poly([(22, 5), (26, 5), (26, 9), (9, 26), (5, 26), (5, 22)], "light")
        frame((13, 13, 18, 18))
        fasteners()
    elif tile_id == 11:
        frame((2, 2, 29, 29))
        rect((6, 5, 25, 26), "shadow")
        poly([(9, 6), (11, 6), (11, 15), (14, 15), (14, 25), (12, 25), (12, 17), (9, 17)], "base")
        poly([(15, 6), (17, 6), (17, 12), (20, 12), (20, 25), (18, 25), (18, 14), (15, 14)], "light")
        rect((22, 6, 23, 25), "mid")
        for x in (9, 15, 21):
            rect((x - 1, 5, x + 2, 7), "light")
        rect((10, 24, 24, 26), "base")
        fasteners()
    elif tile_id == 12:
        frame((2, 2, 29, 29))
        rect((5, 9, 26, 22), "light")
        for x in (-4, 6, 16, 26):
            # Mask broad right-facing chevrons to the central inset rectangle.
            strip = Image.new("L", (32, 32), 0)
            strip_draw = ImageDraw.Draw(strip)
            strip_draw.polygon([(x, 9), (x + 3, 9), (x + 9, 15), (x + 9, 16), (x + 3, 22), (x, 22), (x + 6, 16), (x + 6, 15)], fill=255)
            strip_draw.rectangle((0, 0, 4, 31), fill=0)
            strip_draw.rectangle((27, 0, 31, 31), fill=0)
            image.paste(PALETTE["shadow"], (0, 0), strip)
        draw = ImageDraw.Draw(image)
        fasteners()
    elif tile_id == 13:
        frame((2, 2, 29, 29), "light")
        rect((6, 6, 25, 25), "recess")
        for x in (8, 13, 18, 23):
            rect((x, 7, x + 1, 24), "base")
            rect((x, 8, x, 23), "light")
        rect((6, 15, 25, 16), "mid")
        fasteners()
    elif tile_id == 14:
        frame((2, 2, 29, 29), "mid")
        frame((4, 4, 27, 13))
        frame((4, 17, 27, 27))
        rect((11, 7, 20, 8), "light")
        rect((11, 21, 20, 22), "light")
        fasteners(((6, 6), (24, 6), (6, 24), (24, 24)))
        rect((15, 14, 16, 16), "recess")
    elif tile_id == 15:
        rect((2, 2, 29, 29), "light")
        rect((5, 5, 29, 29), "base")
        rect((27, 6, 29, 29), "mid")
        rect((6, 27, 29, 29), "mid")
        rect((22, 22, 24, 23), "light")
        rect((7, 7, 9, 8), "light")
    else:
        raise ValueError(f"Unknown tile: {tile_id}")

    return image.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.NEAREST).convert("RGB")


def build(output_root: Path) -> dict:
    texture_dir = output_root / "textures"
    docs_dir = output_root / "docs"
    texture_dir.mkdir(parents=True, exist_ok=True)
    docs_dir.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGB", (ATLAS_SIZE, ATLAS_SIZE))
    tiles = []
    for tile_id, (name, purpose) in enumerate(zip(NAMES, PURPOSES)):
        column, row = tile_id % 4, tile_id // 4
        tile = build_tile(tile_id)
        atlas.paste(tile, (column * TILE_SIZE, row * TILE_SIZE))
        tiles.append({
            "id": tile_id,
            "name": name,
            "purpose": purpose,
            "column": column,
            "row_from_top": row,
            "pixel_bounds": [column * 64, row * 64, column * 64 + 63, row * 64 + 63],
            "uv_min": [(column * 64 + 2.5) / 256, 1.0 - (row * 64 + 61.5) / 256],
            "uv_max": [(column * 64 + 61.5) / 256, 1.0 - (row * 64 + 2.5) / 256],
            "mean_luminance": round(sum(level * count for level, count in enumerate(tile.convert("L").histogram())) / (64 * 64 * 255), 4),
        })
    atlas_path = texture_dir / "voxel_surface_atlas.png"
    atlas.save(atlas_path, optimize=False, compress_level=9)
    metadata = {
        "name": "Voxel Frontier Surface Atlas",
        "version": "1.0.0",
        "provenance": "Original artwork authored procedurally for Farinuff Flight; no external image inputs.",
        "generator": "tools/build_voxel_frontier_atlas.py",
        "texture": "textures/voxel_surface_atlas.png",
        "sha256": hashlib.sha256(atlas_path.read_bytes()).hexdigest(),
        "dimensions": [256, 256],
        "tile_dimensions": [64, 64],
        "grid": [4, 4],
        "channels": "RGB; R=G=B at every pixel; opaque",
        "color_space": "sRGB base-color modulation; material base color supplies role tint",
        "palette_8bit": PALETTE,
        "min_feature_width_pixels": 2,
        "sampling": "Nearest filtering recommended. Use the inset UV bounds to avoid neighboring tiles.",
        "uv_contract": "Row-major tile IDs start at the PNG top-left. Blender UV origin is bottom-left. Image top row maps to v near 1. UV bounds are inclusive pixel centers inset 2.5 pixels from tile edges.",
        "tiles": tiles,
    }
    metadata_path = docs_dir / "atlas_tiles.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return {"texture": str(atlas_path), "tile_mapping": str(metadata_path), "sha256": metadata["sha256"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    print(json.dumps(build(args.output_root.resolve()), indent=2))
