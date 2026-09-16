#!/usr/bin/env python3
"""Run a fresh-profile opening playtest and retain local milestone timings."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys

from run_smoke_tests import isolated_project


def summarize(log: str) -> list[dict]:
    sessions: dict[str, dict] = {}
    for line_number, line in enumerate(log.splitlines(), start=1):
        if not line.startswith("OPENING_METRICS "):
            continue
        try:
            event = json.loads(line.removeprefix("OPENING_METRICS "))
            if not isinstance(event, dict) or not isinstance(event.get("session"), str) or not isinstance(event.get("event"), str):
                raise ValueError("missing session or event")
        except ValueError:
            print(f"Skipping incomplete or invalid timing record at log line {line_number}", file=sys.stderr)
            continue
        session = sessions.setdefault(event["session"], {"session": event["session"], "events": []})
        session["events"].append(event)
    return list(sessions.values())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, help="new directory for logs and timing records")
    parser.add_argument("--summarize", type=Path, help="read an existing Godot log without launching")
    args = parser.parse_args()
    if args.summarize:
        print(json.dumps(summarize(args.summarize.read_text(errors="replace")), indent=2))
        return 0
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error("Godot executable not found; pass --godot with its path")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = args.output or Path(".godot/opening-sessions") / stamp
    output.mkdir(parents=True, exist_ok=False)
    print(f"Fresh-profile playtest. Close the game to finish. Local logs: {output.resolve()}", flush=True)
    with isolated_project() as project, (output / "godot.log").open("w") as log:
        result = subprocess.run([godot, "--path", str(project), "--", "--opening-metrics"],
                                stdout=log, stderr=subprocess.STDOUT, check=False)
    records = summarize((output / "godot.log").read_text(errors="replace"))
    (output / "timings.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"Recorded {len(records)} flight sessions. Missing milestones remain unobserved.")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
