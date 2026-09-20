#!/usr/bin/env python3
"""Verify the release gate against small real PCK fixtures, without Godot."""

import hashlib
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from export_release import export_errors
from inspect_release import inspect, read_pack, REQUIRED_RESOURCES, SHIPPING_AUDIO, BENCHMARK_RESOURCES


class ReleaseInspectionTests(unittest.TestCase):
    def test_benchmark_resources_require_explicit_nonshipping_mode(self) -> None:
        records = [{"path": p} for p in REQUIRED_RESOURCES | SHIPPING_AUDIO | BENCHMARK_RESOURCES | {"project.binary", "THIRD_PARTY_NOTICES.md"}]
        self.assertEqual(len(inspect(records)), len(BENCHMARK_RESOURCES))
        self.assertEqual(inspect(records, benchmark=True), [])
        records.append({"path": "benchmarks/candidate_performance.gdc"})
        self.assertEqual(inspect(records, benchmark=True), [])
        records.append({"path": "benchmarks/unlisted_debug_helper.gd"})
        self.assertEqual(len(inspect(records, benchmark=True)), 1)

    def make_pack(self, path: Path, contents: dict[str, bytes]) -> None:
        # Godot v3: 104-byte header, content bytes, then a directory of records.
        payload = b"".join(contents.values())
        header = b"GDPC" + struct.pack("<IIIIIQQ", 3, 4, 6, 3, 2, 104, 104 + len(payload)) + bytes(64)
        directory = struct.pack("<I", len(contents))
        offset = 0
        for name, value in contents.items():
            name_bytes = ("res://" + name).encode()
            name_bytes += bytes(-len(name_bytes) % 4)
            directory += struct.pack("<I", len(name_bytes)) + name_bytes
            directory += struct.pack("<QQ", offset, len(value))
            directory += hashlib.md5(value, usedforsecurity=False).digest() + struct.pack("<I", 0)
            offset += len(value)
        path.write_bytes(header + payload + directory)

    def test_reads_and_checks_real_pack_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pack = Path(directory) / "game.pck"
            self.make_pack(pack, {"project.binary": b"project", "THIRD_PARTY_NOTICES.md": b"notices"})
            records = read_pack(pack)
            self.assertFalse(any("package file" in error for error in inspect(records)))
            self.assertEqual([(r["path"], r["size"]) for r in records],
                             [("project.binary", 7), ("THIRD_PARTY_NOTICES.md", 7)])
            with pack.open("r+b") as file:
                file.seek(104)
                file.write(b"X")
            with self.assertRaisesRegex(ValueError, "Corrupt PCK entry"):
                read_pack(pack)

    def test_truncated_package_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pack = Path(directory) / "game.pck"
            self.make_pack(pack, {"project.binary": b"project"})
            pack.write_bytes(pack.read_bytes()[:-5])
            with self.assertRaisesRegex(ValueError, "Truncated"):
                read_pack(pack)

    def test_development_files_are_rejected_but_shipping_mockup_hulls_are_allowed(self) -> None:
        records = [{"path": path} for path in [
            "project.binary", "THIRD_PARTY_NOTICES.md",
            "assets/models/mockups/butterfly.glb.import",
            "mockups_v11/composition.png", "mcp_interaction_server.gdc",
            "tests/autoload_smoke.gdc", "assets/models/source.blend",
            ".godot/imported/source.blend-abcdef.scn",
        ]]
        records.extend({"path": path} for path in REQUIRED_RESOURCES | SHIPPING_AUDIO)
        errors = inspect(records)
        self.assertEqual(len(errors), 5, errors)
        self.assertFalse(any("butterfly" in error for error in errors))

    def test_missing_notice_and_unsafe_paths_fail(self) -> None:
        errors = inspect([{"path": "project.binary"}, {"path": "../outside"}])
        self.assertIn("Missing required package file: THIRD_PARTY_NOTICES.md", errors)
        self.assertIn("Unsafe package path: ../outside", errors)
        self.assertIn("Missing runtime scene: Planets/Star/Star.tscn", errors)

    def test_only_known_headless_shutdown_diagnostic_is_allowed(self) -> None:
        log = "\n".join([
            "ERROR: 2 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit.",
            "ERROR: Cannot load required resource",
            "SCRIPT ERROR: Parse Error: unknown identifier",
        ])
        self.assertEqual(export_errors(log), ["ERROR: Cannot load required resource",
                                              "SCRIPT ERROR: Parse Error: unknown identifier"])

    def test_remap_must_point_to_an_exported_resource(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pack = Path(directory) / "game.pck"
            self.make_pack(pack, {"ui/main_menu.tscn.remap": b'[remap]\npath="res://.godot/exported/menu.scn"\n'})
            errors = inspect(read_pack(pack))
            self.assertIn("Missing remap target: ui/main_menu.tscn.remap -> .godot/exported/menu.scn", errors)

    def test_unreferenced_preview_audio_is_rejected(self) -> None:
        errors = inspect([{"path": "assets/unused_preview.wav.import"}])
        self.assertIn("Audio outside the shipping inventory: assets/unused_preview.wav.import", errors)


if __name__ == "__main__":
    unittest.main()
