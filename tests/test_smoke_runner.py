#!/usr/bin/env python3
"""Exercise the smoke runner's process boundary without needing Godot."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "tools" / "run_smoke_tests.py"


class SmokeRunnerTests(unittest.TestCase):
    def run_fixture(self, body: str, *scenes: str, timeout: str = "5", suite: str | None = None) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / "godot"
            engine.write_text("#!/usr/bin/env python3\n" + body, encoding="utf-8")
            engine.chmod(0o755)
            result = subprocess.run(
                [sys.executable, str(RUNNER), "--godot", str(engine),
                 "--timeout", timeout, "--log-dir", str(root / "logs"),
                 *(scenes or (() if suite is not None else ("pooling_smoke",))),
                 *(["--suite", suite] if suite else [])],
                text=True, capture_output=True, timeout=10, check=False,
            )
            self.assertTrue(any((root / "logs").glob("*.log")))
            return result

    def test_success_requires_completion(self) -> None:
        result = self.run_fixture('print("POOLING_SMOKE_PASS")\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Smoke tests: 1/1 passed", result.stdout)

    def test_zero_exit_without_completion_fails(self) -> None:
        result = self.run_fixture('print("Godot started but no assertions ran")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing completion marker", result.stdout)

    def test_script_error_fails_even_with_completion_and_zero_exit(self) -> None:
        result = self.run_fixture('print("SCRIPT ERROR: Invalid call")\nprint("POOLING_SMOKE_PASS")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("Godot reported a script error", result.stdout)

    def test_nonzero_exit_fails_even_with_completion(self) -> None:
        result = self.run_fixture('print("POOLING_SMOKE_PASS")\nraise SystemExit(2)\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("Godot exited with code 2", result.stdout)

    def test_hung_scene_times_out(self) -> None:
        result = self.run_fixture("import time\ntime.sleep(30)\n", timeout="0.2")
        self.assertEqual(result.returncode, 1)
        self.assertIn("timed out after 0.2 seconds", result.stdout)

    def test_failure_does_not_skip_remaining_scenes(self) -> None:
        result = self.run_fixture(
            'import sys\nif sys.argv[-1].endswith("autoload_smoke.tscn"):\n    print("AUTOLOAD_SMOKE_PASS")\n',
            "pooling_smoke", "autoload_smoke",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("AUTOLOAD_SMOKE_PASS", result.stdout)
        self.assertIn("Smoke tests: 1/2 passed", result.stdout)

    def test_scenes_receive_distinct_disposable_profiles(self) -> None:
        result = self.run_fixture(
            'import pathlib, re, sys\n'
            'project = pathlib.Path(sys.argv[sys.argv.index("--path") + 1])\n'
            'config = (project / "project.godot").read_text()\n'
            'names = re.findall(r\'config/custom_user_dir_name="([^"]+)"\', config)\n'
            'assert names and names[-1].startswith("farinuff-smoke-")\n'
            'assert "config/use_custom_user_dir=true" in config\n'
            'assert (project / "autoloads" / "save_manager.gd").exists()\n'
            'print("PROFILE=" + names[-1])\n'
            'print(pathlib.Path(sys.argv[-1]).stem.upper() + "_PASS")\n',
            "pooling_smoke", "autoload_smoke",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        profiles = [line.removeprefix("PROFILE=") for line in result.stdout.splitlines()
                    if line.startswith("PROFILE=")]
        self.assertEqual(len(set(profiles)), 2)

    def test_default_suite_covers_production_without_visuals_or_benchmark(self) -> None:
        result = self.run_fixture(
            'import pathlib, sys\nprint(pathlib.Path(sys.argv[-1]).stem.upper() + "_PASS")\n',
            suite="",  # No scene or suite arguments: exercise the CLI default.
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for scene in ("menu_boot", "frontend_navigation", "native_completion",
                      "expedition_progression", "autoload", "pooling", "resource_cache",
                      "audio_settings", "home_base", "home_base_ui"):
            self.assertIn(scene.upper() + "_SMOKE_PASS", result.stdout)
        self.assertNotIn("RUN_WARMUP_BENCHMARK_PASS", result.stdout)
        self.assertNotIn("FRONTIER_VISUAL_SMOKE_PASS", result.stdout)
        self.assertIn("Smoke tests: 10/10 passed", result.stdout)

    def test_extended_suite_runs_real_scene_wrappers_including_benchmark(self) -> None:
        result = self.run_fixture(
            'import pathlib, sys\n'
            'project = pathlib.Path(sys.argv[sys.argv.index("--path") + 1])\n'
            'assert (project / sys.argv[-1].removeprefix("res://")).is_file()\n'
            'print(pathlib.Path(sys.argv[-1]).stem.upper() + "_PASS")\n',
            suite="extended",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("RUN_WARMUP_BENCHMARK_PASS", result.stdout)
        self.assertIn("VOXEL_BOSS_MATERIAL_SMOKE_PASS", result.stdout)
        self.assertIn("MENU_BOOT_SMOKE_PASS", result.stdout)

    def test_production_journey_scenes_are_registered(self) -> None:
        result = self.run_fixture(
            'import pathlib, sys\nprint(pathlib.Path(sys.argv[-1]).stem.upper() + "_PASS")\n',
            "frontend_navigation_smoke", "expedition_progression_smoke",
            "menu_boot_smoke", "neon_cabinet_smoke", "background_drift_smoke",
            suite="extended",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Smoke tests: 5/5 passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
