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

func start(gameplay: Node) -> void:
	_gameplay = gameplay
	_origin = gameplay.player.global_position
	_started_at = Time.get_ticks_msec()
	_session = "%d-%d" % [int(Time.get_unix_time_from_system()), _started_at]
	process_mode = Node.PROCESS_MODE_ALWAYS
	gameplay.player.fire_requested.connect(func(_position: Vector3, _direction: Vector3): _once("first_shot"))
	gameplay.projectile_manager.enemy_projectile_deflected.connect(func(_projectile: Area3D, _position: Vector3): _once("first_reflection"))
	gameplay.projectile_manager.deflected_projectile_hit.connect(func(_target: Area3D, _position: Vector3): _once("first_reflected_hit"))
	SignalBus.wave_started.connect(func(wave: int): _record("wave_started", {"wave": wave}))
	SignalBus.boss_spawned.connect(func(_health: int, _max_health: int, boss: String): _record("boss_spawned", {"boss": boss}))
	SignalBus.boss_died.connect(func(_points: int): _once("first_boss_defeated"))
	SignalBus.elite_upgrade_triggered.connect(func(): _once("first_upgrade_offered"))
	SignalBus.game_over.connect(func(_score: int): _record("defeat"))
	_record("run_started", {
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"practice": gameplay.practice_session,
		"hull": MetaProgression.DEFAULT_SHIP if gameplay.practice_session else MetaProgression.selected_ship,
		"modifiers": [] if gameplay.practice_session else MetaProgression.active_modifiers.duplicate(),
	})
	# start_game emits the first wave before the prepared scene attaches us.
	_record("wave_started", {"wave": GameManager.current_wave})

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
	if not GameManager.chosen_upgrade_ids.is_empty():
		_once("first_upgrade_installed", {"upgrade": GameManager.chosen_upgrade_ids[0]})

func _once(event: String, detail: Dictionary = {}) -> void:
	if _seen.has(event):
		return
	_seen[event] = true
	_record(event, detail)

func _record(event: String, detail: Dictionary = {}) -> void:
	var record := detail.duplicate()
	record.merge({
		"schema": 1,
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
		_record("run_closed")
