extends MeshInstance3D
## Compact nozzle jets and two bounded world-space histories share one surface.
## The jets stay attached while the ribbon wake preserves drift through turns.

const MAX_SAMPLES := 28
const SHADER := preload("res://effects/shaders/frontier_ribbon_3d.gdshader")
var _geometry := ImmediateMesh.new()
var _sockets: Array[Node3D] = []
var _left: Array[Vector3] = []
var _right: Array[Vector3] = []
var _power := 0.2
var _reflection := 0.0
var _ignition := 0.0
var _elapsed := 0.0
var _was_boosting := false


func configure(left: Node3D, right: Node3D) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_sockets.assign([left, right])
	mesh = _geometry
	var ribbon_material := ShaderMaterial.new()
	ribbon_material.shader = SHADER
	material_override = ribbon_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Geometry vertices are world-space; the actual mesh AABB is rebuilt each tick.
	reset()


func reset() -> void:
	_left.clear()
	_right.clear()
	_geometry.clear_surfaces()
	_power = 0.2
	_reflection = 0.0
	_ignition = 0.0
	_elapsed = 0.0
	_was_boosting = false


func reflect() -> void:
	_reflection = 1.0


func ignite() -> void:
	# Called for every boost, including a chained boost that never leaves thrust.
	_ignition = 1.0


func advance(delta: float, speed_fraction: float, boosting: bool, active: bool) -> void:
	if _sockets.size() != 2:
		return
	if not active:
		reset()
		return
	_elapsed += delta
	_ignition = maxf(0.0, _ignition - delta * 5.5)
	if boosting and not _was_boosting:
		ignite()
	_was_boosting = boosting
	_reflection = maxf(0.0, _reflection - delta * 5.0)
	_power = lerpf(_power, 1.0 if boosting else 0.2 + minf(speed_fraction, 1.0) * 0.36, 1.0 - exp(-delta * 12.0))
	_geometry.clear_surfaces()
	_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 2:
		var points: Array[Vector3] = _left if index == 0 else _right
		var socket := _sockets[index]
		if not points.is_empty() and points[0].distance_to(socket.global_position) > 12.0:
			points.clear()
		var exhaust := socket.global_basis.z.normalized() * delta * (3.0 + _power * 4.0)
		for point_index in points.size():
			points[point_index] += exhaust
		points.push_front(socket.global_position)
		if points.size() > MAX_SAMPLES:
			points.resize(MAX_SAMPLES)
		for sample in range(points.size() - 1):
			var age := float(sample) / float(MAX_SAMPLES - 1)
			var next_age := float(sample + 1) / float(MAX_SAMPLES - 1)
			var tangent := points[sample + 1] - points[sample]
			var side := tangent.cross(Vector3.UP).normalized()
			if side.is_zero_approx():
				side = Vector3.RIGHT
			var width := (0.07 + _power * 0.16) * (1.0 - age)
			var next_width := (0.07 + _power * 0.16) * (1.0 - next_age)
			var a := points[sample] - side * width
			var b := points[sample] + side * width
			var c := points[sample + 1] - side * next_width
			var d := points[sample + 1] + side * next_width
			_vertex(a, 0.0, age)
			_vertex(b, 1.0, age)
			_vertex(c, 0.0, next_age)
			_vertex(b, 1.0, age)
			_vertex(d, 1.0, next_age)
			_vertex(c, 0.0, next_age)
		_add_nozzle_jet(socket, index)
	_geometry.surface_end()


func _add_nozzle_jet(socket: Node3D, index: int) -> void:
	# Each plume is three triangles; two small shock diamonds appear at high
	# thrust. No particles, local lights or additional draw calls are needed.
	var origin := socket.global_position
	var aft := socket.global_basis.z.normalized()
	var side := socket.global_basis.x.normalized()
	var shimmer := 1.0 + 0.035 * sin(_elapsed * 43.0 + float(index) * 1.7)
	var length := (0.46 + _power * 1.0 + _ignition * 0.5) * shimmer
	var width := 0.09 + _power * 0.10
	var shoulder := origin + aft * length * 0.22
	var tip := origin + aft * length
	var brightness := 0.88 + _power * 0.32 + _ignition * 0.35 + _reflection * 0.2
	var alpha := 0.58 + _power * 0.32
	_jet_vertex(origin - side * width * 0.48, 0.0, brightness, alpha)
	_jet_vertex(origin + side * width * 0.48, 1.0, brightness, alpha)
	_jet_vertex(shoulder - side * width, 0.0, brightness, alpha)
	_jet_vertex(origin + side * width * 0.48, 1.0, brightness, alpha)
	_jet_vertex(shoulder + side * width, 1.0, brightness, alpha)
	_jet_vertex(shoulder - side * width, 0.0, brightness, alpha)
	_jet_vertex(shoulder - side * width, 0.0, brightness, alpha)
	_jet_vertex(shoulder + side * width, 1.0, brightness, alpha)
	_jet_vertex(tip, 0.5, brightness, 0.0)
	var shock_alpha := smoothstep(0.62, 1.0, _power) * 0.58
	if shock_alpha <= 0.001:
		return
	for diamond in 2:
		var center := origin + aft * length * (0.48 + float(diamond) * 0.24)
		var half_length := aft * length * 0.085
		var half_width := side * width * (0.55 - float(diamond) * 0.12)
		_jet_vertex(center - half_length, 0.5, 1.5, 0.0)
		_jet_vertex(center - half_width, 0.0, 1.5, shock_alpha)
		_jet_vertex(center + half_width, 1.0, 1.5, shock_alpha)
		_jet_vertex(center - half_width, 0.0, 1.5, shock_alpha)
		_jet_vertex(center + half_length, 0.5, 1.5, 0.0)
		_jet_vertex(center + half_width, 1.0, 1.5, shock_alpha)


func _jet_vertex(point: Vector3, side: float, brightness: float, alpha: float) -> void:
	# Negative V identifies nozzle energy; ordinary ribbon V is its 0..1 age.
	_geometry.surface_set_uv(Vector2(side, -brightness))
	_geometry.surface_set_color(Color(minf(brightness, 1.0), 1.0, 1.0, alpha))
	_geometry.surface_add_vertex(point)


func _vertex(point: Vector3, side: float, age: float) -> void:
	_geometry.surface_set_uv(Vector2(side, age))
	_geometry.surface_set_color(Color(0.35 + _power * 0.4 + _reflection * 0.25, 1.0, 1.0, pow(1.0 - age, 1.8) * (0.4 + _power * 0.6)))
	_geometry.surface_add_vertex(point)
