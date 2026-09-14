extends Node3D
## Shared-origin hull modules; orbital motion stays independent of player aim.
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const FrontierMaterials := preload("res://effects/rendering/frontier_ship_materials.gd")
const ShipMotion := preload("res://effects/ship_motion_3d.gd")
const MODULES := {
	"twin_cannons": preload("res://assets/models/animated/bf_elite_twin_cannons.glb"),
	"auto_aim": preload("res://assets/models/animated/bf_elite_auto_aim.glb"),
	"drone_escort": preload("res://assets/models/animated/bf_elite_drone_escort.glb"),
	"hull_plating": preload("res://assets/models/animated/bf_elite_hull_plating.glb"),
	"afterburner": preload("res://assets/models/animated/bf_elite_afterburner.glb"),
	"spread_shot_elite": preload("res://assets/models/animated/bf_elite_spread_shot.glb"),
	"shield_burst": preload("res://assets/models/animated/bf_elite_shield_burst.glb"),
	"magnet_field": preload("res://assets/models/animated/bf_elite_magnet_field.glb"),
	"overclock": preload("res://assets/models/animated/bf_elite_overclock.glb"),
	"rear_gunner": preload("res://assets/models/animated/bf_elite_rear_gunner.glb"),
	"orbitals": preload("res://assets/models/animated/upgrade_orbitals.glb"),
	"piercing": preload("res://assets/models/animated/upgrade_piercing.glb"),
	"explosive_rounds": preload("res://assets/models/animated/upgrade_explosive.glb"),
}
const ORBITAL := preload("res://assets/models/native/orbital_sentinel.glb")
var _modules: Dictionary = {}
var _orbitals: Array[Node3D] = []
var _angle := 0.0
var _motions: Dictionary[String, ShipMotion] = {}
var _activation_time: Dictionary[String, float] = {}

func _ready() -> void:
	for id in MODULES:
		var model := (MODULES[id] as PackedScene).instantiate() as Node3D
		add_child(model)
		FrontierMaterials.apply(model)
		model.position.y = 0.08
		model.hide()
		_modules[id] = model
		_motions[id] = ShipMotion.new(model)
	for index in 2:
		var orbital := ORBITAL.instantiate() as Node3D
		add_child(orbital)
		FrontierMaterials.apply(orbital)
		orbital.hide()
		_orbitals.append(orbital)

func set_upgrade(id: String, enabled: bool, animate: bool = true) -> void:
	if _modules.has(id):
		_modules[id].visible = enabled
		if enabled and animate:
			_motions[id].play(&"deploy")
			_activation_time[id] = 0.52
		else:
			_activation_time.erase(id)
			_motions[id].reset()
	if id == "orbitals":
		for orbital in _orbitals:
			orbital.visible = enabled

func reset() -> void:
	for id in _modules:
		set_upgrade(id, false)
	_angle = 0.0
	_activation_time.clear()


func advance_motion(delta: float, hull: ShipMotion) -> void:
	for id in _motions:
		if not _modules[id].visible:
			continue
		if _activation_time.get(id, 0.0) > 0.0:
			_activation_time[id] -= delta
			_motions[id].advance(delta)
		else:
			# Matching Blender rigs keep armor, engines and guns on their panels.
			_motions[id].follow(hull)


func pulse(id: String) -> void:
	if _modules.has(id) and _modules[id].visible:
		_motions[id].play(&"deploy", 0.32)
		_activation_time[id] = 0.32

func advance_orbitals(delta: float, space: FlightSpace, center: Vector3) -> Array[Vector3]:
	_angle += delta * 2.4
	var positions: Array[Vector3] = []
	for index in _orbitals.size():
		var angle := _angle + index * PI
		var point: Vector3 = center + space.screen_motion_to_combat(Vector2(cos(angle), sin(angle)) * 62.0)
		_orbitals[index].global_position = point + Vector3.UP * 0.2
		_orbitals[index].global_rotation = Vector3(0.0, -angle, 0.0)
		positions.append(point)
	return positions


func prepare_visual_warmup() -> void:
	for id in _modules:
		set_upgrade(id, true, false)
