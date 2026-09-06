extends Control
## Try Again popup — intercepts game over when stocks remain.
## Player can spend a stock to continue, or decline to reach the true game over screen.

signal try_again_accepted
signal try_again_declined

const NativeUpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
const SHIP_PREVIEW_SCRIPT := preload("res://entities/player/ship_upgrade_preview.gd")
const FALLBACK_ICON := "✦"
const FALLBACK_NAME := "YOUR SHIP"

## Builds the try-again UI and plays the entrance animation.
## Runs in PROCESS_MODE_ALWAYS so it works while the game is paused.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

## Constructs the try-again popup UI: dark overlay, "YOU DIED" title,
## remaining stock icons, "TRY AGAIN" and "Give Up" buttons, and a
## countdown timer label that auto-declines after 10 seconds.
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
	vbox.offset_top   = -270
	vbox.offset_bottom = 270
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

	# Stocks left (icons plus a numeric readout so the count is never icon-only)
	var stocks_lbl := Label.new()
	var s := maxi(int(GameManager.try_again_stocks), 0)
	stocks_lbl.text = "Try Again Stocks: %s (%d)" % [_stock_icons(s), s]
	stocks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stocks_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	stocks_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(stocks_lbl)

	var preview := SHIP_PREVIEW_SCRIPT.new() as ShipUpgradePreview
	if preview != null:
		preview.configure(_active_upgrade_ids(), "", _selected_hull_id())
		preview.custom_minimum_size = Vector2(0.0, 76.0)
		vbox.add_child(preview)

	var loadout_label := Label.new()
	loadout_label.text = _format_loadout(_selected_hull_id(), _active_upgrade_ids())
	loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_label.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	loadout_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(loadout_label)

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
	yes_btn.disabled = s <= 0
	if yes_btn.disabled:
		yes_btn.text = "NO TRY-AGAIN STOCKS"
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

## Returns a string of star emoji icons representing the remaining stock
## count, or a dash if none remain.
func _stock_icons(n: int) -> String:
	n = maxi(n, 0)
	var out := ""
	for i in range(n):
		out += "⭐ "
	return out.strip_edges() if n > 0 else "—"

# ── Countdown ──────────────────────────────────────────────────────────────────

var _countdown: float = 10.0
var _action_taken: bool = false

## Initializes the 10-second auto-decline countdown and stores a reference
## to the countdown label for per-frame updates.
func _start_countdown(lbl: Label) -> void:
	_countdown = 10.0
	lbl.text = "Auto-decline in 10 s…"
	set_meta("timer_label", lbl)

## Decrements the countdown timer each frame. Triggers auto-decline when
## the timer reaches 0. Shows a warning indicator and turns the label red
## in the last 3 seconds.
func _process(delta: float) -> void:
	if _action_taken:
		return
	_countdown -= delta
	var lbl := get_meta("timer_label") as Label
	if lbl == null:
		return
	if _countdown <= 0.0:
		_on_give_up()
		return
	lbl.text = "Auto-decline in %d s…" % int(_countdown) + ("" if _countdown > 3 else "  ⚠")
	if _countdown <= 3.0:
		lbl.modulate = Color(1.0, 0.4, 0.3)

# ── Actions ────────────────────────────────────────────────────────────────────

## Called when the player presses "TRY AGAIN". Spends one stock, restores
## lives to the run's loadout-based starting lives, re-activates the game,
## emits try_again_accepted, and closes the popup.
func _on_try_again() -> void:
	if _action_taken or GameManager.try_again_stocks <= 0:
		_on_give_up()
		return
	_action_taken = true
	GameManager.try_again_stocks -= 1
	# Revive at the lives this run's loadout started with (hull reinforcement,
	# ship variant, and Damaged Hull already factored in), not a flat 3.
	GameManager.lives = GameManager.starting_lives
	GameManager.is_game_active = true
	SignalBus.lives_changed.emit(GameManager.lives)
	try_again_accepted.emit()
	_close_popup()


## Called when the player presses "Give Up" or the countdown expires.
## Emits try_again_declined to proceed to the true game over screen.
func _on_give_up() -> void:
	if _action_taken:
		return
	_action_taken = true
	try_again_declined.emit()
	_close_popup()


func _close_popup() -> void:
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.queue_free()
	else:
		queue_free()


func _selected_hull_id() -> String:
	var selected_id := str(MetaProgression.selected_ship)
	for ship in MetaProgression.SHIP_VARIANTS:
		if str(ship.get("id", "")) == selected_id:
			return selected_id
	return MetaProgression.DEFAULT_SHIP


func _active_upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	var player := get_tree().get_first_node_in_group("player_craft")
	if player == null or not player.has_method("get_active_elite_upgrade_ids"):
		return ids
	for raw_id: Variant in player.get_active_elite_upgrade_ids():
		var upgrade_id := str(raw_id)
		if NativeUpgradeCatalog.SUPPORTED_IDS.has(upgrade_id) and not ids.has(upgrade_id):
			ids.append(upgrade_id)
	return ids


func _format_loadout(hull_id: String, active_ids: Array[String]) -> String:
	var hull_name := FALLBACK_NAME
	for ship in MetaProgression.SHIP_VARIANTS:
		if str(ship.get("id", "")) == hull_id:
			hull_name = str(ship.get("name", FALLBACK_NAME)).strip_edges()
			if hull_name == "":
				hull_name = FALLBACK_NAME
			break
	var modules: Array[String] = []
	for upgrade_id in active_ids:
		var definition := _upgrade_definition(upgrade_id)
		var icon := _safe_text(definition, "icon", FALLBACK_ICON)
		var name := _safe_text(definition, "name", upgrade_id.replace("_", " ").to_upper())
		modules.append("%s %s" % [icon, name])
	var module_text := "NONE INSTALLED" if modules.is_empty() else " · ".join(modules)
	return "LOADOUT  ·  %s\nNATIVE MODULES  %d/%d  ·  %s" % [
		hull_name.to_upper(),
		active_ids.size(),
		NativeUpgradeCatalog.SUPPORTED_IDS.size(),
		module_text,
	]


func _upgrade_definition(upgrade_id: String) -> Dictionary:
	for definition in GameManager.ALL_UPGRADES:
		if str(definition.get("id", "")) == upgrade_id:
			return definition
	for definition in GameManager.META_ELITE_UPGRADES:
		if str(definition.get("id", "")) == upgrade_id:
			return definition
	return {}


func _safe_text(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, "")
	var text := str(value).strip_edges()
	return text if text != "" else fallback

# ── Animation ──────────────────────────────────────────────────────────────────

## Plays a fade-in entrance animation for the popup.
func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
