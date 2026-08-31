# Implementation Profiles

These profiles describe how a target engine or platform realizes the portable specification. They are not alternate GDDs.

Each profile should answer:

- What owns simulation state?
- How are portable actions mapped to devices?
- How are entities, collisions, timers, pooling, and randomness represented?
- How are UI, audio, visual effects, and assets integrated?
- How are saves, tests, profiling, and exports handled?
- Which differences from the portable contract are intentional?

The Godot profiles contain observations from this repository. Unity, Unreal, and Web profiles are starting templates for future ports, not claims that those implementations already exist.

## Profiles

- [Profile template](profile-template.md)
- [Godot 2D](godot-2d.md)
- [Godot native 3D](godot-native-3d.md)
- [Unity](unity.md)
- [Unreal](unreal.md)
- [Web](web.md)
- [Porting checklist](porting-checklist.md)
