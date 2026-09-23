#!/usr/bin/env python3
"""Read-only static validation of the original Crescent Harbor Blender delivery.

Uses only the Python standard library. Prints JSON; --report PATH also saves it.
This checks asset bytes and manifest integrity, not Blender/Godot import,
rendering, gameplay performance, or correspondence with the concept image.

Manifest schema 1: full_scene is an asset-relative GLB path; major_roots and
ship_roots list exact exported node names. outputs lists {path, sha256} records
relative to the asset directory, covering every GLB/PNG and editable source.
Optional previews lists {path, sha256} records relative to the repository root.
The manifest itself is excluded from its output hash list.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import struct
import sys
import zlib

import package_voxel_frontier as shared


ASSET_ROOT = Path("assets/models/wayfarer_crescent")
SOURCE = Path("source/wayfarer_crescent.blend")
PREVIEW_ROOT = Path("design/home-base/blender-crescent")
SOFT_TRIANGLES, MAX_TRIANGLES = 800_000, 1_500_000
SOFT_BYTES, MAX_BYTES = 40_000_000, 150_000_000
require = shared.require


def integer(value):
    return isinstance(value, int) and not isinstance(value, bool)


def reference(value, entries, description):
    require(integer(value) and 0 <= value < len(entries), f"Invalid {description}: {value}")
    return entries[value]


def finite_vector(values, width, description):
    require(isinstance(values, (list, tuple)) and len(values) == width,
            f"Invalid {description} dimensions")
    require(all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)
                for v in values), f"Nonfinite {description}")


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def contained_path(base, value):
    require(isinstance(value, str) and value and not Path(value).is_absolute(),
            "Manifest paths must be nonempty relative paths")
    target = (base / value).resolve()
    require(target.is_relative_to(base.resolve()), f"Path escapes delivery directory: {value}")
    require(target.is_file(), f"Missing delivered file: {value}")
    return target


class CheckedGLB(shared.GLB):
    """Reuse the repository's GLB/PNG readers with explicit reference checks."""

    def __init__(self, path):
        require(path.stat().st_size <= MAX_BYTES, f"GLB exceeds strict {MAX_BYTES} byte budget")
        super().__init__(path)
        require(isinstance(self.doc, dict), "GLB JSON must be an object")
        for key in ("nodes", "meshes", "accessors", "bufferViews", "materials", "images",
                    "textures", "samplers", "animations", "scenes"):
            entries = self.doc.get(key, [])
            require(isinstance(entries, list) and all(isinstance(v, dict) for v in entries),
                    f"Invalid glTF {key} array")
        views = self.doc.get("bufferViews", [])
        for view in views:
            require(integer(view.get("buffer", 0)) and view.get("buffer", 0) == 0,
                    "Invalid buffer reference")
            require(integer(view.get("byteOffset", 0)) and integer(view.get("byteLength")),
                    "BufferView offsets and lengths must be integers")
            if "byteStride" in view:
                stride = view["byteStride"]
                require(integer(stride) and 4 <= stride <= 252 and stride % 4 == 0,
                        "Invalid interleaved buffer stride")
        for acc in self.doc.get("accessors", []):
            view = reference(acc.get("bufferView"), views, "accessor bufferView")
            require("sparse" not in acc, "Sparse accessors are outside this delivery policy")
            component = acc.get("componentType")
            require(component in shared.COMPONENTS and acc.get("type") in shared.WIDTHS,
                    "Unsupported accessor encoding")
            require(integer(acc.get("count")) and acc["count"] > 0, "Invalid accessor count")
            offset, component_bytes = acc.get("byteOffset", 0), shared.COMPONENTS[component][1]
            require(integer(offset) and offset >= 0 and offset % component_bytes == 0,
                    "Invalid or unaligned accessor byte offset")
            require((view.get("byteOffset", 0) + offset) % component_bytes == 0,
                    "Unaligned accessor buffer offset")
            width = shared.WIDTHS[acc["type"]]
            stride = view.get("byteStride", width * component_bytes)
            require(stride >= width * component_bytes and
                    offset + (acc["count"] - 1) * stride + width * component_bytes <= view["byteLength"],
                    "Accessor exceeds BufferView")
            for bound in ("min", "max"):
                if bound in acc:
                    finite_vector(acc[bound], width, "accessor " + bound)
            if "min" in acc and "max" in acc:
                require(all(a <= b for a, b in zip(acc["min"], acc["max"])),
                        "Accessor min exceeds max")


def audit_materials(model, directory, external_pixels):
    doc = model.doc
    images, warnings = [], []
    for image in doc.get("images", []):
        if "uri" in image:
            require("bufferView" not in image and not image["uri"].startswith("data:"),
                    "Use embedded PNG bufferViews or a delivered PNG file")
            path = contained_path(directory, str((model.path.parent / image["uri"]).relative_to(directory)))
            info = shared.png_info(path.read_bytes())
            info["external_file"] = path.relative_to(directory).as_posix()
        else:
            reference(image.get("bufferView"), doc.get("bufferViews", []), "image bufferView")
            info = model.image(image)
        images.append(info)
        if (info["width"], info["height"], info["rgba_pixels_sha256"]) not in external_pixels:
            warnings.append("Embedded image has no pixel-identical external source PNG")
    textures, materials = doc.get("textures", []), doc.get("materials", [])
    require(materials, "No materials exported")
    for texture in textures:
        reference(texture.get("source"), images, "texture image")
        if "sampler" in texture:
            sampler = reference(texture["sampler"], doc.get("samplers", []), "texture sampler")
            require(sampler.get("magFilter", 9729) in (9728, 9729), "Invalid magnification filter")
            require(sampler.get("minFilter", 9987) in (9728, 9729, 9984, 9985, 9986, 9987),
                    "Invalid minification filter")
            require(all(sampler.get(axis, 10497) in (33071, 33648, 10497) for axis in ("wrapS", "wrapT")),
                    "Invalid texture wrap mode")
    material_uvs, texture_uses = [], set()
    for material in materials:
        pbr = material.get("pbrMetallicRoughness", {})
        color = pbr.get("baseColorFactor", [1, 1, 1, 1])
        finite_vector(color, 4, "base-color factor")
        require(all(0 <= v <= 1 for v in color), "Base color outside [0,1]")
        emission = material.get("emissiveFactor", [0, 0, 0])
        finite_vector(emission, 3, "emissive factor")
        require(all(v >= 0 for v in emission), "Negative emission")
        for field in ("metallicFactor", "roughnessFactor"):
            value = pbr.get(field, 1)
            require(isinstance(value, (int, float)) and math.isfinite(value) and 0 <= value <= 1,
                    f"Invalid {field}")
        uv_sets = set()
        for container in (pbr, material, *material.get("extensions", {}).values()):
            if not isinstance(container, dict):
                continue
            for key, value in container.items():
                if key.endswith("Texture") and isinstance(value, dict):
                    reference(value.get("index"), textures, f"{key} texture")
                    texture_uses.add(value["index"])
                    channel = value.get("extensions", {}).get("KHR_texture_transform", {}).get("texCoord", value.get("texCoord", 0))
                    require(integer(channel) and channel >= 0, "Invalid material UV channel")
                    uv_sets.add(channel)
        material_uvs.append(uv_sets)
    return material_uvs, {"count": len(materials), "textures": len(textures), "images": images,
                         "bound_textures": sorted(texture_uses)}, warnings


def audit_meshes(model, material_uvs):
    reports = []
    accessors = model.doc.get("accessors", [])
    for mesh_index, mesh in enumerate(model.doc.get("meshes", [])):
        triangles, vertices, uv_degenerate = 0, 0, 0
        minimum_normal_alignment = 1.0
        lower, upper = [math.inf] * 3, [-math.inf] * 3
        primitives = mesh.get("primitives", [])
        require(primitives, f"Mesh {mesh_index} has no primitives")
        for primitive in primitives:
            require(primitive.get("mode", 4) == 4, "Only triangle primitives are supported")
            require(not primitive.get("targets"), "Morph targets are outside the rigid asset policy")
            attrs = primitive.get("attributes", {})
            positions = model.accessor(attrs.get("POSITION"))
            pos_acc = reference(attrs.get("POSITION"), accessors, "position accessor")
            require(pos_acc["type"] == "VEC3" and pos_acc["componentType"] == 5126,
                    "Positions must be float VEC3 values")
            material_id = primitive.get("material")
            required_uvs = reference(material_id, material_uvs, "primitive material")
            for channel in required_uvs:
                require("TEXCOORD_" + str(channel) in attrs, "Textured primitive has no required UV set")
            uv_values, normal_values = [], None
            for name, accessor_id in attrs.items():
                values = positions if name == "POSITION" else model.accessor(accessor_id)
                require(len(values) == len(positions), f"Attribute count mismatch: {name}")
                if name.startswith("TEXCOORD_"):
                    require(all(len(v) == 2 for v in values), "UVs must be VEC2 values")
                    uv_values.append(values)
                elif name == "NORMAL":
                    require(all(len(v) == 3 and 0.5 < sum(n * n for n in v) < 1.5 for v in values),
                            "Invalid vertex normals")
                    normal_values = values
            for point in positions:
                finite_vector(point, 3, "position")
                for axis in range(3):
                    lower[axis] = min(lower[axis], point[axis])
                    upper[axis] = max(upper[axis], point[axis])
            for bound, comparator in (("min", min), ("max", max)):
                if bound in pos_acc:
                    measured = [comparator(p[axis] for p in positions) for axis in range(3)]
                    require(all(math.isclose(a, b, rel_tol=1e-5, abs_tol=1e-5)
                                for a, b in zip(pos_acc[bound], measured)),
                            "Declared position bounds differ from geometry")
            if "indices" in primitive:
                acc = reference(primitive["indices"], accessors, "triangle index accessor")
                require(acc["type"] == "SCALAR" and acc["componentType"] in (5121, 5123, 5125)
                        and not acc.get("normalized", False), "Indices must be unsigned integer scalars")
                indices = [v[0] for v in model.accessor(primitive["indices"])]
            else:
                indices = range(len(positions))
            require(indices and len(indices) % 3 == 0 and
                    all(integer(v) and 0 <= v < len(positions) for v in indices), "Invalid triangle indices")
            for offset in range(0, len(indices), 3):
                ia, ib, ic = indices[offset:offset + 3]
                a, b, c = positions[ia], positions[ib], positions[ic]
                ab, ac = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
                cross = (ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2],
                         ab[0] * ac[1] - ab[1] * ac[0])
                cross_length = math.sqrt(sum(v * v for v in cross))
                require(cross_length > 1e-10, "Degenerate geometry triangle")
                if normal_values is not None:
                    alignment = min(sum(normal_values[i][axis] * cross[axis] for axis in range(3)) / cross_length
                                    for i in (ia, ib, ic))
                    minimum_normal_alignment = min(minimum_normal_alignment, alignment)
                    # Smooth normals may approach the tangent plane, but must
                    # not oppose the face: twisted quads can export that way.
                    require(alignment >= -1e-4,
                            f"Mesh {mesh_index} triangle {offset//3}: exported normal opposes geometry ({alignment:.5f})")
                for uvs in uv_values:
                    ua, ub, uc = uvs[ia], uvs[ib], uvs[ic]
                    if abs((ub[0] - ua[0]) * (uc[1] - ua[1]) -
                           (ub[1] - ua[1]) * (uc[0] - ua[0])) <= 1e-12:
                        uv_degenerate += 1
            triangles += len(indices) // 3
            vertices += len(positions)
        reports.append({"triangles": triangles, "vertices": vertices, "surfaces": len(primitives),
                        "bounds_min": lower, "bounds_max": upper, "degenerate_uv_triangles": uv_degenerate,
                        "minimum_normal_alignment": minimum_normal_alignment})
    require(reports, "No render geometry exported")
    return reports


def audit_scene(model, meshes):
    nodes = model.doc.get("nodes", [])
    scenes = model.doc.get("scenes", [])
    scene = reference(model.doc.get("scene", 0), scenes, "default scene")
    visited, parents, descendants, names = set(), {}, {}, {}
    lower, upper = [math.inf] * 3, [-math.inf] * 3
    triangles = 0

    def visit(index, parent_matrix, parent_index=None):
        nonlocal triangles
        node = reference(index, nodes, "scene node")
        require(index not in visited, "Cyclic or multiply-parented node")
        visited.add(index)
        parents[index] = parent_index
        if node.get("name"):
            names.setdefault(node["name"], []).append(index)
        require(not ("matrix" in node and any(key in node for key in ("translation", "rotation", "scale"))),
                "Node cannot mix matrix and TRS transforms")
        for key, width in (("translation", 3), ("rotation", 4), ("scale", 3), ("matrix", 16)):
            if key in node:
                finite_vector(node[key], width, "node " + key)
        if "rotation" in node:
            require(abs(sum(v * v for v in node["rotation"]) - 1) <= 0.002,
                    "Node rotation quaternion is not unit length")
        require("skin" not in node, "Skins are outside the rigid asset delivery policy")
        matrix = shared.matmul(parent_matrix, shared.node_matrix(node))
        require(all(abs(matrix[i]) <= 1e-8 for i in (3, 7, 11)) and abs(matrix[15] - 1) <= 1e-8,
                "Node transform is not affine")
        determinant = (matrix[0] * (matrix[5] * matrix[10] - matrix[9] * matrix[6])
                       - matrix[4] * (matrix[1] * matrix[10] - matrix[9] * matrix[2])
                       + matrix[8] * (matrix[1] * matrix[6] - matrix[5] * matrix[2]))
        require(math.isfinite(determinant) and abs(determinant) > 1e-12, "Collapsed world transform")
        mesh_count = 0
        if "mesh" in node:
            mesh = reference(node["mesh"], meshes, "node mesh")
            triangles += mesh["triangles"]
            mesh_count += 1
            for corner in itertools.product(*zip(mesh["bounds_min"], mesh["bounds_max"])):
                point = shared.transform(matrix, corner)
                finite_vector(point, 3, "world bounds")
                for axis in range(3):
                    lower[axis] = min(lower[axis], point[axis])
                    upper[axis] = max(upper[axis], point[axis])
        for child in node.get("children", []):
            mesh_count += visit(child, matrix, index)
        descendants[index] = mesh_count
        return mesh_count

    for index in scene.get("nodes", []):
        visit(index, shared.IDENTITY)
    require(visited and len(visited) == len(nodes), "Scene is empty or has orphan exported nodes")
    require(triangles > 0 and all(math.isfinite(v) for v in lower + upper), "Invalid finite scene bounds")
    require(triangles <= MAX_TRIANGLES, f"Scene exceeds strict {MAX_TRIANGLES} triangle budget: {triangles}")
    return {"triangles": triangles, "nodes": len(nodes), "mesh_instances": sum("mesh" in n for n in nodes),
            "bounds_min_xyz": lower, "bounds_max_xyz": upper,
            "bounds_type": "Rest-pose envelope of transformed local mesh AABBs"}, names, parents, descendants


def audit_animations(model):
    reports = []
    for clip in model.doc.get("animations", []):
        samplers, channels = clip.get("samplers", []), clip.get("channels", [])
        require(samplers and channels, "Empty animation clip")
        moving, seen, start, end = set(), set(), math.inf, -math.inf
        for channel in channels:
            target = channel.get("target", {})
            node_id, path = target.get("node"), target.get("path")
            node = reference(node_id, model.doc["nodes"], "animation target")
            require(path in ("translation", "rotation", "scale"), "Expected rigid animation channel")
            require("matrix" not in node, "TRS animation cannot target a matrix-authored node")
            require((node_id, path) not in seen, "Duplicate animation node/path channel")
            seen.add((node_id, path))
            sampler = reference(channel.get("sampler"), samplers, "animation sampler")
            times, values = model.accessor(sampler.get("input")), model.accessor(sampler.get("output"))
            acc = model.doc["accessors"][sampler["input"]]
            require(acc["componentType"] == 5126 and acc["type"] == "SCALAR", "Animation times must be floats")
            output_acc = model.doc["accessors"][sampler["output"]]
            require(output_acc["componentType"] == 5126, "Rigid animation values must be floats")
            require(times[0][0] >= 0 and all(a[0] < b[0] for a, b in zip(times, times[1:])),
                    "Animation times must increase from a nonnegative time")
            interpolation = sampler.get("interpolation", "LINEAR")
            require(interpolation in ("LINEAR", "STEP", "CUBICSPLINE"), "Invalid animation interpolation")
            multiplier = 3 if interpolation == "CUBICSPLINE" else 1
            require(len(values) == len(times) * multiplier, "Animation key/value counts differ")
            for value in values:
                finite_vector(value, 4 if path == "rotation" else 3, "animation value")
            keys = values[1::3] if multiplier == 3 else values
            if path == "rotation":
                require(all(abs(sum(v * v for v in key) - 1) <= 0.002 for key in keys),
                        "Animation quaternion is not unit length")
            elif path == "scale":
                require(all(abs(v) > 1e-8 for key in keys for v in key), "Collapsed animated scale")
            poses = list(keys)
            if multiplier == 3:
                # Equal endpoint values may still move via cubic tangents.
                for i in range(len(times) - 1):
                    duration = times[i + 1][0] - times[i][0]
                    for t in (0.25, 0.5, 0.75):
                        pose = [(2*t**3 - 3*t*t + 1) * a + (t**3 - 2*t*t + t) * duration * out_t
                                + (-2*t**3 + 3*t*t) * b + (t**3 - t*t) * duration * in_t
                                for a, out_t, b, in_t in zip(keys[i], values[3*i + 2], keys[i + 1], values[3*(i + 1)])]
                        if path == "rotation":
                            length = math.sqrt(sum(v*v for v in pose))
                            require(length > 1e-8, "Cubic quaternion crosses a zero-length rotation")
                            pose = [v / length for v in pose]
                        poses.append(pose)
            distances = [max(abs(a - b) for a, b in zip(keys[0], pose)) for pose in poses]
            if path == "rotation":
                distances = [min(distance, max(abs(a + b) for a, b in zip(keys[0], key)))
                             for distance, key in zip(distances, poses)]
            if max(distances) > 1e-5:
                moving.add(node.get("name", str(node_id)))
            start, end = min(start, times[0][0]), max(end, times[-1][0])
        require(moving and end > start, "Animation contains no actual transform motion")
        reports.append({"name": clip.get("name", ""), "duration_seconds": end - start,
                        "channels": len(channels), "moving_nodes": sorted(moving)})
    return reports


def audit_asset(path, directory, external_pixels):
    model = CheckedGLB(path)
    material_uvs, materials, warnings = audit_materials(model, directory, external_pixels)
    meshes = audit_meshes(model, material_uvs)
    scene, names, parents, descendants = audit_scene(model, meshes)
    animations = audit_animations(model)
    uv_degenerate = sum(mesh["degenerate_uv_triangles"] for mesh in meshes)
    if uv_degenerate:
        warnings.append(f"{uv_degenerate} degenerate UV triangles; verify affected material appearance")
    report = {"file": path.relative_to(directory).as_posix(), "status": "pass", "bytes": len(model.data),
              "sha256": shared.digest(model.data), **scene, "unique_meshes": len(meshes),
              "unique_mesh_triangles": sum(mesh["triangles"] for mesh in meshes),
              "vertices": sum(mesh["vertices"] for mesh in meshes),
              "surfaces": sum(mesh["surfaces"] for mesh in meshes), "materials": materials,
              "minimum_normal_alignment": min(mesh["minimum_normal_alignment"] for mesh in meshes),
              "animations": animations, "warnings": sorted(set(warnings))}
    return report, names, parents, descendants


def verify_roots(values, minimum, label, names, parents, descendants):
    require(isinstance(values, list) and len(values) >= minimum and
            all(isinstance(v, str) and v for v in values) and len(values) == len(set(values)),
            f"Manifest needs at least {minimum} distinct {label} names")
    indices = set()
    for name in values:
        require(name in names and len(names[name]) == 1, f"Missing or ambiguous {label} node: {name}")
        index = names[name][0]
        require(descendants[index] > 0, f"Declared {label} has no render geometry: {name}")
        indices.add(index)
    for index in indices:
        parent = parents[index]
        while parent is not None:
            require(parent not in indices, f"Nested {label} entries cannot inflate root count")
            parent = parents[parent]
    return values


def verify_hash_records(base, records, label):
    require(isinstance(records, list) and records, f"Missing manifest {label}")
    seen, reports = set(), []
    for entry in records:
        require(isinstance(entry, dict), f"Invalid {label} hash entry")
        path = contained_path(base, entry.get("path"))
        require(path not in seen, f"Duplicate {label} path: {entry['path']}")
        seen.add(path)
        expected = entry.get("sha256", "")
        require(isinstance(expected, str) and re.fullmatch(r"[0-9a-fA-F]{64}", expected),
                f"Invalid SHA-256: {entry['path']}")
        require(file_hash(path) == expected.lower(), f"SHA-256 mismatch: {entry['path']}")
        reports.append({"file": entry["path"], "sha256": expected.lower(), "bytes": path.stat().st_size})
    return seen, reports


def collect(root):
    directory = (root / ASSET_ROOT).resolve()
    manifest_path = directory / "build_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(integer(manifest.get("schema_version")) and manifest["schema_version"] == 1,
            "Unsupported manifest schema_version")
    hashed, outputs = verify_hash_records(directory, manifest.get("outputs"), "outputs")
    require(manifest_path not in hashed, "Manifest cannot include its own recursive digest")
    glbs = sorted((directory / "meshes").glob("*.glb"))
    pngs = sorted((directory / "textures").glob("*.png"))
    require(len(glbs) >= 2, "Expected full scene and at least one modular GLB")
    require(pngs, "No original texture PNGs delivered")
    required = {p.resolve() for p in glbs + pngs + [directory / SOURCE]}
    require(required <= hashed, f"Unhashed delivery files: {sorted(str(p.relative_to(directory)) for p in required - hashed)}")
    source = directory / SOURCE
    with source.open("rb") as handle:
        signature = handle.read(12)
    require(source.stat().st_size > 1024 and signature.startswith((b"BLENDER", b"\x1f\x8b", b"\x28\xb5\x2f\xfd")),
            "Editable Blender source has an invalid signature")
    texture_reports = [{"file": path.relative_to(directory).as_posix(), **shared.png_info(path.read_bytes())} for path in pngs]
    pixels = {(p["width"], p["height"], p["rgba_pixels_sha256"]) for p in texture_reports}
    full_scene = contained_path(directory, manifest.get("full_scene"))
    require(full_scene in glbs, "Manifest full_scene is not in meshes/*.glb")
    reports, warnings, root_report = [], [], {}
    for path in glbs:
        try:
            report, names, parents, descendants = audit_asset(path, directory, pixels)
            if path == full_scene:
                for label, minimum in (("major_roots", 6), ("ship_roots", 9)):
                    root_report[label] = verify_roots(manifest.get(label), minimum, label, names, parents, descendants)
                if report["triangles"] > SOFT_TRIANGLES:
                    warnings.append(f"Full scene exceeds {SOFT_TRIANGLES} triangle soft budget: {report['triangles']}")
                if report["bytes"] > SOFT_BYTES:
                    warnings.append(f"Full scene exceeds {SOFT_BYTES} byte soft budget: {report['bytes']}")
                if not report["animations"]:
                    warnings.append("Full scene contains no animation clips")
            reports.append(report)
        except (ValueError, KeyError, IndexError, TypeError, AttributeError) as error:
            raise shared.InvalidAsset(f"{path.name}: {error}") from error
    previews = []
    if manifest.get("previews"):
        preview_paths, previews = verify_hash_records(root, manifest["previews"], "previews")
        for path in preview_paths:
            require(path.is_relative_to((root / PREVIEW_ROOT).resolve()), "Preview is outside the designated preview directory")
            require(path.suffix.lower() == ".png", "Preview must be a PNG")
            shared.png_info(path.read_bytes())
    else:
        warnings.append("No preview hashes declared; render review remains separate")
    return {"schema_version": 1, "status": "pass", "asset_root": ASSET_ROOT.as_posix(),
            "evidence_type": "Static GLB/PNG/source and manifest validation; no runtime import or visual approval claimed",
            "policy": {"soft_full_scene_triangles": SOFT_TRIANGLES, "strict_scene_triangles": MAX_TRIANGLES,
                       "soft_full_scene_bytes": SOFT_BYTES, "strict_glb_bytes": MAX_BYTES,
                       "minimum_major_roots": 6, "minimum_ship_roots": 9},
            "manifest_sha256": file_hash(manifest_path), "outputs": outputs, "textures": texture_reports,
            "full_scene": manifest["full_scene"], "verified_roots": root_report,
            "assets": reports, "previews": previews, "warnings": warnings}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, help="Optionally save the JSON report")
    args = parser.parse_args()
    try:
        report, result = collect(args.root.resolve()), 0
    except (ValueError, KeyError, IndexError, TypeError, AttributeError, struct.error, OSError, zlib.error, RecursionError) as error:
        report, result = {"schema_version": 1, "status": "fail", "error": str(error),
                          "evidence_type": "Static asset validation only"}, 1
    payload = shared.json_bytes(report)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(payload)
    print(payload.decode(), end="")
    return result


if __name__ == "__main__":
    sys.exit(main())
