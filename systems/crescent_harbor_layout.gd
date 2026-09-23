extends RefCounted
## Rest-pose navigation envelopes for the authored Crescent Harbor GLB.
## GLB coordinates are already Godot Y-up: Blender (x,y,z) becomes (x,z,-y).
## The pilot flies above the decks; only structures reaching that layer block it.

const STATION_SCALE := 2.0
const SOURCE_FLIGHT_HEIGHT := 11.5
const FLIGHT_Y := 0.0
const MODEL_OFFSET := Vector3(0.0, -23.0, 0.0)
const FLIGHT_CENTER := Vector3(8.0, 0.0, -20.0)
const FLIGHT_RADIUS := 205.0
const DOCK_POSITION := Vector3(-14.4, 0.0, 160.0)
const INITIAL_POSITION := Vector3(-10.0, 0.0, 167.0)
const CAMERA_TARGET := Vector3(6.4, -11.0, -24.8)
const CORE_CENTER := Vector3(-14.4, 0.0, 60.8)
const CORE_RADIUS := 27.0
## Three source units include the pilot half-span and orbital correction sweep.
const CLEARANCE := 3.0
const EDGE_EPSILON := 0.025
const SOURCE_CORE_CENTER := Vector2(-7.2, 30.4)
const SOURCE_CORE_RADIUS := 10.5

## Separate envelopes preserve the basin and the openings between ring modules.
## Rect2 uses GLB X/Z coordinates before the uniform scene scale.
const SOURCE_RECTS: Array[Rect2] = [
	# Eight inhabited neighborhoods on the main ring.
	Rect2(13.95, 15.8, 8.4, 8.4),
	Rect2(-1.0, 0.85, 8.4, 8.4),
	Rect2(-21.8, 0.85, 8.4, 8.4),
	Rect2(-36.75, 15.8, 8.4, 8.4),
	Rect2(-36.75, 36.6, 8.4, 8.4),
	Rect2(-21.8, 51.55, 8.4, 8.4),
	Rect2(-1.0, 51.55, 8.4, 8.4),
	Rect2(13.95, 36.6, 8.4, 8.4),
	# Glazed gardens and the rear loading platform.
	Rect2(-39.2, 24.2, 6.8, 12.4),
	Rect2(-4.3, 54.95, 12.4, 6.8),
	Rect2(-16.0, -13.2, 17.6, 14.4),
	# Front apron lamp posts; the launch approach remains open between them.
	Rect2(-14.85, 76.55, 1.45, 0.85),
	Rect2(-1.0, 76.55, 1.45, 0.85),
	# Separate relay footprints, including equipment and orbital motion margin.
	Rect2(-60.04, -7.68, 12.08, 11.61), # Traffic beacon / flight school.
	Rect2(-49.53, -43.87, 21.86, 19.06), # Power distribution / settings.
	Rect2(-19.09, -76.51, 29.78, 21.82), # Cargo exchange / archives.
	Rect2(25.25, -68.95, 14.35, 14.54), # Port approach / route map.
	Rect2(46.36, -39.20, 26.48, 23.96), # Refuel and repair / hangar.
]


static func source_to_world(point: Vector3) -> Vector3:
	return point * STATION_SCALE + MODEL_OFFSET


static func is_clear(point: Vector3) -> bool:
	if absf(point.y - FLIGHT_Y) > 0.001:
		return false
	var flat := Vector2(point.x, point.z)
	if flat.distance_to(Vector2(FLIGHT_CENTER.x, FLIGHT_CENTER.z)) > FLIGHT_RADIUS + 0.001:
		return false
	return _source_is_clear(flat / STATION_SCALE)


static func _source_is_clear(point: Vector2) -> bool:
	if point.distance_to(SOURCE_CORE_CENTER) < SOURCE_CORE_RADIUS + CLEARANCE:
		return false
	for rectangle in SOURCE_RECTS:
		if rectangle.grow(CLEARANCE).has_point(point):
			return false
	return true


static func constrain(point: Vector3) -> Vector3:
	var center := Vector2(FLIGHT_CENTER.x, FLIGHT_CENTER.z)
	var flat := center + (Vector2(point.x, point.z) - center).limit_length(FLIGHT_RADIUS)
	var source := flat / STATION_SCALE
	if _source_is_clear(source):
		return Vector3(flat.x, FLIGHT_Y, flat.y)
	var candidates: Array[Vector2] = []
	var core_offset := source - SOURCE_CORE_CENTER
	if core_offset.length() < SOURCE_CORE_RADIUS + CLEARANCE:
		var normal := core_offset.normalized() if core_offset.length() > 0.001 else Vector2.DOWN
		candidates.append(SOURCE_CORE_CENTER + normal * (SOURCE_CORE_RADIUS + CLEARANCE + EDGE_EPSILON))
		for index in 16:
			var angle := float(index) * TAU / 16.0
			candidates.append(SOURCE_CORE_CENTER + Vector2(cos(angle), sin(angle)) * (SOURCE_CORE_RADIUS + CLEARANCE + EDGE_EPSILON))
	for rectangle in SOURCE_RECTS:
		var padded := rectangle.grow(CLEARANCE)
		if not padded.has_point(source):
			continue
		var outer := padded.grow(EDGE_EPSILON)
		var clamped := source.clamp(outer.position, outer.end)
		candidates.append(Vector2(outer.position.x, clamped.y))
		candidates.append(Vector2(outer.end.x, clamped.y))
		candidates.append(Vector2(clamped.x, outer.position.y))
		candidates.append(Vector2(clamped.x, outer.end.y))
		for x in [outer.position.x, outer.end.x]:
			for z in [outer.position.y, outer.end.y]:
				candidates.append(Vector2(x, z))
	var best := source
	var best_distance := INF
	for candidate in candidates:
		if not _source_is_clear(candidate):
			continue
		var distance := candidate.distance_squared_to(source)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	# Connected garden/housing envelopes can cover each other's nearest edges.
	# Their corners normally resolve this; radial search handles arbitrary spawns.
	if is_inf(best_distance):
		for radius in range(1, 81):
			for index in 32:
				var angle := float(index) * TAU / 32.0
				var candidate := source + Vector2(cos(angle), sin(angle)) * float(radius)
				if _source_is_clear(candidate):
					best = candidate
					best_distance = 0.0
					break
			if not is_inf(best_distance):
				break
	return Vector3(best.x * STATION_SCALE, FLIGHT_Y, best.y * STATION_SCALE)


static func blockers() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"center": CORE_CENTER, "radius": CORE_RADIUS, "kind": &"circle"}]
	for rectangle in SOURCE_RECTS:
		var padded := rectangle.grow(CLEARANCE)
		var center := padded.get_center() * STATION_SCALE
		result.append({"center": Vector3(center.x, FLIGHT_Y, center.y),
			"half_extents": padded.size * STATION_SCALE * 0.5, "kind": &"rectangle"})
	return result
