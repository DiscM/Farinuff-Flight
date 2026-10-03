extends "res://systems/pickup_pool_3d.gd"
class_name XPOrbManager3D
## XP collection retains the existing global progression authority.

signal xp_orb_collected(orb_value: int, combat_position: Vector3)
const XP_ORB_SCENE := preload("res://entities/collectibles/xp_orb_3d.tscn")
const XPOrb := preload("res://entities/collectibles/xp_orb_3d.gd")


func _pickup_scene() -> PackedScene:
	return XP_ORB_SCENE


func spawn_xp_orb(combat_position: Vector3, value: int, drift_direction: Vector3 = Vector3.BACK) -> XPOrb:
	return _spawn_pickup(combat_position, value, drift_direction) as XPOrb


func _on_pickup_collected(value: int, combat_position: Vector3) -> void:
	super._on_pickup_collected(value, combat_position)
	AudioManager.play_xp_orb()
	SignalBus.xp_orb_collected.emit(value)
	xp_orb_collected.emit(value, combat_position)
