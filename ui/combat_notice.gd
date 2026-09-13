extends Label
## One non-modal channel: tactical messages take priority over optional story.
signal transmission_completed(beat_id: StringName)
const MAX_PENDING := 6
var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _remaining := 0.0
var _clock := 0.0
var _recent: Dictionary = {}
var _completed: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -220
	offset_right = 220
	offset_top = 84
	offset_bottom = 130
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.02, 0.95))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 2)
	SignalBus.combat_notice.connect(_show_notice)
	SignalBus.encounter_warning.connect(_show_encounter_warning)
	SignalBus.game_over.connect(func(_score: int): clear_messages())
	SignalBus.wave_cleared.connect(func(_wave: int): clear_messages())
	SaveManager.settings_changed.connect(_apply_story_frequency)
	hide()

func _show_notice(message: String) -> void:
	post(message, StringName(message), 2, 3.5)

func post(message: String, key: StringName, priority: int = 0, duration: float = 3.0, story: bool = false) -> void:
	if message.is_empty() or (story and (int(SaveManager.get_setting("story_frequency", 0)) == 2 or _completed.has(key))):
		return
	if _active.get("key", &"") == key or _clock - float(_recent.get(key, -100.0)) < 5.0:
		return
	for pending: Dictionary in _queue:
		if pending.key == key:
			return
	var item := {"text": message, "key": key, "priority": priority, "duration": clampf(duration, 2.0, 5.0), "story": story, "expires": _clock + 15.0}
	if not _active.is_empty() and priority > int(_active.priority):
		# Interrupted prose can return while still timely; it has not been marked viewed.
		_queue.push_front(_active)
		_active = {}
		_remaining = 0.0
		text = ""
	_queue.append(item)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.priority) > int(b.priority))
	if _queue.size() > MAX_PENDING:
		_queue.resize(MAX_PENDING)

func _process(delta: float) -> void:
	if not GameManager.is_game_active or get_tree().paused:
		return
	# A hidden HUD means a reward, route choice, or other safe-boundary overlay owns the screen.
	var layer := get_parent() as CanvasLayer
	if layer != null and not layer.visible:
		return
	_clock += delta
	if not _active.is_empty():
		_remaining -= delta
		if _remaining > 0.0:
			return
		var finished := _active
		_active = {}
		_recent[finished.key] = _clock
		if bool(finished.story):
			_completed[finished.key] = true
			transmission_completed.emit(finished.key)
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		if float(item.expires) <= _clock:
			continue
		_active = item
		_remaining = float(item.duration)
		text = ("MOTH // " if bool(item.story) else "") + str(item.text)
		add_theme_color_override("font_color", Color(0.65, 0.9, 1.0) if bool(item.story) else Color(1.0, 0.9, 0.5))
		show()
		return
	hide()

func clear_messages() -> void:
	_queue.clear()
	_active = {}
	_remaining = 0.0
	text = ""
	hide()

func _apply_story_frequency() -> void:
	var frequency := int(SaveManager.get_setting("story_frequency", 0))
	if frequency == 0:
		return
	_queue = _queue.filter(func(item: Dictionary): return not bool(item.story) or (frequency == 1 and int(item.priority) > 0))
	if bool(_active.get("story", false)) and (frequency == 2 or int(_active.get("priority", 0)) == 0):
		_active = {}
		_remaining = 0.0
		hide()


func _show_encounter_warning(message: String, seconds: float) -> void:
	# Authoritative telegraphs supersede queued prose and older tactical hints.
	clear_messages()
	_active = {"text": message, "key": StringName(message), "priority": 3, "duration": seconds, "story": false, "expires": _clock + seconds}
	_remaining = maxf(seconds, 0.5)
	text = message
	add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	show()
