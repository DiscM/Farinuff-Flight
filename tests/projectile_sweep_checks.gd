extends RefCounted
## Isolated physics regressions for ignored fields and deferred death colliders.

const ProjectileScene := preload("res://entities/projectiles/player_projectile_3d.tscn")
const PlateScene := preload("res://entities/enemies/tank_plate_3d.tscn")
const Pod := preload("res://entities/enemies/boss_section_3d.gd")
const Layers := preload("res://systems/native_3d_physics_layers.gd")
var _world: Node3D
var _failures: Array[String] = []

class Target extends Area3D:
	var is_active := true
	var damage_received := 0

	func take_damage(amount: int) -> void:
		if is_active:
			damage_received += amount


func run(owner: Node) -> Array[String]:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	owner.add_child(viewport)
	_world = Node3D.new()
	viewport.add_child(_world)
	var target := Target.new()
	_shape(target, 2.0, Layers.ENEMY_CRAFT)
	var fields: Array[Area3D] = []
	for z in [-2.0, 0.0]:
		var field := Area3D.new()
		_shape(field, z, Layers.HOSTILE_ORDNANCE)
		fields.append(field)
	var shot := _projectile()
	await _physics_ready(owner)
	shot._sweep_motion(Vector3(0, 0, 10))
	_expect(target.damage_received == 1, "Shots sweep past multiple plasma fields to a live target")
	for field in fields:
		field.queue_free()
	target.queue_free()
	shot.queue_free()
	await owner.get_tree().process_frame

	# Both sweeps occur before deferred physics disabling can run.
	for use_pod in [false, true]:
		var armor: Area3D
		if use_pod:
			armor = Pod.new()
			var model := Node3D.new()
			model.name = "Model"
			armor.add_child(model)
			_shape(armor, 0.0, Layers.ENEMY_CRAFT)
			armor.activate(1)
		else:
			armor = PlateScene.instantiate()
			_world.add_child(armor)
			armor.is_active = true
			armor._set_collision_active(true)
			armor.force_update_transform()
		target = Target.new()
		_shape(target, 2.0, Layers.ENEMY_CRAFT)
		var first := _projectile()
		var second := _projectile()
		await _physics_ready(owner)
		first._sweep_motion(Vector3(0, 0, 10))
		second._sweep_motion(Vector3(0, 0, 10))
		_expect(not armor.is_active, "First volley shot destroys armor")
		_expect(target.damage_received == 1, "Second volley shot passes the destroyed plate/pod")
		armor.queue_free()
		target.queue_free()
		first.queue_free()
		second.queue_free()
		await owner.get_tree().process_frame

	target = Target.new()
	target.is_active = false
	_shape(target, 0.0, Layers.ENEMY_CRAFT)
	shot = _projectile()
	await _physics_ready(owner)
	shot._report_hit(target, Vector3.ZERO)
	_expect(shot.is_active, "Inactive overlap does not absorb a shot")
	shot._sweep_motion(Vector3(0, 0, 10))
	_expect(shot.is_active, "Inactive sweep does not absorb a shot")
	target.is_active = true
	shot._sweep_motion(Vector3(0, 0, 10))
	_expect(target.damage_received == 1, "Ignored collider is eligible again after pooled reactivation")
	viewport.queue_free()
	await owner.get_tree().process_frame
	return _failures


func _shape(area: Area3D, z: float, layer: int) -> void:
	area.collision_layer = layer
	area.collision_mask = 0
	area.monitoring = false
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	collision.shape = sphere
	area.add_child(collision)
	_world.add_child(area)
	area.position.z = z
	area.force_update_transform()


func _projectile() -> Projectile3D:
	var shot := ProjectileScene.instantiate() as Projectile3D
	_world.add_child(shot)
	shot.pool_activate(Vector3(0, 0, -5), Vector3(0, 0, 600), Rect2(-100, -100, 200, 200))
	shot.set_physics_process(false)
	shot.hit.connect(func(target: Area3D, _position: Vector3): target.take_damage(1))
	return shot


func _physics_ready(owner: Node) -> void:
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
