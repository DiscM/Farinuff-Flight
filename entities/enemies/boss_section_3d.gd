extends Area3D
## Destructible boss weapon pod. Destroying it removes its contribution to volleys.
signal destroyed(combat_position: Vector3)
const Layers := preload("res://systems/native_3d_physics_layers.gd")
var is_active := false
var health := 12
var _target_label: Label3D

func activate(hit_points: int) -> void:
	health = hit_points
	if _target_label == null:
		_target_label = Label3D.new()
		_target_label.text = "◇ WEAPON POD"
		_target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_target_label.font_size = 28
		_target_label.pixel_size = 0.012
		_target_label.position.y = 1.2
		_target_label.modulate = Color(1.0, 0.85, 0.25)
		add_child(_target_label)
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
	if _target_label != null:
		_target_label.text = "◇ POD · %d" % maxi(health, 0)
	if health <= 0:
		deactivate()
		destroyed.emit(global_position)

func deactivate() -> void:
	is_active = false
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("monitorable", false)
	$CollisionShape3D.set_deferred("disabled", true)
