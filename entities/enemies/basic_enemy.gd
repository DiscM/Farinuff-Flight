extends BaseEnemy
## Basic lineage: steering, locked charge, then Apex death fragments.

const SEEKER_FRAGMENT_SCENE := preload("res://entities/enemies/seeker_fragment.tscn")

var _charge_used := false
var _charge_state := 0
var _charge_timer := 0.0
var _charge_direction := Vector2.ZERO
var _charge_warning: Line2D


func _ready() -> void:
	archetype_id = &"basic"
	super._ready()


func _move(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if generation >= 2 and _charge_state == 0 and player != null:
		var desired := (player.global_position - global_position).normalized()
		spawn_direction = spawn_direction.rotated(clampf(
			spawn_direction.angle_to(desired), -deg_to_rad(40.0) * delta, deg_to_rad(40.0) * delta))
		rotation = spawn_direction.angle() + PI * 0.5

	if generation >= 3 and not _charge_used and _charge_state == 0 and player != null:
		if can_begin_special() and global_position.distance_to(player.global_position) <= 240.0:
			_charge_used = true
			_charge_state = 1
			_charge_timer = 0.55
			_charge_direction = (player.global_position - global_position).normalized()
			_charge_warning = make_line_warning(_charge_direction, 260.0, Color(1.0, 0.3, 0.12, 0.9), 3.0)

	if _charge_state == 1:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_charge_state = 2
			_charge_timer = 0.45
			if is_instance_valid(_charge_warning):
				_charge_warning.queue_free()
	elif _charge_state == 2:
		position += _charge_direction * speed * 2.2 * delta
		rotation = _charge_direction.angle() + PI * 0.5
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_charge_state = 3
			spawn_direction = _charge_direction
	else:
		super._move(delta)


func _finish_death() -> void:
	if generation >= 4 and not suppress_death_effects:
		_release_fragments()
	super._finish_death()


func _release_fragments() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for definition in [
		[&"FragmentLeft", -0.36],
		[&"FragmentRight", 0.36],
	]:
		if not special_attack_coordinator.request_hazard(&"seeker_fragment"):
			break
		var fragment := ObjectPool.acquire(SEEKER_FRAGMENT_SCENE, scene_root)
		if fragment == null:
			special_attack_coordinator.release_hazard(&"seeker_fragment")
			continue
		var initial := spawn_direction.rotated(float(definition[1]))
		fragment.pool_activate(get_origin(definition[0]), initial, special_attack_coordinator)


func dev_trigger_ability() -> void:
	_charge_used = false
	visible_time = 1.0
