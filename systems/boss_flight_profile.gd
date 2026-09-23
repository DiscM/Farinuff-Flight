@tool
extends Resource
class_name BossFlightProfile
## Flight tuning uses baseline screen pixels, independent of camera zoom.
## Drives BossMovementBrain's CHASE, STRAFE and DODGE mobility states.

@export var display_name: StringName = &"Command Hull"
@export_range(100.0, 400.0, 5.0) var cruise_speed := 220.0
@export_range(40.0, 1000.0, 5.0) var preferred_distance := 340.0
@export_range(0.0, 400.0, 5.0) var minimum_separation := 170.0
@export_range(2.0, 10.0, 0.1) var steering_response := 6.0
@export_group("Strafe ring")
@export_range(40.0, 300.0, 5.0) var strafe_tangential := 110.0
@export_range(0.0, 200.0, 5.0) var strafe_weave := 70.0
@export_group("Chase and dodge")
@export_range(1.0, 1.6, 0.01) var chase_surge := 1.12
@export_range(40.0, 400.0, 5.0) var dodge_distance := 130.0
@export_range(0.1, 1.0, 0.01) var dodge_seconds := 0.28
