extends MultiMeshInstance3D
## Six Blender-authored fragments per pooled effect; no event-time nodes or physics.

const HULL := preload("res://assets/models/frontier/hull_fragment.glb")
const VOID := preload("res://assets/models/frontier/void_splinter.glb")
const SHADER := preload("res://effects/shaders/frontier_fragment_3d.gdshader")
const Palette := preload("res://effects/rendering/frontier_palette.gd")
const COUNT := 6
static var _hull_mesh: Mesh
static var _void_mesh: Mesh
var _void := false


func _ready() -> void:
	if _hull_mesh == null:
		_hull_mesh = _mesh_from(HULL)
		_void_mesh = _mesh_from(VOID)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _hull_mesh
	multimesh.instance_count = COUNT
	multimesh.custom_aabb = AABB(Vector3(-9, -3, -9), Vector3(18, 6, 18))
	var fragment_material := ShaderMaterial.new()
	fragment_material.shader = SHADER
	material_override = fragment_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	hide()


func configure(is_void: bool) -> void:
	_void = is_void
	multimesh.mesh = _void_mesh if _void else _hull_mesh
	set_instance_shader_parameter(&"fragment_color", Palette.VIOLET if _void else Palette.SPARK)
	show()


func advance(progress: float, intensity: float, phase: float) -> void:
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
