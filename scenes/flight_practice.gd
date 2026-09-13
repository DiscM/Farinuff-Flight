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
	player.fire_requested.connect(func(_a: Vector3, _b: Vector3): _fired = true)
	player.boost_chained.connect(_on_chain)
	xp_orb_manager.xp_orb_collected.connect(_on_practice_orb)
	_ready_for_practice = true
	if _boss_wave > 0:
		_start_boss()
	else:
		_show_step()

func _build_lesson_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = 76
	var column := VBoxContainer.new()
	panel.add_child(column)
	_lesson = Label.new()
	_lesson.custom_minimum_size = Vector2(400, 0)
	_lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lesson.add_theme_font_size_override("font_size", 18)
	column.add_child(_lesson)
	var exit_button := Button.new()
	exit_button.text = "RETURN TO FLIGHT SCHOOL"
	exit_button.pressed.connect(_leave)
	column.add_child(exit_button)
	hud.add_child(panel)

func _physics_process(delta: float) -> void:
	if not _ready_for_practice or not GameManager.is_game_active or _leaving or _boss_wave > 0:
		return
	if _step == 0 and _fired and flight_space.combat_motion_to_screen(player.global_position - _origin).length() >= 100.0:
		_step = 1
		_show_step()
	if _step in [1, 2]:
		if _step == 1 and player.boost_reflected_projectiles > 0:
			_step = 2
			_show_step()
		_volley_in -= delta
		if _volley_in <= 0.0:
			_volley_in = 1.2
			var direction := player.boost_direction if player.is_boosting else Vector3.FORWARD
			var aim := flight_space.combat_motion_to_screen(direction).normalized()
			var bounds := flight_space.get_combat_bounds()
			for index in 3:
				var origin := player.global_position + flight_space.screen_motion_to_combat(aim * 85.0 + aim.orthogonal() * (index - 1) * 20.0)
				origin.x = clampf(origin.x, bounds.position.x + 1, bounds.end.x - 1)
				origin.z = clampf(origin.z, bounds.position.y + 1, bounds.end.y - 1)
				projectile_manager.fire_enemy_projectile(origin, (player.global_position - origin).normalized(), 100.0)

func _show_step() -> void:
	_lesson.text = [
		"FLIGHT SCHOOL · 1 / 4\nMove across the combat plane, aim, and fire. Practice cannot cost a run or spend supplies.",
		"FLIGHT SCHOOL · 2 / 4\nBoost into the slow volley to reflect it. You can keep practicing after a hit.",
		"FLIGHT SCHOOL · 3 / 4\nReflect three shots in one boost. Press boost while CHAIN is lit for one follow-up, then recharge.",
		"FLIGHT SCHOOL · 4 / 4\nCollect the orbs. Each orb fills NEXT WAVE and NEXT LIFE; twelve orb value restores a life.",
		"FLIGHT SCHOOL COMPLETE\nReflection turns incoming fire into your weapon. Launch an Expedition when you are ready.",
	][_step]

func _on_chain() -> void:
	if _step != 2 or _boss_wave > 0:
		return
	_step = 3
	projectile_manager.clear_projectiles()
	for index in 6:
		xp_orb_manager.spawn_xp_orb(player.global_position + flight_space.screen_motion_to_combat(Vector2.from_angle(index * TAU / 6.0) * 70.0), 2, Vector3.ZERO)
	_show_step()

func _on_practice_orb(_value: int, _position: Vector3) -> void:
	if _step == 3 and GameManager.orbs_collected_this_wave >= 12:
		_step = 4
		_show_step()

func _start_boss() -> void:
	GameManager.current_wave = _boss_wave
	GameManager.boss_active = true
	var boss := BOSS.instantiate()
	actors_root.add_child(boss)
	register_enemy_feedback(boss)
	var bounds := flight_space.get_combat_bounds()
	boss.activate_generation(flight_space, Vector3(bounds.get_center().x, 0, bounds.position.y + bounds.size.y * 0.22), Vector3.BACK, GameManager.get_enemy_generation(_boss_wave))
	boss.finished.connect(_on_boss_finished)
	_lesson.text = "BOSS PRACTICE\nStandard loadout · no rewards · hits cannot end practice. Destroy weapon pods to reduce incoming fire."

func _on_boss_finished(_reason: int, _position: Vector3) -> void:
	projectile_manager.clear_enemy_projectiles()
	hazard_manager.clear_hazards()
	GameManager.boss_active = false
	_lesson.text = "BOSS PRACTICE COMPLETE\nOpen Pause to repeat this practice, or return to Flight School."

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	GameManager.is_game_active = false
	GameManager.return_to_flight_school = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _exit_tree() -> void:
	GameManager.practice_mode = false
	GameManager.is_game_active = false
	super._exit_tree()
