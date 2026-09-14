extends Native3DGameplay
## Selected scenes, immutable conversion reuse, actor-local grids and feedback.

const SurfaceLibrary := preload("res://effects/rendering/enemy_surface_materials.gd")
const BASIC := preload("res://entities/enemies/basic_enemy_3d.tscn")
var _failures: Array[String] = []


func _ready() -> void:
	await super._ready()
	player.set_physics_process(false)
	await _check_material_sharing_and_feedback()
	for failure in _failures:
		push_error(failure)
	print("PIXEL_ENEMY_MATERIAL_SMOKE_PASS" if _failures.is_empty() else "PIXEL_ENEMY_MATERIAL_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_material_sharing_and_feedback() -> void:
	var first := BASIC.instantiate() as BasicEnemy3D
	var second := BASIC.instantiate() as BasicEnemy3D
	var alloy := BASIC.instantiate() as BasicEnemy3D
	alloy.surface_style = SurfaceLibrary.Style.AUTHORED_ALLOY
	for enemy in [first, second, alloy]:
		actors_root.add_child(enemy)
	var material := first._meshes[0].get_active_material(0) as ShaderMaterial
	_expect(material == second._meshes[0].get_active_material(0), "Matching enemies reuse the same immutable material")
	_expect(material != alloy._meshes[0].get_active_material(0), "Alloy and pixel conversions do not contaminate each other")
	_expect(material.shader == SurfaceLibrary.PIXEL_SHADER, "Basic scene selects pixel armor")
	_expect((alloy._meshes[0].get_active_material(0) as ShaderMaterial).shader == SurfaceLibrary.ALLOY_SHADER, "Explicit alloy scene override is honored")
	# Switching a review's style resolves the original GLB source, not a converted
	# material with missing PBR fields, and switching back reuses the same object.
	SurfaceLibrary.apply_to(first.visuals, SurfaceLibrary.Style.AUTHORED_ALLOY)
	_expect(first._meshes[0].get_active_material(0) == alloy._meshes[0].get_active_material(0), "Style switch reuses original authored source")
	SurfaceLibrary.apply_to(first.visuals, SurfaceLibrary.Style.PIXEL_PLANET)
	_expect(first._meshes[0].get_active_material(0) == material, "Switching back retains cached pixel conversion")
	for mesh in first._meshes:
		var local_point := Vector3(0.3, 0.2, -0.4)
		var homogeneous := Vector4(local_point.x, local_point.y, local_point.z, 1.0)
		var x: Vector4 = mesh.get_instance_shader_parameter(&"instance_hull_row_x")
		var y: Vector4 = mesh.get_instance_shader_parameter(&"instance_hull_row_y")
		var z: Vector4 = mesh.get_instance_shader_parameter(&"instance_hull_row_z")
		var mapped := Vector3(x.dot(homogeneous), y.dot(homogeneous), z.dot(homogeneous))
		first.position = Vector3(3.0, 0.0, 2.0)
		first.rotation.y = 1.3
		var expected := first.visuals.to_local(mesh.to_global(local_point))
		_expect(mapped.is_equal_approx(expected), "Pixel grid follows translated/rotated hull, including transformed GLB parts")
	_expect(first.activate_generation(flight_space, Vector3(-12, 0, 0), Vector3.FORWARD, 4), "Pixel enemy activates with generation feedback")
	_expect(second.activate_generation(flight_space, Vector3(12, 0, 0), Vector3.FORWARD, 2), "Shared-material peer activates at a different generation")
	var first_energy: Color = first._meshes[0].get_instance_shader_parameter(&"instance_energy_override")
	var second_energy: Color = second._meshes[0].get_instance_shader_parameter(&"instance_energy_override")
	_expect(first_energy != second_energy, "Generation colors remain per actor")
	first.take_damage(1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(float(first._meshes[0].get_instance_shader_parameter(&"instance_flash")) > 0.0, "Damage flashes the struck pixel enemy")
	_expect(is_zero_approx(float(second._meshes[0].get_instance_shader_parameter(&"instance_flash"))), "Damage never flashes the shared-material peer")
	get_tree().paused = true
	var stopped_time: float = first._meshes[0].get_instance_shader_parameter(&"instance_animation_time")
	await get_tree().create_timer(0.08, true).timeout
	_expect(is_equal_approx(stopped_time, float(first._meshes[0].get_instance_shader_parameter(&"instance_animation_time"))), "Pause freezes the reactor clock")
	get_tree().paused = false
	await get_tree().create_timer(0.2).timeout
	_expect(is_zero_approx(float(first._meshes[0].get_instance_shader_parameter(&"instance_flash"))), "Hit flash expires")
	for enemy in [first, second, alloy]:
		enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
