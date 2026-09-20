#!/usr/bin/env python3
"""Render a source-motion contact sheet without modifying saved boss assets.

Usage inside Blender:
  blender --background assets/models/voxel_bosses/source/voxel_bosses.blend \
    --python tools/render_voxel_boss_preview.py -- --frames-dir /tmp/boss-frames

The presentation scene's six copied rigs receive temporary preview actions.
Isolated asset scenes and the .blend file stay untouched. Frames demonstrate
Blender source articulation; they are not a gameplay or shader verification.
Assemble with regular Python and Pillow (no Blender import is needed):
  python3 tools/render_voxel_boss_preview.py --assemble \
    --frames-dir /tmp/boss-frames --output motion_preview.gif

The output is a 3.6-second loop sampled at 10 fps, 1050 x 875 pixels.
"""

import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ROLES = {
    "boss_assault": "assault",
    "boss_bulwark": "bulwark",
    "boss_tempest": "tempest",
    "boss_void_harbinger": "void_harbinger",
    "boss_tempest_core": "tempest_core",
    "tempest_section": "section",
}


def load_helper(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    import bpy

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames-dir", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    args.frames_dir.mkdir(parents=True, exist_ok=True)
    board = bpy.data.scenes["Voxel Bosses | Collection"]
    bpy.context.window.scene = board
    board.render.engine = "BLENDER_EEVEE"
    board.render.resolution_x, board.render.resolution_y = 1050, 875
    board.render.resolution_percentage = 100
    board.render.image_settings.file_format = "PNG"
    board.render.fps = 30
    board.frame_start, board.frame_end = 0, 105
    key_writer = load_helper("build_combat_motion_blender")
    poses = load_helper("voxel_boss_motion")

    for asset_id, role in ROLES.items():
        collection = next(child for child in board.collection.children
                          if child.name.split(".")[0] == "Asset / " + asset_id)
        rigs = [obj for obj in collection.objects if obj.type == "ARMATURE"]
        if len(rigs) != 1:
            raise RuntimeError(f"Expected one presentation rig for {asset_id}")
        rig = rigs[0]
        # AnimationData belongs to the copied board object, not the shared
        # armature data. Clearing it leaves each isolated source scene intact.
        rig.animation_data_clear()
        rig.animation_data_create()
        action = bpy.data.actions.new("PreviewOnly_" + asset_id)
        rig.animation_data.action = action
        clips = poses.clips(role)
        key_writer.key_pose(rig, poses.pose(), 0)
        windup_start, release_time = .35, 1.55
        windup_end = 1.35
        windup_duration = clips["windup"][-1][0]
        for seconds, values in clips["windup"]:
            time = windup_start + seconds / windup_duration * (windup_end - windup_start)
            key_writer.key_pose(rig, values, round(time * 30))
        for seconds, values in clips["attack"]:
            key_writer.key_pose(rig, values, round((release_time + seconds) * 30))
        key_writer.key_pose(rig, poses.pose(), 105)
        # Match the delivered export's integer-frame linear interpolation.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation = "LINEAR"

    subtitle = next(obj for obj in board.objects if obj.name.split(".")[0] == "Subtitle")
    subtitle.data = subtitle.data.copy()
    subtitle.data.body = "BLENDER SOURCE MOTION   /   ANTICIPATION - RELEASE - SETTLE"
    for number, frame in enumerate(range(0, 106, 3)):
        board.frame_set(frame)
        board.render.filepath = str(args.frames_dir / f"frame_{number:03d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"VOXEL_BOSS_PREVIEW_FRAME {number + 1}/36 source_frame={frame}", flush=True)
    print("VOXEL_BOSS_PREVIEW_COMPLETE", str(args.frames_dir), flush=True)


def assemble():
    """Use one palette across all frames to prevent per-frame color flicker."""
    from PIL import Image

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assemble", action="store_true")
    parser.add_argument("--frames-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    paths = sorted(args.frames_dir.glob("frame_*.png"))
    if len(paths) != 36:
        raise RuntimeError(f"Expected 36 rendered frames, found {len(paths)}")
    frames = [Image.open(path).convert("RGB") for path in paths]
    if any(frame.size != (1050, 875) for frame in frames):
        raise RuntimeError("Rendered frame dimensions differ from the preview contract")
    contact = Image.new("RGB", (262, 219 * len(frames)))
    for index, frame in enumerate(frames):
        contact.paste(frame.resize((262, 219)), (0, index * 219))
    palette = contact.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    indexed[0].save(args.output, save_all=True, append_images=indexed[1:],
                    duration=100, loop=0, disposal=2, optimize=False)
    print("VOXEL_BOSS_PREVIEW_GIF", str(args.output), flush=True)


if __name__ == "__main__":
    assemble() if "--assemble" in sys.argv else main()
