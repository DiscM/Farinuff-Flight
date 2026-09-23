extends Native3DGameplay
## Cross-system contracts for the research-driven refinement pass.
const Catalog := preload("res://entities/player/native_player_upgrades.gd")
const Compass := preload("res://systems/run_compass.gd")
const Rotation := preload("res://systems/pickup_rotation.gd")
const Director := preload("res://systems/native_encounter_director.gd")
var _failures: Array[String] = []

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	player.set_physics_process(false)
	_check_compass()
	_check_drafts()
	await _check_build_reference()
	await _check_reward_layout()
	_check_pickups()
	await _check_combat_record()
	await _check_recovery()
	for failure in _failures:
		push_error(failure)
	print("COHESION_SMOKE_PASS" if _failures.is_empty() else "COHESION_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_compass() -> void:
	for wave in range(1, 41):
		var state := Compass.snapshot(wave)
		_expect(state.boss_wave >= wave and state.boss_wave % 5 == 0, "Compass points to the current or next boss")
		_expect(state.compact.contains("MODULE") == GameManager.offers_elite_reward(state.boss_wave), "Compass promise agrees with elite reward policy")
	_expect(Compass.snapshot(20).reward == "EXPEDITION FINALE", "Wave 20 announces the ending")
	_expect(Compass.snapshot(21).mode == "ENDLESS", "Endless remains identifiable after victory flag clears")
	_expect(Compass.snapshot(25).reward == "3 SYSTEM POINTS", "Harbinger does not promise an unavailable elite draft")
	_expect(Compass.snapshot(5, true).boss_wave == 0, "Practice never promises a run reward")
	var prior := GameManager.chosen_upgrade_ids.duplicate()
	for upgrade: Dictionary in GameManager.get_upgrade_pool():
		GameManager.chosen_upgrade_ids.append(str(upgrade.id))
	_expect(Compass.snapshot(30).reward == "BONUS SUPPLIES + 3 SYSTEM POINTS", "Exhausted module pools promise the actual supply fallback")
	_expect(Compass.snapshot(25).reward == "3 SYSTEM POINTS", "Exhaustion cannot invent supplies on a point-only milestone")
	GameManager.chosen_upgrade_ids.assign(prior)

func _check_build_reference() -> void:
	var build := preload("res://systems/build_reference.gd")
	var owned: Array[String] = ["twin_cannons", "auto_aim", "piercing", "twin_cannons", "invalid"]
	_expect(build.modules(owned).size() == 3, "Build reference filters unknown IDs and duplicates")
	_expect(build.connections(owned).size() == 2, "Build reference lists each installed interaction once")
	var partial: Array[String] = ["twin_cannons"]
	_expect(build.connections(partial).is_empty(), "Build reference cannot promise an uninstalled connection")
	var panel := preload("res://ui/shared/build_reference.gd").new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not panel.scroll.is_ancestor_of(panel.close_button), "Build reference return action remains outside scrolling content")
	var close_count := [0]
	panel.closed.connect(func(): close_count[0] += 1)
	panel._close()
	panel._close()
	_expect(close_count[0] == 1, "Duplicate return input resolves the build reference once")
	layer.queue_free()
	await get_tree().process_frame


func _check_reward_layout() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var popup := preload("res://ui/elite_upgrade_popup.tscn").instantiate()
	popup.use_custom_upgrade_pool = true
	for upgrade: Dictionary in GameManager.ALL_UPGRADES:
		if upgrade.id in ["hull_plating", "spread_shot_elite", "rear_gunner"]:
			popup.custom_upgrade_pool.append(upgrade)
	layer.add_child(popup)
	await get_tree().process_frame
	InterfaceSettings._scale_branch(popup, 1.3)
	await get_tree().process_frame
	await get_tree().process_frame
	var bounds: Rect2 = popup._install_button.get_global_rect()
	_expect(get_viewport().get_visible_rect().encloses(bounds), "Large-text reward installation stays inside the viewport")
	var select: Button = popup.cards_by_id["hull_plating"].get_meta("select_button")
	select.pressed.emit()
	_expect(not popup._install_button.disabled and popup._pending_upgrade_id == "hull_plating", "Scrolled reward selection still enables the separate install action")
	layer.queue_free()
	await get_tree().process_frame


func _check_drafts() -> void:
	seed(21092026)
	var pool: Array[Dictionary] = []
	for entry: Dictionary in GameManager.ALL_UPGRADES:
		if entry.id != "twin_cannons":
			pool.append(entry)
	var owned: Array[String] = ["twin_cannons"]
	for attempt in 30:
		var offers := Catalog.draft(pool, 3, owned)
		var ids := {}
		var roles := {}
		var connected := false
		for offer: Dictionary in offers:
			ids[offer.id] = true
			roles[offer.role] = true
			connected = connected or not Catalog.connection_text(offer.id, owned).is_empty()
		_expect(offers.size() == 3 and ids.size() == 3, "Draft retains three distinct legal options")
		_expect(roles.size() == 3, "A connected offer still leaves different roles")
		_expect(connected, "An available installed-weapon connection reaches the draft")
		_expect(not ids.has("twin_cannons") and not ids.has("piercing"), "Draft cannot invent owned or locked modules outside its pool")
	_expect(Catalog.draft([], 3, owned).is_empty(), "Exhausted pool stays empty for the supply fallback")
	_expect(Catalog.draft(pool, 0, owned).is_empty(), "Zero choices yields no offer")
	var single: Array[Dictionary] = [pool[0]]
	_expect(Catalog.draft(single, 3, owned).size() == 1, "Small pool never duplicates choices")

func _check_pickups() -> void:
	var rotation := Rotation.new()
	for boss in [false, true]:
		var last := -1
		var count := 5 if boss else 6
		for cycle in 10:
			var seen := {}
			for drop in count:
				var kind := rotation.next(boss)
				_expect(not boss or kind != PowerUp.Type.NUKE, "Boss supplies exclude nukes")
				_expect(kind != last, "Supply rotation avoids repeats in a continuous mode")
				last = kind
				seen[kind] = true
			_expect(seen.size() == count, "Each supply cycle covers every eligible type once")
	var director := Director.new()
	add_child(director)
	director.configure(self)
	director.set_physics_process(false)
	director._spawn_in = 0.1
	director._finish_pattern()
	_expect(director._spawn_in >= 2.2, "Formation ends in a spawn recovery interval")
	director._on_wave_started(5)
	_expect(is_equal_approx(director._spawn_in, 0.5), "Boss boundary replaces previous formation recovery")
	director.queue_free()

func _check_combat_record() -> void:
	GameManager.practice_mode = false
	GameManager.is_game_active = true
	GameManager.bonus_damage = 20
	GameManager.run_insights = preload("res://systems/run_insights.gd").new()
	var enemy := preload("res://entities/enemies/tank_enemy_3d.tscn").instantiate() as TankEnemy3D
	actors_root.add_child(enemy)
	enemy.activate_generation(flight_space, Vector3(12, 0, 0), Vector3.FORWARD, 1)
	enemy.set_physics_process(false)
	var hp := enemy.health
	_on_reflected_projectile_hit(enemy, enemy.global_position)
	_expect(enemy.health == hp - 2, "Returned fire deals two damage independently of player damage upgrades")
	_expect(GameManager.run_insights.counter_hits == 1, "Actual counter-hit enters flight record")
	_on_enemy_projectile_deflected(null, player.global_position)
	player._begin_boost()
	player.boost_reflected_projectiles = 3
	player._begin_boost()
	_expect(GameManager.run_insights.reflections == 1 and GameManager.run_insights.chains == 1 and GameManager.run_insights.boosts == 2, "Production event connections count reflection, boosts and chain")
	player.is_boosting = false
	player.reset_damage_state()
	player.has_shield = false
	GameManager.lives = 3
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.ENEMY_PROJECTILE)
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.ENEMY_CONTACT)
	_expect(GameManager.run_insights.hits_taken == 1, "Invulnerability rejects damage without inflating record")
	_expect(GameManager.run_insights.last_damage_source == 1, "Ignored collision cannot replace the accepted hit source")
	player.reset_damage_state()
	player.has_shield = true
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.ENEMY_CONTACT)
	_expect(GameManager.run_insights.hits_taken == 1, "Shield absorption is not recorded as hull damage")
	player.reset_damage_state()
	GameManager.lives = 1
	var observed_source: Array[int] = []
	var observer := func(_score: int): observed_source.append(GameManager.run_insights.last_damage_source)
	SignalBus.game_over.connect(observer)
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.HOSTILE_ORDNANCE)
	SignalBus.game_over.disconnect(observer)
	_expect(observed_source == [2], "Fatal cause is available before the game-over signal")
	_expect(GameManager.run_insights.next_attempt_tip().contains("PLASMA"), "Advice follows observed damage category")
	var active_time := GameManager.run_insights.active_seconds
	GameManager._process(10.0)
	_expect(GameManager.run_insights.active_seconds == active_time, "Defeat/reward downtime is excluded from active time")
	GameManager.start_game(false, true)
	_expect(GameManager.run_insights.reflections == 0 and GameManager.run_insights.hits_taken == 0, "New session resets its flight record")
	_on_enemy_projectile_deflected(null, player.global_position)
	_expect(GameManager.run_insights.reflections == 0, "Practice never contributes run performance")
	enemy.queue_free()
	await get_tree().process_frame

func _check_recovery() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var popup := preload("res://ui/try_again_popup.gd").new()
	GameManager.try_again_stocks = 2
	GameManager.starting_lives = 3
	GameManager.is_game_active = false
	overlay.add_child(popup)
	# The screen has no processing deadline; this formerly expired after ten seconds.
	_expect(not popup.is_processing(), "Recovery decision has no automatic countdown")
	await get_tree().create_timer(10.2, true).timeout
	_expect(is_instance_valid(popup), "Recovery stays available beyond the former ten-second deadline")
	if not is_instance_valid(popup):
		return
	var accepted: Array[bool] = []
	popup.try_again_accepted.connect(func(): accepted.append(true))
	popup._on_try_again()
	popup._on_try_again()
	_expect(accepted.size() == 1 and GameManager.try_again_stocks == 1, "Explicit recovery spends exactly one continue")
	_expect(GameManager.lives == 3, "Recovery retains loadout-based starting lives")
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
