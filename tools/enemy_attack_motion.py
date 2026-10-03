"""Attack-specific rigid poses, Blender +Y forward/+Z up; no gameplay motion.

Each tuple is (fold, sweep, spread, weapon recoil, body pitch). Boss families
have authored neutral→brace→release→settle sequences and role-specific poses.
The four-bone contract and central datum stay fixed. All windups hold their
last pose and releases start there, so runtime warning durations can stretch.
"""


def pose(values=(0, 0, 0, 0, 0)):
    fold, sweep, spread, recoil, pitch = values
    return dict(fold=fold, sweep=sweep, spread=spread, recoil=recoil,
                pitch=pitch, lift=0.0, scale=1.0)


def scaled(values, fraction):
    return tuple(value * fraction for value in values)


def pair(prefix, brace, impulse, seconds=.7):
    return {
        prefix + "_windup": [(0, pose()), (.3, pose(scaled(brace, .4))),
                              (.7, pose(brace)), (1.0, pose(brace))],
        prefix + "_attack": [(0, pose(brace)), (2/30, pose(impulse)),
                              (5/30, pose(impulse)), (seconds*.6, pose(scaled(impulse, -.2))),
                              (seconds, pose())],
    }


# charge: aerodynamic lock; slam: wide brace and downward plate impact;
# volley: open weapon banks; alternate: reverse vane/crown sweep.
BOSS_POSES = {
    "assault": {
        "charge": ((24, 15, -.12, -.18, -1.0), (18, 12, .08, .24, 2.5)),
        "slam": ((-12, -4, .34, -.12, -2.5), (20, 5, .18, .32, 2.8)),
        "volley": ((-8, 5, .28, -.24, -.4), (10, -4, .36, .42, 1.0)),
        "alternate": ((12, -14, .12, -.2, -.5), (-18, 12, .42, .34, 1.8)),
    },
    "bulwark": {
        "charge": ((16, 8, -.1, -.08, -.7), (12, 6, .12, .18, 1.8)),
        "slam": ((-14, -5, .55, -.15, -1.8), (18, 4, .4, .3, 2.0)),
        "volley": ((-10, -3, .48, -.22, -.3), (7, 2, .6, .34, 1.2)),
        "alternate": ((-8, 12, .36, -.15, -.6), (14, -10, .54, .32, 1.4)),
    },
    "tempest": {
        "charge": ((20, 14, -.05, -.12, -1.3), (16, 12, .16, .25, 2.0)),
        "slam": ((-20, 6, .42, -.12, -2), (16, -6, .3, .32, 2.5)),
        "volley": ((-18, 14, .34, -.16, -.6), (15, -12, .48, .32, 1.8)),
        "alternate": ((18, -14, .28, -.18, -.6), (-20, 14, .46, .36, 1.6)),
    },
    "void_harbinger": {
        "charge": ((22, -10, -.2, -.2, -1), (16, -6, .1, .22, 1.4)),
        "slam": ((-22, 8, .52, -.15, -1.6), (22, -8, .24, .28, 1.8)),
        "volley": ((22, -10, -.2, -.2, -1), (-22, 8, .56, .28, 1.2)),
        "alternate": ((-20, -12, .46, -.18, -.6), (20, 12, -.12, .3, 1.5)),
    },
    "tempest_core": {
        "charge": ((20, 8, -.08, -.3, -.8), (12, 5, .18, .4, 1.8)),
        "slam": ((-20, -6, .5, -.25, -1.8), (22, 6, .26, .45, 2.2)),
        "volley": ((-16, -8, .5, -.3, -.5), (18, 6, .22, .5, 2.2)),
        "alternate": ((18, 12, .2, -.28, -.6), (-20, -12, .55, .46, 1.8)),
    },
    "section": {
        "charge": ((14, 7, -.03, -.08, -.5), (10, 5, .06, .14, 1)),
        "slam": ((-12, 4, .12, -.06, -.8), (14, -4, .08, .14, 1.2)),
        "volley": ((12, 7, .08, -.1, -.5), (-8, -4, .16, .18, 1.1)),
        "alternate": ((-10, -7, .1, -.08, -.5), (12, 7, .14, .16, 1)),
    },
}


def boss_clips(role):
    data = {}
    duration = {"assault": .65, "bulwark": .95, "tempest": .6,
                "void_harbinger": .9, "tempest_core": .8, "section": .5}[role]
    for family, (brace, impulse) in BOSS_POSES[role].items():
        data.update(pair(family, brace, impulse, duration))
    # Reactors expose/open, then seal; a visible change in combat phase.
    brace, impulse = BOSS_POSES[role]["alternate"]
    data["phase_shift"] = [(0, pose()), (.25, pose(scaled(brace, .6))),
                           (.55, pose(impulse)), (.85, pose(scaled(impulse, .35))),
                           (1.1, pose())]
    return data


REGULAR_POSES = {
    "basic": ("charge", (22, 14, -.06, -.08, -1.2), (28, 18, .1, .15, 2.8)),
    "fast": ("phase", (28, 16, -.08, -.06, -.8), (-24, -16, .18, .15, 1.8)),
    "bomber": ("deploy", (-22, -4, .2, -.12, -1.0), (-28, 6, .28, .16, 1.4)),
    "tank": ("radial", (-12, -6, .24, -.15, -.5), (8, 8, .34, .26, 1.2)),
    "sniper": ("rail", (-14, 2, .18, -.26, -.6), (8, -2, .08, .5, 2)),
}


def regular_clips(role):
    prefix, brace, impulse = REGULAR_POSES[role]
    return pair(prefix, brace, impulse, .55 if role == "tank" else .5)
