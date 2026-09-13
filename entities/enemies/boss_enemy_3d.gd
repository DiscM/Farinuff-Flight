extends BasicEnemy3D
## Five native command hulls. Health phases intensify patterns; destructible
## weapon pods reduce volley density and remove Bulwark/Core damage resistance.
const Section := preload("res://entities/enemies/boss_section_3d.gd")
const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const Shot := preload("res://entities/projectiles/projectile_3d.gd")
const RAM_DURATION := 1.0
const ArenaPatterns := preload("res://systems/boss_arena_patterns.gd")
var _arena_patterns: ArenaPatterns
var _roam_target := Vector3.ZERO
var _relocate_time := 0.0
const TITLES := ["ASSAULT COMMANDER", "IRON BULWARK", "TEMPEST", "VOID HARBINGER", "TEMPEST CORE"]
## Authored Expedition milestones are stable content IDs. Keep this mapping
## explicit so the Wave-20 finale cannot change when the title catalog grows.
const MILESTONE_VARIANTS := {
	5: 0, # Assault Commander
	10: 1, # Iron Bulwark
	15: 2, # Tempest
	20: 4, # Tempest Core
	25: 3, # Void Harbinger, first Endless revelation
}
var max_health := 60
var variant := 0
var phase := 0
var _boss_time := 0.0
var _anchor := Vector3.ZERO
var _volley_timer := 1.8
var _warning_timer := 0.0
var _volley_index := 0
var _locked_aim := Vector2.DOWN
var _burst_remaining := 0
var _burst_timer := 0.0
var _burst_step := 0
var _attack_phase := 0
var _attack_has_breakers := false
var _sections: Array[Section] = []
var dev_variant_override := -1
var _phase_transition := 0.0
var _core_charging := false
var _core_charge_damage := 0
var _core_charge_target := 8
var _core_beam: EnemyRailBeam3D
var _echo_marks: Array[Dictionary] = []
var _siege_mines: Dictionary[EnemyMine3D, Section] = {}
var _ram_warning: MeshInstance3D
var _ram_primed := false
var _ram_time := 0.0
var _ram_recovery := 0.0
var _ram_start := Vector3.ZERO
var _ram_target := Vector3.ZERO
const PHASE_NAMES := [
	["SPEARHEAD", "FLANK ASSAULT", "BREAKTHROUGH"],
	["BATTLEMENT", "SIEGE GATES", "LAST REDOUBT"],
	["STORM ORBIT", "REVERSE CURRENT", "ALTERNATING EYE"],
	["RETURNING ECHO", "DISPLACED ECHO", "BARBED RETURN"],
	["REACTOR PULSE", "POLARITY SHIFT", "CORE COLLAPSE"],
]
const SHOT_COLORS := [Color(1.0, 0.42, 0.1), Color(1.0, 0.8, 0.25), Color(0.65, 0.4, 1.0), Color(1.0, 0.25, 0.55), Color(1.0, 0.95, 0.8)]


## Public boss-selection seam used by production activation and contract tests.
## Waves after the authored milestones retain the existing five-hull rotation
## for Endless play, while the milestone table always wins for its exact waves.
static func resolve_variant_for_wave(wave: int) -> int:
	if MILESTONE_VARIANTS.has(wave):
		return int(MILESTONE_VARIANTS[wave])
	var cycle := maxi(floori(float(wave) / 5.0) - 1, 0)
	return cycle % TITLES.size()

func _ready() -> void:
	super._ready()
	_ram_warning = MeshInstance3D.new()
	var lane_mesh := BoxMesh.new()
	lane_mesh.size = Vector3.ONE
	_ram_warning.mesh = lane_mesh
	var lane_material := StandardMaterial3D.new()
	lane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lane_material.albedo_color = Color(1.0, 0.4, 0.05, 0.25)
	_ram_warning.material_override = lane_material
	_ram_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Attachments.add_child(_ram_warning)
	_ram_warning.hide()
	for section in $Attachments/Sections.get_children():
		_sections.append(section as Section)
		section.destroyed.connect(_on_section_destroyed.bind(section))

func _is_basic_lineage() -> bool:
	return false

func _configure_movement() -> void:
	_anchor = global_position
	velocity = Vector3.ZERO
	_boss_time = 0.0

func activate_generation(space: FlightSpace, origin: Vector3, direction: Vector3, stage: int) -> bool:
	if not super.activate_generation(space, origin, direction, stage):
		return false
	variant = (
		clampi(dev_variant_override, 0, TITLES.size() - 1)
		if dev_variant_override >= 0
		else resolve_variant_for_wave(GameManager.current_wave)
	)
	max_health = roundi((400.0 + GameManager.current_wave * 32.0) * (1.15 if variant in [1, 4] else 1.0) * GameManager.get_enemy_health_multiplier() * 0.32)
	health = max_health
	phase = 0
	_phase_transition = 0.0
	_cancel_ram()
	_core_charging = false
	_core_charge_damage = 0
	_volley_index = 0
	_burst_remaining = 0
	_burst_timer = 0.0
	_burst_step = 0
	_volley_timer = 1.8
	_warning_timer = 0.0
	$Attachments/Warning.scale = Vector3.ONE
	for index in visuals.get_child_count():
		visuals.get_child(index).visible = index == variant
	$Attachments/Warning.hide()
	for section in _sections:
		if variant > 0:
			section.activate(maxi(8, floori((45.0 + GameManager.current_wave * 3.0) * GameManager.get_enemy_health_multiplier() / 6.0)))
		else:
			section.deactivate()
	_roam_target = global_position
	_relocate_time = 0.0
	if _arena_patterns == null:
		var arena_layer := CanvasLayer.new()
		arena_layer.layer = 1
		add_child(arena_layer)
		_arena_patterns = ArenaPatterns.new()
		arena_layer.add_child(_arena_patterns)
	_arena_patterns.configure(self, space)
	add_to_group(&"native_3d_bosses")
	SignalBus.boss_spawned.emit(health, max_health, TITLES[variant])
	_present_phase()
	if not GameManager.practice_mode:
		SaveManager.record_boss_encounter(GameManager.current_wave)
	SignalBus.combat_notice.emit("TARGET WEAPON PODS TO BREAK ARMOR" if variant in [1, 4] else "DESTROY WEAPON PODS TO REDUCE FIRE" if variant > 0 else "WATCH THE CHARGE · BOOST THROUGH THE VOLLEY")
	return true

func _advance_movement(delta: float) -> void:
	_boss_time += delta
	_update_attack_facing(delta)
	_update_echo_marks(delta)
	if _phase_transition > 0.0:
		_phase_transition = maxf(0.0, _phase_transition - delta)
		$Attachments/Warning.scale = Vector3.ONE * (1.2 + 0.15 * sin(_boss_time * 8.0))
		if _phase_transition <= 0.0:
			$Attachments/Warning.hide()
			$Attachments/Warning.scale = Vector3.ONE
		return
	if _ram_time > 0.0:
		_ram_time = maxf(0.0, _ram_time - delta)
		global_position = _ram_start.lerp(_ram_target, 1.0 - _ram_time / RAM_DURATION)
		if _ram_time <= 0.0:
			_ram_recovery = 1.8
			SignalBus.combat_notice.emit("COMMANDER OVEREXTENDED · ATTACK NOW")
		return
	if _ram_recovery > 0.0:
		_ram_recovery = maxf(0.0, _ram_recovery - delta)
		return
	# Relocate between attacks, keeping telegraphed origins still during volleys.
	if _warning_timer <= 0.0 and _burst_remaining == 0:
		_roam_arena(delta)
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_step += 1
			_fire_pattern()
			_burst_remaining -= 1
			_burst_timer = _burst_delay()
		return
	if _warning_timer > 0.0:
		_warning_timer -= delta
		$Attachments/Warning.scale = Vector3.ONE * (1.0 + 0.12 * sin(_boss_time * 35.0))
		if _warning_timer <= 0.0:
			$Attachments/Warning.hide()
			if _ram_primed:
				_ram_primed = false
				_ram_warning.hide()
				_ram_time = RAM_DURATION
				_volley_index += 1
				_volley_timer = 0.6
				return
			if _core_charging:
				_core_charging = false
				_release_core_beam()
				_volley_index += 1
				_volley_timer = 2.0
				return
			_volley_index += 1
			_burst_step = 0
			_burst_remaining = 1 + _attack_phase
			_burst_timer = _burst_delay()
			_fire_pattern()
			_volley_timer = maxf(1.1, 1.6 - phase * 0.25)
		return
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
		_locked_aim = Vector2.DOWN
		if player != null:
			var target := player.global_position
			if (_volley_index + 1) % 5 == 1:
				var player_velocity: Vector3 = player.get("velocity")
				target += player_velocity * 0.45
			_locked_aim = _flight_space.combat_motion_to_screen(target - global_position).normalized()
		# Telegraph the family before firing; every follow-up keeps this aim lock.
		var family := (_volley_index + 1) % 5
		_attack_phase = phase
		_attack_has_breakers = true
		var warning: String = ["LANCE VOLLEY · BAIT AND SIDESTEP", "SIEGE WALL · PASS THROUGH THE DOOR", "ORBITING STORM · CROSS THE MOVING GAP", "ECHOES · OUT, PAUSE, THEN RETURN", "REACTOR PULSE · WAIT, THEN CROSS"][variant]
		_warning_timer = 0.85 if _attack_has_breakers else 0.65
		if variant == 2:
			warning = "ORBITING STORM · CROSS THE MOVING GAP"
			_warning_timer = 1.1
		if variant == 0 and _volley_index % 2 == 0:
			_prime_ram()
			_warning_timer = 1.1
			warning = "COMMANDER CHARGE · LEAVE ORANGE LANE"
		if variant == 4 and (_volley_index % 2 == 0):
			_core_charging = true
			_core_charge_damage = 0
			_core_charge_target = 8 + phase * 4
			_warning_timer = 2.0
			warning = "CORE CHARGING · HIT CORE TO INTERRUPT"
		SignalBus.combat_notice.emit(warning)
		$Attachments/Warning.show()
		charge_started.emit(get_combat_position(), _flight_space.input_to_combat_direction(_locked_aim))

func _update_attack_facing(delta: float) -> void:
	if _phase_transition > 0.0:
		return
	var target_direction := Vector3.ZERO
	if _ram_time > 0.0 or _ram_primed:
		target_direction = _ram_target - _ram_start
	else:
		var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
		if player != null:
			target_direction = player.global_position - global_position
	if target_direction.is_zero_approx():
		return
	# Turn only the model container: collision, weapon pods and world-space
	# telegraphs keep their existing contracts and attack directions stay locked.
	var heading := atan2(-target_direction.x, -target_direction.z) - global_rotation.y
	visuals.rotation.y = lerp_angle(visuals.rotation.y, heading, 1.0 - exp(-8.0 * delta))

func _burst_delay() -> float:
	match variant:
		1: return 1.15
		3: return 1.2 if _burst_step == 0 else 0.85
		4: return 1.0
	return 0.8

func _fire_pattern() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null:
		return
	if variant == 1 and _burst_step == 0:
		_deploy_siege_mines()
	var step := float(_burst_step)
	var turn := -1.0 if _volley_index % 2 == 0 else 1.0
	var p := _attack_phase
	match variant:
		0: # Commander: spearheads become flanking lances, then a sweeping assault.
			var aim := _locked_aim.rotated(turn * (step - 0.5) * 0.18)
			if p == 0:
				_fire_commander_lances(manager, global_position, aim, 7, 0.16, 240.0, Shot.Motion.ACCELERATING)
			elif p == 1:
				for side in [-1.0, 1.0]:
					_fire_commander_lances(manager, global_position, aim.rotated(side * 0.48), 4, 0.14, 235.0, Shot.Motion.ACCELERATING)
			else:
				_fire_commander_lances(manager, global_position, aim, 11, 0.14, 250.0, Shot.Motion.ACCELERATING, true)
		1: # Parallel masonry moves as a wall, not rays from a central fan.
			_fire_siege_wall(manager)
		2: # Tempest owns persistent circular motion; no aimed support volleys.
			if _burst_step == 0:
				_deploy_storm_orbit(manager)
		3: # Echoes threaten the return journey as well as their outward flight.
			_place_echo_mark()
		4: # Reactor pulses park in space before releasing along their original axes.
			var diagonal := p == 1 or (p == 2 and _burst_step % 2 == 1)
			var axis := _locked_aim.rotated(PI * 0.25 if diagonal else 0.0)
			for arm in 4:
				var direction := axis.rotated(arm * PI * 0.5)
				var across := direction.rotated(PI * 0.5)
				for lane in [-1.0, 1.0]:
					var origin := global_position + _flight_space.screen_motion_to_combat(across * lane * 32.0)
					manager.fire_enemy_projectile(origin, _flight_space.input_to_combat_direction(direction), 200.0, Shot.Motion.STOP_RELEASE, SHOT_COLORS[4], 4)
	charge_released.emit(get_combat_position(), _flight_space.input_to_combat_direction(_locked_aim))

func _fire_siege_wall(manager: ProjectileManager) -> void:
	var across := _locked_aim.rotated(PI * 0.5)
	var gap := 0 if _attack_phase == 0 else (-2 if _burst_step % 2 == 0 else 2)
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	for lane in range(-5, 6):
		if absi(lane - gap) <= 1:
			continue
		var origin := global_position + _flight_space.screen_motion_to_combat(across * lane * 42.0)
		if player != null and _flight_space.combat_motion_to_screen(origin - player.global_position).length() < 85.0:
			continue
		var profile := Shot.Motion.BOOST_BREAKER if absi(lane) == 5 else Shot.Motion.STRAIGHT
		manager.fire_enemy_projectile(origin, _flight_space.input_to_combat_direction(_locked_aim), 165.0, profile, SHOT_COLORS[1], 1)

func _fire_commander_lances(manager: ProjectileManager, origin: Vector3, aim: Vector2, count: int, spacing: float, speed: float, motion: Shot.Motion = Shot.Motion.STRAIGHT, breaker_center: bool = false) -> void:
	for index in count:
		var direction := aim.rotated((index - (count - 1) * 0.5) * spacing)
		var profile := Shot.Motion.BOOST_BREAKER if breaker_center and index == count / 2 else motion
		_fire_commander_shot(manager, origin, direction, speed, profile, index)

func _commander_escape_direction() -> Vector2:
	var side := -1.0 if _volley_index % 2 == 0 else 1.0
	return _locked_aim.rotated(side * 0.42)

func _fire_commander_shot(manager: ProjectileManager, origin: Vector3, direction: Vector2, speed: float, motion: Shot.Motion, slot: int) -> void:
	# Commander lance groups preserve a shared sidestep corridor.
	# Bound parallax from offset weapons outside the boss's 120-pixel near zone.
	# A single sample farther out can miss a ray crossing the lane on approach.
	var origin_offset := _flight_space.combat_motion_to_screen(origin - global_position).length()
	var gap_angle := absf(_commander_escape_direction().angle_to(direction))
	var clearance := 0.22 + asin(clampf(origin_offset / 120.0, 0.0, 1.0))
	if motion in [Shot.Motion.CURVE_LEFT, Shot.Motion.CURVE_RIGHT]:
		# Keep the whole bounded bend out of the corridor, not just its launch ray.
		clearance += 0.66
	if gap_angle < clearance:
		return
	# Every sixth slot is cyan; its offset alternates between successive layers.
	# Straight motion keeps these dangerous shots predictable within the weave.
	var profile := motion
	if _attack_has_breakers and (slot + _burst_step * 3) % 6 == 2:
		profile = Shot.Motion.BOOST_BREAKER
	manager.fire_enemy_projectile(origin, _flight_space.input_to_combat_direction(direction), speed, profile, SHOT_COLORS[variant].lightened(_attack_phase * 0.08), variant)

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
	var previous_phase := phase
	if _core_charging:
		_core_charge_damage += amount
		if _core_charge_damage >= _core_charge_target:
			_core_charging = false
			_warning_timer = 0.0
			_volley_index += 1
			_volley_timer = 2.5
			$Attachments/Warning.hide()
			SignalBus.combat_notice.emit("REACTOR DISRUPTED · ATTACK NOW")
	super.take_damage(amount)
	phase = 2 if health <= float(max_health) / 3.0 else 1 if health <= float(max_health) * 2.0 / 3.0 else 0
	if health > 0 and phase != previous_phase:
		_begin_phase_transition()
		SignalBus.boss_phase_changed.emit(variant, phase)
	SignalBus.boss_health_changed.emit(maxi(health, 0))

func _deploy_storm_orbit(manager: ProjectileManager) -> void:
	var reverse := phase == 1 or (phase == 2 and _volley_index % 2 == 0)
	var sign := -1.0 if reverse else 1.0
	var motion := Shot.Motion.ORBIT_RIGHT if reverse else Shot.Motion.ORBIT_LEFT
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	# Two opposite broad openings revolve with the storm. Reflected shots leave
	# orbit immediately, allowing a controlled boost to carve another crossing.
	for slot in 16:
		if slot % 8 in [0, 1]:
			continue
		var radial := _locked_aim.rotated(slot * TAU / 16.0)
		var origin := global_position + _flight_space.screen_motion_to_combat(radial * 140.0)
		if player != null and _flight_space.combat_motion_to_screen(origin - player.global_position).length() < 75.0:
			continue
		var tangent := radial.rotated(sign * PI * 0.5)
		manager.fire_enemy_projectile(origin, _flight_space.input_to_combat_direction(tangent), 95.0 + phase * 10.0, motion, SHOT_COLORS[2], 2)
	SignalBus.combat_notice.emit("STORM REVERSES · WATCH THE GAPS" if reverse else "STORM ORBITS · CROSS OR REFLECT")

func _place_echo_mark() -> void:
	if _echo_marks.size() >= 3:
		return
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if player == null:
		return
	var position := player.global_position
	# Nearby marks merge rather than stacking several bursts under one position.
	for mark in _echo_marks:
		if _flight_space.combat_motion_to_screen(position - Vector3(mark.position)).length() < 90.0:
			return
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6
	marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SHOT_COLORS[3]
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.top_level = true
	var across := _flight_space.screen_motion_to_combat(Vector2(35.0, 0.0))
	var along := _flight_space.screen_motion_to_combat(Vector2(0.0, 35.0))
	marker.global_transform = Transform3D(Basis(across, Vector3.UP * 0.05, along), position + Vector3.UP * 0.03)
	_echo_marks.append({"position": position, "marker": marker, "timer": 1.6, "phase": phase, "aim": _locked_aim, "sequence": _burst_step})
	SignalBus.combat_notice.emit("ECHO MARKED · WATCH THE RETURN PATH")

func _update_echo_marks(delta: float) -> void:
	for index in range(_echo_marks.size() - 1, -1, -1):
		var mark := _echo_marks[index]
		mark.timer = float(mark.timer) - delta
		if float(mark.timer) > 0.0:
			continue
		var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
		if manager != null:
			var count := 8 + int(mark.phase) * 2
			# Even fans leave the aimed center open. Later phases offset alternating
			# echoes, requiring a small lane correction rather than more density.
			var offset := 0.09 if int(mark.phase) > 0 and int(mark.sequence) % 2 == 0 else 0.0
			for slot in count:
				var direction := Vector2(mark.aim).rotated((slot - (count - 1) * 0.5) * 0.18 + offset)
				var profile := Shot.Motion.BOOST_BREAKER if int(mark.phase) > 0 and slot % 5 == 0 else Shot.Motion.RETURNING
				var origin := Vector3(mark.position) + _flight_space.screen_motion_to_combat(direction * 35.0)
				manager.fire_enemy_projectile(origin, _flight_space.input_to_combat_direction(direction), 180.0, profile, SHOT_COLORS[3], 3)
		var marker: MeshInstance3D = mark.marker
		marker.queue_free()
		_echo_marks.remove_at(index)

func _clear_echo_marks() -> void:
	for mark in _echo_marks:
		var marker: MeshInstance3D = mark.marker
		if is_instance_valid(marker):
			marker.queue_free()
	_echo_marks.clear()

func _deploy_siege_mines() -> void:
	var hazards := get_tree().get_first_node_in_group(&"native_3d_hazard_manager") as NativeHazardManager
	if hazards == null:
		return
	var deployed := 0
	for index in _sections.size():
		var section := _sections[index]
		if not section.is_active or deployed >= 2:
			continue
		var side := -1.0 if index % 2 == 0 else 1.0
		var direction := _locked_aim.rotated(side * (0.75 if phase == 0 else 1.0))
		var position := global_position + _flight_space.screen_motion_to_combat(direction * (180.0 + phase * 30.0))
		var bounds := _flight_space.get_combat_bounds(-40.0)
		if not bounds.has_point(Vector2(position.x, position.z)):
			continue
		# Don't materialize a contact hazard on top of the player's current position.
		var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
		if player != null and _flight_space.combat_motion_to_screen(player.global_position - position).length() < 100.0:
			continue
		var mine := hazards.spawn_mine(position, phase == 2, false)
		if mine == null:
			continue
		_siege_mines[mine] = section
		mine.returned_to_pool.connect(_on_siege_mine_returned, CONNECT_ONE_SHOT)
		deployed += 1
	if deployed > 0:
		SignalBus.combat_notice.emit("SIEGE MINES · SHOOT MINES OR THEIR POD")

func _on_siege_mine_returned(mine: EnemyMine3D) -> void:
	_siege_mines.erase(mine)

func _clear_siege_mines(section: Section = null) -> void:
	for mine in _siege_mines.keys():
		if section == null or _siege_mines[mine] == section:
			if is_instance_valid(mine):
				mine.despawn()
			_siege_mines.erase(mine)

func _roam_arena(delta: float) -> void:
	_relocate_time -= delta
	if _relocate_time <= 0.0:
		var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
		var center := player.global_position if player != null else _anchor
		var heading := Vector2.from_angle(_volley_index * 1.7 + variant * 0.9 + phase * 0.5)
		var radius := 420.0 if variant in [0, 2] else 560.0
		_roam_target = center + _flight_space.screen_motion_to_combat(heading * radius)
		var bounds := _flight_space.get_combat_bounds(-100.0)
		_roam_target.x = clampf(_roam_target.x, bounds.position.x, bounds.end.x)
		_roam_target.z = clampf(_roam_target.z, bounds.position.y, bounds.end.y)
		_relocate_time = 2.5
	var displacement := _flight_space.combat_motion_to_screen(_roam_target - global_position)
	var speed := 180.0 if variant in [0, 2] else 120.0
	global_position += _flight_space.screen_motion_to_combat(displacement.limit_length(speed * delta))

func _prime_ram() -> void:
	_ram_primed = true
	_ram_start = global_position
	# Follow the locked aim all the way to the screen edge. Ray intersection
	# preserves the advertised direction even for diagonal charges.
	var direction := _flight_space.screen_motion_to_combat(_locked_aim).normalized()
	var bounds := _flight_space.get_combat_bounds()
	var distance_to_edge := INF
	if not is_zero_approx(direction.x):
		var edge_x: float = bounds.end.x if direction.x > 0.0 else bounds.position.x
		distance_to_edge = minf(distance_to_edge, (edge_x - _ram_start.x) / direction.x)
	if not is_zero_approx(direction.z):
		var edge_z: float = bounds.end.y if direction.z > 0.0 else bounds.position.y
		distance_to_edge = minf(distance_to_edge, (edge_z - _ram_start.z) / direction.z)
	if not is_finite(distance_to_edge) or distance_to_edge <= 0.0:
		_ram_primed = false
		return
	_ram_target = _ram_start + direction * distance_to_edge
	var along := _ram_target - _ram_start
	var screen_direction := _flight_space.combat_motion_to_screen(along).normalized()
	var across := _flight_space.screen_motion_to_combat(screen_direction.orthogonal() * 120.0)
	if along.is_zero_approx():
		_ram_primed = false
		return
	_ram_warning.global_transform = Transform3D(Basis(across, Vector3.UP * 0.025, along), (_ram_start + _ram_target) * 0.5 + Vector3.UP * 0.03)
	_ram_warning.show()

func _cancel_ram() -> void:
	_ram_primed = false
	_ram_time = 0.0
	_ram_recovery = 0.0
	if is_instance_valid(_ram_warning):
		_ram_warning.hide()

func _release_core_beam() -> void:
	var hazards := get_tree().get_first_node_in_group(&"native_3d_hazard_manager") as NativeHazardManager
	if hazards == null:
		return
	# The beam's existing visible lane telegraph gives the dodge route after a
	# failed interrupt. It is owned by this hull and uses normal hazard admission.
	_core_beam = hazards.spawn_rail_beam(global_position, _flight_space.input_to_combat_direction(_locked_aim), self)
	if _core_beam != null:
		_core_beam.returned_to_pool.connect(_on_core_beam_returned, CONNECT_ONE_SHOT)
		SignalBus.combat_notice.emit("REACTOR LANCE · LEAVE THE MARKED LANE")

func _on_core_beam_returned(rail: EnemyRailBeam3D) -> void:
	if _core_beam == rail:
		_core_beam = null

func _cancel_core_weapon() -> void:
	_core_charging = false
	_core_charge_damage = 0
	if is_instance_valid(_core_beam) and _core_beam.is_active:
		_core_beam.despawn()
	_core_beam = null

func _present_phase() -> void:
	SignalBus.boss_phase_presented.emit(phase, PHASE_NAMES[variant][phase], SHOT_COLORS[variant])

func _begin_phase_transition() -> void:
	if _arena_patterns != null:
		_arena_patterns.reset_patterns()
	_clear_echo_marks()
	_clear_siege_mines()
	_cancel_ram()
	_cancel_core_weapon()
	_present_phase()
	# Cancel the old sequence and clear its field before advertising the new rules.
	_warning_timer = 0.0
	_burst_remaining = 0
	_burst_step = 0
	_volley_index = 0
	_phase_transition = 1.5
	_volley_timer = 0.6
	$Attachments/Warning.show()
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager != null:
		manager.clear_enemy_projectiles()
	SignalBus.combat_notice.emit("PHASE %d · %s" % [phase + 1, PHASE_NAMES[variant][phase]])

func get_reward_points() -> int:
	return 1500 + GameManager.current_wave * 100

func should_drop_xp_orb() -> bool:
	return false

func _before_finish(reason: FinishReason, _position: Vector3) -> void:
	if _arena_patterns != null:
		_arena_patterns.shutdown()
	_clear_echo_marks()
	_clear_siege_mines()
	_cancel_ram()
	_cancel_core_weapon()
	_phase_transition = 0.0
	_warning_timer = 0.0
	_burst_remaining = 0
	$Attachments/Warning.hide()
	$Attachments/Warning.scale = Vector3.ONE
	for section in _sections:
		section.deactivate()
	if reason == FinishReason.DESTROYED:
		var director := get_tree().get_first_node_in_group(&"native_encounter_director")
		if director != null:
			Callable(director, "finish_boss").call_deferred(GameManager.current_wave, get_reward_points())


func _on_section_destroyed(_position: Vector3, section: Section) -> void:
	_clear_siege_mines(section)
	AudioManager.play_explosion(true)
	SignalBus.combat_notice.emit("ARMOR BROKEN · CORE EXPOSED" if variant in [1, 4] and _active_section_count() == 0 else "WEAPON POD DESTROYED · FIRE REDUCED")
