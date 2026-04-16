extends Control
## Pause menu — shown when ESC is pressed during gameplay.
## Allows the player to resume, retry, or return to the main menu.

signal resumed

const DEV_MENU_SCENE := preload("res://ui/dev_menu.tscn")
var _dev_panel: PanelContainer = null
var _dev_slot: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Explicitly size to the full viewport
	var vp_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	_build_ui()
	_animate_in()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		resumed.emit()

func _build_ui() -> void:
	var vp_size := get_viewport_rect().size

	# Full-screen semi-transparent overlay
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.08, 0.82)
	bg.position = Vector2.ZERO
	bg.size = vp_size
	add_child(bg)

	# ScrollContainer fills the screen so everything is scrollable if needed
	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = vp_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(scroll)

	# Main vertical column, centered horizontally
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(vp_size.x, 0)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 14)
	scroll.add_child(outer)

	# Top spacer to push content to vertical center
	var top_space := Control.new()
	top_space.custom_minimum_size = Vector2(0, maxf(vp_size.y * 0.12, 40))
	outer.add_child(top_space)

	# Title
	var title := Label.new()
	title.text = "⏸  PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.add_theme_font_size_override("font_size", 36)
	outer.add_child(title)

	var div := HSeparator.new()
	div.add_theme_color_override("color", Color(1.0, 0.92, 0.3, 0.35))
	outer.add_child(div)

	# Spacer
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	outer.add_child(sp)

	# Buttons — scale to 80% of viewport width, capped at 300px
	var btn_w := minf(vp_size.x * 0.8, 300.0)
	outer.add_child(_make_btn("▶  Resume",     Color(0.3, 1.0, 0.5),  _on_resume,    btn_w))
	outer.add_child(_make_btn("🔄  Retry",     Color(0.4, 0.82, 1.0), _on_retry,     btn_w))
	outer.add_child(_make_btn("🏠  Main Menu", Color(1.0, 0.5, 0.5),  _on_menu,      btn_w))

	var dev_separator := HSeparator.new()
	dev_separator.add_theme_color_override("color", Color(0.3, 0.8, 0.3, 0.3))
	outer.add_child(dev_separator)

	outer.add_child(_make_btn("🛠  Dev Tools ▼", Color(0.3, 0.9, 0.4), _on_dev_tools, btn_w))

	# Container that holds the dev panel, hidden by default
	_dev_slot = VBoxContainer.new()
	_dev_slot.visible = false
	_dev_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(_dev_slot)

	# Bottom spacer
	var bot_space := Control.new()
	bot_space.custom_minimum_size = Vector2(0, 30)
	outer.add_child(bot_space)

func _make_btn(label: String, col: Color, callback: Callable, width: float) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(width, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(callback)
	return btn

# ── Actions ────────────────────────────────────────────────────────────────────

func _on_resume() -> void:
	resumed.emit()
	get_parent().queue_free()

func _on_dev_tools() -> void:
	if _dev_slot == null:
		return
	if _dev_slot.visible:
		_dev_slot.visible = false
	else:
		_dev_slot.visible = true
		if _dev_panel == null or not is_instance_valid(_dev_panel):
			_dev_panel = DEV_MENU_SCENE.instantiate() as PanelContainer
			_dev_panel.force_close.connect(_on_resume)
			_dev_slot.add_child(_dev_panel)

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
	pivot_offset = size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
