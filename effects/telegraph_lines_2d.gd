extends RefCounted
## Screen-space strokes with world-anchored direction markers. Draw only the
## visible segment so a large boss arena never creates offscreen arrow geometry.
const DANGER := Color(1.0, 0.61, 0.24)
const BREAKER := Color(0.2, 0.9, 1.0)
const SAFE := Color(0.24, 0.95, 0.7)

static func draw_path(canvas: Node2D, start: Vector2, end: Vector2, tint: Color, progress: float, elapsed: float, fast: bool, scale: float) -> void:
	var clipped := _clip_segment(start, end, canvas.get_viewport_rect().grow(12.0 * scale))
	if clipped.is_empty():
		return
	var direction := (end - start).normalized()
	var length := clipped[0].distance_to(clipped[1])
	var strength := lerpf(0.25, 0.65, progress)
	_stroke(canvas, clipped[0], clipped[1], Color(0.015, 0.025, 0.04), 4.5 * scale, 0.5)
	_stroke(canvas, clipped[0], clipped[1], tint, 9.0 * scale, strength * 0.09)
	_stroke(canvas, clipped[0], clipped[1], tint, 4.0 * scale, strength * 0.2)
	_stroke(canvas, clipped[0], clipped[1], tint.lightened(progress * 0.25), 1.25 * scale, strength)
	var spacing := 150.0 * scale
	var flow := elapsed * (82.0 if fast else 42.0) * scale
	var offset := fposmod((start - clipped[0]).dot(direction) + flow, spacing)
	var normal := direction.orthogonal()
	for index in range(int(length / spacing) + 1):
		var distance := offset + index * spacing
		if distance > length:
			break
		var fade := clampf(minf(distance, length - distance) / (24.0 * scale), 0.0, 1.0)
		var tip := clipped[0] + direction * distance
		for echo in (2 if fast else 1):
			var point := tip - direction * echo * 7.0 * scale
			var arrow := PackedVector2Array([point - direction * 7.0 * scale + normal * 3.5 * scale, point, point - direction * 7.0 * scale - normal * 3.5 * scale])
			canvas.draw_polyline(arrow, _alpha(tint.lightened(0.25), (0.45 + progress * 0.4) * fade), 1.4 * scale, true)

static func draw_route(canvas: Node2D, start: Vector2, end: Vector2, scale: float) -> void:
	var clipped := _clip_segment(start, end, canvas.get_viewport_rect().grow(16.0 * scale))
	if clipped.is_empty():
		return
	var normal := (end - start).normalized().orthogonal()
	_stroke(canvas, clipped[0], clipped[1], SAFE, 22.0 * scale, 0.035)
	for side in [-1.0, 1.0]:
		var offset: Vector2 = normal * side * 11.0 * scale
		_stroke(canvas, clipped[0] + offset, clipped[1] + offset, SAFE, 4.0 * scale, 0.06)
		_stroke(canvas, clipped[0] + offset, clipped[1] + offset, SAFE, 1.1 * scale, 0.48)

static func draw_marker(canvas: Node2D, center: Vector2, progress: float, scale: float) -> void:
	if not canvas.get_viewport_rect().grow(50.0 * scale).has_point(center):
		return
	var radius := 34.0 * scale
	canvas.draw_circle(center, radius, _alpha(DANGER, 0.035 + progress * 0.04), true, -1.0, true)
	canvas.draw_arc(center, radius, 0.0, TAU, 80, _alpha(DANGER, 0.12), 7.0 * scale, true)
	canvas.draw_arc(center, radius, 0.0, TAU, 80, _alpha(DANGER, 0.24), 1.0 * scale, true)
	if progress > 0.001:
		canvas.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + progress * TAU, 80, _alpha(DANGER.lightened(0.3), 0.85), 2.0 * scale, true)
	for index in 4:
		var angle := index * PI * 0.5
		var direction := Vector2.from_angle(angle)
		canvas.draw_line(center + direction * 39.0 * scale, center + direction * 45.0 * scale, _alpha(DANGER, 0.7), 1.5 * scale, true)
		canvas.draw_arc(center, 23.0 * scale, angle + 0.15, angle + 0.6, 12, _alpha(DANGER, 0.35), 1.0 * scale, true)
	canvas.draw_line(center - Vector2(5, 0) * scale, center + Vector2(5, 0) * scale, _alpha(DANGER, 0.7), 1.0 * scale, true)
	canvas.draw_line(center - Vector2(0, 5) * scale, center + Vector2(0, 5) * scale, _alpha(DANGER, 0.7), 1.0 * scale, true)

static func _stroke(canvas: Node2D, start: Vector2, end: Vector2, tint: Color, width: float, opacity: float) -> void:
	var inset := minf(0.12, 32.0 / maxf(start.distance_to(end), 1.0))
	var points := PackedVector2Array([start, start.lerp(end, inset), start.lerp(end, 1.0 - inset), end])
	var colors := PackedColorArray([_alpha(tint, 0.0), _alpha(tint, opacity), _alpha(tint, opacity), _alpha(tint, 0.0)])
	canvas.draw_polyline_colors(points, colors, width, true)

static func _alpha(tint: Color, opacity: float) -> Color:
	return Color(tint.r, tint.g, tint.b, opacity)

static func _clip_segment(start: Vector2, end: Vector2, bounds: Rect2) -> PackedVector2Array:
	var delta := end - start
	if delta.length_squared() < 1.0:
		return PackedVector2Array()
	var near := 0.0
	var far := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.0001:
			if start[axis] < bounds.position[axis] or start[axis] > bounds.end[axis]:
				return PackedVector2Array()
			continue
		var first := (bounds.position[axis] - start[axis]) / delta[axis]
		var last := (bounds.end[axis] - start[axis]) / delta[axis]
		near = maxf(near, minf(first, last))
		far = minf(far, maxf(first, last))
		if near >= far:
			return PackedVector2Array()
	return PackedVector2Array([start + delta * near, start + delta * far])
