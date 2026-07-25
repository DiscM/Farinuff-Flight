extends Area2D
class_name EnemyRailBeam
## Locked precision beam: 0.9s warning, 0.15s hazardous lane.

var source_enemy: Node
var coordinator: SpecialAttackCoordinator
var direction := Vector2.DOWN
var _timer := 0.0
var _active := false
var _fired := false
var _hit_player := false

@onready var warning: Line2D = $Warning
@onready var beam: Polygon2D = $Beam
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_process(false)


func pool_activate(origin: Vector2, shot_direction: Vector2, owner_enemy: Node, shared_coordinator: SpecialAttackCoordinator) -> void:
	global_position = origin
	direction = shot_direction.normalized()
	rotation = direction.angle()
	source_enemy = owner_enemy
	coordinator = shared_coordinator
	_timer = 0.9
	_active = true
	_fired = false
	_hit_player = false
	visible = true
	warning.visible = true
	warning.modulate = Color.WHITE
	beam.visible = false
	collision.disabled = true
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	add_to_group("rail_beams")
	add_to_group("evolved_pressure")


func _process(delta: float) -> void:
	if source_enemy == null or not is_instance_valid(source_enemy) or source_enemy.is_queued_for_deletion():
		despawn()
		return
	_timer -= delta
	if not _fired:
		warning.modulate.a = 0.35 + 0.65 * absf(sin(_timer * 22.0))
		if _timer <= 0.0:
			_fired = true
			_timer = 0.15
			warning.visible = false
			beam.visible = true
			collision_layer = 8
			collision.set_deferred("disabled", false)
	elif _timer <= 0.0:
		despawn()


func despawn() -> void:
	if not _active:
		return
	_active = false
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.release_major(source_enemy)
	visible = false
	call_deferred("_release")


func _release() -> void:
	remove_from_group("rail_beams")
	remove_from_group("evolved_pressure")
	collision.set_deferred("disabled", true)
	collision_layer = 0
	monitoring = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.release(self)


func _on_area_entered(area: Area2D) -> void:
	if _fired and not _hit_player and area.is_in_group("player"):
		_hit_player = true
		if area.has_method("receive_hostile_hit"):
			area.receive_hostile_hit(2.0)
