extends BaseEnemy
class_name BossEnemy
## Boss enemy — actively moves around the screen in phases, cycles through unique attack patterns.
## Regular bosses appear every 5th wave with archetype-specific base HP.
## Elite bosses appear every 10th wave with 125 HP, and the Wave 20 Tempest Core is a special encounter.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")
const TEMPEST_SECTION_SCRIPT := preload("res://entities/enemies/tempest_section.gd")
const TEMPEST_CORE_TEXTURE := preload("res://assets/sprites/generated/tempest_core_idle_strip.png")
const BOSS_HEALTH_SCALE_MULTIPLIER: float = 0.7

static var _telegraph_marker_texture: Texture2D
static var _section_burst_texture: Texture2D
static var _tempest_warning_texture: Texture2D

var is_elite: bool = false
var is_tempest_core: bool = false
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

enum TempestPhase { BARRIER, ARMAMENTS, CONDUITS, EXPOSED, OVERLOAD }
var tempest_phase: TempestPhase = TempestPhase.BARRIER
var tempest_sections: Array[Area2D] = []
var tempest_core_exposed: bool = false
var tempest_section_attack_timer: float = 0.0
var tempest_special_attack_timer: float = 0.0
var tempest_orbit_angle: float = 0.0
var tempest_damage_multiplier: float = 1.0
var tempest_warning_markers: Array[Sprite2D] = []
var tempest_overload_triggered: bool = false
var tempest_phase_transition_pending: bool = false

var max_boss_health: int = 0
var _dying: bool = false

## Configures the boss based on its type (regular, elite, or tempest core),
## builds the attack sequence, initializes movement state, creates the
## telegraph crosshair marker, and emits the boss_spawned signal to set up
## the HUD health bar.
func _ready() -> void:
	# Bosses should scale a little more gently than standard enemies because
	# their phase mechanics already extend fight length.
	health_scale_multiplier = BOSS_HEALTH_SCALE_MULTIPLIER
	if is_tempest_core:
		_configure_tempest_core()
	elif is_elite:
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

	if is_tempest_core:
		if sprite:
			sprite.texture = TEMPEST_CORE_TEXTURE

	viewport_size = get_viewport_rect().size
	_build_attack_sequence()
	if is_tempest_core:
		_start_tempest_phase(TempestPhase.BARRIER, false)
	attack_timer = 1.5  # initial delay before first attack
	move_target = Vector2(viewport_size.x / 2.0, 130.0)
	move_timer = 3.0

	telegraph_marker = Sprite2D.new()
	telegraph_marker.z_index = 5
	telegraph_marker.texture = _get_telegraph_marker_texture()
	telegraph_marker.visible = false
	var scene_root := get_tree().current_scene
	scene_root.call_deferred("add_child", telegraph_marker)

	SignalBus.boss_spawned.emit(health, max_boss_health, boss_title)


## Returns the cached red crosshair texture shown while the boss is
## telegraphing its attack. Built once and reused for every boss spawn.
func _get_telegraph_marker_texture() -> Texture2D:
	if _telegraph_marker_texture == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for i in range(64):
			if i > 26 and i < 38:
				continue
			if i > 8 and i < 56:
				img.set_pixel(32, i, Color(1.0, 0.1, 0.2, 0.8))
				img.set_pixel(31, i, Color(1.0, 0.1, 0.2, 0.8))
				img.set_pixel(i, 32, Color(1.0, 0.1, 0.2, 0.8))
				img.set_pixel(i, 31, Color(1.0, 0.1, 0.2, 0.8))
		for y in range(64):
			for x in range(64):
				var dist := Vector2(float(x) - 32.0, float(y) - 32.0).length()
				if dist > 26.0 and dist < 30.0:
					img.set_pixel(x, y, Color(1.0, 0.0, 0.1, 0.6))
		_telegraph_marker_texture = ImageTexture.create_from_image(img)
	return _telegraph_marker_texture


## Configures the Tempest Core boss (Wave 20): sets high HP, points,
## orb value, variant type, title, and bullet color.
func _configure_tempest_core() -> void:
	max_health = 300
	points = 12000
	orb_value = 18
	boss_variant = BossVariant.TEMPEST
	boss_title = "WAVE 20: TEMPEST CORE - SHIELD ARRAY"
	bullet_color = Color(0.2, 2.0, 3.0, 1.0)


## Selects the regular boss variant based on the current wave's encounter
## index (cycling through ASSAULT, BULWARK, TEMPEST), setting appropriate
## HP, title, and bullet color for each variant.
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

## Builds the ordered list of attack patterns the boss will cycle through,
## tailored to the boss type: tempest core, elite, or regular variant.
func _build_attack_sequence() -> void:
	if is_tempest_core:
		attack_sequence = [
			AttackPattern.CROSS, AttackPattern.RADIAL,
			AttackPattern.AIMED, AttackPattern.SWEEP,
		]
		return
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


## Transitions the Tempest Core boss to a new phase. Clears existing sections
## and warning markers, spawns new phase-specific sections with unique HP/color/orbit
## parameters, configures the attack sequence and timers for the phase, tints the
## core sprite, and announces the phase change to the HUD.
func _start_tempest_phase(next_phase: TempestPhase, announce: bool = true) -> void:
	tempest_phase = next_phase
	attack_index = 0
	_clear_tempest_sections()
	_clear_tempest_warnings()
	# Keep active shots alive across phase swaps; they already self-clean on exit.

	match tempest_phase:
		TempestPhase.BARRIER:
			boss_title = "WAVE 20: TEMPEST CORE - SHIELD ARRAY"
			tempest_core_exposed = false
			tempest_damage_multiplier = 0.0
			attack_sequence = [AttackPattern.CROSS, AttackPattern.RADIAL, AttackPattern.AIMED]
			_spawn_tempest_section("ShieldPylonA", Vector2(70.0, 0.0), 34, Vector2(27.0, 48.0), Color(0.2, 0.92, 1.0), 70.0, 0.0)
			_spawn_tempest_section("ShieldPylonB", Vector2(-35.0, 60.0), 34, Vector2(27.0, 48.0), Color(0.2, 0.92, 1.0), 70.0, TAU / 3.0)
			_spawn_tempest_section("ShieldPylonC", Vector2(-35.0, -60.0), 34, Vector2(27.0, 48.0), Color(0.2, 0.92, 1.0), 70.0, TAU * 2.0 / 3.0)
			tempest_section_attack_timer = 1.0
			tempest_special_attack_timer = 4.5
			if sprite:
				sprite.modulate = Color(0.76, 0.95, 1.0)
		TempestPhase.ARMAMENTS:
			boss_title = "TEMPEST CORE - STORM BATTERIES"
			tempest_core_exposed = false
			tempest_damage_multiplier = 0.0
			attack_sequence = [AttackPattern.SWEEP, AttackPattern.SHOTGUN, AttackPattern.SPIRAL, AttackPattern.AIMED]
			_spawn_tempest_section("LeftStormBattery", Vector2(-62.0, 20.0), 46, Vector2(33.0, 47.0), Color(1.0, 0.32, 0.72))
			_spawn_tempest_section("RightStormBattery", Vector2(62.0, 20.0), 46, Vector2(33.0, 47.0), Color(1.0, 0.32, 0.72))
			_spawn_tempest_section("VentralLauncher", Vector2(0.0, 68.0), 34, Vector2(36.0, 30.0), Color(1.0, 0.55, 0.16))
			tempest_section_attack_timer = 0.45
			tempest_special_attack_timer = 3.3
			if sprite:
				sprite.modulate = Color(1.0, 0.8, 0.95)
		TempestPhase.CONDUITS:
			boss_title = "TEMPEST CORE - FLUX CONDUITS"
			tempest_core_exposed = true
			tempest_damage_multiplier = 0.35
			attack_sequence = [AttackPattern.SPIRAL, AttackPattern.SWEEP, AttackPattern.AIMED]
			_spawn_tempest_section("FluxConduitA", Vector2(56.0, 0.0), 28, Vector2(25.0, 35.0), Color(0.32, 1.0, 0.55), 56.0, 0.0)
			_spawn_tempest_section("FluxConduitB", Vector2(-28.0, 48.0), 28, Vector2(25.0, 35.0), Color(0.32, 1.0, 0.55), 56.0, TAU / 3.0)
			_spawn_tempest_section("FluxConduitC", Vector2(-28.0, -48.0), 28, Vector2(25.0, 35.0), Color(0.32, 1.0, 0.55), 56.0, TAU * 2.0 / 3.0)
			tempest_section_attack_timer = 0.7
			tempest_special_attack_timer = 2.8
			if sprite:
				sprite.modulate = Color(0.68, 1.0, 0.8)
		TempestPhase.EXPOSED:
			boss_title = "TEMPEST CORE - CORE EXPOSED"
			tempest_core_exposed = true
			tempest_damage_multiplier = 1.0
			attack_sequence = [AttackPattern.SPIRAL, AttackPattern.RADIAL, AttackPattern.SWEEP, AttackPattern.AIMED, AttackPattern.CROSS]
			tempest_special_attack_timer = 2.2
			if sprite:
				sprite.modulate = Color(1.0, 0.68, 0.92)
		TempestPhase.OVERLOAD:
			boss_title = "TEMPEST CORE - OVERLOAD"
			tempest_core_exposed = true
			tempest_damage_multiplier = 1.0
			attack_sequence = [AttackPattern.SPIRAL, AttackPattern.SWEEP, AttackPattern.RADIAL, AttackPattern.SPIRAL, AttackPattern.SHOTGUN]
			tempest_special_attack_timer = 1.2
			bullet_color = Color(3.0, 0.25, 1.4, 1.0)
			if sprite:
				sprite.modulate = Color(1.5, 0.45, 0.8)

	attack_timer = 0.65
	if announce:
		SignalBus.boss_spawned.emit(health, max_boss_health, boss_title)


## Creates and attaches a TempestSection child node to the boss at the given
## local position, with the specified HP, collision size, color, and optional
## orbit parameters. Connects the section's destroyed signal to handle phase
## transitions.
func _spawn_tempest_section(section_name: String, local_position: Vector2, hp: int, size: Vector2, color: Color, orbit_radius: float = 0.0, orbit_offset: float = 0.0) -> void:
	var section = TEMPEST_SECTION_SCRIPT.new()
	add_child(section)
	section.position = local_position
	section.setup(section_name, hp, size, color)
	section.set_meta("orbit_radius", orbit_radius)
	section.set_meta("orbit_offset", orbit_offset)
	section.destroyed.connect(_on_tempest_section_destroyed)
	tempest_sections.append(section)


## Frees all existing tempest sections and clears the tracking array.
func _clear_tempest_sections() -> void:
	for section in tempest_sections:
		if is_instance_valid(section):
			section.queue_free()
	tempest_sections.clear()


## Frees all active storm-strike warning markers and clears the tracking array.
func _clear_tempest_warnings() -> void:
	for marker in tempest_warning_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	tempest_warning_markers.clear()


## Called when a tempest section is destroyed. Removes it from the tracking
## array, spawns a visual burst effect, and triggers the next phase transition
## when all sections of the current phase are destroyed.
func _on_tempest_section_destroyed(section: Area2D) -> void:
	tempest_sections.erase(section)
	_spawn_section_burst(section.global_position)
	if not tempest_sections.is_empty():
		return
	if tempest_phase == TempestPhase.BARRIER:
		_queue_tempest_phase_transition(TempestPhase.ARMAMENTS)
	elif tempest_phase == TempestPhase.ARMAMENTS:
		_queue_tempest_phase_transition(TempestPhase.CONDUITS)
	elif tempest_phase == TempestPhase.CONDUITS:
		_queue_tempest_phase_transition(TempestPhase.EXPOSED)


## Queues a deferred tempest phase transition, guarding against duplicate
## transitions and transitions during the death sequence.
func _queue_tempest_phase_transition(next_phase: TempestPhase) -> void:
	if tempest_phase_transition_pending or _dying:
		return
	tempest_phase_transition_pending = true
	_complete_tempest_phase_transition.call_deferred(tempest_phase, next_phase)


## Completes a deferred phase transition, verifying that the boss is still
## alive and hasn't already moved to a different phase before applying.
func _complete_tempest_phase_transition(previous_phase: TempestPhase, next_phase: TempestPhase) -> void:
	tempest_phase_transition_pending = false
	if _dying or tempest_phase != previous_phase:
		return
	_start_tempest_phase(next_phase)


## Creates an expanding ring visual effect at the given position when a
## tempest section is destroyed, providing clear feedback to the player.
func _spawn_section_burst(burst_position: Vector2) -> void:
	var ring := Sprite2D.new()
	ring.texture = _get_section_burst_texture()
	ring.global_position = burst_position
	var scene_root := get_tree().current_scene
	scene_root.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.24)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)


## Returns the cached cyan ring used when tempest sections are destroyed.
func _get_section_burst_texture() -> Texture2D:
	if _section_burst_texture == null:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(48):
			for x in range(48):
				var distance := Vector2(float(x) - 24.0, float(y) - 24.0).length()
				if distance > 16.0 and distance < 21.0:
					image.set_pixel(x, y, Color(0.4, 0.95, 1.0, 0.9))
		_section_burst_texture = ImageTexture.create_from_image(image)
	return _section_burst_texture

# ---- Movement --------------------------------------------------------

## Handles all per-frame boss movement. During telegraph phases, updates the
## spinning crosshair marker. Otherwise, executes the current movement phase
## and picks a new one when the timer expires. Also advances the attack timer
## independently and fires tempest section/special attacks if applicable.
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

	if is_tempest_core and not tempest_sections.is_empty():
		tempest_section_attack_timer -= delta
		if tempest_section_attack_timer <= 0.0:
			_fire_tempest_sections()

	if is_tempest_core:
		_update_tempest_systems(delta)


## Updates tempest-specific systems each frame: orbits sections around the
## core (BARRIER and CONDUITS phases), and manages the special storm-strike
## attack timer with phase-appropriate cooldowns.
func _update_tempest_systems(delta: float) -> void:
	var orbit_speed := 0.0
	if tempest_phase == TempestPhase.BARRIER:
		orbit_speed = 0.72
	elif tempest_phase == TempestPhase.CONDUITS:
		orbit_speed = -1.18

	if orbit_speed != 0.0:
		tempest_orbit_angle += delta * orbit_speed
		for section in tempest_sections:
			if not is_instance_valid(section):
				continue
			var orbit_radius := float(section.get_meta("orbit_radius", 0.0))
			if orbit_radius <= 0.0:
				continue
			var angle := tempest_orbit_angle + float(section.get_meta("orbit_offset", 0.0))
			section.position = Vector2(cos(angle), sin(angle)) * orbit_radius

	tempest_special_attack_timer -= delta
	if tempest_special_attack_timer <= 0.0:
		_begin_tempest_storm_strike()
		match tempest_phase:
			TempestPhase.BARRIER:
				tempest_special_attack_timer = 4.4
			TempestPhase.ARMAMENTS:
				tempest_special_attack_timer = 3.2
			TempestPhase.CONDUITS:
				tempest_special_attack_timer = 2.6
			TempestPhase.EXPOSED:
				tempest_special_attack_timer = 2.1
			TempestPhase.OVERLOAD:
				tempest_special_attack_timer = 1.15


## Begins a storm strike attack: places a pulsing crosshair warning marker
## at the player's current position, then fires a concentrated lane of
## bullets toward that position after a brief telegraph delay.
func _begin_tempest_storm_strike() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var target_position: Vector2 = player.global_position
	var marker := Sprite2D.new()
	marker.texture = _get_tempest_warning_texture()
	marker.global_position = target_position
	marker.z_index = 6
	var scene_root := get_tree().current_scene
	scene_root.add_child(marker)
	tempest_warning_markers.append(marker)
	var lane_count := 5
	if tempest_phase == TempestPhase.CONDUITS:
		lane_count = 7
	elif tempest_phase == TempestPhase.EXPOSED:
		lane_count = 9
	elif tempest_phase == TempestPhase.OVERLOAD:
		lane_count = 11
	var tween := marker.create_tween()
	tween.tween_property(marker, "modulate:a", 0.2, 0.18)
	tween.tween_property(marker, "modulate:a", 1.0, 0.18)
	tween.tween_callback(_release_tempest_storm_strike.bind(target_position, lane_count))
	tween.tween_property(marker, "scale", Vector2(1.65, 1.65), 0.12)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, 0.12)
	tween.tween_callback(marker.queue_free)


## Returns the cached warning marker texture used for Tempest Core tells.
func _get_tempest_warning_texture() -> Texture2D:
	if _tempest_warning_texture == null:
		var image := Image.create(84, 84, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(84):
			for x in range(84):
				var distance := Vector2(float(x) - 42.0, float(y) - 42.0).length()
				if distance > 35.0 and distance < 40.0:
					image.set_pixel(x, y, Color(0.2, 0.9, 1.0, 0.85))
				elif (absf(float(x) - 42.0) < 1.5 or absf(float(y) - 42.0) < 1.5) and distance < 29.0:
					image.set_pixel(x, y, Color(1.0, 0.32, 0.75, 0.8))
		_tempest_warning_texture = ImageTexture.create_from_image(image)
	return _tempest_warning_texture


## Fires the actual storm strike: a fan of bullets aimed at the telegraphed
## target position. Lane count increases in later phases for higher difficulty.
## In EXPOSED/OVERLOAD phases, also fires a supplementary radial burst.
func _release_tempest_storm_strike(target_position: Vector2, lane_count: int) -> void:
	if _dying:
		return
	var direction := (target_position - global_position).normalized()
	for i in range(lane_count):
		var offset := (float(i) - float(lane_count - 1) / 2.0) * 0.105
		_spawn_bullet(direction.rotated(offset), 500.0)
	if tempest_phase >= TempestPhase.EXPOSED:
		_fire_radial(10 if tempest_phase == TempestPhase.EXPOSED else 14)

## Executes the current movement phase: HOVER (sway at target), DASH (quick
## snap to a new position), STRAFE (circle-strafe around upper screen), or
## DIVE (rush toward lower screen). Each phase uses lerp-based movement with
## phase-appropriate speeds.
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

## Selects the next movement phase randomly (avoiding repeating the current
## phase), calculates the target position for the new phase, and starts the
## telegraph period where a crosshair marker shows the player where the boss
## is heading.
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

## Returns the delay in seconds before the next attack, varying by boss
## type, current attack pattern, and tempest phase for escalating pressure.
func _get_attack_delay() -> float:
	if is_tempest_core:
		if tempest_phase == TempestPhase.BARRIER:
			return 1.15
		if tempest_phase == TempestPhase.ARMAMENTS:
			return 0.62
		if tempest_phase == TempestPhase.CONDUITS:
			return 0.54
		if tempest_phase == TempestPhase.EXPOSED:
			return 0.46
		return 0.27
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

## Dispatches to the appropriate attack function based on the current
## position in the attack_sequence array.
func _fire_current_pattern() -> void:
	match attack_sequence[attack_index]:
		AttackPattern.AIMED:   _fire_aimed()
		AttackPattern.RADIAL:
			var bullet_count := 12
			if is_tempest_core:
				bullet_count = 24 if tempest_phase == TempestPhase.OVERLOAD else 18
			elif is_elite:
				bullet_count = 16
			_fire_radial(bullet_count)
		AttackPattern.SHOTGUN: _fire_shotgun()
		AttackPattern.SPIRAL:  _fire_spiral_tick()
		AttackPattern.CROSS:   _fire_cross()
		AttackPattern.SWEEP:   _fire_sweep()

## Fires a tight spread of bullets aimed at the player's current position.
## The spread count increases for elite and tempest core variants,
## rewarding players who dodge laterally.
func _fire_aimed() -> void:
	## Tight spread aimed at the player — rewards player Rear Gun by shooting from below.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var player_pos: Vector2 = player.global_position
	var base_dir := (player_pos - global_position).normalized()
	var count := 5 if is_elite else 3
	if is_tempest_core:
		count = 7 if tempest_phase >= TempestPhase.EXPOSED else 5
	for i in range(count):
		var off := (float(i) - float(count - 1) / 2.0) * 0.18
		_spawn_bullet(base_dir.rotated(off), 420.0)

## Fires a full 360° burst of evenly-spaced bullets, forcing the player
## to find gaps in the ring.
func _fire_radial(count: int) -> void:
	## Full 360° burst — forces the player to dodge in all directions.
	for i in range(count):
		var angle := (TAU / count) * i
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 300.0)

## Fires a wide downward cone of bullets, punishing players who sit
## directly below the boss. Count scales with boss type and phase.
func _fire_shotgun() -> void:
	## Wide downward cone — punishes players who sit directly below.
	var count := 7 if is_elite else 5
	if is_tempest_core:
		count = 11 if tempest_phase == TempestPhase.OVERLOAD else 9
	for i in range(count):
		var off := (float(i) - float(count - 1) / 2.0) * 0.28
		_spawn_bullet(Vector2.DOWN.rotated(off), 360.0)

## Fires one tick of a rotating spiral pattern. Multiple arms rotate
## together, covering a wide area over successive ticks. Arm count
## increases for elite and tempest core variants.
func _fire_spiral_tick() -> void:
	## Rotating spiral — covers a wide area over successive ticks.
	spiral_angle += TAU / 8.0
	var arms := 3 if is_elite else 2
	if is_tempest_core:
		arms = 4 if tempest_phase == TempestPhase.OVERLOAD else 3
	for i in range(arms):
		var angle := spiral_angle + (TAU / arms) * i
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 280.0)

## Fires a cross pattern: 4 cardinal directions for regular bosses,
## 8 (including diagonals) for elite, and 12 for late-phase tempest core.
func _fire_cross() -> void:
	## Cardinal + diagonal shots — 4-way for regular, 8-way for elite.
	var count := 8 if is_elite else 4
	if is_tempest_core and tempest_phase >= TempestPhase.EXPOSED:
		count = 12
	for i in range(count):
		var angle := (TAU / count) * i
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 320.0)

## Fires a rotating fan of bullets that sweeps back and forth, creating
## moving safe gaps instead of a static burst. Shot count and rotation
## speed scale with boss type.
func _fire_sweep() -> void:
	## A rotating fan creates moving safe gaps instead of a static burst.
	spiral_angle += 0.34 if is_elite else 0.48
	var shot_count := 5 if is_elite else 3
	if is_tempest_core:
		spiral_angle += 0.14
		shot_count = 7 if tempest_phase == TempestPhase.OVERLOAD else 5
	var base_direction := Vector2.DOWN.rotated(sin(spiral_angle) * 0.9)
	for i in range(shot_count):
		var offset := (float(i) - float(shot_count - 1) / 2.0) * 0.22
		_spawn_bullet(base_direction.rotated(offset), 350.0)

## Spawns a single enemy bullet from the boss's current global position
## in the given direction at the given speed.
func _spawn_bullet(dir: Vector2, spd: float) -> void:
	_spawn_bullet_from(global_position, dir, spd)


## Spawns a single enemy bullet from an arbitrary origin position (used by
## tempest sections firing from their own positions). Adds slight speed
## randomization for visual variety.
func _spawn_bullet_from(origin: Vector2, dir: Vector2, spd: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var bullet = ObjectPool.acquire(ENEMY_BULLET_SCENE, scene_root)
	if bullet == null:
		return
	bullet.pool_activate(origin, dir, spd * randf_range(0.92, 1.08), bullet_color)


## Fires aimed shots from each active tempest section toward the player.
## Shot patterns vary by phase: single shots in BARRIER, triple fan in
## ARMAMENTS, and tangential pairs in CONDUITS.
func _fire_tempest_sections() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var player_position: Vector2 = player.global_position
	for section in tempest_sections:
		if not is_instance_valid(section):
			continue
		var aim_direction := (player_position - section.global_position).normalized()
		if tempest_phase == TempestPhase.BARRIER:
			_spawn_bullet_from(section.global_position, aim_direction, 360.0)
		elif tempest_phase == TempestPhase.ARMAMENTS:
			_spawn_bullet_from(section.global_position, aim_direction, 400.0)
			_spawn_bullet_from(section.global_position, aim_direction.rotated(-0.18), 420.0)
			_spawn_bullet_from(section.global_position, aim_direction.rotated(0.18), 420.0)
		elif tempest_phase == TempestPhase.CONDUITS:
			var tangent := section.position.normalized().rotated(PI / 2.0)
			_spawn_bullet_from(section.global_position, tangent, 350.0)
			_spawn_bullet_from(section.global_position, -tangent, 350.0)
	tempest_section_attack_timer = 0.9 if tempest_phase == TempestPhase.BARRIER else (0.64 if tempest_phase == TempestPhase.CONDUITS else 0.48)


## Override: boss damage handling with tempest-specific logic. When the core
## is shielded (damage_multiplier 0), shows a visual "immune" flash.
## Partial damage is applied during CONDUITS phase. Triggers the OVERLOAD
## phase when health drops below 42%.
func take_damage(amount: int) -> void:
	if _dying:
		return
	if is_tempest_core and tempest_damage_multiplier <= 0.0:
		if sprite:
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 2.0), 0.04)
			tween.tween_property(sprite, "modulate", Color(0.76, 0.95, 1.0) if tempest_phase == TempestPhase.BARRIER else Color(1.0, 0.8, 0.95), 0.1)
		return
	if is_tempest_core and tempest_damage_multiplier < 1.0:
		var reduced_damage := mini(maxi(1, ceili(float(amount) * tempest_damage_multiplier)), 12)
		super.take_damage(reduced_damage)
	else:
		super.take_damage(amount)
	if health > 0:
		SignalBus.boss_health_changed.emit(health)
	if is_tempest_core and health > 0 and not tempest_overload_triggered and health <= int(max_boss_health * 0.42):
		tempest_overload_triggered = true
		_start_tempest_phase(TempestPhase.OVERLOAD)


## Override: boss death sequence. Guards against re-entry from multiple
## simultaneous hits. Immediately hides the boss and disables collision,
## cleans up the telegraph marker, tempest sections, and warnings, spawns
## death rewards (orb + explosion), emits boss_died, and deferred-frees
## the node.
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
	_clear_tempest_sections()
	_clear_tempest_warnings()
	# Let live projectiles finish their normal lifecycle instead of being purged here.

	# Spawn death orbs and explosion (mirrors base_enemy._die() without queue_free)
	SignalBus.enemy_killed.emit(points, global_position)
	var scene_root := get_tree().current_scene
	if guaranteed_orb or randf() < 0.6:
		var orb: Area2D = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position
		orb.orb_value = orb_value
		scene_root.call_deferred("add_child", orb)
	var explosion = ObjectPool.acquire(EXPLOSION_SCENE, scene_root)
	if explosion != null and explosion.has_method("play_at"):
		explosion.play_at(global_position)

	# Emit the boss signal AFTER hiding, so the pause triggered by elite upgrade
	# doesn't block any remaining cleanup.
	SignalBus.boss_died.emit(points)

	# Free the node — deferred so we're safely outside any signal handlers.
	call_deferred("queue_free")

## Override: player collision deals fixed damage instead of instant death.
## Bosses take 10 damage from player ram and standard bullet damage from
## player projectiles (1 + bonus_damage).
func _on_area_entered(area: Area2D) -> void:
	if _dying or is_queued_for_deletion():
		return
	if area.is_in_group("player"):
		take_damage(10)
	elif area.collision_layer & 4 != 0:
		take_damage(1 + GameManager.bonus_damage)
