extends RefCounted
## Bounded weapon releases driven only by the owning FSM's flight progress.
## This has no timer or state transitions of its own.
const Tactics := preload("res://systems/enemy_tactics_3d.gd")
const Tell := preload("res://effects/enemy_maneuver_tell_3d.gd")
const Projectiles := preload("res://systems/projectile_manager_3d.gd")
const Shot := preload("res://entities/projectiles/projectile_3d.gd")
const SHOT_TINT := Color(1.0, 0.52, 0.16)
# Each pair is flight progress and a baseline-screen firing angle in degrees.
const PATTERNS := {
	Tactics.Action.IMMELMANN: {
		"label": "TURN BURST", "speed": 430.0,
		"shots": [Vector2(0.66, 0.0), Vector2(0.84, 0.0)],
	},
	Tactics.Action.CORKSCREW: {
		"label": "SWEEP BURST", "speed": 390.0,
		"shots": [Vector2(0.28, -10.0), Vector2(0.42, -3.5), Vector2(0.56, 3.5), Vector2(0.70, 10.0)],
	},
	Tactics.Action.LOW_YO_YO: {
		"label": "DIVE VOLLEY", "speed": 410.0,
		"shots": [Vector2(0.62, -14.0), Vector2(0.62, 0.0), Vector2(0.62, 14.0)],
	},
}

var _action: Tactics.Action = Tactics.Action.NONE
var _target := Vector3.ZERO
var _released := 0
var _tell: Tell


func prepare(action: Tactics.Action, target: Vector3) -> void:
	cancel()
	if PATTERNS.has(action):
		_action = action
		_target = target
		_target.y = 0.0


func cancel() -> void:
	_action = Tactics.Action.NONE
	_released = 0
	if is_instance_valid(_tell):
		_tell.hide()


func update_warning(actor: Node3D) -> void:
	if _action == Tactics.Action.NONE:
		return
	var pattern: Dictionary = PATTERNS[_action]
	var shots: Array = pattern.shots
	if _released >= shots.size():
		if is_instance_valid(_tell):
			_tell.hide()
		return
	if not is_instance_valid(_tell):
		_tell = Tell.new()
		actor.add_child(_tell)
		_tell.name = "ManeuverAttackTell"
	var lanes := PackedVector3Array()
	for index in range(_released, shots.size()):
		var event: Vector2 = shots[index]
		var origin: Vector3 = actor._tactics.sample_path(event.x)
		var reach := maxf(origin.distance_to(_target), 8.0)
		lanes.append(origin)
		lanes.append(origin + _direction(actor, origin, event.y) * reach)
	_tell.present_attack(lanes, _target, "%s · %d" % [pattern.label, shots.size() - _released])


func advance(actor: Node3D, progress: float) -> void:
	if _action == Tactics.Action.NONE or not actor.is_active or not GameManager.is_game_active:
		return
	if not actor.is_maneuver_committed() or actor.state != actor._tactics._flight_state or actor._tactics._action != _action:
		cancel()
		return
	var pattern: Dictionary = PATTERNS[_action]
	var shots: Array = pattern.shots
	var before := _released
	var manager := actor.get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as Projectiles
	var muzzle := actor.get_socket(&"MuzzleCenter") as Marker3D
	while _released < shots.size() and progress >= shots[_released].x:
		var event: Vector2 = shots[_released]
		_released += 1
		# Consume rejected releases too: pool saturation must not defer a burst
		# until after its advertised window or grow the pool.
		if manager == null or not manager.is_ready or muzzle == null:
			continue
		# Sample each release along the route even when one slow frame crosses
		# several shots. The animated socket stays attached to the rolling hull.
		var origin: Vector3 = actor._tactics.sample_path(event.x) + (muzzle.global_position - actor.global_position)
		origin.y = 0.0
		manager.fire_enemy_projectile(origin, _direction(actor, origin, event.y), pattern.speed, Shot.Motion.STRAIGHT, SHOT_TINT)
	if _released != before:
		actor.play_motion(&"attack")
		update_warning(actor)


func _direction(actor: Node3D, origin: Vector3, degrees: float) -> Vector3:
	var aim: Vector2 = actor._flight_space.combat_motion_to_screen(_target - origin).normalized()
	if aim.is_zero_approx():
		aim = actor._flight_space.combat_motion_to_screen(actor._heading).normalized()
	return actor._flight_space.screen_motion_to_combat(aim.rotated(deg_to_rad(degrees) * actor._tactics._direction)).normalized()


func debug_state() -> Dictionary:
	return {"pattern": PATTERNS[_action].label if _action != Tactics.Action.NONE else "",
		"released": _released, "target": _target}
