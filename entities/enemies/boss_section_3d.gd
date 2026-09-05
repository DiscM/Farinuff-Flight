extends Area3D
## Destructible boss weapon pod. Destroying it removes its contribution to volleys.
signal destroyed(combat_position: Vector3)
const Layers := preload("res://systems/native_3d_physics_layers.gd")
var is_active := false
var health := 12

func activate(hit_points: int) -> void:
	health = hit_points
	is_active = true
	collision_layer = Layers.ENEMY_CRAFT
	collision_mask = 0
	monitoring = false
	monitorable = true
	$CollisionShape3D.disabled = false
	show()

func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	health -= amount
	if health <= 0:
		deactivate()
		destroyed.emit(global_position)

func deactivate() -> void:
	is_active = false
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("monitorable", false)
	$CollisionShape3D.set_deferred("disabled", true)
