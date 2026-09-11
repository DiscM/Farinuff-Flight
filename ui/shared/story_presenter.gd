extends Control
class_name StoryPresenter
## Plain content panel that renders one StoryBeatDefinition-style beat as text.
## The caller owns campaign state, focus, and lifetime; this control only
## displays a beat and reports completion. Story Frequency is passed in rather
## than read from SaveManager, keeping this a pure rendering control.

const FREQ_FULL: StringName = &"full"
const FREQ_BRIEF: StringName = &"brief"
const FREQ_OFF: StringName = &"off"
const BRIEF_MAX_CHARS: int = 40

signal completed
signal skipped

## Opens a story beat. `beat` may be null for a pure text pane; otherwise it is
## duck-typed for: id, trigger_type, text_key, once_policy, blocking,
## skippable, auto_dismiss_seconds, speaker_id, required_route_tags,
## forbidden_route_tags. Any absent field falls back to a safe default.
func display(beat: Resource, text: String, story_frequency: StringName = &"full") -> void:
	_frequency = story_frequency
	_beat = beat
	_raw_text = text
	if _frequency != FREQ_FULL and _frequency != FREQ_BRIEF:
		# Off (or any unrecognized value) renders nothing and completes at once.
		_frequency = FREQ_OFF
	if not is_node_ready():
		_pending_display = true
		return
	_render()


@onready var title_label: Label = %TitleLabel
@onready var speaker_label: Label = %SpeakerLabel
@onready var body_label: Label = %BodyLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var skip_button: Button = %SkipButton

var _beat: Resource
var _raw_text: String = ""
var _frequency: StringName = &"full"
var _pending_display := false
var _auto_dismiss_timer: SceneTreeTimer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(_on_confirm)
	skip_button.pressed.connect(_on_skip)
	title_label.add_theme_font_size_override("font_size", 20)
	if _pending_display:
		_pending_display = false
		_render()


func _render() -> void:
	if _frequency == FREQ_OFF:
		_pause_auto_dismiss()
		completed.emit()
		return

	var blocking := _beat_blocking()
	var skippable := _beat_skippable()
	var auto_dismiss := _beat_auto_dismiss()

	# Non-blocking beats never capture input or pause the tree (barks).
	set_process_mode(Node.PROCESS_MODE_INHERIT if blocking else Node.PROCESS_MODE_DISABLED)
	mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
	confirm_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
	)
	skip_button.visible = blocking or skippable
	if blocking and not skippable:
		skip_button.visible = _beat_skippable()

	if _frequency == FREQ_BRIEF:
		_show_brief()
	else:
		_show_full(auto_dismiss)

	if blocking:
		set_process_mode(Node.PROCESS_MODE_INHERIT)
		confirm_button.grab_focus()
	else:
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		confirm_button.release_focus()

	_configure_auto_dismiss(auto_dismiss, blocking)


func _show_full(auto_dismiss: float) -> void:
	var speaker := _beat_speaker()
	var title := _beat_title(_raw_text)
	title_label.visible = not title.is_empty()
	title_label.text = title
	speaker_label.visible = not speaker.is_empty()
	speaker_label.text = speaker
	body_label.visible = true
	body_label.text = _body_copy(_raw_text)
	confirm_button.visible = auto_dismiss <= 0.0 or _beat_blocking()


func _show_brief() -> void:
	title_label.visible = false
	speaker_label.visible = false
	body_label.visible = true
	body_label.text = _condense_line(_raw_text)
	confirm_button.visible = true


func _condense_line(text: String) -> String:
	var first := text.split("\n", true, 1)[0].strip_edges()
	if first.length() <= BRIEF_MAX_CHARS:
		return first
	return first.substr(0, BRIEF_MAX_CHARS).rstrip(" ,.;:") + "…"


func _body_copy(text: String) -> String:
	if text.is_empty():
		return ""
	return text.strip_edges()


func _on_confirm() -> void:
	if _frequency == FREQ_OFF:
		return
	_pause_auto_dismiss()
	completed.emit()


func _on_skip() -> void:
	_pause_auto_dismiss()
	skipped.emit()
	completed.emit()


func _configure_auto_dismiss(auto_dismiss: float, blocking: bool) -> void:
	_pause_auto_dismiss()
	if auto_dismiss > 0.0 and not blocking:
		_auto_dismiss_timer = get_tree().create_timer(auto_dismiss, true)
		_auto_dismiss_timer.timeout.connect(_on_auto_dismiss)


func _on_auto_dismiss() -> void:
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	completed.emit()


func _pause_auto_dismiss() -> void:
	if _auto_dismiss_timer != null and _auto_dismiss_timer.is_connected("timeout", _on_auto_dismiss):
		_auto_dismiss_timer.timeout.disconnect(_on_auto_dismiss)
	_auto_dismiss_timer = null


func _beat_blocking() -> bool:
	return bool(_beat_get(&"blocking", false))


func _beat_skippable() -> bool:
	return bool(_beat_get(&"skippable", true))


func _beat_auto_dismiss() -> float:
	return float(_beat_get(&"auto_dismiss_seconds", 0.0))


func _beat_speaker() -> String:
	var speaker := str(_beat_get(&"speaker_id", &""))
	return speaker if not speaker.is_empty() else ""


func _beat_title(text: String) -> String:
	# Presentation ownership stays in the text payload; a speaker or a heading
	# is not fabricated from stable IDs here.
	return ""


func _beat_get(field: StringName, fallback: Variant) -> Variant:
	# Duck-typing against any Resource whose script exposes the field. Real
	# beats derive from StoryBeatDefinition and expose every field; a null
	# beat (pure text pane) yields the fallback.
	if _beat == null:
		return fallback
	if not _beat is Resource:
		return fallback
	var value: Variant = (_beat as Resource).get(field)
	return value if value != null else fallback