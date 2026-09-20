#!/usr/bin/env python3
"""Validate and package the original animated Voxel Bosses collection.

Reuses the previous pack's read-only GLB/PNG parser without changing that pack.
The new catalog supplies explicit rig, mesh, clip and socket contracts.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys
import tempfile
import zipfile
import zlib

import package_voxel_frontier as shared


ASSET_ROOT = Path("assets/models/voxel_bosses")
DESIGN_ROOT = Path("design/voxel-bosses")
PACKAGE_NAME = "Farinuff_Flight_Voxel_Bosses_1.0.0"
CORE_FILES = (
    "tools/package_voxel_bosses.py",
    "tools/package_voxel_frontier.py",
    "tools/build_voxel_bosses_blender.py",
    "tools/build_voxel_frontier_blender.py",
    "tools/build_voxel_frontier_atlas.py",
    "tools/build_combat_motion_blender.py",
    "tools/voxel_boss_motion.py",
    "effects/ship_motion_3d.gd",
    "effects/rendering/enemy_surface_materials.gd",
    "effects/shaders/models/imported_enemy_surface_3d.gdshader",
    "effects/shaders/models/pixel_planet_enemy_3d.gdshader",
    "effects/shaders/PixelPlanets/LICENSE",
)
require = shared.require
digest = shared.digest
json_bytes = shared.json_bytes


def audit_asset(path, spec):
    model = shared.GLB(path)
    report = model.audit(spec["id"])
    nodes, skins = model.doc["nodes"], model.doc.get("skins", [])
    names = [node.get("name", "") for node in nodes]
    require(len(names) == len(set(names)), "Duplicate exported node names")
    require(len(skins) == 1, "Each boss asset must have one rigid skeleton")
    require(report["mesh_nodes"] == spec["mesh_nodes"], f"{path.name}: mesh count differs from catalog")
    joint_ids = skins[0]["joints"]
    joint_names = {nodes[index]["name"] for index in joint_ids}
    require(joint_names == set(spec["bones"]), f"{path.name}: bone names differ from catalog")
    require(spec["rig_node"] in names, f"{path.name}: named rig node missing")
    render_nodes = [node for node in nodes if "mesh" in node]
    require(all(node.get("skin") == 0 for node in render_nodes), "Every boss mesh must bind to the authored skeleton")
    require({item["name"] for item in report["animations"]} == set(spec["clips"]), "Boss animation names differ from catalog")
    for animation in report["animations"]:
        expected = spec["clip_durations_seconds"][animation["name"]]
        require(abs(animation["duration_seconds"] - expected) <= 1.0 / 30.0 + 0.001, f"{path.name}: {animation['name']} duration differs from authored timing")
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            require(child not in parents, "Scene node has multiple parents")
            parents[child] = index
    sockets = {}
    for name, expected_bone in spec["sockets"].items():
        require(name in names, f"{path.name}: missing socket {name}")
        index = names.index(name)
        require("mesh" not in nodes[index], "Socket must be a transform marker")
        ancestor = parents.get(index)
        while ancestor is not None and ancestor not in joint_ids:
            ancestor = parents.get(ancestor)
        require(ancestor is not None and nodes[ancestor]["name"] == expected_bone, f"{name}: socket does not follow expected {expected_bone} bone")
        sockets[name] = {"bone": expected_bone, "local_translation": nodes[index].get("translation", [0, 0, 0])}
    require({name for name in names if name.startswith("Socket_")} == set(spec["sockets"]), "Uncatalogued or missing socket markers")
    motion, endpoints = [], {}
    for animation in model.doc["animations"]:
        moving_bones = set()
        endpoints[animation["name"]] = {}
        for channel in animation["channels"]:
            sampler = animation["samplers"][channel["sampler"]]
            values = model.accessor(sampler["output"])
            if sampler.get("interpolation", "LINEAR") == "CUBICSPLINE":
                values = values[1::3]
            changed = any(any(abs(value[i] - values[0][i]) > 1e-5 for i in range(len(value))) for value in values[1:])
            target = channel["target"]["node"]
            if target in joint_ids:
                endpoints[animation["name"]][(target, channel["target"]["path"])] = (values[0], values[-1])
            if changed and target in joint_ids:
                moving_bones.add(nodes[target]["name"])
        require(moving_bones, f"{path.name}: {animation['name']} contains no animated bone motion")
        motion.append({"clip": animation["name"], "moving_bones": sorted(moving_bones)})
    def same_pose(left_clip, left_end, right_clip, right_end):
        left, right = endpoints[left_clip], endpoints[right_clip]
        require(set(left) == set(right), "Clip channel sets differ; cannot establish pose continuity")
        for channel, left_values in left.items():
            a, b = left_values[left_end], right[channel][right_end]
            distance = max(abs(x - y) for x, y in zip(a, b))
            if channel[1] == "rotation":
                distance = min(distance, max(abs(x + y) for x, y in zip(a, b)))
            require(distance <= 0.0002, f"{path.name}: pose discontinuity {left_clip}→{right_clip} on {nodes[channel[0]]['name']}/{channel[1]}")
    same_pose("cruise", 0, "cruise", 1)
    same_pose("hit", 0, "hit", 1)
    same_pose("windup", 1, "attack", 0)
    same_pose("attack", 1, "cruise", 0)
    report.update({"name": spec["name"], "role": spec["role"], "rig_node": spec["rig_node"], "bones": sorted(joint_names), "sockets": sockets, "motion": motion, "pose_continuity": "pass: cruise loop, hit return, windup-to-attack handoff, attack-to-idle return"})
    return report


def collect(root):
    directory = root / ASSET_ROOT
    catalog = json.loads((directory / "docs/catalog.json").read_text())
    specs = catalog["assets"]
    require(len({item["id"] for item in specs}) == len(specs), "Duplicate stable asset IDs")
    require({path.name for path in (directory / "meshes").glob("*.glb")} == {item["file"] for item in specs}, "Boss mesh inventory differs from catalog")
    reports = [audit_asset(directory / "meshes" / item["file"], item) for item in specs]
    textures = [{"file": path.relative_to(root).as_posix(), **shared.png_info(path.read_bytes())} for path in sorted((directory / "textures").glob("*.png"))]
    require(textures, "Portable external atlas PNG missing")
    require(all(texture["width"] == texture["height"] == 256 for texture in textures), "Shared atlas must remain 256 × 256")
    pixels = {(image["width"], image["height"], image["rgba_pixels_sha256"]) for image in textures}
    for report in reports:
        require(all((image["width"], image["height"], image["rgba_pixels_sha256"]) in pixels for image in report["embedded_images"]), report["file"] + ": embedded atlas pixels differ from packaged PNG")
    return {"schema_version": 1, "package_id": catalog["package_id"], "status": "pass", "evidence_type": "Static file validation; rendered and gameplay evidence is separate", "policy": {"max_triangles_per_asset": shared.MAX_TRIANGLES, "max_vertices_per_asset": shared.MAX_VERTICES, "required_texture": "embedded 256×256 atlas on every material; distinct base-color tints", "rig": "one four-bone rigid skeleton on every asset", "sockets": "exact named markers parented to their catalogued bone", "clips": "cruise, hit, windup, attack; actual nonconstant bone motion required", "collisionless": True}, "assets": reports, "textures": textures}


def technical_sheet(report):
    lines = ["# Voxel Bosses — technical inventory", "", "Bounds are measured from the delivered GLB rest scene in Godot coordinates: X width, Y height, Z length. Runtime presentation scale is applied separately. The origin is a central hull datum; bounds can be asymmetric.", "", "| Asset | Triangles | Vertices | Surfaces | Meshes | Dimensions X × Y × Z | Sockets |", "| --- | ---: | ---: | ---: | ---: | --- | ---: |"]
    for asset in report["assets"]:
        dimensions = " × ".join(f"{value:.2f}" for value in asset["dimensions_xyz"])
        lines.append(f"| `{asset['file']}` | {asset['triangles']:,} | {asset['vertices']:,} | {asset['surfaces']} | {asset['mesh_nodes']} | {dimensions} | {len(asset['sockets'])} |")
    lines += ["", f"Total geometry: {sum(asset['triangles'] for asset in report['assets']):,} triangles. Every asset has a four-bone rigid skeleton, four moving animation clips, valid UVs and the shared embedded atlas. Hard face normals intentionally split vertices. Surfaces are material partitions; they are not a measured draw-call count.", "", "Exact bone/socket bindings, moving bones per clip, clip durations, material factors, atlas hashes and file digests are recorded in `validation.json`.", ""]
    return "\n".join(lines).encode()


def payload_files(root, includes, report):
    files = {}
    for path in sorted((root / ASSET_ROOT).rglob("*")):
        if not path.is_file() or path.name.startswith(".") or path.suffix in (".import", ".blend1", ".blend2", ".pyc") or "__pycache__" in path.parts:
            continue
        if path.name in ("manifest.json", "validation.json", "TECHNICAL_SHEET.md", "MANIFEST.sha256"):
            continue
        files[path.relative_to(root).as_posix()] = path.read_bytes()
    for relative in list(CORE_FILES) + includes:
        path = (root / relative).resolve()
        require(path.is_relative_to(root) and path.is_file(), f"Missing source/integration file: {relative}")
        files[path.relative_to(root).as_posix()] = path.read_bytes()
    require(any(name.endswith(".blend") for name in files), "Editable boss Blender source missing")
    require(any(name.endswith(".gdshader") for name in files), "Runtime shader source must be included")
    for name in ("README.md", "RIGHTS.md"):
        files[name] = (root / ASSET_ROOT / "docs" / name).read_bytes()
    for directory in (ASSET_ROOT / "source", ASSET_ROOT / "docs", DESIGN_ROOT):
        files[(directory / ".gdignore").as_posix()] = b""
    files["validation.json"] = json_bytes(report)
    files["TECHNICAL_SHEET.md"] = technical_sheet(report)
    return files


def verify_zip(path):
    prefix = PACKAGE_NAME + "/"
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None, "ZIP CRC integrity failure")
        names = archive.namelist()
        require(len(names) == len(set(names)) and all(name.startswith(prefix) and ".." not in Path(name).parts for name in names), "Duplicate or unsafe ZIP member")
        manifest = json.loads(archive.read(prefix + "manifest.json"))
        require(set(names) == {prefix + item["path"] for item in manifest["files"]} | {prefix + "manifest.json", prefix + "MANIFEST.sha256"}, "ZIP inventory differs from manifest")
        for item in manifest["files"]:
            data = archive.read(prefix + item["path"])
            require(len(data) == item["bytes"] and digest(data) == item["sha256"], "Hash mismatch: " + item["path"])
        checksums = "".join(f"{item['sha256']}  {item['path']}\n" for item in manifest["files"])
        checksums += digest(archive.read(prefix + "manifest.json")) + "  manifest.json\n"
        require(archive.read(prefix + "MANIFEST.sha256").decode() == checksums, "Checksum list differs from manifest")
    return {"status": "pass", "package": str(path), "files": len(names), "bytes": path.stat().st_size, "sha256": digest(path.read_bytes())}


def build(root, report, output, includes):
    files = payload_files(root, includes, report)
    provenance = json.loads((root / ASSET_ROOT / "docs/provenance.json").read_text())
    manifest = {"schema_version": 1, "package_id": provenance["package_id"], "version": provenance["version"], "license_spdx": provenance["license_spdx"], "asset_count": len(report["assets"]), "provenance": (ASSET_ROOT / "docs/provenance.json").as_posix(), "validation": "validation.json", "files": [{"path": name, "bytes": len(data), "sha256": digest(data)} for name, data in sorted(files.items())]}
    files["manifest.json"] = json_bytes(manifest)
    files["MANIFEST.sha256"] = ("".join(f"{item['sha256']}  {item['path']}\n" for item in manifest["files"]) + digest(files["manifest.json"]) + "  manifest.json\n").encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(prefix="voxel_bosses_", suffix=".zip", dir=output.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with zipfile.ZipFile(temporary_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, data in sorted(files.items()):
                info = zipfile.ZipInfo(PACKAGE_NAME + "/" + name, date_time=(2026, 9, 20, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, data)
        verify_zip(temporary_path)
        temporary_path.replace(output)
    finally:
        temporary_path.unlink(missing_ok=True)
    (output.parent / ".gdignore").write_text("")
    output.with_suffix(".zip.sha256").write_text(f"{digest(output.read_bytes())}  {output.name}\n")
    (root / ASSET_ROOT / "docs/validation.json").write_bytes(json_bytes(report))
    (root / ASSET_ROOT / "docs/TECHNICAL_SHEET.md").write_bytes(technical_sheet(report))
    return verify_zip(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--include", action="append", default=[], help="Additional project-relative integration/evidence file; repeatable")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    try:
        if args.verify:
            print(json.dumps(verify_zip(args.verify.resolve()), indent=2))
        else:
            root = args.root.resolve()
            report = collect(root)
            if args.validate_only:
                print(json.dumps(report, indent=2))
            else:
                output = args.output.resolve() if args.output else root / DESIGN_ROOT / (PACKAGE_NAME + ".zip")
                print(json.dumps(build(root, report, output, args.include), indent=2))
        return 0
    except (shared.InvalidAsset, KeyError, IndexError, TypeError, struct.error, OSError, ValueError, zlib.error, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "fail", "error": str(error)}, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
