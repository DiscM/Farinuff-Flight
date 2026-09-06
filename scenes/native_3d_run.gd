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

var encounters: EncounterDirector
var _run_overlay: CanvasLayer
var _allocation_queue: Array[int] = []
var _ended := false
var _elite_pending := false


func _ready() -> void:
	encounters = EncounterDirector.new()
	encounters.name = "EncounterDirector"
	$GameplayManagers.add_child(encounters)
	encounters.configure(self)
	SignalBus.game_over.connect(_end_run)
	SignalBus.allocation_triggered.connect(_queue_allocation)
	SignalBus.elite_upgrade_triggered.connect(_queue_elite_reward)
	SignalBus.expedition_completed.connect(_show_victory)
	await super._ready()
	if not GameManager.is_game_active:
		return
	$HUD/FlightInstructions.hide()
	projectile_status.hide()
	encounters.start()
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
	hud.show()
	get_tree().paused = false


func _show_game_over(score: int) -> void:
	GameManager.finalize_run()
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
	_run_overlay.queue_free()
	_run_overlay = null
	if GameManager.continue_into_endless():
		encounters.start()
	hud.show()
	get_tree().paused = false


func _return_to_menu() -> void:
	GameManager.finalize_run()
	get_tree().paused = false
	var menu_scene := ResourceCache.get_scene(MAIN_MENU_PATH)
	if menu_scene != null and get_tree().change_scene_to_packed(menu_scene) == OK:
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _ended or is_instance_valid(_run_overlay) or _elite_pending or not _allocation_queue.is_empty():
		return
	super._unhandled_input(event)
