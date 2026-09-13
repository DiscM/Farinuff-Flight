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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "THE RETURN SIGNAL · EXPEDITION CHART"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var instructions := Label.new()
	instructions.text = "Trace the twenty-wave route home. Inspect a relay to preview its threats. Every launch begins in the Far Reach; choose the next route after clearing each sector."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)
	_chart = preload("res://ui/expedition_chart.gd").new()
	column.add_child(_chart)
	var legend := Label.new()
	legend.text = "◇ Reachable · ✓ Cleared · ◈ Discovered · ▣ Locked\nWhite frame: input focus. Gold frame: selected relay. Confirm a relay to inspect it."
	if ExpeditionManager.get_snapshot().expedition_clear_count > 0:
		legend.text += "\nVOID REACH · Follow the signal after Wave 20 to enter Endless. First contact: Void Harbinger, Wave 25."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)
	_launch_button = Button.new()
	_launch_button.text = "REVIEW LOADOUT · LAUNCH FROM WAVE 1"
	_launch_button.custom_minimum_size.y = 48
	_launch_button.pressed.connect(_launch)
	column.add_child(_launch_button)
	_archives_button = Button.new()
	var recovered := ExpeditionManager.get_recovered_fragments().size()
	_archives_button.text = "ARCHIVES · %d / 4 FRAGMENTS" % recovered
	_archives_button.disabled = recovered == 0
	_archives_button.tooltip_text = "Recover a fragment by clearing a route sector to open the Archives."
	_archives_button.custom_minimum_size.y = 44
	_archives_button.pressed.connect(_open_archives)
	column.add_child(_archives_button)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size.y = 44
	back.pressed.connect(_close)
	column.add_child(back)
	_launch_button.grab_focus()
	column.resized.connect(func():
		if _launch_button.has_focus():
			scroll.ensure_control_visible.call_deferred(_launch_button)
	)
	await get_tree().process_frame
	if is_instance_valid(scroll) and _launch_button.has_focus():
		scroll.ensure_control_visible(_launch_button)

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
