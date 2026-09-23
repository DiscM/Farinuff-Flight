extends Node
## Recovery decisions and nested settings keep input on the visible modal.

const Recovery := preload("res://ui/try_again_popup.gd")
const Confirmation := preload("res://ui/shared/run_confirmation.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var disk := preload("res://tests/save_file_snapshot.gd").new()
	var old_settings := SaveManager.settings.duplicate(true)
	var old_run := [GameManager.try_again_stocks, GameManager.lives, GameManager.starting_lives, GameManager.is_game_active]
	SaveManager.update_setting("reduced_motion", true)
	SaveManager.update_setting("hold_to_confirm", false)
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	await _check_cancel_and_continue()
	await _check_confirm_once()
	await _check_hold_and_quit_interruption()
	await _check_no_continues()
	await _check_nested_settings_focus()
	GameManager.try_again_stocks = old_run[0]
	GameManager.lives = old_run[1]
	GameManager.starting_lives = old_run[2]
	GameManager.is_game_active = old_run[3]
	SaveManager.settings = old_settings
	SaveManager.settings_changed.emit()
	disk.restore()
	for failure in _failures:
		push_error(failure)
	print("RECOVERY_DECISION_SMOKE_PASS" if _failures.is_empty() else "RECOVERY_DECISION_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _make_popup(stocks: int) -> Control:
	var layer := CanvasLayer.new()
	add_child(layer)
	GameManager.try_again_stocks = stocks
	GameManager.lives = 0
	GameManager.starting_lives = 5
	GameManager.is_game_active = false
	var popup := Recovery.new()
	layer.add_child(popup)
	await _frames(2)
	return popup


func _check_cancel_and_continue() -> void:
	var popup = await _make_popup(2)
	var resolved := [0, 0]
	popup.try_again_accepted.connect(func(): resolved[0] += 1)
	popup.try_again_declined.connect(func(): resolved[1] += 1)
	var end_button := _button(popup, "END RUN")
	end_button.grab_focus()
	end_button.pressed.emit()
	var dialog: Control = popup._end_confirmation
	popup._on_give_up()
	_expect(is_instance_valid(dialog) and dialog == popup._end_confirmation, "Repeated End Run opens one confirmation")
	_expect(get_viewport().gui_get_focus_owner() == _button(dialog, "KEEP PLAYING"), "Recovery confirmation defaults to keeping the run")
	popup._on_try_again()
	_expect(resolved == [0, 0] and GameManager.try_again_stocks == 2, "Confirmation leaves the run and continues untouched")
	_press_action(&"ui_cancel")
	await _frames(2)
	_expect(is_instance_valid(popup) and not is_instance_valid(popup._end_confirmation), "Cancel closes only the recovery confirmation")
	_expect(end_button.has_focus(), "Cancel restores the exact recovery action that opened the dialog")
	popup._on_try_again()
	popup._on_try_again()
	_expect(resolved == [1, 0] and GameManager.try_again_stocks == 1, "Continue remains available after cancel and spends once")
	_expect(GameManager.lives == 5, "Continue restores this loadout's starting lives")
	await _frames(2)


func _check_confirm_once() -> void:
	var popup = await _make_popup(2)
	var declined := [0]
	popup.try_again_declined.connect(func(): declined[0] += 1)
	popup._on_give_up()
	var confirm := _button(popup._end_confirmation, "END RUN")
	confirm.pressed.emit()
	confirm.pressed.emit()
	_expect(declined[0] == 1, "Confirmed End Run resolves once despite duplicate activation")
	_expect(GameManager.try_again_stocks == 2 and not GameManager.is_game_active, "Ending a run does not spend a continue or revive the ship")
	await _frames(2)


func _check_hold_and_quit_interruption() -> void:
	SaveManager.update_setting("hold_to_confirm", true)
	var popup = await _make_popup(1)
	var declined := [0]
	popup.try_again_declined.connect(func(): declined[0] += 1)
	popup._on_give_up()
	var dialog: Control = popup._end_confirmation
	var confirm: Button = dialog.get("_confirm")
	confirm.pressed.emit()
	_expect(declined[0] == 0 and confirm.text.contains("HOLD TO"), "Recovery honors hold-to-confirm instead of accepting a click")
	confirm.grab_focus()
	Input.action_press(&"ui_accept")
	confirm.button_down.emit()
	dialog._process(0.5)
	_expect(declined[0] == 0, "A short confirmation hold preserves the recovery decision")
	# Window-close confirmation uses another, higher CanvasLayer in production.
	# Its safe focus must interrupt an in-progress End Run hold.
	var quit_layer := CanvasLayer.new()
	quit_layer.layer = 100
	add_child(quit_layer)
	var quit_dialog := Confirmation.new()
	quit_dialog.title = "Quit the game?"
	quit_layer.add_child(quit_dialog)
	dialog._process(1.1)
	_expect(declined[0] == 0, "A quit modal cannot complete a covered recovery hold")
	Input.action_release(&"ui_accept")
	quit_dialog._finish(false)
	quit_layer.queue_free()
	await _frames(2)
	_expect(confirm.has_focus() and is_instance_valid(popup), "Canceling quit restores the pending recovery choice")
	confirm.grab_focus()
	Input.action_press(&"ui_accept")
	confirm.button_down.emit()
	dialog._process(1.01)
	Input.action_release(&"ui_accept")
	_expect(declined[0] == 1 and GameManager.try_again_stocks == 1, "A complete hold ends the run without spending its remaining continue")
	await _frames(2)
	SaveManager.update_setting("hold_to_confirm", false)


func _check_no_continues() -> void:
	var popup = await _make_popup(0)
	var declined := [0]
	popup.try_again_declined.connect(func(): declined[0] += 1)
	_expect(_button(popup, "END RUN").has_focus(), "An exhausted recovery screen focuses its available action")
	popup._on_give_up()
	_expect(declined[0] == 1 and not is_instance_valid(popup._end_confirmation), "No-continue results need no extra recovery confirmation")
	await _frames(2)


func _check_nested_settings_focus() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var pause := preload("res://ui/pause_menu.tscn").instantiate()
	layer.add_child(pause)
	await _frames(2)
	var settings_invoker: Button = pause.get_node("LeftDock/MenuButtons/SettingsWrap/Button")
	settings_invoker.grab_focus()
	settings_invoker.pressed.emit()
	var settings: Control = pause._settings_menu
	await _frames(2)
	_expect(settings_invoker.focus_mode == Control.FOCUS_NONE, "Settings suspends the covered pause actions")
	_check_focus_cycle(settings, settings.find_child("CloseButton", true, false), "Pause settings")
	var tabs: TabContainer = settings.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 3
	await _frames(2)
	var controls_invoker: Button = settings.get("_controls_button")
	controls_invoker.grab_focus()
	controls_invoker.pressed.emit()
	await _frames(2)
	var controls_layer: CanvasLayer = settings.get("_controls_layer")
	var controls: Control = controls_layer.get_child(0)
	_expect(controls_invoker.focus_mode == Control.FOCUS_NONE, "Change Controls suspends the covered settings actions")
	_check_focus_cycle(controls, _button(controls, "BACK"), "Change Controls")
	_press_action(&"ui_cancel")
	await _frames(2)
	_expect(not is_instance_valid(settings.get("_controls_layer")) and controls_invoker.has_focus(), "Back from controls restores its settings action")
	_expect(settings_invoker.focus_mode == Control.FOCUS_NONE, "Closing the inner modal keeps the pause menu suspended")
	_press_action(&"ui_cancel")
	await _frames(2)
	_expect(not is_instance_valid(pause._settings_menu) and settings_invoker.has_focus(), "Back from settings restores its pause action")
	_expect(settings_invoker.focus_mode == Control.FOCUS_ALL, "Closing settings restores original pause focus modes")
	settings_invoker.pressed.emit()
	await _frames(2)
	pause._settings_menu.queue_free()
	await _frames(2)
	_expect(settings_invoker.focus_mode == Control.FOCUS_ALL, "Removing a modal without its close signal still restores underlying focus")
	layer.queue_free()
	await _frames(2)


func _check_focus_cycle(modal: Control, start: Control, label: String) -> void:
	var cursor := start
	for index in 40:
		var next := cursor.find_next_valid_focus()
		_expect(next != null and (next == modal or modal.is_ancestor_of(next)), label + " keeps forward focus inside the visible modal")
		if next == null:
			break
		cursor = next
	cursor = start
	for index in 40:
		var previous := cursor.find_prev_valid_focus()
		_expect(previous != null and (previous == modal or modal.is_ancestor_of(previous)), label + " keeps reverse focus inside the visible modal")
		if previous == null:
			break
		cursor = previous


func _button(root: Node, label: String) -> Button:
	for candidate: Button in root.find_children("*", "Button", true, false):
		if candidate.text == label:
			return candidate
	return null


func _press_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
