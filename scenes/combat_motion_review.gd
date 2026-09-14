extends Native3DGameplay
## Live motion draft using production actors, Blender clips and combat lighting.
## Space pauses the presentation. This review does not start an encounter.

const ENEMIES := [
	preload("res://entities/enemies/basic_enemy_3d.tscn"),
	preload("res://entities/enemies/fast_enemy_3d.tscn"),
	preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	preload("res://entities/enemies/tank_enemy_3d.tscn"),
	preload("res://entities/enemies/sniper_enemy_3d.tscn"),
]
const PLAYER := preload("res://entities/player/player_3d.tscn")
var enemies: Array[BasicEnemy3D] = []
var ships: Array[Player3D] = []
var preview_paused := false
var _cycle := 0.0
var _shot_clock := 0.0
var _stage := -1
var _caption: Label


func _ready() -> void:
	await super._ready()
	hud.hide()
	player.hide()
	player.set_physics_process(false)
	$World3D/FrontierLandmarks.hide()
	for index in ENEMIES.size():
		var enemy := ENEMIES[index].instantiate() as BasicEnemy3D
		actors_root.add_child(enemy)
		enemy.scale = Vector3.ONE * 2.2
		enemy.rotation.y = 0.12
		enemies.append(enemy)
	for index in 3:
		var ship := PLAYER.instantiate() as Player3D
		actors_root.add_child(ship)
		ship.configure_flight_space(flight_space)
		ship.set_physics_process(false)
		ship.scale = Vector3.ONE * 2.8
		ship.set_elite_upgrade_enabled("twin_cannons", true)
		ship.set_elite_upgrade_enabled("hull_plating", true)
		if index > 0:
			ship.set_elite_upgrade_enabled("afterburner", true)
		if index == 2:
			ship.set_elite_upgrade_enabled("shield_burst", true)
			ship.set_elite_upgrade_enabled("overclock", true)
		for model in ["PlayerHullGLB", "InterceptorHull", "BulwarkHull"]:
			ship.visuals.get_node(model).visible = model == ["PlayerHullGLB", "InterceptorHull", "BulwarkHull"][index]
		ships.append(ship)
	ships[1].get_ship_motion().set_boost(true)
	_build_labels()
	_layout()
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if preview_paused or ships.is_empty():
		return
	_cycle = fmod(_cycle + delta, 4.0)
	var stage := 0 if _cycle < 1.2 else 1 if _cycle < 1.75 else 2 if _cycle < 2.25 else 3
	if stage != _stage:
		_stage = stage
		if stage == 1:
			for enemy in enemies:
				enemy.play_motion(&"windup", 0.55, true)
		elif stage == 2:
			for enemy in enemies:
				enemy.play_motion(&"attack")
			ships[2].play_ship_motion(&"upgrade")
			ships[2]._upgrade_visuals.pulse("shield_burst")
			ships[2]._upgrade_visuals.pulse("overclock")
		_caption.text = ["CRUISE", "ANTICIPATION", "RELEASE", "RECOVERY"][_stage] + "    /    SPACE PAUSE"
	for enemy in enemies:
		enemy.advance_motion(delta)
		enemy._set_instance_parameter(&"instance_animation_time", _cycle)
	_shot_clock -= delta
	if _shot_clock <= 0.0:
		_shot_clock = 0.5
		ships[0].get_ship_motion().shot()
		ships[1].get_ship_motion().shot()
	for ship in ships:
		ship.advance_ship_motion(delta)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	for index in enemies.size():
		enemies[index].global_position = flight_space.screen_to_combat_plane(size * Vector2(.12 + .19 * index, .355))
	for index in ships.size():
		ships[index].global_position = flight_space.screen_to_combat_plane(size * Vector2(.22 + .28 * index, .745))
	$Backdrop/Celestial.position = size * Vector2(.93, .035)
	$Backdrop/Celestial.scale = Vector2.ONE * .5


func _build_labels() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(layout)
	_label(layout, "FLIGHT / IN MOTION", Vector2(.045,.045), 28, Color("dceffa"))
	_label(layout, "Rigid wing folds · weapon recoil · upgrades that move with the ship", Vector2(.045,.105), 15, Color("929bb9"))
	_label(layout, "ENEMIES   /   DETAIL VIEW 2.2×", Vector2(.045,.18), 13, Color("929bb9"))
	for index in 5:
		_label(layout, ["REDJACK  +50%", "RAZORWING  +65%", "VERDANT  +45%", "BASTION  +30%", "LANCER  +55%"][index], Vector2(.12 + .19 * index,.49), 13, [Color("ed876b"),Color("f0bd72"),Color("c7df84"),Color("c1a1eb"),Color("8bcbee")][index], true)
	_label(layout, "PLAYER   /   DETAIL VIEW 2.8×", Vector2(.045,.575), 13, Color("929bb9"))
	for index in 3:
		_label(layout, ["VOLLEY / TWIN CANNONS", "BOOST / AFTERBURNER", "UPGRADE / SHIELD + OVERCLOCK"][index], Vector2(.22 + .28 * index,.885), 13, Color("9ccede"), true)
	_caption = _label(layout, "", Vector2(.045,.95), 13, Color("929bb9"))


func _label(parent: Control, content: String, anchor: Vector2, size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.set_anchor(SIDE_LEFT, anchor.x)
	label.set_anchor(SIDE_TOP, anchor.y)
	label.set_anchor(SIDE_RIGHT, anchor.x)
	label.set_anchor(SIDE_BOTTOM, anchor.y)
	if centered:
		label.offset_left = -160
		label.offset_right = 160
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		preview_paused = not preview_paused
		get_viewport().set_input_as_handled()
