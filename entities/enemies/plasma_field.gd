extends Area2D
class_name PlasmaField
## Short-lived bounded Apex hazard.

var coordinator: SpecialAttackCoordinator
var _active := false
var _life := 0.0
var _pulse := 0.0
var _hit_cooldown := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_process(false)


func pool_activate(spawn_position: Vector2, shared_coordinator: SpecialAttackCoordinator) -> void:
	global_position = spawn_position
	coordinator = shared_coordinator
	_active = true
	_life = 2.0
	_pulse = 0.0
	_hit_cooldown = 0.0
	visible = true
	collision_layer = 32
	collision_mask = 1
	monitoring = true
	monitorable = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	add_to_group("hostile_ordnance")
	add_to_group("evolved_pressure")


func _process(delta: float) -> void:
	_life -= delta
	_pulse += delta
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	scale = Vector2.ONE * (1.0 + sin(_pulse * 9.0) * 0.08)
	modulate.a = clampf(_life, 0.0, 1.0)
	if _life <= 0.0:
		despawn()


func clear_ordnance() -> void:
	despawn()


func despawn() -> void:
	if not _active:
		return
	_active = false
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.release_hazard(&"plasma_field")
	visible = false
	call_deferred("_release")


func _release() -> void:
	remove_from_group("hostile_ordnance")
	remove_from_group("evolved_pressure")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.release(self)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and _hit_cooldown <= 0.0:
		_hit_cooldown = 0.8
		if area.has_method("receive_hostile_hit"):
			area.receive_hostile_hit(2.0)
