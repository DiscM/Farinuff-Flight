extends Native3DGameplay
## Imported boss hulls, variant-safe sockets and synchronized destructible pods.

const BOSS := preload("res://entities/enemies/boss_enemy_3d.tscn")
const Surfaces := preload("res://effects/rendering/enemy_surface_materials.gd")
const Motion := preload("res://effects/ship_motion_3d.gd")
const IDS := ["boss_assault", "boss_bulwark", "boss_tempest", "boss_void_harbinger", "boss_tempest_core"]
const WAVES := [5, 10, 15, 25, 20]
var _failures: Array[String] = []

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	for index in IDS.size():
		await _check_variant(index)
	for failure in _failures:
		push_error(failure)
	print("VOXEL_BOSS_MATERIAL_SMOKE_PASS" if _failures.is_empty() else "VOXEL_BOSS_MATERIAL_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_variant(index: int) -> void:
	var boss = BOSS.instantiate()
	actors_root.add_child(boss)
	GameManager.current_wave = WAVES[index]
	_expect(boss.activate_generation(flight_space, Vector3(12,0,-6), Vector3.BACK, 1), IDS[index] + " activates")
	boss.set_physics_process(false)
	_expect(boss.variant == index, IDS[index] + " retains its wave selection")
	_expect(boss._motions.size() == 5, "Five boss hull rigs remain independently selectable")
	var model := boss.visuals.get_child(index) as Node3D
	_expect(model.scene_file_path == "res://assets/models/voxel_bosses/meshes/%s.glb" % IDS[index], IDS[index] + " uses the packaged voxel GLB")
	_expect(model.scale.is_equal_approx(Vector3.ONE * 1.6), IDS[index] + " uses the enlarged combat hull scale")
	_expect(boss.scale.is_equal_approx(Vector3.ONE), "Boss actor transform remains unit-scaled")
	_expect(boss.collision_shape.shape.size.is_equal_approx(Vector3(10.88, 1.0, 9.92)), "Boss target envelope follows the enlarged hull independently of its rig")
	_check_surfaces(model, IDS[index])
	var motion: Motion = boss._motions[index]
	_check_rig(motion, IDS[index])
	var hull_collision: Transform3D = boss.collision_shape.global_transform
	var hull_size: Vector3 = boss.collision_shape.shape.size
	var wing_rest := motion.skeleton.get_bone_pose_rotation(1)
	var pod_collisions: Array[Transform3D] = []
	for section in boss._sections:
		pod_collisions.append(section.get_node("CollisionShape3D").global_transform)
		_expect((section.get_node("Model") as Node3D).scene_file_path == "res://assets/models/voxel_bosses/meshes/tempest_section.glb", "Destructible sections use the voxel pod")
		_expect(section.get_node("Model").scale.is_equal_approx(Vector3.ONE * .64), "Pod model follows the enlarged boss proportions")
		_expect(is_equal_approx(section.get_node("CollisionShape3D").shape.radius,2.56), "Pod target envelope follows its enlarged model")
		_expect(is_equal_approx(absf(section.position.x), 9.28) and section.scale.is_equal_approx(Vector3.ONE), "Pod attachment clears the enlarged hull without scaling the actor transform")
		_check_surfaces(section.get_node("Model") as Node3D, "weapon pod")
		_check_rig(section._motion, "weapon pod")
	boss.play_motion(&"windup", .6, true)
	for step in 40:
		boss.advance_motion(1.0/60.0)
	_expect(wing_rest.angle_to(motion.skeleton.get_bone_pose_rotation(1)) > .07, IDS[index] + " visibly articulates its attack anticipation")
	_expect(motion.current_clip == &"windup", "Hull holds its anticipation until the attack release")
	boss.play_motion(&"hit")
	_expect(motion.current_clip == &"windup", "Damage never hides a boss attack tell")
	# The last hidden variant deliberately enters another pose. It must not
	# overwrite the selected hull's wrapper muzzle, including after visual yaw.
	var hidden_index := (index + 1) % IDS.size()
	boss._motions[hidden_index].play(&"attack")
	boss._motions[hidden_index].advance(.1)
	boss.visuals.rotation.y = .47
	boss._sync_motion_sockets()
	var muzzle := model.find_child("Socket_Muzzle", true, false) as Node3D
	_expect(muzzle != null, IDS[index] + " contains the production muzzle socket")
	if muzzle != null:
		_expect(boss.get_socket(&"MuzzleCenter").global_transform.is_equal_approx(Motion.socket_transform(muzzle)), "Selected animated hull alone supplies the shared muzzle")
	_expect(boss.collision_shape.global_transform.is_equal_approx(hull_collision) and boss.collision_shape.shape.size == hull_size, "Hull articulation and visual yaw leave collision geometry unchanged")
	for pod_index in boss._sections.size():
		var section = boss._sections[pod_index]
		_expect(section.get_node("CollisionShape3D").global_transform.is_equal_approx(pod_collisions[pod_index]), "Weapon pod articulation leaves its collider fixed")
		if section.is_active:
			_expect(section._motion.current_clip == &"windup", "Active pods hold the same attack anticipation as their boss")
	boss.play_motion(&"attack")
	_expect(motion.current_clip == &"attack", "Boss release starts its authored attack clip")
	for section in boss._sections:
		if section.is_active:
			_expect(section._motion.current_clip == &"attack", "Boss release synchronizes its active pods")
	for step in 90:
		boss.advance_motion(1.0/60.0)
	_expect(motion.current_clip == &"cruise", "Boss returns to its cruise motion after release")
	if index > 0:
		await _check_pod_feedback_and_retirement(boss)
	var held_time := motion.animation_player.current_animation_position
	GameManager.is_game_active = false
	boss._physics_process(.15)
	_expect(is_equal_approx(held_time,motion.animation_player.current_animation_position), "Inactive gameplay freezes the boss clock")
	GameManager.is_game_active = true
	boss.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _check_pod_feedback_and_retirement(boss: BasicEnemy3D) -> void:
	var sections: Array = boss.get("_sections")
	var first = sections[0]
	var second = sections[1]
	_expect(first._meshes[0].get_active_material(0) == second._meshes[0].get_active_material(0), "Twin pods share immutable material conversions")
	first.take_damage(1)
	boss.advance_motion(.04)
	_expect(float(first._meshes[0].get_instance_shader_parameter(&"instance_flash")) > .0, "The damaged pod flashes")
	_expect(is_zero_approx(float(second._meshes[0].get_instance_shader_parameter(&"instance_flash"))), "A damaged pod never flashes its peer")
	first.take_damage(99999)
	var stopped_time: float = first._animation_time
	boss.advance_motion(.2)
	_expect(not first.is_active and not first.visible, "Destroyed pod retires visually and logically")
	_expect(is_equal_approx(stopped_time,first._animation_time), "Destroyed pod stops animation and reactor clocks")
	_expect(boss.call("_active_section_count") == 1, "Destroying one pod preserves the other pod's fire contribution")
	await get_tree().process_frame
	await get_tree().process_frame
	first.activate(20)
	_expect(first._motion.current_clip == &"cruise" and is_zero_approx(first._animation_time), "Reactivated pod begins from its authored cruise pose")
	_expect(is_zero_approx(float(first._meshes[0].get_instance_shader_parameter(&"instance_flash"))), "Reactivated pod clears stale hit feedback")

func _check_rig(motion: Motion, label: String) -> void:
	_expect(motion != null and motion.skeleton != null, label + " imports its Blender rigid rig")
	if motion == null or motion.skeleton == null:
		return
	_expect(motion.skeleton.get_bone_count() == 4, label + " retains four rigid bones")
	for bone_name in ["Body", "Port", "Starboard", "Weapon"]:
		_expect(motion.skeleton.find_bone(bone_name) >= 0, label + " retains bone " + bone_name)
	for clip in [&"cruise", &"windup", &"attack", &"hit"]:
		_expect(motion._clips.has(clip), label + " imports clip " + String(clip))

func _check_surfaces(model: Node3D, label: String) -> void:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	_expect(meshes.size() >= 4 and meshes.size() <= 8, label + " uses a bounded mesh count")
	var emitted := false
	var painted := false
	for node in meshes:
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			_expect(not uv.is_empty() and uv.size() == vertices.size(), label + " retains UVs on every vertex")
			var material := mesh.get_active_material(surface) as ShaderMaterial
			_expect(material != null and material.shader == Surfaces.PIXEL_SHADER, label + " uses the production pixel shader")
			if material == null:
				continue
			var atlas := material.get_shader_parameter(&"albedo_texture") as Texture2D
			_expect(atlas != null and material.get_shader_parameter(&"has_albedo_texture") == true, label + " samples its authored atlas")
			var color: Color = material.get_shader_parameter(&"base_color")
			painted = painted or (color.s > .25 and color.v > .3)
			emitted = emitted or float(material.get_shader_parameter(&"emission_strength")) > .0
	_expect(painted, label + " preserves colored paint beneath the atlas")
	_expect(emitted, label + " retains authored reactor emission")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
