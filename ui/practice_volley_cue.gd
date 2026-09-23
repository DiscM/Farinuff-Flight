extends Node2D
## A quiet, shape-based preview of the next training volley.
var flight_space: FlightSpace3D
var origins: Array[Vector3] = []
var target := Vector3.ZERO
var remaining := 0.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if flight_space == null or remaining <= 0.0:
		return
	for origin in origins:
		var point := flight_space.combat_to_screen(origin)
		var direction := point.direction_to(flight_space.combat_to_screen(target))
		var side := direction.orthogonal()
		var color := Color(1.0, 0.35, 0.55, 0.85)
		draw_arc(point, 4.0 + remaining * 3.0, 0, TAU, 24, color, 1.5, true)
		draw_polyline(PackedVector2Array([
			point - direction * 4.0 + side * 4.0,
			point + direction * 3.0,
			point - direction * 4.0 - side * 4.0,
		]), color, 1.5, true)
