extends CanvasLayer
## HUD — displays score, combo, lives, wave, XP bar, level, and active power-up indicators.

@onready var score_label: Label = $MarginContainer/TopBar/ScoreLabel
@onready var combo_label: Label = $MarginContainer/TopBar/ComboLabel
@onready var wave_label: Label = $MarginContainer/TopBar/WaveLabel
@onready var lives_container: HBoxContainer = $MarginContainer/TopBar/LivesContainer
@onready var wave_banner: Label = $WaveBanner
@onready var level_up_banner: Label = $LevelUpBanner
@onready var power_up_container: HBoxContainer = $MarginContainer2/PowerUpContainer
@onready var level_label: Label = $XPBarContainer/VBox/LevelLabel
@onready var xp_bar: ProgressBar = $XPBarContainer/VBox/XPBar
@onready var boss_bar_container: MarginContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/VBox/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossBarContainer/VBox/BossHealthBar

func _ready() -> void:
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.combo_changed.connect(_on_combo_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_cleared.connect(_on_wave_cleared)
	SignalBus.power_up_collected.connect(_on_power_up_collected)
	SignalBus.xp_changed.connect(_on_xp_changed)
	SignalBus.level_up.connect(_on_level_up)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_health_changed.connect(_on_boss_health_changed)
	SignalBus.boss_died.connect(_on_boss_died)
	wave_banner.visible = false
	level_up_banner.visible = false
	boss_bar_container.visible = false

func update_all() -> void:
	_on_score_changed(GameManager.score)
	_on_combo_changed(GameManager.combo)
	_on_lives_changed(GameManager.lives)
	_on_wave_started(GameManager.current_wave)
	_on_xp_changed(GameManager.xp, GameManager.xp_to_next_level)
	level_label.text = "LV " + str(GameManager.level)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: " + str(new_score)

func _on_combo_changed(new_combo: int) -> void:
	if new_combo > 1:
		combo_label.text = "×" + str(new_combo) + " COMBO"
		combo_label.visible = true
		# Pulse effect
		var tween := create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.08)
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15)
	else:
		combo_label.visible = false

func _on_lives_changed(new_lives: int) -> void:
	# Re-draw lives icons
	for child in lives_container.get_children():
		child.queue_free()
	for i in range(new_lives):
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
		heart.add_theme_font_size_override("font_size", 22)
		lives_container.add_child(heart)

func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE " + str(wave_number)
	var is_boss_wave := (wave_number % 5 == 0)
	var is_elite_wave := (wave_number % 10 == 0)
	if is_boss_wave:
		wave_banner.text = "⚠  " + ("ELITE BOSS!" if is_elite_wave else "BOSS INCOMING!")
		wave_banner.modulate = Color(1.0, 0.15, 0.4) if is_elite_wave else Color(1.0, 0.5, 0.1)
	else:
		wave_banner.text = "— WAVE " + str(wave_number) + " —"
		wave_banner.modulate = Color.WHITE
	wave_banner.visible = true
	wave_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): wave_banner.visible = false)

func _on_wave_cleared(wave_number: int) -> void:
	wave_banner.text = "WAVE " + str(wave_number) + " CLEARED!"
	wave_banner.modulate = Color(0.3, 1.0, 0.5)
	wave_banner.visible = true
	wave_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		wave_banner.visible = false
		wave_banner.modulate = Color.WHITE
	)

# --- XP / Level ---

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	xp_bar.max_value = xp_to_next
	xp_bar.value = current_xp

func _on_level_up(new_level: int) -> void:
	level_label.text = "LV " + str(new_level)

	# Pulse the level label
	var label_tween := create_tween()
	label_tween.tween_property(level_label, "scale", Vector2(1.5, 1.5), 0.1)
	label_tween.tween_property(level_label, "scale", Vector2.ONE, 0.2)

	# Show a brief "LEVEL UP!" banner
	level_up_banner.text = "⚔  LEVEL " + str(new_level) + "!  ⚔"
	level_up_banner.visible = true
	level_up_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(level_up_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): level_up_banner.visible = false)

# --- Boss ---

func _on_boss_spawned(health: int, max_health: int) -> void:
	boss_health_bar.max_value = max_health
	boss_health_bar.value = health
	var is_elite := GameManager.current_wave % 10 == 0
	boss_name_label.text = "⚠  ELITE BOSS" if is_elite else "⚠  BOSS"
	boss_name_label.add_theme_color_override("font_color",
		Color(1.0, 0.1, 0.7) if is_elite else Color(1.0, 0.2, 0.5))
	boss_bar_container.visible = true

	# Pulse boss bar on spawn
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(boss_bar_container, "modulate:a", 0.3, 0.15)
	tween.tween_property(boss_bar_container, "modulate:a", 1.0, 0.15)

func _on_boss_health_changed(health: int) -> void:
	boss_health_bar.value = health

func _on_boss_died(_points: int) -> void:
	var tween := create_tween()
	tween.tween_property(boss_bar_container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		boss_bar_container.visible = false
		boss_bar_container.modulate.a = 1.0
	)

# --- Power-ups ---

func _on_power_up_collected(type: int, _pos: Vector2) -> void:
	# Show brief indicator
	var indicator := Label.new()
	var names := ["SCALE UP!", "RAPID FIRE!", "SHIELD!", "SPREAD SHOT!", "MAGNET!", "NUKE!"]
	var colors := [
		Color(0.2, 0.8, 1.0),
		Color(1.0, 0.8, 0.0),
		Color(0.3, 0.9, 0.5),
		Color(1.0, 0.4, 0.8),
		Color(0.6, 0.4, 1.0),
		Color(1.0, 0.2, 0.2),
	]
	indicator.text = names[type] if type < names.size() else "POWER UP!"
	indicator.add_theme_color_override("font_color", colors[type] if type < colors.size() else Color.WHITE)
	indicator.add_theme_font_size_override("font_size", 20)
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_up_container.add_child(indicator)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.4)
	tween.tween_callback(indicator.queue_free)
