extends Node
## Headless regression coverage for the SaveManager, ObjectPool,
## MetaProgression, and GameManager autoloads.
##
## Run with:
## godot --headless --path . res://tests/autoload_smoke.tscn
## (Run the .tscn wrapper, not --script: --script mode skips the autoloads
## these tests depend on and never exits.)

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_object_pool()
	await _check_save_manager()
	await _check_meta_progression()

	if _failures.is_empty():
		print("PASS: autoload smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# --- ObjectPool ---

func _check_object_pool() -> void:
	var holder := Node.new()
	add_child(holder)

	var first := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(first != null, "Pool acquire must return a node for an empty bucket")
	_expect(first.get_parent() == holder, "Acquired node must be parented to the given parent")

	ObjectPool.release(first)
	_expect(first.get_parent() == ObjectPool, "Released node must be reparented to the pool")

	var second := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(second == first, "Second acquire must reuse the released instance")

	# Double release must not corrupt the bucket
	ObjectPool.release(second)
	ObjectPool.release(second)
	var third := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(third == second, "Double release must not duplicate the pooled instance")
	ObjectPool.release(third)

	# Releasing a node with no pool key must fall back to queue_free
	var stray := Node2D.new()
	holder.add_child(stray)
	ObjectPool.release(stray)
	_expect(stray.is_queued_for_deletion(), "Non-pooled release must queue_free the node")

	# Idle cap: releasing more than the cap frees the overflow instead of pooling it
	var extra: Array[Node] = []
	for i in range(ObjectPool.MAX_IDLE_PER_SCENE + 2):
		extra.append(ObjectPool.acquire(BULLET_SCENE, holder))
	for node in extra:
		ObjectPool.release(node)
	var pooled_count := 0
	for child in ObjectPool.get_children():
		if child is Area2D:
			pooled_count += 1
	_expect(pooled_count <= ObjectPool.MAX_IDLE_PER_SCENE, "Idle pool must respect MAX_IDLE_PER_SCENE")

	holder.queue_free()


# --- SaveManager ---

func _check_save_manager() -> void:
	var save_path: String = SaveManager.SAVE_PATH
	var had_save := FileAccess.file_exists(save_path)
	var original_bytes: PackedByteArray = []
	if had_save:
		original_bytes = FileAccess.get_file_as_bytes(save_path)
	var original_settings: Dictionary = SaveManager.settings.duplicate(true)
	var original_high_score: int = SaveManager.high_score

	# Unknown keys are ignored by update_setting
	SaveManager.update_setting("not_a_real_key", 123)
	_expect(not SaveManager.settings.has("not_a_real_key"), "update_setting must ignore unknown keys")

	# Malformed JSON keeps current in-memory state
	_write_save("{not valid json")
	SaveManager._load_data()
	_expect(
		bool(SaveManager.settings.get("screen_shake")) == bool(original_settings.get("screen_shake")),
		"Malformed save must not corrupt in-memory settings"
	)

	# Hand-edited type mismatch: "screen_shake": "false" (string) must be
	# rejected, not coerced to true
	_write_save('{"version": 1, "high_score": 500, "settings": {"screen_shake": "false", "music_volume": 0.3}}')
	SaveManager._load_data()
	_expect(
		bool(SaveManager.settings.get("screen_shake")) == bool(SaveManager.DEFAULT_SETTINGS.get("screen_shake")),
		"String-typed boolean must be rejected in favor of the default"
	)
	_expect(SaveManager.high_score == 500, "Valid high_score must load from the save file")
	_expect(
		is_equal_approx(float(SaveManager.settings.get("music_volume")), 0.3),
		"Valid music_volume must load from the save file"
	)

	# Pre-versioning save (no version key) is treated as the current schema
	_write_save('{"high_score": 700, "settings": {}}')
	SaveManager._load_data()
	_expect(SaveManager.high_score == 700, "Save without a version key must still load")

	# Mismatched explicit version is rejected
	_write_save('{"version": 999, "high_score": 1, "settings": {}}')
	SaveManager.high_score = 42
	SaveManager._load_data()
	_expect(SaveManager.high_score == 42, "Mismatched save version must be rejected")

	# Restore the player's real save data and in-memory state
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(original_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(save_path)
	SaveManager.settings = original_settings
	SaveManager.high_score = original_high_score
	SaveManager._apply_audio_settings()
	SaveManager._apply_control_scheme()
	await get_tree().process_frame


func _write_save(content: String) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


# --- MetaProgression ---

func _check_meta_progression() -> void:
	var save_path: String = SaveManager.SAVE_PATH
	var had_save := FileAccess.file_exists(save_path)
	var original_bytes: PackedByteArray = []
	if had_save:
		original_bytes = FileAccess.get_file_as_bytes(save_path)
	var original_salvage: int = MetaProgression.salvage
	var original_levels: Dictionary = MetaProgression.unlock_levels.duplicate()
	var original_ship: String = MetaProgression.selected_ship
	var original_modifiers: Array[String] = MetaProgression.active_modifiers.duplicate()
	var original_score: int = GameManager.score
	var original_wave: int = GameManager.current_wave
	var original_run_salvage: int = GameManager.run_salvage
	var original_finalized: bool = GameManager._run_finalized

	# Start from a clean wallet so cost arithmetic is deterministic.
	MetaProgression.salvage = 0
	MetaProgression.unlock_levels = {}
	MetaProgression.selected_ship = MetaProgression.DEFAULT_SHIP
	MetaProgression.active_modifiers = []

	# Earning persists to the SaveManager mirror.
	MetaProgression.earn_salvage(75)
	_expect(MetaProgression.salvage == 75, "earn_salvage must increase the wallet")
	_expect(SaveManager.salvage == 75, "earn_salvage must persist through SaveManager")
	MetaProgression.earn_salvage(0)
	_expect(MetaProgression.salvage == 75, "Zero/negative earnings must be ignored")

	# Tiered purchases: blocked without funds, escalating costs, level cap.
	_expect(not MetaProgression.purchase("meta_hull"), "Purchase without funds must fail")
	MetaProgression.earn_salvage(2000)
	_expect(MetaProgression.get_next_cost("meta_hull") == 150, "First hull tier must cost 150")
	_expect(MetaProgression.purchase("meta_hull"), "First hull tier must be purchasable")
	_expect(MetaProgression.get_level("meta_hull") == 1, "Hull level must be 1 after first purchase")
	_expect(MetaProgression.salvage == 1925, "Purchase must deduct the tier cost")
	_expect(MetaProgression.get_next_cost("meta_hull") == 300, "Second hull tier must cost 300")
	MetaProgression.purchase("meta_hull")
	MetaProgression.purchase("meta_hull")
	_expect(MetaProgression.get_level("meta_hull") == 3, "Hull must reach level 3")
	_expect(MetaProgression.get_next_cost("meta_hull") == -1, "Maxed item must report no next cost")
	_expect(not MetaProgression.purchase("meta_hull"), "Maxed item must not be purchasable")
	_expect(not MetaProgression.purchase("not_a_real_item"), "Unknown item must not be purchasable")

	# Single-level items (ships, modifiers, blueprints) cap at level 1.
	MetaProgression.purchase("ship_interceptor")
	_expect(MetaProgression.get_level("ship_interceptor") == 1, "Ship purchase must record level 1")
	_expect(not MetaProgression.purchase("ship_interceptor"), "Owned ship must not be purchasable again")

	# Save round-trip: wallet, levels, and selections survive a reload.
	MetaProgression.select_ship("ship_interceptor")
	MetaProgression.purchase("mod_tough_enemies")
	MetaProgression.set_modifier_active("mod_tough_enemies", true)
	SaveManager._load_data()
	_expect(int(SaveManager.unlock_levels.get("meta_hull", 0)) == 3, "Unlock levels must survive a save reload")
	_expect(SaveManager.selected_ship == "ship_interceptor", "Ship selection must survive a save reload")
	_expect(SaveManager.active_modifiers.has("mod_tough_enemies"), "Active modifiers must survive a save reload")

	# Migration: a pre-tiers purchased_unlocks array becomes level-1 unlocks.
	_write_save('{"version": 1, "salvage": 10, "purchased_unlocks": ["meta_hull", "meta_orbitals"]}')
	SaveManager.unlock_levels = {}
	SaveManager._load_data()
	_expect(
		int(SaveManager.unlock_levels.get("meta_hull", 0)) == 1 and int(SaveManager.unlock_levels.get("meta_orbitals", 0)) == 1,
		"Legacy purchased_unlocks array must migrate to level-1 unlocks"
	)

	# Hand-edited saves: mistyped salvage and levels are rejected.
	_write_save('{"version": 1, "salvage": "lots", "unlock_levels": {"a": 2, "b": "x", "c": 0}}')
	SaveManager.salvage = 5
	SaveManager.unlock_levels = {}
	SaveManager._load_data()
	_expect(SaveManager.salvage == 5, "String-typed salvage must be rejected in favor of in-memory value")
	_expect(
		SaveManager.unlock_levels == {"a": 2},
		"Unlock levels must keep valid positive-int entries only"
	)

	# Ship selection rules: locked ships are ignored; the base ship is always owned.
	MetaProgression.unlock_levels = {}
	MetaProgression.select_ship("ship_swallowtail")
	MetaProgression.select_ship("ship_bulwark")
	_expect(MetaProgression.selected_ship == "ship_swallowtail", "Locked ship must not be selectable")
	MetaProgression.unlock_levels = {"ship_bulwark": 1}
	MetaProgression.select_ship("ship_bulwark")
	_expect(MetaProgression.selected_ship == "ship_bulwark", "Owned ship must be selectable")
	_expect(float(MetaProgression.get_selected_ship_profile().get("lives_delta", 0)) == 2.0, "Bulwark profile must grant +2 lives")

	# Modifier toggles and the salvage multiplier.
	MetaProgression.unlock_levels = {"mod_tough_enemies": 1, "mod_orb_drought": 1}
	MetaProgression.active_modifiers = []
	MetaProgression.set_modifier_active("mod_no_powerups", true)
	_expect(not MetaProgression.is_modifier_active("mod_no_powerups"), "Locked modifier must not activate")
	MetaProgression.set_modifier_active("mod_tough_enemies", true)
	MetaProgression.set_modifier_active("mod_orb_drought", true)
	_expect(
		is_equal_approx(MetaProgression.get_salvage_multiplier(), 1.55),
		"Active modifiers must stack additively into the multiplier"
	)
	MetaProgression.set_modifier_active("mod_orb_drought", false)
	_expect(is_equal_approx(MetaProgression.get_salvage_multiplier(), 1.30), "Untoggled modifier must leave the multiplier")

	# The elite upgrade pool grows when a blueprint unlock is owned.
	GameManager.chosen_upgrade_ids = []
	var base_pool_size := GameManager.ALL_UPGRADES.size()
	MetaProgression.unlock_levels = {}
	_expect(
		GameManager.get_upgrade_pool().size() == base_pool_size,
		"Pool must equal the base catalog without blueprint unlocks"
	)
	MetaProgression.unlock_levels = {"meta_orbitals": 1}
	_expect(
		GameManager.get_upgrade_pool().size() == base_pool_size + 1,
		"Pool must gain the orbitals elite once its blueprint is owned"
	)

	# finalize_run banks a multiplied, itemized end-of-run bonus exactly once.
	MetaProgression.salvage = 0
	MetaProgression.unlock_levels = {"mod_tough_enemies": 1}
	MetaProgression.active_modifiers = ["mod_tough_enemies"]
	GameManager.score = 5000
	GameManager.current_wave = 6
	GameManager.run_salvage = 0
	GameManager.run_salvage_multiplier = 1.3
	GameManager._run_finalized = false
	GameManager.finalize_run()
	# (5000/100)*1.3 = 65 score bonus, (5*2)*1.3 = 13 wave bonus
	_expect(GameManager.run_salvage == 78, "finalize_run must bank the multiplied total")
	_expect(GameManager.run_salvage_score_bonus == 65, "finalize_run must itemize the score bonus")
	_expect(GameManager.run_salvage_wave_bonus == 13, "finalize_run must itemize the wave bonus")
	_expect(MetaProgression.salvage == 78, "finalize_run must earn the same amount into the wallet")
	GameManager.finalize_run()
	_expect(GameManager.run_salvage == 78, "finalize_run must not bank twice for the same run")

	# start_game applies the full loadout: tiers, ship profile, modifiers.
	GameManager.run_salvage = 42
	GameManager._run_finalized = true
	MetaProgression.unlock_levels = {
		"meta_hull": 2, "meta_reserves": 1, "meta_thrusters": 2, "meta_cannons": 1,
		"ship_interceptor": 1, "mod_frail": 1, "mod_orb_drought": 1,
		"mod_fast_spawns": 1, "mod_tough_enemies": 1,
	}
	MetaProgression.selected_ship = "ship_interceptor"
	MetaProgression.active_modifiers = ["mod_frail", "mod_orb_drought", "mod_fast_spawns", "mod_tough_enemies"]
	GameManager.start_game()
	# Lives: 3 base + 2 hull - 1 interceptor - 1 frail = 3
	_expect(GameManager.lives == 3, "start_game must stack ship, hull, and frail life deltas")
	_expect(GameManager.try_again_stocks == 3, "meta_reserves must grant +1 try-again stock per level")
	_expect(
		is_equal_approx(GameManager.meta_speed_pct, MetaProgression.META_SPEED_BONUS * 2.0),
		"meta_thrusters must scale its bonus with level"
	)
	_expect(
		is_equal_approx(GameManager.ship_speed_pct, 0.15) and is_equal_approx(GameManager.ship_fire_rate_pct, 0.10),
		"Ship profile bonuses must apply at start_game"
	)
	_expect(
		GameManager.orbs_needed_this_wave == int((10.0 + 1.3) * 1.5),
		"Energy Drought must raise the wave-1 orb threshold by 50%"
	)
	_expect(
		is_equal_approx(GameManager.get_spawn_interval(), GameManager.base_spawn_interval * 0.8),
		"Rapid Assault must shorten the spawn interval by 20%"
	)
	_expect(
		is_equal_approx(GameManager.get_enemy_health_multiplier(), 1.3),
		"Armored Fleet must raise the enemy health multiplier"
	)
	_expect(
		is_equal_approx(GameManager.run_salvage_multiplier, 1.90),
		"start_game must snapshot the active modifier multiplier"
	)
	_expect(GameManager.run_salvage == 0 and not GameManager._run_finalized, "start_game must reset run salvage state")

	# Restore the player's real save data and in-memory state.
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(original_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(save_path)
	MetaProgression.salvage = original_salvage
	MetaProgression.unlock_levels = original_levels
	MetaProgression.selected_ship = original_ship
	MetaProgression.active_modifiers = original_modifiers
	SaveManager.salvage = original_salvage
	SaveManager.unlock_levels = original_levels.duplicate()
	SaveManager.selected_ship = original_ship
	SaveManager.active_modifiers = original_modifiers.duplicate()
	GameManager.score = original_score
	GameManager.current_wave = original_wave
	GameManager.run_salvage = original_run_salvage
	GameManager.run_salvage_boss = 0
	GameManager.run_salvage_score_bonus = 0
	GameManager.run_salvage_wave_bonus = 0
	GameManager.run_salvage_multiplier = 1.0
	GameManager._run_finalized = original_finalized
	GameManager.chosen_upgrade_ids = []
	GameManager.lives = 3
	GameManager.try_again_stocks = 2
	GameManager.meta_speed_pct = 0.0
	GameManager.meta_fire_rate_pct = 0.0
	GameManager.ship_speed_pct = 0.0
	GameManager.ship_fire_rate_pct = 0.0
	GameManager.is_game_active = false
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
