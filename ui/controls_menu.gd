extends Control
## Captures gameplay bindings while menu navigation retains its default controls.
signal closed
var _column: VBoxContainer
var _capture: Control
var _message: Label
var _swap: Button
var _cancel: Button
var _action := ""
var _family := ""
var _pending: InputEvent
var _armed_at := 0
var _neutral_axes: Dictionary = {}
var _return_focus: Control
var _rows: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("scalable_ui")
	add_to_group("input_binding_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.07, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 12)
	scroll.add_child(_column)
	label("FLIGHT CONTROLS", _column, 28)
	label("Select a binding, then press a key, mouse button, or controller input. Right stick aims. Escape always cancels menus and pauses flight.", _column)
	for index: int in InputBindings.ACTIONS.size():
		var action: String = InputBindings.ACTIONS[index]
		label(InputBindings.TITLES[index], _column, 20)
		for device_family: String in ["keyboard", "gamepad"]:
			var button := Button.new()
			button.custom_minimum_size.y = 44
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(_begin_capture.bind(action, device_family, button))
			_column.add_child(button)
			_rows[action + ":" + device_family] = button
	var presets := HFlowContainer.new()
	_column.add_child(presets)
	make_button("RESTORE DEFAULTS", presets, func(): InputBindings.restore_defaults(); _refresh())
	make_button("MOUSE FIRE PRESET", presets, func(): InputBindings.restore_defaults(true); _refresh())
	var back := make_button("BACK", _column, _close)
	_refresh()
	back.grab_focus()
	# The first focus change precedes container layout, so follow_focus alone
	# cannot calculate the initial scroll offset yet.
	await get_tree().process_frame
	if is_instance_valid(scroll) and back.has_focus():
		scroll.ensure_control_visible(back)

func label(text: String, parent: Node, font_size: int = 16) -> Label:
	var control := Label.new()
	control.text = text
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_font_size_override("font_size", font_size)
	parent.add_child(control)
	return control

func make_button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _refresh() -> void:
	for key: String in _rows:
		var parts := key.split(":")
		var prefix := "Controller" if parts[1] == "gamepad" else "Keyboard / mouse"
		_rows[key].text = "%s: %s" % [prefix, InputBindings.binding_label(parts[0], parts[1])]

func _begin_capture(action: String, device_family: String, button: Button) -> void:
	_action = action
	_family = device_family
	_pending = null
	_return_focus = button
	_armed_at = Time.get_ticks_msec() + 250
	_neutral_axes.clear()
	for axis: int in range(JOY_AXIS_MAX):
		_neutral_axes[axis] = absf(Input.get_joy_axis(InputBindings.active_gamepad, axis)) < 0.3
	_capture = PanelContainer.new()
	_capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_capture)
	var center := CenterContainer.new()
	_capture.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = minf(520, get_viewport_rect().size.x - 48)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_message = label("Press a %s input for %s.\nRelease sticks first. Escape cancels." % [device_family, InputBindings.TITLES[InputBindings.ACTIONS.find(action)]], box, 22)
	_swap = make_button("SWAP BINDINGS", box, _confirm_swap)
	_swap.hide()
	_cancel = make_button("CANCEL", box, _end_capture)
	for dialog_button: Button in [_swap, _cancel]:
		var other: Button = _cancel if dialog_button == _swap else _swap
		dialog_button.focus_neighbor_top = dialog_button.get_path_to(other)
		dialog_button.focus_neighbor_bottom = dialog_button.get_path_to(other)
		dialog_button.focus_neighbor_left = dialog_button.get_path_to(other)
		dialog_button.focus_neighbor_right = dialog_button.get_path_to(other)
		dialog_button.focus_next = dialog_button.get_path_to(other)
		dialog_button.focus_previous = dialog_button.get_path_to(other)
	_cancel.grab_focus()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_capture):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_end_capture()
		return
	# Buttons in the capture dialog remain operable while all gameplay input is consumed.
	if event is InputEventMouseButton and (_cancel.get_global_rect().has_point(event.position) or (_swap.visible and _swap.get_global_rect().has_point(event.position))):
		return
	if _pending != null:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_end_capture()
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() < _armed_at or event.is_echo():
		return
	if InputBindings.event_family(event) != _family:
		return
	if event is InputEventKey:
		if not event.pressed:
			return
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
	elif event is InputEventJoypadButton:
		if not event.pressed:
			return
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.3:
			_neutral_axes[event.axis] = true
		if absf(event.axis_value) < 0.75 or not bool(_neutral_axes.get(event.axis, false)):
			return
		if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			_message.text = "The right stick is reserved for aiming. Choose another input."
			return
	else:
		return
	var collisions: Array[String] = InputBindings.conflicts(_action, event)
	if collisions.is_empty():
		InputBindings.assign(_action, event)
		_end_capture()
	elif collisions.size() == 1:
		_pending = event.duplicate()
		_message.text = "%s is already assigned to %s. Exchange these two actions' %s bindings?" % [event.as_text(), InputBindings.TITLES[InputBindings.ACTIONS.find(collisions[0])], _family]
		_swap.show()
		_cancel.grab_focus()
	else:
		_message.text = "That input is used by multiple actions. Choose another input or restore a preset."

func _confirm_swap() -> void:
	if _pending != null and InputBindings.assign(_action, _pending, true):
		_end_capture()

func _end_capture() -> void:
	if is_instance_valid(_capture):
		_capture.queue_free()
	_capture = null
	_pending = null
	_refresh()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if is_instance_valid(_capture):
			_end_capture()
		else:
			_close()

func _close() -> void:
	closed.emit()
	queue_free()
