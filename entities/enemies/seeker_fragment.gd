extends Area2D
class_name SeekerFragment
## Targetable Apex death fragment. It never awards score, combo, or orbs.

const LIFE_TIME := 2.5
const SPEED := 190.0
const TURN_RATE := 1.8

var direction := Vector2.DOWN
var lifetime := 0.0
var coordinator: SpecialAttackCoordinator
var _active := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_physics_process(false)


func pool_activate(spawn_position: Vector2, initial_direction: Vector2, shared_coordinator: SpecialAttackCoordinator) -> void:
	global_position = spawn_position
	direction = initial_direction.normalized()
	coordinator = shared_coordinator
	lifetime = LIFE_TIME
	_active = true
	visible = true
	collision_layer = 2
	collision_mask = 5
	monitoring = true
	monitorable = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group("enemies")
	add_to_group("evolved_pressure")


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		despawn()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var desired := (player.global_position - global_position).normalized()
		direction = direction.rotated(clampf(direction.angle_to(desired), -TURN_RATE * delta, TURN_RATE * delta))
	rotation = direction.angle() + PI * 0.5
	position += direction * SPEED * delta


func take_damage(_amount: int) -> void:
	despawn()


func despawn() -> void:
	if not _active:
		return
	_active = false
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.release_hazard(&"seeker_fragment")
	visible = false
	call_deferred("_release")


func _release() -> void:
	remove_from_group("enemies")
	remove_from_group("evolved_pressure")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.release(self)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		despawn()
