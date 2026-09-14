extends Native3DGameplay
## Live, repeatable comparison using the actual enemy scenes and combat camera.
## 1–4: generation; R: rotate; H: hit flash. Bottom row is gameplay scale.

const REVIEW_SCENES := [
	preload("res://entities/enemies/basic_enemy_3d.tscn"),
	preload("res://entities/enemies/tank_enemy_3d.tscn"),
	preload("res://entities/enemies/bomber_enemy_3d.tscn"),
]
const SurfaceLibrary := preload("res://effects/rendering/enemy_surface_materials.gd")
var review_enemies: Array[BasicEnemy3D] = []
var review_generation := 1
var rotating := false
var _review_time := 0.0
var _hit_left := 0.0
var _caption: Label


func _ready() -> void:
	await super._ready()
	hud.hide()
	player.hide()
	player.set_physics_process(false)
	$World3D/FrontierLandmarks.hide()
	# The real pixel planet remains visible alongside the new surface treatment.
	$Backdrop/Celestial.drift_velocity = Vector2.ZERO
	var planet: Control = $Backdrop/Celestial.current_planet
	planet.override_time = true
	planet.update_time(1000.0)
	for row in 3:
		for column in REVIEW_SCENES.size():
			var enemy := REVIEW_SCENES[column].instantiate() as BasicEnemy3D
			enemy.surface_style = SurfaceLibrary.Style.AUTHORED_ALLOY if row == 0 else SurfaceLibrary.Style.PIXEL_PLANET
			enemy.name = "%s_%s" % [["Alloy", "Pixel", "GameplayScale"][row], ["Basic", "Tank", "Bomber"][column]]
			actors_root.add_child(enemy)
			enemy.scale = Vector3.ONE * (3.5 if row < 2 else 1.0)
			enemy.rotation.y = 0.24
			review_enemies.append(enemy)
	_create_review_labels()
	_layout_review()
	_set_review_generation(1)
	get_viewport().size_changed.connect(_layout_review)


func _create_review_labels() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MaterialReviewLabels"
	layer.layer = 15
	add_child(layer)
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_label(root, "PIXEL-FORGED ARMOR", Vector2(0.04, 0.045), 28, Color("e2d8f4"))
	_label(root, "PixelPlanets light bands · shared hull grid · limited palette", Vector2(0.04, 0.102), 16, Color("a99fc1"))
	for column in 3:
		_label(root, ["REDJACK / BASIC", "BASTION / TANK", "VERDANT / BOMBER"][column], Vector2(0.25 + column * 0.25, 0.168), 15, [Color("ef977e"), Color("c1a1eb"), Color("c7df84")][column], true)
	_label(root, "ALLOY\n3.5×", Vector2(0.045, 0.285), 15, Color("858098"))
	_label(root, "PIXEL\n3.5×", Vector2(0.045, 0.575), 15, Color("d3b8f2"))
	_label(root, "IN GAME\n1×", Vector2(0.045, 0.808), 15, Color("858098"))
	_caption = _label(root, "", Vector2(0.04, 0.93), 15, Color("a99fc1"))


func _label(parent: Control, content: String, anchor: Vector2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.set_anchor(SIDE_LEFT, anchor.x)
	label.set_anchor(SIDE_TOP, anchor.y)
	label.set_anchor(SIDE_RIGHT, anchor.x)
	label.set_anchor(SIDE_BOTTOM, anchor.y)
	if centered:
		label.offset_left = -140.0
		label.offset_right = 140.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _layout_review() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for index in review_enemies.size():
		var row := floori(float(index) / 3.0)
		var column := index % 3
		var screen_position := viewport_size * Vector2(0.25 + column * 0.25, [0.325, 0.625, 0.84][row])
		review_enemies[index].global_position = flight_space.screen_to_combat_plane(screen_position)
	# Small reference in the top corner, outside the material comparison rows.
	$Backdrop/Celestial.position = viewport_size * Vector2(0.88, 0.015)
	$Backdrop/Celestial.scale = Vector2.ONE * 0.62


func _set_review_generation(value: int) -> void:
	review_generation = clampi(value, 1, 4)
	for enemy in review_enemies:
		enemy.generation = review_generation
		enemy._set_generation_visuals()
	_caption.text = "GEN %d   /   1–4 GENERATION    R ROTATE    H HIT FLASH" % review_generation


func _process(delta: float) -> void:
	_review_time += delta
	_hit_left = maxf(0.0, _hit_left - delta)
	for enemy in review_enemies:
		if rotating:
			enemy.rotation.y += delta * 0.35
		enemy._set_instance_parameter(&"instance_animation_time", _review_time)
		enemy._set_instance_parameter(&"instance_flash", _hit_left / 0.15)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_set_review_generation(event.keycode - KEY_1 + 1)
		KEY_R:
			rotating = not rotating
		KEY_H:
			_hit_left = 0.15
		_:
			return
	get_viewport().set_input_as_handled()
