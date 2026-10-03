extends "res://systems/pickup_pool_3d.gd"
class_name PowerUpManager3D
## Power-up selection and collection policy over the shared pickup lifecycle.

signal power_up_collected(power_up_type: int, combat_position: Vector3)
const POWER_UP_SCENE := preload("res://entities/powerups/power_up_3d.tscn")
var _spawned := 0
var _type_counts: Dictionary[int, int] = {}


func _init() -> void:
	pool_size = 16


func _pickup_scene() -> PackedScene:
	return POWER_UP_SCENE


func spawn_power_up(combat_position: Vector3, power_up_type: int, drift_direction: Vector3 = Vector3.BACK) -> PowerUp3D:
	var pickup := _spawn_pickup(combat_position, power_up_type, drift_direction) as PowerUp3D
	if pickup != null:
		_spawned += 1
		var type := clampi(power_up_type, 0, 5)
		_type_counts[type] = int(_type_counts.get(type, 0)) + 1
	return pickup


func get_metrics() -> Dictionary:
	var metrics := super.get_metrics()
	metrics.merge({"spawned": _spawned, "type_counts": _type_counts.duplicate()})
	return metrics


func _on_pickup_collected(value: int, combat_position: Vector3) -> void:
	super._on_pickup_collected(value, combat_position)
	power_up_collected.emit(value, combat_position)
