extends CanvasLayer
## HUD — displays score, combo, lives, wave, orb meter, and active power-up indicators.

@onready var score_label: Label = $MarginContainer/TopBar/ScoreLabel
@onready var combo_label: Label = $MarginContainer/TopBar/ComboLabel
@onready var wave_label: Label = $MarginContainer/TopBar/WaveLabel
@onready var lives_container: HBoxContainer = $MarginContainer/TopBar/LivesContainer
@onready var power_up_container: HBoxContainer = $MarginContainer2/PowerUpContainer
@onready var boss_bar_container: MarginContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/VBox/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossBarContainer/VBox/BossHealthBar

# Orb meter (built in code)
const MAX_VISIBLE_HEARTS: int = 10

var orb_bar: ProgressBar
var orb_label: Label

## Connects all HUD-relevant signals from the SignalBus, hides the boss
## bar initially, and builds the orb meter UI.
func _ready() -> void:
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.combo_changed.connect(_on_combo_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_cleared.connect(_on_wave_cleared)
	SignalBus.power_up_collected.connect(_on_power_up_collected)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_health_changed.connect(_on_boss_health_changed)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.orb_meter_changed.connect(_on_orb_meter_changed)
	boss_bar_container.visible = false
	_build_orb_meter()

## Forces a full refresh of all HUD elements from GameManager's current state.
func update_all() -> void:
	_on_score_changed(GameManager.score)
	_on_combo_changed(GameManager.combo)
	_on_lives_changed(GameManager.lives)
	_on_wave_started(GameManager.current_wave)

## Updates the score display text.
func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: " + str(new_score)

## Updates the combo display. Shows the combo label with a scale pulse
## animation when combo > 1; hides it otherwise.
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

## Rebuilds the lives display with up to 10 visible hearts and an overflow
## count for any health above that cap.
func _on_lives_changed(new_lives: int) -> void:
	# Re-draw lives icons
	for child in lives_container.get_children():
		child.queue_free()
	var visible_hearts := clampi(new_lives, 0, MAX_VISIBLE_HEARTS)
	for i in range(visible_hearts):
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
		heart.add_theme_font_size_override("font_size", 22)
		lives_container.add_child(heart)
	if new_lives > MAX_VISIBLE_HEARTS:
		var overflow_label := Label.new()
		overflow_label.text = "+" + str(new_lives - MAX_VISIBLE_HEARTS)
		overflow_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.6))
		overflow_label.add_theme_font_size_override("font_size", 18)
		lives_container.add_child(overflow_label)

## Updates the persistent top-bar wave label.
func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE " + str(wave_number)

## Wave clears are handled by GameManager progression; the HUD keeps this
## callback connected so future non-banner feedback can be added in one place.
func _on_wave_cleared(_wave_number: int) -> void:
	pass


# --- Boss ---

## Initializes the boss health bar: sets max/current values, displays the
## boss name with an appropriate color, shows the container, and plays a
## pulsing entrance animation.
func _on_boss_spawned(health: int, max_health: int, boss_name: String) -> void:
	boss_health_bar.max_value = max_health
	boss_health_bar.value = health
	var is_elite := GameManager.current_wave % 10 == 0
	boss_name_label.text = boss_name
	boss_name_label.add_theme_color_override("font_color",
		Color(1.0, 0.1, 0.7) if is_elite else Color(1.0, 0.2, 0.5))
	boss_bar_container.visible = true

	# Pulse boss bar on spawn
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(boss_bar_container, "modulate:a", 0.3, 0.15)
	tween.tween_property(boss_bar_container, "modulate:a", 1.0, 0.15)

## Updates the boss health bar value whenever the boss takes damage.
func _on_boss_health_changed(health: int) -> void:
	boss_health_bar.value = health

## Fades out the boss health bar when the boss is defeated, then hides it.
func _on_boss_died(_points: int) -> void:
	var tween := create_tween()
	tween.tween_property(boss_bar_container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		boss_bar_container.visible = false
		boss_bar_container.modulate.a = 1.0
	)

# --- Power-ups ---

## Shows a brief color-coded text indicator when a power-up is collected
## (e.g. "RAPID FIRE!"), then fades it out after 1.5 seconds.
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

# --- Orb Meter ---

## Constructs the orb meter UI programmatically: a diamond icon, progress
## bar, and fraction label anchored at the bottom-left of the screen.
func _build_orb_meter() -> void:
	var container := MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.offset_left = 16
	container.offset_bottom = -12
	container.offset_top = -42
	container.offset_right = 200
	add_child(container)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	container.add_child(hbox)

	var icon := Label.new()
	icon.text = "💎"
	icon.add_theme_font_size_override("font_size", 16)
	hbox.add_child(icon)

	orb_bar = ProgressBar.new()
	orb_bar.custom_minimum_size = Vector2(120, 12)
	orb_bar.max_value = GameManager.orbs_per_heart
	orb_bar.value = 0
	orb_bar.show_percentage = false
	orb_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(orb_bar)

	orb_label = Label.new()
	orb_label.text = "0/" + str(GameManager.orbs_per_heart)
	orb_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	orb_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(orb_label)

## Updates the orb meter progress bar and label. Plays a green flash when
## a heart is restored (meter resets to 0) or a scale pulse on regular
## orb collection.
func _on_orb_meter_changed(current: int, max_orbs: int) -> void:
	orb_bar.max_value = max_orbs
	orb_bar.value = current
	orb_label.text = str(current) + "/" + str(max_orbs)

	# Pulse on collection
	var tween := create_tween()
	if current == 0:
		# Heart restored — green flash
		tween.tween_property(orb_label, "modulate", Color(0.3, 1.0, 0.5), 0.1)
		tween.tween_property(orb_label, "modulate", Color.WHITE, 0.3)
	else:
		tween.tween_property(orb_bar, "scale", Vector2(1.1, 1.3), 0.06)
		tween.tween_property(orb_bar, "scale", Vector2.ONE, 0.12)
