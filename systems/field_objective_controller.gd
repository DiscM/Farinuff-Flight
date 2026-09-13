extends Node
## One optional interception per sector. Rewards and cancellation are sealed once.
var director: Node
var _attempted_sectors: Array[int] = []
var _courier: Node3D
var _remaining := 0.0
var _label: Label
var _sealed := true
var _cleanup_in := 0.0

func configure(encounters: Node) -> void:
	director = encounters
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -240
	_label.offset_right = 240
	_label.offset_top = -115
	_label.offset_bottom = -85
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	director.gameplay.hud.add_child(_label)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.game_over.connect(_on_game_over)
	_label.hide()

func try_start() -> bool:
	var wave := GameManager.current_wave
	var sector := floori(float(wave - 1) / 5.0)
	if wave % 5 != 3 or _attempted_sectors.has(sector) or not _sealed:
		return false
	# Admission consumes this ordinary spawn slot; retry next slot if crowded.
	var craft: Node3D = director.spawn_enemy(&"courier", 2, 0.32)
	if craft == null:
		return false
	_attempted_sectors.append(sector)
	GameManager.run_objectives_attempted += 1
	_courier = craft
	var bounds: Rect2 = director.gameplay.flight_space.get_combat_bounds()
	var crossing: Vector3 = Vector3(bounds.size.x, 0, 0)
	_remaining = clampf(director.gameplay.flight_space.combat_motion_to_screen(crossing).length() / 85.0, 3.0, 12.0)
	_sealed = false
	craft.finished.connect(_on_finished)
	_label.show()
	SignalBus.combat_notice.emit("OPTIONAL · INTERCEPT THE COURIER")
	return true

func _process(delta: float) -> void:
	if _cleanup_in > 0.0:
		_cleanup_in -= delta
		if _cleanup_in <= 0:
			_label.hide()
	if _sealed or not GameManager.is_game_active:
		return
	_remaining -= delta
	_label.text = "◇ COURIER · %.1fs · +500 SCORE%s" % [maxf(_remaining, 0.0), "" if GameManager.is_modifier_active("mod_no_powerups") else " + RAPID FIRE"]
	if _remaining <= 0.0 or not is_instance_valid(_courier):
		cancel("COURIER ESCAPED · WAVE CONTINUES")

func _on_finished(reason: int, position: Vector3) -> void:
	if _sealed:
		return
	_sealed = true
	_courier = null
	_cleanup_in = 3.0
	if reason != BasicEnemy3D.FinishReason.DESTROYED or not GameManager.is_game_active or GameManager.boss_active:
		_label.text = "COURIER LOST · WAVE CONTINUES"
		return
	GameManager.award_objective_score(500)
	if not GameManager.is_modifier_active("mod_no_powerups"):
		director.gameplay.power_up_manager.spawn_power_up.call_deferred(position, PowerUp.Type.RAPID_FIRE)
	_label.text = "COURIER INTERCEPTED · +500 SCORE"
	AudioManager.play_powerup()

func cancel(message: String = "") -> void:
	if _sealed:
		return
	_sealed = true
	if is_instance_valid(_courier):
		_courier.queue_free()
	_courier = null
	_label.text = message
	_cleanup_in = 3.0
	_label.visible = not message.is_empty()

func _on_wave_started(wave: int) -> void:
	if wave % 5 == 0:
		cancel()
func _on_game_over(_score: int) -> void:
	cancel()
