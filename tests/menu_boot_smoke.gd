extends Node
## The boot scene never instantiates legacy UI, including before its first draw.
const MENU := preload("res://ui/main_menu.tscn")
var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var seen := SaveManager.has_seen_flight_school
	var return_to_school := GameManager.return_to_flight_school
	for mode in ["returning", "first_flight", "practice_return"]:
		SaveManager.has_seen_flight_school = mode != "first_flight"
		GameManager.return_to_flight_school = mode == "practice_return"
		var menu := MENU.instantiate()
		_expect(menu.get_node_or_null("CabinetLayout") == null, "Legacy title controls must not be instantiated")
		_expect(menu.get_node_or_null("ShipStage") == null, "Legacy ship intro must not be instantiated")
		add_child(menu)
		var shell := menu.get_node_or_null("CommandDeckShell") as FrontendShell
		_expect(shell != null, "New frontend must mount synchronously during ready")
		await get_tree().process_frame
		await get_tree().process_frame
		if shell != null:
			var expected: StringName = &"command_deck" if mode == "returning" else &"flight_school"
			_expect(shell.get_current_page_id() == expected, "Correct initial page for " + mode)
			_expect(shell.get_current_page().is_visible_in_tree(), "Initial page must be visible")
		menu.queue_free()
		await get_tree().process_frame
	SaveManager.has_seen_flight_school = seen
	GameManager.return_to_flight_school = return_to_school
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("MENU_BOOT_SMOKE_PASS: direct frontend startup; first-flight and practice routing preserved")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
