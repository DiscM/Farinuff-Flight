extends Node
## Boot is a flyable world; explicit practice returns reopen the matching service.
const HOME := preload("res://scenes/home_base.tscn")
const LEGACY_REDIRECT := preload("res://ui/main_menu.tscn")
var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/home_base.tscn", "Production starts directly in the home port")
	var legacy := LEGACY_REDIRECT.instantiate()
	_expect(legacy.get_child_count() == 0 and not legacy is Control, "The deprecated menu contains only a redirect, with no old interface")
	legacy.free()
	var seen := SaveManager.has_seen_flight_school
	var return_to_school := GameManager.return_to_flight_school
	var return_to_bay := GameManager.return_to_launch_bay
	for mode in ["returning", "first_flight", "practice_return", "practice_launch"]:
		SaveManager.has_seen_flight_school = mode != "first_flight"
		GameManager.return_to_flight_school = mode == "practice_return"
		GameManager.return_to_launch_bay = mode == "practice_launch"
		var home := HOME.instantiate()
		add_child(home)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(home.player != null and home.station != null and home.camera != null, "Flyable home world mounts for " + mode)
		_expect(home.get_node_or_null("CommandDeckShell") == null, "The retired command deck never mounts on boot")
		_expect(not GameManager.is_game_active and not GameManager.practice_mode, "Menu flight never starts a run")
		var services: Node = home._services
		_expect(services != null, "Local station services are available")
		if services != null:
			var expected: StringName = &""
			if mode == "practice_return":
				expected = &"flight_school"
			elif mode == "practice_launch":
				expected = &"launch_bay"
			_expect(services.get_current_page_id() == expected, "Correct local service for " + mode)
			_expect(services.is_open() == (expected != &""), "Only explicit practice returns open a service on boot")
			if services.is_open():
				_expect(services.frontend.get_current_page().is_visible_in_tree(), "Returned service is visible")
		_expect(not GameManager.return_to_launch_bay and not GameManager.return_to_flight_school, "Practice return requests are consumed on boot")
		home.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
	# Old shortcuts still enter the new world, with no intervening command deck.
	var shortcut := LEGACY_REDIRECT.instantiate()
	get_tree().root.add_child(shortcut)
	get_tree().current_scene = shortcut
	for frame in range(600):
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == "res://scenes/home_base.tscn":
			break
	var redirected_home := get_tree().current_scene
	_expect(redirected_home != null and redirected_home.scene_file_path == "res://scenes/home_base.tscn", "Legacy menu shortcuts redirect to the flyable port")
	get_tree().current_scene = self
	if is_instance_valid(redirected_home) and redirected_home != self:
		redirected_home.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	SaveManager.has_seen_flight_school = seen
	GameManager.return_to_flight_school = return_to_school
	GameManager.return_to_launch_bay = return_to_bay
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("MENU_BOOT_SMOKE_PASS flyable home port startup; explicit practice service returns preserved")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
