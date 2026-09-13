extends Control
signal back_requested
signal closed
signal open_section(page_id: StringName)
@export var embedded := false
var _back_button: Button
var _body: Label
var _picker: OptionButton
var _fragments: Array[Resource] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 0.99)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var title := Label.new()
	title.text = "ARCHIVES · RECOVERED SIGNAL"
	title.add_theme_font_size_override("font_size", 26)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var fragments := ExpeditionManager.get_recovered_fragments()
	_fragments = fragments
	var progress := Label.new()
	progress.text = "%d / 4 fragments recovered. Other routes may carry another part of the signal." % fragments.size()
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(progress)
	var picker := OptionButton.new()
	_picker = picker
	picker.custom_minimum_size.y = 44
	for fragment in fragments:
		picker.add_item(_fragment_title(fragment))
	picker.disabled = fragments.is_empty()
	column.add_child(picker)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 20)
	_body.custom_minimum_size.y = 180
	column.add_child(_body)
	picker.item_selected.connect(func(index: int): _display_fragment(fragments[index]))
	if fragments.is_empty():
		_body.text = "No fragments recovered yet. Clear a route through the Broken Perimeter or Tempest Reach to recover one."
	else:
		picker.select(-1)
		_body.text = "Select a recovered fragment to read it. NEW marks unread transmissions."
	_back_button = Button.new()
	_back_button.text = "BACK TO THE CHART"
	_back_button.custom_minimum_size.y = 48
	_back_button.pressed.connect(_close)
	column.add_child(_back_button)
	_back_button.grab_focus()

func _display_fragment(fragment: Resource) -> void:
	_body.text = preload("res://campaign/story_copy.gd").for_beat(fragment)
	ExpeditionManager.record_story_viewed(fragment.id)
	MenuAudio.play(&"STORY.FRAGMENT.OPEN")
	for index in _fragments.size():
		_picker.set_item_text(index, _fragment_title(_fragments[index]))

func get_primary_safe_action() -> Control:
	return _back_button

func _close() -> void:
	if embedded:
		back_requested.emit()
	else:
		closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _fragment_title(fragment: Resource) -> String:
	var title := String(fragment.id).trim_suffix("_fragment").replace("_", " ").capitalize()
	return title if ExpeditionManager.get_snapshot().seen_story_beat_ids.has(fragment.id) else "NEW · " + title
