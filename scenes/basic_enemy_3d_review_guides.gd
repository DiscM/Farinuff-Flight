extends Node2D
class_name BasicEnemy3DReviewGuides
## Review-only projection of the real primitive hitboxes and wrapper sockets.

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const CORNERS := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]

var show_hitboxes := true
var show_sockets := false
var _flight_space: FlightSpace
var _enemies: Array[BasicEnemy] = []


func configure(flight_space: FlightSpace, enemies: Array[BasicEnemy]) -> void:
	_flight_space = flight_space
	_enemies = enemies


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _flight_space == null:
		return
	for enemy in _enemies:
		if not is_instance_valid(enemy) or not enemy.is_active:
			continue
		if show_hitboxes:
			var collision := enemy.collision_shape
			var half_size := (collision.shape as BoxShape3D).size * 0.5
			var outline := PackedVector2Array()
			for corner: Vector2 in CORNERS:
				var point := collision.global_transform * Vector3(corner.x * half_size.x, 0.0, corner.y * half_size.z)
				outline.append(_flight_space.combat_to_screen(point))
			draw_polyline(outline, Color(1.0, 0.55, 0.2, 0.75), 1.0, true)
		if show_sockets:
			for marker in enemy.get_socket_markers():
				var point := _flight_space.active_camera.unproject_position(marker.global_position)
				draw_circle(point, 2.5, Color(0.35, 1.0, 0.85))
				draw_string(ThemeDB.fallback_font, point + Vector2(5, -4), marker.name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.7, 1.0, 0.9))
