extends Control
## Game Over debrief — shows final score, native loadout, retry, and menu.

const NativeUpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
const SHIP_PREVIEW_SCRIPT := preload("res://entities/player/ship_upgrade_preview.gd")
const FALLBACK_ICON := "✦"
const FALLBACK_NAME := "YOUR SHIP"
const NATIVE_RUN_PATH := "res://scenes/native_3d_run.tscn"
const MAIN_MENU_PATH := "res://ui/main_menu.tscn"

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var best_wave_label: Label = $VBoxContainer/BestWaveLabel
@onready var salvage_label: Label = $VBoxContainer/SalvageLabel
@onready var salvage_breakdown_label: Label = $VBoxContainer/SalvageBreakdownLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var loadout_label: Label = $VBoxContainer/LoadoutLabel
var _transitioning := false

## Connects the retry and menu buttons to their respective handlers.
func _ready() -> void:
	# Retry is the common next action. The bounded cache keeps the packed root
	# scene resident without creating another gameplay tree in the background.
	ResourceCache.prime_scene(NATIVE_RUN_PATH)
	ResourceCache.prime_scene(MAIN_MENU_PATH)
	$VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)
	_build_native_preview()

## Displays the final score, the all-time high score (highlighted when the
## run set a new record), the wave the player reached against the persisted
## best, and the itemized salvage breakdown including milestone awards.
func show_score(final_score: int) -> void:
	score_label.text = "SCORE: " + str(final_score)
	if GameManager.last_run_was_record:
		high_score_label.text = "NEW RECORD: " + str(GameManager.high_score)
		high_score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		high_score_label.text = "HIGH SCORE: " + str(GameManager.high_score)
	level_label.text = "WAVE REACHED: " + str(GameManager.current_wave)
	if MetaProgression.last_run_set_best_wave:
		best_wave_label.text = "NEW BEST WAVE: " + str(MetaProgression.stat_best_wave)
		best_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		best_wave_label.text = "BEST WAVE: " + str(MetaProgression.stat_best_wave)
	salvage_label.text = "SALVAGE EARNED: ⬡ " + str(GameManager.run_salvage) + "   (TOTAL: ⬡ " + str(MetaProgression.salvage) + ")"
	var breakdown := "BOSSES ⬡%d · SCORE ⬡%d · WAVES ⬡%d" % [
		GameManager.run_salvage_boss,
		GameManager.run_salvage_score_bonus,
		GameManager.run_salvage_wave_bonus,
	]
	if GameManager.run_salvage_milestones > 0:
		breakdown += "\n+ FIRST-CLEAR MILESTONE BONUS ⬡%d" % GameManager.run_salvage_milestones
	if GameManager.run_salvage_multiplier > 1.0:
		breakdown += "\n(INCLUDES ×%.2f MODIFIER BONUS)" % GameManager.run_salvage_multiplier
	salvage_breakdown_label.text = breakdown
	stats_label.text = "LIFETIME — RUNS: %d · KILLS: %d" % [
		MetaProgression.stat_total_runs,
		MetaProgression.stat_total_kills,
	]
	loadout_label.text = _format_loadout(_selected_hull_id(), _active_upgrade_ids())


func _build_native_preview() -> void:
	var preview := SHIP_PREVIEW_SCRIPT.new() as ShipUpgradePreview
	if preview == null:
		return
	preview.configure(_active_upgrade_ids(), "", _selected_hull_id())
	preview.custom_minimum_size = Vector2(0.0, 64.0)
	var spacer := $VBoxContainer/Spacer
	$VBoxContainer.add_child(preview)
	$VBoxContainer.move_child(preview, spacer.get_index())


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
			hull_name = _safe_text(ship, "name", FALLBACK_NAME).to_upper()
			break
	var module_names: Array[String] = []
	for upgrade_id in active_ids:
		var definition := _upgrade_definition(upgrade_id)
		var icon := _safe_text(definition, "icon", FALLBACK_ICON)
		var name := _safe_text(definition, "name", upgrade_id.replace("_", " ").to_upper())
		module_names.append("%s %s" % [icon, name])
	var modules_text := "NONE INSTALLED" if module_names.is_empty() else " · ".join(module_names)
	return "LOADOUT  ·  %s\nNATIVE MODULES  %d/%d  ·  %s" % [
		hull_name,
		active_ids.size(),
		NativeUpgradeCatalog.SUPPORTED_IDS.size(),
		modules_text,
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

## Unpauses the game and reuses the resident game scene for a fresh run.
func _on_retry_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	var run_scene := await ResourceCache.wait_for_scene(NATIVE_RUN_PATH)
	get_tree().paused = false
	if run_scene != null and get_tree().change_scene_to_packed(run_scene) == OK:
		return
	_transitioning = false
	get_tree().change_scene_to_file("res://scenes/native_3d_run.tscn")

## Unpauses the game and reuses the resident title scene.
func _on_menu_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	var menu_scene := await ResourceCache.wait_for_scene(MAIN_MENU_PATH)
	get_tree().paused = false
	if menu_scene != null and get_tree().change_scene_to_packed(menu_scene) == OK:
		return
	_transitioning = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
