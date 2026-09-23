extends Node
## Homeport is the start screen: sections guide flight and require local access.

const HUD := preload("res://ui/home_base_hud.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	# Let the shared boot preload finish before this short UI-only test exits.
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	var previous_scale: Variant = SaveManager.settings.get("menu_text_scale", 1.0)
	SaveManager.settings["menu_text_scale"] = 1.3
	var old_family := InputBindings.family
	var original_bindings := SaveManager.control_bindings.duplicate(true)
	InputBindings.family = "keyboard"
	var hud := HUD.new()
	add_child(hud)
	await _settle()
	var destinations: Array = [
		{"id": &"launch_bay", "title": "Launch Bay", "description": "Prepare your ship and begin an expedition.", "color": Color(1.0, 0.8, 0.25), "distance": 60.0},
		{"id": &"hangar", "title": "Hangar", "description": "Upgrade permanent systems and restock your supplies.", "color": Color(0.35, 0.9, 0.95), "distance": 80.0},
		{"id": &"flight_school", "title": "Flight School", "description": "Learn to fly, reflect projectiles, and master combat.", "color": Color(0.4, 0.9, 0.65), "distance": 30.0, "selected": true},
		{"id": &"route_map", "title": "Route Map", "description": "Explore sectors and plan your next route.", "color": Color(0.65, 0.65, 1.0), "distance": 100.0},
		{"id": &"archives", "title": "Archives", "description": "Review pilot records and discoveries.", "color": Color(0.95, 0.6, 0.45), "distance": 150.0},
		{"id": &"settings", "title": "Settings", "description": "Tune audio, visuals, accessibility, and controls.", "color": Color(0.8, 0.85, 0.9), "distance": 120.0},
	]
	var received := {"interactions": 0, "selected": &"", "quit": false}
	hud.interact_requested.connect(func(): received.interactions += 1)
	hud.section_selected.connect(func(id: StringName): received.selected = id)
	hud.quit_requested.connect(func(): received.quit = true)
	hud.set_sections_status(destinations)
	await _settle()
	_expect(hud._section_buttons.size() == 6, "Directory must list every station service")
	_expect(not hud._context_panel.visible, "No section should expose a context panel before a destination is supplied")
	var school_button := hud._section_buttons[&"flight_school"] as Button
	_expect(school_button.text.begins_with("›") and school_button.get_theme_color("font_color") == destinations[2].color, "Chosen waypoint must have a marker and its section color")
	(hud._section_buttons[&"hangar"] as Button).pressed.emit()
	_expect(received.selected == &"hangar" and received.interactions == 0, "Directory selects a waypoint without opening services remotely")
	_expect(get_viewport().gui_get_focus_owner() == null, "Selecting a waypoint must return control to the ship")
	hud.set_active_section(destinations[1], 70.0, false)
	_expect(school_button.text.begins_with("›") and school_button.get_theme_color("font_color") == destinations[2].color, "Nearby section changes must preserve the selected waypoint highlight")
	_expect((hud._section_buttons[&"hangar"] as Button).get_theme_color("font_color") == hud.MUTED and hud._section_label.text == "HANGAR", "Nearby service uses the context card independently of waypoint selection")
	(hud._interact_button as Button).pressed.emit()
	_expect(hud._interact_button.disabled and received.interactions == 0, "Out-of-range sections cannot be accessed by the HUD")
	_expect(hud._range_label.text.contains("70 m"), "Approach panel must report destination distance")
	hud.set_active_section(destinations[1], 8.0, true)
	(hud._interact_button as Button).pressed.emit()
	_expect(received.interactions == 1, "Nearby interaction must request the local service immediately")
	hud.focus_primary()
	_expect(hud._interact_button.has_focus(), "Nearby section's primary action must be Interact")
	hud.set_menu_open(true)
	await _settle()
	_expect(hud._resume_button.has_focus(), "Pause must focus Resume")
	_expect(not hud._context_panel.visible and not hud._directory_panel.visible, "Pause must conceal underlying section controls")
	_expect(hud._menu_button.focus_mode == Control.FOCUS_NONE, "Pause must remove the underlying pause button from focus")
	for button: Button in hud._section_buttons.values():
		_expect(button.focus_mode == Control.FOCUS_NONE and button.disabled, "Pause must isolate destination navigation focus")
	(hud._interact_button as Button).pressed.emit()
	_expect(received.interactions == 1, "Paused interaction must not open a service")
	(hud._quit_button as Button).pressed.emit()
	_expect(received.quit, "Pause must expose Quit Game intent")
	_expect(hud.find_child("ReturnButton", true, false) == null, "Deprecated Return to Menu action must be absent")
	hud.set_menu_open(false)
	await _settle()
	_expect(get_viewport().gui_get_focus_owner() == null, "Resume must release GUI focus so flight can continue")
	hud.focus_primary()
	hud.set_active_section(destinations[1], 30.0, false)
	_expect(get_viewport().gui_get_focus_owner() == null, "Leaving service range must clear interaction focus")
	InputBindings.family = "gamepad"
	InputBindings.device_changed.emit()
	_expect(hud._movement_label.text.contains("L-stick"), "Flight prompts must react to controller handoff")
	_expect(hud.get_service_hint() == "A / Cross to interact", "Controller must expose the immediate service interaction")
	InputBindings.family = "keyboard"
	InputBindings.device_changed.emit()
	_expect(hud.get_service_hint() == "E to interact", "Keyboard service interaction must prefer E")
	_expect(hud._boost_label.text.contains(InputBindings.binding_hint("boost")), "Flight prompts must show the active boost binding")
	SaveManager.control_bindings = {"boost": {"gamepad": [{"kind": "button", "code": JOY_BUTTON_A}], "keyboard": [{"kind": "key", "code": KEY_E}]}}
	InputBindings.apply_bindings()
	InputBindings.family = "gamepad"
	InputBindings.device_changed.emit()
	_expect(hud.get_service_hint() == "X / Square to interact", "Boost on A must preserve a controller interaction shortcut")
	InputBindings.family = "keyboard"
	InputBindings.device_changed.emit()
	_expect(hud.get_service_hint() == "F to interact", "Boost on E must preserve a keyboard interaction shortcut")
	SaveManager.control_bindings = {"boost": {"gamepad": [{"kind": "button", "code": JOY_BUTTON_LEFT_SHOULDER}]}}
	InputBindings.family = "gamepad"
	InputBindings.apply_bindings()
	_expect(hud._zoom_label.text == "ZOOM IN  RB", "Boost on LB must remove the conflicting zoom prompt")
	SaveManager.control_bindings["move_right"] = {"gamepad": [{"kind": "button", "code": JOY_BUTTON_RIGHT_SHOULDER}]}
	InputBindings.apply_bindings()
	_expect(not hud._zoom_label.visible, "Reserved shoulder buttons must hide unavailable controller zoom")
	SaveManager.control_bindings = original_bindings
	InputBindings.apply_bindings()
	var viewport_rect := get_viewport().get_visible_rect().grow(1)
	for family: String in ["keyboard", "gamepad"]:
		InputBindings.family = family
		InputBindings.device_changed.emit()
		hud.set_navigation_hint("New pilot? Visit Flight School to learn flight and reflection.")
		for section: Dictionary in destinations:
			hud.set_active_section(section, 6.0, true)
			await _settle()
			for control: Control in [hud._menu_button, hud._movement_label, hud._boost_label, hud._navigation_label, hud._directory_panel, hud._context_panel, hud._interact_button]:
				_expect(viewport_rect.encloses(control.get_global_rect()), "130% homeport UI must fit the viewport: " + control.name)
			_expect(not hud._movement_label.get_global_rect().intersects(hud._context_panel.get_global_rect()), "Flight instructions and destination context must not overlap")
			_expect(not hud._directory_panel.get_global_rect().intersects(hud._context_panel.get_global_rect()), "Destination directory and interaction panel must not overlap")
	var old_button := hud._section_buttons[&"archives"] as Button
	destinations[2]["selected"] = false
	destinations[0]["selected"] = true
	hud.set_sections_status(destinations)
	_expect(not school_button.text.begins_with("›") and school_button.get_theme_color("font_color") == hud.MUTED, "Changing the waypoint must clear its previous marker and highlight")
	_expect((hud._section_buttons[&"launch_bay"] as Button).text.begins_with("›"), "Changing the waypoint must mark the new destination")
	hud.set_sections_status([destinations[0]])
	await _settle()
	_expect(hud._section_buttons.size() == 1 and not is_instance_valid(old_button), "Directory refresh must remove obsolete waypoints")
	InputBindings.family = old_family
	SaveManager.settings["menu_text_scale"] = previous_scale
	InputBindings.apply_bindings()
	hud.queue_free()
	await _settle()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("HOME_BASE_UI_SMOKE_PASS six destinations, local interaction, wayfinding, pause focus, quit intent, remapped controls, 130% layout")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _settle() -> void:
	for _frame in 5:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
