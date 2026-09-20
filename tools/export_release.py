#!/usr/bin/env python3
"""Export an inspectable Windows release candidate; never publish or promote it."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

from inspect_release import inspect, read_pack, SHIPPING_AUDIO
from godot_workspace import ROOT, staged_project


def export_errors(log_text: str) -> list[str]:
    # Godot 4.6.3's headless importer leaks dummy-renderer shader handles at
    # shutdown. Retain the diagnostic in export.log without hiding real errors.
    return [line for line in log_text.splitlines()
            if re.match(r"^(?:SCRIPT ERROR|ERROR):", line)
            and not re.fullmatch(r"ERROR: \d+ RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit\.", line)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_PATH", "godot"))
    parser.add_argument("--git", default="git")
    parser.add_argument("--output", required=True, type=Path, help="new, empty artifact directory")
    parser.add_argument("--allow-dirty", action="store_true", help="local validation only; records dirty state")
    parser.add_argument("--benchmark", action="store_true", help="dedicated non-shipping performance package with isolated progress")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error(f"Godot executable not found: {args.godot}")
    lock = json.loads((ROOT / "tools" / "godot_release.json").read_text())
    engine = subprocess.check_output([godot, "--version"], text=True).strip()
    if engine != lock["engine_version"]:
        parser.error(f"Expected Godot {lock['version']} stable, got {engine}")
    revision = subprocess.check_output([args.git, "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    status = subprocess.check_output([args.git, "status", "--porcelain"], cwd=ROOT, text=True)
    if status and not args.allow_dirty:
        parser.error("Release candidates require a clean checkout; --allow-dirty is for local validation")
    project = (ROOT / "project.godot").read_text()
    if re.search(r'(?m)^config/custom_user_dir_name="(?:Farinuff Flight Smoke Tests|farinuff-smoke-)', project):
        parser.error("Refusing to export a project configured with a smoke-test save directory")
    if "mcp_interaction_server" in project:
        parser.error("Stop the development bridge before exporting")
    referenced_audio = set()
    for folder in ("autoloads", "campaign", "effects", "entities", "scenes", "systems", "ui"):
        for source in (ROOT / folder).rglob("*"):
            if source.suffix in {".gd", ".tscn", ".tres"}:
                referenced_audio.update(re.findall(r'res://([^"\n]+\.(?:wav|ogg|mp3|flac))"', source.read_text()))
    if referenced_audio != SHIPPING_AUDIO:
        parser.error("Update tools/shipping_audio.json to match runtime audio references: "
                     + ", ".join(sorted(referenced_audio ^ SHIPPING_AUDIO)))
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("The output directory must be empty (previous candidates are preserved)")
    output.mkdir(parents=True, exist_ok=True)
    executable = output / "Farinuff Flight.exe"
    log_path = output / "export.log"
    # Import/export settings belong to a private project, not the developer's
    # project.godot or the source revision recorded in the candidate metadata.
    export_settings = project + '\n[editor]\nimport/use_multiple_threads=false\n[filesystem]\nimport/blender/enabled=false\n'
    benchmark_profile = "farinuff-performance-" + uuid.uuid4().hex if args.benchmark else None
    if args.benchmark:
        export_settings += ('\n[application]\nrun/main_scene="res://benchmarks/candidate_performance.tscn"\n'
                            'run/flush_stdout_on_print=true\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(benchmark_profile)
                            + '\n[benchmark]\nenabled=true\n')
    with staged_project(export_settings, reuse_import_cache=False) as staged:
        # Only the explicitly inventoried sampler cues belong in a candidate.
        excluded_audio = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "assets").rglob("*")
                                if path.suffix.lower() in {".wav", ".ogg", ".mp3", ".flac"}
                                and path.relative_to(ROOT).as_posix() not in SHIPPING_AUDIO)
        presets = (staged / "export_presets.cfg").read_text()
        if args.benchmark:
            presets = presets.replace('custom_features=""', 'custom_features="performance_benchmark"')
            presets = presets.replace('benchmarks/**,', '')
        presets = re.sub(r'^exclude_filter="([^"]*)"',
                         lambda match: 'exclude_filter=' + json.dumps(match[1] + "," + ",".join(excluded_audio), ensure_ascii=False),
                         presets, flags=re.MULTILINE)
        (staged / "export_presets.cfg").write_text(presets)
        (output / "shipping-audio.json").write_text(json.dumps(sorted(SHIPPING_AUDIO), indent=2) + "\n")
        # The cursor and bundled theme fonts have not been imported on first boot.
        # Restore both settings after import, before exporting the shipping config.
        (staged / "project.godot").write_text(export_settings + '\n[display]\nmouse_cursor/custom_image=""\n[gui]\ntheme/custom=""\n')
        import_log = output / "import.log"
        with import_log.open("w") as log:
            imported = subprocess.run([godot, "--headless", "--path", str(staged), "--import"],
                                      stdout=log, stderr=subprocess.STDOUT, timeout=600, check=False)
        if imported.returncode or export_errors(import_log.read_text(errors="replace")):
            print(f"Import failed; inspect {import_log}")
            return 1
        (staged / "project.godot").write_text(export_settings)
        with log_path.open("w") as log:
            result = subprocess.run([godot, "--headless", "--path", str(staged),
                                     "--export-release", "Windows Desktop", str(executable)],
                                    stdout=log, stderr=subprocess.STDOUT, timeout=600, check=False)
    log_text = log_path.read_text(errors="replace")
    if result.returncode or export_errors(log_text):
        print(f"Export failed; inspect {log_path}")
        return 1
    if not executable.exists() or executable.stat().st_size == 0:
        raise ValueError("Export did not produce a Windows executable")
    records = read_pack(executable.with_suffix(".pck"))
    errors = inspect(records, benchmark=args.benchmark)
    (output / "package-manifest.json").write_text(json.dumps({"files": records, "errors": errors}, indent=2) + "\n")
    if errors:
        print("\n".join(errors))
        return 1
    shutil.copyfile(ROOT / "THIRD_PARTY_NOTICES.md", output / "THIRD_PARTY_NOTICES.md")
    # PixelPlanets is a nested Godot project: the exporter ignores its raw
    # LICENSE even with an include_filter. Ship full notices as loose files.
    licenses = {
        "Barlow-OFL.txt": "assets/fonts/barlow/OFL.txt",
        "PixelPlanets-LICENSE.txt": "effects/shaders/PixelPlanets/LICENSE",
        "Kenney-License.txt": "ui/kenney_ui-pack-space-expansion/License.txt",
        "SunGraphica-source-info.txt": "assets/Game UI collection FREE version/Sungraphica + info .txt",
        "Shapeforms-License.pdf": "assets/Shapeforms Audio Free Sound Effects/Shapeforms Audio License Agreement.pdf",
    }
    (output / "licenses").mkdir()
    for name, source in licenses.items():
        shutil.copyfile(ROOT / source, output / "licenses" / name)
    version = re.search(r'(?m)^config/version="([^"]+)"', project).group(1)
    metadata = {
        "application_version": version,
        "commit": revision,
        "dirty": bool(status),
        "working_tree_status": status.splitlines(),
        "engine": engine,
        "engine_lock": lock,
        "preset": "Windows Desktop",
        "built_at_utc": datetime.now(timezone.utc).isoformat(),
        "package_files": len(records),
        "purpose": "performance_benchmark" if args.benchmark else "release_candidate",
        "benchmark_profile": benchmark_profile,
        "validation": "Export and package inspection only; target-machine playtest and permissions remain required.",
    }
    (output / "build.json").write_text(json.dumps(metadata, indent=2) + "\n")
    checksums = []
    for file in sorted(output.rglob("*")):
        if file.is_file():
            with file.open("rb") as source:
                checksums.append(f"{hashlib.file_digest(source, 'sha256').hexdigest()}  {file.relative_to(output).as_posix()}")
    (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n")
    label = "Non-shipping Windows benchmark" if args.benchmark else "Windows candidate"
    print(f"{label}: {output} ({len(records)} verified package entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
