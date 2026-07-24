extends Node
## Regression coverage for elite-selection and point-allocation completion flow.

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const ELITE_POPUP_SCENE := preload("res://ui/elite_upgrade_popup.tscn")
const ALLOCATION_POPUP_SCENE := preload("res://ui/point_allocation_popup.tscn")

var _failures: Array[String] = []
var _elite_signal_count := 0
var _allocation_signal_count := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_chosen := GameManager.chosen_upgrade_ids.duplicate()
	var original_fire_rate := GameManager.stat_fire_rate_level
	var original_fire_rate_bonus := GameManager.bonus_fire_rate_pct
	var original_lives := GameManager.lives

	var world := Node2D.new()
	add_child(world)
	var player := PLAYER_SCENE.instantiate()
	world.add_child(player)
	await get_tree().process_frame

	var elite_popup := ELITE_POPUP_SCENE.instantiate()
	elite_popup.panel_only = true
	add_child(elite_popup)
	await get_tree().create_timer(0.45, true, false, true).timeout

	var upgrade_id := str(elite_popup.chosen_upgrades[0]["id"])
	_elite_signal_count = 0
	elite_popup.upgrade_chosen.connect(_on_elite_upgrade_chosen)
	var alpha_before_selection: float = elite_popup.modulate.a
	elite_popup._on_upgrade_selected(upgrade_id)

	var selected_card := elite_popup.cards_by_id[upgrade_id] as PanelContainer
	var selected_button := selected_card.get_meta("select_button") as Button
	_expect(
		player.is_elite_upgrade_enabled(upgrade_id),
		"Elite gameplay state must apply immediately when the card is selected"
	)
	_expect(selected_button.text == "SELECTED", "Chosen elite button must show SELECTED")
	_expect(selected_button.disabled, "Chosen elite button must lock immediately")
	_expect(
		is_equal_approx(elite_popup.modulate.a, alpha_before_selection),
		"Elite popup must not fade on selection"
	)
	_expect(_elite_signal_count == 0, "Elite completion signal must retain the 0.15s confirmation")

	await get_tree().create_timer(0.18, true, false, true).timeout
	_expect(_elite_signal_count == 1, "Elite completion signal must emit once after confirmation")
	_expect(is_instance_valid(elite_popup), "Combined elite panel must remain visible after completion")

	var allocation_popup := ALLOCATION_POPUP_SCENE.instantiate()
	allocation_popup.panel_only = true
	add_child(allocation_popup)
	allocation_popup.set_points(1)
	await get_tree().process_frame

	_allocation_signal_count = 0
	allocation_popup.allocation_done.connect(_on_allocation_done)
	allocation_popup._on_plus_pressed("fire_rate")
	allocation_popup._on_confirm()
	var committed_level := GameManager.stat_fire_rate_level
	_expect(allocation_popup.confirm_btn.text == "ALLOCATED", "Point button must show ALLOCATED")
	_expect(allocation_popup.confirm_btn.disabled, "Completed point panel must lock")
	_expect(_allocation_signal_count == 1, "Point completion must emit exactly once")

	allocation_popup._on_confirm()
	_expect(
		GameManager.stat_fire_rate_level == committed_level and _allocation_signal_count == 1,
		"Repeated point confirmation must not apply stats or emit again"
	)
	await _check_solo_elite_close(player)

	await _clear_player_upgrade_state(player)
	world.queue_free()
	elite_popup.queue_free()
	allocation_popup.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	await _check_actual_combined_flow(true)
	await _check_actual_combined_flow(false)

	GameManager.chosen_upgrade_ids = original_chosen
	GameManager.stat_fire_rate_level = original_fire_rate
	GameManager.bonus_fire_rate_pct = original_fire_rate_bonus
	GameManager.lives = original_lives
	await get_tree().process_frame
	await get_tree().process_frame

	if _failures.is_empty():
		print("PASS: upgrade modal flow smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check_solo_elite_close(player: Node) -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var popup := ELITE_POPUP_SCENE.instantiate()
	overlay.add_child(popup)
	await get_tree().create_timer(0.45, true, false, true).timeout

	var upgrade_id := str(popup.chosen_upgrades[0]["id"])
	_elite_signal_count = 0
	popup.upgrade_chosen.connect(_on_elite_upgrade_chosen)
	popup._on_upgrade_selected(upgrade_id)
	_expect(
		player.is_elite_upgrade_enabled(upgrade_id),
		"Solo elite state must also apply immediately"
	)
	await get_tree().create_timer(0.10, true, false, true).timeout
	_expect(is_instance_valid(overlay), "Solo elite popup must retain the 0.15s confirmation")
	await get_tree().create_timer(0.08, true, false, true).timeout
	await get_tree().process_frame
	_expect(_elite_signal_count == 1, "Solo elite completion must emit once")
	_expect(not is_instance_valid(overlay), "Solo elite popup must close immediately after confirmation")


func _check_actual_combined_flow(elite_first: bool) -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn") as PackedScene
	var game: Node = game_scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.elite_upgrade_active = true
	game.allocation_active = true
	get_tree().paused = true
	game._show_combined(1)
	await get_tree().process_frame

	var overlay := game.get_child(game.get_child_count() - 1) as CanvasLayer
	var elite_popup := _find_descendant_with_method(overlay, "_on_upgrade_selected")
	var allocation_popup := _find_descendant_with_method(overlay, "_on_confirm")
	_expect(elite_popup != null, "Combined screen must contain the real elite panel")
	_expect(allocation_popup != null, "Combined screen must contain the real allocation panel")
	if elite_popup == null or allocation_popup == null:
		get_tree().paused = false
		game.queue_free()
		await get_tree().process_frame
		return

	var upgrade_id := str(elite_popup.chosen_upgrades[0]["id"])
	if elite_first:
		elite_popup._on_upgrade_selected(upgrade_id)
		await get_tree().create_timer(0.18, true, false, true).timeout
		_expect(is_instance_valid(overlay), "Combined overlay must wait after elite completion")
		var card := elite_popup.cards_by_id[upgrade_id] as PanelContainer
		var button := card.get_meta("select_button") as Button
		_expect(button.text == "SELECTED" and button.disabled, "Waiting elite panel must stay SELECTED")
		_expect(not game.elite_upgrade_active and game.allocation_active, "Only elite completion flag should clear")
		allocation_popup._on_plus_pressed("fire_rate")
		allocation_popup._on_confirm()
	else:
		allocation_popup._on_plus_pressed("fire_rate")
		allocation_popup._on_confirm()
		await get_tree().process_frame
		_expect(is_instance_valid(overlay), "Combined overlay must wait after allocation completion")
		_expect(
			allocation_popup.confirm_btn.text == "ALLOCATED" and allocation_popup.confirm_btn.disabled,
			"Waiting allocation panel must stay ALLOCATED"
		)
		_expect(game.elite_upgrade_active and not game.allocation_active, "Only allocation completion flag should clear")
		elite_popup._on_upgrade_selected(upgrade_id)
		await get_tree().create_timer(0.10, true, false, true).timeout
		_expect(is_instance_valid(overlay), "Elite-last flow must retain the 0.15s confirmation")
		await get_tree().create_timer(0.08, true, false, true).timeout

	await get_tree().process_frame
	_expect(not is_instance_valid(overlay), "Combined overlay must close after both real panels complete")
	_expect(not game.elite_upgrade_active and not game.allocation_active, "Both completion flags must clear")
	_expect(not get_tree().paused, "Gameplay must resume after both combined decisions")
	await _clear_player_upgrade_state(game.player)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	game = null
	game_scene = null


func _clear_player_upgrade_state(player: Node) -> void:
	player.clear_elite_upgrades()
	player.afterimage_cache.invalidate()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		get_tree().get_nodes_in_group("drone_escort").is_empty(),
		"Elite test teardown must remove externally parented escort drones"
	)


func _find_descendant_with_method(root: Node, method_name: String) -> Node:
	if root.has_method(method_name):
		return root
	for child in root.get_children():
		var found := _find_descendant_with_method(child, method_name)
		if found != null:
			return found
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_elite_upgrade_chosen() -> void:
	_elite_signal_count += 1


func _on_allocation_done() -> void:
	_allocation_signal_count += 1
