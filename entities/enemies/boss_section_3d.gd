extends Area3D
## Destructible boss weapon pod. Destroying it removes its contribution to volleys.
signal destroyed(combat_position: Vector3)
const Layers := preload("res://systems/native_3d_physics_layers.gd")
const SurfaceMaterials := preload("res://effects/rendering/enemy_surface_materials.gd")
const Motion := preload("res://effects/ship_motion_3d.gd")
var is_active := false
var health := 12
var _target_label: Label3D
var _motion: Motion
var _meshes: Array[MeshInstance3D] = []
var _animation_time := 0.0
var _flash_time_left := 0.0

func _ready() -> void:
	var model := $Model as Node3D
	SurfaceMaterials.apply_to(model, SurfaceMaterials.Style.PIXEL_PLANET, 8.0 * model.scale.x)
	if model.find_child("AnimationPlayer", true, false) != null:
		_motion = Motion.new(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	_set_feedback(&"instance_flash", 0.0)
	_set_feedback(&"instance_animation_time", 0.0)

func can_deal_contact_damage() -> bool:
	return false # The parent boss owns explicitly telegraphed hit resolution.

func activate(hit_points: int) -> void:
	health = hit_points
	_animation_time = 0.0
	_flash_time_left = 0.0
	_set_feedback(&"instance_flash", 0.0)
	_set_feedback(&"instance_animation_time", 0.0)
	if _motion != null:
		_motion.reset()
	if _target_label == null:
		_target_label = Label3D.new()
		_target_label.text = "◇ WEAPON POD"
		_target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_target_label.font_size = 28
		_target_label.pixel_size = 0.012
		_target_label.position.y = $CollisionShape3D.shape.radius * .75
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
	_flash_time_left = 0.15
	play_motion(&"hit")
	if _target_label != null:
		_target_label.text = "◇ POD · %d" % maxi(health, 0)
	if health <= 0:
		deactivate()
		destroyed.emit(global_position)

func deactivate() -> void:
	is_active = false
	_flash_time_left = 0.0
	_set_feedback(&"instance_flash", 0.0)
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("monitorable", false)
	$CollisionShape3D.set_deferred("disabled", true)

func play_motion(clip: StringName, seconds: float = 0.0, hold: bool = false) -> void:
	if is_active and _motion != null:
		_motion.play(clip, seconds, hold)

func advance_motion(delta: float) -> void:
	# The boss's physics clock owns this; no second timer advances a pod while
	# combat is paused or after it has been destroyed. Its collider never moves.
	if not is_active:
		return
	if _motion != null:
		_motion.advance(delta)
	_animation_time += delta
	_set_feedback(&"instance_animation_time", _animation_time)
	_flash_time_left = maxf(0.0, _flash_time_left - delta)
	var flash := (0.15 - _flash_time_left) / 0.05 if _flash_time_left > 0.1 else _flash_time_left / 0.1
	_set_feedback(&"instance_flash", clampf(flash, 0.0, 1.0))

func _set_feedback(parameter: StringName, value: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(parameter, value)
