extends Control
## Read-only ship reference with scrollable content and a fixed return action.
signal closed
const Build := preload("res://systems/build_reference.gd")
var _closed := false
var scroll: ScrollContainer
var close_button: Button

func _ready() -> void:
	name = "BuildReference"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("scalable_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	_label(layout, "YOUR SHIP / INSTALLED SYSTEMS", 26, NeonUI.CYAN)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().accessibility_name = "Scroll installed systems"
	layout.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	var owned := GameManager.get_owned_elite_ids()
	_label(column, Build.systems_text(), 16, NeonUI.WHITE)
	var connections := Build.connections(owned)
	if not connections.is_empty():
		_label(column, "ACTIVE CONNECTIONS", 16, NeonUI.YELLOW)
		for connection in connections:
			_label(column, "• " + connection, 16, NeonUI.WHITE)
	column.add_child(HSeparator.new())
	var modules := Build.modules(owned)
	if modules.is_empty():
		var empty_copy := "No modules installed. Practice grants no run progression." if GameManager.practice_mode else "No modules installed. Defeat the Wave 5 boss to choose your first module."
		_label(column, empty_copy, 18, NeonUI.WHITE)
	for module: Dictionary in modules:
		_label(column, "%s · %s" % [module.name, module.get("role", "Utility")], 18, module.color)
		_label(column, str(module.description), 16, NeonUI.WHITE)
	close_button = NeonUI.make_button("CloseBuildReference", "BACK TO PAUSE", NeonUI.YELLOW, Vector2(0, 48))
	close_button.pressed.connect(_close)
	layout.add_child(close_button)
	close_button.grab_focus()

func _label(parent: Node, copy: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = copy
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()
