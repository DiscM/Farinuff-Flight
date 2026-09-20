extends Node3D
## Production hulls and scenery under the game's camera and material adapters.
## R rotates, A articulates, F flashes, S changes material style, T isolates paint.

const SurfaceLibrary := preload("res://effects/rendering/enemy_surface_materials.gd")
const SceneryMaterials := preload("res://effects/rendering/station_debris_materials.gd")
const ENEMY_SCENES := [
	preload("res://entities/enemies/basic_enemy_3d.tscn"),
	preload("res://entities/enemies/fast_enemy_3d.tscn"),
	preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	preload("res://entities/enemies/tank_enemy_3d.tscn"),
	preload("res://entities/enemies/sniper_enemy_3d.tscn"),
]
const ENEMY_TITLES := ["01 / CINDER", "02 / NEEDLE", "03 / MANTIS", "04 / BASTION", "05 / LONGBOW"]
const ENEMY_ROLES := ["BASIC", "FAST", "BOMBER", "TANK", "SNIPER"]
const DEBRIS_IDS := ["relay_fragment", "solar_fragment", "cargo_wreck", "engine_wreck", "hull_fragment", "asteroid_cluster"]
const DEBRIS_TITLES := ["RELAY FRAGMENT", "SOLAR FRAGMENT", "CARGO WRECK", "ENGINE WRECK", "HULL FRAGMENT", "ASTEROID CLUSTER"]
var _enemies: Array[BasicEnemy3D] = []
var _debris: Array[Node3D] = []
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
	for index in ENEMY_SCENES.size():
		var enemy := ENEMY_SCENES[index].instantiate() as BasicEnemy3D
		add_child(enemy)
		enemy.scale = Vector3.ONE * 2.45
		enemy.rotation_degrees.y = -12.0
		_enemies.append(enemy)
		_label(ENEMY_TITLES[index], Vector2(.04 + index * .195, .455), 16, Color("dfebf1"))
		_label(ENEMY_ROLES[index], Vector2(.04 + index * .195, .492), 11, Color("708c9e"))
	for index in DEBRIS_IDS.size():
		var scene := load("res://assets/models/voxel_frontier/meshes/%s.glb" % DEBRIS_IDS[index]) as PackedScene
		var model := scene.instantiate() as Node3D
		add_child(model)
		model.scale = Vector3.ONE * 2.05
		model.rotation_degrees = Vector3(8, -16, 0)
		SceneryMaterials.apply_to(model, .86)
		_debris.append(model)
		_label(DEBRIS_TITLES[index], Vector2(.025 + index * .166, .838), 13, Color("b4cbd8"))
	_label("FARINUFF FLIGHT", Vector2(.035, .03), 13, Color("6bdced"))
	_label("VOXEL FRONTIER", Vector2(.035, .066), 34, Color("e7f4fc"))
	_label("FIVE HOSTILE HULLS  /  SIX SALVAGE FORMS", Vector2(.035, .135), 13, Color("8ca6b9"))
	_label("01—05   COMBAT FLEET", Vector2(.035, .21), 11, Color("5e8197"))
	_label("06—11   ORBITAL SALVAGE", Vector2(.035, .565), 11, Color("5e8197"))
	_status = _label("", Vector2(.035, .94), 12, Color("8ca6b9"))
	_label("R rotate   A attack   F flash   S style   T texture", Vector2(.57, .94), 12, Color("6c879b"))
	_remember_surfaces()
	_update_status()
	_layout()
	get_viewport().size_changed.connect(_layout)
	if "--verify-voxel-textures" in OS.get_cmdline_user_args():
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
	for index in _enemies.size():
		_enemies[index].global_position = _camera.project_position(size * Vector2(.11 + .195 * index, .345), 75)
	for index in _debris.size():
		_debris[index].global_position = _camera.project_position(size * Vector2(.083 + .166 * index, .73), 75)


func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	if _attack_wait > 0.0:
		_attack_wait -= delta
		if _attack_wait <= 0.0:
			for enemy in _enemies:
				enemy.play_motion(&"attack")
	for enemy in _enemies:
		enemy.advance_motion(delta)
		enemy._set_instance_parameter(&"instance_animation_time", _clock)
		enemy._set_instance_parameter(&"instance_flash", _flash)
		if _turning:
			enemy.rotation.y += delta * .3
	if _turning:
		for model in _debris:
			model.rotation.y += delta * .24


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
	# Review toggles duplicate materials; gameplay's immutable cache is untouched.
	_textures_enabled = enabled
	for entry in _original_surfaces:
		var original := entry[2] as ShaderMaterial
		if enabled:
			entry[0].set_surface_override_material(entry[1], original)
		else:
			var isolated := original.duplicate() as ShaderMaterial
			isolated.set_shader_parameter(&"has_albedo_texture", false)
			isolated.set_shader_parameter(&"has_emission_texture", false)
			entry[0].set_surface_override_material(entry[1], isolated)
	_update_status()


func set_review_style(index: int) -> void:
	var retained_textures := _textures_enabled
	set_textures_visible(true)
	_style_index = posmod(index, 3)
	for enemy in _enemies:
		var style: SurfaceLibrary.Style = enemy.surface_style
		if _style_index > 0:
			style = SurfaceLibrary.Style.PIXEL_PLANET if _style_index == 1 else SurfaceLibrary.Style.AUTHORED_ALLOY
		SurfaceLibrary.apply_to(enemy.visuals, style, enemy.surface_pixel_density)
	for model in _debris:
		SurfaceLibrary.apply_to(model, SurfaceLibrary.Style.AUTHORED_ALLOY if _style_index == 2 else SurfaceLibrary.Style.PIXEL_PLANET, 8.0 * model.scale.x)
	_remember_surfaces()
	set_textures_visible(retained_textures)


func _update_status() -> void:
	if _status != null:
		_status.text = "%s   /   UV ATLAS %s" % [["PRODUCTION SHADERS", "PIXEL PLANET", "AUTHORED ALLOY"][_style_index], "ON" if _textures_enabled else "OFF"]


func verify_texture_rendering() -> Dictionary:
	# Compare the same frozen frame with and without the atlas. This checks
	# visible GPU output for every asset, rather than merely bound uniforms.
	set_process(false)
	var output := "res://design/voxel-frontier/godot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "styles": [], "passed": true}
	if DisplayServer.get_name() == "headless":
		return {"passed": false, "reason": "Texture visibility requires a rendered viewport"}
	for style in 3:
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
		for index in 11:
			var anchor := Vector2(.11 + .195 * index, .345) if index < 5 else Vector2(.083 + .166 * (index - 5), .73)
			var half_size := Vector2(.078, .095)
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
			var id: String = ENEMY_ROLES[index].to_lower() if index < 5 else DEBRIS_IDS[index - 5]
			entries.append({"asset": id, "changed_pixels": changed, "passed": changed > 24})
			if changed <= 24:
				report["passed"] = false
		report["styles"].append({"style": ["production", "pixel_planet", "authored_alloy"][style], "assets": entries})
	set_review_style(0)
	set_textures_visible(true)
	var file := FileAccess.open(output + "/texture_visibility.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	set_process(true)
	return report


func _verify_and_quit() -> void:
	var report := await verify_texture_rendering()
	print("VOXEL_TEXTURE_RENDER_PASS" if report.get("passed", false) else "VOXEL_TEXTURE_RENDER_FAIL")
	get_tree().quit(0 if report.get("passed", false) else 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			_turning = not _turning
		KEY_A:
			_attack_wait = .6
			for enemy in _enemies:
				enemy.play_motion(&"windup", .6, true)
		KEY_F:
			_flash = 1.0
		KEY_S:
			set_review_style(_style_index + 1)
		KEY_T:
			set_textures_visible(not _textures_enabled)
