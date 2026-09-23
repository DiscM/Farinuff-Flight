extends Control
## Flight is the front door. This HUD guides pilots to station destinations;
## only the nearby destination exposes its service interaction.

signal menu_requested
signal resume_requested
signal quit_requested
signal interact_requested
signal section_selected(section_id: StringName)

const MUTED := Color(0.62, 0.74, 0.81)
const PORT_CYAN := Color(0.38, 0.89, 0.92)
const PORT_GREEN := Color(0.53, 0.86, 0.65)
const PANEL_INK := Color(0.015, 0.032, 0.052, 0.88)

var _section: Dictionary = {}
var _service_available := false
var _menu_open := false
var _boost_ready := true
var _boost_fraction := 1.0
var _navigation_text := "Fly to a station marker. Interact to enter."
var _menu_button: Button
var _resume_button: Button
var _quit_button: Button
var _interact_button: Button
var _context_panel: PanelContainer
var _directory_panel: PanelContainer
var _directory_list: VBoxContainer
var _section_buttons: Dictionary = {}
var _pause_layer: Control
var _navigation_label: Label
var _movement_label: Label
var _boost_label: Label
var _zoom_label: Label
var _telemetry_label: Label
var _section_label: Label
var _section_description: Label
var _range_label: Label


func _ready() -> void:
	name = "HomeBaseHUD"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("scalable_ui")
	_build_header()
	_build_directory()
	_build_instruments()
	_build_pause_panel()
	InputBindings.bindings_changed.connect(_refresh_controls)
	InputBindings.device_changed.connect(_refresh_controls)
	_refresh_controls()
	set_active_section({}, 0.0, false)
	set_flight_status(0.0, 0.0)
	set_menu_open(false)


func set_active_section(section: Dictionary, distance: float, in_range: bool) -> void:
	var previous_accent: Color = _section.get("color", PORT_CYAN)
	_section = section.duplicate()
	_service_available = in_range and not section.is_empty()
	if not is_instance_valid(_context_panel):
		return
	if not _service_available and _interact_button.has_focus():
		get_viewport().gui_release_focus()
	_context_panel.visible = not section.is_empty() and not _menu_open
	_section_label.text = str(section.get("title", "")).to_upper()
	_section_description.text = str(section.get("description", ""))
	var accent: Color = section.get("color", PORT_CYAN)
	_section_label.add_theme_color_override("font_color", accent)
	if previous_accent != accent:
		_context_panel.add_theme_stylebox_override("panel", _panel_style(accent))
	_range_label.text = "●  SERVICES IN RANGE" if _service_available else "APPROACH  /  %d m" % ceili(maxf(distance, 0.0))
	_range_label.add_theme_color_override("font_color", PORT_GREEN if _service_available else MUTED)
	_refresh_interact()


## Directory clicks place a waypoint; access still requires flying to the marker.
func set_sections_status(entries: Array) -> void:
	if not is_instance_valid(_directory_list):
		return
	var retained: Array[StringName] = []
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var id := StringName(entry.get("id", ""))
		if id == &"":
			continue
		retained.append(id)
		var button: Button = _section_buttons.get(id)
		if not is_instance_valid(button):
			button = _button("Destination_" + str(id), "", PORT_CYAN)
			button.add_theme_font_size_override("font_size", 12)
			button.custom_minimum_size.y = 40
			button.pressed.connect(func():
				section_selected.emit(id)
				get_viewport().gui_release_focus()
			)
			_directory_list.add_child(button)
			_section_buttons[id] = button
		var selected := bool(entry.get("selected", false))
		button.text = "%s %02d  %s" % ["›" if selected else " ", index + 1, str(entry.get("title", id)).to_upper()]
		button.tooltip_text = "Set waypoint: %s" % str(entry.get("title", id))
		if entry.has("distance"):
			button.tooltip_text += " · %d m" % ceili(maxf(float(entry.distance), 0.0))
		button.accessibility_name = "Set waypoint to " + str(entry.get("title", id))
		button.accessibility_description = "Fly to this section and interact to use its services."
		button.set_meta("section_color", entry.get("color", PORT_CYAN))
		button.set_meta("waypoint_selected", selected)
		button.disabled = _menu_open
		button.focus_mode = Control.FOCUS_NONE if _menu_open else Control.FOCUS_ALL
	for id: StringName in _section_buttons.keys():
		if id not in retained:
			var obsolete: Button = _section_buttons[id]
			_directory_list.remove_child(obsolete)
			obsolete.queue_free()
			_section_buttons.erase(id)
	_directory_panel.visible = not _menu_open and not _section_buttons.is_empty()
	_refresh_directory_highlight()


func set_flight_status(speed: float, distance: float) -> void:
	if is_instance_valid(_telemetry_label):
		_telemetry_label.text = "SPEED %02d m/s   /   RANGE %03d m" % [roundi(maxf(speed, 0.0)), roundi(maxf(distance, 0.0))]


func set_boost_state(available: bool, fraction: float) -> void:
	_boost_ready = available
	_boost_fraction = clampf(fraction, 0.0, 1.0)
	_refresh_boost()


func set_navigation_hint(text: String) -> void:
	_navigation_text = text
	if is_instance_valid(_navigation_label):
		_navigation_label.text = text


func get_service_hint() -> String:
	var event := get_service_event()
	return "%s to interact" % _event_hint(event) if event != null else "Click Interact"


## Reserve every live flight binding, including the user's remapped controls.
func get_service_event(device_family: String = "") -> InputEvent:
	var family := InputBindings.family if device_family.is_empty() else device_family
	var candidates: Array[InputEvent] = []
	if family == "gamepad":
		for code: int in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			var event := InputEventJoypadButton.new()
			event.button_index = code as JoyButton
			candidates.append(event)
	else:
		for code: int in [KEY_E, KEY_F, KEY_TAB, KEY_ENTER, KEY_V, KEY_C, KEY_H, KEY_J]:
			candidates.append(_key_event(code))
	for event: InputEvent in candidates:
		if not is_flight_binding(event):
			return event
	return null


func is_flight_binding(event: InputEvent) -> bool:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "boost", "pause"]:
		if InputMap.event_is_action(event, action, true):
			return true
	return false


func set_menu_open(open: bool) -> void:
	if not is_instance_valid(_pause_layer):
		return
	_menu_open = open
	_pause_layer.visible = open
	_context_panel.visible = not _section.is_empty() and not open
	_directory_panel.visible = not _section_buttons.is_empty() and not open
	_menu_button.disabled = open
	_menu_button.focus_mode = Control.FOCUS_NONE if open else Control.FOCUS_ALL
	_interact_button.focus_mode = Control.FOCUS_NONE if open or not _service_available else Control.FOCUS_ALL
	for button: Button in _section_buttons.values():
		button.disabled = open
		button.focus_mode = Control.FOCUS_NONE if open else Control.FOCUS_ALL
	if open:
		_resume_button.grab_focus()
	else:
		get_viewport().gui_release_focus()


func focus_primary() -> void:
	if _menu_open:
		_resume_button.grab_focus()
	elif _service_available:
		_interact_button.grab_focus()
	else:
		_menu_button.grab_focus()


func _build_header() -> void:
	var margin := _screen_margin(false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override("separation", 3)
	row.add_child(title)
	title.add_child(_label("FARINUFF FLIGHT", 28, NeonUI.WHITE))
	title.add_child(_label("WAYFARER / CRESCENT HARBOR   /   ●  SAFE PORT", 12, PORT_GREEN))
	_menu_button = _button("PauseButton", "PAUSE", PORT_CYAN)
	_menu_button.custom_minimum_size.x = 150
	_menu_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_menu_button.accessibility_name = "Pause homeport flight"
	_menu_button.tooltip_text = "Pause your flight or quit the game."
	_menu_button.pressed.connect(func(): menu_requested.emit())
	row.add_child(_menu_button)


func _build_directory() -> void:
	_directory_panel = PanelContainer.new()
	_directory_panel.name = "StationDirectory"
	_directory_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_directory_panel.offset_left = -274
	_directory_panel.offset_right = -28
	_directory_panel.offset_top = 104
	_directory_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_directory_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel_style(PORT_CYAN)
	style.bg_color = Color(0.012, 0.028, 0.048, 0.60)
	style.border_color = Color(PORT_CYAN, 0.30)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_directory_panel.add_theme_stylebox_override("panel", style)
	add_child(_directory_panel)
	_directory_list = VBoxContainer.new()
	_directory_list.add_theme_constant_override("separation", 3)
	_directory_panel.add_child(_directory_list)
	_directory_list.add_child(_label("DESTINATIONS / SET WAYPOINT", 10, MUTED))


func _build_instruments() -> void:
	var margin := _screen_margin(true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	var flight := VBoxContainer.new()
	flight.custom_minimum_size.x = 280
	flight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flight.size_flags_vertical = Control.SIZE_SHRINK_END
	flight.add_theme_constant_override("separation", 5)
	row.add_child(flight)
	_navigation_label = _label(_navigation_text, 15, PORT_CYAN)
	flight.add_child(_navigation_label)
	_telemetry_label = _label("", 11, MUTED)
	flight.add_child(_telemetry_label)
	_movement_label = _label("", 12, NeonUI.WHITE)
	flight.add_child(_movement_label)
	_boost_label = _label("", 12, NeonUI.WHITE)
	flight.add_child(_boost_label)
	_zoom_label = _label("", 11, MUTED)
	flight.add_child(_zoom_label)
	_context_panel = PanelContainer.new()
	_context_panel.name = "NearbyDestination"
	_context_panel.custom_minimum_size.x = 344
	_context_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_context_panel.add_theme_stylebox_override("panel", _panel_style(PORT_CYAN))
	row.add_child(_context_panel)
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	_context_panel.add_child(section)
	_range_label = _label("", 10, PORT_GREEN)
	section.add_child(_range_label)
	_section_label = _label("", 22, PORT_CYAN)
	section.add_child(_section_label)
	_section_description = _label("", 12, MUTED)
	section.add_child(_section_description)
	_interact_button = _button("InteractButton", "INTERACT", NeonUI.YELLOW)
	_interact_button.accessibility_name = "Interact with nearby station section"
	_interact_button.pressed.connect(func():
		if _service_available and not _menu_open:
			interact_requested.emit()
	)
	section.add_child(_interact_button)
	resized.connect(func():
		_context_panel.custom_minimum_size.x = minf(344.0, maxf(280.0, size.x * 0.35))
	)


func _build_pause_panel() -> void:
	_pause_layer = Control.new()
	_pause_layer.name = "PauseMenu"
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.004, 0.008, 0.016, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 410
	panel.add_theme_stylebox_override("panel", _panel_style(PORT_CYAN))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_label("CRESCENT HARBOR / FLIGHT PAUSED", 12, PORT_CYAN))
	column.add_child(_label("A moment in orbit.", 26, NeonUI.WHITE))
	_resume_button = _button("ResumeButton", "RESUME FLIGHT", NeonUI.YELLOW)
	_resume_button.pressed.connect(func(): resume_requested.emit())
	column.add_child(_resume_button)
	_quit_button = _button("QuitButton", "QUIT GAME", PORT_CYAN)
	_quit_button.pressed.connect(func(): quit_requested.emit())
	column.add_child(_quit_button)
	_resume_button.focus_neighbor_top = _quit_button.get_path()
	_resume_button.focus_neighbor_bottom = _quit_button.get_path()
	_quit_button.focus_neighbor_top = _resume_button.get_path()
	_quit_button.focus_neighbor_bottom = _resume_button.get_path()


func _refresh_controls() -> void:
	if not is_instance_valid(_movement_label):
		return
	var movement := PackedStringArray()
	for action: String in ["move_up", "move_left", "move_down", "move_right"]:
		movement.append(_hint(action))
	_movement_label.text = "MOVE  %s" % " / ".join(movement)
	_menu_button.text = "PAUSE  /  %s" % _hint("pause")
	_refresh_zoom_hint()
	_refresh_boost()
	_refresh_interact()


func _refresh_interact() -> void:
	if not is_instance_valid(_interact_button):
		return
	_interact_button.disabled = not _service_available
	_interact_button.focus_mode = Control.FOCUS_ALL if _service_available and not _menu_open else Control.FOCUS_NONE
	var event := get_service_event()
	_interact_button.text = "INTERACT  /  %s" % _event_hint(event) if event != null else "INTERACT"
	if not _service_available:
		_interact_button.text = "FLY CLOSER TO INTERACT"


func _refresh_directory_highlight() -> void:
	for id: StringName in _section_buttons:
		var button: Button = _section_buttons[id]
		var accent: Color = button.get_meta("section_color", PORT_CYAN)
		var current := bool(button.get_meta("waypoint_selected", false))
		if button.has_meta("highlight_current") and button.get_meta("highlight_current") == current and button.get_meta("highlight_color", PORT_CYAN) == accent:
			continue
		button.set_meta("highlight_current", current)
		button.set_meta("highlight_color", accent)
		var fill := Color(0.035, 0.105, 0.14, 0.90) if current else Color(0.005, 0.013, 0.025, 0.20)
		button.add_theme_stylebox_override("normal", NeonUI.button_style(accent if current else Color(accent, 0.22), fill))
		button.add_theme_color_override("font_color", accent if current else MUTED)


func _refresh_zoom_hint() -> void:
	if InputBindings.family == "gamepad":
		var outward := InputEventJoypadButton.new()
		outward.button_index = JOY_BUTTON_LEFT_SHOULDER
		var inward := InputEventJoypadButton.new()
		inward.button_index = JOY_BUTTON_RIGHT_SHOULDER
		var can_out := not is_flight_binding(outward)
		var can_in := not is_flight_binding(inward)
		_zoom_label.visible = can_out or can_in
		_zoom_label.text = "ZOOM  LB / RB" if can_out and can_in else ("ZOOM OUT  LB" if can_out else "ZOOM IN  RB")
	else:
		_zoom_label.visible = true
		var can_out := not is_flight_binding(_key_event(KEY_MINUS))
		var can_in := not is_flight_binding(_key_event(KEY_EQUAL))
		_zoom_label.text = "ZOOM  Wheel"
		if can_out and can_in:
			_zoom_label.text += " / − +"
		elif can_out:
			_zoom_label.text += " / − out"
		elif can_in:
			_zoom_label.text += " / + in"


func _refresh_boost() -> void:
	if not is_instance_valid(_boost_label):
		return
	var state := "READY" if _boost_ready else "RECHARGING %d%%" % roundi(_boost_fraction * 100.0)
	_boost_label.text = "BOOST  %s  ·  %s" % [_hint("boost"), state]
	_boost_label.add_theme_color_override("font_color", NeonUI.WHITE if _boost_ready else MUTED)


func _hint(action: String) -> String:
	return _compact_hint(InputBindings.binding_hint(action))


func _event_hint(event: InputEvent) -> String:
	return _compact_hint(InputBindings.event_label(event))


func _compact_hint(text: String) -> String:
	return text.replace("South (A / Cross)", "A / Cross").replace("East (B / Circle)", "B / Circle").replace("West (X / Square)", "X / Square").replace("North (Y / Triangle)", "Y / Triangle").replace("Start / Options", "Start").replace("Left stick ", "L-stick ").replace("Left trigger", "LT").replace("Right trigger", "RT").replace("Left bumper", "LB").replace("Right bumper", "RB")


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	return event


func _screen_margin(bottom: bool) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset((Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE) as Control.LayoutPreset)
	margin.grow_vertical = (Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END) as Control.GrowDirection
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	return margin


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := NeonUI.make_label(text, font_size, color, HORIZONTAL_ALIGNMENT_LEFT)
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color(0.003, 0.008, 0.02, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _button(node_name: String, text: String, color: Color) -> Button:
	var button := NeonUI.make_button(node_name, text, color, Vector2(0, 44))
	button.add_theme_font_size_override("font_size", 15)
	button.focus_entered.connect(func(): MenuAudio.play(&"UI.NAV.MOVE"))
	return button


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := NeonUI.plaque(accent.darkened(0.38), PANEL_INK, 2, 1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
