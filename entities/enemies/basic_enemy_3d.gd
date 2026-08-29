extends Area3D
class_name BasicEnemy3D
## Scene-managed Generation I contact enemy. No steering, shooting, rewards,
## Player damage, or imported-animation dependencies in this migration slice.

signal finished(reason: FinishReason, combat_position: Vector3)

enum FinishReason { DESTROYED, CONTACT, ESCAPED }

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const GenerationStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const SpawnTuning := preload("res://entities/enemies/enemy_spawn_tuning.gd")

@export var gameplay_stats: GenerationStats

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var sockets: Node3D = $Attachments/Sockets

var is_active := false
var health: int = 0
var velocity := Vector3.ZERO

var _flight_space: FlightSpace
var _exit_bounds := Rect2()
var _heading := Vector3.BACK
var _speed_pixels := 0.0
var _meshes: Array[MeshInstance3D] = []
var _socket_markers: Array[Marker3D] = []
var _animation_time := 0.0
var _flash_time_left := 0.0
var _breathing: Tween


func _ready() -> void:
	# Inert but visible before activation: the transition can warm the actual
	# first enemy without collision, gameplay groups, timers, or reward effects.
	set_physics_process(false)
	for node in visuals.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	for child in sockets.get_children():
		if child is Marker3D:
			_socket_markers.append(child as Marker3D)
	area_entered.connect(_on_area_entered)
	_set_instance_parameter(&"instance_animation_time", 0.0)
	_set_instance_parameter(&"instance_flash", 0.0)


func activate(flight_space: FlightSpace, combat_position: Vector3, direction: Vector3) -> bool:
	if is_active or is_queued_for_deletion():
		return false
	if flight_space == null or flight_space.configuration == null or gameplay_stats == null:
		push_error("BasicEnemy3D requires shared generation stats and a configured FlightSpace3D")
		return false
	direction.y = 0.0
	if direction.is_zero_approx():
		return false
	_flight_space = flight_space
	_heading = direction.normalized()
	combat_position.y = 0.0
	global_position = combat_position
	rotation = Vector3(0.0, atan2(-_heading.x, -_heading.z), 0.0)
	# Gen I enters from four cardinal edges. The reference's square stays
	# 26x26 screen pixels at each heading; compensate camera foreshortening
	# with the authored box, independently of visual/socket yaw.
	collision_shape.global_rotation = Vector3.ZERO
	_speed_pixels = gameplay_stats.move_speed * GameManager.get_late_game_speed_multiplier()
	_configure_movement()
	# Preserve the reference's two separate rounding steps.
	health = roundi(float(gameplay_stats.max_health) * GameManager.get_enemy_health_multiplier())
	health = roundi(float(health) * GameManager.get_late_game_health_multiplier())
	_refresh_exit_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_exit_bounds):
		get_viewport().size_changed.connect(_refresh_exit_bounds)
	_animation_time = 0.0
	_flash_time_left = 0.0
	_set_instance_parameter(&"instance_animation_time", 0.0)
	_set_instance_parameter(&"instance_flash", 0.0)
	is_active = true
	add_to_group(&"enemy_craft")
	collision_layer = PhysicsLayers.ENEMY_CRAFT
	collision_mask = PhysicsLayers.ENEMY_CRAFT_MASK
	monitoring = true
	monitorable = true
	collision_shape.disabled = false
	force_update_transform()
	set_physics_process(true)
	show()
	_breathing = create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_breathing.tween_property(visuals, "scale", Vector3(1.05, 1.0, 0.95), 0.6).set_trans(Tween.TRANS_SINE)
	_breathing.tween_property(visuals, "scale", Vector3(0.95, 1.0, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	_advance_movement(delta)
	global_position.y = 0.0
	# Player Projectiles sweep at priority 2, after actor transforms reach physics.
	force_update_transform()
	if _has_crossed_exit_edge():
		_finish(FinishReason.ESCAPED)
		return
	_animation_time += delta
	_set_instance_parameter(&"instance_animation_time", _animation_time)
	if _flash_time_left > 0.0:
		_flash_time_left = maxf(_flash_time_left - delta, 0.0)
		var flash := (0.15 - _flash_time_left) / 0.05 if _flash_time_left > 0.1 else _flash_time_left / 0.1
		_set_instance_parameter(&"instance_flash", clampf(flash, 0.0, 1.0))


## Hook for movement variants. The default is the Generation I straight path;
## specialized native roles override these two methods while retaining the
## shared hitbox, damage, contact, and finish lifecycle.
func _configure_movement() -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(_heading).normalized()
	velocity = _flight_space.screen_motion_to_combat(screen_direction * _speed_pixels)
	velocity.y = 0.0


func _advance_movement(delta: float) -> void:
	global_position += velocity * delta


func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	health -= amount
	if health <= 0:
		_finish(FinishReason.DESTROYED)
	else:
		_flash_time_left = 0.15


func get_socket_markers() -> Array[Marker3D]:
	return _socket_markers


func _on_area_entered(area: Area3D) -> void:
	# Projectile damage is routed once by Native3DGameplay, never also here.
	if area.is_in_group(&"player_craft"):
		_finish(FinishReason.CONTACT)


func _finish(reason: FinishReason) -> void:
	if not is_active:
		return
	is_active = false
	set_physics_process(false)
	remove_from_group(&"enemy_craft")
	hide()
	if _breathing != null:
		_breathing.kill()
	# Contacts may arrive during a physics flush. Deactivate logically now and
	# defer physics mutations; repeated damage/contact callbacks cannot finish twice.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	var combat_position := global_position
	combat_position.y = 0.0
	finished.emit(reason, combat_position)
	queue_free()


func _refresh_exit_bounds() -> void:
	_exit_bounds = _flight_space.get_combat_bounds(SpawnTuning.DESPAWN_MARGIN)


func _has_crossed_exit_edge() -> bool:
	return (
		(_heading.z > 0.3 and global_position.z > _exit_bounds.end.y)
		or (_heading.z < -0.3 and global_position.z < _exit_bounds.position.y)
		or (_heading.x > 0.3 and global_position.x > _exit_bounds.end.x)
		or (_heading.x < -0.3 and global_position.x < _exit_bounds.position.x)
	)


func _set_instance_parameter(parameter: StringName, value: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(parameter, value)
