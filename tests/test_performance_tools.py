#!/usr/bin/env python3
"""Exercise measurement math, completion gates, artifact trust, and isolation."""

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from performance_report import STAGES, percentile, summarize
from run_performance import capture, main, sha256, verify_build
from godot_workspace import ROOT, user_data_root


def telemetry(cycles=3):
    config = {"cycles": float(cycles), "seconds": 10, "endless_seconds": 60, "warmup_seconds": 2}
    metadata = {"config": config, "scenario": "candidate-pressure-v1", "display": "headless",
                "debug_build": True, "os": "macOS"}
    events = [{"version": 1, "kind": "metadata", "payload": metadata}]
    def emit(kind, payload):
        events.append({"version": 1, "kind": kind, "payload": payload})
    state = {"nodes": 38, "objects": 3000, "resources": 1000, "orphan_nodes": None,
             "static_bytes": None, "renderer_bytes": None}
    counters = []
    for shots in (1, 100):
        counters.append({"projectiles": {"player": {"shots_fired": shots}, "enemy": {"shots_fired": shots},
                                         "active": 30, "pool_growth_after_warmup": 0},
                         "enemies": 10, "hazards": {"total_active": 3, "pool_growth_after_warmup": 0},
                         "effects": {"pool_growth_after_warmup": 0}})
    for cycle in range(cycles):
        for name in ("menu", "launch"):
            emit("transition", {"cycle": cycle, "name": name, "elapsed_ms": 20})
        for name in STAGES:
            emit("warmup", {"cycle": cycle, "name": name, "simulation_seconds": 2,
                            "frame_intervals_ms": [16] * 125, "counters": copy.deepcopy(counters)})
            emit("stage", {"cycle": cycle, "name": name, "simulation_seconds": 60 if name == "endless" else 10,
                           "boss_phase": 2 if name.startswith("boss_") else None,
                           "boss_attacks": [{"id": "fixture", "simulation_seconds": 3}], "boss_selection_seed": 8026,
                           "frame_intervals_ms": [16] * 625, "counters": copy.deepcopy(counters)})
        emit("transition", {"cycle": cycle, "name": "retry", "elapsed_ms": 40})
        emit("cleanup", {"cycle": cycle, "state": copy.deepcopy(state)})
    emit("complete", {"cycles": cycles})
    return events


class PerformanceReportTests(unittest.TestCase):
    def test_nearest_rank_retains_outliers_and_hitches(self):
        self.assertEqual(percentile(list(range(1, 101)), .95), 95)
        events = telemetry()
        stage = next(e["payload"] for e in events if e["kind"] == "stage")
        stage["frame_intervals_ms"] = [16] * 98 + [55, 80]
        row = summarize(events, [])["stages"][0]
        self.assertEqual(row["p95_ms"], 16)
        self.assertEqual(row["p99_ms"], 55)
        self.assertEqual(row["max_ms"], 80)
        self.assertEqual(row["hitches_over_50_ms"], 2)
        self.assertFalse(row["meets_frame_targets"])

    def test_float_cycles_and_unavailable_counters(self):
        report = summarize(telemetry(), [{"rss_bytes": None}, {"rss_bytes": 12345}])
        self.assertEqual(len(report["stages"]), 21)
        self.assertEqual(report["classification"], "headless_functional_check")
        self.assertEqual(report["rss_peak_bytes"], 12345)
        self.assertIsNone(report["cleanup"]["static_bytes"]["last_minus_first"])
        self.assertEqual(report["cleanup"]["nodes"]["last_minus_first"], 0)
        self.assertFalse(report["target_windows_measured"])

    def test_short_local_release_run_is_not_full_protocol_or_windows_evidence(self):
        events = telemetry(1)
        events[0]["payload"].update(debug_build=False, display="macOS")
        report = summarize(events, [])
        self.assertEqual(report["classification"], "release_runtime_measurement")
        self.assertFalse(report["full_protocol_duration"])
        self.assertFalse(report["target_windows_measured"])
        self.assertIsNone(report["cleanup"]["nodes"]["last_minus_first"])

    def test_background_release_is_never_foreground_windows_evidence(self):
        events = telemetry()
        events[0]["payload"].update(debug_build=False, display="Windows", os="Windows")
        events[0]["payload"]["config"]["allow_background"] = True
        report = summarize(events, [])
        self.assertEqual(report["classification"], "background_rendered_diagnostic")
        self.assertFalse(report["target_windows_measured"])

    def test_missing_duplicate_and_reordered_stages_fail(self):
        for change in (lambda e: e.pop(4), lambda e: e.insert(4, e[4]), lambda e: e.reverse()):
            events = telemetry()
            change(events)
            with self.assertRaises(ValueError):
                summarize(events, [])

    def test_missing_completion_warmup_transition_and_cleanup_fail(self):
        for kind in ("complete", "warmup", "transition", "cleanup"):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                summarize([e for e in telemetry() if e["kind"] != kind], [])

    def test_missing_active_workload_fails(self):
        for missing in ("fire", "enemy_fire", "enemies", "hazards", "boss_phase"):
            events = telemetry()
            stage = next(e["payload"] for e in events if e["kind"] == "stage" and e["payload"]["name"] == "boss_assault")
            for counter in stage["counters"]:
                if missing == "fire":
                    counter["projectiles"]["player"]["shots_fired"] = 100
                elif missing == "enemy_fire":
                    counter["projectiles"]["enemy"]["shots_fired"] = 0
                elif missing == "enemies":
                    counter["enemies"] = 0
                elif missing == "hazards":
                    counter["hazards"]["total_active"] = 0
                else:
                    stage["boss_phase"] = 0
            with self.subTest(missing=missing), self.assertRaises(ValueError):
                summarize(events, [])

    def test_nonfinite_samples_and_malformed_payloads_fail(self):
        for value in (float("nan"), float("inf"), 0, -1, True, "16"):
            events = telemetry()
            next(e["payload"] for e in events if e["kind"] == "stage")["frame_intervals_ms"][0] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                summarize(events, [])
        events = telemetry()
        del events[0]["payload"]["config"]
        with self.assertRaisesRegex(ValueError, "Malformed"):
            summarize(events, [])


class PerformanceProcessTests(unittest.TestCase):
    def test_utf8_telemetry_and_output_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "李"
            output.mkdir()
            record = 'PERFORMANCE_EVENT ' + json.dumps({"version": 1, "kind": "complete", "payload": {"name": "李"}}, ensure_ascii=False) + '\n'
            body = "import sys; sys.stdout.buffer.write(" + repr(record.encode("utf-8")) + ")"
            events, _, _, _ = capture([sys.executable, "-c", body], output, output / "config.json", 2)
            self.assertEqual(events[0]["payload"]["name"], "李")
            self.assertIn("李", (output / "runtime.log").read_text(encoding="utf-8"))

    def test_errors_timeouts_and_shutdown_diagnostics_are_distinct(self):
        for body, failure in (("print('ERROR: rendering failed')", ValueError),
                              ("import time; time.sleep(30)", TimeoutError),
                              ("print('SCRIPT ERROR: invalid call')", ValueError)):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                with self.assertRaises(failure):
                    capture([sys.executable, "-c", body], root, root / "config.json", .2)
                self.assertTrue((root / "runtime.log").exists())
                self.assertTrue((root / "rss.json").exists())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body = 'print(\'PERFORMANCE_EVENT {"version":1,"kind":"complete","payload":{}}\'); print("ERROR: teardown diagnostic")'
            _, _, _, diagnostics = capture([sys.executable, "-c", body], root, root / "config.json", 2)
            self.assertEqual(diagnostics, [{"phase": "shutdown", "message": "ERROR: teardown diagnostic"}])

    def test_shipping_and_modified_packages_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            metadata = root / "build.json"
            metadata.write_text(json.dumps({"purpose": "release_candidate"}))
            with self.assertRaisesRegex(ValueError, "dedicated"):
                verify_build(root)
            metadata.write_text(json.dumps({"purpose": "performance_benchmark"}))
            for name in ("Farinuff Flight.exe", "Farinuff Flight.pck"):
                (root / name).write_bytes(b"fixture")
            (root / "SHA256SUMS.txt").write_text("\n".join(sha256(p) + "  " + p.name for p in root.iterdir()))
            self.assertEqual(verify_build(root)["purpose"], "performance_benchmark")
            (root / "Farinuff Flight.pck").write_bytes(b"modified")
            with self.assertRaisesRegex(ValueError, "checksum"):
                verify_build(root)

    def test_source_run_uses_and_removes_private_project_and_profile(self):
        original = (ROOT / "project.godot").read_bytes()
        observed = []
        def fake_capture(command, output, config_path, timeout):
            project = Path(command[command.index("--path") + 1])
            settings = (project / "project.godot").read_text()
            import re
            profile = re.findall(r'config/custom_user_dir_name="([^"]+)"', settings)[-1]
            self.assertTrue(profile.startswith("farinuff-performance-"))
            self.assertIn('run/main_scene="res://benchmarks/candidate_performance.tscn"', settings)
            observed.extend([project, user_data_root() / profile])
            events = telemetry(1)
            events[0]["payload"].update(cpu="fixture", gpu="", driver="headless", vsync=None, frame_cap=0)
            events[0]["payload"]["config"].update(json.loads(config_path.read_text()))
            return events, [], {}, []
        engine = json.loads((ROOT / "tools/godot_release.json").read_text())["engine_version"]
        with tempfile.TemporaryDirectory() as directory, patch("run_performance.capture", fake_capture), patch("run_performance.subprocess.check_output", side_effect=["abc", "", engine]):
            with patch.object(sys, "argv", ["run_performance.py", "--godot", sys.executable, "--cycles", "1", "--output", directory]):
                self.assertEqual(main(), 0)
        self.assertEqual((ROOT / "project.godot").read_bytes(), original)
        self.assertTrue(all(not p.exists() for p in observed))


if __name__ == "__main__":
    unittest.main()
