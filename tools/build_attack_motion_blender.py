"""Add attack clips to existing editable rigs, preserving their geometry.

Run: Blender --background --python tools/build_attack_motion_blender.py
Existing canonical source files are updated after exporting their selected rigs.
No import/rebind, palette replacement, gameplay transforms or new mesh instances.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import sys

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_combat_motion_blender as writer
from enemy_attack_motion import boss_clips, regular_clips
import build_voxel_frontier_blender as fleet


def update_scene(scene, recipes, output, offset, tint):
    bpy.context.window.scene = scene
    rig = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
    rig.animation_data_create()
    for track in list(rig.animation_data.nla_tracks):
        if track.name in recipes:
            rig.animation_data.nla_tracks.remove(track)
    for name, keys in recipes.items():
        action = bpy.data.actions.new(scene.name + '__' + name)
        rig.animation_data.action = action
        for seconds, values in keys:
            writer.key_pose(rig, values, offset + round(seconds * 30))
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, offset, action).name = name
        rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = False
    scene.frame_set(offset)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB',
        use_selection=True, use_active_scene=True, export_animations=True,
        export_animation_mode='NLA_TRACKS', export_force_sampling=True,
        export_frame_range=False, export_skins=True, export_def_bones=True,
        export_anim_single_armature=False, export_yup=True,
        export_cameras=False, export_lights=False, export_extras=False)
    data = output.read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+size])
    if tint:
        for material in doc.get('materials', []):
            if material['name'].startswith('VF_'):
                canonical = re.sub(r'\.\d+$', '', material['name'])
                _, role, slot = canonical.split('_', 2)
                index = ('armor', 'edge', 'structure', 'trim', 'reactor', 'brass').index(slot)
                color = [*fleet.linear(fleet.PALETTES[role][index]), 1.0]
            else:
                color = list(bpy.data.materials[material['name']].diffuse_color)
            material.setdefault('pbrMetallicRoughness', {})['baseColorFactor'] = color
    for group in ('nodes', 'meshes', 'materials', 'skins', 'images'):
        for entry in doc.get(group, []):
            if 'name' in entry:
                entry['name'] = re.sub(r'\.\d+$', '', entry['name'])
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    tail = data[20+size:]
    output.write_bytes(struct.pack('<4sII', b'glTF', 2, 20+len(encoded)+len(tail)) +
                      struct.pack('<I4s', len(encoded), b'JSON') + encoded + tail)
    for track in rig.animation_data.nla_tracks:
        track.mute = track.name != 'cruise'
    scene.frame_set(offset)
    return dict(clips=[a['name'] for a in doc['animations']], bytes=output.stat().st_size,
                sha256=hashlib.sha256(output.read_bytes()).hexdigest())


def update_pack(source, manifest_path, entries, prefix, offset, tint):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    manifest = json.loads(manifest_path.read_text())
    for asset, role, output in entries:
        result = update_scene(bpy.data.scenes[prefix+asset],
                              boss_clips(role) if role not in writer.ENEMIES else regular_clips(role), output, offset, tint)
        record = next(item for item in manifest['assets'] if item.get('id', item.get('asset')) == asset)
        record.update(result)
        if 'animations' in record:
            record['animations'] = result['clips']
    manifest['attack_motion_revision'] = 1
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source))


if __name__ == '__main__':
    bosses = ROOT/'assets/models/voxel_bosses'
    roles = ('assault', 'bulwark', 'tempest', 'void_harbinger', 'tempest_core', 'section')
    ids = ('boss_assault', 'boss_bulwark', 'boss_tempest', 'boss_void_harbinger', 'boss_tempest_core', 'tempest_section')
    update_pack(bosses/'source/voxel_bosses.blend', bosses/'build_manifest.json',
                [(asset, role, bosses/'meshes'/f'{asset}.glb') for asset, role in zip(ids, roles)],
                'Voxel Bosses | ', 0, True)
    enemies = ROOT/'assets/models/voxel_frontier'
    update_pack(enemies/'source/voxel_frontier.blend', enemies/'build_manifest.json',
                [(f'{role}_enemy', role, enemies/'meshes'/f'{role}_enemy.glb') for role in writer.ENEMIES],
                'Voxel Frontier | ', 1, True)
    print('ATTACK_MOTION_EXPORTED 6 boss rigs and 5 regular enemy rigs')
