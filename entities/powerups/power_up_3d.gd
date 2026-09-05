extends Area3D
class_name PowerUp3D
## Native pooled power-up wrapper. Collection is valid through direct Player
## Craft contact or a Player Projectile hit; the existing SignalBus remains the
## single power-up application path.

signal collected(power_up_type: int, combat_position: Vector3)
signal returned_to_pool(power_up: PowerUp3D)

const PowerUpTypes := preload("res://entities/powerups/power_up_types.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

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
@export_range(1.0, 500.0, 0.1) var drift_speed_pixels: float = 80.0
@export_range(0.0, 128.0, 0.1) var bob_amplitude_pixels: float = 30.0
@export_range(0.0, 12.0, 0.1) var bob_frequency: float = 2.5
@export_range(1.0, 60.0, 0.5) var lifetime_seconds: float = 20.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var pickup_mesh: MeshInstance3D = $Visuals/PickupMesh
@onready var type_label: Label3D = $Visuals/TypeLabel

var is_active := false
var remaining_lifetime := 0.0
var _return_pending := false
var _idle_parent: Node3D
var _flight_space: FlightSpace
var _bounds := Rect2()
var _screen_direction := Vector2.DOWN
var _bob_time := 0.0


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


## Render the low-poly pickup under the transition cover without arming it.
func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visuals.position.y = 0.24
	visible = true
	pickup_mesh.visible = true
	type_label.visible = true


## Reuses the pickup with a fresh type, downward drift heading, and bounds.
## Motion remains screen-equivalent before projection onto the Combat Plane.
func pool_activate(
	flight_space: FlightSpace,
	spawn_position: Vector3,
	new_type: int,
	drift_direction: Vector3,
	combat_bounds: Rect2
) -> bool:
	if flight_space == null or flight_space.configuration == null or _idle_parent == null:
		return false
	_flight_space = flight_space
	_bounds = combat_bounds
	power_up_type = clampi(new_type, PowerUpTypes.Type.SCALE_UP, PowerUpTypes.Type.NUKE)
	_screen_direction = _flight_space.combat_motion_to_screen(drift_direction).normalized()
	if _screen_direction.is_zero_approx():
		_screen_direction = Vector2.DOWN
	_bob_time = 0.0
	remaining_lifetime = lifetime_seconds
	_return_pending = false
	is_active = true
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	transform.basis = Basis.IDENTITY
	visuals.position = Vector3(0.0, 0.24, 0.0)
	visuals.rotation = Vector3.ZERO
	_set_visuals()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(&"native_3d_powerups")
	collision_shape.disabled = false
	collision_layer = PhysicsLayers.PICKUP
	collision_mask = PhysicsLayers.PICKUP_MASK
	monitoring = true
	monitorable = true
	force_update_transform()
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		despawn()
		return
	_bob_time += delta
	var bob_motion := _screen_direction.orthogonal() * sin(_bob_time * bob_frequency) * bob_amplitude_pixels
	var screen_motion := _screen_direction * drift_speed_pixels + bob_motion
	global_position += _flight_space.screen_motion_to_combat(screen_motion * delta)
	global_position.y = 0.0
	visuals.rotation.y += delta * 1.8
	visuals.position.y = 0.24 + sin(_bob_time * bob_frequency * 1.6) * 0.08
	if not _bounds.has_point(Vector2(global_position.x, global_position.z)):
		despawn()


## Moves toward a native Player Craft when the Magnet power-up is active.
func magnet_pull_to(target_position: Vector3, delta: float, pull_speed_pixels: float) -> void:
	if not is_active or _flight_space == null:
		return
	var screen_offset := _flight_space.combat_motion_to_screen(target_position - global_position)
	if screen_offset.is_zero_approx():
		return
	var screen_direction := screen_offset.normalized()
	global_position += _flight_space.screen_motion_to_combat(screen_direction * pull_speed_pixels * delta)
	global_position.y = 0.0


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


func _collect() -> void:
	if not is_active or _return_pending:
		return
	var combat_position := global_position
	combat_position.y = 0.0
	collected.emit(power_up_type, combat_position)
	SignalBus.power_up_collected.emit(power_up_type, combat_position)
	despawn()


## Returns the pickup to the scene-owned pool after disabling overlap/motion.
func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	visible = false
	set_physics_process(false)
	remove_from_group(&"native_3d_powerups")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	call_deferred("_finish_return")


func _finish_return() -> void:
	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	remaining_lifetime = 0.0
	_bob_time = 0.0
	_flight_space = null
	_bounds = Rect2()
	_screen_direction = Vector2.DOWN
	_reset_visuals()
	transform = Transform3D.IDENTITY
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


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
