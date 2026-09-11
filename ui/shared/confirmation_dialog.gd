extends Control
class_name SharedConfirmationDialog
## Reusable modal for destructive actions (Restart/Abandon Expedition, Quit).
## Renders a dim backdrop, plaque, title, body, and Cancel/Confirm buttons.
## Default focus is Cancel; `ui_cancel` behaves as Cancel. Respects Reduced
## Flashing by avoiding pulses and procedural glow. The opener owns lifetime:
## free this node (e.g. queue_free) when the page that opened it closes.

signal confirmed
signal cancelled

var title_text: String = ""
var body_text: String = ""
var confirm_text: String = "Confirm"
var cancel_text: String = "Cancel"
## 0 = instant confirm on activation; >0 requires holding the Confirm button.
## A future settings wiring (Hold-to-confirm) may supply this value. No timer
## machinery is started unless this exceeds zero.
var hold_to_confirm_seconds: float = 0.0

@onready var backplate: ColorRect = %Backplate
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton
@onready var confirm_progress: ProgressBar = %ConfirmProgress

var _holding_confirm := false
var _held_time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.pressed.connect(_emit_cancelled)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.focus_entered.connect(func() -> void: confirm_progress.value = 0.0)
	confirm_button.focus_entered.connect(func() -> void: confirm_progress.value = 0.0)
	_refresh_labels()
	_configure_hold_if_needed()
	# Destructive actions must default focus to Cancel.
	cancel_button.grab_focus()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		_emit_cancelled()


func _process(delta: float) -> void:
	if hold_to_confirm_seconds <= 0.0 or not _holding_confirm:
		return
	_held_time += delta
	confirm_progress.value = clampf(_held_time / hold_to_confirm_seconds, 0.0, 1.0)
	if _held_time >= hold_to_confirm_seconds:
		_holding_confirm = false
		_emit_confirmed()


func _on_confirm_pressed() -> void:
	# With an instant confirm (hold <= 0) a click confirms immediately. With
	# hold-to-confirm enabled, only the accumulated hold in _process confirms.
	if hold_to_confirm_seconds <= 0.0:
		_emit_confirmed()


func _on_confirm_button_down() -> void:
	if hold_to_confirm_seconds > 0.0:
		_holding_confirm = true
		_held_time = 0.0
		confirm_progress.value = 0.0


func _on_confirm_button_up() -> void:
	_holding_confirm = false
	confirm_progress.value = 0.0


## Populates the dialog. Call before or after adding to the tree; labels are
## refreshed on ready.
func display(
	p_title: String = "",
	p_body: String = "",
	p_confirm: String = "Confirm",
	p_cancel: String = "Cancel"
) -> void:
	title_text = p_title
	body_text = p_body
	confirm_text = p_confirm
	cancel_text = p_cancel
	if is_node_ready():
		configure(title_text, body_text, confirm_text, cancel_text, hold_to_confirm_seconds)


## Convenience that also applies the hold duration in one call.
func configure(
	p_title: String,
	p_body: String,
	p_confirm: String,
	p_cancel: String,
	p_hold: float
) -> void:
	title_text = p_title
	body_text = p_body
	confirm_text = p_confirm
	cancel_text = p_cancel
	hold_to_confirm_seconds = maxf(p_hold, 0.0)
	if is_node_ready():
		_refresh_labels()
		_configure_hold_if_needed()


func get_cancel_button() -> Button:
	return cancel_button


func get_confirm_button() -> Button:
	return confirm_button


func _refresh_labels() -> void:
	title_label.text = title_text
	body_label.text = body_text
	cancel_button.text = cancel_text
	confirm_button.text = confirm_text


func _configure_hold_if_needed() -> void:
	confirm_progress.visible = hold_to_confirm_seconds > 0.0
	confirm_progress.value = 0.0
	set_process(hold_to_confirm_seconds > 0.0)


func _emit_confirmed() -> void:
	set_process(false)
	confirmed.emit()
	queue_free()


func _emit_cancelled() -> void:
	set_process(false)
	cancelled.emit()
	queue_free()