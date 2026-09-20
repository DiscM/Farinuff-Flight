#!/usr/bin/env python3
"""Check resource references and scene IDs; Godot import validates asset formats."""
from pathlib import Path
import re
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
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'PASS: resource references and scene IDs in {checked} source/resources.')
print('Static checks only; GDScript parsing and gameplay require Godot validation.')
