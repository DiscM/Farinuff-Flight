extends Control
signal back_requested
signal closed
signal expedition_requested
signal open_section(page_id: StringName)
@export var embedded := false
var _chart: Control
var _archives: Control
var _launch_button: Button
var _archives_button: Button
var _leaving := false

func _ready() -> void:
	add_to_group("scalable_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.015, 0.04, 0.98)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	preload("res://ui/shared/menu_briefing.gd").enable_scroll(scroll, "Scroll route intelligence")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "ROUTE MAP"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	preload("res://ui/shared/menu_briefing.gd").wrap_heading(title)
	_chart = preload("res://ui/expedition_chart.gd").new()
	column.add_child(_chart)
	var legend := Label.new()
	legend.text = "◇ Available · ✓ Cleared · ◈ Discovered · ▣ Locked"
	if ExpeditionManager.get_snapshot().expedition_clear_count > 0:
		legend.text += "\nENDLESS · Wave 21+"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)
	_launch_button = Button.new()
	_launch_button.text = "CHOOSE SHIP · START AT WAVE 1"
	_launch_button.custom_minimum_size.y = 48
	_launch_button.pressed.connect(_launch)
	layout.add_child(_launch_button)
	NeonUI.style_primary(_launch_button)
	var secondary_actions := HBoxContainer.new()
	secondary_actions.add_theme_constant_override("separation", 12)
	layout.add_child(secondary_actions)
	_archives_button = Button.new()
	var recovered := ExpeditionManager.get_recovered_fragments().size()
	_archives_button.text = "ARCHIVES · %d / 4 FRAGMENTS" % recovered
	_archives_button.disabled = recovered == 0
	_archives_button.tooltip_text = "Clear a route to find a signal fragment and unlock the Archives."
	_archives_button.custom_minimum_size.y = 44
	_archives_button.pressed.connect(_open_archives)
	_archives_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archives_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	secondary_actions.add_child(_archives_button)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size.y = 44
	back.pressed.connect(_close)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_actions.add_child(back)
	_launch_button.grab_focus()

func get_primary_safe_action() -> Control:
	return _launch_button

func _launch() -> void:
	if _leaving or is_instance_valid(_archives):
		return
	if embedded:
		open_section.emit(&"launch_bay")
	else:
		_leaving = true
		expedition_requested.emit()

func _open_archives() -> void:
	if is_instance_valid(_archives):
		return
	if embedded:
		open_section.emit(&"archives")
		return
	_archives = preload("res://ui/frontend/archives_screen.gd").new()
	_archives.closed.connect(func():
		_archives.queue_free()
		_archives = null
		_archives_button.grab_focus()
	)
	add_child(_archives)

func _close() -> void:
	if _leaving or is_instance_valid(_archives):
		return
	if embedded:
		back_requested.emit()
	else:
		closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not is_instance_valid(_archives):
		get_viewport().set_input_as_handled()
		_close()
