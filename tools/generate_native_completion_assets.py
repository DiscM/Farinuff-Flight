#!/usr/bin/env python3
"""Build original low-poly native upgrade/VFX GLBs using the local stdlib exporter.
The checked-in outputs are runtime assets; no procedural mesh building at boot.
"""
import json
import math
from pathlib import Path
import generate_mockup_models as gm

OUT = Path(__file__).resolve().parents[1] / 'assets/models/native'


def ring(model, radius, tube, y, material, part):
    for i in range(32):
        for j in range(6):
            vertices = []
            for a, b in [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]:
                angle, cross = a * math.tau / 32, b * math.tau / 6
                r = radius + math.cos(cross) * tube
                vertices.append((math.cos(angle) * r, y + math.sin(cross) * tube, math.sin(angle) * r))
            model.add_quad(vertices, material, part, part)


def build():
    orbital = gm.Model('orbital_sentinel', 'ORBITAL // SENTINEL')
    orbital.add_ellipsoid((0, 0, 0), (0.32, 0.22, 0.32), 'cyan', 'core', 4, 8)
    ring(orbital, 0.43, 0.045, 0, 'steel', 'cage')
    for side in [-1, 1]:
        orbital.add_beveled_plate([(side*.2,-.1),(side*.6,-.35),(side*.65,.3),(side*.2,.1)], -.06,.08,'yellow',f'fin{side}')
    mount = gm.Model('upgrade_orbitals', 'MODULE // ORBITAL CONTROL')
    ring(mount, .35,.035,.24,'cyan','coil')
    piercing = gm.Model('upgrade_piercing', 'MODULE // COIL LANCES')
    for side in [-1,1]:
        piercing.add_loft([(-1.65,.045,.18,.045),(-.55,.07,.18,.07)],'steel',f'rail{side}',6,side*.7)
        piercing.add_loft([(-1.55,.025,.25,.025),(-.65,.04,.25,.04)],'cyan',f'coil{side}',6,side*.7)
    explosive = gm.Model('upgrade_explosive', 'MODULE // PLASMA CELLS')
    for side in [-1,1]:
        for i in range(3):
            explosive.add_ellipsoid((side*(.7+i*.2),.18,.45),( .09,.09,.24),'orange',f'cell{side}{i}',4,8)
    shock = gm.Model('shock_ring', 'VFX // SHOCK RING')
    ring(shock,1.0,.035,0,'white','ring')
    flash = gm.Model('muzzle_flare', 'VFX // MUZZLE FLARE')
    flash.add_loft([(-.9,.015,0,.015),(-.2,.20,0,.12),(.12,.03,0,.03)],'white','flare',6)
    return [orbital,mount,piercing,explosive,shock,flash]


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for model in build():
        model.validate()
        stats = gm.export_glb(model, OUT / (model.name + '.glb'))
        manifest.append({'file': model.name + '.glb', **stats})
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps(manifest, indent=2))
