extends Control
## Pause menu — shown when ESC is pressed during gameplay.
## Allows the player to resume, retry, or return to the main menu.

signal resumed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		resumed.emit()

func _build_ui() -> void:
	# Full-screen semi-transparent overlay
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.08, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center column
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left  = -160
	vbox.offset_right =  160
	vbox.offset_top   = -180
	vbox.offset_bottom = 180
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⏸  PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var div := HSeparator.new()
	div.add_theme_color_override("color", Color(1.0, 0.92, 0.3, 0.35))
	vbox.add_child(div)

	# Spacer
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(sp)

	# Buttons
	vbox.add_child(_make_btn("▶  Resume",    Color(0.3, 1.0, 0.5),  _on_resume))
	vbox.add_child(_make_btn("🔄  Retry",    Color(0.4, 0.82, 1.0), _on_retry))
	vbox.add_child(_make_btn("🏠  Main Menu", Color(1.0, 0.5, 0.5),  _on_menu))

func _make_btn(label: String, col: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(280, 54)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(callback)
	return btn

# ── Actions ────────────────────────────────────────────────────────────────────

func _on_resume() -> void:
	resumed.emit()
	get_tree().paused = false
	get_parent().queue_free()

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

# ── Animation ──────────────────────────────────────────────────────────────────

func _animate_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	pivot_offset = Vector2(360, 512)  # center of the 720×1024 viewport
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
