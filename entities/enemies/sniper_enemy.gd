extends BaseEnemy
## Ranged enemy that establishes a firing lane before retreating off screen.

const RAIL_BEAM_SCENE := preload("res://entities/enemies/enemy_rail_beam.tscn")

var entry_distance: float = 0.0
var hold_position: Vector2 = Vector2.ZERO
var hold_timer: float = 0.0
var shoot_timer: float = 0.0
var holding: bool = false
var has_withdrawn: bool = false
var ordinary_shots := 0
var shot_sequence := 0
var _aim_warning: Line2D
var _aim_timer := 0.0
var _locked_direction := Vector2.ZERO
var _rail_used := false

## Initializes the sniper enemy: sets the guaranteed 2-value orb and
## randomizes the first shot delay. Health, speed, and points come from
## the evolution-stage data in the scene, not this script.
func _ready() -> void:
	archetype_id = &"sniper"
	orb_value = 2
	guaranteed_orb = true
	super._ready()
	shoot_timer = randf_range(0.6, 1.2)

## Three-phase movement: enters the screen along spawn_direction until it
## reaches 115px depth, then holds position while oscillating perpendicular
## and firing aimed shots at the player every 1.55s. After 6 seconds of
## holding, withdraws at high speed along its original travel direction.
func _move(delta: float) -> void:
	if not holding:
		var movement_speed := 210.0 if has_withdrawn else speed
		var movement := spawn_direction * movement_speed * delta
		position += movement
		entry_distance += movement.length()
		if not has_withdrawn and entry_distance >= 115.0:
			holding = true
			hold_position = position
		return
	else:
		hold_timer += delta
		var perpendicular := Vector2(-spawn_direction.y, spawn_direction.x)
		position = hold_position + perpendicular * sin(hold_timer * 1.8) * 54.0
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			rotation = (player.global_position - global_position).angle() + PI * 0.5
		if _aim_timer > 0.0:
			_aim_timer -= delta
			if _aim_timer <= 0.0:
				_fire_locked_shot()
		else:
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				shoot_timer = 1.55
				_begin_aimed_shot()
		if hold_timer >= 6.0:
			holding = false
			has_withdrawn = true
			rotation = spawn_direction.angle() + PI * 0.5

## Fires a single high-speed bullet aimed directly at the player's
## current position. The bullet is colored neon cyan for visibility.
func _begin_aimed_shot() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if generation >= 4 and ordinary_shots >= 3 and not _rail_used:
		if _try_fire_rail(player):
			return
	var target := player.global_position
	if generation >= 3 and shot_sequence % 2 == 1:
		var player_velocity: Vector2 = player.get("velocity")
		var distance := global_position.distance_to(player.global_position)
		var lead_time := minf(distance / 550.0, 0.5)
		target += player_velocity * lead_time
	_locked_direction = (target - get_origin(&"Barrel")).normalized()
	if generation >= 2 and can_begin_special():
		_aim_timer = 0.5
		var warning_color := Color(1.0, 0.48, 0.12, 0.92) if generation == 2 else Color(1.0, 0.12, 0.25, 0.92)
		_aim_warning = make_line_warning(_locked_direction, 900.0, warning_color, 2.0 if generation == 2 else 3.0)
	else:
		_fire_locked_shot()


func _fire_locked_shot() -> void:
	if is_instance_valid(_aim_warning):
		_aim_warning.queue_free()
	var shot_speed := randf_range(430.0, 500.0) if generation == 1 else 550.0
	var shot_color := Color(2.8, 0.25, 0.35, 1.0) if generation >= 3 and shot_sequence % 2 == 1 else Color(2.5, 0.55, 0.15, 1.0)
	var bullet := fire_enemy_bullet(get_origin(&"Barrel"), _locked_direction, shot_speed, shot_color)
	if bullet == null:
		return
	ordinary_shots += 1
	shot_sequence += 1


func _try_fire_rail(player: Node2D) -> bool:
	if not can_begin_special() or not special_attack_coordinator.request_major(self):
		return false
	_rail_used = true
	var direction := (player.global_position - get_origin(&"Barrel")).normalized()
	var scene_root := get_tree().current_scene
	var beam = ObjectPool.acquire(RAIL_BEAM_SCENE, scene_root)
	if beam == null:
		special_attack_coordinator.release_major(self)
		return false
	beam.pool_activate(get_origin(&"Barrel"), direction, self, special_attack_coordinator)
	return true


func dev_trigger_ability() -> void:
	ordinary_shots = 3
	shoot_timer = 0.0
	visible_time = 1.0
