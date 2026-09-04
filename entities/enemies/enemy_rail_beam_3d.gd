extends Area3D
class_name EnemyRailBeam3D
## Locked, non-reflectable lane: 0.9-second warning, 0.15-second damage window.
## Only this wrapper observes overlaps; the Player cannot also consume the hit.

signal returned_to_pool(rail: EnemyRailBeam3D)

const PlayerCraft := preload("res://entities/player/player_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")

@onready var warning: MeshInstance3D = $Visuals/Warning
@onready var beam: MeshInstance3D = $Visuals/Beam
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_active := false
var fired := false
var remaining_time := 0.0
var _hit_player := false
var _return_pending := false
var _source: Node
var _coordinator: SpecialAttackCoordinator
var _idle_parent: Node3D


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D, coordinator: SpecialAttackCoordinator) -> void:
	_idle_parent = idle_parent
	_coordinator = coordinator


func prepare_visual_warmup() -> void:
	show()
	warning.show()
	beam.show()


func pool_activate(flight_space: FlightSpace, origin: Vector3, direction: Vector3, source: Node) -> bool:
	direction.y = 0.0
	if direction.is_zero_approx() or not is_instance_valid(source):
		return false
	_source = source
	# Project the entire screen-space rectangle, including its perpendicular
	# width. This preserves the 1600x18 lane at diagonal headings too.
	var screen_direction := flight_space.combat_motion_to_screen(direction).normalized()
	var along := flight_space.screen_motion_to_combat(screen_direction)
	var across := flight_space.screen_motion_to_combat(Vector2(-screen_direction.y, screen_direction.x))
	global_transform = Transform3D.IDENTITY
	global_position = Vector3(origin.x, 0.0, origin.z)
	var lane_basis := Basis(across, Vector3.UP, along)
	warning.transform = Transform3D(lane_basis.scaled_local(Vector3(3.0, 1.0, 1600.0)), along * 800.0 + Vector3.UP * 0.04)
	beam.transform = Transform3D(lane_basis.scaled_local(Vector3(18.0, 1.0, 1600.0)), along * 800.0 + Vector3.UP * 0.04)
	# Convex primitive vertices preserve the affine camera projection without
	# unsupported shearing/scaling of a physics shape transform.
	var points := PackedVector3Array()
	for length in [0.0, 1600.0]:
		for width in [-9.0, 9.0]:
			for height in [-0.25, 0.25]:
				points.append(along * length + across * width + Vector3.UP * height)
	(collision_shape.shape as ConvexPolygonShape3D).points = points
	remaining_time = 0.9
	fired = false
	_hit_player = false
	_return_pending = false
	is_active = true
	warning.transparency = 0.0
	warning.show()
	beam.hide()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER_CRAFT
	monitorable = false
	monitoring = true
	collision_shape.disabled = true
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	if not is_instance_valid(_source) or _source.is_queued_for_deletion() or not _source.is_active:
		despawn()
		return
	remaining_time -= delta
	if not fired:
		warning.transparency = 0.65 * (1.0 - absf(sin(remaining_time * 22.0)))
		if remaining_time <= 0.0:
			fired = true
			remaining_time = 0.15
			warning.hide()
			beam.show()
			collision_shape.set_deferred("disabled", false)
	elif remaining_time <= 0.0:
		despawn()


func _on_area_entered(area: Area3D) -> void:
	if not is_active or not fired or _hit_player or not area is PlayerCraft:
		return
	_hit_player = true
	area.receive_damage(area.global_position, PlayerCraft.DamageSource.HOSTILE_ORDNANCE)


func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	_release_major()
	hide()
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	_finish_return.call_deferred()


func _finish_return() -> void:
	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_source = null
	remaining_time = 0.0
	fired = false
	_hit_player = false
	warning.transparency = 0.0
	warning.hide()
	beam.hide()
	transform = Transform3D.IDENTITY
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _release_major() -> void:
	if is_instance_valid(_coordinator) and is_instance_valid(_source):
		_coordinator.release_major(_source)


func _exit_tree() -> void:
	_release_major()
