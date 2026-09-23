extends BasicEnemy3D
## Boss actor: spawn/finish integration and destructible hull sections.
## Combat is explicitly stepped by BossAI; this remains the only transform writer.
const Section := preload("res://entities/enemies/boss_section_3d.gd")
const Intelligence := preload("res://systems/boss_ai.gd")
const ArenaPatterns := preload("res://systems/boss_arena_patterns.gd")
const HEALTH_MULTIPLIER := 1.25
@onready var _boss_ai: Intelligence = $BossAI
@onready var _health: BossHealth = $Health
var _arena_patterns: ArenaPatterns
var _sections: Array[Section] = []
var phase := 0
var variant := 0
var dev_variant_override := -1
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
	for section in $Attachments/Sections.get_children():
		_sections.append(section as Section)
		section.destroyed.connect(_on_section_destroyed.bind(section))
	_health.changed.connect(_on_health_changed)
	_health.phase_changed.connect(_on_phase_changed)
	_health.died.connect(_on_died)
	_boss_ai.combat_cancelled.connect(_clear_attack_field)

func _is_basic_lineage() -> bool:
	return false

func _configure_movement() -> void:
	velocity = Vector3.ZERO

func activate_generation(space: FlightSpace, origin: Vector3, direction: Vector3, stage: int) -> bool:
	if not super.activate_generation(space, origin, direction, stage):
		return false
	variant = clampi(dev_variant_override, 0, 4) if dev_variant_override >= 0 else resolve_variant_for_wave(GameManager.current_wave)
	max_health = roundi((400.0 + GameManager.current_wave * 32.0) * (1.15 if variant in [1, 4] else 1.0) * GameManager.get_enemy_health_multiplier() * 0.32 * HEALTH_MULTIPLIER)
	health = max_health
	phase = 0
	for index in visuals.get_child_count():
		visuals.get_child(index).visible = index == variant
	_sync_motion_sockets()
	for section in _sections:
		if variant > 0:
			section.activate(maxi(8, floori((45.0 + GameManager.current_wave * 3.0) * GameManager.get_enemy_health_multiplier() / 6.0)))
		else:
			section.deactivate()
	_boss_ai.configure(space, variant)
	_health.configure(max_health, _boss_ai.profile.phase_two_threshold, _boss_ai.profile.phase_three_threshold)
	if _arena_patterns == null:
		var arena_layer := CanvasLayer.new()
		arena_layer.layer = 1
		add_child(arena_layer)
		_arena_patterns = ArenaPatterns.new()
		arena_layer.add_child(_arena_patterns)
	_arena_patterns.configure(self, space)
	add_to_group(&"native_3d_bosses")
	SignalBus.boss_spawned.emit(health, max_health, TITLES[variant])
	SignalBus.boss_phase_thresholds_changed.emit(_health.phase_two_threshold, _health.phase_three_threshold)
	_present_phase()
	if not GameManager.practice_mode:
		SaveManager.record_boss_encounter(GameManager.current_wave)
	return true

func _sync_motion_sockets() -> void:
	# Five imported hulls share one wrapper muzzle. Only the selected visible
	# hull may supply it; hidden variants must never overwrite its animated pose.
	for pair in _animated_sockets:
		if pair[1].is_visible_in_tree():
			pair[0].global_transform = ShipMotion.socket_transform(pair[1])

func play_motion(clip: StringName, seconds: float = 0.0, hold: bool = false) -> void:
	super.play_motion(clip, seconds, hold)
	for section in _sections:
		section.play_motion(clip, seconds, hold)

func advance_motion(delta: float) -> void:
	super.advance_motion(delta)
	for section in _sections:
		section.advance_motion(delta)

func _advance_movement(delta: float) -> void:
	if delta <= 0.0:
		return
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	var displacement := _boss_ai.step(delta, player)
	velocity = displacement / delta
	global_position += displacement

func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	if variant in [1, 4] and _active_section_count() > 0:
		amount = maxi(1, ceili(amount * 0.5))
	var applied := _health.apply_damage(amount)
	if health > 0:
		_flash_time_left = 0.15
		play_motion(&"hit")
		_boss_ai.record_damage(applied, max_health)

func _on_health_changed(current: int, maximum: int) -> void:
	health = current
	max_health = maximum
	SignalBus.boss_health_changed.emit(current)

func _on_phase_changed(next: int) -> void:
	phase = next
	velocity = Vector3.ZERO
	_boss_ai.begin_phase(phase)
	_present_phase()
	SignalBus.boss_phase_changed.emit(variant, phase)

func _on_died() -> void:
	_finish(FinishReason.DESTROYED)

func stun(duration: float = -1.0) -> bool:
	return _boss_ai.try_stun(duration)

func can_deal_contact_damage() -> bool:
	return false # Slam/charge resolve explicitly after their tell, once per attack.

func _on_area_entered(_area: Area3D) -> void:
	pass

func _has_crossed_exit_edge() -> bool:
	return false

func _active_section_count() -> int:
	var count := 0
	for section in _sections:
		if section.is_active:
			count += 1
	return count

func _present_phase() -> void:
	SignalBus.boss_phase_presented.emit(phase, PHASE_NAMES[variant][phase], SHOT_COLORS[variant])

func _clear_attack_field() -> void:
	if _arena_patterns != null:
		_arena_patterns.reset_patterns()
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager3D
	if manager != null:
		manager.clear_enemy_projectiles()

func get_reward_points() -> int:
	return 1500 + GameManager.current_wave * 100

func should_drop_xp_orb() -> bool:
	return false

func _before_finish(reason: FinishReason, _position: Vector3) -> void:
	_boss_ai.shutdown()
	velocity = Vector3.ZERO
	if _arena_patterns != null:
		_arena_patterns.shutdown()
	for section in _sections:
		section.deactivate()
	if reason == FinishReason.DESTROYED:
		var director := get_tree().get_first_node_in_group(&"native_encounter_director")
		if director != null:
			Callable(director, "finish_boss").call_deferred(GameManager.current_wave, get_reward_points())

func _on_section_destroyed(_position: Vector3, _section: Section) -> void:
	AudioManager.play_explosion(true)
