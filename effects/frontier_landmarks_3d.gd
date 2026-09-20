extends Node3D
## A bounded drifting scenery field behind actors, held still during boss fights.

const RELAY := preload("res://assets/models/voxel_frontier/meshes/relay_fragment.glb")
# Legacy collections remain available to their standalone asset reviews.
const STATION_DEBRIS_SCENES := [
	preload("res://assets/models/frontier/station_debris/station_ring_section.glb"),
	preload("res://assets/models/frontier/station_debris/station_habitat_wreck.glb"),
	preload("res://assets/models/frontier/station_debris/station_solar_wing.glb"),
	preload("res://assets/models/frontier/station_debris/station_truss.glb"),
	preload("res://assets/models/frontier/station_debris/station_armor_plate.glb"),
]
const SPACE_DEBRIS_SCENES := [
	preload("res://assets/models/frontier/space_debris/derelict_satellite.glb"),
	preload("res://assets/models/frontier/space_debris/ruptured_cargo_pod.glb"),
	preload("res://assets/models/frontier/space_debris/spent_fuel_tank.glb"),
	preload("res://assets/models/frontier/space_debris/discarded_engine_bell.glb"),
	preload("res://assets/models/frontier/space_debris/broken_survey_dish.glb"),
	preload("res://assets/models/frontier/space_debris/faceted_asteroid.glb"),
]
const VOXEL_DEBRIS_SCENES := [
	preload("res://assets/models/voxel_frontier/meshes/relay_fragment.glb"),
	preload("res://assets/models/voxel_frontier/meshes/solar_fragment.glb"),
	preload("res://assets/models/voxel_frontier/meshes/cargo_wreck.glb"),
	preload("res://assets/models/voxel_frontier/meshes/engine_wreck.glb"),
	preload("res://assets/models/voxel_frontier/meshes/hull_fragment.glb"),
	preload("res://assets/models/voxel_frontier/meshes/asteroid_cluster.glb"),
]
# Six voxel salvage forms share the existing eighteen-instance scenery budget.
const DEBRIS_SCENES := VOXEL_DEBRIS_SCENES
const SceneryMaterials := preload("res://effects/rendering/station_debris_materials.gd")
const DEBRIS_COUNT := 18
## Canvas pixels per second, matching the planet's frame-independent travel.
@export_range(0.0, 100.0) var drift_speed := 20.0
@export_range(0.0, 100.0) var relay_drift_speed := 12.0
@export_range(0.0, 256.0) var wrap_padding := 32.0
var _camera: Camera3D
var _relay: Node3D
var _relay_anchor := Vector2(0.12, 0.68)
var _relay_radius := 0.0
var _debris: Array[Node3D] = []
var _anchors: Array[Vector2] = []
var _radii: Array[float] = []


func _ready() -> void:
	_camera = get_node("../CameraRig3D/ShakeOffset/Camera3D") as Camera3D
	_relay = RELAY.instantiate() as Node3D
	add_child(_relay)
	_relay.rotation_degrees = Vector3(12.0, -28.0, 18.0)
	# Match the former station landmark's footprint with the smaller voxel mesh.
	_relay.scale = Vector3.ONE * 4.4
	SceneryMaterials.apply_to(_relay, 0.78)
	_relay_radius = _visual_radius(_relay)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73140
	for index in DEBRIS_COUNT:
		var fragment := DEBRIS_SCENES[index % DEBRIS_SCENES.size()].instantiate() as Node3D
		add_child(fragment)
		fragment.scale = Vector3.ONE * rng.randf_range(0.48, 0.82)
		fragment.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.32, 0.32))
		SceneryMaterials.apply_to(fragment, 0.68)
		_debris.append(fragment)
		_anchors.append(Vector2(rng.randf(), rng.randf()))
		_radii.append(_visual_radius(fragment))
	_update_positions()
	get_viewport().size_changed.connect(_update_positions)


func _process(delta: float) -> void:
	# boss_active covers entry, every phase, and deferred defeat/continue handling.
	# Skipping travel accumulation preserves the exact point where it was stopped.
	if not GameManager.boss_active:
		var height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
		_relay_anchor.y = _advance_down(_relay_anchor.y, _relay_radius, relay_drift_speed, delta, height)
		_relay.rotation.y += delta * 0.008
		for index in _debris.size():
			var speed := drift_speed * (0.8 + float(index % 4) * 0.2)
			_anchors[index].y = _advance_down(_anchors[index].y, _radii[index], speed, delta, height)
			_debris[index].rotation.z += delta * (0.025 + float(index % 3) * 0.01)
	# Keep the frozen screen anchors aligned when the boss camera follows or shakes.
	_update_positions()


func _update_positions() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	# Screen anchors follow viewport expansion; depth remains behind every actor.
	_relay.global_position = _camera.project_position(viewport_size * _relay_anchor, 110.0)
	for index in _debris.size():
		_debris[index].global_position = _camera.project_position(viewport_size * _anchors[index], 95.0)


func _advance_down(anchor_y: float, radius: float, speed: float, delta: float, height: float) -> float:
	if is_zero_approx(speed):
		return anchor_y
	# A rotation-independent sphere encloses every mesh, including long antennas.
	# Orthographic projection converts its world radius to a viewport fraction.
	var margin := radius / _camera.size + wrap_padding / height
	return wrapf(anchor_y + speed * delta / height, -margin, 1.0 + margin)


func _visual_radius(model: Node3D) -> float:
	var radius := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := mesh.get_aabb()
		for corner in 8:
			var point := mesh.global_transform * bounds.get_endpoint(corner)
			radius = maxf(radius, point.distance_to(model.global_position))
	return radius
