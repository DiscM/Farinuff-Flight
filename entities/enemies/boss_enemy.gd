extends BaseEnemy
class_name BossEnemy
## Boss enemy — large, high HP, cycles through 3 unique attack phases.
## Regular version every 5 waves; Elite (is_elite=true) every 10 waves.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var is_elite: bool = false

# Attack state
var phase_timer: float = 0.0
var current_phase: int = 0   # 0 = aimed, 1 = radial, 2 = spiral (elite)
var phase_durations: Array[float] = [2.5, 2.0, 2.8]

# Oscillation movement (boss sways side to side)
var sway_time: float = 0.0
var viewport_width: float = 720.0
var target_y: float = 140.0  # boss parks near top

# Track health for HUD bar
var max_boss_health: int = 0

func _ready() -> void:
	if is_elite:
		max_health = 120
		speed = 0.0
		points = 2000
		xp_value = 3000
	else:
		max_health = 50
		speed = 0.0
		points = 800
		xp_value = 1200

	# Scale HP with player level (same formula as base, but lighter: 15%)
	var level_bonus := (GameManager.level - 1) * ceili(max_health * 0.15)
	max_health += level_bonus

	super._ready()
	max_boss_health = health

	viewport_width = get_viewport_rect().size.x
	phase_timer = phase_durations[0]

	SignalBus.boss_spawned.emit(health, max_boss_health)

func _move(delta: float) -> void:
	# Drift to target Y position, then sway horizontally
	if position.y < target_y:
		position.y += 120.0 * delta
	else:
		position.y = target_y

	sway_time += delta
	var sway_x := sin(sway_time * 0.8) * (viewport_width * 0.3)
	position.x = lerp(position.x, viewport_width / 2.0 + sway_x, delta * 1.5)

	# Attack cycling
	phase_timer -= delta
	if phase_timer <= 0.0:
		_fire_phase(current_phase)
		current_phase = _next_phase()
		phase_timer = phase_durations[current_phase]
	
	# Emit HP for HUD bar
	SignalBus.boss_health_changed.emit(health)

func _next_phase() -> int:
	if is_elite:
		return (current_phase + 1) % 3
	else:
		return (current_phase + 1) % 2  # only phases 0 and 1

func _fire_phase(phase: int) -> void:
	match phase:
		0:  # Aimed triple-shot at player
			_fire_aimed()
		1:  # 12-way radial burst
			_fire_radial(12 if is_elite else 8)
		2:  # Spiral volley (elite only)
			_fire_spiral()

func _fire_aimed() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player_pos: Vector2 = players[0].global_position
	var base_dir := (player_pos - global_position).normalized()
	# Triple spread
	var offsets := [-0.25, 0.0, 0.25]
	for off in offsets:
		var dir := base_dir.rotated(off)
		_spawn_bullet(dir, 380.0)

func _fire_radial(count: int) -> void:
	for i in range(count):
		var angle := (TAU / count) * i
		var dir := Vector2(cos(angle), sin(angle))
		_spawn_bullet(dir, 300.0)

func _fire_spiral() -> void:
	# 3 sequential bursts offset 120° each, delayed slightly
	for burst in range(3):
		for i in range(5):
			var angle := (TAU / 5.0) * i + (TAU / 3.0) * burst
			var dir := Vector2(cos(angle), sin(angle))
			var bullet := _spawn_bullet(dir, 260.0, true)
			# Slight delay per burst handled by staggering in angle only

func _spawn_bullet(dir: Vector2, spd: float, _deferred: bool = false) -> Area2D:
	var bullet: Area2D = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.add_to_group("enemy_bullets")
	bullet.set_meta("direction", dir)
	bullet.set_meta("custom_speed", spd)
	get_tree().current_scene.call_deferred("add_child", bullet)
	return bullet

func _die() -> void:
	SignalBus.boss_died.emit(points)
	super._die()
