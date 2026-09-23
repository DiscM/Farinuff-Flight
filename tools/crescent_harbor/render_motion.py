"""Render a disposable motion review from the saved Crescent Harbor scene.

Run an inexpensive probe first (writes only under /tmp):
    Blender --background --factory-startup --python-exit-code 1 \
        --python tools/crescent_harbor/render_motion.py -- --test

After the final source is ready, explicitly request the complete movie:
    Blender --background --factory-startup --python-exit-code 1 \
        --python tools/crescent_harbor/render_motion.py -- --render

The Blender source is opened read-only in practice: no save operator is used.
Temporary PNG frames are encoded into H.264 and removed after successful export.
The 24 fps authored animation is sampled every third frame and played at 8 fps,
so a 480-frame loop retains its intended 20-second duration.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

import bpy


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "assets/models/wayfarer_crescent/source/wayfarer_crescent.blend"
DEFAULT_OUTPUT = ROOT / "design/home-base/blender-crescent/crescent-motion.mp4"
DEFAULT_TEST = Path("/tmp/crescent-motion-test.png")


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--test", action="store_true", help="Render a single frame only.")
    mode.add_argument("--render", action="store_true", help="Render and encode the full loop.")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--width", type=int, default=960)
    parser.add_argument("--height", type=int, default=540)
    parser.add_argument("--fps", type=int, default=8)
    parser.add_argument("--test-frame", type=int, default=121)
    parser.add_argument("--samples", type=int, default=24)
    parser.add_argument("--camera-scale", type=float, default=1.0,
                        help="Optional orthographic camera multiplier; 1 keeps every island in view.")
    parser.add_argument("--ffmpeg", type=Path, default=Path("/opt/homebrew/bin/ffmpeg"))
    parser.add_argument("--keep-frames", action="store_true")
    return parser.parse_args(argv)


def set_engine(scene, samples):
    """Use the local Blender version's registered Eevee engine, when present."""
    identifiers = {item.identifier for item in
                   scene.render.bl_rna.properties["engine"].enum_items}
    for identifier in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        if identifier in identifiers:
            scene.render.engine = identifier
            eevee = getattr(scene, "eevee", None)
            if eevee is not None:
                for prop in ("taa_render_samples", "taa_samples"):
                    if hasattr(eevee, prop):
                        setattr(eevee, prop, samples)
            return identifier
    if "CYCLES" not in identifiers:
        raise RuntimeError("No supported preview engine: " + ", ".join(sorted(identifiers)))
    scene.render.engine = "CYCLES"
    scene.cycles.samples = min(samples, 8)
    scene.cycles.use_denoising = True
    return "CYCLES"


def render_frame(scene, frame, destination):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    scene.render.filepath = str(destination)
    started = time.monotonic()
    bpy.ops.render.render(write_still=True)
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("Rendered frame is missing: " + str(destination))
    return time.monotonic() - started


def checked_enum(owner, name, value):
    choices = {item.identifier for item in owner.bl_rna.properties[name].enum_items}
    if value not in choices:
        raise RuntimeError(f'Unsupported {name}={value}; expected one of {sorted(choices)}')
    setattr(owner, name, value)


def encode(frames, destination, fps, ffmpeg):
    if not ffmpeg.is_file():
        raise FileNotFoundError(ffmpeg)
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y",
               "-framerate", str(fps), "-start_number", "0",
               "-i", str(frames / "frame-%04d.png"), "-an",
               "-c:v", "libx264", "-preset", "medium", "-crf", "18",
               "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(destination)]
    subprocess.run(command, check=True)
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("Encoder did not create the movie: " + str(destination))


def main():
    args = arguments()
    if args.width <= 0 or args.height <= 0 or args.width % 2 or args.height % 2:
        raise ValueError("Preview width and height must be positive even integers.")
    if args.fps <= 0 or not 0.5 <= args.camera_scale <= 1.5:
        raise ValueError("Invalid preview frame rate or camera scale.")
    source = args.source.resolve()
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    if scene.camera is None:
        raise RuntimeError("The saved scene has no presentation camera.")
    authored_fps = scene.render.fps / scene.render.fps_base
    ratio = authored_fps / args.fps
    if not math.isclose(ratio, round(ratio), abs_tol=1e-6):
        raise ValueError("Preview FPS must divide the authored frame rate exactly.")
    step = int(round(ratio))
    # Frame 481 closes the loop and repeats frame 1, so it is not encoded twice.
    frame_numbers = list(range(scene.frame_start, scene.frame_end, step))
    engine = set_engine(scene, args.samples)
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    checked_enum(scene.render.image_settings, 'file_format', 'PNG')
    checked_enum(scene.render.image_settings, 'color_mode', 'RGB')
    checked_enum(scene.render.image_settings, 'color_depth', '8')
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    if scene.camera.data.type == "ORTHO":
        scene.camera.data.ortho_scale *= args.camera_scale
    report = {"source": str(source), "source_sha256": source_hash,
              "blender_version": bpy.app.version_string, "engine": engine,
              "resolution": [args.width, args.height], "fps": args.fps,
              "authored_fps": authored_fps, "source_frame_step": step,
              "frame_count": len(frame_numbers), "duration_seconds": len(frame_numbers) / args.fps,
              "camera_scale": args.camera_scale}
    if args.test:
        output = (args.output or DEFAULT_TEST).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        seconds = render_frame(scene, args.test_frame, output)
        report.update({"mode": "test", "test_frame": args.test_frame,
                       "render_seconds": round(seconds, 3),
                       "cold_frame_based_estimate_seconds": round(seconds * len(frame_numbers), 1),
                       "output": str(output)})
    else:
        output = (args.output or DEFAULT_OUTPUT).resolve()
        if output.suffix.lower() != ".mp4":
            raise ValueError("Full preview output must use an .mp4 extension.")
        frames = Path(tempfile.mkdtemp(prefix="crescent-motion-"))
        print("CRESCENT_MOTION_FRAMES " + str(frames), flush=True)
        timings = []
        for index, frame in enumerate(frame_numbers):
            timings.append(render_frame(scene, frame, frames / ("frame-%04d.png" % index)))
            if index == 0 or (index + 1) % 8 == 0:
                print("CRESCENT_MOTION_PROGRESS " + json.dumps({
                    "complete": index + 1, "total": len(frame_numbers),
                    "last_frame_seconds": round(timings[-1], 3)}), flush=True)
        encode(frames, output, args.fps, args.ffmpeg)
        report.update({"mode": "movie", "output": str(output),
                       "render_seconds": round(sum(timings), 3),
                       "mean_frame_seconds": round(sum(timings) / len(timings), 3),
                       "movie_bytes": output.stat().st_size})
        if args.keep_frames:
            report["frames_directory"] = str(frames)
        else:
            shutil.rmtree(frames)
        if hashlib.sha256(source.read_bytes()).hexdigest() != source_hash:
            raise RuntimeError("The source changed on disk during preview rendering; regenerate the preview.")
    output.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
    print("CRESCENT_MOTION_RESULT " + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
