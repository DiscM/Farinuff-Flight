extends BaseEnemy
class_name BossEnemy
## Boss enemy — actively moves around the screen in phases, cycles through unique attack patterns.
## Regular (every 5th wave): 200 HP. Elite (every 10th wave): 500 HP.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var is_elite: bool = false

# --- Movement Phases ---
enum MovePhase { HOVER, DASH, STRAFE, DIVE }
var move_phase: MovePhase = MovePhase.HOVER
var move_timer: float = 0.0
var move_target: Vector2 = Vector2.ZERO
var strafe_angle: float = 0.0
var viewport_size: Vector2 = Vector2(720.0, 1024.0)

# --- Attack Patterns ---
enum AttackPattern { AIMED, RADIAL, SHOTGUN, SPIRAL, CROSS }
var attack_timer: float = 0.0
var attack_index: int = 0
var attack_sequence: Array = []
var spiral_angle: float = 0.0

var max_boss_health: int = 0

func _ready() -> void:
	if is_elite:
		max_health = 500
		points = 5000
		xp_value = 8000
	else:
		max_health = 200
		points = 1500
		xp_value = 2500
	speed = 0.0

	# Scale HP with player level at 25% per level
	var level_bonus := (GameManager.level - 1) * ceili(max_health * 0.25)
	max_health += level_bonus

	super._ready()
	max_boss_health = health

	viewport_size = get_viewport_rect().size
	_build_attack_sequence()
	attack_timer = 1.5  # initial delay before first attack
	move_target = Vector2(viewport_size.x / 2.0, 130.0)
	move_timer = 3.0

	SignalBus.boss_spawned.emit(health, max_boss_health)

func _build_attack_sequence() -> void:
	if is_elite:
		attack_sequence = [
			AttackPattern.AIMED, AttackPattern.RADIAL,
			AttackPattern.SPIRAL, AttackPattern.CROSS,
			AttackPattern.SHOTGUN, AttackPattern.AIMED,
			AttackPattern.SPIRAL, AttackPattern.RADIAL,
		]
	else:
		attack_sequence = [
			AttackPattern.AIMED, AttackPattern.RADIAL,
			AttackPattern.SHOTGUN, AttackPattern.CROSS,
			AttackPattern.AIMED, AttackPattern.RADIAL,
		]

# ---- Movement --------------------------------------------------------

func _move(delta: float) -> void:
	# Movement phase timer
	move_timer -= delta
	if move_timer <= 0.0:
		_pick_next_move_phase()
	_execute_move(delta)

	# Attack timer (independent of movement)
	attack_timer -= delta
	if attack_timer <= 0.0:
		_fire_current_pattern()
		attack_index = (attack_index + 1) % attack_sequence.size()
		attack_timer = _get_attack_delay()

	SignalBus.boss_health_changed.emit(health)

func _execute_move(delta: float) -> void:
	match move_phase:
		MovePhase.HOVER:
			# Gentle wide sway at the top of the screen
			var t := Time.get_ticks_msec() / 1000.0
			var sway_x := sin(t * 0.85) * 200.0
			var sway_y := sin(t * 0.5) * 35.0
			var home := Vector2(viewport_size.x / 2.0, 140.0) + Vector2(sway_x, sway_y)
			position = position.lerp(home, delta * 2.0)

		MovePhase.DASH:
			# Snap to a new position on screen
			position = position.lerp(move_target, delta * 9.0)

		MovePhase.STRAFE:
			# Circle-strafe around the upper half of the screen
			strafe_angle += delta * (2.0 if is_elite else 1.4)
			var radius := 210.0
			var center := Vector2(viewport_size.x / 2.0, 280.0)
			var target := center + Vector2(cos(strafe_angle), sin(strafe_angle) * 0.5) * radius
			position = position.lerp(target, delta * 3.5)

		MovePhase.DIVE:
			# Rush toward the lower screen then pull back up
			position = position.lerp(move_target, delta * 6.0)

func _pick_next_move_phase() -> void:
	# Weighted random selection — avoid picking the same phase twice in a row
	var options: Array = [MovePhase.HOVER, MovePhase.DASH, MovePhase.STRAFE, MovePhase.DIVE]
	options.erase(move_phase)  # don't repeat current phase
	move_phase = options[randi() % options.size()]

	match move_phase:
		MovePhase.HOVER:
			move_timer = randf_range(2.5, 4.0)

		MovePhase.DASH:
			move_target = Vector2(
				randf_range(100.0, viewport_size.x - 100.0),
				randf_range(80.0, 320.0)
			)
			move_timer = randf_range(1.0, 1.8)

		MovePhase.STRAFE:
			strafe_angle = randf() * TAU
			move_timer = randf_range(3.0, 5.0)

		MovePhase.DIVE:
			move_target = Vector2(
				randf_range(120.0, viewport_size.x - 120.0),
				randf_range(380.0, 580.0)
			)
			move_timer = 1.8

# ---- Attacks ---------------------------------------------------------

func _get_attack_delay() -> float:
	match attack_sequence[attack_index]:
		AttackPattern.SPIRAL:
			return 0.35 if is_elite else 0.5
		AttackPattern.RADIAL:
			return 1.8 if is_elite else 2.2
		AttackPattern.CROSS:
			return 1.6 if is_elite else 2.0
		_:
			return 1.4 if is_elite else 1.8

func _fire_current_pattern() -> void:
	match attack_sequence[attack_index]:
		AttackPattern.AIMED:   _fire_aimed()
		AttackPattern.RADIAL:  _fire_radial(16 if is_elite else 12)
		AttackPattern.SHOTGUN: _fire_shotgun()
		AttackPattern.SPIRAL:  _fire_spiral_tick()
		AttackPattern.CROSS:   _fire_cross()

func _fire_aimed() -> void:
	## Tight spread aimed at the player — rewards player Rear Gun by shooting from below.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player_pos: Vector2 = players[0].global_position
	var base_dir := (player_pos - global_position).normalized()
	var count := 5 if is_elite else 3
	for i in range(count):
		var off := (float(i) - float(count - 1) / 2.0) * 0.18
		_spawn_bullet(base_dir.rotated(off), 420.0)

func _fire_radial(count: int) -> void:
	## Full 360° burst — forces the player to dodge in all directions.
	for i in range(count):
		var angle := (TAU / count) * i
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 300.0)

func _fire_shotgun() -> void:
	## Wide downward cone — punishes players who sit directly below.
	var count := 7 if is_elite else 5
	for i in range(count):
		var off := (float(i) - float(count - 1) / 2.0) * 0.28
		_spawn_bullet(Vector2.DOWN.rotated(off), 360.0)

func _fire_spiral_tick() -> void:
	## Rotating spiral — covers a wide area over successive ticks.
	spiral_angle += TAU / 8.0
	var arms := 3 if is_elite else 2
	for i in range(arms):
		var angle := spiral_angle + (TAU / arms) * i
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 280.0)

func _fire_cross() -> void:
	## Cardinal + diagonal shots — 4-way for regular, 8-way for elite.
	var count := 8 if is_elite else 4
	for i in range(count):
		var angle := (TAU / count) * i
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 320.0)

func _spawn_bullet(dir: Vector2, spd: float) -> void:
	var bullet: Area2D = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.add_to_group("enemy_bullets")
	bullet.set_meta("direction", dir)
	bullet.set_meta("custom_speed", spd)
	get_tree().current_scene.call_deferred("add_child", bullet)

func _die() -> void:
	SignalBus.boss_died.emit(points)
	super._die()
