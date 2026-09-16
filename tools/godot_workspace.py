"""Private Godot project settings with shared source resources."""

from contextlib import contextmanager
import os
from pathlib import Path
import shutil
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def user_data_root() -> Path:
    """Godot's desktop application-data parent, before the custom profile name."""
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support"
    if sys.platform == "win32":
        return Path(os.environ["APPDATA"])
    configured = Path(os.environ.get("XDG_DATA_HOME", ""))
    return configured if configured.is_absolute() else Path.home() / ".local" / "share"


@contextmanager
def staged_project(settings: str, *, reuse_import_cache: bool = True):
    with tempfile.TemporaryDirectory(prefix="farinuff-project-") as directory:
        project = Path(directory)
        for source in ROOT.iterdir():
            if source.name in {"project.godot", "override.cfg", ".git"}:
                continue
            if source.name == ".godot" and not reuse_import_cache:
                continue
            if source.name == "export_presets.cfg":
                shutil.copyfile(source, project / source.name)
            else:
                (project / source.name).symlink_to(source, target_is_directory=source.is_dir())
        (project / "project.godot").write_text(settings, encoding="utf-8")
        yield project
