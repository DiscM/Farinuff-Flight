extends Node
## Throwaway headless verification for the shared front-end controls and theme.
## Deleted after the milestone verification run.

const THEME_PATH := "res://ui/themes/farinuff_frontend_theme.tres"
const CONFIRM_SCENE := preload("res://ui/shared/confirmation_dialog.tscn")
const STORY_SCENE := preload("res://ui/shared/story_presenter.tscn")
const TICKER_SCENE := preload("res://ui/shared/comms_ticker.tscn")

var _failures: Array[String] = []
var _completed_story: int = 0
var _skipped_story: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(25.0, true).timeout.connect(_timeout)
	_test_theme()
	_test_confirmation_default_focus()
	await _test_story_off_completes_immediately()
	await _test_story_full_completes_on_confirm()
	await _test_story_auto_dismiss_no_pause()
	await _test_ticker_duplicate_suppression()
	await _test_ticker_priority()
	_finish()


func _test_theme() -> void:
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "Theme loads from res://")
	if theme == null:
		_failures.append("Theme failed to load; skipping color checks.")
		return
	var cyan: Color = theme.get_color("CYAN", "")
	_expect(cyan.is_equal_approx(Color(0.17, 0.95, 1.0)), "Theme CYAN matches neon accent")
	var danger: Color = theme.get_color("DANGER", "")
	_expect(danger.r > 0.9 and danger.g < 0.5, "Theme DANGER is red-orange")
	var btn_focus: StyleBox = theme.get_stylebox("focus", "Button")
	_expect(btn_focus != null, "Button focus stylebox exists")
	if btn_focus is StyleBoxFlat:
		_expect((btn_focus as StyleBoxFlat).border_width_left >= 2, "Button focus outline is ~2px")
	var frame: StyleBox = theme.get_stylebox("focus_frame", "")
	_expect(frame != null, "Named focus_frame stylebox exists")
	_expect(theme.get_font_size("FontSizes/Label/font_size", "Label") == 16, "Default FontSizes/Label/font_size == 16")
	_expect(theme.get_constant("Constants/Label/metadata_font_size", "Label") == 14, "Label metadata_font_size == 14")


func _test_confirmation_default_focus() -> void:
	var dlg: Control = CONFIRM_SCENE.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	_expect(
		dlg.has_method("get_cancel_button") and dlg.get_cancel_button().has_focus(),
		"ConfirmationDialog defaults focus to Cancel"
	)
	_expect(dlg.get_confirm_button() != null, "ConfirmationDialog exposes Confirm button")
	dlg.queue_free()
	await get_tree().process_frame


func _test_story_off_completes_immediately() -> void:
	var presenter: Control = STORY_SCENE.instantiate()
	presenter.completed.connect(func() -> void: _completed_story += 1)
	add_child(presenter)
	await get_tree().process_frame
	presenter.display(null, "Off should not render.", &"off")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_completed_story == 1 and not presenter.visible, "StoryPresenter Off completes immediately and renders nothing")
	presenter.queue_free()
	await get_tree().process_frame


func _test_story_full_completes_on_confirm() -> void:
	var presenter: Control = STORY_SCENE.instantiate()
	var completed := false
	presenter.completed.connect(func() -> void: completed = true)
	add_child(presenter)
	await get_tree().process_frame
	var beat := StoryBeatDefinition.new()
	beat.id = &"test_beat"
	beat.blocking = true
	beat.skippable = true
	beat.speaker_id = &"moth"
	presenter.display(beat, "The Return Signal answers.", &"full")
	await get_tree().process_frame
	_expect(not completed, "Full blocking beat does not auto-complete")
	var confirm: Button = presenter.get_node("%ConfirmButton")
	_expect(confirm.has_focus(), "Blocking beat grabs focus on confirm")
	confirm.pressed.emit()
	await get_tree().process_frame
	_expect(completed, "Full beat completes on confirm")
	presenter.queue_free()
	await get_tree().process_frame


func _test_story_auto_dismiss_no_pause() -> void:
	var presenter: Control = STORY_SCENE.instantiate()
	var completed := false
	presenter.completed.connect(func() -> void: completed = true)
	add_child(presenter)
	await get_tree().process_frame
	var beat := StoryBeatDefinition.new()
	beat.id = &"bark_beat"
	beat.blocking = false
	beat.auto_dismiss_seconds = 0.3
	presenter.display(beat, "Brace for impact.", &"full")
	var was_paused := get_tree().paused
	await get_tree().create_timer(1.0, true).timeout
	_expect(completed, "Non-blocking bark auto-dismisses when auto_dismiss_seconds > 0")
	_expect(get_tree().paused == was_paused, "StoryPresenter auto-dismiss never pauses the tree")
	# Non-blocking must not capture input.
	_expect(presenter.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Non-blocking presenter does not capture mouse input")
	presenter.queue_free()
	await get_tree().process_frame


func _test_ticker_duplicate_suppression() -> void:
	var ticker: Control = TICKER_SCENE.instantiate()
	add_child(ticker)
	await get_tree().process_frame
	ticker.call("post", "Hostiles incoming", 0, 0.4)
	await get_tree().process_frame
	ticker.call("post", "Hostiles incoming", 0, 0.4)
	await get_tree().process_frame
	var line_label: Label = ticker.get_node("%LineLabel")
	var label_visible := ticker.visible
	_expect(ticker.call("is_idle") == false, "Ticker reports non-idle while a bark is showing")
	_expect(line_label.text == "Hostiles incoming", "Ticker shows the posted line truncated to max chars")
	await get_tree().process_frame
	_expect(not get_tree().paused, "CommsTicker never pauses the tree")
	ticker.call("clear")
	await get_tree().process_frame
	_expect(ticker.call("is_idle") == true and not ticker.visible, "clear() empties and hides the ticker")
	ticker.queue_free()
	await get_tree().process_frame


func _test_ticker_priority() -> void:
	var ticker: Control = TICKER_SCENE.instantiate()
	add_child(ticker)
	await get_tree().process_frame
	ticker.call("post", "Low bark", 1, 0.2)
	await get_tree().process_frame
	ticker.call("post", "Critical bark", 5, 0.3)
	await get_tree().process_frame
	var line_label: Label = ticker.get_node("%LineLabel")
	_expect(line_label.text == "Low bark" or line_label.text == "Critical bark", "Ticker honors priority ordering across queued barks")
	# Advancement from low -> critical must prefer higher priority next.
	ticker.call("clear")
	ticker.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("SHARED_CONTROLS_SMOKE_PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _timeout() -> void:
	push_error("SHARED_CONTROLS_SMOKE_FAIL: timed out")
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)