extends "res://entities/collectibles/pooled_pickup_3d.gd"
class_name XPOrb3D
## Contact-only XP collection and the value-tier pickup palette.

@export_range(1, 99, 1) var orb_value: int = 1
@onready var orb_mesh: MeshInstance3D = $Visuals/OrbMesh


func _init() -> void:
	_pickup_group = &"xp_orbs"


func _activate_visuals(value: int) -> void:
	orb_value = maxi(value, 1)
	_set_palette()


func _collection_value() -> int:
	return orb_value


func _set_palette() -> void:
	var palette: Array[Color]
	if orb_value == 1:
		palette = [
			Color(0.08, 0.34, 0.86, 1.0),
			Color(0.12, 0.78, 1.0, 1.0),
			Color(0.72, 1.0, 1.0, 1.0),
			Color(0.08, 0.7, 1.0, 1.0),
		]
	elif orb_value == 2:
		palette = [
			Color(0.36, 0.08, 0.78, 1.0),
			Color(0.72, 0.2, 1.0, 1.0),
			Color(0.96, 0.72, 1.0, 1.0),
			Color(0.6, 0.08, 1.0, 1.0),
		]
	else:
		palette = [
			Color(0.72, 0.06, 0.14, 1.0),
			Color(1.0, 0.16, 0.22, 1.0),
			Color(1.0, 0.72, 0.72, 1.0),
			Color(1.0, 0.05, 0.12, 1.0),
		]
	orb_mesh.set_instance_shader_parameter(&"instance_base_override", palette[0])
	orb_mesh.set_instance_shader_parameter(&"instance_energy_override", palette[1])
	orb_mesh.set_instance_shader_parameter(&"instance_accent_override", palette[2])
	orb_mesh.set_instance_shader_parameter(&"instance_glow_override", palette[3])
	orb_mesh.set_instance_shader_parameter(&"instance_phase_offset", float(orb_value) * 0.73)


func _reset_visuals() -> void:
	visuals.transform = Transform3D.IDENTITY
	orb_mesh.set_instance_shader_parameter(&"instance_modulate", Color.WHITE)
	orb_mesh.set_instance_shader_parameter(&"instance_flash", 0.0)
	orb_mesh.set_instance_shader_parameter(&"instance_phase_offset", 0.0)
	orb_mesh.set_instance_shader_parameter(&"instance_base_override", Color.TRANSPARENT)
	orb_mesh.set_instance_shader_parameter(&"instance_energy_override", Color.TRANSPARENT)
	orb_mesh.set_instance_shader_parameter(&"instance_accent_override", Color.TRANSPARENT)
	orb_mesh.set_instance_shader_parameter(&"instance_glow_override", Color.TRANSPARENT)
