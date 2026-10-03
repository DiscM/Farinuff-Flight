extends "res://entities/collectibles/pooled_pickup_3d.gd"
class_name PowerUp3D
## Projectile or craft collection; power-up application stays on SignalBus.

const PowerUpTypes := preload("res://entities/powerups/power_up_types.gd")
const TYPE_COLORS := {
	PowerUpTypes.Type.SCALE_UP: Color(0.2, 0.8, 1.0),
	PowerUpTypes.Type.RAPID_FIRE: Color(1.0, 0.8, 0.0),
	PowerUpTypes.Type.SHIELD: Color(0.3, 0.9, 0.5),
	PowerUpTypes.Type.SPREAD_SHOT: Color(1.0, 0.4, 0.8),
	PowerUpTypes.Type.MAGNET: Color(0.6, 0.4, 1.0),
	PowerUpTypes.Type.NUKE: Color(1.0, 0.2, 0.2),
}

const TYPE_LABELS := {
	PowerUpTypes.Type.SCALE_UP: "S+",
	PowerUpTypes.Type.RAPID_FIRE: "RF",
	PowerUpTypes.Type.SHIELD: "SH",
	PowerUpTypes.Type.SPREAD_SHOT: "SP",
	PowerUpTypes.Type.MAGNET: "MG",
	PowerUpTypes.Type.NUKE: "NK",
}

@export_range(0, 5, 1) var power_up_type: int = PowerUpTypes.Type.SCALE_UP
@onready var pickup_mesh: MeshInstance3D = $Visuals/PickupMesh
@onready var type_label: Label3D = $Visuals/TypeLabel


func _init() -> void:
	_pickup_group = &"native_3d_powerups"
	_requires_idle_parent = true
	drift_speed_pixels = 80.0
	bob_amplitude_pixels = 30.0
	bob_frequency = 2.5


func prepare_visual_warmup() -> void:
	super.prepare_visual_warmup()
	visuals.position.y = 0.24
	pickup_mesh.visible = true
	type_label.visible = true


func _activate_visuals(value: int) -> void:
	power_up_type = clampi(value, PowerUpTypes.Type.SCALE_UP, PowerUpTypes.Type.NUKE)
	visuals.position = Vector3(0.0, 0.24, 0.0)
	visuals.rotation = Vector3.ZERO
	_set_visuals()


func _advance_visuals(delta: float) -> void:
	visuals.rotation.y += delta * 1.8
	visuals.position.y = 0.24 + sin(_bob_time * bob_frequency * 1.6) * 0.08


func _collection_value() -> int:
	return power_up_type


func _after_collection(position: Vector3) -> void:
	SignalBus.power_up_collected.emit(power_up_type, position)


func take_damage(_amount: int) -> void:
	_collect()


func _on_area_entered(area: Area3D) -> void:
	if not is_active or _return_pending or not GameManager.is_game_active:
		return
	if area.collision_layer & PhysicsLayers.PLAYER_PROJECTILE:
		if area.has_method("despawn"):
			area.despawn()
		_collect()
	elif area.is_in_group(&"player_craft"):
		_collect()


func get_type_color() -> Color:
	return TYPE_COLORS.get(power_up_type, Color.WHITE)


func get_type_label() -> String:
	return TYPE_LABELS.get(power_up_type, "?")


func _set_visuals() -> void:
	var color := get_type_color()
	pickup_mesh.set_instance_shader_parameter(&"instance_base_override", color.darkened(0.45))
	pickup_mesh.set_instance_shader_parameter(&"instance_energy_override", color)
	pickup_mesh.set_instance_shader_parameter(&"instance_accent_override", Color.WHITE)
	pickup_mesh.set_instance_shader_parameter(&"instance_glow_override", color)
	pickup_mesh.set_instance_shader_parameter(&"instance_phase_offset", float(power_up_type) * 0.61)
	type_label.text = get_type_label()
	type_label.modulate = color.lightened(0.35)
	pickup_mesh.visible = true
	type_label.visible = true


func _reset_visuals() -> void:
	visuals.position = Vector3(0.0, 0.24, 0.0)
	visuals.rotation = Vector3.ZERO
	pickup_mesh.set_instance_shader_parameter(&"instance_modulate", Color.WHITE)
	pickup_mesh.set_instance_shader_parameter(&"instance_flash", 0.0)
	pickup_mesh.set_instance_shader_parameter(&"instance_phase_offset", 0.0)
	pickup_mesh.set_instance_shader_parameter(&"instance_base_override", Color.TRANSPARENT)
	pickup_mesh.set_instance_shader_parameter(&"instance_energy_override", Color.TRANSPARENT)
	pickup_mesh.set_instance_shader_parameter(&"instance_accent_override", Color.TRANSPARENT)
	pickup_mesh.set_instance_shader_parameter(&"instance_glow_override", Color.TRANSPARENT)
	type_label.text = ""
	type_label.visible = false
	pickup_mesh.visible = false
