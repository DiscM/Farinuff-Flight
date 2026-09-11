extends Native3DGameplay
## Production native run: encounters and run UI around the shared combat scene.

const EncounterDirector := preload("res://systems/native_encounter_director.gd")
const TRY_AGAIN := preload("res://ui/try_again_popup.tscn")
const GAME_OVER := preload("res://ui/game_over.tscn")
const ALLOCATION := preload("res://ui/point_allocation_popup.tscn")
const ELITE_REWARD := preload("res://ui/elite_upgrade_popup.tscn")
const NativeUpgrades := preload("res://entities/player/native_player_upgrades.gd")
const VICTORY := preload("res://ui/expedition_victory.tscn")
const MAIN_MENU_PATH := "res://ui/main_menu.tscn"
const NATIVE_RUN_PATH := "res://scenes/native_3d_run.tscn"

var _comms: Node
var encounters: EncounterDirector
var _run_overlay: CanvasLayer
var _allocation_queue: Array[int] = []
var _ended := false
var _elite_pending := false
var _campaign_steps: Array[Dictionary] = []
var _active_campaign_step: Dictionary = {}


func _ready() -> void:
	encounters = EncounterDirector.new()
	encounters.name = "EncounterDirector"
	$GameplayManagers.add_child(encounters)
	encounters.configure(self)
	SignalBus.wave_cleared.connect(_queue_campaign_milestone)
	SignalBus.game_over.connect(_end_run)
	SignalBus.allocation_triggered.connect(_queue_allocation)
	SignalBus.elite_upgrade_triggered.connect(_queue_elite_reward)
	SignalBus.expedition_completed.connect(_show_victory)
	await super._ready()
	if not GameManager.is_game_active:
		return
	$HUD/FlightInstructions.hide()
	projectile_status.hide()
	ExpeditionManager.start_new_expedition()
	_comms = preload("res://systems/campaign_comms.gd").new()
	add_child(_comms)
	_comms.configure(self, hud.get_node("CommsTicker"))
	_comms.route_arrived()
	_queue_arrival_story()
	encounters.start()
	_show_next_reward.call_deferred()
	if GameManager.pending_start_powerup:
		GameManager.pending_start_powerup = false
		SignalBus.power_up_collected.emit(randi_range(0, 4), player.global_position)


func _prepare_run_actors() -> void:
	await encounters.warm_actors()


func _new_overlay() -> CanvasLayer:
	var overlay := CanvasLayer.new()
	overlay.layer = 40
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	get_tree().paused = true
	hud.hide()
	return overlay


func _end_run(score: int) -> void:
	if _ended:
		return
	_ended = true
	encounters.started = false
	get_tree().paused = true
	if GameManager.try_again_stocks > 0:
		_show_try_again.call_deferred(score)
	else:
		_show_game_over.call_deferred(score)


func _show_try_again(score: int) -> void:
	_run_overlay = _new_overlay()
	var popup := TRY_AGAIN.instantiate()
	_run_overlay.add_child(popup)
	popup.try_again_accepted.connect(_revive)
	popup.try_again_declined.connect(_show_game_over.bind(score), CONNECT_DEFERRED)


func _revive() -> void:
	_run_overlay.queue_free()
	_run_overlay = null
	for enemy in get_tree().get_nodes_in_group(&"native_3d_regular_enemies"):
		enemy.queue_free()
	projectile_manager.clear_projectiles()
	hazard_manager.clear_hazards()
	power_up_manager.clear_power_ups()
	player.reset_damage_state()
	player._start_invincibility(3.0)
	_ended = false
	# Preserve any boss and the current wave rather than scheduling it again.
	encounters.started = true
	_show_next_reward.call_deferred()


func _show_game_over(score: int) -> void:
	GameManager.finalize_run()
	ExpeditionManager.abandon_expedition()
	ResourceCache.prime_scene(MAIN_MENU_PATH)
	ResourceCache.prime_scene(NATIVE_RUN_PATH)
	if is_instance_valid(_run_overlay):
		_run_overlay.queue_free()
	_run_overlay = _new_overlay()
	var screen := GAME_OVER.instantiate()
	_run_overlay.add_child(screen)
	screen.show_score(score)


func _queue_allocation(points: int) -> void:
	_allocation_queue.append(points)
	get_tree().paused = true
	_show_next_reward.call_deferred()


func _show_next_reward() -> void:
	if _ended or is_instance_valid(_run_overlay):
		return
	if _elite_pending:
		_elite_pending = false
		var choices := NativeUpgrades.available()
		if choices.is_empty():
			_allocation_queue.push_front(3)
		else:
			_run_overlay = _new_overlay()
			var elite := ELITE_REWARD.instantiate()
			elite.use_custom_upgrade_pool = true
			elite.custom_upgrade_pool = choices
			elite.upgrade_target = player
			elite.show_ship_previews = true
			_run_overlay.add_child(elite)
			elite.upgrade_chosen.connect(_finish_reward)
			return
	if _allocation_queue.is_empty():
		if not _campaign_steps.is_empty():
			_show_campaign_step()
			return
		hud.show()
		get_tree().paused = false
		return
	_run_overlay = _new_overlay()
	var popup := ALLOCATION.instantiate()
	_run_overlay.add_child(popup)
	popup.set_points(_allocation_queue.pop_front())
	popup.allocation_done.connect(_finish_reward)


func _finish_reward() -> void:
	_run_overlay.queue_free()
	_run_overlay = null
	# Keep the tree paused until every milestone reward is resolved. Deferred
	# presentation also lets the closing popup finish its own signal handler.
	_show_next_reward.call_deferred()


func _queue_elite_reward() -> void:
	_elite_pending = true
	get_tree().paused = true
	_show_next_reward.call_deferred()


func _show_victory(wave: int) -> void:
	_campaign_steps.clear()
	encounters.started = false
	projectile_manager.clear_projectiles()
	hazard_manager.clear_hazards()
	ResourceCache.prime_scene(MAIN_MENU_PATH)
	_run_overlay = _new_overlay()
	var screen := VICTORY.instantiate()
	_run_overlay.add_child(screen)
	screen.show_result(wave)
	screen.continue_endless.connect(_continue_endless)
	screen.return_to_menu.connect(_return_to_menu)


func _continue_endless() -> void:
	ExpeditionManager.complete_expedition(ExpeditionManager.FINAL_ENDING_FOLLOW_SIGNAL)
	_run_overlay.queue_free()
	_run_overlay = null
	if GameManager.continue_into_endless():
		encounters.start()
	hud.show()
	get_tree().paused = false


func _return_to_menu() -> void:
	ExpeditionManager.complete_expedition(ExpeditionManager.FINAL_ENDING_RETURN_HOME)
	GameManager.finalize_run()
	get_tree().paused = false
	var menu_scene := ResourceCache.get_scene(MAIN_MENU_PATH)
	if menu_scene != null and get_tree().change_scene_to_packed(menu_scene) == OK:
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


## Debug-build command surface used by the pause-menu panel. Keeping these
## operations on the run controller prevents the UI from reaching into manager
## internals or reviving legacy 2D actors.
func dev_add_orbs(amount: int = 50) -> void:
	if GameManager.is_game_active and amount > 0:
		SignalBus.xp_orb_collected.emit(amount)


func dev_add_lives(amount: int = 5) -> void:
	if amount <= 0:
		return
	GameManager.lives += amount
	SignalBus.lives_changed.emit(GameManager.lives)


func dev_clear_hostiles() -> void:
	for enemy in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		if is_instance_valid(enemy) and enemy.has_method(&"take_damage"):
			enemy.take_damage(999999)
	projectile_manager.clear_enemy_projectiles()
	hazard_manager.clear_hazards()


func dev_force_generation(generation: int) -> void:
	GameManager.dev_enemy_generation_override = clampi(generation, 1, 4)
	encounters.threat.set_generation(GameManager.dev_enemy_generation_override)


func dev_spawn_archetype(kind: StringName) -> Node:
	return encounters.dev_spawn_archetype(kind)


func dev_trigger_enemy_abilities() -> void:
	for enemy in get_tree().get_nodes_in_group(&"native_3d_regular_enemies"):
		if is_instance_valid(enemy) and enemy.has_method(&"dev_trigger_ability"):
			enemy.dev_trigger_ability()


func dev_spawn_boss_variant(variant: StringName) -> bool:
	return encounters.dev_spawn_boss_variant(variant)


func dev_trigger_elite_reward() -> void:
	if not _ended and not is_instance_valid(_run_overlay):
		SignalBus.elite_upgrade_triggered.emit()


func dev_trigger_point_allocation(points: int = 3) -> void:
	if not _ended and not is_instance_valid(_run_overlay) and points > 0:
		SignalBus.allocation_triggered.emit(points)


func get_dev_debug_state() -> String:
	if encounters == null or encounters.threat == null:
		return "Encounter director unavailable"
	return encounters.threat.get_debug_state()


func _unhandled_input(event: InputEvent) -> void:
	if _ended or is_instance_valid(_run_overlay) or _elite_pending or not _allocation_queue.is_empty():
		return
	super._unhandled_input(event)


func _queue_campaign_milestone(wave: int) -> void:
	if wave % 5 != 0 or wave > GameManager.FINAL_EXPEDITION_WAVE:
		return
	var transition := ExpeditionManager.record_milestone(wave)
	if transition.finale:
		return
	for beat_id in transition.story_beat_ids:
		_queue_story(beat_id)
	if not transition.next_reachable_node_ids.is_empty():
		_campaign_steps.append({"kind": "route"})
	get_tree().paused = true
	_show_next_reward.call_deferred()


func _queue_story(beat_id: StringName) -> void:
	if int(SaveManager.get_setting("story_frequency", 0)) == 2:
		return
	if ExpeditionManager.get_snapshot().seen_story_beat_ids.has(beat_id):
		return
	var beat := ExpeditionManager.get_story_beat(beat_id)
	if beat != null:
		_campaign_steps.append({"kind": "story", "beat": beat})


func _queue_arrival_story() -> void:
	var node := ExpeditionManager.get_current_node()
	if node != null:
		_queue_story(node.briefing_beat_id)


func _show_campaign_step() -> void:
	_active_campaign_step = _campaign_steps.pop_front()
	_run_overlay = _new_overlay()
	var panel := preload("res://ui/sector_interlude.gd").new()
	if _active_campaign_step.kind == "route":
		panel.heading = "SELECT THE NEXT SECTOR"
		panel.body = "Choose the threats ahead. Your ship build carries into the next sector. Route choices change enemy composition; salvage and wave length stay unchanged."
		panel.routes = ExpeditionManager.get_route_options()
	else:
		panel.body = preload("res://campaign/story_copy.gd").for_beat(_active_campaign_step.beat)
		if int(SaveManager.get_setting("story_frequency", 0)) == 1:
			panel.body = panel.body.split(". ")[0] + "."
	panel.allow_abandon = true
	panel.abandon_requested.connect(_abandon_from_interlude)
	panel.resolved.connect(_finish_campaign_step)
	_run_overlay.add_child(panel)


func _finish_campaign_step(node_id: StringName) -> void:
	if _active_campaign_step.kind == "route":
		ExpeditionManager.choose_route(node_id)
		_queue_arrival_story()
		_comms.route_arrived()
	else:
		ExpeditionManager.record_story_viewed(_active_campaign_step.beat.id)
	_active_campaign_step = {}
	_finish_reward()


func abandon_run() -> void:
	encounters.objectives.cancel()
	encounters.started = false
	GameManager.is_game_active = false
	GameManager.finalize_run()
	ExpeditionManager.abandon_expedition()


func _abandon_from_interlude() -> void:
	abandon_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
