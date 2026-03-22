extends PanelContainer
## Developer Testing panel — embedded inside the pause menu. No full-screen overlay, no input blocking.

signal force_close

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(280, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.05, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.border_color = Color(0.2, 0.8, 0.3, 0.6)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "🛠  DEV TOOLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var div := HSeparator.new()
	vbox.add_child(div)

	_add_btn(vbox, "+ 50 Orbs",            _on_add_orbs)
	_add_btn(vbox, "Clear Enemies",         _on_clear_enemies)
	_add_btn(vbox, "Spawn Elite Boss",      _on_spawn_elite_boss)
	_add_btn(vbox, "Trigger Elite Upgrade", _on_elite_upgrade)
	_add_btn(vbox, "Trigger Point Alloc",   _on_point_allocation)
	_add_btn(vbox, "+ 5 Lives",             _on_add_lives)
	_add_btn(vbox, "Toggle God Mode",       _on_toggle_god_mode)
	_add_btn(vbox, "Full Power",            _on_full_power)

func _add_btn(parent: Node, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	btn.custom_minimum_size = Vector2(0, 30)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(callback)
	parent.add_child(btn)

# ── Actions ─────────────────────────────────────────────────────────────────────

func _on_add_orbs() -> void:
	SignalBus.xp_orb_collected.emit(50)

func _on_clear_enemies() -> void:
	get_tree().call_group("enemies", "take_damage", 9999)
	get_tree().call_group("enemy_bullets", "queue_free")

func _on_spawn_elite_boss() -> void:
	# Close the pause menu first so the boss spawns into a live game
	force_close.emit()
	GameManager.current_wave = 10
	GameManager.boss_active = true
	SignalBus.wave_started.emit(10)

func _on_elite_upgrade() -> void:
	force_close.emit()
	SignalBus.elite_upgrade_triggered.emit()

func _on_point_allocation() -> void:
	force_close.emit()
	SignalBus.allocation_triggered.emit(3)

func _on_add_lives() -> void:
	GameManager.lives += 5
	SignalBus.lives_changed.emit(GameManager.lives)

func _on_toggle_god_mode() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0]
		p.dev_god_mode = not p.dev_god_mode
		p.sprite.modulate = Color(1.2, 1.2, 0.2) if p.dev_god_mode else Color.WHITE

func _on_full_power() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0]
		p._apply_rapid_fire()
		p._apply_spread_shot()
		p.grant_orbitals()
		p.grant_piercing()
		p.grant_explosive_rounds()
