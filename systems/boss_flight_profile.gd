@tool
extends Resource
class_name BossFlightProfile
## Flight tuning uses baseline screen pixels, independent of camera zoom.
## INTERCEPT, WITHDRAW and REENTER also serve as tactical overrides.

enum Maneuver { INTERCEPT, FLANK, ORBIT, WEAVE, FIGURE_EIGHT, WITHDRAW, REENTER }

@export var display_name: StringName = &"Command Hull"
@export_range(100.0, 400.0, 5.0) var cruise_speed := 220.0
@export_range(250.0, 500.0, 5.0) var preferred_distance := 340.0
@export_range(0.0, 1.0, 0.05) var lead_seconds := 0.4
@export_range(0.0, 160.0, 5.0) var maximum_lead := 110.0
@export_range(2.0, 10.0, 0.1) var steering_response := 6.0
@export_range(2.0, 6.0, 0.1) var maneuver_seconds := 3.0
@export_range(60.0, 150.0, 5.0) var pattern_amplitude := 100.0
@export var sequence: Array[Maneuver] = [Maneuver.FLANK, Maneuver.ORBIT, Maneuver.WEAVE, Maneuver.WITHDRAW]
