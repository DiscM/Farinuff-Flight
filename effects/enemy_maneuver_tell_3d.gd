extends Node3D
## A committed flight corridor, separate from the animated hull and hitbox.
var _line := MeshInstance3D.new()
var _mesh := ImmediateMesh.new()
var _label := Label3D.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	name = "ManeuverTell"
	top_level = true
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0, 0.35, 0.2)
	_material.no_depth_test = true
	_line.mesh = _mesh
	_line.material_override = _material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.pixel_size = 0.085
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.6, 0.3)
	add_child(_label)
	hide()


func present(points: PackedVector3Array, caption: String, target: Vector3 = Vector3.ZERO, show_target: bool = false) -> void:
	global_transform = Transform3D.IDENTITY
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in points.size() - 1:
		_mesh.surface_add_vertex(points[index] + Vector3.UP * 0.3)
		_mesh.surface_add_vertex(points[index + 1] + Vector3.UP * 0.3)
	var tip := points[-1] + Vector3.UP * 0.3
	var back := (points[-2] - points[-1]).normalized() * 1.2
	for angle in [-0.55, 0.55]:
		_mesh.surface_add_vertex(tip)
		_mesh.surface_add_vertex(tip + back.rotated(Vector3.UP, angle))
	if show_target:
		var aim := target + Vector3.UP * 0.3
		for index in 24:
			var a := float(index) / 24.0 * TAU
			var b := float(index + 1) / 24.0 * TAU
			_mesh.surface_add_vertex(aim + Vector3(cos(a), 0.0, sin(a)) * 2.0)
			_mesh.surface_add_vertex(aim + Vector3(cos(b), 0.0, sin(b)) * 2.0)
		for progress in [0.24, 0.5, 0.76]:
			var origin := points[roundi(progress * (points.size() - 1))] + Vector3.UP * 0.3
			for segment in 6:
				_mesh.surface_add_vertex(origin.lerp(aim, float(segment) / 6.0))
				_mesh.surface_add_vertex(origin.lerp(aim, (float(segment) + 0.45) / 6.0))
	_mesh.surface_end()
	_label.position = points[0] + Vector3.UP * 8.0
	_label.text = caption
	show()


func present_attack(lanes: PackedVector3Array, target: Vector3, caption: String) -> void:
	# These stay visible through the flight, independently of cosmetic motion.
	global_transform = Transform3D.IDENTITY
	_material.albedo_color = Color(1.0, 0.66, 0.18)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(0, lanes.size(), 2):
		var origin := lanes[index] + Vector3.UP * 0.4
		var aim := lanes[index + 1] + Vector3.UP * 0.4
		for segment in 8:
			_mesh.surface_add_vertex(origin.lerp(aim, float(segment) / 8.0))
			_mesh.surface_add_vertex(origin.lerp(aim, (float(segment) + 0.55) / 8.0))
	var center := target + Vector3.UP * 0.4
	for index in 32:
		var a := float(index) / 32.0 * TAU
		var b := float(index + 1) / 32.0 * TAU
		_mesh.surface_add_vertex(center + Vector3(cos(a), 0.0, sin(a)) * 3.0)
		_mesh.surface_add_vertex(center + Vector3(cos(b), 0.0, sin(b)) * 3.0)
	_mesh.surface_end()
	_label.position = target + Vector3.UP * 8.0
	_label.modulate = Color(1.0, 0.8, 0.35)
	_label.text = caption
	show()
