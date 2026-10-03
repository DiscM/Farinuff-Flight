extends MultiMeshInstance3D
## Pooled hull shards and voxel death debris; no event-time nodes or physics.

const HULL := preload("res://assets/models/frontier/hull_fragment.glb")
const VOID := preload("res://assets/models/frontier/void_splinter.glb")
const SHADER := preload("res://effects/shaders/frontier_fragment_3d.gdshader")
const Palette := preload("res://effects/rendering/frontier_palette.gd")
const COUNT := 6
const MAX_VOXELS := 48
static var _voxel_mesh: BoxMesh
var _voxels := false
var _hull_extent := 1.0
var _piece_size := 0.16
var _random := RandomNumberGenerator.new()
var _directions := PackedVector3Array()
var _spins := PackedVector3Array()
var _sizes := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _lifts := PackedFloat32Array()
static var _hull_mesh: Mesh
static var _void_mesh: Mesh
var _void := false


func _ready() -> void:
	_random.randomize()
	_directions.resize(MAX_VOXELS)
	_spins.resize(MAX_VOXELS)
	_sizes.resize(MAX_VOXELS)
	_speeds.resize(MAX_VOXELS)
	_lifts.resize(MAX_VOXELS)
	if _hull_mesh == null:
		_hull_mesh = _mesh_from(HULL)
		_void_mesh = _mesh_from(VOID)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _hull_mesh
	multimesh.instance_count = MAX_VOXELS
	multimesh.visible_instance_count = COUNT
	if _voxel_mesh == null:
		_voxel_mesh = BoxMesh.new()
		_voxel_mesh.size = Vector3.ONE
	for index in MAX_VOXELS:
		multimesh.set_instance_color(index, Color.WHITE)
	multimesh.custom_aabb = AABB(Vector3(-9, -3, -9), Vector3(18, 6, 18))
	var fragment_material := ShaderMaterial.new()
	fragment_material.shader = SHADER
	material_override = fragment_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	hide()


func configure(is_void: bool) -> void:
	_voxels = false
	multimesh.visible_instance_count = COUNT
	for index in COUNT:
		multimesh.set_instance_color(index, Color.WHITE)
	_void = is_void
	multimesh.mesh = _void_mesh if _void else _hull_mesh
	set_instance_shader_parameter(&"fragment_color", Palette.VIOLET if _void else Palette.SPARK)
	show()


func configure_voxels(hull_color: Color, hull_extent: float) -> void:
	_voxels = true
	_void = false
	_hull_extent = clampf(hull_extent, 0.5, 12.0)
	_piece_size = clampf(_hull_extent * 0.055, 0.10, 0.34)
	multimesh.mesh = _voxel_mesh
	multimesh.visible_instance_count = _random.randi_range(40, MAX_VOXELS) if _hull_extent > 4.0 else _random.randi_range(28, 36)
	# Keep the culling bounds large enough for the largest boss burst.
	multimesh.custom_aabb = AABB(Vector3(-28, -10, -28), Vector3(56, 20, 56))
	for index in multimesh.visible_instance_count:
		var angle := float(index) * 2.399963 + _random.randf_range(-0.4, 0.4)
		_directions[index] = Vector3(cos(angle), 0.0, sin(angle))
		_spins[index] = Vector3(_random.randf_range(-9.0, 9.0), _random.randf_range(-9.0, 9.0), _random.randf_range(-9.0, 9.0))
		_sizes[index] = _random.randf_range(0.55, 1.5)
		_speeds[index] = _random.randf_range(0.4, 1.4)
		_lifts[index] = _random.randf_range(0.25, 1.3)
		var color := hull_color
		if index % 7 == 0:
			color = Palette.SPARK
		elif index % 4 == 0:
			color = hull_color.darkened(0.55)
		elif index % 3 == 0:
			color = hull_color.lightened(0.22)
		multimesh.set_instance_color(index, color)
	set_instance_shader_parameter(&"fragment_color", Color.WHITE)
	show()


func advance(progress: float, intensity: float, phase: float) -> void:
	if _voxels:
		_advance_voxels(progress, intensity, phase)
		return
	var fade := 1.0 - smoothstep(0.45, 1.0, progress)
	set_instance_shader_parameter(&"fragment_fade", fade)
	set_instance_shader_parameter(&"fragment_heat", pow(1.0 - progress, 2.0))
	for index in COUNT:
		var angle := float(index) * TAU / float(COUNT) + phase
		var radius := (1.0 - pow(1.0 - progress, 2.0)) * (3.0 + float(index % 3) * 1.1)
		if _void:
			radius = lerpf(3.2, 0.15, minf(progress / 0.42, 1.0)) if progress < 0.42 else lerpf(0.15, 3.8, (progress - 0.42) / 0.58)
			angle += progress * 1.8
		var point := Vector3(cos(angle) * radius, sin(progress * PI) * 0.4, sin(angle) * radius) * intensity
		var spin := Basis.from_euler(Vector3(angle + progress * 4.0, progress * 5.0, angle))
		spin = spin.scaled(Vector3.ONE * (0.65 + float(index % 3) * 0.2) * intensity)
		multimesh.set_instance_transform(index, Transform3D(spin, point))


static func _mesh_from(scene: PackedScene) -> Mesh:
	var root := scene.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var result: Mesh = (meshes[0] as MeshInstance3D).mesh
	root.free()
	return result


func _advance_voxels(progress: float, intensity: float, phase: float) -> void:
	var fade := 1.0 - smoothstep(0.65, 1.0, progress)
	set_instance_shader_parameter(&"fragment_fade", fade)
	set_instance_shader_parameter(&"fragment_heat", pow(1.0 - progress, 4.0) * 0.45)
	var travel := 1.0 - exp(-progress * 2.8)
	for index in multimesh.visible_instance_count:
		var radial := Basis(Vector3.UP, phase) * _directions[index]
		var point := radial * (_hull_extent * _speeds[index] * (0.25 + travel * 1.65))
		point += Vector3.FORWARD * progress * intensity * 0.7
		point.y = sin(progress * PI) * _lifts[index] - progress * progress * 0.45
		var spin := Basis.from_euler(_spins[index] * (0.2 + progress))
		var size := _piece_size * _sizes[index] * lerpf(1.0, 0.65, progress)
		multimesh.set_instance_transform(index, Transform3D(spin.scaled(Vector3.ONE * size), point))


## Read only the selected visible hull, even when its actor was hidden for death.
## AABB/material reads avoid walking imported vertex buffers during combat.
static func hull_appearance(root: Node3D) -> Dictionary:
	var result := {"color": Color(0.52, 0.60, 0.72), "extent": 1.0, "weight": 0.0}
	_collect_hull(root, result)
	return result


static func _collect_hull(node: Node3D, result: Dictionary) -> void:
	if not node.visible:
		return
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.mesh.get_aabb()
		var size: Vector3 = bounds.size * node.global_basis.get_scale().abs()
		result.extent = maxf(result.extent, maxf(size.x, size.z) * 0.5)
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			var color := Color.TRANSPARENT
			if material is ShaderMaterial:
				var value = material.get_shader_parameter(&"base_color")
				if value is Color: color = value
			elif material is BaseMaterial3D:
				color = material.albedo_color
			# Prefer colored armor over dark structural or luminous reactor parts.
			var weight := size.x * size.z * color.s
			if color.a > 0.0 and color.v > 0.12 and color.v < 0.95 and weight > result.weight:
				result.color = color
				result.weight = weight
	for child in node.get_children():
		if child is Node3D: _collect_hull(child, result)
