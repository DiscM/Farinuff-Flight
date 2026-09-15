#!/usr/bin/env python3
"""Exercise the smoke runner's process boundary without needing Godot."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "tools" / "run_smoke_tests.py"


class SmokeRunnerTests(unittest.TestCase):
    def run_fixture(self, body: str, *scenes: str, timeout: str = "5") -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / "godot"
            engine.write_text("#!/usr/bin/env python3\n" + body, encoding="utf-8")
            engine.chmod(0o755)
            result = subprocess.run(
                [sys.executable, str(RUNNER), "--godot", str(engine),
                 "--timeout", timeout, "--log-dir", str(root / "logs"),
                 *(scenes or ("pooling_smoke",))],
                text=True, capture_output=True, timeout=10, check=False,
            )
            self.assertTrue((root / "logs" / f"{scenes[0] if scenes else 'pooling_smoke'}.log").exists())
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


if __name__ == "__main__":
    unittest.main()
