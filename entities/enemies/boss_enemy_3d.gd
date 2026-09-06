extends BasicEnemy3D
## Five native command hulls. Health phases intensify patterns; destructible
## weapon pods reduce volley density and remove Bulwark/Core damage resistance.
const Section := preload("res://entities/enemies/boss_section_3d.gd")
const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const TITLES := ["ASSAULT COMMANDER", "IRON BULWARK", "TEMPEST", "VOID HARBINGER", "TEMPEST CORE"]
var max_health := 60
var variant := 0
var phase := 0
var _boss_time := 0.0
var _anchor := Vector3.ZERO
var _volley_timer := 1.8
var _warning_timer := 0.0
var _volley_index := 0
var _locked_aim := Vector2.DOWN
var _sections: Array[Section] = []

func _ready() -> void:
	super._ready()
	for section in $Attachments/Sections.get_children():
		_sections.append(section as Section)

func _is_basic_lineage() -> bool:
	return false

func _configure_movement() -> void:
	_anchor = global_position
	velocity = Vector3.ZERO
	_boss_time = 0.0

func activate_generation(space: FlightSpace, origin: Vector3, direction: Vector3, stage: int) -> bool:
	if not super.activate_generation(space, origin, direction, stage):
		return false
	variant = (maxi(floori(GameManager.current_wave / 5.0), 1) - 1) % TITLES.size()
	max_health = roundi((45.0 + GameManager.current_wave * 3.0) * GameManager.get_enemy_health_multiplier())
	health = max_health
	phase = 0
	_volley_index = 0
	_volley_timer = 1.8
	_warning_timer = 0.0
	$Attachments/Warning.scale = Vector3.ONE
	for index in visuals.get_child_count():
		visuals.get_child(index).visible = index == variant
	$Attachments/Warning.hide()
	for section in _sections:
		if variant > 0:
			section.activate(maxi(8, floori(max_health / 6.0)))
		else:
			section.deactivate()
	add_to_group(&"native_3d_bosses")
	SignalBus.boss_spawned.emit(health, max_health, TITLES[variant])
	return true

func _advance_movement(delta: float) -> void:
	_boss_time += delta
	var amplitude := 70.0 if variant == 1 else 130.0
	global_position = _anchor + _flight_space.screen_motion_to_combat(Vector2(sin(_boss_time * 0.6) * amplitude, sin(_boss_time * 0.35) * 28.0))
	if _warning_timer > 0.0:
		_warning_timer -= delta
		$Attachments/Warning.scale = Vector3.ONE * (1.0 + 0.12 * sin(_boss_time * 35.0))
		if _warning_timer <= 0.0:
			$Attachments/Warning.hide()
			_fire_volley()
			_volley_timer = maxf(0.65, 1.65 - phase * 0.3)
		return
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
		_locked_aim = _flight_space.combat_motion_to_screen(player.global_position - global_position).normalized() if player != null else Vector2.DOWN
		_warning_timer = 0.65
		$Attachments/Warning.show()
		charge_started.emit(get_combat_position(), _flight_space.input_to_combat_direction(_locked_aim))

func _fire_volley() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null:
		return
	_volley_index += 1
	var pods := _active_section_count()
	match variant:
		0: # Alternating aimed fans and broad, spaced arcs.
			_fire_fan(manager, global_position, _locked_aim, 5 + phase * 2, 0.14, 280.0)
		1: # Slow fortress rings with a rotating escape gap.
			_fire_ring(manager, 14 + phase * 2 + pods * 2, _volley_index * 0.27, 205.0)
		2: # Rotating pinwheel arms; one step per visible charge.
			for arm in 4:
				_fire_fan(manager, global_position, Vector2.from_angle(_volley_index * 0.38 + arm * TAU / 4.0), 2 + phase, 0.12, 245.0)
		3: # Alternating aimed pincer volleys and sparse perimeter rings.
			if _volley_index % 2 == 0:
				_fire_ring(manager, 16 + phase * 2, _volley_index * 0.2, 235.0)
			else:
				_fire_fan(manager, global_position, _locked_aim, 7 + phase * 2, 0.11, 350.0)
		4: # Endless command core alternates the earlier pattern families.
			_fire_ring(manager, 18 + phase * 2, _volley_index * 0.31, 220.0)
			_fire_fan(manager, global_position, _locked_aim, 3 + phase * 2, 0.16, 320.0)
	for section in _sections:
		if section.is_active:
			_fire_fan(manager, section.global_position, _locked_aim, 1 + phase, 0.18, 285.0)
	charge_released.emit(get_combat_position(), _flight_space.input_to_combat_direction(_locked_aim))

func _fire_fan(manager: ProjectileManager, origin: Vector3, aim: Vector2, count: int, spacing: float, speed: float) -> void:
	for index in count:
		var direction := aim.rotated((index - (count - 1) * 0.5) * spacing)
		manager.fire_enemy_projectile(origin, _flight_space.input_to_combat_direction(direction), speed)

func _fire_ring(manager: ProjectileManager, count: int, angle: float, speed: float) -> void:
	# Omit two adjacent slots to keep a readable route through every ring.
	for index in range(2, count):
		manager.fire_enemy_projectile(global_position, _flight_space.input_to_combat_direction(Vector2.from_angle(angle + index * TAU / count)), speed)

func _active_section_count() -> int:
	var count := 0
	for section in _sections:
		if section.is_active:
			count += 1
	return count

func _has_crossed_exit_edge() -> bool:
	return false

func _on_area_entered(_area: Area3D) -> void:
	pass # Player owns contact damage; contact never despawns a boss.

func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	if (variant == 1 or variant == 4) and _active_section_count() > 0:
		amount = maxi(1, ceili(amount * 0.5))
	super.take_damage(amount)
	phase = 2 if health <= max_health / 3 else 1 if health <= max_health * 2 / 3 else 0
	SignalBus.boss_health_changed.emit(maxi(health, 0))

func get_reward_points() -> int:
	return 1500 + GameManager.current_wave * 100

func should_drop_xp_orb() -> bool:
	return false

func _before_finish(reason: FinishReason, _position: Vector3) -> void:
	_warning_timer = 0.0
	$Attachments/Warning.hide()
	$Attachments/Warning.scale = Vector3.ONE
	for section in _sections:
		section.deactivate()
	if reason == FinishReason.DESTROYED:
		var director := get_tree().get_first_node_in_group(&"native_encounter_director")
		if director != null:
			Callable(director, "finish_boss").call_deferred(GameManager.current_wave, get_reward_points())
