extends Node2D
class_name DroneEscort3DReviewGuides
## Review-only projection of the native Drone Escort's primitive hitbox and
## wrapper-owned sockets. The guides never participate in gameplay collision.

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PlayerDrone := preload("res://entities/player/player_drone_3d.gd")

var show_hitbox := true
var show_sockets := false
var _flight_space: FlightSpace


func configure(flight_space: FlightSpace) -> void:
	_flight_space = flight_space


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _flight_space == null:
		return
	var drone := get_tree().get_first_node_in_group(&"native_3d_player_drone") as PlayerDrone
	if drone == null or not drone.is_active:
		return
	if show_hitbox:
		_draw_hitbox(drone)
	if show_sockets:
		_draw_sockets(drone)


func _draw_hitbox(drone: PlayerDrone) -> void:
	var sphere := drone.collision_shape.shape as SphereShape3D
	if sphere == null:
		return
	var points := PackedVector2Array()
	for index in range(33):
		var angle := TAU * float(index) / 32.0
		var world_point := drone.collision_shape.global_transform * Vector3(
			cos(angle) * sphere.radius, 0.0, sin(angle) * sphere.radius
		)
		points.append(_flight_space.combat_to_screen(world_point))
	draw_polyline(points, Color(0.25, 1.0, 0.72, 0.86), 1.5, true)


func _draw_sockets(drone: PlayerDrone) -> void:
	for socket in drone.sockets.get_children():
		if not socket is Marker3D:
			continue
		var marker := socket as Marker3D
		var point := _flight_space.active_camera.unproject_position(marker.global_position)
		draw_circle(point, 2.5, Color(1.0, 0.78, 0.2))
		draw_string(
			ThemeDB.fallback_font,
			point + Vector2(5.0, -4.0),
			marker.name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			10,
			Color(1.0, 0.92, 0.65)
		)
