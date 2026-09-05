extends Native3DGameplay
## Optional CI behavior coverage. This task deliberately did not run Godot.
const BossScene := preload("res://entities/enemies/boss_enemy_3d.tscn")
const UpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
var _failures: Array[String] = []

class DamageTarget extends Area3D:
	var damage_received := 0
	func take_damage(amount: int) -> void:
		damage_received += amount

func _ready() -> void:
	await super._ready()
	_run_checks.call_deferred()

func _run_checks() -> void:
	_expect(GameManager.is_game_active, "Native scene must initialize")
	for id in UpgradeCatalog.SUPPORTED_IDS:
		_expect(player.apply_elite_upgrade(id), "Upgrade applies: " + id)
		_expect(not player.apply_elite_upgrade(id), "Duplicate rejected: " + id)
	_expect(player.get_active_elite_upgrade_ids().size() == 13, "All native capabilities exposed")
	player.has_spread_shot = true
	_expect(player._get_fire_directions().size() == 5, "Temporary and elite spread stack")
	var first := DamageTarget.new()
	var second := DamageTarget.new()
	$World3D.add_child(first)
	$World3D.add_child(second)
	first.collision_layer = 2
	second.collision_layer = 2
	projectile_manager.fire_player_projectile(player.global_position, Vector3.FORWARD)
	var shots := get_tree().get_nodes_in_group(&"player_projectiles")
	_expect(not shots.is_empty(), "Player projectile acquired")
	if not shots.is_empty():
		var shot := shots.back() as Projectile3D
		_expect(shot.homing and shot.piercing and shot.explosive, "Projectile snapshots upgrades")
		shot._report_hit(first, player.global_position)
		shot._report_hit(first, player.global_position)
		shot._report_hit(second, player.global_position)
		_expect(first.damage_received == 1 + GameManager.bonus_damage, "Piercing target hit exactly once")
		_expect(second.damage_received == first.damage_received, "Piercing continues to another target")
		_expect(shot.is_active, "Piercing retains projectile")
	projectile_manager.clear_projectiles()
	first.queue_free()
	second.queue_free()
	player.reset_elite_upgrades()
	player.reset_power_up_state()
	_expect(player.get_active_elite_upgrade_ids().is_empty(), "Reset clears permanent local state")
	_expect(not player.is_drone_escort_enabled(), "Reset disables drone")
	await get_tree().process_frame
	await get_tree().process_frame
	projectile_manager.fire_player_projectile(player.global_position, Vector3.FORWARD)
	shots = get_tree().get_nodes_in_group(&"player_projectiles")
	if not shots.is_empty():
		var recycled := shots.back() as Projectile3D
		_expect(not recycled.homing and not recycled.piercing and not recycled.explosive, "Pool reuse clears modifiers")
	projectile_manager.clear_projectiles()
	for index in 5:
		GameManager.current_wave = (index + 1) * 5
		var boss := BossScene.instantiate()
		actors_root.add_child(boss)
		_expect(boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 1), "Boss activates")
		_expect(boss.variant == index, "Wave selects correct boss hull")
		if index > 0:
			_expect(boss._active_section_count() == 2, "Boss has destructible pods")
			boss._sections[0].take_damage(99999)
			_expect(boss._active_section_count() == 1, "Destroyed pod stops contributing")
		boss.queue_free()
	GameManager.is_game_active = false
	if _failures.is_empty():
		print("PASS: native upgrades, projectile reuse, and five boss variants")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
