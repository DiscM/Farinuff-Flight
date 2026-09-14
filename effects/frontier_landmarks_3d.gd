extends Node3D
## A finite distant set, projected behind actors. No collisions or runtime spawning.

const RELAY := preload("res://assets/models/frontier/broken_orbital_relay.glb")
const FRAGMENT := preload("res://assets/models/frontier/hull_fragment.glb")
const DEBRIS_COUNT := 14
var _camera: Camera3D
var _relay: Node3D
var _debris: Array[Node3D] = []
var _anchors: Array[Vector2] = []
var _elapsed := 0.0


func _ready() -> void:
	_camera = get_node("../CameraRig3D/ShakeOffset/Camera3D") as Camera3D
	_relay = RELAY.instantiate() as Node3D
	add_child(_relay)
	_relay.rotation_degrees = Vector3(12.0, -28.0, 18.0)
	_relay.scale = Vector3.ONE * 1.65
	_dim_model(_relay, 0.69)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73140
	for index in DEBRIS_COUNT:
		var fragment := FRAGMENT.instantiate() as Node3D
		add_child(fragment)
		fragment.scale = Vector3.ONE * rng.randf_range(0.28, 0.85)
		fragment.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		_dim_model(fragment, 0.19)
		_debris.append(fragment)
		_anchors.append(Vector2(rng.randf(), rng.randf()))
	_update_positions()
	get_viewport().size_changed.connect(_update_positions)


func _process(delta: float) -> void:
	_elapsed += delta
	_relay.rotation.y += delta * 0.008
	for index in _debris.size():
		_debris[index].rotation.z += delta * (0.025 + float(index % 3) * 0.01)
	_update_positions()


func _update_positions() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	# Screen anchors follow viewport expansion; depth remains behind every actor.
	_relay.global_position = _camera.project_position(viewport_size * Vector2(0.12, 0.68), 110.0)
	for index in _debris.size():
		var anchor := _anchors[index]
		anchor.y = fposmod(anchor.y + _elapsed * (0.0015 + float(index % 3) * 0.0006), 1.08) - 0.04
		_debris[index].global_position = _camera.project_position(viewport_size * anchor, 95.0)


func _dim_model(model: Node3D, value: float) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(index) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			# Distant scenery has a fixed exposure; rotating metal must never
			# catch the combat key light and become brighter than a projectile.
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = false
			material.albedo_color = source.albedo_color * Color(value, value, value, 1.0)
			mesh.set_surface_override_material(index, material)
