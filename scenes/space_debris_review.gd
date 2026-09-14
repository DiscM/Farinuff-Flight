extends "res://scenes/station_debris_review.gd"
## Companion gallery using the same material, camera and controls as the station.

const DEBRIS_TITLES := ["DERELICT SATELLITE", "RUPTURED CARGO POD", "SPENT FUEL TANK",
	"DISCARDED ENGINE BELL", "BROKEN SURVEY DISH", "FACETED ASTEROID"]


func _ready() -> void:
	$Backdrop/Celestial.drift_velocity = Vector2.ZERO
	$Backdrop/Celestial.current_planet.override_time = true
	$Backdrop/Celestial.current_planet.set_colors($Backdrop/Celestial.current_planet.original_colors)
	for scene in Landmarks.SPACE_DEBRIS_SCENES:
		var model := scene.instantiate() as Node3D
		$World3D.add_child(model)
		model.scale = Vector3.ONE * 3.3
		model.rotation_degrees = Vector3(10, -12, 0)
		SceneryMaterials.apply_to(model, 1.0)
		_models.append(model)
	_label("PIXEL-FORGED SPACE DEBRIS", Vector2(.04, .055), 28, Color("dfd8ed"))
	_label("Original Blender props · shared station palette and planet shading", Vector2(.04, .115), 15, Color("a5a0b7"))
	_label("Detail inspection · raised exposure · R to rotate", Vector2(.04, .93), 14, Color("9b94ae"))
	for index in DEBRIS_TITLES.size():
		_label(DEBRIS_TITLES[index], Vector2(.10 + .31 * (index % 3), .50 if index < 3 else .85), 15, Color("a5bfcc"))
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for index in _models.size():
		var anchor := Vector2(.19 + .31 * (index % 3), .35 if index < 3 else .70)
		_models[index].global_position = _camera.project_position(viewport_size * anchor, 75)
	$Backdrop/Celestial.position = viewport_size * Vector2(.905, .035)
	$Backdrop/Celestial.scale = Vector2.ONE * .6
