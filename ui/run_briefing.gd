extends PanelContainer
## Read-only pause snapshot. Binding hints follow settings and device changes.

var _controls: Label

func _ready() -> void:
	name = "RunBriefing"
	InputBindings.bindings_changed.connect(_refresh_controls)
	InputBindings.device_changed.connect(_refresh_controls)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			_refresh_snapshot()
	)
	_refresh_snapshot()

func _refresh_snapshot() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var frame := preload("res://ui/shared/menu_briefing.gd").frame()
	frame.set_content_margin_all(24)
	add_theme_stylebox_override("panel", frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().accessibility_name = "Scroll flight briefing"
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	var mode := "PRACTICE" if GameManager.practice_mode else "ENDLESS" if GameManager.expedition_completed else "EXPEDITION"
	_label(column, "%s / WAVE %02d" % [mode, GameManager.current_wave], 30, NeonUI.WHITE)
	if GameManager.boss_active:
		_label(column, "BOSS ENGAGED", 18, NeonUI.YELLOW)
	if not GameManager.boss_active:
		var meter := ProgressBar.new()
		meter.name = "WaveProgress"
		meter.max_value = maxi(1, GameManager.orbs_needed_this_wave)
		meter.value = GameManager.orbs_collected_this_wave
		meter.show_percentage = false
		meter.custom_minimum_size.y = 8
		var fill := StyleBoxFlat.new()
		fill.bg_color = NeonUI.CYAN
		meter.add_theme_stylebox_override("fill", fill)
		column.add_child(meter)
		_label(column, "XP %d / %d" % [GameManager.orbs_collected_this_wave, GameManager.orbs_needed_this_wave], 16)
	column.add_child(HSeparator.new())
	var resources := GridContainer.new()
	resources.columns = 2
	resources.add_theme_constant_override("h_separation", 32)
	resources.add_theme_constant_override("v_separation", 10)
	column.add_child(resources)
	for entry: Array in [["LIVES", GameManager.lives], ["TRY-AGAIN STOCKS", GameManager.try_again_stocks], ["SCORE", GameManager.score], ["SALVAGE EARNED", GameManager.run_salvage]]:
		var stat := _label(resources, "%s\n%s" % [entry[0], entry[1]], 18)
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(HSeparator.new())
	_label(column, "INSTALLED UPGRADES", 16, NeonUI.CYAN)
	var upgrades := PackedStringArray()
	var owned := GameManager.get_owned_elite_ids()
	for upgrade: Dictionary in GameManager.ALL_UPGRADES + GameManager.META_ELITE_UPGRADES:
		if owned.has(str(upgrade.id)):
			upgrades.append(str(upgrade.name))
	_label(column, " · ".join(upgrades) if not upgrades.is_empty() else "None installed", 18)
	_label(column, "System levels · Fire rate %d / Lives %d / Speed %d" % [GameManager.stat_fire_rate_level, GameManager.stat_health_level, GameManager.stat_speed_level], 16)
	column.add_child(HSeparator.new())
	_controls = _label(column, "", 16, NeonUI.CYAN)
	_refresh_controls()

func _label(parent: Node, text: String, font_size: int, color: Color = Color(0.82, 0.88, 0.96)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _refresh_controls() -> void:
	_controls.text = "FIRE  %s\nBOOST / REFLECT  %s\nRESUME  %s" % [InputBindings.binding_label("shoot"), InputBindings.binding_label("boost"), InputBindings.binding_label("pause")]
