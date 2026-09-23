extends ProgressBar
## HUD-only flight feedback keeps the combat plane clear.
var player: Node
var status: Label
var _chain_was_ready := false

func _ready() -> void:
	show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = NeonUI.YELLOW
	add_theme_stylebox_override("fill", fill)
	if is_instance_valid(status):
		status.add_theme_color_override("font_color", NeonUI.YELLOW)
		status.add_theme_font_override("font", NeonUI.DATA_FONT)
	max_value = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent().has_method("mount_boost"):
		get_parent().call_deferred("mount_boost", self, status)

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(status):
		return
	var state: Dictionary = player.get_boost_state()
	value = clampf(float(state.meter), 0.0, 1.0)
	var pips := ""
	for index in int(state.threshold):
		pips += "◆" if index < int(state.reflections) else "◇"
	if bool(state.boosting):
		status.text = "REFLECT  %s" % pips
	else:
		status.text = (
			"HOLD BOOST [%s]" % InputBindings.binding_hint("boost")
			if value >= 0.2
			else "BOOST RECHARGING"
		)
	var ready := bool(state.chain_ready)
	if ready and not _chain_was_ready:
		AudioManager.play_ui_click()
	_chain_was_ready = ready
