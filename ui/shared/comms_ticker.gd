extends Control
class_name CommsTicker
## Small non-modal HUD control for short combat barks (the plan's "one line,
## at most 42 characters and about 3 seconds"). Owns no campaign state and no
## focus. Never captures input and never pauses the tree. Prioritizes barks,
## suppresses a duplicate in-flight message, and auto-dismisses. Respects
## Reduced Flashing by avoiding glitch/pulse animations.

const MAX_CHARS: int = 42
const MAX_VISIBLE_COUNT: int = 4

@onready var label: Label = %LineLabel

var _queue: Array[Dictionary] = []
var _current_text: String = ""
var _dismiss_timer: SceneTreeTimer


## Queues a combat bark. Higher `priority` wins; a message already queued or
## showing with identical text is suppressed while in flight.
func post(message: String, priority: int = 0, duration: float = 3.0) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		return
	if _is_in_flight(trimmed):
		return
	var entry := {"text": trimmed, "priority": priority, "duration": duration}
	_queue.append(entry)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority > b.priority)
	if _current_text.is_empty():
		_show_next()


## Clears the active bark and all queued barks immediately.
func clear() -> void:
	_queue.clear()
	_current_text = ""
	_stop_dismiss_timer()
	_apply_current("")


## True when no bark is showing and nothing is queued.
func is_idle() -> bool:
	return _current_text.is_empty() and _queue.is_empty()


func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _is_in_flight(text: String) -> bool:
	if _current_text == text:
		return true
	for entry in _queue:
		if entry["text"] == text:
			return true
	return false


func _show_next() -> void:
	if not is_inside_tree():
		return
	if not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		_current_text = str(entry["text"])
		_apply_current(_current_text)
		visible = true
		_start_dismiss(float(entry["duration"]))
	else:
		_current_text = ""
		_apply_current("")
		visible = false


func _apply_current(text_value: String) -> void:
	if not is_node_ready():
		return
	label.text = text_value if text_value.length() <= MAX_CHARS else text_value.substr(0, MAX_CHARS)


func _start_dismiss(duration: float) -> void:
	_stop_dismiss_timer()
	_dismiss_timer = get_tree().create_timer(maxf(duration, 0.1), true)
	_dismiss_timer.timeout.connect(_on_dismiss_timeout)


func _stop_dismiss_timer() -> void:
	if _dismiss_timer != null and is_instance_valid(_dismiss_timer):
		_dismiss_timer.timeout.disconnect(_on_dismiss_timeout)
	_dismiss_timer = null


func _on_dismiss_timeout() -> void:
	_dismiss_timer = null
	_current_text = ""
	_show_next()