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
var allocation_committed: bool = false

# UI refs (built in _ready)
var points_label: Label
var fire_rate_label: Label
var health_label: Label
var speed_label: Label
var fire_rate_btn: Button
var health_btn: Button
var speed_btn: Button
var confirm_btn: Button
var reset_btn: Button

## Builds the allocation UI and plays the entrance animation.
## Runs in PROCESS_MODE_ALWAYS so it works while the game is paused.
func _ready() -> void:
	add_to_group("scalable_ui")
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

## Sets the number of points available to allocate and refreshes the UI
## to reflect the new count.
func set_points(p: int) -> void:
	points_remaining = p
	if points_label:
		_refresh_ui()
		if not panel_only:
			if points_remaining > 0:
				_focus_available_stat()
			else:
				confirm_btn.grab_focus()

# ── UI Construction ──────────────────────────────────────────────

## Constructs the allocation popup UI: optional dark overlay background
## (skipped in panel_only mode), title, points remaining label, three
## stat rows (Fire Rate / Health / Speed) each with a level display and
## "+" button, and a confirm button that enables only when all points
## have been spent.
func _build_ui() -> void:
	var compact_layout := panel_only

	if not panel_only:
		# Dark overlay background (fullscreen)
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.01, 0.04, 0.90)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# A centered panel uses its content minimum so text scaling cannot clip rows.
	var vbox := VBoxContainer.new()
	if panel_only:
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(vbox)
	else:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		var panel := PanelContainer.new()
		var frame := NeonUI.plaque(Color(0.18, 0.38, 0.48), NeonUI.INK_DARK, 2, 1)
		frame.set_content_margin_all(24)
		panel.add_theme_stylebox_override("panel", frame)
		panel.custom_minimum_size.x = 440
		center.add_child(panel)
		panel.add_child(vbox)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN if compact_layout else BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12 if compact_layout else 14)

	# Title
	var title := Label.new()
	title.text = "SHIP SYSTEMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_font_size_override("font_size", 26 if compact_layout else 30)
	title.add_theme_font_override("font", NeonUI.HEADING_FONT)
	vbox.add_child(title)

	# Subtitle / points
	points_label = Label.new()
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	points_label.add_theme_font_size_override("font_size", 16 if compact_layout else 18)
	vbox.add_child(points_label)
	var guidance := NeonUI.make_label("Review your choices, then apply upgrades.", 13, Color(0.57, 0.68, 0.78))
	guidance.custom_minimum_size.y = 36
	vbox.add_child(guidance)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6 if compact_layout else 10)
	vbox.add_child(spacer)

	# Stat rows
	_add_stat_row(vbox, "FIRE RATE", "fire_rate", Color(1.0, 0.75, 0.15))
	_add_stat_row(vbox, "EXTRA LIVES", "health", Color(1.0, 0.4, 0.55))
	_add_stat_row(vbox, "THRUST", "speed", Color(0.3, 0.85, 1.0))

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6 if compact_layout else 10)
	vbox.add_child(spacer2)

	reset_btn = Button.new()
	reset_btn.text = "RESET CHOICES"
	reset_btn.custom_minimum_size = Vector2(180, 36)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(_reset_choices)
	vbox.add_child(reset_btn)

	# Confirm button
	confirm_btn = Button.new()
	confirm_btn.text = "APPLY UPGRADES"
	confirm_btn.custom_minimum_size = Vector2(180 if compact_layout else 200, 46 if compact_layout else 50)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	NeonUI.style_primary(confirm_btn)
	confirm_btn.add_theme_font_size_override("font_size", 18 if compact_layout else 20)
	confirm_btn.add_theme_color_override("font_color", NeonUI.INK_DARK)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(confirm_btn)

	_refresh_ui()

## Helper: creates a horizontal row with a stat name label, current level
## display, and a "+" button for the given stat. Stores references to the
## label and button for later updates.
func _add_stat_row(parent: VBoxContainer, label_text: String, stat_id: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10 if panel_only else 12)
	var card := PanelContainer.new()
	var row_style := NeonUI.plaque(Color(color, 0.28), Color(0.02, 0.035, 0.06), 2, 1)
	row_style.content_margin_top = 10
	row_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", row_style)
	parent.add_child(card)
	card.add_child(row)
	var caption := VBoxContainer.new()
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_constant_override("separation", 3)
	row.add_child(caption)

	# Stat name
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(125 if panel_only else 145, 0)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_font_size_override("font_size", 17 if panel_only else 18)
	caption.add_child(name_label)
	var benefit := Label.new()
	benefit.text = {"health": "+1 life / point", "fire_rate": "Shot delay −4.5% / point", "speed": "+4.5% / point · max 45%"}[stat_id]
	benefit.add_theme_font_size_override("font_size", 11 if panel_only else 12)
	benefit.add_theme_color_override("font_color", Color(0.57, 0.68, 0.78))
	caption.add_child(benefit)

	# Current level display
	var level_lbl := Label.new()
	level_lbl.custom_minimum_size = Vector2(110 if panel_only else 135, 0)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_override("font", NeonUI.DATA_FONT)
	level_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	level_lbl.add_theme_font_size_override("font_size", 17 if panel_only else 18)
	row.add_child(level_lbl)

	# + button
	var btn := Button.new()
	btn.text = "  +  "
	btn.custom_minimum_size = Vector2(58, 38 if panel_only else 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 20 if panel_only else 22)
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

## Called when a stat's "+" button is pressed. Decrements the remaining
## points, increments the chosen stat's temporary allocation, and refreshes
## the UI to reflect the new state.
func _on_plus_pressed(stat_id: String) -> void:
	var pending := alloc_fire_rate if stat_id == "fire_rate" else alloc_speed if stat_id == "speed" else alloc_health
	if allocation_committed or points_remaining <= 0 or not GameManager.can_allocate_stat(stat_id, pending):
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
	if points_remaining == 0:
		confirm_btn.grab_focus()
	elif (stat_id == "fire_rate" and fire_rate_btn.disabled) or (stat_id == "speed" and speed_btn.disabled):
		_focus_available_stat()


func _focus_available_stat() -> void:
	for button: Button in [fire_rate_btn, health_btn, speed_btn]:
		if not button.disabled:
			button.grab_focus()
			return


func _reset_choices() -> void:
	if allocation_committed:
		return
	points_remaining += alloc_fire_rate + alloc_health + alloc_speed
	alloc_fire_rate = 0
	alloc_health = 0
	alloc_speed = 0
	_refresh_ui()
	_focus_available_stat()


## Called when the "APPLY UPGRADES" button is pressed. Applies all temporarily
## allocated points to GameManager's stat system, emits allocation_done,
## and frees the popup (unless in panel_only mode).
func _on_confirm() -> void:
	if allocation_committed or points_remaining > 0:
		return
	allocation_committed = true

	# Apply all allocated points
	for i in range(alloc_fire_rate):
		GameManager.apply_stat_point("fire_rate")
	for i in range(alloc_health):
		GameManager.apply_stat_point("health")
	for i in range(alloc_speed):
		GameManager.apply_stat_point("speed")

	_show_completed_state()
	allocation_done.emit()
	# In panel_only mode the parent is a shared HBoxContainer; game.gd cleans up the overlay.
	if not panel_only:
		get_parent().queue_free()


## Locks a completed panel while the combined milestone screen waits for the
## elite selection. Repeated confirmation cannot apply the allocation again.
func _show_completed_state() -> void:
	points_label.text = "UPGRADES APPLIED"
	points_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	fire_rate_btn.disabled = true
	health_btn.disabled = true
	speed_btn.disabled = true
	reset_btn.disabled = true
	confirm_btn.text = "APPLIED"
	confirm_btn.disabled = true

## Updates all UI elements: points remaining label, stat level displays
## (showing the sum of existing + pending allocations), button disabled
## states, and the confirm button (only enabled when all points are spent).
func _refresh_ui() -> void:
	points_label.text = "%d POINT%s AVAILABLE" % [points_remaining, "" if points_remaining == 1 else "S"]

	var fr_total: int = GameManager.stat_fire_rate_level + alloc_fire_rate
	var sp_total: int = GameManager.stat_speed_level + alloc_speed

	fire_rate_label.text = "−%.1f%%" % (minf(fr_total * GameManager.STAT_BONUS_STEP, GameManager.STAT_BONUS_CAP) * 100.0)
	health_label.text = "%d → %d" % [GameManager.lives, GameManager.lives + alloc_health] if alloc_health > 0 else str(GameManager.lives)
	speed_label.text = "+%.1f%%" % (minf(sp_total * GameManager.STAT_BONUS_STEP, GameManager.STAT_BONUS_CAP) * 100.0)
	fire_rate_btn.text = "MAX" if fr_total >= GameManager.STAT_MAX_LEVEL else "+"
	speed_btn.text = "MAX" if sp_total >= GameManager.STAT_MAX_LEVEL else "+"
	fire_rate_btn.tooltip_text = "Reduce base shot delay by 4.5% per point, up to 45%. Other fire-rate upgrades stack with this reduction."
	speed_btn.tooltip_text = "Add 4.5% thrust. Maximum allocation bonus: 45%."
	health_btn.tooltip_text = "Restore one life immediately when upgrades are applied."
	reset_btn.disabled = alloc_fire_rate + alloc_health + alloc_speed == 0

	# Disable + buttons when no points left
	var can_alloc := points_remaining > 0
	fire_rate_btn.disabled = not can_alloc or not GameManager.can_allocate_stat("fire_rate", alloc_fire_rate)
	health_btn.disabled = not can_alloc
	speed_btn.disabled = not can_alloc or not GameManager.can_allocate_stat("speed", alloc_speed)

	# Enable confirm only when all points spent
	confirm_btn.disabled = points_remaining > 0

## Plays a fade-in entrance animation.
func _animate_in() -> void:
	if bool(SaveManager.get_setting("reduced_motion", false)):
		return
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
