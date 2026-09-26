@tool
extends Resource
class_name FlightSpace3DConfig
## Canonical combat scale for Expedition, Flight School and harbor combat.

const DEFAULT_PIXELS_PER_WORLD_UNIT := 15.0

@export_range(1.0, 64.0, 0.25) var pixels_per_world_unit: float = DEFAULT_PIXELS_PER_WORLD_UNIT
## Hulls, hitboxes and mounted parts share this scale without changing flight speeds.
@export_range(0.25, 6.0, 0.25) var enemy_scale_multiplier: float = 3.0
## Player cruise and boost share a multiplier while retaining their response times.
@export_range(0.25, 6.0, 0.25) var player_speed_multiplier: float = 3.0
## The stable top-down projection spans 220 world units vertically. The
## rendered camera shares the home port's angle and can orbit independently.
@export var baseline_viewport_size := Vector2i(5867, 3300)
@export_range(45.0, 90.0, 0.5) var camera_elevation_degrees: float = 90.0
@export_range(1.0, 512.0, 0.5) var camera_height: float = 252.0
@export_range(0.0, 512.0, 1.0) var spawn_margin_pixels: float = 80.0
@export_range(0.0, 512.0, 1.0) var despawn_margin_pixels: float = 140.0


func pixels_to_world(pixels: float) -> float:
	return pixels / pixels_per_world_unit


func get_orthogonal_size() -> float:
	var elevation_radians := deg_to_rad(camera_elevation_degrees)
	return pixels_to_world(float(baseline_viewport_size.y)) * sin(elevation_radians)


func get_camera_position() -> Vector3:
	var elevation_radians := deg_to_rad(camera_elevation_degrees)
	var camera_depth := camera_height / tan(elevation_radians)
	return Vector3(0.0, camera_height, camera_depth)
