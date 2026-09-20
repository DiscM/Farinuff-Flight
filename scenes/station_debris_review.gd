extends Node
## Actual Blender exports with the production pixel material; R toggles rotation.

const Landmarks := preload("res://effects/frontier_landmarks_3d.gd")
const SceneryMaterials := preload("res://effects/rendering/station_debris_materials.gd")
const TITLES := ["RELAY FRAGMENT", "SOLAR FRAGMENT", "CARGO WRECK", "ENGINE WRECK", "HULL FRAGMENT", "ASTEROID CLUSTER"]
var _models: Array[Node3D] = []
var _turning := false
var _previous_hdr_2d := false
@onready var _camera: Camera3D = $World3D/CameraRig3D/ShakeOffset/Camera3D


func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _exit_tree() -> void:
	get_viewport().use_hdr_2d = _previous_hdr_2d


func _ready() -> void:
	$Backdrop/Celestial.drift_velocity = Vector2.ZERO
	$Backdrop/Celestial.current_planet.override_time = true
	$Backdrop/Celestial.current_planet.set_colors($Backdrop/Celestial.current_planet.original_colors)
	var relay := Landmarks.RELAY.instantiate() as Node3D
	$World3D.add_child(relay)
	relay.scale = Vector3.ONE * 6.4
	relay.rotation_degrees = Vector3(10, -16, 0)
	SceneryMaterials.apply_to(relay, 1.0)
	_models.append(relay)
	for scene in Landmarks.DEBRIS_SCENES:
		var model := scene.instantiate() as Node3D
		$World3D.add_child(model)
		model.scale = Vector3.ONE * 2.6
		model.rotation_degrees = Vector3(10, -12, 0)
		SceneryMaterials.apply_to(model, 1.0)
		_models.append(model)
	_label("VOXEL SALVAGE", Vector2(.04, .055), 28, Color("dfd8ed"))
	_label("Blender voxel wreckage · authored texture atlas · shared planet shading", Vector2(.04, .115), 15, Color("a5a0b7"))
	_label("VOXEL RELAY LANDMARK", Vector2(.07, .85), 16, Color("a5bfcc"))
	_label("Detail inspection · raised exposure · R to rotate", Vector2(.04, .93), 14, Color("9b94ae"))
	for index in TITLES.size():
		var anchor := Vector2([.47, .66, .85][index % 3], .525 if index < 3 else .835)
		_label(TITLES[index], anchor, 13, Color("a5bfcc"))
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_models[0].global_position = _camera.project_position(viewport_size * Vector2(.22, .51), 75)
	for index in Landmarks.DEBRIS_SCENES.size():
		var anchor := Vector2([.53, .72, .91][index % 3], .36 if index < 3 else .68)
		_models[index + 1].global_position = _camera.project_position(viewport_size * anchor, 75)
	$Backdrop/Celestial.position = viewport_size * Vector2(.905, .035)
	$Backdrop/Celestial.scale = Vector2.ONE * .6


func _label(content: String, anchor: Vector2, font_size: int, tint: Color) -> void:
	var label := Label.new()
	label.text = content
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.anchor_left = anchor.x
	label.anchor_top = anchor.y
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", tint)
	$Labels.add_child(label)


func _process(delta: float) -> void:
	if _turning:
		for model in _models:
			model.rotation.y += delta * .24


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_turning = not _turning
