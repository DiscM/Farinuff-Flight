extends Control
## Owns input during scene preparation so a pending launch cannot be repeated.
signal returned
var scene_path := ""
var _status: Label
var _back: Button
var _failed := false
var _progress: ProgressBar
var _hint: Label
var _heading: Label

func _ready() -> void:
	add_to_group("scalable_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	var shade := ColorRect.new()
	shade.color = Color.WHITE
	var sky := ShaderMaterial.new()
	preload("res://effects/rendering/galaxy_visual_style.gd").apply_to(sky)
	shade.material = sky
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var eyebrow := NeonUI.make_label("FARINUFF FLIGHT  /  LAUNCH SEQUENCE", 14, NeonUI.CYAN)
	eyebrow.custom_minimum_size.y = 24
	column.add_child(eyebrow)
	_heading = NeonUI.make_label("READY FOR THE VOID", 36)
	_heading.custom_minimum_size.y = 56
	column.add_child(_heading)
	_status = Label.new()
	_status.custom_minimum_size.x = 360
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "PREPARING FLIGHT"
	_status.add_theme_font_size_override("font_size", 18)
	column.add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(360, 5)
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.16, 0.23, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = NeonUI.CYAN
	_progress.add_theme_stylebox_override("background", track)
	_progress.add_theme_stylebox_override("fill", fill)
	column.add_child(_progress)
	_hint = NeonUI.make_label("HOLD %s TO FIRE  ·  %s TO BOOST" % [InputBindings.binding_label("shoot").to_upper(), InputBindings.binding_label("boost").to_upper()], 14, Color(0.62, 0.76, 0.84))
	_hint.custom_minimum_size = Vector2(360, 38)
	column.add_child(_hint)
	_back = Button.new()
	_back.text = "RETURN TO MAIN MENU"
	_back.custom_minimum_size.y = 48
	_back.pressed.connect(func(): returned.emit())
	NeonUI.style_primary(_back)
	_back.hide()
	column.add_child(_back)

func _process(_delta: float) -> void:
	if not _failed:
		var progress := clampf(ResourceCache.get_scene_progress(scene_path) * 100.0, 0.0, 100.0)
		_progress.value = progress
		_status.text = "PREPARING FLIGHT · %d%%" % roundi(progress)

func show_failure() -> void:
	_failed = true
	_heading.text = "LAUNCH INTERRUPTED"
	_status.text = "Couldn't start the run.\nReturn to the main menu and try again."
	_progress.hide()
	_hint.hide()
	_back.show()
	_back.grab_focus()

func _input(_event: InputEvent) -> void:
	if not _failed:
		get_viewport().set_input_as_handled()
