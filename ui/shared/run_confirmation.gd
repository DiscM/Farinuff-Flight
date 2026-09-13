extends Control
## Shared destructive-action dialog; never owns the run's pause state.
signal confirmed
signal canceled
var title := "End Expedition?"
var dialog_text := "This run cannot be resumed."
var _confirm: Button
var _progress: ProgressBar
var _holding := false
var _elapsed := 0.0
var _resolved := false
var _return_focus: Control
var _requires_hold := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("scalable_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	_return_focus = get_viewport().gui_get_focus_owner()
	_requires_hold = bool(SaveManager.get_setting("hold_to_confirm", false))
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.012, 0.035, 0.98)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(500.0, get_viewport_rect().size.x - 40.0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	var description := Label.new()
	description.text = dialog_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	_confirm = Button.new()
	_confirm.text = "HOLD TO CONFIRM · 1 SECOND" if _requires_hold else "CONFIRM"
	_confirm.custom_minimum_size.y = 48
	_confirm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.button_down.connect(func(): _holding = true; _elapsed = 0.0)
	_confirm.button_up.connect(_reset_hold)
	_confirm.focus_exited.connect(_reset_hold)
	_confirm.mouse_exited.connect(_reset_hold)
	_confirm.pressed.connect(func():
		if not _requires_hold:
			_finish(true)
	)
	column.add_child(_confirm)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 8
	_progress.visible = _requires_hold
	column.add_child(_progress)
	var cancel := Button.new()
	cancel.text = "CANCEL / KEEP RUN"
	cancel.custom_minimum_size.y = 48
	cancel.pressed.connect(func(): _finish(false))
	column.add_child(cancel)
	# Keep keyboard/controller navigation inside the modal. The underlying
	# pause menu stays in the tree and must not receive focus behind the shade.
	for button: Button in [_confirm, cancel]:
		var other: Button = cancel if button == _confirm else _confirm
		button.focus_neighbor_top = button.get_path_to(other)
		button.focus_neighbor_bottom = button.get_path_to(other)
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
	cancel.grab_focus()

func _process(delta: float) -> void:
	if _resolved or not _requires_hold or not _holding:
		return
	if not _confirm.has_focus() or not (Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_reset_hold()
		return
	_elapsed += delta
	_progress.value = _elapsed
	if _elapsed >= 1.0:
		_finish(true)

func _reset_hold() -> void:
	_holding = false
	_elapsed = 0.0
	if is_instance_valid(_progress):
		_progress.value = 0.0

func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_finish(false)

func _finish(accept: bool) -> void:
	if _resolved:
		return
	_resolved = true
	MenuAudio.play(&"UI.NAV.CONFIRM" if accept else &"UI.NAV.CANCEL")
	if not accept and is_instance_valid(_return_focus):
		_return_focus.grab_focus()
	if accept:
		confirmed.emit()
	else:
		canceled.emit()
	queue_free()
