#!/usr/bin/env python3
"""Rigid animation poses for the Voxel Frontier boss fleet.

This module intentionally has no Blender dependency. ``clips(role)`` returns
fresh ``(seconds, pose_dictionary)`` keys accepted by ``key_pose`` in
``build_combat_motion_blender.py``. The rig contract is Body, Port, Starboard,
and Weapon; Blender coordinates are +Y forward and +Z up. Fold, sweep, and
pitch are degrees; spread and recoil are model-space units.

Only visual bones animate. Body lift remains zero and body scale remains one,
so no clip changes the actor origin, collision shape, or gameplay timing.
Godot's ShipMotion3D stretches windup to the encounter's warning duration and
holds its final pose; attack starts in precisely that pose. Sample at 30 fps
with AUTO_CLAMPED Bezier handles to preserve each release and prevent ringing.

Run this file with ordinary Python to validate all six motion identities and
print a compact duration/key-count report. Importing it performs no I/O.
"""

import json
import math


ROLES = ("assault", "bulwark", "tempest", "void_harbinger", "tempest_core", "section")
BONES = ("Body", "Port", "Starboard", "Weapon")
CLIP_NAMES = ("cruise", "hit", "windup", "attack")
POSE_KEYS = ("fold", "sweep", "spread", "recoil", "pitch", "lift", "scale")

DESIGN_NOTES = {
    "assault": "Scarlet ram: swept armor braces inward, punches forward, then rebounds sharply.",
    "bulwark": "Violet fortress: heavy armor opens slowly, braces against a broad recoil, and settles with weight.",
    "tempest": "Storm-blue vanes: a swept charge releases into a crisp counter-sweep and a quick spring return.",
    "void_harbinger": "Acid-green claws: slow inward contraction, wide unfurling impulse, and a lingering mechanical exhale.",
    "tempest_core": "Amber aperture: the central weapon extends while petals open, then fires into a deep recoil and staged closure.",
    "section": "Detached storm module: a restrained fin brace and short gun recoil keep the small silhouette legible.",
}


def pose(fold=0.0, sweep=0.0, spread=0.0, recoil=0.0, pitch=0.0, lift=0.0, scale=1.0):
    """Construct a complete pose compatible with the existing four-bone writer."""
    return dict(fold=fold, sweep=sweep, spread=spread, recoil=recoil,
                pitch=pitch, lift=lift, scale=scale)


def _suite(cruise, hit, windup, attack):
    return dict(cruise=cruise, hit=hit, windup=windup, attack=attack)


_ASSAULT_CHARGE = pose(fold=20, sweep=12, spread=-.12, recoil=-.22, pitch=-1.2)
_ASSAULT_RELEASE = pose(fold=24, sweep=15, spread=.24, recoil=.38, pitch=2.6)
_BULWARK_CHARGE = pose(fold=-14, sweep=-5, spread=.48, recoil=-.18, pitch=-.7)
_BULWARK_RELEASE = pose(fold=7, sweep=2, spread=.60, recoil=.34, pitch=1.5)
_TEMPEST_CHARGE = pose(fold=-18, sweep=14, spread=.34, recoil=-.16, pitch=-.6)
_TEMPEST_RELEASE = pose(fold=15, sweep=-12, spread=.48, recoil=.32, pitch=1.8)
_VOID_CHARGE = pose(fold=22, sweep=-10, spread=-.20, recoil=-.20, pitch=-1.0)
_VOID_RELEASE = pose(fold=-22, sweep=8, spread=.56, recoil=.28, pitch=1.2)
_CORE_CHARGE = pose(fold=-16, sweep=-8, spread=.50, recoil=-.30, pitch=-.5)
_CORE_RELEASE = pose(fold=18, sweep=6, spread=.22, recoil=.50, pitch=2.2)
_SECTION_CHARGE = pose(fold=12, sweep=7, spread=.08, recoil=-.10, pitch=-.5)
_SECTION_RELEASE = pose(fold=-8, sweep=-4, spread=.16, recoil=.18, pitch=1.1)


_CLIPS = {
    "assault": _suite(
        cruise=[
            (0, pose()), (.10, pose()),
            (.75, pose(fold=3, sweep=1.5)), (1.40, pose()),
            (2.10, pose(fold=-2, sweep=-.8)), (2.70, pose()), (2.80, pose()),
        ],
        hit=[
            (0, pose()), (.05, pose(fold=-2, recoil=.12, pitch=-2.2)),
            (.14, pose(sweep=1, recoil=-.03, pitch=.8)), (.28, pose()),
        ],
        windup=[
            (0, pose()), (.26, pose(fold=8, sweep=6, spread=-.05, recoil=-.10)),
            (.56, _ASSAULT_CHARGE), (.76, _ASSAULT_CHARGE),
        ],
        attack=[
            (0, _ASSAULT_CHARGE), (.08, _ASSAULT_RELEASE), (.16, _ASSAULT_RELEASE),
            (.32, pose(fold=-5, sweep=-4, spread=.08, recoil=-.07, pitch=-.8)),
            (.50, pose(fold=2, sweep=1)), (.64, pose()),
        ],
    ),
    "bulwark": _suite(
        cruise=[
            (0, pose()), (.16, pose()),
            (1.0, pose(fold=-2, spread=.055)), (1.80, pose()),
            (2.60, pose(fold=1, spread=-.025)), (3.44, pose()), (3.60, pose()),
        ],
        hit=[
            (0, pose()), (.07, pose(fold=1.5, spread=.05, recoil=.09, pitch=-1.1)),
            (.20, pose(fold=-.8, recoil=-.02, pitch=.45)), (.40, pose()),
        ],
        windup=[
            (0, pose()), (.30, pose(fold=-4, spread=.16, recoil=-.05)),
            (.78, _BULWARK_CHARGE), (1.02, _BULWARK_CHARGE),
        ],
        attack=[
            (0, _BULWARK_CHARGE), (.12, _BULWARK_RELEASE), (.24, _BULWARK_RELEASE),
            (.52, pose(fold=-5, sweep=-2, spread=.19, recoil=-.045, pitch=-.5)),
            (.76, pose(fold=1.5, spread=.045, recoil=.025)), (.96, pose()),
        ],
    ),
    "tempest": _suite(
        cruise=[
            (0, pose()), (.08, pose()),
            (.60, pose(fold=-3, sweep=3, spread=.04)), (1.20, pose()),
            (1.80, pose(fold=2, sweep=-2, spread=-.02)), (2.32, pose()), (2.40, pose()),
        ],
        hit=[
            (0, pose()), (.04, pose(fold=3, sweep=-2, recoil=.10, pitch=-1.8)),
            (.12, pose(fold=-1, sweep=1, recoil=-.03, pitch=.6)), (.25, pose()),
        ],
        windup=[
            (0, pose()), (.24, pose(fold=-5, sweep=5, spread=.10, recoil=-.04)),
            (.50, _TEMPEST_CHARGE), (.70, _TEMPEST_CHARGE),
        ],
        attack=[
            (0, _TEMPEST_CHARGE), (.07, _TEMPEST_RELEASE), (.15, _TEMPEST_RELEASE),
            (.28, pose(fold=-6, sweep=5, spread=.12, recoil=-.06, pitch=-.65)),
            (.42, pose(fold=2, sweep=-1.5, recoil=.025)), (.58, pose()),
        ],
    ),
    "void_harbinger": _suite(
        cruise=[
            (0, pose()), (.15, pose()),
            (1.10, pose(fold=3.5, sweep=-1, spread=-.05)), (2.10, pose()),
            (3.10, pose(fold=-4, sweep=1.5, spread=.075)), (4.05, pose()), (4.20, pose()),
        ],
        hit=[
            (0, pose()), (.06, pose(fold=4, spread=-.06, recoil=.08, pitch=-1.5)),
            (.18, pose(fold=-2, spread=.04, recoil=-.02, pitch=.55)), (.36, pose()),
        ],
        windup=[
            (0, pose()), (.34, pose(fold=7, sweep=-3, spread=-.07, recoil=-.07)),
            (.70, _VOID_CHARGE), (.96, _VOID_CHARGE),
        ],
        attack=[
            (0, _VOID_CHARGE), (.10, _VOID_RELEASE), (.20, _VOID_RELEASE),
            (.48, pose(fold=6, sweep=-3, spread=.12, recoil=-.05, pitch=-.4)),
            (.72, pose(fold=-2, sweep=1, spread=.035)), (.94, pose()),
        ],
    ),
    "tempest_core": _suite(
        cruise=[
            (0, pose()), (.12, pose()),
            (.82, pose(fold=-2.5, spread=.06, recoil=-.025)), (1.60, pose()),
            (2.38, pose(fold=1.5, spread=-.025, recoil=.015)), (3.08, pose()), (3.20, pose()),
        ],
        hit=[
            (0, pose()), (.06, pose(fold=2, recoil=.14, pitch=-1.6)),
            (.16, pose(fold=-1, recoil=-.04, pitch=.6)), (.32, pose()),
        ],
        windup=[
            (0, pose()), (.28, pose(fold=-5, sweep=-2, spread=.16, recoil=-.12)),
            (.64, _CORE_CHARGE), (.88, _CORE_CHARGE),
        ],
        attack=[
            (0, _CORE_CHARGE), (.09, _CORE_RELEASE), (.18, _CORE_RELEASE),
            (.38, pose(fold=-6, sweep=-3, spread=.10, recoil=-.10, pitch=-.7)),
            (.62, pose(fold=2, spread=.025, recoil=.035)), (.82, pose()),
        ],
    ),
    "section": _suite(
        cruise=[
            (0, pose()), (.08, pose()),
            (.50, pose(fold=2, sweep=1)), (1.0, pose()),
            (1.50, pose(fold=-1.5, sweep=-.75)), (1.92, pose()), (2.0, pose()),
        ],
        hit=[
            (0, pose()), (.04, pose(fold=-2, recoil=.06, pitch=-1.0)),
            (.11, pose(fold=.75, recoil=-.015, pitch=.4)), (.22, pose()),
        ],
        windup=[
            (0, pose()), (.20, pose(fold=4, sweep=3, spread=.025, recoil=-.04)),
            (.42, _SECTION_CHARGE), (.58, _SECTION_CHARGE),
        ],
        attack=[
            (0, _SECTION_CHARGE), (.06, _SECTION_RELEASE), (.13, _SECTION_RELEASE),
            (.24, pose(fold=3, sweep=2, spread=.035, recoil=-.04, pitch=-.35)),
            (.34, pose(fold=-1, recoil=.015)), (.46, pose()),
        ],
    ),
}


def clips(role):
    """Return independent key poses for one canonical role; reject misspellings."""
    if role not in _CLIPS:
        raise ValueError(f"Unknown voxel boss role {role!r}; expected one of {ROLES}")
    # Copy each key separately: repeated held poses and clip-boundary matches
    # must not alias one another when an author adjusts a returned timeline.
    return {clip: [(seconds, dict(values)) for seconds, values in keys]
            for clip, keys in _CLIPS[role].items()}


def validate_clips(role, animation_clips=None):
    """Check sampling keys and transition contracts; return a compact report.

    Raises ValueError with a role/clip/key location for invalid authored data.
    These analytic checks complement, rather than replace, a rendered review:
    they cannot detect mesh interpenetration or unreadable native-scale motion.
    """
    if role not in ROLES:
        raise ValueError(f"Unknown voxel boss role {role!r}")
    data = clips(role) if animation_clips is None else animation_clips

    def require(condition, message):
        if not condition:
            raise ValueError(f"{role}: {message}")

    require(set(data) == set(CLIP_NAMES), "must contain exactly cruise/hit/windup/attack")
    limits = dict(fold=24, sweep=15, spread=.60, recoil=.50, pitch=3)
    if role == "section":
        limits.update(fold=16, sweep=8, spread=.18, recoil=.18, pitch=1.5)
    for clip, keys in data.items():
        require(len(keys) >= 4, f"{clip} needs at least four keys")
        previous = -1.0
        for index, (seconds, values) in enumerate(keys):
            location = f"{clip}[{index}]"
            require(isinstance(seconds, (int, float)) and math.isfinite(seconds),
                    f"{location} time must be finite")
            require(seconds > previous, f"{location} time must strictly increase")
            require(set(values) == set(POSE_KEYS), f"{location} pose keys differ from key_pose contract")
            for parameter, value in values.items():
                require(isinstance(value, (int, float)) and math.isfinite(value),
                        f"{location}.{parameter} must be finite")
                if parameter in limits:
                    require(abs(value) <= limits[parameter] + 1e-9,
                            f"{location}.{parameter} exceeds approved motion envelope")
            require(values["lift"] == 0.0, f"{location} must keep body origin fixed")
            require(values["scale"] == 1.0, f"{location} must keep body scale fixed")
            previous = seconds
        require(keys[0][0] == 0.0, f"{clip} must start at time zero")
        require(any(values != keys[0][1] for _, values in keys[1:]), f"{clip} is static")

    neutral = pose()
    require(data["cruise"][0][1] == neutral == data["cruise"][-1][1],
            "cruise endpoints must be neutral")
    require(data["cruise"][1][1] == neutral == data["cruise"][-2][1],
            "cruise needs neutral seam handles for a quiet loop")
    require(data["hit"][0][1] == neutral == data["hit"][-1][1], "hit must return to neutral")
    require(data["windup"][0][1] == neutral, "windup must start neutral")
    require(data["windup"][-1][1] != neutral, "windup must anticipate the attack")
    require(data["windup"][-2][1] == data["windup"][-1][1], "windup must hold its peak")
    require(data["attack"][0][1] == data["windup"][-1][1], "attack must match the held windup pose")
    require(data["attack"][-1][1] == neutral, "attack must settle to neutral")
    require(data["attack"][1][1] == data["attack"][2][1], "release needs a readable impulse hold")
    require(data["attack"][2][0] - data["attack"][1][0] >= 2.0 / 30.0,
            "release hold must survive at least two 30 fps frames")
    require(data["attack"][3][1]["fold"] * data["attack"][1][1]["fold"] < 0,
            "attack needs a counter-fold overshoot before settling")
    return {
        "role": role,
        "valid": True,
        "notes": DESIGN_NOTES[role],
        "clips": {clip: {"seconds": keys[-1][0], "keys": len(keys)} for clip, keys in data.items()},
    }


def validate_all():
    """Validate every variant and ensure the fleet does not reuse one pose set."""
    reports = [validate_clips(role) for role in ROLES]
    signatures = {json.dumps(_CLIPS[role], sort_keys=True) for role in ROLES}
    if len(signatures) != len(ROLES):
        raise ValueError("Every voxel boss role needs its own motion identity")
    return {"valid": True, "roles": len(ROLES), "clips": len(ROLES) * len(CLIP_NAMES),
            "bones": list(BONES), "variants": reports}


if __name__ == "__main__":
    print(json.dumps(validate_all(), indent=2))
