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
		status.add_theme_font_override("font", NeonUI.HEADING_FONT)
	max_value = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent().has_method("mount_boost"):
		get_parent().call_deferred("mount_boost", self, status)

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(status):
		return
	var state: Dictionary = player.get_boost_state()
	var ready := bool(state.chain_ready)
	var pips := ""
	for index in int(state.threshold):
		pips += "◆" if index < int(state.reflections) else "◇"
	if ready:
		status.text = "CHAIN  %s  •  %s  %.2fs" % [pips, InputBindings.binding_hint("boost"), float(state.chain_remaining)]
		value = float(state.chain_fraction)
	elif bool(state.boosting):
		status.text = "FINAL BOOST" if bool(state.chain_followup) else "REFLECT  %s" % pips
		value = float(state.reflections) / float(state.threshold)
	else:
		value = float(state.recharge)
		status.text = "BOOST [%s] READY" % InputBindings.binding_hint("boost") if value >= 1.0 else "BOOST RECHARGING"
	if ready and not _chain_was_ready:
		AudioManager.play_ui_click()
	_chain_was_ready = ready
