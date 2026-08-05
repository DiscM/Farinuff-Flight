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

	# A stale pooled reference can exist when another system frees an inactive
	# node during a scene teardown. The pool must discard it without crashing.
	var stale := ObjectPool.acquire(BULLET_SCENE, holder)
	ObjectPool.release(stale)
	stale.free()
	var recovered := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(recovered != null, "Pool must skip stale freed references")
	ObjectPool.release(recovered)

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
	var backup_path: String = SaveManager.SAVE_BACKUP_PATH
	var temp_path: String = SaveManager.SAVE_TEMP_PATH
	var had_save := FileAccess.file_exists(save_path)
	var original_bytes: PackedByteArray = []
	if had_save:
		original_bytes = FileAccess.get_file_as_bytes(save_path)
	var had_backup := FileAccess.file_exists(backup_path)
	var original_backup_bytes: PackedByteArray = []
	if had_backup:
		original_backup_bytes = FileAccess.get_file_as_bytes(backup_path)
	var had_temp := FileAccess.file_exists(temp_path)
	var original_temp_bytes: PackedByteArray = []
	if had_temp:
		original_temp_bytes = FileAccess.get_file_as_bytes(temp_path)
	var original_settings: Dictionary = SaveManager.settings.duplicate(true)
	var original_high_score: int = SaveManager.high_score
	var original_flight_school_seen: bool = SaveManager.has_seen_flight_school
	var original_save_read_only: bool = SaveManager._save_read_only_due_to_future_version

	# Remove transactional leftovers for deterministic test fixtures. Restore
	# them verbatim at the end so the smoke test is non-destructive.
	if had_backup:
		DirAccess.remove_absolute(backup_path)
	if had_temp:
		DirAccess.remove_absolute(temp_path)

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

	# Pre-versioning save (no version key) is treated as the legacy schema
	_write_save('{"high_score": 700, "settings": {}}')
	SaveManager._load_data()
	_expect(SaveManager.high_score == 700, "Save without a version key must still load")

	# Versioned writes are atomic and keep a recoverable previous copy.
	SaveManager.record_high_score(701)
	_expect(FileAccess.file_exists(backup_path), "Save writes must keep a backup of the previous copy")
	_write_save("{not valid json")
	SaveManager.high_score = 42
	SaveManager._load_data()
	_expect(SaveManager.high_score == 700, "Malformed primary save must recover from its backup")

	# Additive v2 fields load without invalidating a v1-compatible save.
	_write_save('{"version": 2, "high_score": 800, "has_seen_flight_school": true, "settings": {}}')
	SaveManager.has_seen_flight_school = false
	SaveManager._load_data()
	_expect(SaveManager.high_score == 800, "Current schema save must load normally")
	_expect(SaveManager.has_seen_flight_school, "Current schema onboarding state must load")

	SaveManager.has_seen_flight_school = false
	SaveManager.mark_flight_school_seen()
	_expect(SaveManager.has_seen_flight_school, "Flight School completion must persist in memory")

	# Mismatched explicit version is rejected
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	_write_save('{"version": 999, "high_score": 1, "settings": {}}')
	SaveManager.high_score = 42
	SaveManager._load_data()
	_expect(SaveManager.high_score == 42, "Mismatched save version must be rejected")
	SaveManager.record_high_score(900)
	var future_save := FileAccess.get_file_as_string(save_path)
	_expect(
		future_save.contains('"version": 999'),
		"A future save must remain intact when this build cannot migrate it"
	)

	# Restore the player's real save data and in-memory state
	_restore_file(save_path, had_save, original_bytes)
	_restore_file(backup_path, had_backup, original_backup_bytes)
	_restore_file(temp_path, had_temp, original_temp_bytes)
	SaveManager.settings = original_settings
	SaveManager.high_score = original_high_score
	SaveManager.has_seen_flight_school = original_flight_school_seen
	SaveManager._save_read_only_due_to_future_version = original_save_read_only
	SaveManager._apply_audio_settings()
	SaveManager._apply_control_scheme()
	await get_tree().process_frame


func _write_save(content: String) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _restore_file(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# --- MetaProgression ---

func _check_meta_progression() -> void:
	var save_path: String = SaveManager.SAVE_PATH
	var backup_path: String = SaveManager.SAVE_BACKUP_PATH
	var temp_path: String = SaveManager.SAVE_TEMP_PATH
	var had_save := FileAccess.file_exists(save_path)
	var original_bytes: PackedByteArray = []
	if had_save:
		original_bytes = FileAccess.get_file_as_bytes(save_path)
	var had_backup := FileAccess.file_exists(backup_path)
	var original_backup_bytes: PackedByteArray = []
	if had_backup:
		original_backup_bytes = FileAccess.get_file_as_bytes(backup_path)
	var had_temp := FileAccess.file_exists(temp_path)
	var original_temp_bytes: PackedByteArray = []
	if had_temp:
		original_temp_bytes = FileAccess.get_file_as_bytes(temp_path)
	var original_salvage: int = MetaProgression.salvage
	var original_levels: Dictionary = MetaProgression.unlock_levels.duplicate()
	var original_ship: String = MetaProgression.selected_ship
	var original_modifiers: Array[String] = MetaProgression.active_modifiers.duplicate()
	var original_stocks: int = MetaProgression.consumable_stocks
	var original_powerup_armed: bool = MetaProgression.consumable_powerup_armed
	var original_milestones: Array[int] = MetaProgression.claimed_milestones.duplicate()
	var original_total_runs: int = MetaProgression.stat_total_runs
	var original_total_kills: int = MetaProgression.stat_total_kills
	var original_best_wave: int = MetaProgression.stat_best_wave
	var original_score: int = GameManager.score
	var original_wave: int = GameManager.current_wave
	var original_run_salvage: int = GameManager.run_salvage
	var original_finalized: bool = GameManager._run_finalized
	var original_expedition_completed: bool = GameManager.expedition_completed
	var original_game_active: bool = GameManager.is_game_active
	var original_boss_active: bool = GameManager.boss_active

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
	MetaProgression.consumable_stocks = 2
	MetaProgression.consumable_powerup_armed = true
	MetaProgression.claimed_milestones = [5]
	MetaProgression.stat_total_runs = 3
	MetaProgression.stat_total_kills = 77
	MetaProgression.stat_best_wave = 9
	MetaProgression._persist()
	SaveManager._load_data()
	_expect(int(SaveManager.unlock_levels.get("meta_hull", 0)) == 3, "Unlock levels must survive a save reload")
	_expect(SaveManager.selected_ship == "ship_interceptor", "Ship selection must survive a save reload")
	_expect(SaveManager.active_modifiers.has("mod_tough_enemies"), "Active modifiers must survive a save reload")
	_expect(SaveManager.consumable_stocks == 2, "Consumable stockpile must survive a save reload")
	_expect(SaveManager.consumable_powerup, "Armed drop pod must survive a save reload")
	_expect(SaveManager.claimed_milestones == [5], "Claimed milestones must survive a save reload")
	_expect(
		SaveManager.stat_total_runs == 3 and SaveManager.stat_total_kills == 77 and SaveManager.stat_best_wave == 9,
		"Lifetime stats must survive a save reload"
	)

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

	# Diminishing score conversion: salvage = sqrt(score / 10).
	_expect(MetaProgression.score_to_salvage(0) == 0, "Zero score must convert to zero salvage")
	_expect(MetaProgression.score_to_salvage(1000) == 10, "score_to_salvage must use sqrt scaling")
	_expect(MetaProgression.score_to_salvage(40000) == 63, "Deep scores must see diminishing returns")

	# Boss kills bank salvage immediately; elite (Wave-10) bosses pay double.
	MetaProgression.salvage = 0
	GameManager.run_salvage = 0
	GameManager.run_salvage_boss = 0
	GameManager.run_salvage_multiplier = 1.0
	GameManager.chosen_upgrade_ids = []
	GameManager.current_wave = 5
	GameManager._on_boss_died(0)
	_expect(
		GameManager.run_salvage_boss == MetaProgression.SALVAGE_PER_BOSS,
		"Regular boss must bank its salvage reward"
	)
	GameManager.current_wave = 10
	GameManager._on_boss_died(0)
	_expect(
		GameManager.run_salvage_boss == MetaProgression.SALVAGE_PER_BOSS + MetaProgression.SALVAGE_PER_ELITE_BOSS,
		"Elite boss must pay double the regular reward"
	)
	_expect(
		MetaProgression.salvage == MetaProgression.SALVAGE_PER_BOSS + MetaProgression.SALVAGE_PER_ELITE_BOSS,
		"Boss salvage must reach the wallet immediately"
	)

	# Wave 20 is the finite Expedition climax; the player can explicitly
	# continue into Endless after the victory state instead of being forced to
	# treat the victory as an ordinary wave transition.
	GameManager.current_wave = GameManager.FINAL_EXPEDITION_WAVE
	GameManager.run_salvage = 0
	GameManager.run_salvage_boss = 0
	GameManager.run_salvage_multiplier = 1.0
	GameManager.chosen_upgrade_ids = []
	GameManager.boss_active = true
	GameManager.is_game_active = true
	GameManager.expedition_completed = false
	GameManager._on_boss_died(0)
	_expect(GameManager.expedition_completed, "Wave 20 boss must complete the Expedition")
	_expect(not GameManager.is_game_active, "Expedition completion must stop active gameplay")
	_expect(GameManager.current_wave == GameManager.FINAL_EXPEDITION_WAVE + 1, "Expedition completion must stage Endless at wave 21")
	_expect(GameManager.run_salvage_boss == MetaProgression.SALVAGE_PER_ELITE_BOSS, "Tempest Core must bank its elite salvage reward")
	_expect(GameManager.continue_into_endless(), "Completed Expedition must offer an Endless continuation")
	_expect(GameManager.is_game_active and not GameManager.expedition_completed, "Endless continuation must resume active gameplay")

	# First-clear milestones: flat one-time awards keyed on waves cleared.
	MetaProgression.claimed_milestones = []
	_expect(MetaProgression.claim_first_clear_milestones(4) == 0, "No milestone may award below wave 5")
	_expect(MetaProgression.claim_first_clear_milestones(10) == 150, "Wave 5+10 milestones must pay 50+100")
	_expect(
		MetaProgression.claimed_milestones.has(5) and MetaProgression.claimed_milestones.has(10),
		"Claimed milestones must be recorded"
	)
	_expect(MetaProgression.claim_first_clear_milestones(12) == 0, "Milestones must be one-time only")

	# Lifetime stats accumulate across runs and track the best wave.
	MetaProgression.stat_total_runs = 0
	MetaProgression.stat_total_kills = 0
	MetaProgression.stat_best_wave = 0
	MetaProgression.record_run_stats(7, 42)
	_expect(
		MetaProgression.stat_total_runs == 1 and MetaProgression.stat_total_kills == 42,
		"record_run_stats must accumulate totals"
	)
	_expect(
		MetaProgression.stat_best_wave == 7 and MetaProgression.last_run_set_best_wave,
		"First recorded run must set the best wave"
	)
	MetaProgression.record_run_stats(5, 8)
	_expect(
		MetaProgression.stat_best_wave == 7 and not MetaProgression.last_run_set_best_wave,
		"A weaker run must not touch the best wave"
	)
	_expect(MetaProgression.stat_total_kills == 50, "Kill totals must accumulate across runs")

	# finalize_run banks a multiplied, itemized end-of-run bonus exactly once.
	MetaProgression.salvage = 0
	MetaProgression.unlock_levels = {"mod_tough_enemies": 1}
	MetaProgression.active_modifiers = ["mod_tough_enemies"]
	MetaProgression.claimed_milestones = []
	MetaProgression.stat_total_runs = 0
	MetaProgression.stat_total_kills = 0
	MetaProgression.stat_best_wave = 0
	GameManager.score = 5000
	GameManager.current_wave = 6
	GameManager.run_kills = 17
	GameManager.run_salvage = 0
	GameManager.run_salvage_milestones = 0
	GameManager.run_salvage_multiplier = 1.3
	GameManager._run_finalized = false
	GameManager.finalize_run()
	# sqrt(5000/10) ≈ 22.36 → 22 salvage; ×1.3 = 28.6 → 29 score bonus.
	# 5 waves × ⬡3 × 1.3 = 19.5 → 20 wave bonus. Wave-5 milestone = flat ⬡50.
	_expect(GameManager.run_salvage_score_bonus == 29, "finalize_run must itemize the diminishing score bonus")
	_expect(GameManager.run_salvage_wave_bonus == 20, "finalize_run must itemize the wave bonus")
	_expect(GameManager.run_salvage_milestones == 50, "finalize_run must itemize the flat milestone bonus")
	_expect(GameManager.run_salvage == 99, "finalize_run must bank the multiplied total plus flat milestones")
	_expect(MetaProgression.salvage == 99, "finalize_run must earn the same amount into the wallet")
	_expect(
		MetaProgression.claimed_milestones.has(5) and MetaProgression.claimed_milestones.size() == 1,
		"finalize_run must claim the reached milestone"
	)
	_expect(
		MetaProgression.stat_total_runs == 1 and MetaProgression.stat_total_kills == 17,
		"finalize_run must record lifetime stats"
	)
	_expect(
		MetaProgression.stat_best_wave == 6 and MetaProgression.last_run_set_best_wave,
		"finalize_run must track the best wave"
	)
	GameManager.finalize_run()
	_expect(GameManager.run_salvage == 99, "finalize_run must not bank twice for the same run")

	# Consumables: repeatable purchases with a stockpile cap and one-shot pod.
	MetaProgression.salvage = 500
	MetaProgression.consumable_stocks = 0
	MetaProgression.consumable_powerup_armed = false
	_expect(MetaProgression.get_next_cost("consumable_stock") == 120, "Reserve Stock must cost 120")
	_expect(MetaProgression.purchase("consumable_stock"), "First Reserve Stock must be purchasable")
	_expect(MetaProgression.consumable_stocks == 1, "Stock purchase must increment the stockpile")
	MetaProgression.purchase("consumable_stock")
	MetaProgression.purchase("consumable_stock")
	_expect(
		MetaProgression.get_level("consumable_stock") == 3 and MetaProgression.get_max_level("consumable_stock") == 3,
		"Stockpile must report its level pips"
	)
	_expect(MetaProgression.get_next_cost("consumable_stock") == -1, "Full stockpile must report no next cost")
	_expect(not MetaProgression.purchase("consumable_stock"), "Full stockpile must not be purchasable")
	_expect(MetaProgression.purchase("consumable_powerup"), "Drop pod must be purchasable")
	_expect(MetaProgression.consumable_powerup_armed, "Drop pod purchase must arm the pod")
	_expect(MetaProgression.get_next_cost("consumable_powerup") == -1, "Armed drop pod must report no next cost")
	_expect(not MetaProgression.purchase("consumable_powerup"), "Armed drop pod must not be purchasable again")
	# 500 - 3×120 - 100 = 40
	_expect(MetaProgression.salvage == 40, "Consumable purchases must deduct their costs")
	_expect(MetaProgression.consume_stockpile() == 3, "consume_stockpile must return the stockpile")
	_expect(MetaProgression.consumable_stocks == 0, "consume_stockpile must zero the stockpile")
	_expect(MetaProgression.consume_powerup_pod(), "consume_powerup_pod must report the armed pod")
	_expect(not MetaProgression.consume_powerup_pod(), "consume_powerup_pod must only fire once")

	# start_game applies the full loadout: tiers, ship profile, modifiers,
	# and consumes the Hangar field supply.
	GameManager.run_salvage = 42
	GameManager._run_finalized = true
	MetaProgression.unlock_levels = {
		"meta_hull": 2, "meta_reserves": 1, "meta_thrusters": 2, "meta_cannons": 1,
		"ship_interceptor": 1, "mod_frail": 1, "mod_orb_drought": 1,
		"mod_fast_spawns": 1, "mod_tough_enemies": 1,
	}
	MetaProgression.selected_ship = "ship_interceptor"
	MetaProgression.active_modifiers = ["mod_frail", "mod_orb_drought", "mod_fast_spawns", "mod_tough_enemies"]
	MetaProgression.consumable_stocks = 2
	MetaProgression.consumable_powerup_armed = true
	GameManager.start_game()
	# Lives: 3 base + 2 hull - 1 interceptor - 1 frail = 3
	_expect(GameManager.lives == 3, "start_game must stack ship, hull, and frail life deltas")
	_expect(GameManager.starting_lives == 3, "starting_lives must capture the loadout-adjusted lives")
	_expect(GameManager.try_again_stocks == 5, "reserves +1 and stockpile +2 must stack onto the base 2 stocks")
	_expect(MetaProgression.consumable_stocks == 0, "start_game must consume the stockpile")
	_expect(GameManager.pending_start_powerup, "start_game must flag the armed drop pod for the game scene")
	_expect(not MetaProgression.consumable_powerup_armed, "start_game must consume the armed pod")
	_expect(GameManager.run_kills == 0, "start_game must reset the run kill counter")
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

	# Orb carry-over caps at half the new wave's threshold; small surpluses
	# carry through intact.
	GameManager.boss_active = false
	GameManager.current_wave = 1
	GameManager.orbs_needed_this_wave = GameManager.get_orb_threshold_for_wave(1)
	GameManager.orbs_collected_this_wave = 100
	GameManager._advance_wave()
	_expect(
		GameManager.orbs_collected_this_wave == floori(
			float(GameManager.get_orb_threshold_for_wave(2)) / 2.0
		),
		"A huge orb surplus must be capped at half the new wave's threshold"
	)
	GameManager.orbs_needed_this_wave = GameManager.get_orb_threshold_for_wave(GameManager.current_wave)
	GameManager.orbs_collected_this_wave = GameManager.orbs_needed_this_wave + 2
	GameManager._advance_wave()
	_expect(GameManager.orbs_collected_this_wave == 2, "A small orb surplus must carry over intact")

	# Late-game drift multipliers keep endless runs scaling past Gen IV.
	_expect(is_equal_approx(GameManager.get_late_game_health_multiplier(16), 1.0), "No health drift at wave 16")
	_expect(
		is_equal_approx(GameManager.get_late_game_health_multiplier(26), 1.4),
		"Health drift must grow +4% per wave past 16"
	)
	_expect(is_equal_approx(GameManager.get_late_game_health_multiplier(100), 2.0), "Health drift must cap at ×2.0")
	_expect(is_equal_approx(GameManager.get_late_game_speed_multiplier(16), 1.0), "No speed drift at wave 16")
	_expect(is_equal_approx(GameManager.get_late_game_speed_multiplier(100), 1.30), "Speed drift must cap at ×1.30")

	# ThreatDirector grows the active cap / budget late-game.
	var director := ThreatDirector.new()
	add_child(director)
	_expect(director.get_late_pressure_bonus(15) == 0, "No pressure bonus at wave 15")
	_expect(director.get_late_pressure_bonus(20) == 1, "Pressure bonus must step every 5 waves past 15")
	_expect(director.get_late_pressure_bonus(60) == 3, "Pressure bonus must cap at +3")
	director.queue_free()

	# Restore the player's real save data and in-memory state.
	_restore_file(save_path, had_save, original_bytes)
	_restore_file(backup_path, had_backup, original_backup_bytes)
	_restore_file(temp_path, had_temp, original_temp_bytes)
	MetaProgression.salvage = original_salvage
	MetaProgression.unlock_levels = original_levels
	MetaProgression.selected_ship = original_ship
	MetaProgression.active_modifiers = original_modifiers
	MetaProgression.consumable_stocks = original_stocks
	MetaProgression.consumable_powerup_armed = original_powerup_armed
	MetaProgression.claimed_milestones = original_milestones
	MetaProgression.stat_total_runs = original_total_runs
	MetaProgression.stat_total_kills = original_total_kills
	MetaProgression.stat_best_wave = original_best_wave
	MetaProgression.last_run_set_best_wave = false
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
	GameManager.run_salvage_milestones = 0
	GameManager.run_salvage_multiplier = 1.0
	GameManager._run_finalized = original_finalized
	GameManager.expedition_completed = original_expedition_completed
	GameManager.chosen_upgrade_ids = []
	GameManager.lives = 3
	GameManager.starting_lives = 3
	GameManager.try_again_stocks = 2
	GameManager.run_kills = 0
	GameManager.pending_start_powerup = false
	GameManager.boss_active = false
	GameManager.meta_speed_pct = 0.0
	GameManager.meta_fire_rate_pct = 0.0
	GameManager.ship_speed_pct = 0.0
	GameManager.ship_fire_rate_pct = 0.0
	GameManager.is_game_active = false
	GameManager.boss_active = original_boss_active
	GameManager.is_game_active = original_game_active
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
