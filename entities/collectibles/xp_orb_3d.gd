extends Area3D
class_name XPOrb3D
## Native XP Orb wrapper. The wrapper owns contact collection, frozen drift
## motion, and the pooled lifecycle; XP authority stays with SignalBus and
## GameManager through XPOrbManager3D.

signal collected(orb_value: int, combat_position: Vector3)
signal returned_to_pool(orb: Area3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(1, 99, 1) var orb_value: int = 1
@export_range(0.0, 500.0, 0.1) var drift_speed_pixels: float = 40.0
@export_range(0.0, 128.0, 0.1) var bob_amplitude_pixels: float = 24.0
@export_range(0.0, 12.0, 0.1) var bob_frequency: float = 3.0
@export_range(1.0, 60.0, 0.5) var lifetime_seconds: float = 20.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var orb_mesh: MeshInstance3D = $Visuals/OrbMesh

var is_active := false
var remaining_lifetime := 0.0
var _return_pending := false
var _idle_parent: Node3D
var _flight_space: FlightSpace
var _bounds := Rect2()
var _drift_screen_direction := Vector2.DOWN
var _bob_time := 0.0


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


## Render the low-poly pickup under a transition cover without arming it.
func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visible = true


## Reuses the orb with a fresh value, drift heading, and camera-derived bounds.
## The direction is supplied in the native Combat Plane, but the frozen
## behavior is evaluated in screen-equivalent pixels before being projected.
func pool_activate(
	flight_space: FlightSpace,
	spawn_position: Vector3,
	value: int,
	drift_direction: Vector3,
	combat_bounds: Rect2
) -> bool:
	if flight_space == null or flight_space.configuration == null:
		return false
	_flight_space = flight_space
	_bounds = combat_bounds
	orb_value = maxi(value, 1)
	var screen_direction := _flight_space.combat_motion_to_screen(drift_direction).normalized()
	_drift_screen_direction = screen_direction if not screen_direction.is_zero_approx() else Vector2.DOWN
	_bob_time = 0.0
	remaining_lifetime = lifetime_seconds
	_return_pending = false
	is_active = true
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	transform.basis = Basis.IDENTITY
	_set_palette()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(&"xp_orbs")
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
	var bob_motion := _drift_screen_direction.orthogonal() * sin(_bob_time * bob_frequency) * bob_amplitude_pixels
	var screen_motion := _drift_screen_direction * drift_speed_pixels + bob_motion
	global_position += _flight_space.screen_motion_to_combat(screen_motion * delta)
	global_position.y = 0.0
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


func _on_area_entered(area: Area3D) -> void:
	if not is_active or _return_pending or not GameManager.is_game_active:
		return
	if area.is_in_group(&"player_craft"):
		_collect()


func _collect() -> void:
	if not is_active or _return_pending:
		return
	var combat_position := global_position
	combat_position.y = 0.0
	collected.emit(orb_value, combat_position)
	despawn()


## Returns the orb to the scene-owned pool after disabling collision and motion.
func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	visible = false
	set_physics_process(false)
	remove_from_group(&"xp_orbs")
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
	_reset_visuals()
	transform = Transform3D.IDENTITY
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


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
