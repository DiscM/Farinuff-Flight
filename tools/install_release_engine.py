#!/usr/bin/env python3
"""Install the pinned Linux CI editor and/or desktop release templates."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.request
import zipfile

from godot_workspace import ROOT, user_data_root


def download(name: str, digest: str, cache: Path, tag: str) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / name
    if not archive.exists():
        partial = archive.with_suffix(".download")
        url = f"https://github.com/godotengine/godot-builds/releases/download/{tag}/{name}"
        print(f"Downloading {name}", flush=True)
        with urllib.request.urlopen(url, timeout=60) as source, partial.open("wb") as target:
            shutil.copyfileobj(source, target)
        partial.replace(archive)
    with archive.open("rb") as source:
        actual = hashlib.file_digest(source, "sha256").hexdigest()
    if actual != digest:
        raise ValueError(f"Checksum mismatch: {archive}; remove it before retrying")
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--editor-dir", type=Path, help="install the Linux x86_64 editor here")
    parser.add_argument("--templates", action="store_true", help="install Windows/Linux release templates")
    parser.add_argument("--cache", type=Path, default=ROOT / ".godot" / "production-downloads")
    args = parser.parse_args()
    if not args.editor_dir and not args.templates:
        parser.error("select --editor-dir and/or --templates")
    if args.editor_dir and sys.platform != "linux":
        parser.error("the CI editor is Linux x86_64; use your matching local Godot editor on other hosts")
    lock = json.loads((ROOT / "tools" / "godot_release.json").read_text())
    if args.editor_dir:
        name = f"Godot_v{lock['tag']}_linux.x86_64"
        archive = download(name + ".zip", lock["editor_sha256"], args.cache, lock["tag"])
        args.editor_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as package:
            with package.open(name) as source, (args.editor_dir / "godot").open("wb") as target:
                shutil.copyfileobj(source, target)
        (args.editor_dir / "godot").chmod(0o755)
        if os.environ.get("GITHUB_PATH"):
            with open(os.environ["GITHUB_PATH"], "a", encoding="utf-8") as path_file:
                path_file.write(str(args.editor_dir.resolve()) + "\n")
    if args.templates:
        archive = download(f"Godot_v{lock['tag']}_export_templates.tpz",
                           lock["templates_sha256"], args.cache, lock["tag"])
        godot_folder = "godot" if sys.platform.startswith("linux") else "Godot"
        destination = user_data_root() / godot_folder / "export_templates" / (lock["version"] + ".stable")
        destination.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as package:
            for name in ("windows_release_x86_64.exe", "linux_release.x86_64"):
                with package.open("templates/" + name) as source, (destination / name).open("wb") as target:
                    shutil.copyfileobj(source, target)
                (destination / name).chmod(0o755)
        print(f"Verified release templates installed in {destination}")


if __name__ == "__main__":
    main()
