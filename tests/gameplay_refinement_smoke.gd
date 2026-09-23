extends Native3DGameplay
## Production mechanics with isolated input, no rewards, and no durable progression.
const Director := preload("res://systems/native_encounter_director.gd")
const Allocation := preload("res://ui/point_allocation_popup.gd")
var _failures: Array[String] = []

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	player.set_physics_process(false)
	_check_encounters()
	await _check_boost()
	_check_allocation()
	for failure in _failures:
		push_error(failure)
	print("GAMEPLAY_REFINEMENT_SMOKE_PASS" if _failures.is_empty() else "GAMEPLAY_REFINEMENT_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_encounters() -> void:
	seed(21092026)
	var director := Director.new()
	add_child(director)
	director.configure(self)
	director.set_physics_process(false)
	var observed := {}
	for wave in [1, 2, 3, 4, 6, 16, 26]:
		GameManager.current_wave = wave
		director._on_wave_started(wave)
		for sample in 1000:
			var kind := director._pick_kind()
			_expect(director.is_archetype_available(kind, wave), "Ambient roster honors wave %d introduction" % wave)
			observed[kind] = true
		if wave == 1:
			_expect(observed.size() == 1 and observed.has(&"basic"), "First wave teaches pursuit alone")
		if wave >= 3:
			director._begin_pattern()
			for kind: StringName in director._pattern.archetypes:
				_expect(director.is_archetype_available(kind, wave), "Formations honor introduction rules")
	_expect(observed.size() == 5, "Full regular roster remains available after first boss")
	director._on_wave_started(6)
	_expect(is_equal_approx(director._spawn_in, 2.5), "New sector gives time to regroup after rewards")
	director._on_wave_started(7)
	_expect(is_equal_approx(director._spawn_in, 0.5), "Ordinary waves retain momentum")
	director.queue_free()
	GameManager.current_wave = 1

func _check_boost() -> void:
	player.is_boosting = false
	player.boost_reflected_projectiles = 0
	player.boost_chain_window_timer = 0.0
	player.boost_cooldown_timer = 0.08
	Input.action_release("boost")
	player.reset_action_input()
	player._update_boost(0.01)
	Input.action_press("boost")
	player._update_boost(0.01)
	_expect(not player.is_boosting, "Buffer does not bypass recharge")
	Input.action_release("boost")
	await get_tree().process_frame
	await get_tree().process_frame
	player._update_boost(0.07)
	_expect(player.is_boosting, "Press just before recharge is accepted when ready")
	_expect(is_zero_approx(player._boost_input_buffer), "Boost consumes buffered press once")
	player.is_boosting = false
	player.boost_cooldown_timer = 0.4
	Input.action_press("boost")
	player._update_boost(0.01)
	Input.action_release("boost")
	await get_tree().process_frame
	await get_tree().process_frame
	player._update_boost(0.2)
	player._update_boost(0.3)
	_expect(not player.is_boosting, "Old press expires instead of firing unexpectedly")
	player._boost_input_buffer = 0.1
	player.reset_action_input()
	_expect(is_zero_approx(player._boost_input_buffer), "Pause/reset discards queued action")
	player.boost_reflected_projectiles = 0
	player.boost_chain_window_timer = 0.0
	player._chain_followup = false
	player._begin_boost()
	for i in 3:
		player.register_boost_reflection()
	player.boost_duration_timer = 0.001
	player._update_boost(0.01)
	_expect(player.get_boost_state().chain_ready, "Three reflections open a follow-up opportunity")
	player._update_boost(0.20)
	_expect(player.get_boost_state().chain_ready, "Chain opportunity survives a 200 ms reaction")
	player._begin_boost()
	for i in 3:
		player.register_boost_reflection()
	_expect(not player._has_boost_chain(), "Buffered controls preserve one-follow-up chain limit")
	player.is_boosting = false
	player.reset_action_input()

func _check_allocation() -> void:
	GameManager.stat_fire_rate_level = 9
	GameManager.bonus_fire_rate_pct = 9 * GameManager.STAT_BONUS_STEP
	GameManager.stat_speed_level = 10
	GameManager.bonus_speed_pct = GameManager.STAT_BONUS_CAP
	var popup := Allocation.new()
	popup.panel_only = true
	hud.add_child(popup)
	popup.set_points(3)
	_expect(popup.speed_btn.disabled and popup.speed_btn.text == "MAX", "Capped stat is visibly unavailable")
	popup._on_plus_pressed("speed")
	popup._on_plus_pressed("invalid")
	_expect(popup.points_remaining == 3, "Capped or unknown stat never consumes points")
	popup._on_plus_pressed("fire_rate")
	popup._on_plus_pressed("fire_rate")
	_expect(popup.alloc_fire_rate == 1 and popup.points_remaining == 2, "Pending points respect remaining capacity")
	_expect(popup.fire_rate_label.text == "−45.0%", "Preview shows actual capped benefit")
	var original_lives := GameManager.lives
	popup._on_plus_pressed("health")
	_expect(GameManager.stat_fire_rate_level == 9 and GameManager.lives == original_lives, "Preview does not mutate the ship")
	popup._reset_choices()
	_expect(popup.points_remaining == 3 and popup.alloc_health == 0 and popup.alloc_fire_rate == 0, "Reset refunds every uncommitted point")
	popup._on_plus_pressed("fire_rate")
	popup._on_plus_pressed("health")
	popup._on_plus_pressed("health")
	popup._on_confirm()
	popup._on_confirm()
	popup._reset_choices()
	_expect(GameManager.stat_fire_rate_level == 10 and is_equal_approx(GameManager.bonus_fire_rate_pct, 0.45), "Final point reaches cap exactly")
	_expect(GameManager.lives == original_lives + 2, "Confirmation applies lives exactly once")
	_expect(popup.reset_btn.disabled and popup.allocation_committed, "Committed choices stay locked")
	GameManager.apply_stat_point("fire_rate")
	_expect(GameManager.stat_fire_rate_level == 10, "Stat model also rejects over-cap upgrades")
	popup.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
