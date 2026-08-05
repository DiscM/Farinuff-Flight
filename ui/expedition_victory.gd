extends Control
## Finite-campaign victory screen. The run stays resumable until the player
## chooses Endless or returns to the menu.

signal continue_endless
signal return_to_menu

const CYAN := Color(0.14, 0.93, 1.0)
const GREEN := Color(0.32, 1.0, 0.55)
const YELLOW := Color(1.0, 0.84, 0.12)
const MAGENTA := Color(1.0, 0.16, 0.55)
const INK := Color(0.005, 0.012, 0.04, 0.98)

var _wave_label: Label
var _body_label: Label
var _salvage_label: Label
var _continue_button: Button
var _menu_button: Button
var _resolved := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_continue_button.grab_focus()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.002, 0.004, 0.018, 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(318.0, 390.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "EXPEDITION // COMPLETE"
	eyebrow.add_theme_color_override("font_color", GREEN)
	eyebrow.add_theme_font_size_override("font_size", 12)
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "TEMPEST CORE BROKEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", CYAN)
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)

	_wave_label = Label.new()
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_color_override("font_color", YELLOW)
	_wave_label.add_theme_font_size_override("font_size", 20)
	content.add_child(_wave_label)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(MAGENTA, 0.78)
	content.add_child(rule)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	_body_label.add_theme_font_size_override("font_size", 15)
	content.add_child(_body_label)

	_salvage_label = Label.new()
	_salvage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_salvage_label.add_theme_color_override("font_color", GREEN)
	_salvage_label.add_theme_font_size_override("font_size", 13)
	content.add_child(_salvage_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	_continue_button = _make_button("CONTINUE TO ENDLESS", YELLOW)
	_continue_button.custom_minimum_size = Vector2(0.0, 52.0)
	_continue_button.pressed.connect(_on_continue_pressed)
	content.add_child(_continue_button)

	_menu_button = _make_button("END RUN / MAIN MENU", MAGENTA)
	_menu_button.custom_minimum_size = Vector2(0.0, 44.0)
	_menu_button.pressed.connect(_on_menu_pressed)
	content.add_child(_menu_button)


func _make_button(label: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(INK, color, 2, 1))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.04, 0.07, 0.12, 1.0), color, 2, 2))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.04, 0.07, 0.12, 1.0), color, 2, 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.10, 0.16, 1.0), color, 2, 2))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.07, 0.98)
	style.border_color = Color(YELLOW, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _button_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style


## Public setup seam so the game scene can provide the exact cleared wave.
func show_result(final_wave: int) -> void:
	_wave_label.text = "WAVE %02d  //  EXPEDITION CLEAR" % final_wave
	var ship_profile := MetaProgression.get_selected_ship_profile()
	var ship_name := str(ship_profile.get("name", "YOUR SHIP")).to_upper()
	_body_label.text = "%s BREAKS THE FORMATION.\nTHE EXPEDITION IS YOURS." % ship_name
	_salvage_label.text = "BOSS SALVAGE BANKED: %s" % _format_salvage(GameManager.run_salvage_boss)


func _format_salvage(value: int) -> String:
	return "SALVAGE %d" % value


func _on_continue_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	continue_endless.emit()


func _on_menu_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	return_to_menu.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _resolved:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_menu_pressed()
		get_viewport().set_input_as_handled()
