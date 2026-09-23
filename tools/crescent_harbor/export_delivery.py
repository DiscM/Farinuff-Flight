"""Export a verified source checkpoint without resaving or rebuilding it."""
from pathlib import Path
import json
import sys

import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build_crescent_harbor_blender import ASSET, export_file, export_module, save_manifest

manifest = json.loads((ASSET / 'build_manifest.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(ASSET / 'source/wayfarer_crescent.blend'))
scene = bpy.context.scene
scene.frame_set(1)
stations = [scene.objects[name] for name in manifest['major_roots']]
cables = [scene.objects[name] for name in manifest['cable_roots']]
fleet = [scene.objects[name] for name in manifest['ship_roots']]
exports = [export_file(ASSET / 'meshes/wayfarer_crescent.glb', stations + cables + fleet)]
for index, root in enumerate(stations):
    name = 'wayfarer_core.glb' if index == 0 else root['service_kind'] + '_relay.glb'
    exports.append(export_module(ASSET / 'meshes' / name, root))
for root in [fleet[0], fleet[2], fleet[3], fleet[9]]:
    exports.append(export_module(ASSET / 'meshes' / (root.name.lower() + '.glb'), root))
save_manifest(scene, stations, cables, fleet, exports)
print('VERIFIED_CHECKPOINT_EXPORTED', exports[0], flush=True)
