extends Native3DGameplay
## Real bound input events must survive the event that changes input family.
var _failures: Array[String] = []
var _shots := 0

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	var disk_snapshot := preload("res://tests/save_file_snapshot.gd").new()
	player.set_physics_process(false)
	player.fire_requested.connect(func(_position: Vector3, _direction: Vector3): _shots += 1)
	for toggle in [false, true]:
		SaveManager.update_setting("toggle_fire", toggle)
		for binding in [["gamepad", 0], ["gamepad", 1], ["keyboard", 0]]:
			var family := str(binding[0])
			await _neutral()
			InputBindings.family = "keyboard" if family == "gamepad" else "gamepad"
			var before := _shots
			_send("shoot", family, true, binding[1])
			player._update_shooting()
			_expect(InputBindings.family == family, "Real fire event changes to " + family)
			_expect(_shots == before + 1, "First %s fire press works (toggle=%s)" % [family, toggle])
			_expect(player._fire_latched == toggle, "Toggle fire keeps the first intentional press")
			_send("shoot", family, false, binding[1])
	for binding in [["gamepad", 0], ["gamepad", 1], ["keyboard", 0]]:
		var family := str(binding[0])
		await _neutral()
		InputBindings.family = "keyboard" if family == "gamepad" else "gamepad"
		_send("boost", family, true, binding[1])
		player._update_boost(0.01)
		_expect(InputBindings.family == family, "Real boost event changes to " + family)
		_expect(player.is_boosting, "First %s boost press works" % family)
		_send("boost", family, false, binding[1])
	await _check_old_device_release()
	await _check_held_input_guards()
	await _neutral()
	disk_snapshot.restore()
	# The boot cache loads on a worker. Let it finish before engine shutdown so
	# a successful short input test cannot cancel resource parsing midway.
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("INPUT_HANDOFF_SMOKE_PASS" if _failures.is_empty() else "INPUT_HANDOFF_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_old_device_release() -> void:
	await _neutral()
	SaveManager.update_setting("toggle_fire", true)
	_send("move_right", "keyboard", true)
	_send("shoot", "gamepad", true)
	player._update_shooting()
	_send("move_right", "keyboard", false)
	_expect(InputBindings.family == "gamepad" and player._fire_latched, "Old keyboard release cannot steal controller focus or stop toggle fire")
	_send("shoot", "gamepad", false)
	await _neutral()
	_send("boost", "gamepad", true)
	_send("shoot", "keyboard", true)
	player._update_shooting()
	_send("boost", "gamepad", false)
	_expect(InputBindings.family == "keyboard" and player._fire_latched, "Old controller release cannot steal keyboard focus or stop toggle fire")
	_send("shoot", "keyboard", false)

func _check_held_input_guards() -> void:
	await _neutral()
	SaveManager.update_setting("toggle_fire", true)
	InputBindings.family = "keyboard"
	_send("shoot", "keyboard", true)
	player._update_shooting()
	await get_tree().process_frame
	await get_tree().process_frame
	# A different device's movement must not carry across old automatic fire.
	_send("move_right", "gamepad", true)
	player.shoot_timer.stop()
	var before := _shots
	player._update_shooting()
	_expect(not player._fire_latched and _shots == before, "Device handoff clears old latched and held fire")
	_send("move_right", "gamepad", false)
	_send("shoot", "keyboard", false)
	await _neutral()
	SaveManager.update_setting("toggle_fire", false)
	for guard in ["pause", "remap"]:
		InputBindings.family = "keyboard"
		_send("shoot", "keyboard", true)
		_send("boost", "keyboard", true)
		if guard == "pause":
			get_tree().paused = true
			get_tree().paused = false
		else:
			InputBindings.apply_bindings()
		before = _shots
		player._update_shooting()
		player._update_boost(0.01)
		_expect(_shots == before and not player.is_boosting, "%s still requires held actions to be released" % guard)
		_send("shoot", "keyboard", false)
		_send("boost", "keyboard", false)
		await _neutral()

func _neutral() -> void:
	for action in ["shoot", "boost", "move_right"]:
		for family in ["keyboard", "gamepad"]:
			_send(action, family, false)
		Input.action_release(action)
	player.reset_action_input()
	player.shoot_timer.stop()
	player.is_boosting = false
	player.boost_cooldown_timer = 0.0
	player.boost_chain_window_timer = 0.0
	player.boost_reflected_projectiles = 0
	player._chain_followup = false
	player._update_shooting()
	player._update_boost(0.01)
	await get_tree().process_frame
	await get_tree().process_frame

func _send(action: String, family: String, pressed: bool, binding_index: int = 0) -> void:
	var event: InputEvent = InputBindings.events_for(action, family)[binding_index].duplicate()
	if event is InputEventJoypadMotion:
		if not pressed:
			event.axis_value = 0.0
	else:
		event.pressed = pressed
	if family == "gamepad":
		event.device = 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
