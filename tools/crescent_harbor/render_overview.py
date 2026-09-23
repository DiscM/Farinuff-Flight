"""Refresh the overview without rewriting the verified animation source."""
from pathlib import Path
import hashlib
import json

import bpy

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/models/wayfarer_crescent'
PREVIEW = ROOT / 'design/home-base/blender-crescent'
bpy.ops.wm.open_mainfile(filepath=str(ASSET / 'source/wayfarer_crescent.blend'))
scene = bpy.context.scene
scene.frame_set(1)
scene.render.filepath = str(PREVIEW / 'crescent-harbor-overview.png')
bpy.ops.render.render(write_still=True)
path = ASSET / 'build_manifest.json'
manifest = json.loads(path.read_text())
manifest['previews'] = [
    {'path': str(p.relative_to(ROOT)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
    for p in sorted(PREVIEW.glob('*.png'))
]
path.write_text(json.dumps(manifest, indent=2) + '\n')
