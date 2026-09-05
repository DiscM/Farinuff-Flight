extends Node3D
## Shared-origin hull modules; orbital motion stays independent of player aim.
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const MODULES := {
	"twin_cannons": preload("res://assets/models/redesign/butterfly_elites/bf_elite_twin_cannons.glb"),
	"auto_aim": preload("res://assets/models/redesign/butterfly_elites/bf_elite_auto_aim.glb"),
	"drone_escort": preload("res://assets/models/redesign/butterfly_elites/bf_elite_drone_escort.glb"),
	"hull_plating": preload("res://assets/models/redesign/butterfly_elites/bf_elite_hull_plating.glb"),
	"afterburner": preload("res://assets/models/redesign/butterfly_elites/bf_elite_afterburner.glb"),
	"spread_shot_elite": preload("res://assets/models/redesign/butterfly_elites/bf_elite_spread_shot.glb"),
	"shield_burst": preload("res://assets/models/redesign/butterfly_elites/bf_elite_shield_burst.glb"),
	"magnet_field": preload("res://assets/models/redesign/butterfly_elites/bf_elite_magnet_field.glb"),
	"overclock": preload("res://assets/models/redesign/butterfly_elites/bf_elite_overclock.glb"),
	"rear_gunner": preload("res://assets/models/redesign/butterfly_elites/bf_elite_rear_gunner.glb"),
	"orbitals": preload("res://assets/models/native/upgrade_orbitals.glb"),
	"piercing": preload("res://assets/models/native/upgrade_piercing.glb"),
	"explosive_rounds": preload("res://assets/models/native/upgrade_explosive.glb"),
}
const ORBITAL := preload("res://assets/models/native/orbital_sentinel.glb")
var _modules: Dictionary = {}
var _orbitals: Array[Node3D] = []
var _angle := 0.0

func _ready() -> void:
	for id in MODULES:
		var model := (MODULES[id] as PackedScene).instantiate() as Node3D
		add_child(model)
		model.position.y = 0.08
		model.hide()
		_modules[id] = model
	for index in 2:
		var orbital := ORBITAL.instantiate() as Node3D
		add_child(orbital)
		orbital.hide()
		_orbitals.append(orbital)

func set_upgrade(id: String, enabled: bool) -> void:
	if _modules.has(id):
		_modules[id].visible = enabled
	if id == "orbitals":
		for orbital in _orbitals:
			orbital.visible = enabled

func reset() -> void:
	for id in _modules:
		set_upgrade(id, false)
	_angle = 0.0

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
		set_upgrade(id, true)
