"""Render the production attack fixture with disposable saves and GPU output."""
import argparse
import subprocess
from run_smoke_tests import isolated_project
from godot_workspace import ROOT

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    args=parser.parse_args()
    log=ROOT/'design/attack-motion/render.log'
    with isolated_project() as project,log.open('w') as output:
        result=subprocess.run([args.godot,'--path',str(project),'res://tests/enemy_attack_animation_smoke.tscn'],stdout=output,stderr=subprocess.STDOUT,timeout=90)
    data=log.read_text()
    print(data)
    raise SystemExit(0 if result.returncode==0 and 'ENEMY_ATTACK_ANIMATION_SMOKE_PASS' in data and 'SCRIPT ERROR' not in data else 1)
