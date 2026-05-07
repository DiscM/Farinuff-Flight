extends Control
## Try Again popup — intercepts game over when stocks remain.
## Player can spend a stock to continue, or decline to reach the true game over screen.

signal try_again_accepted
signal try_again_declined

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

func _build_ui() -> void:
	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.06, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center column
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left  = -200
	vbox.offset_right =  200
	vbox.offset_top   = -200
	vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "💀  YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.3))
	title.add_theme_font_size_override("font_size", 44)
	vbox.add_child(title)

	# Stocks left
	var stocks_lbl := Label.new()
	var s := GameManager.try_again_stocks
	stocks_lbl.text = "Try Again Stocks: " + _stock_icons(s)
	stocks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stocks_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	stocks_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(stocks_lbl)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1.0, 0.3, 0.3, 0.4))
	vbox.add_child(sep)

	# Spacer
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(sp)

	# Try Again button
	var yes_btn := Button.new()
	yes_btn.text = "▶  TRY AGAIN  (−1 Stock)"
	yes_btn.custom_minimum_size = Vector2(300, 58)
	yes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	yes_btn.add_theme_font_size_override("font_size", 22)
	yes_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	yes_btn.pressed.connect(_on_try_again)
	vbox.add_child(yes_btn)

	# Give Up button
	var no_btn := Button.new()
	no_btn.text = "✕  Give Up"
	no_btn.custom_minimum_size = Vector2(200, 44)
	no_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	no_btn.add_theme_font_size_override("font_size", 17)
	no_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	no_btn.pressed.connect(_on_give_up)
	vbox.add_child(no_btn)

	# Countdown timer label
	var timer_lbl := Label.new()
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	timer_lbl.add_theme_font_size_override("font_size", 14)
	timer_lbl.name = "TimerLabel"
	vbox.add_child(timer_lbl)
	_start_countdown(timer_lbl)

func _stock_icons(n: int) -> String:
	var out := ""
	for i in range(n):
		out += "⭐ "
	return out.strip_edges() if n > 0 else "—"

# ── Countdown ──────────────────────────────────────────────────────────────────

var _countdown: float = 10.0
var _action_taken: bool = false

func _start_countdown(lbl: Label) -> void:
	_countdown = 10.0
	lbl.text = "Auto-decline in 10 s…"
	var t := get_tree().create_timer(0.0, false, false, true)  # process while paused
	# We'll drive the countdown in _process instead
	set_meta("timer_label", lbl)

func _process(delta: float) -> void:
	if _action_taken:
		return
	_countdown -= delta
	var lbl := get_meta("timer_label") as Label
	if _countdown <= 0.0:
		_on_give_up()
		return
	lbl.text = "Auto-decline in %d s…" % int(_countdown) + ("" if _countdown > 3 else "  ⚠")
	if _countdown <= 3.0:
		lbl.modulate = Color(1.0, 0.4, 0.3)

# ── Actions ────────────────────────────────────────────────────────────────────

func _on_try_again() -> void:
	_action_taken = true
	GameManager.try_again_stocks -= 1
	# Restore lives to 3 and mark game active
	GameManager.lives = 3
	GameManager.is_game_active = true
	SignalBus.lives_changed.emit(GameManager.lives)
	try_again_accepted.emit()
	get_parent().queue_free()


func _on_give_up() -> void:
	_action_taken = true
	try_again_declined.emit()
	get_parent().queue_free()

# ── Animation ──────────────────────────────────────────────────────────────────

func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
