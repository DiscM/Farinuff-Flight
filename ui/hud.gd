extends CanvasLayer
## HUD — displays score, combo, lives, wave, orb meter, and active power-up indicators.

const HUD_PANEL_ALPHA := 0.08
const HUD_PANEL_DARK_ALPHA := 0.12

@onready var left_dock: Control = $LeftDock
@onready var boss_dock: Control = $BossDock
@onready var right_dock: Control = $RightDock
@onready var score_panel: PanelContainer = $LeftDock/PanelStack/ScorePanel
@onready var wave_panel: PanelContainer = $LeftDock/PanelStack/WavePanel
@onready var combo_panel: PanelContainer = $LeftDock/PanelStack/ComboPanel
@onready var lives_panel: PanelContainer = $RightDock/PanelStack/LivesPanel
@onready var orb_panel: PanelContainer = $RightDock/PanelStack/OrbPanel
@onready var power_up_panel: PanelContainer = $RightDock/PanelStack/PowerUpPanel
@onready var score_label: Label = $LeftDock/PanelStack/ScorePanel/ScoreLabel
@onready var wave_label: Label = $LeftDock/PanelStack/WavePanel/WaveLabel
@onready var combo_label: Label = $LeftDock/PanelStack/ComboPanel/ComboLabel
@onready var lives_container: HBoxContainer = $RightDock/PanelStack/LivesPanel/LivesRow/LivesContainer
@onready var lives_count_label: Label = $RightDock/PanelStack/LivesPanel/LivesRow/LivesCountLabel
@onready var power_up_container: HBoxContainer = $RightDock/PanelStack/PowerUpPanel/PowerUpVBox/PowerUpContainer
@onready var boss_bar_container: PanelContainer = $BossDock/BossBarContainer
@onready var boss_class_label: Label = $BossDock/BossBarContainer/BossVBox/BossClassLabel
@onready var boss_name_label: Label = $BossDock/BossBarContainer/BossVBox/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossDock/BossBarContainer/BossVBox/BossHealthBar
@onready var orb_bar: ProgressBar = $RightDock/PanelStack/OrbPanel/OrbRow/OrbBar
@onready var orb_label: Label = $RightDock/PanelStack/OrbPanel/OrbRow/OrbLabel

# Orb meter (built in code)
const MAX_VISIBLE_HEARTS: int = 10

# --- Active power-up timers ---
## Timed power-ups shown as live countdown chips in the PowerUpPanel, keyed
## by the PowerUp.Type enum carried by SignalBus.power_up_collected.
## "timer" names the player's Timer node driving that effect.
const TIMED_POWER_UPS: Dictionary = {
	PowerUp.Type.RAPID_FIRE: {"key": &"rapid", "label": "RAPID", "color": Color(1.0, 0.8, 0.0), "timer": "rapid_fire_timer"},
	PowerUp.Type.SPREAD_SHOT: {"key": &"spread", "label": "SPREAD", "color": Color(1.0, 0.4, 0.8), "timer": "spread_shot_timer"},
	PowerUp.Type.MAGNET: {"key": &"magnet", "label": "MAGNET", "color": Color(0.6, 0.4, 1.0), "timer": "magnet_timer"},
}
const SHIELD_TYPE: int = PowerUp.Type.SHIELD
const SHIELD_CHIP: Dictionary = {"key": &"shield", "label": "SHIELD", "color": Color(0.3, 0.9, 0.5)}

var _effect_chips: Dictionary = {}  # StringName key -> {panel, time, bar}
var _player: Node = null

## Connects all HUD-relevant signals from the SignalBus, hides the boss
## bar initially, and builds the orb meter UI.
func _ready() -> void:
	_apply_mockup_style()
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

## Applies the split HUD styling from the approved mockup.
func _apply_mockup_style() -> void:
	score_panel.add_theme_stylebox_override("panel", _hud_outline(NeonUI.CYAN, Color(0.02, 0.06, 0.14, HUD_PANEL_ALPHA)))
	wave_panel.add_theme_stylebox_override("panel", _hud_outline(NeonUI.CYAN, Color(0.02, 0.06, 0.14, HUD_PANEL_ALPHA)))
	combo_panel.add_theme_stylebox_override("panel", _hud_outline(NeonUI.YELLOW, Color(0.08, 0.07, 0.02, HUD_PANEL_ALPHA)))
	lives_panel.add_theme_stylebox_override("panel", _hud_outline(NeonUI.GREEN, Color(0.01, 0.07, 0.08, HUD_PANEL_ALPHA)))
	orb_panel.add_theme_stylebox_override("panel", _hud_outline(NeonUI.CYAN, Color(0.02, 0.06, 0.14, HUD_PANEL_ALPHA)))
	boss_bar_container.add_theme_stylebox_override("panel", _hud_outline(NeonUI.PINK, Color(0.09, 0.02, 0.09, HUD_PANEL_DARK_ALPHA), 8))
	power_up_panel.add_theme_stylebox_override("panel", _hud_outline(NeonUI.YELLOW, Color(0.07, 0.06, 0.02, HUD_PANEL_ALPHA)))
	_style_progress_bar(orb_bar, NeonUI.CYAN)
	_style_progress_bar(boss_health_bar, NeonUI.PINK)

func _hud_outline(accent: Color, fill: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(accent, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 2
	style.shadow_offset = Vector2(1, 1)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style

func _style_progress_bar(bar: ProgressBar, accent: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.18)
	bg.border_color = Color(0.5, 0.75, 0.85, 0.42)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

## Forces a full refresh of all HUD elements from GameManager's current state.
func update_all() -> void:
	_on_score_changed(GameManager.score)
	_on_combo_changed(GameManager.combo)
	_on_lives_changed(GameManager.lives)
	_on_wave_started(GameManager.current_wave)

## Updates the score display text.
func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE " + _compact_number(new_score)

## Updates the combo display. Shows the combo label with a scale pulse
## animation when combo > 1; hides it otherwise.
func _on_combo_changed(new_combo: int) -> void:
	if new_combo > 1:
		combo_label.text = "MULT x" + str(new_combo)
		combo_panel.visible = true
		# Pulse effect
		var tween := create_tween()
		tween.tween_property(combo_panel, "scale", Vector2(1.04, 1.04), 0.08)
		tween.tween_property(combo_panel, "scale", Vector2.ONE, 0.15)
	else:
		combo_label.text = "MULT x1"
		combo_panel.visible = true

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
		heart.add_theme_color_override("font_color", NeonUI.GREEN)
		heart.add_theme_font_size_override("font_size", 9)
		lives_container.add_child(heart)
	lives_count_label.text = str(new_lives)
	if new_lives > MAX_VISIBLE_HEARTS:
		var overflow_label := Label.new()
		overflow_label.text = "+" + str(new_lives - MAX_VISIBLE_HEARTS)
		overflow_label.add_theme_color_override("font_color", NeonUI.GREEN)
		overflow_label.add_theme_font_size_override("font_size", 11)
		lives_container.add_child(overflow_label)

## Updates the persistent top-bar wave label.
func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE " + str(wave_number)

func _compact_number(value: int) -> String:
	if value >= 1000000:
		return str(snappedf(float(value) / 1000000.0, 0.1)) + "M"
	if value >= 10000:
		return str(snappedf(float(value) / 1000.0, 0.1)) + "K"
	return str(value)

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
	boss_class_label.text = "ELITE BOSS" if is_elite else "BOSS"
	boss_name_label.add_theme_color_override("font_color",
		NeonUI.WHITE if is_elite else Color(1.0, 0.82, 0.88))
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

## Polls the player's power-up timers every frame and keeps one chip per
## active effect in the PowerUpPanel. Timed effects (rapid fire, spread shot,
## magnet) show a live countdown and a depleting bar; the shield shows a
## persistent "HELD" chip until it absorbs a hit.
func _process(_delta: float) -> void:
	_sync_power_up_timers()

func _sync_power_up_timers() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_clear_effect_chips()
		return
	for type: int in TIMED_POWER_UPS:
		var cfg: Dictionary = TIMED_POWER_UPS[type]
		var timer: Timer = _player.get(cfg["timer"]) as Timer
		if timer != null and timer.time_left > 0.0:
			_update_effect_chip(cfg, timer.time_left, timer.wait_time)
		else:
			_remove_effect_chip(cfg["key"])
	# Shield persists until consumed — no countdown.
	if bool(_player.get("has_shield")):
		_update_effect_chip(SHIELD_CHIP, -1.0, 1.0)
	else:
		_remove_effect_chip(SHIELD_CHIP["key"])

## Creates the chip for an effect on first use, then refreshes its countdown
## text and progress bar. A negative remaining time means "no timer" (shield).
func _update_effect_chip(cfg: Dictionary, remaining: float, duration: float) -> void:
	var key: StringName = cfg["key"]
	if not _effect_chips.has(key):
		_effect_chips[key] = _build_effect_chip(cfg)
	var chip: Dictionary = _effect_chips[key]
	if remaining >= 0.0:
		(chip["time"] as Label).text = "%.1fs" % remaining
		(chip["bar"] as ProgressBar).value = remaining / maxf(duration, 0.01)
	else:
		(chip["time"] as Label).text = "HELD"
		(chip["bar"] as ProgressBar).value = 1.0

## Builds a compact color-coded chip: effect name on top, countdown beneath,
## and a thin depleting progress bar at the bottom.
func _build_effect_chip(cfg: Dictionary) -> Dictionary:
	var accent: Color = cfg["color"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 30)
	panel.add_theme_stylebox_override("panel", _hud_outline(accent, Color(0.01, 0.04, 0.09, 0.28), 4))
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)
	var name_label := Label.new()
	name_label.text = cfg["label"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_font_size_override("font_size", 7)
	vbox.add_child(name_label)
	var time_label := Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_color_override("font_color", NeonUI.WHITE)
	time_label.add_theme_font_size_override("font_size", 7)
	vbox.add_child(time_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 3)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	_style_progress_bar(bar, accent)
	vbox.add_child(bar)
	power_up_container.add_child(panel)
	# Brief fade-in so chips don't pop harshly
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	return {"panel": panel, "time": time_label, "bar": bar}

## Fades out and frees an effect's chip if one is currently shown.
func _remove_effect_chip(key: StringName) -> void:
	if not _effect_chips.has(key):
		return
	var panel: PanelContainer = _effect_chips[key]["panel"]
	_effect_chips.erase(key)
	if is_instance_valid(panel):
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(panel.queue_free)

func _clear_effect_chips() -> void:
	for key: StringName in _effect_chips.keys():
		_remove_effect_chip(key)

## Shows a brief color-coded text indicator when a power-up is collected
## (e.g. "NUKE!"), then fades it out after 1.5 seconds. Timed effects and the
## shield are skipped here — they get persistent countdown chips instead.
func _on_power_up_collected(type: int, _pos: Vector2) -> void:
	if TIMED_POWER_UPS.has(type) or type == SHIELD_TYPE:
		return
	# Show brief indicator
	var indicator := Label.new()
	var names := ["SCALE", "RAPID", "SHIELD", "SPREAD", "MAGNET", "NUKE"]
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
	indicator.add_theme_font_size_override("font_size", 7)
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(40, 18)
	chip.add_theme_stylebox_override("panel", _hud_outline(colors[type] if type < colors.size() else NeonUI.CYAN, Color(0.01, 0.04, 0.09, 0.2), 4))
	chip.add_child(indicator)
	power_up_container.add_child(chip)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(chip, "modulate:a", 0.0, 0.4)
	tween.tween_callback(chip.queue_free)

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
