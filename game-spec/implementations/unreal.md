# Implementation Profile: Unreal Engine

Status: porting template; not implemented in this repository

## Recommended mapping

- Simulation: a gameplay module in C++ or engine-independent data/model code; keep Actor presentation thin.
- Entity presentation: Actors and Components for Player Craft, Enemy Craft, Projectiles, hazards, and pickups.
- Content data: DataTables or Primary Data Assets generated from the portable catalogs.
- Identity and state: Gameplay Tags for portable IDs and state transitions where useful.
- Input: Enhanced Input actions named after the portable action map.
- UI: UMG for HUD, menus, popups, and accessibility-sensitive text.
- Effects: Niagara and MetaSounds/Audio Components connected to stable event IDs.
- Persistence: versioned `SaveGame` data plus an explicit backup/recovery path.
- Tests: Automation Framework scenarios with a deterministic seed and functional level tests for presentation flows.

## Port-specific decisions to record

- 2D orthographic or top-down 3D camera
- Actor/component ownership and replication policy if multiplayer is ever added
- Data Asset generation and hot-reload workflow
- Collision channels and dedicated Gameplay Hitbox components
- Pooling strategy for Projectiles, hazards, and effects
- Packaging and target hardware budgets

Do not make Gameplay Tags, Actor names, or Blueprint paths the only definition of a portable content ID.
