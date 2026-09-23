#!/usr/bin/env python3
"""Read-only audit of the original Wayfarer Homeport GLB/texture delivery.

Run without arguments to print JSON. --report PATH optionally saves the same
report; it never launches Blender/Godot or changes an art file. This checks
portable asset bytes, not engine appearance, gameplay, or frame-rate.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import struct
import sys
import zlib

import package_voxel_frontier as shared


ASSET_ROOT = Path("assets/models/home_base")
require = shared.require
MAX_FILE_BYTES = 32 * 1024 * 1024


def plain_name(value):
    """Ignore glTF library prefixes and Blender's collision suffixes."""
    return re.sub(r"\.\d{3,}$", "", value.rsplit("/", 1)[-1])


def pixel_identity(image):
    return image["width"], image["height"], image["rgba_pixels_sha256"]


def finite_vector(value, width, description):
    require(isinstance(value, (tuple, list)) and len(value) == width,
            f"Invalid {description} width")
    require(all(isinstance(v, (int, float)) and math.isfinite(v) for v in value),
            f"Nonfinite {description}")


def same_pose(left, right, rotation=False, tolerance=0.0002):
    distance = max(abs(a - b) for a, b in zip(left, right))
    if rotation:
        distance = min(distance, max(abs(a + b) for a, b in zip(left, right)))
    return distance <= tolerance


def audit_animation(model, spec, reachable):
    nodes = model.doc["nodes"]
    clips = model.doc.get("animations", [])
    expected = set(spec["loop_clips"])
    names = [plain_name(clip.get("name", "")) for clip in clips]
    require(len(names) == len(set(names)), "Duplicate animation names after suffix normalization")
    require(set(names) == expected, f"Expected clips {sorted(expected)}, found {sorted(names)}")
    reports = []
    for clip, name in zip(clips, names):
        channels = clip.get("channels", [])
        require(channels and clip.get("samplers"), f"{name}: empty animation")
        moving, targets, times_by_channel = set(), set(), []
        for channel in channels:
            target = channel.get("target", {})
            node, path = target.get("node", -1), target.get("path", "")
            require(node in reachable and path in ("translation", "rotation", "scale"),
                    f"{name}: animation must target a reachable rigid transform")
            require((node, path) not in targets, f"{name}: duplicate node/path channel")
            targets.add((node, path))
            index = channel.get("sampler", -1)
            require(isinstance(index, int) and 0 <= index < len(clip["samplers"]),
                    f"{name}: invalid sampler index")
            sampler = clip["samplers"][index]
            input_acc = model.doc["accessors"][sampler["input"]]
            require(input_acc["componentType"] == 5126 and input_acc["type"] == "SCALAR",
                    f"{name}: animation times must be float scalars")
            times = model.accessor(sampler["input"])
            values = model.accessor(sampler["output"])
            interpolation = sampler.get("interpolation", "LINEAR")
            require(interpolation in ("LINEAR", "STEP", "CUBICSPLINE"),
                    f"{name}: unsupported interpolation")
            multiplier = 3 if interpolation == "CUBICSPLINE" else 1
            require(len(times) >= 2 and len(values) == len(times) * multiplier,
                    f"{name}: missing keys or sampler cardinality mismatch")
            require(times[0][0] >= 0 and all(a[0] < b[0] for a, b in zip(times, times[1:])),
                    f"{name}: key times must strictly increase from nonnegative time")
            if multiplier == 3:
                values = values[1::3]
            for value in values:
                finite_vector(value, 4 if path == "rotation" else 3, "animation key")
                if path == "rotation":
                    require(abs(sum(v * v for v in value) - 1) <= 0.002,
                            f"{name}: non-unit animation quaternion")
                elif path == "scale":
                    require(all(abs(v) > 1e-8 for v in value), f"{name}: collapsed animated scale")
            require(same_pose(values[0], values[-1], path == "rotation"),
                    f"{name}: visible loop discontinuity on {nodes[node].get('name')}/{path}")
            if any(not same_pose(values[0], value, path == "rotation", tolerance=1e-5)
                   for value in values[1:]):
                moving.add(plain_name(nodes[node].get("name", "")))
            times_by_channel.append((times[0][0], times[-1][0]))
        require(moving, f"{name}: no actual transform motion")
        required_motion = set(spec.get("moving_nodes", {}).get(name, []))
        require(required_motion <= moving,
                f"{name}: expected moving nodes missing: {sorted(required_motion - moving)}")
        end = max(t[1] for t in times_by_channel)
        start = min(t[0] for t in times_by_channel)
        require(0 < end - start <= 180, f"{name}: duration outside (0, 180] seconds")
        reports.append({"name": name, "exported_name": clip.get("name"),
                        "duration_seconds": end - start, "channels": len(channels),
                        "moving_nodes": sorted(moving), "loop_pose_continuity": "pass"})
    return reports


def audit_asset(path, spec, atlas_pixels):
    require(path.stat().st_size <= MAX_FILE_BYTES, f"{path.name}: exceeds 32 MiB delivery budget")
    model = shared.GLB(path)
    doc = model.doc
    require(not doc.get("cameras") and not doc.get("skins"), "Only unskinned rigid asset parts are expected")
    require(not doc.get("extensionsRequired"), "Asset needs an unsupported required glTF extension")
    nodes, meshes = doc.get("nodes", []), doc.get("meshes", [])
    require(nodes and meshes, "Asset contains no render geometry")
    node_names = {plain_name(node.get("name", "")) for node in nodes}
    require(set(spec.get("required_nodes", [])) <= node_names, "Required scene parts are absent")
    for node in nodes:
        name = node.get("name", "").lower()
        require(not any(term in name for term in ("-col", "_collision", "-convcol", "-navmesh", "_collider")),
                f"Collision/helper node exported: {name}")
        require("camera" not in node and "skin" not in node and
                "KHR_lights_punctual" not in node.get("extensions", {}),
                "Camera/light/skin was exported")
        for field, width in (("translation", 3), ("rotation", 4), ("scale", 3)):
            if field in node:
                finite_vector(node[field], width, f"node {field}")
        if "rotation" in node:
            require(abs(sum(v * v for v in node["rotation"]) - 1) <= 0.002,
                    "Node quaternion is not normalized")
        shared.node_matrix(node)

    images = [model.image(value) for value in doc.get("images", [])]
    require(images, "Asset contains no embedded PNG textures")
    for image in images:
        require(image["width"] == image["height"] and image["width"] in (256, 512),
                "Embedded texture must be 256 or 512 pixels square")
        require(pixel_identity(image) in set(atlas_pixels.values()),
                "Embedded texture pixels differ from the external source atlases")
    require(set(atlas_pixels.values()) <= {pixel_identity(image) for image in images},
            "Both base-color and emission source atlases must be embedded")
    textures, materials = doc.get("textures", []), doc.get("materials", [])
    require(textures and materials, "Missing textures or materials")
    used_images, material_info, emission_images = set(), [], set()

    def texture_image(reference, role):
        require(reference.get("texCoord", 0) == 0, f"{role}: requires an unsupported UV channel")
        index = reference.get("index", -1)
        require(isinstance(index, int) and 0 <= index < len(textures), f"{role}: invalid texture index")
        source = textures[index].get("source", -1)
        require(isinstance(source, int) and 0 <= source < len(images), f"{role}: invalid texture image")
        sampler = textures[index].get("sampler")
        if sampler is not None:
            require(isinstance(sampler, int) and 0 <= sampler < len(doc.get("samplers", [])),
                    f"{role}: invalid sampler reference")
        used_images.add(source)
        return source

    for index, material in enumerate(materials):
        pbr = material.get("pbrMetallicRoughness", {})
        require("baseColorTexture" in pbr, f"Material {index} has no base-color atlas")
        source = texture_image(pbr["baseColorTexture"], "base color")
        require(pixel_identity(images[source]) == atlas_pixels["homeport_atlas.png"],
                "Base-color texture does not match homeport_atlas.png")
        factor = pbr.get("baseColorFactor", [1, 1, 1, 1])
        finite_vector(factor, 4, "base-color factor")
        require(all(0 <= value <= 1 for value in factor), "Base-color factor out of range")
        emission = material.get("emissiveFactor", [0, 0, 0])
        finite_vector(emission, 3, "emissive factor")
        require(all(value >= 0 for value in emission), "Negative emission")
        emissive_source = None
        if "emissiveTexture" in material:
            emissive_source = texture_image(material["emissiveTexture"], "emission")
            require(pixel_identity(images[emissive_source]) == atlas_pixels["homeport_emission.png"],
                    "Emission texture does not match homeport_emission.png")
            if max(emission) > 0:
                emission_images.add(emissive_source)
        for reference in (pbr.get("metallicRoughnessTexture"), material.get("normalTexture"), material.get("occlusionTexture")):
            if reference:
                texture_image(reference, "surface")
        for field in ("metallicFactor", "roughnessFactor"):
            value = pbr.get(field, 1)
            require(isinstance(value, (float, int)) and math.isfinite(value) and 0 <= value <= 1,
                    f"Invalid {field}")
        material_info.append({"name": material.get("name", str(index)), "base_color_image": source,
                              "emission_image": emissive_source, "emissive_factor": emission})
    require(emission_images, "No material uses the emission atlas with nonzero emission")
    # Duplicate exporter image entries are allowed, provided their pixels are all
    # source-verified. Distinct source images must actually be material-bound.
    require(set(atlas_pixels.values()) <= {pixel_identity(images[i]) for i in used_images},
            "One of the source atlases is embedded but not used")

    points_by_mesh, triangles, vertices, surfaces, used_materials = [], 0, 0, 0, set()
    for mesh in meshes:
        points = []
        for primitive in mesh.get("primitives", []):
            require(primitive.get("mode", 4) == 4 and not primitive.get("targets"),
                    "Only rigid triangle meshes are permitted")
            attributes = primitive.get("attributes", {})
            require(all(key in attributes for key in ("POSITION", "NORMAL", "TEXCOORD_0")),
                    "Missing position, normal, or UV channel")
            positions, normals, uvs = [model.accessor(attributes[key])
                                      for key in ("POSITION", "NORMAL", "TEXCOORD_0")]
            require(len(positions) == len(normals) == len(uvs), "Vertex attribute counts differ")
            require(all(len(p) == 3 for p in positions + normals) and all(len(uv) == 2 for uv in uvs),
                    "Vertex attribute dimensions are invalid")
            require(all(0.5 < sum(v * v for v in normal) < 1.5 for normal in normals),
                    "Invalid vertex normal")
            require(all(-1e-5 <= v <= 1.00001 for uv in uvs for v in uv), "UVs outside the atlas")
            material_id = primitive.get("material", -1)
            require(isinstance(material_id, int) and 0 <= material_id < len(materials),
                    "Invalid primitive material")
            used_materials.add(material_id)
            if "indices" in primitive:
                acc = doc["accessors"][primitive["indices"]]
                require(acc["type"] == "SCALAR" and acc["componentType"] in (5121, 5123, 5125)
                        and not acc.get("normalized", False), "Invalid index accessor")
                indices = [value[0] for value in model.accessor(primitive["indices"])]
            else:
                indices = list(range(len(positions)))
            require(indices and len(indices) % 3 == 0 and
                    all(0 <= i < len(positions) for i in indices), "Invalid triangle indices")
            for offset in range(0, len(indices), 3):
                ia, ib, ic = indices[offset:offset + 3]
                a, b, c = positions[ia], positions[ib], positions[ic]
                ab, ac = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
                cross = (ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2],
                         ab[0] * ac[1] - ab[1] * ac[0])
                require(sum(v * v for v in cross) > 1e-18, "Degenerate geometry triangle")
                ua, ub, uc = uvs[ia], uvs[ib], uvs[ic]
                require(abs((ub[0] - ua[0]) * (uc[1] - ua[1]) -
                            (ub[1] - ua[1]) * (uc[0] - ua[0])) > 1e-12,
                        "Degenerate UV triangle")
            points.extend(positions)
            triangles += len(indices) // 3
            vertices += len(positions)
            surfaces += 1
        require(points, "Empty mesh")
        points_by_mesh.append(points)
    require(triangles <= spec["max_triangles"], f"{triangles} triangles exceeds {spec['max_triangles']} budget")
    require(used_materials == set(range(len(materials))), "Unused exported materials")

    scenes, scene_id = doc.get("scenes", []), doc.get("scene", 0)
    require(isinstance(scene_id, int) and 0 <= scene_id < len(scenes), "No default scene")
    visited, world_points, mesh_nodes = set(), [], []

    def visit(index, parent):
        require(isinstance(index, int) and 0 <= index < len(nodes) and index not in visited,
                "Invalid, shared, or cyclic scene node")
        visited.add(index)
        node = nodes[index]
        matrix = shared.matmul(parent, shared.node_matrix(node))
        if "mesh" in node:
            mesh_id = node["mesh"]
            require(isinstance(mesh_id, int) and 0 <= mesh_id < len(meshes), "Invalid mesh reference")
            mesh_nodes.append(index)
            world_points.extend(shared.transform(matrix, p) for p in points_by_mesh[mesh_id])
        for child in node.get("children", []):
            visit(child, matrix)

    for index in scenes[scene_id].get("nodes", []):
        visit(index, shared.IDENTITY)
    require(world_points and len(visited) == len(nodes), "Empty scene or orphan exported node")
    low = [min(p[i] for p in world_points) for i in range(3)]
    high = [max(p[i] for p in world_points) for i in range(3)]
    dimensions = [high[i] - low[i] for i in range(3)]
    require(all(math.isfinite(value) and value > 0 for value in dimensions), "Invalid scene bounds")
    radius = max(math.hypot(point[0], point[2]) for point in world_points)
    if "max_radius_xz" in spec:
        require(radius <= spec["max_radius_xz"] + 1e-4, f"Scene radius {radius:.3f} exceeds budget")
    if "max_height" in spec:
        require(dimensions[1] <= spec["max_height"] + 1e-4, f"Scene height {dimensions[1]:.3f} exceeds budget")
    animations = audit_animation(model, spec, visited)
    return {"id": spec["id"], "file": path.name, "status": "pass", "bytes": len(model.data),
            "sha256": shared.digest(model.data), "triangles": triangles, "vertices": vertices,
            "surfaces": surfaces, "mesh_nodes": len(mesh_nodes), "materials": material_info,
            "embedded_images": images, "animations": animations, "bounds_min_xyz": low,
            "bounds_max_xyz": high, "dimensions_xyz": dimensions, "rest_radius_xz": radius,
            "required_nodes": spec.get("required_nodes", []), "external_buffers_or_images": False,
            "degenerate_geometry_or_uv_triangles": 0}


def collect(root):
    directory = root / ASSET_ROOT
    catalog = json.loads((directory / "docs/catalog.json").read_text())
    specs = catalog["assets"]
    require(len(specs) == 4 and len({spec["id"] for spec in specs}) == 4, "Expected four unique asset IDs")
    require({path.name for path in (directory / "meshes").glob("*.glb")} == {spec["file"] for spec in specs},
            "GLB inventory differs from catalog")
    textures = []
    for name in ("homeport_atlas.png", "homeport_emission.png"):
        path = directory / "textures" / name
        info = shared.png_info(path.read_bytes())
        require(info["width"] == info["height"] and info["width"] in (256, 512),
                f"{name}: source atlas must be 256 or 512 pixels square")
        textures.append({"file": name, **info})
    atlas_pixels = {image["file"]: pixel_identity(image) for image in textures}
    require(len(set(atlas_pixels.values())) == 2, "Color and emission atlases must have distinct pixel content")
    source = directory / "source/home_base.blend"
    source_bytes = source.read_bytes()
    require(len(source_bytes) > 1024 and source_bytes.startswith((b"BLENDER", b"\x1f\x8b", b"\x28\xb5\x2f\xfd")),
            "Editable Blender source is missing or has an invalid file signature")
    reports = []
    for spec in specs:
        path = directory / "meshes" / spec["file"]
        try:
            reports.append(audit_asset(path, spec, atlas_pixels))
        except (shared.InvalidAsset, KeyError, IndexError, TypeError, ValueError) as error:
            raise shared.InvalidAsset(f"{path.name}: {error}") from error
    return {"schema_version": 1, "package_id": catalog["package_id"], "status": "pass",
            "evidence_type": "Static GLB/PNG/source validation; engine rendering and gameplay are separate checks",
            "policy": {"geometry": "Per-asset triangle and rest-bounds budgets in catalog.json",
                       "textures": "Both original embedded PNG atlases, matching decoded source pixels",
                       "animation": "Rigid looping clips, valid keys, actual motion, matching endpoint poses",
                       "excluded": "Cameras, lights, skins, collision helpers, external texture/buffer dependencies"},
            "source": {"file": "source/home_base.blend", "bytes": len(source_bytes),
                       "sha256": shared.digest(source_bytes)}, "assets": reports, "textures": textures,
            "total_triangles": sum(asset["triangles"] for asset in reports)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, help="Optionally write JSON report; default is stdout only")
    args = parser.parse_args()
    try:
        report = collect(args.root.resolve())
        result = 0
    except (shared.InvalidAsset, KeyError, IndexError, TypeError, struct.error, OSError,
            ValueError, zlib.error, RecursionError) as error:
        report, result = {"status": "fail", "error": str(error)}, 1
    payload = shared.json_bytes(report)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(payload)
    print(payload.decode(), end="")
    return result


if __name__ == "__main__":
    raise SystemExit(main())
