#!/usr/bin/env python3
"""Audit original Voxel Frontier GLBs and create a verified, self-contained ZIP.

Uses only the Python standard library. No Blender/Godot process is launched.
Run from the repository with --validate-only for a read-only geometry audit.
Builds fail closed if required source art, materials, or embedded textures are absent.
"""

from __future__ import annotations

import argparse
import binascii
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import zipfile
import zlib


ASSET_ROOT = Path("assets/models/voxel_frontier")
PACKAGE_NAME = "Farinuff_Flight_Voxel_Frontier_1.0.0"
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
IDENTITY = [1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1.]
MAX_TRIANGLES = 20000
MAX_VERTICES = 40000
CORE_FILES = (
    "tools/package_voxel_frontier.py",
    "tools/build_voxel_frontier_blender.py",
    "tools/build_voxel_frontier_atlas.py",
    "tools/build_combat_motion_blender.py",
    "effects/rendering/enemy_surface_materials.gd",
    "effects/rendering/station_debris_materials.gd",
    "effects/shaders/models/imported_enemy_surface_3d.gdshader",
    "effects/shaders/models/pixel_planet_enemy_3d.gdshader",
    "effects/shaders/PixelPlanets/LICENSE",
)


class InvalidAsset(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidAsset(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def matmul(a, b):
    return [sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4)) for col in range(4) for row in range(4)]


def node_matrix(node):
    if "matrix" in node:
        result = node["matrix"]
        require(len(result) == 16 and all(math.isfinite(v) for v in result), "Invalid node matrix")
        return result
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    result = [
        (1 - 2*y*y - 2*z*z)*sx, (2*x*y + 2*z*w)*sx, (2*x*z - 2*y*w)*sx, 0,
        (2*x*y - 2*z*w)*sy, (1 - 2*x*x - 2*z*z)*sy, (2*y*z + 2*x*w)*sy, 0,
        (2*x*z + 2*y*w)*sz, (2*y*z - 2*x*w)*sz, (1 - 2*x*x - 2*y*y)*sz, 0,
        tx, ty, tz, 1,
    ]
    require(all(math.isfinite(v) for v in result), "Nonfinite node transform")
    require(abs(sx * sy * sz) > 1e-12, "Collapsed node scale")
    return result


def transform(matrix, point):
    return tuple(sum(matrix[k * 4 + row] * point[k] for k in range(3)) + matrix[12 + row] for row in range(3))


def png_info(data):
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), "Embedded image is not a PNG")
    offset, compressed, header, ended = 8, bytearray(), None, False
    while offset + 12 <= len(data):
        length, kind = struct.unpack_from(">I4s", data, offset)
        end = offset + 12 + length
        require(end <= len(data), "Truncated PNG chunk")
        payload = data[offset+8:offset+8+length]
        crc = struct.unpack_from(">I", data, offset+8+length)[0]
        require(binascii.crc32(kind + payload) & 0xFFFFFFFF == crc, "PNG chunk CRC mismatch")
        if kind == b"IHDR":
            require(header is None and length == 13, "Invalid PNG IHDR")
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            require(length == 0, "Invalid PNG IEND")
            ended = True
            break
        offset = end
    require(header and ended and compressed, "Incomplete PNG")
    width, height, depth, color, compression, filtering, interlace = header
    require(0 < width <= 4096 and 0 < height <= 4096, "PNG outside 1–4096px budget")
    require(depth == 8 and color in (0, 2, 4, 6), "Atlas must use 8-bit gray/RGB/RGBA PNG")
    require(compression == 0 and filtering == 0 and interlace == 0, "Unsupported PNG encoding")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    decoded = zlib.decompress(bytes(compressed))
    row_size = 1 + width * channels
    require(len(decoded) == row_size * height, "PNG decoded pixel count mismatch")
    require(all(decoded[y * row_size] <= 4 for y in range(height)), "Invalid PNG filter")
    # Decode lossless PNG row filters so re-encoding by Blender can be compared
    # by pixels, without mistaking a different compression stream for repainting.
    rgba, previous = bytearray(), bytearray(width * channels)
    for y in range(height):
        method = decoded[y * row_size]
        row = bytearray(decoded[y * row_size + 1:(y + 1) * row_size])
        for x in range(len(row)):
            left = row[x - channels] if x >= channels else 0
            above = previous[x]
            corner = previous[x - channels] if x >= channels else 0
            if method == 1:
                predictor = left
            elif method == 2:
                predictor = above
            elif method == 3:
                predictor = (left + above) // 2
            elif method == 4:
                p = left + above - corner
                distances = (abs(p - left), abs(p - above), abs(p - corner))
                predictor = (left, above, corner)[distances.index(min(distances))]
            else:
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        for x in range(0, len(row), channels):
            sample = row[x:x+channels]
            if color == 0:
                rgba.extend((sample[0], sample[0], sample[0], 255))
            elif color == 2:
                rgba.extend((*sample, 255))
            elif color == 4:
                rgba.extend((sample[0], sample[0], sample[0], sample[1]))
            else:
                rgba.extend(sample)
        previous = row
    return {"width": width, "height": height, "bit_depth": depth, "channels": channels, "sha256": digest(data), "rgba_pixels_sha256": digest(rgba), "bytes": len(data)}


class GLB:
    def __init__(self, path):
        self.path = path
        self.data = path.read_bytes()
        require(len(self.data) >= 20, "Truncated GLB header")
        magic, version, length = struct.unpack_from("<4sII", self.data)
        require(magic == b"glTF" and version == 2 and length == len(self.data), "Invalid GLB 2.0 header or length")
        offset, chunks = 12, []
        while offset < length:
            require(offset + 8 <= length, "Truncated GLB chunk header")
            size, kind = struct.unpack_from("<II", self.data, offset)
            require(size % 4 == 0 and offset + 8 + size <= length, "Invalid GLB chunk size")
            chunks.append((kind, self.data[offset+8:offset+8+size]))
            offset += 8 + size
        require(len(chunks) == 2 and chunks[0][0] == 0x4E4F534A and chunks[1][0] == 0x004E4942, "Expected JSON and BIN chunks only")
        self.doc = json.loads(chunks[0][1])
        self.bin = chunks[1][1]
        require(self.doc.get("asset", {}).get("version") == "2.0", "glTF version is not 2.0")
        buffers = self.doc.get("buffers", [])
        require(len(buffers) == 1 and "uri" not in buffers[0], "GLB must have one embedded buffer")
        require(0 <= len(self.bin) - buffers[0]["byteLength"] <= 3, "GLB buffer length mismatch")
        self.buffer_length = buffers[0]["byteLength"]
        for view in self.doc.get("bufferViews", []):
            require(view.get("buffer", 0) == 0, "BufferView refers to an external buffer")
            start, size = view.get("byteOffset", 0), view["byteLength"]
            require(start >= 0 and size > 0 and start + size <= self.buffer_length, "BufferView exceeds buffer")

    def accessor(self, index):
        accessors = self.doc.get("accessors", [])
        require(isinstance(index, int) and 0 <= index < len(accessors), "Accessor reference out of range")
        acc = accessors[index]
        require("sparse" not in acc and "bufferView" in acc, "Sparse or missing accessor bufferView")
        require(acc["componentType"] in COMPONENTS and acc["type"] in WIDTHS, "Unsupported accessor encoding")
        view = self.doc["bufferViews"][acc["bufferView"]]
        code, size = COMPONENTS[acc["componentType"]]
        width = WIDTHS[acc["type"]]
        count = acc["count"]
        stride = view.get("byteStride", width * size)
        inner = acc.get("byteOffset", 0)
        require(count > 0 and stride >= width * size and inner >= 0, "Invalid accessor count/stride/offset")
        require(inner + (count - 1) * stride + width * size <= view["byteLength"], "Accessor exceeds BufferView")
        start = view.get("byteOffset", 0) + inner
        values = [struct.unpack_from("<" + code * width, self.bin, start + i * stride) for i in range(count)]
        if acc.get("normalized", False) and code != "f":
            denominator = {5120: 127., 5121: 255., 5122: 32767., 5123: 65535., 5125: 4294967295.}[acc["componentType"]]
            values = [tuple(max(-1., v / denominator) for v in item) for item in values]
        require(all(math.isfinite(v) for item in values for v in item), "Accessor contains nonfinite data")
        return values

    def image(self, image):
        require(image.get("mimeType") == "image/png" and "bufferView" in image and "uri" not in image, "Image must be an embedded PNG")
        view = self.doc["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        return png_info(self.bin[start:start + view["byteLength"]])

    def audit(self, stable_id):
        doc = self.doc
        require(not doc.get("cameras"), "Camera included in asset export")
        require(not doc.get("extensionsRequired"), "Runtime-critical glTF extensions are outside this package policy")
        nodes = doc.get("nodes", [])
        require(nodes and doc.get("meshes"), "No render geometry")
        for node in nodes:
            name = node.get("name", "").lower()
            require(not any(term in name for term in ("-col", "_collision", "-convcol", "-navmesh", "_collider", "rigidbody", "staticbody")), "Collision/helper node exported: " + name)
            require("camera" not in node and "KHR_lights_punctual" not in node.get("extensions", {}), "Camera/light node exported")
        skins = doc.get("skins", [])
        for skin in skins:
            joints = skin.get("joints", [])
            require(joints and len(joints) == len(set(joints)) and all(0 <= joint < len(nodes) for joint in joints), "Invalid skeleton joints")
            require(len(joints) == 4, "Enemy skeleton must retain four rigid bones")
            if "inverseBindMatrices" in skin:
                matrices = self.accessor(skin["inverseBindMatrices"])
                require(len(matrices) == len(joints) and all(len(matrix) == 16 for matrix in matrices), "Inverse bind matrices do not match joints")
        skin_by_mesh = {}
        for node in nodes:
            if "skin" in node:
                require("mesh" in node and 0 <= node["skin"] < len(skins), "Invalid skinned mesh node")
                skin_by_mesh.setdefault(node["mesh"], []).append(skins[node["skin"]])
        animation_info = []
        for animation in doc.get("animations", []):
            durations = []
            for channel in animation.get("channels", []):
                target = channel.get("target", {})
                require(0 <= target.get("node", -1) < len(nodes), "Animation target node out of range")
                require(target.get("path") in ("translation", "rotation", "scale"), "Animation target is not a rigid transform")
                sampler = animation["samplers"][channel["sampler"]]
                times, values = self.accessor(sampler["input"]), self.accessor(sampler["output"])
                require(all(len(time) == 1 for time in times), "Animation time accessor is not scalar")
                require(times[0][0] >= 0 and all(times[i][0] < times[i+1][0] for i in range(len(times)-1)), "Animation times must increase")
                interpolation = sampler.get("interpolation", "LINEAR")
                require(interpolation in ("LINEAR", "STEP", "CUBICSPLINE"), "Unsupported animation interpolation")
                multiplier = 3 if interpolation == "CUBICSPLINE" else 1
                require(len(values) == len(times) * multiplier, "Animation value/key count mismatch")
                width = 4 if target["path"] == "rotation" else 3
                require(all(len(value) == width for value in values), "Animation value width mismatch")
                durations.append(times[-1][0])
            require(durations and max(durations) > 0, "Animation clip is empty")
            animation_info.append({"name": animation.get("name", ""), "duration_seconds": max(durations), "channels": len(durations)})
        if skins:
            names = {item["name"].split("/")[-1] for item in animation_info}
            require(names == {"cruise", "hit", "windup", "attack"}, "Enemy animation clip set differs from contract")
        else:
            require(not animation_info, "Debris should be static; game owns tumbling motion")
        images = [self.image(item) for item in doc.get("images", [])]
        require(images, "Missing embedded atlas image")
        textures, materials = doc.get("textures", []), doc.get("materials", [])
        require(textures and materials, "Missing textures/materials")
        image_uses, material_info = set(), []
        for i, material in enumerate(materials):
            base = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            require(base is not None, f"Material {i} has no base-color texture")
            require(base.get("texCoord", 0) == 0, f"Material {i} expects a UV channel other than TEXCOORD_0")
            require(0 <= base["index"] < len(textures), "Texture index out of range")
            texture = textures[base["index"]]
            require("source" in texture and 0 <= texture["source"] < len(images), "Texture image source missing")
            image_uses.add(texture["source"])
            material_info.append({"index": i, "name": material.get("name", f"material_{i}"), "base_color_image": texture["source"], "base_color_factor": material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1]), "emissive_factor": material.get("emissiveFactor", [0, 0, 0])})
        color_factors = [tuple(material["base_color_factor"]) for material in material_info]
        require(len(set(color_factors)) > 1 and any(max(color[:3]) - min(color[:3]) > 0.03 for color in color_factors), "Role/material tints missing; grayscale atlas requires exported base-color factors")
        positions_by_mesh, vertex_count, triangle_count, surface_count = [], 0, 0, 0
        used_materials, degenerate_uvs = set(), 0
        for mesh_index, mesh in enumerate(doc["meshes"]):
            points = []
            for primitive in mesh.get("primitives", []):
                require(primitive.get("mode", 4) == 4 and "targets" not in primitive, "Expected static triangle mesh")
                attrs = primitive.get("attributes", {})
                require(all(k in attrs for k in ("POSITION", "NORMAL", "TEXCOORD_0")), "Missing position, normal, or UV channel")
                pos, normals, uvs = (self.accessor(attrs[key]) for key in ("POSITION", "NORMAL", "TEXCOORD_0"))
                require(len(pos) == len(normals) == len(uvs), "Attribute counts differ")
                require(all(len(p) == 3 for p in pos + normals) and all(len(uv) == 2 for uv in uvs), "Invalid attribute dimensions")
                require(all(0.5 < sum(n*n for n in normal) < 1.5 for normal in normals), "Invalid vertex normal length")
                require(all(-1e-5 <= uv <= 1.00001 for point in uvs for uv in point), "UVs outside atlas [0, 1]")
                if mesh_index in skin_by_mesh:
                    require("JOINTS_0" in attrs and "WEIGHTS_0" in attrs, "Skinned mesh missing joints/weights")
                    joints, weights = self.accessor(attrs["JOINTS_0"]), self.accessor(attrs["WEIGHTS_0"])
                    require(len(joints) == len(weights) == len(pos), "Skin attribute counts differ")
                    max_joints = min(len(skin["joints"]) for skin in skin_by_mesh[mesh_index])
                    require(all(len(joint) == len(weight) == 4 for joint, weight in zip(joints, weights)), "Skin attributes must be VEC4")
                    require(all(0 <= value < max_joints and int(value) == value for joint in joints for value in joint), "Joint index out of range")
                    require(all(all(0 <= value <= 1 for value in weight) and abs(sum(weight)-1) < 1e-4 for weight in weights), "Invalid/non-normalized skin weights")
                    require(all(sum(value > 1e-5 for value in weight) == 1 for weight in weights), "Voxel parts must be rigidly weighted to one bone")
                material_id = primitive.get("material", -1)
                require(0 <= material_id < len(materials), "Missing/out-of-range primitive material")
                used_materials.add(material_id)
                indices = [int(item[0]) for item in self.accessor(primitive["indices"])] if "indices" in primitive else list(range(len(pos)))
                if "indices" in primitive:
                    index_accessor = doc["accessors"][primitive["indices"]]
                    require(index_accessor["componentType"] in (5121, 5123, 5125) and index_accessor["type"] == "SCALAR" and not index_accessor.get("normalized", False), "Triangle indices must be unsigned integer scalars")
                require(len(indices) % 3 == 0 and all(0 <= index < len(pos) for index in indices), "Invalid triangle indices")
                for index in range(0, len(indices), 3):
                    ia, ib, ic = indices[index:index+3]
                    a, b, c = pos[ia], pos[ib], pos[ic]
                    ab, ac = [b[j]-a[j] for j in range(3)], [c[j]-a[j] for j in range(3)]
                    cross = [ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0]]
                    require(sum(v*v for v in cross) > 1e-18, "Degenerate triangle found")
                    ua, ub, uc = uvs[ia], uvs[ib], uvs[ic]
                    if abs((ub[0]-ua[0])*(uc[1]-ua[1])-(ub[1]-ua[1])*(uc[0]-ua[0])) <= 1e-12:
                        degenerate_uvs += 1
                vertex_count += len(pos)
                triangle_count += len(indices)//3
                surface_count += 1
                points.extend(pos)
            require(points, "Empty mesh")
            positions_by_mesh.append(points)
        require(triangle_count <= MAX_TRIANGLES and vertex_count <= MAX_VERTICES, "Geometry exceeds explicit per-asset budget")
        require(degenerate_uvs == 0, "Degenerate UV triangles would hide atlas detail")
        require(used_materials == set(range(len(materials))), "Unused materials included")
        require(image_uses == set(range(len(images))), "Embedded image not used by a base-color material")
        scenes = doc.get("scenes", [])
        scene_id = doc.get("scene", 0)
        require(0 <= scene_id < len(scenes), "Missing default scene")
        world_points, visited, mesh_nodes = [], set(), 0

        def visit(index, parent):
            nonlocal mesh_nodes
            require(0 <= index < len(nodes) and index not in visited, "Invalid or cyclic scene node reference")
            visited.add(index)
            node = nodes[index]
            matrix = matmul(parent, node_matrix(node))
            if "mesh" in node:
                require(0 <= node["mesh"] < len(positions_by_mesh), "Node mesh index out of range")
                world_points.extend(transform(matrix, p) for p in positions_by_mesh[node["mesh"]])
                mesh_nodes += 1
            for child in node.get("children", []):
                visit(child, matrix)

        for node_id in scenes[scene_id].get("nodes", []):
            visit(node_id, IDENTITY)
        require(world_points and len(visited) == len(nodes), "Empty scene or orphan exported nodes")
        minimum = [min(p[i] for p in world_points) for i in range(3)]
        maximum = [max(p[i] for p in world_points) for i in range(3)]
        dimensions = [maximum[i]-minimum[i] for i in range(3)]
        require(all(math.isfinite(value) and value > 0 for value in dimensions), "Invalid scene bounds")
        return {
            "id": stable_id, "file": self.path.name, "status": "pass", "bytes": len(self.data), "sha256": digest(self.data),
            "vertices": vertex_count, "triangles": triangle_count, "surfaces": surface_count, "mesh_nodes": mesh_nodes,
            "materials": material_info, "embedded_images": images,
            "skins": len(skins), "joint_counts": [len(skin["joints"]) for skin in skins], "animations": animation_info,
            "bounds_min_xyz": minimum, "bounds_max_xyz": maximum, "dimensions_xyz": dimensions,
            "uv_channels": ["TEXCOORD_0"], "degenerate_triangles": 0, "degenerate_uv_triangles": 0,
            "collisionless": True, "external_buffers_or_images": False,
        }


def collect(root):
    asset_dir = root / ASSET_ROOT
    specs = json.loads((asset_dir / "docs/catalog.json").read_text())
    meshes = sorted((asset_dir / "meshes").glob("*.glb"))
    expected = {entry["file"] for entry in specs["assets"]}
    require({path.name for path in meshes} == expected, "Mesh inventory differs from catalog.json")
    ids = [entry["id"] for entry in specs["assets"]]
    require(len(ids) == len(set(ids)), "Duplicate stable asset ID")
    reports = []
    for spec in specs["assets"]:
        report = GLB(asset_dir / "meshes" / spec["file"]).audit(spec["id"])
        report.update({"name": spec["name"], "role": spec["role"]})
        require(bool(report["skins"]) == (spec["category"] == "enemy"), "Catalog animation category disagrees with exported skin")
        require(report["mesh_nodes"] == (6 if spec["category"] == "enemy" else 1), "Mesh-node count differs from six-part enemy / merged debris contract")
        reports.append(report)
    atlases = sorted((asset_dir / "textures").glob("*.png"))
    require(atlases, "External editable atlas PNG missing")
    atlas_info = [{"file": str(path.relative_to(root)), **png_info(path.read_bytes())} for path in atlases]
    external_digests = {(item["width"], item["height"], item["rgba_pixels_sha256"]) for item in atlas_info}
    for report in reports:
        require(all((image["width"], image["height"], image["rgba_pixels_sha256"]) in external_digests for image in report["embedded_images"]), report["file"] + ": embedded atlas pixels differ from external source PNG")
    return {"schema_version": 1, "package_id": specs["package_id"], "status": "pass", "evidence_type": "Static file validation; rendered appearance is a separate check", "policy": {"max_triangles_per_asset": MAX_TRIANGLES, "max_vertices_per_asset": MAX_VERTICES, "max_texture_dimension": 4096, "required_uv": "TEXCOORD_0", "required_texture": "embedded base-color PNG on every material", "allow_collision_camera_light_nodes": False}, "assets": reports, "textures": atlas_info}


def file_map(root, includes):
    result = {}
    asset_dir = root / ASSET_ROOT
    for path in sorted(asset_dir.rglob("*")):
        if not path.is_file() or path.name.startswith(".") or path.suffix in (".import", ".blend1", ".blend2", ".pyc") or "__pycache__" in path.parts:
            continue
        if path.name in ("manifest.json", "validation.json", "MANIFEST.sha256", "TECHNICAL_SHEET.md"):
            continue
        result[path.relative_to(root).as_posix()] = path.read_bytes()
    for relative in includes:
        path = (root / relative).resolve()
        require(path.is_relative_to(root) and path.is_file(), f"Missing/invalid integration file: {relative}")
        result[path.relative_to(root).as_posix()] = path.read_bytes()
    require(any(name.endswith(".blend") for name in result), "Editable Blender source missing")
    require(any("build_" in name and name.endswith(".py") for name in result), "Reproducible Blender authoring script missing; include with --include")
    require(any(name.endswith(".gdshader") for name in result), "Runtime shader source missing; include with --include")
    result["README.md"] = (asset_dir / "docs/README.md").read_bytes()
    result["RIGHTS.md"] = (asset_dir / "docs/RIGHTS.md").read_bytes()
    # Regenerable source files are kept out of Godot's importer in an unpacked project.
    result[(ASSET_ROOT / "source/.gdignore").as_posix()] = b""
    result[(ASSET_ROOT / "docs/.gdignore").as_posix()] = b""
    result["design/voxel-frontier/.gdignore"] = b""
    return result


def technical_sheet(report):
    lines = [
        "# Voxel Frontier — technical inventory", "",
        "Measurements are read from the delivered GLB rest scene. X is width, Y is height, Z is length in Godot. Dimensions precede the game scene's per-role presentation scale.", "",
        "| Asset | Triangles | Vertices | Surfaces | Mesh nodes | Dimensions X × Y × Z |",
        "| --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for asset in report["assets"]:
        dims = " × ".join(f"{value:.2f}" for value in asset["dimensions_xyz"])
        lines.append(f"| `{asset['file']}` | {asset['triangles']:,} | {asset['vertices']:,} | {asset['surfaces']} | {asset['mesh_nodes']} | {dims} |")
    lines += ["", "Surfaces are material partitions; they are not a measured GPU draw-call count. Hard face normals intentionally split corner vertices.", "",
        f"The complete set contains {sum(a['triangles'] for a in report['assets']):,} triangles. Every GLB embeds the same 256 × 256 RGB atlas and supplies TEXCOORD_0 UVs on every surface.", "",
        "Each enemy has one four-joint skeleton and four clips: `cruise`, `hit`, `windup`, `attack`. All vertices carry one full-weight bone influence. Debris contains no skeletons or animation clips.", "",
        "The static validator requires nondegenerate geometry and UV triangles, finite coordinates, valid material tints and atlas references, and no collision meshes/cameras/lights. The exact check policy, all material factors, texture digests, and animation durations are in `validation.json`.", ""]
    return "\n".join(lines).encode()


def verify_zip(path):
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None, "ZIP CRC integrity failure")
        names = archive.namelist()
        require(len(names) == len(set(names)), "Duplicate ZIP members")
        prefix = PACKAGE_NAME + "/"
        require(all(name.startswith(prefix) and ".." not in Path(name).parts for name in names), "Unexpected ZIP root or unsafe member")
        manifest = json.loads(archive.read(prefix + "manifest.json"))
        expected = {prefix + entry["path"] for entry in manifest["files"]}
        require(set(names) == expected | {prefix + "manifest.json", prefix + "MANIFEST.sha256"}, "ZIP contents differ from manifest")
        for entry in manifest["files"]:
            data = archive.read(prefix + entry["path"])
            require(len(data) == entry["bytes"] and digest(data) == entry["sha256"], "Package hash mismatch: " + entry["path"])
        checksums = archive.read(prefix + "MANIFEST.sha256").decode()
        expected_checksums = "".join(f"{entry['sha256']}  {entry['path']}\n" for entry in manifest["files"])
        expected_checksums += digest(archive.read(prefix + "manifest.json")) + "  manifest.json\n"
        require(checksums == expected_checksums, "Checksum list disagrees with manifest")
        return {"status": "pass", "package": str(path), "files": len(names), "bytes": path.stat().st_size, "sha256": digest(path.read_bytes())}


def build(root, report, output, includes):
    files = file_map(root, includes)
    files["validation.json"] = json_bytes(report)
    files["TECHNICAL_SHEET.md"] = technical_sheet(report)
    provenance = json.loads((root / ASSET_ROOT / "docs/provenance.json").read_text())
    manifest = {
        "schema_version": 1, "package_id": provenance["package_id"], "version": provenance["version"],
        "license_spdx": provenance["license_spdx"], "source_type": provenance["source_type"],
        "asset_count": len(report["assets"]), "provenance": (ASSET_ROOT / "docs/provenance.json").as_posix(),
        "validation": "validation.json", "files": [{"path": name, "bytes": len(data), "sha256": digest(data)} for name, data in sorted(files.items())],
    }
    files["manifest.json"] = json_bytes(manifest)
    files["MANIFEST.sha256"] = ("".join(f"{entry['sha256']}  {entry['path']}\n" for entry in manifest["files"]) + digest(files["manifest.json"]) + "  manifest.json\n").encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Temporary archive is verified before replacing the previous package.
    with tempfile.NamedTemporaryFile(prefix="voxel_frontier_", suffix=".zip", dir=output.parent, delete=False) as temporary:
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
    (output.with_suffix(".zip.sha256")).write_text(f"{digest(output.read_bytes())}  {output.name}\n")
    (root / ASSET_ROOT / "docs/validation.json").write_bytes(json_bytes(report))
    (root / ASSET_ROOT / "docs/TECHNICAL_SHEET.md").write_bytes(technical_sheet(report))
    return verify_zip(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, help="ZIP destination (default: design/voxel-frontier/<package>.zip)")
    parser.add_argument("--include", action="append", default=[], help="Project-relative authoring/integration/preview file to include; repeatable")
    parser.add_argument("--validate-only", action="store_true", help="Validate art files without writing anything")
    parser.add_argument("--verify", type=Path, help="Verify an existing package instead of building")
    args = parser.parse_args()
    try:
        if args.verify:
            print(json.dumps(verify_zip(args.verify.resolve()), indent=2))
            return 0
        root = args.root.resolve()
        report = collect(root)
        if args.validate_only:
            print(json.dumps(report, indent=2))
        else:
            output = args.output.resolve() if args.output else root / "design/voxel-frontier" / (PACKAGE_NAME + ".zip")
            includes = list(CORE_FILES) + args.include
            print(json.dumps(build(root, report, output, includes), indent=2))
        return 0
    except (InvalidAsset, KeyError, IndexError, TypeError, struct.error, OSError, ValueError, zlib.error, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "fail", "error": str(error)}, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
