extends Control
## Game Over screen — shows final score with retry and menu buttons.

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var best_wave_label: Label = $VBoxContainer/BestWaveLabel
@onready var salvage_label: Label = $VBoxContainer/SalvageLabel
@onready var salvage_breakdown_label: Label = $VBoxContainer/SalvageBreakdownLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel

## Connects the retry and menu buttons to their respective handlers.
func _ready() -> void:
	$VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)

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

## Unpauses the game and reloads the game scene for a fresh run.
func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")

## Unpauses the game and returns to the main menu.
func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
