extends Node3D
## Animated boss gallery using the production actor, pods and material bridge.

const BOSS := preload("res://entities/enemies/boss_enemy_3d.tscn")
const POD := preload("res://assets/models/voxel_bosses/meshes/tempest_section.glb")
const Section := preload("res://entities/enemies/boss_section_3d.gd")
const SurfaceLibrary := preload("res://effects/rendering/enemy_surface_materials.gd")
const IDS := ["boss_assault", "boss_bulwark", "boss_tempest", "boss_void_harbinger", "boss_tempest_core", "tempest_section"]
const TITLES := ["ASSAULT COMMANDER", "IRON BULWARK", "TEMPEST", "VOID HARBINGER", "TEMPEST CORE", "WEAPON POD"]
const SUBTITLES := ["WAVE 05 / COMMAND SHIP", "WAVE 10 / SIEGE PLATFORM", "WAVE 15 / STORM ENGINE", "WAVE 25 / ENDLESS REVELATION", "WAVE 20 / EXPEDITION FINALE", "DESTRUCTIBLE SECTION / ENLARGED DETAIL"]
var _bosses: Array = []
var _pod: Section
var _original_surfaces: Array = []
var _turning := false
var _textures_enabled := true
var _style_index := 0
var _clock := 0.0
var _flash := 0.0
var _attack_wait := 0.0
var _previous_hdr_2d := false
var _status: Label
@onready var _camera: Camera3D = $CameraRig3D/ShakeOffset/Camera3D

func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true

func _exit_tree() -> void:
	get_viewport().use_hdr_2d = _previous_hdr_2d

func _ready() -> void:
	for index in 5:
		var boss = BOSS.instantiate()
		add_child(boss)
		boss.variant = index
		boss.scale = Vector3.ONE * 1.42
		boss.rotation_degrees.y = -10.0
		for hull_index in boss.visuals.get_child_count():
			boss.visuals.get_child(hull_index).visible = hull_index == index
		for section in boss._sections:
			if index > 0:
				section.activate(100)
				section._target_label.hide()
			else:
				section.deactivate()
		boss._sync_motion_sockets()
		_bosses.append(boss)
	_pod = Section.new()
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	collision.shape = sphere
	collision.disabled = true
	_pod.add_child(collision)
	var model := POD.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * .4
	_pod.add_child(model)
	add_child(_pod)
	_pod.scale = Vector3.ONE * 5.0
	_pod.rotation_degrees.y = -10.0
	_pod.activate(100)
	_pod._target_label.hide()
	_label("FARINUFF FLIGHT / VOXEL FRONTIER", Vector2(.035, .025), 12, Color("6bdced"))
	_label("CAPITAL THREATS", Vector2(.035, .06), 32, Color("e7f4fc"))
	_label("FIVE BOSS SILHOUETTES  /  RIGID ARTICULATION  /  DESTRUCTIBLE WEAPON PODS", Vector2(.035, .124), 11, Color("8ca6b9"))
	for index in 6:
		var anchor := Vector2(.035 + .33 * (index % 3), .48 if index < 3 else .87)
		_label("%02d / %s" % [index + 1, TITLES[index]], anchor, 16, Color("dfebf1"))
		_label(SUBTITLES[index], anchor + Vector2(0,.039), 10, Color("708c9e"))
	_status = _label("", Vector2(.035, .958), 11, Color("8ca6b9"))
	_label("R rotate   A attack   F flash   S style   T texture", Vector2(.57, .958), 11, Color("6c879b"))
	_remember_surfaces()
	_update_status()
	_layout()
	get_viewport().size_changed.connect(_layout)
	if "--verify-boss-textures" in OS.get_cmdline_user_args():
		_verify_and_quit.call_deferred()

func _label(content: String, anchor: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.anchor_left = anchor.x
	label.anchor_top = anchor.y
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", tint)
	$Labels.add_child(label)
	return label

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	for index in _bosses.size():
		_bosses[index].global_position = _camera.project_position(size * _anchor(index), 75)
	_pod.global_position = _camera.project_position(size * _anchor(5), 75)

func _anchor(index: int) -> Vector2:
	return Vector2(.17 + .33 * (index % 3), .335 if index < 3 else .725)

func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	if _attack_wait > 0.0:
		_attack_wait -= delta
		if _attack_wait <= 0.0:
			for boss in _bosses:
				boss.play_motion(&"attack")
			_pod.play_motion(&"attack")
	for boss in _bosses:
		boss.advance_motion(delta)
		boss._set_instance_parameter(&"instance_animation_time", _clock)
		boss._set_instance_parameter(&"instance_flash", _flash)
		if _turning:
			boss.rotation.y += delta * .24
	_pod.advance_motion(delta)
	if _turning:
		_pod.rotation.y += delta * .24

func _remember_surfaces() -> void:
	_original_surfaces.clear()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as ShaderMaterial
			if material != null and material.shader in [SurfaceLibrary.PIXEL_SHADER, SurfaceLibrary.ALLOY_SHADER]:
				_original_surfaces.append([mesh, index, material])

func set_textures_visible(enabled: bool) -> void:
	_textures_enabled = enabled
	for entry in _original_surfaces:
		if enabled:
			entry[0].set_surface_override_material(entry[1], entry[2])
		else:
			var isolated := (entry[2] as ShaderMaterial).duplicate() as ShaderMaterial
			isolated.set_shader_parameter(&"has_albedo_texture", false)
			isolated.set_shader_parameter(&"has_emission_texture", false)
			entry[0].set_surface_override_material(entry[1], isolated)
	_update_status()

func set_review_style(index: int) -> void:
	var retained_textures := _textures_enabled
	set_textures_visible(true)
	_style_index = posmod(index, 2)
	var style: SurfaceLibrary.Style = SurfaceLibrary.Style.PIXEL_PLANET if _style_index == 0 else SurfaceLibrary.Style.AUTHORED_ALLOY
	for boss in _bosses:
		SurfaceLibrary.apply_to(boss.visuals, style, boss.surface_pixel_density)
		for section in boss._sections:
			SurfaceLibrary.apply_to(section.get_node("Model") as Node3D, style, 3.2)
	SurfaceLibrary.apply_to(_pod.get_node("Model") as Node3D, style, 3.2)
	_remember_surfaces()
	set_textures_visible(retained_textures)

func _update_status() -> void:
	if _status != null:
		_status.text = "%s   /   UV ATLAS %s" % [["PRODUCTION / PIXEL PLANET", "AUTHORED ALLOY"][_style_index], "ON" if _textures_enabled else "OFF"]

func verify_texture_rendering() -> Dictionary:
	set_process(false)
	var output := "res://design/voxel-bosses/godot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "styles": [], "passed": true}
	if DisplayServer.get_name() == "headless":
		return {"passed": false, "reason": "Texture visibility requires a rendered viewport"}
	for style in 2:
		set_review_style(style)
		set_textures_visible(true)
		for frame in 5:
			await RenderingServer.frame_post_draw
		var textured := get_viewport().get_texture().get_image()
		textured.save_png(output + "/style_%d_textured.png" % style)
		set_textures_visible(false)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var plain := get_viewport().get_texture().get_image()
		plain.save_png(output + "/style_%d_untextured.png" % style)
		var entries: Array = []
		for index in 6:
			var anchor := _anchor(index)
			var half_size := Vector2(.14, .13)
			var size := Vector2(textured.get_size())
			var region := Rect2i(Vector2i((anchor - half_size) * size), Vector2i(half_size * size * 2.0))
			region = region.intersection(Rect2i(Vector2i.ZERO, textured.get_size()))
			var changed := 0
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					var a := textured.get_pixel(x, y)
					var b := plain.get_pixel(x, y)
					if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > .015:
						changed += 1
			entries.append({"asset": IDS[index], "changed_pixels": changed, "passed": changed > 24})
			if changed <= 24:
				report["passed"] = false
		report["styles"].append({"style": ["production_pixel_planet", "authored_alloy"][style], "assets": entries})
	set_review_style(0)
	set_textures_visible(true)
	var file := FileAccess.open(output + "/texture_visibility.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	set_process(true)
	return report

func _verify_and_quit() -> void:
	var report := await verify_texture_rendering()
	print("VOXEL_BOSS_TEXTURE_RENDER_PASS" if report.get("passed", false) else "VOXEL_BOSS_TEXTURE_RENDER_FAIL")
	get_tree().quit(0 if report.get("passed", false) else 1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			_turning = not _turning
		KEY_A:
			_attack_wait = .6
			for boss in _bosses:
				boss.play_motion(&"windup", .6, true)
			_pod.play_motion(&"windup", .6, true)
		KEY_F:
			_flash = 1.0
			_pod.take_damage(1)
		KEY_S:
			set_review_style(_style_index + 1)
		KEY_T:
			set_textures_visible(not _textures_enabled)
