"""Render two detail views from the delivered scene without changing its source."""
from pathlib import Path
import hashlib
import json

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DELIVERY = ROOT / 'assets/models/wayfarer_crescent'
PREVIEWS = ROOT / 'design/home-base/blender-crescent'

bpy.ops.wm.open_mainfile(filepath=str(DELIVERY / 'source/wayfarer_crescent.blend'))
scene = bpy.context.scene
scene.frame_set(1)
scene.cycles.samples = 32
scene.render.resolution_percentage = 100
camera = scene.camera

for root_name, stem, scale, width, height, elevation in (
    ('Wayfarer_Core', 'crescent-core-detail', 98, 1600, 1200, 8),
    ('Relay_05_RefuelRepair', 'crescent-service-detail', 43, 1400, 1100, 5),
):
    target = scene.objects[root_name].matrix_world.translation + Vector((0, 0, elevation))
    camera.location = target + Vector((150, -200, 180))
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = scale
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = str(PREVIEWS / (stem + '.png'))
    bpy.ops.render.render(write_still=True)
    print('DETAIL_RENDER', scene.render.filepath, flush=True)

manifest_path = DELIVERY / 'build_manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['previews'] = [
    {'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    for path in sorted(PREVIEWS.glob('*.png'))
]
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
