extends Native3DGameplay
## Production flight and projectiles with an isolated, non-banking session.
const BOSS := preload("res://entities/enemies/boss_enemy_3d.tscn")
var _step := 0
var _lesson: Label
var _origin := Vector3.ZERO
var _volley_in := 1.0
var _fired := false
var _ready_for_practice := false
var _boss_wave := 0
var _leaving := false
var _moved := false
var _progress: Label
var _launch_button: Button
var _lesson_panel: PanelContainer
var _volley_cue: Node2D
var _volley_origins: Array[Vector3] = []
var _volley_target := Vector3.ZERO
var _volley_warning := 0.0
var _completion_focus_pending := false
const VOLLEY_WARNING := 0.75
const VOLLEY_DISTANCE := 170.0

func _enter_tree() -> void:
	super._enter_tree()
	GameManager.practice_mode = true

func _ready() -> void:
	_boss_wave = GameManager.practice_boss_wave
	await super._ready()
	if not GameManager.is_game_active:
		return
	$HUD/FlightInstructions.hide()
	projectile_status.hide()
	_origin = player.global_position
	_build_lesson_ui()
	player.fire_requested.connect(_on_practice_fire)
	projectile_manager.enemy_projectile_deflected.connect(_on_practice_reflection)
	player.boost_chained.connect(_on_chain)
	xp_orb_manager.xp_orb_collected.connect(_on_practice_orb)
	_ready_for_practice = true
	InputBindings.bindings_changed.connect(_refresh_lesson_bindings)
	InputBindings.device_changed.connect(_refresh_lesson_bindings)
	_volley_cue = preload("res://ui/practice_volley_cue.gd").new()
	_volley_cue.flight_space = flight_space
	hud.add_child(_volley_cue)
	if _boss_wave > 0:
		_start_boss()
	else:
		GameManager.orbs_needed_this_wave = 12
		_show_step()

func _build_lesson_ui() -> void:
	var panel := PanelContainer.new()
	_lesson_panel = panel
	panel.name = "PracticeLesson"
	panel.add_to_group("scalable_ui")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = 146 if _boss_wave > 0 else 90
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 12)
	_progress.add_theme_color_override("font_color", NeonUI.CYAN)
	column.add_child(_progress)
	_lesson = Label.new()
	_lesson.custom_minimum_size = Vector2(420, 0)
	_lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lesson.add_theme_font_size_override("font_size", 16)
	column.add_child(_lesson)
	_launch_button = Button.new()
	_launch_button.text = "PREPARE EXPEDITION"
	_launch_button.pressed.connect(_prepare_expedition)
	_launch_button.hide()
	column.add_child(_launch_button)
	var exit_button := Button.new()
	exit_button.text = "RETURN TO FLIGHT SCHOOL"
	exit_button.pressed.connect(_leave)
	column.add_child(exit_button)
	hud.add_child(panel)
	get_viewport().size_changed.connect(_layout_lesson)
	get_viewport().size_changed.connect(_keep_lesson_orbs_reachable.call_deferred)
	SaveManager.settings_changed.connect(_layout_lesson)
	panel.minimum_size_changed.connect(_layout_lesson)
	_layout_lesson.call_deferred()

func _layout_lesson() -> void:
	if not is_instance_valid(_lesson_panel):
		return
	var header := hud.get_node("CombatHeader") as Control
	var top := header.position.y + header.size.y * header.scale.y + 8.0
	if _boss_wave > 0:
		top = maxf(top, 146.0)
	_lesson_panel.offset_top = top
	_lesson_panel.offset_bottom = top + _lesson_panel.get_combined_minimum_size().y

func _physics_process(delta: float) -> void:
	if _completion_focus_pending and not Input.is_action_pressed("shoot") and not Input.is_action_pressed("ui_accept"):
		_completion_focus_pending = false
		_launch_button.disabled = false
		_launch_button.grab_focus()
	if not _ready_for_practice or not GameManager.is_game_active or _leaving or _boss_wave > 0:
		return
	if _step == 0:
		_moved = _moved or flight_space.combat_motion_to_screen(player.global_position - _origin).length() >= 100.0
		if _fired and _moved:
			_step = 1
		_show_step()
	if _step in [1, 2]:
		_show_step()
		if _volley_warning > 0.0:
			_volley_warning = maxf(0.0, _volley_warning - delta)
			_volley_cue.remaining = _volley_warning
			if _volley_warning <= 0.0:
				for origin in _volley_origins:
					projectile_manager.fire_enemy_projectile(origin, (_volley_target - origin).normalized(), 100.0)
			return
		_volley_in -= delta
		if _volley_in <= 0.0:
			_volley_in = 2.0
			_prepare_volley()

func _prepare_volley() -> void:
	_volley_target = player.global_position
	var bounds := flight_space.get_combat_bounds(-24.0)
	# Approach from the open side of the field, clear of the lesson above the ship.
	var direction := Vector2.RIGHT if _volley_target.x <= bounds.get_center().x else Vector2.LEFT
	var test_origin := _volley_target + flight_space.screen_motion_to_combat(direction * VOLLEY_DISTANCE)
	if not bounds.has_point(Vector2(test_origin.x, test_origin.z)):
		var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
		direction = flight_space.combat_motion_to_screen(center - _volley_target).normalized()
	_volley_origins.clear()
	for index in 3:
		var origin := _volley_target + flight_space.screen_motion_to_combat(direction * VOLLEY_DISTANCE + direction.orthogonal() * (index - 1) * 16.0)
		origin.x = clampf(origin.x, bounds.position.x, bounds.end.x)
		origin.z = clampf(origin.z, bounds.position.y, bounds.end.y)
		_volley_origins.append(origin)
	_volley_warning = VOLLEY_WARNING
	_volley_cue.origins = _volley_origins.duplicate()
	_volley_cue.target = _volley_target
	_volley_cue.remaining = _volley_warning
	_volley_cue.queue_redraw()

func _on_practice_fire(_position: Vector3, _direction: Vector3) -> void:
	_fired = true

func _on_practice_reflection(_projectile: Area3D, _position: Vector3) -> void:
	if _step == 1 and _boss_wave == 0:
		_step = 2
		_show_step()

func _show_step() -> void:
	_progress.text = "MOVE + FIRE  %s  REFLECT  %s  CHAIN  %s  COLLECT" % ["✓" if _step > 0 else "·", "✓" if _step > 1 else "·", "✓" if _step > 2 else "·"]
	var chain_ready := bool(player.get_boost_state().chain_ready)
	_progress.modulate = NeonUI.GREEN if _step == 4 else Color.WHITE
	_lesson.text = [
		"MOVE %s   FIRE %s\nMove around · Hold %s to fire.\nAim with the mouse or right stick." % ["✓" if _moved else "○", "✓" if _fired else "○", InputBindings.binding_hint("shoot")],
		"BOOST INTO THE INCOMING SHOTS\nMove toward the markers, then hold %s.\nHits cannot end practice." % InputBindings.binding_hint("boost"),
		("CHAIN READY · PRESS %s AGAIN!" % InputBindings.binding_hint("boost") if chain_ready else "REFLECT %d / 3 WHILE BOOSTING" % mini(player.boost_reflected_projectiles, 3)) + "\nReflecting refunds the boost meter.\nThe follow-up press bursts the bar back up.",
		"CHAIN COMPLETE · COLLECT THE ORBS\nFly through the glowing orbs: %d / 12.\nOrb points advance waves and restore lives." % mini(GameManager.orbs_collected_this_wave, 12),
		"FLIGHT SCHOOL COMPLETE\nYou can move, reflect, chain, and recover.\nChoose your ship when you are ready.",
		][_step]
	_lesson.modulate = NeonUI.YELLOW if chain_ready and _step == 2 else Color.WHITE
	if _step in [1, 2] and _volley_warning > 0.0 and not chain_ready:
		_lesson.text = "VOLLEY CHARGING · WAIT FOR THE SHOTS\nThen move into the volley and hold %s.\n%s" % [InputBindings.binding_hint("boost"), "Reflect all 3 to refill the meter." if _step == 2 else "Hits cannot end practice."]
	_launch_button.visible = _step == 4

func _refresh_lesson_bindings() -> void:
	if _ready_for_practice and _boss_wave == 0:
		_show_step()

func _on_chain() -> void:
	if _step != 2 or _boss_wave > 0:
		return
	_step = 3
	_volley_warning = 0.0
	_volley_cue.remaining = 0.0
	projectile_manager.clear_projectiles()
	var bounds := flight_space.get_combat_bounds(-32.0)
	for index in 6:
		var point := player.global_position + flight_space.screen_motion_to_combat(Vector2.from_angle(index * TAU / 6.0) * 70.0)
		point.x = clampf(point.x, bounds.position.x, bounds.end.x)
		point.z = clampf(point.z, bounds.position.y, bounds.end.y)
		var orb := xp_orb_manager.spawn_xp_orb(point, 2, Vector3.ZERO)
		if orb != null:
			# Lessons wait for the pilot: supplies cannot drift away or expire.
			orb.drift_speed_pixels = 0.0
			orb.bob_amplitude_pixels = 0.0
			orb.remaining_lifetime = INF
	_show_step()

func _on_practice_orb(_value: int, _position: Vector3) -> void:
	if _step == 3 and GameManager.orbs_collected_this_wave >= 12:
		_step = 4
		_offer_expedition()
	if _step in [3, 4]:
		_show_step()

func _keep_lesson_orbs_reachable() -> void:
	if _step != 3 or _boss_wave > 0:
		return
	var bounds := flight_space.get_combat_bounds(-32.0)
	for orb in get_tree().get_nodes_in_group("xp_orbs"):
		orb.global_position.x = clampf(orb.global_position.x, bounds.position.x, bounds.end.x)
		orb.global_position.z = clampf(orb.global_position.z, bounds.position.y, bounds.end.y)

func _offer_expedition() -> void:
	_launch_button.show()
	_launch_button.disabled = true
	_completion_focus_pending = true

func _start_boss() -> void:
	GameManager.current_wave = _boss_wave
	GameManager.boss_active = true
	var boss := BOSS.instantiate()
	actors_root.add_child(boss)
	register_enemy_feedback(boss)
	var bounds := flight_space.get_combat_bounds()
	boss.activate_generation(flight_space, Vector3(bounds.get_center().x, 0, bounds.position.y + bounds.size.y * 0.22), Vector3.BACK, GameManager.get_enemy_generation(_boss_wave))
	boss.finished.connect(_on_boss_finished)
	_lesson.text = "BOSS PRACTICE\nBase ship · No upgrades\nHits cannot end practice.\nDestroy weapon pods to reduce boss fire."
	_progress.text = "BOSS PRACTICE · NO SUPPLIES USED"

func _on_boss_finished(_reason: int, _position: Vector3) -> void:
	projectile_manager.clear_enemy_projectiles()
	hazard_manager.clear_hazards()
	GameManager.boss_active = false
	_lesson.text = "BOSS PRACTICE COMPLETE\nPause → Restart or Flight School"
	_offer_expedition()

func _prepare_expedition() -> void:
	if _leaving:
		return
	GameManager.return_to_launch_bay = true
	_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	GameManager.is_game_active = false
	GameManager.return_to_flight_school = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/home_base.tscn")

func _exit_tree() -> void:
	GameManager.practice_mode = false
	GameManager.is_game_active = false
	super._exit_tree()
