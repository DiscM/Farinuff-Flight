extends Area3D
class_name PlayerDrone3D
## Native Drone Escort upgrade. The wrapper owns hover movement, target search,
## fire cadence, and overlap reporting; Native3DGameplay owns projectile and
## enemy-damage routing.

signal fire_requested(combat_position: Vector3, direction: Vector3)
signal contact_damage_requested(target: Area3D, combat_position: Vector3)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")

## Matches the frozen 2D escort behavior.
const FIRE_INTERVAL := 0.65
const HOVER_OFFSET_PIXELS := Vector2(50.0, -20.0)
const HOVER_SMOOTHING := 6.0

@export_range(0.05, 4.0, 0.01) var fire_interval: float = FIRE_INTERVAL
@export var hover_offset_pixels := HOVER_OFFSET_PIXELS

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var sockets: Node3D = $Attachments/Sockets

var is_active := false
var shots_fired := 0
var contact_hits := 0

var _player: PlayerCraft
var _flight_space: FlightSpace
var _shoot_timer := 0.0


func _ready() -> void:
	# The scene is inert until Native3DGameplay explicitly enables the upgrade.
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


## Makes the wrapper visible and collision-active for the supplied native run.
## The drone remains a scene-managed single actor; it is not pooled because the
## reference has at most one escort per Player Craft.
func configure(player: PlayerCraft, flight_space: FlightSpace) -> bool:
	if player == null or flight_space == null or flight_space.configuration == null:
		push_error("PlayerDrone3D requires a Player3D and configured FlightSpace3D")
		return false
	_player = player
	_flight_space = flight_space
	shots_fired = 0
	contact_hits = 0
	_shoot_timer = 0.0
	set_combat_position(_hover_target_position())
	collision_layer = PhysicsLayers.PLAYER_PROJECTILE
	collision_mask = PhysicsLayers.ENEMY_CRAFT
	monitoring = true
	monitorable = true
	collision_shape.disabled = false
	is_active = true
	add_to_group(&"native_3d_player_drone")
	set_physics_process(true)
	show()
	force_update_transform()
	return true


## Makes this wrapper safe for transition warm-up without enabling gameplay.
func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visible = true


func deactivate() -> void:
	if not is_active and get_parent() == null:
		return
	is_active = false
	set_physics_process(false)
	remove_from_group(&"native_3d_player_drone")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	hide()


func _physics_process(delta: float) -> void:
	if not is_active or _player == null or not is_instance_valid(_player):
		return
	if not GameManager.is_game_active:
		return
	var target_position := _hover_target_position()
	var smoothing := clampf(delta * HOVER_SMOOTHING, 0.0, 1.0)
	set_combat_position(global_position.lerp(target_position, smoothing))
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = fire_interval
		_fire()


func get_combat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func get_socket(socket_name: StringName) -> Marker3D:
	return sockets.get_node_or_null(NodePath(String(socket_name))) as Marker3D


func get_status() -> Dictionary:
	return {
		"active": is_active,
		"shots_fired": shots_fired,
		"contact_hits": contact_hits,
		"fire_interval": fire_interval,
		"hover_offset_pixels": hover_offset_pixels,
	}


func _hover_target_position() -> Vector3:
	var player_position := _player.get_combat_position()
	var offset := _flight_space.screen_motion_to_combat(hover_offset_pixels)
	return Vector3(player_position.x + offset.x, 0.0, player_position.z + offset.z)


func _fire() -> void:
	if _flight_space == null:
		return
	var direction := _nearest_enemy_direction(get_combat_position())
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var muzzle := get_socket(&"MuzzleCenter")
	var spawn_position := muzzle.global_position if muzzle != null else global_position
	spawn_position.y = 0.0
	shots_fired += 1
	fire_requested.emit(spawn_position, direction)


func _nearest_enemy_direction(origin: Vector3) -> Vector3:
	var best: Node3D
	var best_distance_squared := INF
	for enemy in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D) or not enemy.has_method(&"take_damage"):
			continue
		var enemy_node := enemy as Node3D
		var screen_offset := _flight_space.combat_motion_to_screen(
			enemy_node.global_position - origin
		)
		var distance_squared := screen_offset.length_squared()
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = enemy_node
	if best == null:
		return Vector3.ZERO
	var direction := best.global_position - origin
	direction.y = 0.0
	return direction.normalized()


func _on_area_entered(area: Area3D) -> void:
	if not is_active or not GameManager.is_game_active or area == null:
		return
	if not (area.collision_layer & PhysicsLayers.ENEMY_CRAFT):
		return
	contact_hits += 1
	var combat_position := get_combat_position()
	contact_damage_requested.emit(area, combat_position)


func set_combat_position(combat_position: Vector3) -> void:
	global_position = Vector3(combat_position.x, 0.0, combat_position.z)
