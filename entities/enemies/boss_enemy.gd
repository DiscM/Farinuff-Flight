extends BaseEnemy
class_name BossEnemy
## Boss enemy — actively moves around the screen in phases, cycles through unique attack patterns.
## Regular (every 5th wave): 200 HP. Elite (every 10th wave): 500 HP.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var is_elite: bool = false
enum BossVariant { ASSAULT, BULWARK, TEMPEST }
var boss_variant: BossVariant = BossVariant.ASSAULT
var boss_title: String = "BOSS: ASSAULT WING"
var bullet_color: Color = Color(3.0, 0.2, 1.5, 1.0)

# --- Movement Phases ---
enum MovePhase { HOVER, DASH, STRAFE, DIVE }
var move_phase: MovePhase = MovePhase.HOVER
var move_timer: float = 0.0
var move_target: Vector2 = Vector2.ZERO
var strafe_angle: float = 0.0
var viewport_size: Vector2 = Vector2(720.0, 1024.0)

var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
var pattern_active: bool = false
var pattern_time: float = 0.0
var next_move_phase: MovePhase = MovePhase.HOVER
var telegraph_marker: Sprite2D = null

# --- Attack Patterns ---
enum AttackPattern { AIMED, RADIAL, SHOTGUN, SPIRAL, CROSS, SWEEP }
var attack_timer: float = 0.0
var attack_index: int = 0
var attack_sequence: Array = []
var spiral_angle: float = 0.0

var max_boss_health: int = 0
var _dying: bool = false

func _ready() -> void:
	if is_elite:
		max_health = 125
		points = 5000
		orb_value = 10
		boss_variant = BossVariant.TEMPEST
		boss_title = "ELITE BOSS: VOID HARBINGER"
	else:
		_configure_regular_variant()
		points = 1500
		orb_value = 5
	guaranteed_orb = true
	speed = 0.0

	super._ready()
	max_boss_health = health

	viewport_size = get_viewport_rect().size
	_build_attack_sequence()
	attack_timer = 1.5  # initial delay before first attack
	move_target = Vector2(viewport_size.x / 2.0, 130.0)
	move_timer = 3.0

	telegraph_marker = Sprite2D.new()
	telegraph_marker.z_index = 5
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for i in range(64):
		if i > 26 and i < 38: continue
		if i > 8 and i < 56:
			img.set_pixel(32, i, Color(1.0, 0.1, 0.2, 0.8))
			img.set_pixel(31, i, Color(1.0, 0.1, 0.2, 0.8))
			img.set_pixel(i, 32, Color(1.0, 0.1, 0.2, 0.8))
			img.set_pixel(i, 31, Color(1.0, 0.1, 0.2, 0.8))
	for y in range(64):
		for x in range(64):
			var dist = Vector2(x-32, y-32).length()
			if dist > 26.0 and dist < 30.0:
				img.set_pixel(x, y, Color(1.0, 0.0, 0.1, 0.6))
	
	telegraph_marker.texture = ImageTexture.create_from_image(img)
	telegraph_marker.visible = false
	get_tree().current_scene.call_deferred("add_child", telegraph_marker)

	SignalBus.boss_spawned.emit(health, max_boss_health, boss_title)

func _configure_regular_variant() -> void:
	var encounter_index := floori(float(GameManager.current_wave) / 5.0)
	match encounter_index % 3:
		1:
			boss_variant = BossVariant.ASSAULT
			boss_title = "BOSS: ASSAULT WING"
			max_health = 46
			bullet_color = Color(3.0, 0.35, 0.35, 1.0)
		2:
			boss_variant = BossVariant.BULWARK
			boss_title = "BOSS: BULWARK ARRAY"
			max_health = 62
			bullet_color = Color(2.0, 0.4, 3.0, 1.0)
		_:
			boss_variant = BossVariant.TEMPEST
			boss_title = "BOSS: VOID HARBINGER"
			max_health = 52
			bullet_color = Color(0.2, 2.0, 3.0, 1.0)

func _build_attack_sequence() -> void:
	if is_elite:
		attack_sequence = [
			AttackPattern.AIMED, AttackPattern.RADIAL,
			AttackPattern.SPIRAL, AttackPattern.CROSS,
			AttackPattern.SWEEP, AttackPattern.AIMED,
			AttackPattern.SPIRAL, AttackPattern.RADIAL,
		]
		return
	match boss_variant:
		BossVariant.ASSAULT:
			attack_sequence = [
				AttackPattern.AIMED, AttackPattern.SHOTGUN,
				AttackPattern.AIMED, AttackPattern.CROSS,
				AttackPattern.SHOTGUN,
			]
		BossVariant.BULWARK:
			attack_sequence = [
				AttackPattern.RADIAL, AttackPattern.CROSS,
				AttackPattern.RADIAL, AttackPattern.SHOTGUN,
			]
		BossVariant.TEMPEST:
			attack_sequence = [
				AttackPattern.SPIRAL, AttackPattern.SWEEP,
				AttackPattern.AIMED, AttackPattern.SPIRAL,
				AttackPattern.RADIAL,
			]

# ---- Movement --------------------------------------------------------

func _move(delta: float) -> void:
	if is_telegraphing:
		telegraph_timer -= delta
		if is_instance_valid(telegraph_marker):
			telegraph_marker.rotation -= delta * 3.0 # Spinning crosshair
			telegraph_marker.modulate.a = 0.6 + 0.4 * sin(telegraph_timer * 15.0) # Pulsing effect

		if telegraph_timer <= 0.0:
			is_telegraphing = false
			move_phase = next_move_phase
			if is_instance_valid(telegraph_marker):
				telegraph_marker.visible = false
	else:
		# Execute movement FIRST with the current move_target, THEN check the timer.
		# If we checked the timer first, _pick_next_move_phase() would overwrite move_target
		# and _execute_move would snap toward the new target for one frame — the visible teleport.
		_execute_move(delta)
		move_timer -= delta
		if move_timer <= 0.0:
			_pick_next_move_phase()

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
			var target := move_target
			# Fly directly to the telegraphed target first
			if position.distance_to(move_target) < 30.0:
				pattern_active = true
			
			if pattern_active:
				pattern_time += delta
				# Blend the sway in so it doesn't instantly jump
				var blend := minf(pattern_time, 1.0)
				var sway_x := sin(pattern_time * 0.85) * 200.0
				var sway_y := sin(pattern_time * 0.5) * 35.0
				target += Vector2(sway_x, sway_y) * blend
				
			position = position.lerp(target, delta * (4.0 if not pattern_active else 2.0))

		MovePhase.DASH:
			# Snap to a new position on screen
			position = position.lerp(move_target, delta * 9.0)

		MovePhase.STRAFE:
			# Circle-strafe around the upper half of the screen
			var radius := 210.0
			var center := Vector2(viewport_size.x / 2.0, 280.0)
			
			# Fly to the exact telegraphed spot on the circle before we start orbiting
			if position.distance_to(move_target) < 30.0:
				pattern_active = true
				
			if pattern_active:
				strafe_angle += delta * (2.0 if is_elite else 1.4)
				
			var target := center + Vector2(cos(strafe_angle), sin(strafe_angle) * 0.5) * radius
			position = position.lerp(target, delta * (5.0 if not pattern_active else 3.5))

		MovePhase.DIVE:
			# Rush toward the lower screen then pull back up
			position = position.lerp(move_target, delta * 6.0)

func _pick_next_move_phase() -> void:
	# Weighted random selection — avoid picking the same phase twice in a row
	var options: Array = [MovePhase.HOVER, MovePhase.DASH, MovePhase.STRAFE, MovePhase.DIVE]
	options.erase(move_phase)  # don't repeat current phase
	next_move_phase = options[randi() % options.size()]

	# Pre-calculate the starting position of the *next* phase
	match next_move_phase:
		MovePhase.HOVER:
			move_timer = randf_range(2.5, 4.0)
			move_target = Vector2(viewport_size.x / 2.0, 140.0)
		MovePhase.DASH:
			move_target = Vector2(
				randf_range(100.0, viewport_size.x - 100.0),
				randf_range(80.0, 320.0)
			)
			move_timer = randf_range(1.0, 1.8)
		MovePhase.STRAFE:
			strafe_angle = randf() * TAU
			move_timer = randf_range(3.0, 5.0)
			var radius := 210.0
			var center := Vector2(viewport_size.x / 2.0, 280.0)
			move_target = center + Vector2(cos(strafe_angle), sin(strafe_angle) * 0.5) * radius
		MovePhase.DIVE:
			move_target = Vector2(
				randf_range(120.0, viewport_size.x - 120.0),
				randf_range(380.0, 580.0)
			)
			move_timer = 1.8

	is_telegraphing = true
	telegraph_timer = 3.0
	pattern_active = false
	pattern_time = 0.0
	
	if is_instance_valid(telegraph_marker):
		telegraph_marker.global_position = move_target
		telegraph_marker.visible = true

# ---- Attacks ---------------------------------------------------------

func _get_attack_delay() -> float:
	match attack_sequence[attack_index]:
		AttackPattern.SPIRAL:
			return 0.35 if is_elite else 0.5
		AttackPattern.RADIAL:
			return 1.8 if is_elite else 2.2
		AttackPattern.CROSS:
			return 1.6 if is_elite else 2.0
		AttackPattern.SWEEP:
			return 0.75 if is_elite else 1.0
		_:
			return 1.4 if is_elite else 1.8

func _fire_current_pattern() -> void:
	match attack_sequence[attack_index]:
		AttackPattern.AIMED:   _fire_aimed()
		AttackPattern.RADIAL:  _fire_radial(16 if is_elite else 12)
		AttackPattern.SHOTGUN: _fire_shotgun()
		AttackPattern.SPIRAL:  _fire_spiral_tick()
		AttackPattern.CROSS:   _fire_cross()
		AttackPattern.SWEEP:   _fire_sweep()

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

func _fire_sweep() -> void:
	## A rotating fan creates moving safe gaps instead of a static burst.
	spiral_angle += 0.34 if is_elite else 0.48
	var shot_count := 5 if is_elite else 3
	var base_direction := Vector2.DOWN.rotated(sin(spiral_angle) * 0.9)
	for i in range(shot_count):
		var offset := (float(i) - float(shot_count - 1) / 2.0) * 0.22
		_spawn_bullet(base_direction.rotated(offset), 350.0)

func _spawn_bullet(dir: Vector2, spd: float) -> void:
	var bullet: Area2D = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.add_to_group("enemy_bullets")
	bullet.set_meta("direction", dir)
	bullet.set_meta("custom_speed", spd * randf_range(0.92, 1.08))
	bullet.set_meta("bullet_color", bullet_color)
	get_tree().current_scene.call_deferred("add_child", bullet)

func _die() -> void:
	# Guard against re-entry (e.g. multiple bullets hitting on the same frame)
	if _dying:
		return
	_dying = true

	# Immediately make the boss non-collidable and invisible so it can't
	# be interacted with again, even if queue_free is blocked by a tree pause.
	visible = false
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

	# Clean up the telegraph marker
	if is_instance_valid(telegraph_marker):
		telegraph_marker.queue_free()

	# Remove all bullets this boss fired so they don't orphan on screen
	get_tree().call_group("enemy_bullets", "queue_free")

	# Spawn death orbs and explosion (mirrors base_enemy._die() without queue_free)
	SignalBus.enemy_killed.emit(points, global_position)
	if guaranteed_orb or randf() < 0.6:
		var orb: Area2D = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position
		orb.orb_value = orb_value
		get_tree().current_scene.call_deferred("add_child", orb)
	var explosion_scene := preload("res://effects/explosion.tscn")
	var explosion := explosion_scene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", explosion)

	# Emit the boss signal AFTER hiding, so the pause triggered by elite upgrade
	# doesn't block any remaining cleanup.
	SignalBus.boss_died.emit(points)

	# Free the node — deferred so we're safely outside any signal handlers.
	call_deferred("queue_free")

## Override: player collision deals fixed damage instead of instant death.
func _on_area_entered(area: Area2D) -> void:
	if _dying or is_queued_for_deletion():
		return
	if area.is_in_group("player"):
		take_damage(10)
	elif area.collision_layer & 4:
		take_damage(1 + GameManager.bonus_damage)
