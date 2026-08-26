# Farinuff Flight Context

This glossary defines the shared language for the game's flight space and combat actors during the transition to native 3D flight.

## Flight and combat

**Top-down 3D**:
A three-dimensional presentation of top-down combat in which craft navigate a horizontal combat plane; depth supports model form, lighting, effects, and layered presentation rather than free-flight maneuvering.
_Avoid_: 2.5D (for the target runtime), free-flight 3D

**Combat Plane**:
The bounded horizontal space in which the player craft and enemy craft move, collide, and exchange attacks.
_Avoid_: screen, camera plane

**Vertical Maneuvering**:
Player- or enemy-controlled movement through the vertical dimension of the flight space; this is outside the scope of the first Top-down 3D version.
_Avoid_: altitude control, free-flight movement

**Projectile**:
A traveling attack launched by a craft or encounter hazard that may damage, be deflected, or trigger an impact effect.
_Avoid_: shot as a category, ordnance unless referring to a non-projectile hazard

**Interaction Range**:
The distance from the player craft within which an incoming projectile can affect the player or be actively responded to.
_Avoid_: draw range, camera range

**Backdrop**:
The non-interactive visual field behind the combat plane, including stars, nebulae, and foreground celestial scenery.
_Avoid_: arena, combat world

**Run Behavior**:
The observable rules and tuning that shape a run, including movement, enemy patterns, attacks, damage, upgrades, and encounter timing.
_Avoid_: visual behavior, implementation parity

**Gameplay Hitbox**:
The simplified contact envelope used to determine whether a craft or projectile can affect another combatant; it does not need to match the craft's visible silhouette exactly.
_Avoid_: model collision, render collision

**Player Craft**:
The ship controlled by the player during a run.
_Avoid_: player sprite, player body

**Enemy Craft**:
A hostile ship that participates in an encounter and can attack or be destroyed by the player craft.
_Avoid_: enemy sprite, enemy body
