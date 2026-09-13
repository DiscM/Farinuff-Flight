extends Control
## Owns input during scene preparation so a pending launch cannot be repeated.
signal returned
var scene_path := ""
var _status: Label
var _back: Button
var _failed := false

func _ready() -> void:
	add_to_group("scalable_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	_status = Label.new()
	_status.custom_minimum_size.x = 360
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "PREPARING FLIGHT"
	_status.add_theme_font_size_override("font_size", 24)
	column.add_child(_status)
	_back = Button.new()
	_back.text = "RETURN TO COMMAND DECK"
	_back.custom_minimum_size.y = 48
	_back.pressed.connect(func(): returned.emit())
	_back.hide()
	column.add_child(_back)

func _process(_delta: float) -> void:
	if not _failed:
		_status.text = "PREPARING FLIGHT · %d%%" % roundi(ResourceCache.get_scene_progress(scene_path) * 100.0)

func show_failure() -> void:
	_failed = true
	_status.text = "Couldn't prepare this flight.\nReturn to the command deck and try again."
	_back.show()
	_back.grab_focus()

func _input(_event: InputEvent) -> void:
	if not _failed:
		get_viewport().set_input_as_handled()
