extends Control
## Point allocation screen — pauses game, lets player invest points into stats.
## Shown every 5 waves with a set number of points to allocate.

signal allocation_done

var points_remaining: int = 0

# When true, no fullscreen overlay bg is drawn — used for side-by-side layout
var panel_only: bool = false

# Temp allocation (committed on confirm)
var alloc_fire_rate: int = 0
var alloc_health: int = 0
var alloc_speed: int = 0

# UI refs (built in _ready)
var points_label: Label
var fire_rate_label: Label
var health_label: Label
var speed_label: Label
var fire_rate_btn: Button
var health_btn: Button
var speed_btn: Button
var confirm_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

func set_points(p: int) -> void:
	points_remaining = p
	if points_label:
		_refresh_ui()

# ── UI Construction ──────────────────────────────────────────────

func _build_ui() -> void:
	if not panel_only:
		# Dark overlay background (fullscreen)
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.01, 0.04, 0.90)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# Center container
	var vbox := VBoxContainer.new()
	if panel_only:
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.set_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.offset_left = -220
		vbox.offset_right = 220
		vbox.offset_top = -240
		vbox.offset_bottom = 240
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚙  UPGRADE YOUR SHIP  ⚙"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	# Subtitle / points
	points_label = Label.new()
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	points_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(points_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Stat rows
	_add_stat_row(vbox, "🔥  FIRE RATE", "fire_rate", Color(1.0, 0.75, 0.15))
	_add_stat_row(vbox, "❤️  HEALTH", "health", Color(1.0, 0.4, 0.55))
	_add_stat_row(vbox, "🚀  FLIGHT SPEED", "speed", Color(0.3, 0.85, 1.0))

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	# Confirm button
	confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.custom_minimum_size = Vector2(200, 50)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(confirm_btn)

	_refresh_ui()

func _add_stat_row(parent: VBoxContainer, label_text: String, stat_id: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	# Stat name
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(220, 0)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)

	# Current level display
	var level_lbl := Label.new()
	level_lbl.custom_minimum_size = Vector2(50, 0)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	level_lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(level_lbl)

	# + button
	var btn := Button.new()
	btn.text = "  +  "
	btn.custom_minimum_size = Vector2(50, 40)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", color)
	btn.pressed.connect(_on_plus_pressed.bind(stat_id))
	row.add_child(btn)

	# Store refs
	match stat_id:
		"fire_rate":
			fire_rate_label = level_lbl
			fire_rate_btn = btn
		"health":
			health_label = level_lbl
			health_btn = btn
		"speed":
			speed_label = level_lbl
			speed_btn = btn

# ── Interaction ──────────────────────────────────────────────────

func _on_plus_pressed(stat_id: String) -> void:
	if points_remaining <= 0:
		return
	points_remaining -= 1
	match stat_id:
		"fire_rate":
			alloc_fire_rate += 1
		"health":
			alloc_health += 1
		"speed":
			alloc_speed += 1
	_refresh_ui()

func _on_confirm() -> void:
	# Apply all allocated points
	for i in range(alloc_fire_rate):
		GameManager.apply_stat_point("fire_rate")
	for i in range(alloc_health):
		GameManager.apply_stat_point("health")
	for i in range(alloc_speed):
		GameManager.apply_stat_point("speed")

	allocation_done.emit()
	# In panel_only mode the parent is a shared HBoxContainer; game.gd cleans up the overlay.
	if not panel_only:
		get_parent().queue_free()

func _refresh_ui() -> void:
	points_label.text = "Points remaining: " + str(points_remaining)

	var fr_total: int = GameManager.stat_fire_rate_level + alloc_fire_rate
	var hp_total: int = GameManager.stat_health_level + alloc_health
	var sp_total: int = GameManager.stat_speed_level + alloc_speed

	fire_rate_label.text = str(fr_total)
	health_label.text = str(hp_total)
	speed_label.text = str(sp_total)

	# Disable + buttons when no points left
	var can_alloc := points_remaining > 0
	fire_rate_btn.disabled = not can_alloc
	health_btn.disabled = not can_alloc
	speed_btn.disabled = not can_alloc

	# Enable confirm only when all points spent
	confirm_btn.disabled = points_remaining > 0

func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
