extends Node
## Opt-in local playtest timing. No network, account identifiers, or save writes.
## Launch with -- --opening-metrics; stdout records can be kept with the build.

const PREFIX := "OPENING_METRICS "
var _started_at := 0
var _active_seconds := 0.0
var _seen: Dictionary = {}
var _session := ""
var _gameplay: Node
var _origin := Vector3.ZERO
var _developer_assisted := false
var _wave_started_at := 0.0
var _wave_baseline: Dictionary = {}
var _installed: Dictionary = {}
var _boss_started_at := 0.0
var _boss_wave := 0

func start(gameplay: Node) -> void:
	_gameplay = gameplay
	_origin = gameplay.player.global_position
	_started_at = Time.get_ticks_msec()
	_session = "%d-%d" % [int(Time.get_unix_time_from_system()), _started_at]
	process_mode = Node.PROCESS_MODE_ALWAYS
	gameplay.player.fire_requested.connect(func(_position: Vector3, _direction: Vector3): _once("first_shot"))
	gameplay.projectile_manager.enemy_projectile_deflected.connect(func(_projectile: Area3D, _position: Vector3): _once("first_reflection"))
	gameplay.projectile_manager.deflected_projectile_hit.connect(func(_target: Area3D, _position: Vector3): _once("first_reflected_hit"))
	SignalBus.wave_started.connect(_record_wave_started)
	SignalBus.wave_cleared.connect(func(wave: int): _record("wave_completed", wave_detail(wave)))
	SignalBus.elite_offers_presented.connect(func(ids: Array[String]): _record("upgrade_offered", {"choices": ids, "installed": GameManager.get_owned_elite_ids()}))
	SignalBus.boss_spawned.connect(_record_boss_started)
	SignalBus.boss_died.connect(_record_boss_completed)
	SignalBus.elite_upgrade_triggered.connect(func(): _once("first_upgrade_offered"))
	SignalBus.game_over.connect(func(_score: int):
		var detail := wave_detail(GameManager.current_wave)
		detail["last_damage_source"] = GameManager.run_insights.last_damage_source
		_record("defeat", detail))
	_record("run_started", {
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"practice": gameplay.practice_session,
		"hull": MetaProgression.DEFAULT_SHIP if gameplay.practice_session else MetaProgression.selected_ship,
		"modifiers": [] if gameplay.practice_session else MetaProgression.active_modifiers.duplicate(),
		"starting_lives": GameManager.starting_lives,
		"starting_speed_bonus": GameManager.meta_speed_pct + GameManager.ship_speed_pct,
		"starting_fire_rate_bonus": GameManager.meta_fire_rate_pct + GameManager.ship_fire_rate_pct,
	})
	# start_game emits the first wave before the prepared scene attaches us.
	_record_wave_started(GameManager.current_wave)

func _process(delta: float) -> void:
	if _gameplay == null:
		return
	_developer_assisted = _developer_assisted or _gameplay.player.dev_god_mode or GameManager.dev_enemy_generation_override > 0
	if GameManager.is_game_active and not get_tree().paused:
		_active_seconds += delta
		var displacement: Vector3 = _gameplay.player.global_position - _origin
		if _gameplay.flight_space.combat_motion_to_screen(displacement).length() >= 100.0:
			_once("first_movement")
	# Installation commits while the reward overlay pauses gameplay.
	for upgrade: String in GameManager.chosen_upgrade_ids:
		if not _installed.has(upgrade):
			_installed[upgrade] = true
			_once("first_upgrade_installed", {"upgrade": upgrade})
			_record("upgrade_installed", {"upgrade": upgrade, "wave": GameManager.current_wave})

func _record_wave_started(wave: int) -> void:
	_wave_started_at = _active_seconds
	_wave_baseline = GameManager.run_insights.counters()
	_record("wave_started", {"wave": wave})

func wave_detail(wave: int) -> Dictionary:
	var detail := {"wave": wave, "wave_active_seconds": snappedf(_active_seconds - _wave_started_at, 0.01),
		"build": GameManager.get_owned_elite_ids()}
	var counters := GameManager.run_insights.counters()
	for key: String in counters:
		detail[key] = int(counters[key]) - int(_wave_baseline.get(key, 0))
	return detail

func _record_boss_started(_health: int, _max_health: int, boss: String) -> void:
	_boss_started_at = _active_seconds
	_boss_wave = GameManager.current_wave
	_record("boss_spawned", {"boss": boss, "wave": _boss_wave})

func _record_boss_completed(_points: int) -> void:
	_once("first_boss_defeated")
	_record("boss_completed", {"wave": _boss_wave, "boss_active_seconds": snappedf(_active_seconds - _boss_started_at, 0.01)})

func _once(event: String, detail: Dictionary = {}) -> void:
	if _seen.has(event):
		return
	_seen[event] = true
	_record(event, detail)

func _record(event: String, detail: Dictionary = {}) -> void:
	if is_instance_valid(_gameplay) and is_instance_valid(_gameplay.player):
		_developer_assisted = _developer_assisted or _gameplay.player.dev_god_mode or GameManager.dev_enemy_generation_override > 0
	var record := detail.duplicate()
	record.merge({
		"schema": 2,
		"session": _session,
		"event": event,
		"wall_seconds": snappedf((Time.get_ticks_msec() - _started_at) / 1000.0, 0.01),
		"active_seconds": snappedf(_active_seconds, 0.01),
		"developer_assisted": _developer_assisted,
		"time_scale": Engine.time_scale,
	}, true)
	print(PREFIX + JSON.stringify(record))

func _exit_tree() -> void:
	if not _session.is_empty():
		_record("run_closed", wave_detail(GameManager.current_wave))
