extends Node3D
## A gameplay tell that stays readable when Reduced Motion suppresses rolls.
var _ring: MeshInstance3D
var _label: Label3D
var _material: StandardMaterial3D


func _init() -> void:
	name = "ReflectTell"
	_ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.94
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 8
	_ring.mesh = mesh
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _material
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.pixel_size = 0.1
	_label.outline_size = 8
	_label.no_depth_test = true
	add_child(_label)
	hide()


func present(radius: float, armed: bool, charges: int) -> void:
	_ring.scale = Vector3.ONE * radius
	_ring.position.y = 0.25
	_material.albedo_color = Color(1.0, 0.85, 0.25) if armed else Color(1.0, 0.48, 0.12)
	_label.modulate = _material.albedo_color
	_label.position.y = radius + 2.0
	_label.text = "REFLECT %d" % charges if armed else "REFLECT READYING"
	show()
