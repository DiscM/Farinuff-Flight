#!/usr/bin/env python3
"""File-only resource/asset checks. Does not launch or substitute for Godot."""
from pathlib import Path
import json
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
checked = 0
for directory in ('entities', 'systems', 'scenes', 'effects', 'ui', 'autoloads', 'tests', 'tools'):
    for path in (ROOT / directory).rglob('*'):
        if path.suffix not in ('.gd', '.tscn', '.tres', '.gdshader'):
            continue
        # Vendored standalone projects use their own res:// root.
        if any(parent != ROOT and (parent / 'project.godot').exists() for parent in path.parents if parent != ROOT.parent):
            continue
        checked += 1
        source = path.read_text()
        # Ignore historical comments; resource strings can include spaces.
        source = '\n'.join(line for line in source.splitlines() if not line.lstrip().startswith('#'))
        for resource in re.findall(r'"res://([^"\n]+)"', source):
            if '%' not in resource and not (ROOT / resource).exists():
                errors.append(f'{path.relative_to(ROOT)}: missing {resource}')
        if path.suffix in ('.tscn', '.tres'):
            for kind, declaration in [('ExtResource', 'ext_resource'), ('SubResource', 'sub_resource')]:
                defined = re.findall(r'\[' + declaration + r'[^\n]*\bid="([^"]+)"', source)
                if len(defined) != len(set(defined)):
                    errors.append(f'{path.relative_to(ROOT)}: duplicate {kind} IDs')
                used = set(re.findall(kind + r'\("([^"]+)"\)', source))
                for missing in used - set(defined):
                    errors.append(f'{path.relative_to(ROOT)}: undefined {kind} {missing}')
        if path.relative_to(ROOT).parts[0] == 'entities' and re.search(r'(extends Area2D|type="Area2D")', source):
            errors.append(f'{path.relative_to(ROOT)}: legacy combat actor')

assets = list((ROOT / 'assets/models/native').glob('*.glb'))
for asset in assets:
    blob = asset.read_bytes()
    magic, version, size = struct.unpack_from('<III', blob)
    if magic != 0x46546C67 or version != 2 or size != len(blob):
        errors.append(f'{asset.name}: invalid GLB header')
        continue
    json_size, chunk_type = struct.unpack_from('<II', blob, 12)
    data = json.loads(blob[20:20 + json_size])
    binary_offset = 20 + json_size
    binary_size, binary_type = struct.unpack_from('<II', blob, binary_offset)
    if chunk_type != 0x4E4F534A or binary_type != 0x004E4942 or binary_offset + 8 + binary_size != size:
        errors.append(f'{asset.name}: invalid GLB chunks')
    for view in data.get('bufferViews', []):
        if view.get('byteOffset', 0) + view['byteLength'] > binary_size:
            errors.append(f'{asset.name}: out-of-bounds buffer view')
    for mesh in data.get('meshes', []):
        for primitive in mesh['primitives']:
            for accessor in list(primitive['attributes'].values()) + [primitive['indices']]:
                if accessor >= len(data['accessors']):
                    errors.append(f'{asset.name}: missing accessor')

upgrade_source = (ROOT / 'entities/player/native_player_upgrades.gd').read_text()
visual_source = (ROOT / 'entities/player/native_upgrade_visuals.gd').read_text()
ids = re.findall(r'"([a-z_]+)"', upgrade_source.split('static func')[0])
if len(ids) != 13 or len(set(ids)) != 13:
    errors.append('Elite catalog must expose 13 distinct native abilities')
for upgrade in ids:
    if f'"{upgrade}": preload(' not in visual_source:
        errors.append(f'Missing native module: {upgrade}')
for entry in ('ui/main_menu.gd', 'ui/game_over.gd'):
    if 'res://scenes/native_3d_run.tscn' not in (ROOT / entry).read_text():
        errors.append(f'{entry}: native entry missing')
if (ROOT / 'scenes/game.tscn').exists():
    errors.append('Retired gameplay entry still present')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'PASS: {checked} source/resources, {len(assets)} generated GLBs, 13 upgrade modules, native entry points.')
print('Static checks only; GDScript parsing and gameplay require Godot validation.')
