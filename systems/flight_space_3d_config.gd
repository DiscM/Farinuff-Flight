@tool
extends Resource
class_name FlightSpace3DConfig
## Shared scale, framing, and margin configuration for the native Combat Plane.

const DEFAULT_PIXELS_PER_WORLD_UNIT := 11.0

@export_range(1.0, 64.0, 0.25) var pixels_per_world_unit: float = DEFAULT_PIXELS_PER_WORLD_UNIT
@export var baseline_viewport_size := Vector2i(1280, 720)
@export_range(45.0, 89.0, 0.5) var camera_elevation_degrees: float = 70.0
@export_range(1.0, 200.0, 0.5) var camera_height: float = 52.0
@export_range(0.0, 512.0, 1.0) var spawn_margin_pixels: float = 80.0
@export_range(0.0, 512.0, 1.0) var despawn_margin_pixels: float = 140.0


func pixels_to_world(pixels: float) -> float:
	return pixels / pixels_per_world_unit


func world_to_pixels(world_units: float) -> float:
	return world_units * pixels_per_world_unit


## Preserves the baseline's vertical Combat Plane span after accounting for
## foreshortening from the near-top-down camera elevation.
func get_orthogonal_size() -> float:
	var elevation_radians := deg_to_rad(camera_elevation_degrees)
	return pixels_to_world(float(baseline_viewport_size.y)) * sin(elevation_radians)


func get_camera_position() -> Vector3:
	var elevation_radians := deg_to_rad(camera_elevation_degrees)
	var camera_depth := camera_height / tan(elevation_radians)
	return Vector3(0.0, camera_height, camera_depth)
