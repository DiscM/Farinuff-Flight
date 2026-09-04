extends Node2D
class_name TankArmor3DReviewGuides
## Review-only projection of the Tank hull and native armor-plate hitboxes.

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const TankEnemy := preload("res://entities/enemies/tank_enemy_3d.gd")
const CORNERS := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]

var show_hitboxes := true
var show_sockets := false
var _flight_space: FlightSpace
var _tanks: Array[TankEnemy] = []


func configure(flight_space: FlightSpace, tanks: Array[TankEnemy]) -> void:
	_flight_space = flight_space
	_tanks = tanks


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _flight_space == null:
		return
	for tank in _tanks:
		if not is_instance_valid(tank) or not tank.is_active:
			continue
		if show_hitboxes:
			_draw_box(tank.collision_shape, Color(1.0, 0.55, 0.2, 0.8), 1.0)
			for plate in tank.get_armor_plates():
				if is_instance_valid(plate) and plate.is_active:
					_draw_box(plate.collision_shape, Color(0.45, 0.95, 1.0, 0.9), 1.5)
		if show_sockets:
			for marker in tank.get_socket_markers():
				var point := _flight_space.active_camera.unproject_position(marker.global_position)
				draw_circle(point, 2.5, Color(0.7, 1.0, 0.9))
				draw_string(
					ThemeDB.fallback_font,
					point + Vector2(5, -4),
					marker.name,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					10,
					Color(0.7, 1.0, 0.9)
				)


func _draw_box(collision: CollisionShape3D, color: Color, width: float) -> void:
	if collision == null or not collision.shape is BoxShape3D:
		return
	var shape := collision.shape as BoxShape3D
	var half_size := shape.size * 0.5
	var outline := PackedVector2Array()
	for corner: Vector2 in CORNERS:
		var point := collision.global_transform * Vector3(corner.x * half_size.x, 0.0, corner.y * half_size.z)
		outline.append(_flight_space.combat_to_screen(point))
	draw_polyline(outline, color, width, true)
