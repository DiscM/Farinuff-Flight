extends Node
## Owns gameplay bindings without changing the menu navigation safety keys.
signal bindings_changed
signal device_changed

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "shoot", "boost", "pause"]
const TITLES := ["Move left", "Move right", "Move up", "Move down", "Fire", "Boost / reflect", "Pause"]
var family := "keyboard"
var active_gamepad := 0
var _defaults: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in ACTIONS:
		var config: Dictionary = ProjectSettings.get_setting("input/" + action, {})
		_defaults[action] = config.get("events", []).duplicate(true)
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	_defaults["pause"] = [escape, start]
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		active_gamepad = pads[0]
	apply_bindings()

func _input(event: InputEvent) -> void:
	var next := family
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		active_gamepad = event.device
		next = "gamepad"
	elif event is InputEventKey or event is InputEventMouseButton:
		next = "keyboard"
	if next != family:
		family = next
		device_changed.emit()

func apply_bindings() -> void:
	if _defaults.is_empty():
		return
	for action: String in ACTIONS:
		InputMap.action_erase_events(action)
		for device_family: String in ["keyboard", "gamepad"]:
			for event: InputEvent in events_for(action, device_family):
				var binding: InputEvent = event.duplicate()
				if device_family == "gamepad":
					binding.device = -1
				InputMap.action_add_event(action, binding)
	bindings_changed.emit()

func events_for(action: String, device_family: String) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var overrides: Dictionary = SaveManager.control_bindings.get(action, {})
	if overrides.get(device_family) is Array:
		for encoded: Variant in overrides[device_family]:
			if encoded is Dictionary:
				var decoded := decode(encoded)
				if decoded != null and event_family(decoded) == device_family:
					result.append(decoded)
		if not result.is_empty():
			return result
	if device_family == "keyboard" and bool(SaveManager.get_setting("alt_controls", false)) and action in ["shoot", "boost"]:
		return [decode({"kind": "mouse", "code": MOUSE_BUTTON_LEFT})] if action == "shoot" else [decode({"kind": "key", "code": KEY_SPACE})]
	for event: InputEvent in _defaults.get(action, []):
		if event_family(event) == device_family:
			result.append(event)
	return result

func event_family(event: InputEvent) -> String:
	return "gamepad" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard"

func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"kind": "key", "code": event.physical_keycode if event.physical_keycode != 0 else event.keycode}
	if event is InputEventMouseButton:
		return {"kind": "mouse", "code": event.button_index}
	if event is InputEventJoypadButton:
		return {"kind": "button", "code": event.button_index}
	if event is InputEventJoypadMotion:
		return {"kind": "axis", "code": event.axis, "direction": -1 if event.axis_value < 0 else 1}
	return {}

func decode(data: Dictionary) -> InputEvent:
	var code := int(data.get("code", -1))
	if code < 0:
		return null
	match str(data.get("kind", "")):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = code
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = code
			return event
		"button":
			var event := InputEventJoypadButton.new()
			event.button_index = code
			return event
		"axis":
			var event := InputEventJoypadMotion.new()
			event.axis = code
			event.axis_value = -1.0 if int(data.get("direction", 1)) < 0 else 1.0
			return event
	return null

func conflicts(action: String, event: InputEvent) -> Array[String]:
	var result: Array[String] = []
	for other: String in ACTIONS:
		if other == action:
			continue
		for existing: InputEvent in events_for(other, event_family(event)):
			if encode(existing) == encode(event):
				result.append(other)
				break
	return result

func assign(action: String, event: InputEvent, swap: bool = false) -> bool:
	var collisions := conflicts(action, event)
	if not collisions.is_empty() and (not swap or collisions.size() != 1):
		return false
	var device_family := event_family(event)
	var updated := SaveManager.control_bindings.duplicate(true)
	if not collisions.is_empty():
		# Exchange complete device bindings so neither action becomes unreachable.
		var previous: Array = []
		for old_event: InputEvent in events_for(action, device_family):
			previous.append(encode(old_event))
		var other: String = collisions[0]
		var other_bindings: Dictionary = updated.get(other, {}).duplicate(true)
		other_bindings[device_family] = previous
		updated[other] = other_bindings
	var action_bindings: Dictionary = updated.get(action, {}).duplicate(true)
	action_bindings[device_family] = [encode(event)]
	updated[action] = action_bindings
	SaveManager.save_control_bindings(updated)
	apply_bindings()
	return true

func restore_defaults(alternate: bool = false) -> void:
	SaveManager.save_control_bindings({})
	SaveManager.update_setting("alt_controls", alternate)
	apply_bindings()

func binding_label(action: String, device_family: String = "") -> String:
	var labels := PackedStringArray()
	for event: InputEvent in events_for(action, family if device_family.is_empty() else device_family):
		labels.append(event_label(event))
	return " / ".join(labels)


func binding_hint(action: String) -> String:
	var events := events_for(action, family)
	return event_label(events[0]) if not events.is_empty() else action.capitalize()

func event_label(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var names := ["South (A / Cross)", "East (B / Circle)", "West (X / Square)", "North (Y / Triangle)", "Back / Select", "Guide", "Start / Options", "Left stick click", "Right stick click", "Left bumper", "Right bumper", "D-pad up", "D-pad down", "D-pad left", "D-pad right"]
		if event.button_index >= 0 and event.button_index < names.size():
			return names[event.button_index]
	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_LEFT_X:
				return "Left stick left" if event.axis_value < 0 else "Left stick right"
			JOY_AXIS_LEFT_Y:
				return "Left stick up" if event.axis_value < 0 else "Left stick down"
			JOY_AXIS_TRIGGER_LEFT:
				return "Left trigger"
			JOY_AXIS_TRIGGER_RIGHT:
				return "Right trigger"
	return event.as_text().replace(" (Physical)", "")

func is_pause_event(event: InputEvent) -> bool:
	return event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)
