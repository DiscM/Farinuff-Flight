extends Native3DGameplay
## Exercise real projection and HUD opacity without changing combat bounds.

var _failures: Array[String] = []

func _ready() -> void:
	await super._ready()
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		for boss_active in [false, true]:
			GameManager.boss_active = boss_active
			await get_tree().physics_frame
			var before := flight_space.get_combat_bounds()
			var header := hud.get_node("CombatHeader") as Control
			await _hold_at_screen_position(header.get_global_rect().get_center(), 0.2)
			_expect(header.modulate.a < 0.3, "Header yields to the craft at %s (boss=%s)" % [resolution, boss_active])
			await _hold_at_screen_position(get_viewport().get_visible_rect().size * 0.5, 0.2)
			_expect(header.modulate.a > 0.95, "HUD returns to full readability away from the craft")
			_expect(flight_space.get_combat_bounds().is_equal_approx(before), "HUD fading preserves combat bounds")
	var planet := $Backdrop/Celestial
	planet.type_index = 10 # Star: brightest palette with multiple shader layers.
	planet._spawn_planet()
	GameManager.boss_active = false
	await get_tree().create_timer(0.6).timeout
	var flight_colors: Array = planet.current_planet.get_colors()
	GameManager.boss_active = true
	await get_tree().create_timer(0.6).timeout
	var boss_colors: Array = planet.current_planet.get_colors()
	_expect(flight_colors.size() == boss_colors.size() and not flight_colors.is_empty(), "Boss palette preserves all planet layers")
	for index in mini(flight_colors.size(), boss_colors.size()):
		_expect(boss_colors[index].v < flight_colors[index].v, "Boss backdrop lowers each bright palette entry")
	GameManager.boss_active = false
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("COMBAT_READABILITY_SMOKE_PASS")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _hold_at_screen_position(point: Vector2, duration: float) -> void:
	# The boss camera follows the craft; continue moving under the HUD so this
	# checks occlusion while the camera moves, not a stale world coordinate.
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < until:
		player.global_position = flight_space.screen_to_combat_plane(point)
		await get_tree().process_frame
