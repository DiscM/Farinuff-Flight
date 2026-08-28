extends Node
class_name FlightSpace3D
## Stateless adapter between viewport coordinates and the Y=0 Combat Plane.

const FlightConfig := preload("res://systems/flight_space_3d_config.gd")
const COMBAT_PLANE := Plane(Vector3.UP, 0.0)

@export_node_path("Camera3D") var active_camera_path: NodePath
@export_node_path("Camera3D") var stable_camera_path: NodePath
@export var configuration: FlightConfig

@onready var active_camera: Camera3D = get_node_or_null(active_camera_path) as Camera3D
@onready var stable_camera: Camera3D = get_node_or_null(stable_camera_path) as Camera3D


func _ready() -> void:
	if active_camera == null:
		push_error("FlightSpace3D requires the active Camera3D reference")
	if stable_camera == null:
		push_error("FlightSpace3D requires the stable Camera3D reference")
	if configuration == null:
		push_error("FlightSpace3D requires a FlightSpace3DConfig resource")


## Projects a viewport position through the rendered gameplay camera and onto
## the Combat Plane. The returned world position always has Y=0.
func screen_to_combat_plane(screen_position: Vector2) -> Vector3:
	return _screen_to_combat_plane(active_camera, screen_position)


func _screen_to_combat_plane(source_camera: Camera3D, screen_position: Vector2) -> Vector3:
	if source_camera == null:
		return Vector3.ZERO
	var ray_origin := source_camera.project_ray_origin(screen_position)
	var ray_direction := source_camera.project_ray_normal(screen_position)
	var intersection: Variant = COMBAT_PLANE.intersects_ray(ray_origin, ray_direction)
	if typeof(intersection) != TYPE_VECTOR3:
		return Vector3.ZERO
	var combat_position: Vector3 = intersection
	combat_position.y = 0.0
	return combat_position


## Converts the existing screen-oriented input convention (right=+X,
## down=+Y) into a world direction, including camera foreshortening.
func input_to_combat_direction(input_direction: Vector2) -> Vector3:
	return screen_motion_to_combat(input_direction).normalized()


## Converts screen-equivalent tuning/input vectors without casting a ray.
## Unlike a direction, this preserves analog magnitude, speed, and distance.
## The baseline vertical span is fixed, so resizing never changes world speed.
func screen_motion_to_combat(screen_motion: Vector2) -> Vector3:
	if stable_camera == null or configuration == null:
		return Vector3.ZERO
	return _screen_motion_basis() * Vector3(screen_motion.x, 0.0, screen_motion.y)


func combat_motion_to_screen(combat_motion: Vector3) -> Vector2:
	if stable_camera == null or configuration == null:
		return Vector2.ZERO
	var motion := _screen_motion_basis().inverse() * combat_motion
	return Vector2(motion.x, motion.z)


func _screen_motion_basis() -> Basis:
	var camera_right := stable_camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var camera_down := stable_camera.global_basis.z
	camera_down.y = 0.0
	camera_down = camera_down.normalized()
	var units_per_pixel := stable_camera.size / float(configuration.baseline_viewport_size.y)
	var foreshortening := absf(stable_camera.global_basis.y.dot(camera_down))
	return Basis(
		camera_right * units_per_pixel,
		Vector3.UP,
		camera_down * (units_per_pixel / maxf(foreshortening, 0.001))
	)


func combat_to_screen(combat_position: Vector3) -> Vector2:
	if active_camera == null:
		return Vector2.ZERO
	combat_position.y = 0.0
	return active_camera.unproject_position(combat_position)


## Returns camera-derived bounds in X/Z coordinates. A positive baseline-pixel
## margin expands the rectangle for off-plane spawning and despawning. Scale
## that margin with viewport height so its world-space distance stays fixed.
func get_combat_bounds(baseline_margin_pixels: float = 0.0) -> Rect2:
	if stable_camera == null or configuration == null:
		return Rect2()
	var viewport_rect := stable_camera.get_viewport().get_visible_rect()
	var pixel_scale := viewport_rect.size.y / float(configuration.baseline_viewport_size.y)
	var margin := Vector2.ONE * baseline_margin_pixels * pixel_scale
	var screen_min := viewport_rect.position - margin
	var screen_max := viewport_rect.position + viewport_rect.size + margin
	var screen_corners: Array[Vector2] = [
		screen_min,
		Vector2(screen_max.x, screen_min.y),
		screen_max,
		Vector2(screen_min.x, screen_max.y),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for screen_corner in screen_corners:
		var world_corner := _screen_to_combat_plane(stable_camera, screen_corner)
		var combat_corner := Vector2(world_corner.x, world_corner.z)
		minimum = minimum.min(combat_corner)
		maximum = maximum.max(combat_corner)
	return Rect2(minimum, maximum - minimum)


func clamp_to_combat_plane(combat_position: Vector3) -> Vector3:
	var bounds := get_combat_bounds()
	combat_position.x = clampf(combat_position.x, bounds.position.x, bounds.end.x)
	combat_position.y = 0.0
	combat_position.z = clampf(combat_position.z, bounds.position.y, bounds.end.y)
	return combat_position
