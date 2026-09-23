#!/usr/bin/env python3
"""Read an unencrypted desktop PCK and reject development/source-only content.

Format reference: Godot 4.6.3 core/io/file_access_pack.cpp, PackSourcePCK.
The actual exported pack is inspected, including imported resource records.
"""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct


FORBIDDEN_ROOTS = {"benchmarks", "design", "docs", "tests", "tools", "prompts", "references", "renders",
                   "reviews", "shots", "visual-context", "boards", "builds", ".github", ".git"}
SOURCE_EXTENSIONS = {".blend", ".blend1", ".psd", ".kra", ".aseprite", ".xcf"}
SHIPPING_AUDIO = set(json.loads(Path(__file__).with_name("shipping_audio.json").read_text()))
REQUIRED = {"project.binary", "THIRD_PARTY_NOTICES.md"}
REQUIRED_RESOURCES = {"scenes/home_base.tscn", "ui/main_menu.tscn", "scenes/native_3d_run.tscn", "scenes/flight_practice.tscn"}
REQUIRED_RESOURCES.update("assets/models/home_base/meshes/" + name for name in (
    "wayfarer_station.glb", "cargo_tug.glb", "service_drone.glb", "navigation_buoy.glb",
))
REQUIRED_RESOURCES.update("Planets/" + path for path in (
    "Asteroids/Asteroid.tscn", "DryTerran/DryTerran.tscn", "Galaxy/Galaxy.tscn",
    "GasPlanet/GasPlanet.tscn", "GasPlanetLayers/GasPlanetLayers.tscn",
    "IceWorld/IceWorld.tscn", "LandMasses/LandMasses.tscn", "LavaWorld/LavaWorld.tscn",
    "NoAtmosphere/NoAtmosphere.tscn", "Rivers/Rivers.tscn", "Star/Star.tscn", "BlackHole/BlackHole.tscn",
))
BENCHMARK_RESOURCES = {"benchmarks/candidate_performance.tscn", "benchmarks/candidate_performance.gd",
                       "benchmarks/performance_sampler.gd"}


def read_pack(path: Path) -> list[dict]:
    total = path.stat().st_size
    records = []
    with path.open("rb") as pack:
        def read(size: int) -> bytes:
            value = pack.read(size)
            if len(value) != size:
                raise ValueError("Truncated PCK")
            return value

        def number(kind: str) -> int:
            return struct.unpack("<" + kind, read(struct.calcsize("<" + kind)))[0]

        if read(4) != b"GDPC":
            raise ValueError("Expected a standalone Godot PCK")
        version = number("I")
        read(12)  # Engine major/minor/patch.
        flags = number("I")
        base = number("Q")
        if flags & ~2:  # Only relative file-base flag; no encryption or sparse packs.
            raise ValueError("Encrypted or sparse PCK is not supported")
        if version == 3:
            directory = number("Q")
            if not 104 <= directory < total:
                raise ValueError("Invalid PCK directory offset")
            pack.seek(directory)
        elif version == 2:
            read(64)
        else:
            raise ValueError(f"Unsupported PCK version: {version}")
        count = number("I")
        if count > total // 40:
            raise ValueError("Invalid PCK entry count")
        for _ in range(count):
            length = number("I")
            if not 0 < length <= 16384:
                raise ValueError("Invalid PCK path length")
            name = read(length).rstrip(b"\0").decode("utf-8").removeprefix("res://")
            offset, size = number("Q") + base, number("Q")
            digest = read(16).hex()
            entry_flags = number("I")
            if entry_flags or offset + size > total or offset < 0:
                raise ValueError(f"Invalid or unsupported PCK entry: {name}")
            records.append({"path": name, "size": size, "offset": offset, "md5": digest})
        for record in records:
            pack.seek(record["offset"])
            digest = hashlib.md5(usedforsecurity=False)
            remaining = record["size"]
            while remaining:
                block = read(min(remaining, 1024 * 1024))
                digest.update(block)
                remaining -= len(block)
            if digest.hexdigest() != record["md5"]:
                raise ValueError(f"Corrupt PCK entry: {record['path']}")
            if record["path"].endswith((".remap", ".import")):
                pack.seek(record["offset"])
                contents = read(record["size"]).decode("utf-8")
                section = re.search(r"(?ms)^\[remap\]\n(.*?)(?=^\[|\Z)", contents)
                record["remap_targets"] = re.findall(r'^path(?:\.[^=]+)?="res://([^"]+)"',
                                                     section[1] if section else "", re.MULTILINE)
    return records


def inspect(records: list[dict], *, benchmark: bool = False) -> list[str]:
    errors = []
    benchmark_paths = {name + suffix for name in BENCHMARK_RESOURCES for suffix in ("", ".remap", ".uid")}
    benchmark_paths.update(name.removesuffix(".gd") + ".gdc" for name in BENCHMARK_RESOURCES if name.endswith(".gd"))
    names = {record["path"] for record in records}
    for name in sorted(REQUIRED - names):
        errors.append(f"Missing required package file: {name}")
    for name in sorted(REQUIRED_RESOURCES):
        imported_model = name.endswith(".glb") and name + ".import" in names
        if name not in names and name + ".remap" not in names and not imported_model:
            errors.append(f"Missing runtime scene: {name}")
    if benchmark:
        for name in sorted(BENCHMARK_RESOURCES):
            if name not in names and name + ".remap" not in names:
                errors.append(f"Missing benchmark resource: {name}")
    if len(names) != len(records):
        errors.append("Duplicate package paths")
    for record in records:
        if record["path"].endswith(".remap") and not record.get("remap_targets"):
            errors.append(f"Missing remap target declaration: {record['path']}")
        for target in record.get("remap_targets", []):
            if target not in names:
                errors.append(f"Missing remap target: {record['path']} -> {target}")
    for name in sorted(SHIPPING_AUDIO):
        if name not in names and name + ".import" not in names:
            errors.append(f"Missing shipping audio: {name}")
    for name in sorted(names):
        path = PurePosixPath(name)
        if not path.parts or path.is_absolute() or ".." in path.parts:
            errors.append(f"Unsafe package path: {name}")
        elif ((path.parts[0] in FORBIDDEN_ROOTS and not (benchmark and name in benchmark_paths)) or path.parts[0].startswith("mockups")
              or "mcp_interaction_server" in name or path.suffix in SOURCE_EXTENSIONS
              or any(extension + "-" in path.name for extension in SOURCE_EXTENSIONS)):
            errors.append(f"Development/source-only file in release: {name}")
        if name.endswith((".wav.import", ".ogg.import", ".mp3.import", ".flac.import")):
            if name.removesuffix(".import") not in SHIPPING_AUDIO:
                errors.append(f"Audio outside the shipping inventory: {name}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    records = read_pack(args.pack)
    errors = inspect(records)
    args.manifest.write_text(json.dumps({"files": records, "errors": errors}, indent=2) + "\n")
    for error in errors:
        print(error)
    print(f"Package inspection: {len(records)} files, {len(errors)} errors")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
