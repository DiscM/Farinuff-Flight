extends Node3D
## In-engine look-development board for marrying the GLB mockups to Farinuff
## Flight's existing neon evolution, galaxy, projectile, and CRT treatments.

const PLAYER_MODEL: PackedScene = preload("res://assets/models/mockups/player_ship_mockup.glb")
const BASIC_MODEL: PackedScene = preload("res://assets/models/mockups/basic_enemy_mockup.glb")
const FAST_MODEL: PackedScene = preload("res://assets/models/mockups/fast_enemy_mockup.glb")
const BOMBER_MODEL: PackedScene = preload("res://assets/models/mockups/bomber_enemy_mockup.glb")
const TANK_MODEL: PackedScene = preload("res://assets/models/mockups/tank_enemy_mockup.glb")
const SNIPER_MODEL: PackedScene = preload("res://assets/models/mockups/sniper_enemy_mockup.glb")

const SHIP_SHADER: Shader = preload("res://effects/shaders/models/neon_ship_3d.gdshader")
const OUTLINE_SHADER: Shader = preload("res://effects/shaders/models/neon_outline_3d.gdshader")
const CRT_SHADER: Shader = preload("res://effects/shaders/crt_overlay.gdshader")

const CAPTURE_ROOT := "res://assets/models/mockups/shader_previews/"
const MODES := [&"gameplay", &"evolution", &"fleet"]

const CYAN := Color(0.02, 0.72, 1.0)
const ICE := Color(0.76, 0.95, 1.0)
const RED := Color(1.0, 0.035, 0.12)
const ORANGE := Color(1.0, 0.28, 0.025)
const LIME := Color(0.38, 1.0, 0.12)
const VIOLET := Color(0.65, 0.10, 1.0)
const MAGENTA := Color(1.0, 0.04, 0.52)

@onready var fleet: Node3D = $Fleet
@onready var camera: Camera3D = $Camera3D
@onready var galaxy_floor: MeshInstance3D = $GalaxyFloor
@onready var grid_floor: MeshInstance3D = $GridFloor

var _mode: StringName = &"gameplay"
var _capture_requested := false
var _ui_layer: CanvasLayer
var _crt_layer: CanvasLayer
var _animated_models: Array[Node3D] = []


func _ready() -> void:
	_parse_arguments()
	_build_mockup(_mode)
	_build_ui(_mode)
	_build_crt_overlay()

	if OS.get_cmdline_user_args().has("--shader-mockup-smoke"):
		await get_tree().process_frame
		_run_smoke_check()
		return

	if _capture_requested:
		# Give the imported meshes, shaders, and screen-texture post pass enough
		# frames to settle before reading the viewport.
		for frame in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_capture_mockup()


func _process(delta: float) -> void:
	if _capture_requested:
		return
	for index in range(_animated_models.size()):
		var model := _animated_models[index]
		if is_instance_valid(model):
			model.position.y = sin(Time.get_ticks_msec() * 0.0016 + index * 0.7) * 0.055
			model.rotation.y += delta * (0.055 if _mode == &"fleet" else 0.015)


func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == "--shader-mockup-capture":
			_capture_requested = true
			if index + 1 < args.size() and StringName(args[index + 1]) in MODES:
				_mode = StringName(args[index + 1])
		elif args[index].begins_with("--shader-mockup="):
			var candidate := StringName(args[index].trim_prefix("--shader-mockup="))
			if candidate in MODES:
				_mode = candidate


func _build_mockup(mode: StringName) -> void:
	match mode:
		&"evolution":
			_build_evolution_mockup()
		&"fleet":
			_build_fleet_mockup()
		_:
			_build_gameplay_mockup()


func _build_gameplay_mockup() -> void:
	camera.size = 12.4
	camera.position = Vector3(0.0, 11.9, 7.5)
	camera.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	_set_floor_palette(Color(0.02, 0.30, 0.82), Color(0.08, 0.10, 0.54), Color(0.12, 0.68, 0.90))

	var player := _spawn_ship(
		PLAYER_MODEL,
		"Player",
		Vector3(0.0, 0.0, 3.5),
		Vector3(1.08, 1.08, 1.08),
		CYAN,
		ICE,
		0.38,
		0.38,
		0.0,
		0.0,
		0.4
	)
	_add_engine_trails(player, CYAN, 1.35)
	_add_target_ring(Vector3(0.0, -0.52, 3.5), CYAN, 1.08)

	var basic := _spawn_ship(BASIC_MODEL, "Basic", Vector3(-3.8, 0.0, -2.7), Vector3.ONE, RED, Color(1.0, 0.58, 0.68), 0.42, 0.52, 0.05, 0.0, 1.1)
	var fast := _spawn_ship(FAST_MODEL, "Fast", Vector3(0.0, 0.0, -3.45), Vector3(0.94, 0.94, 0.94), ORANGE, Color(1.0, 0.88, 0.38), 0.62, 0.68, 0.16, 0.04, 2.2)
	var sniper := _spawn_ship(SNIPER_MODEL, "Sniper", Vector3(3.8, 0.0, -2.7), Vector3.ONE, CYAN, Color(0.72, 0.96, 1.0), 0.82, 0.84, 0.26, 0.34, 3.4)
	_add_engine_trails(basic, RED, 0.8)
	_add_engine_trails(fast, ORANGE, 1.35)
	_add_engine_trails(sniper, CYAN, 0.95)
	_add_targeting_beam(Vector3(3.8, 0.10, -4.8), 4.2, CYAN)

	_add_energy_bolt(Vector3(-1.15, 0.18, 1.8), CYAN, 1.0)
	_add_energy_bolt(Vector3(1.10, 0.18, 0.55), CYAN, 0.78)
	_add_energy_bolt(Vector3(-2.85, 0.12, -0.55), RED, 0.62)


func _build_evolution_mockup() -> void:
	camera.size = 11.2
	camera.position = Vector3(0.0, 10.8, 7.0)
	camera.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	_set_floor_palette(Color(0.08, 0.18, 0.72), Color(0.20, 0.05, 0.55), Color(0.72, 0.08, 0.48))

	var positions := [-5.25, -1.75, 1.75, 5.25]
	var energy_colors := [CYAN, Color(0.18, 0.62, 1.0), ORANGE, MAGENTA]
	var accent_colors := [ICE, Color(0.62, 0.92, 1.0), Color(1.0, 0.78, 0.28), Color(1.0, 0.72, 0.94)]
	var circuits := [0.08, 0.48, 0.72, 0.92]
	var heats := [0.0, 0.05, 0.72, 0.58]
	var apexes := [0.0, 0.0, 0.08, 0.92]

	for index in range(4):
		var ship := _spawn_ship(
			BASIC_MODEL,
			"Generation%d" % (index + 1),
			Vector3(positions[index], 0.0, 0.25),
			Vector3(1.22, 1.22, 1.22),
			energy_colors[index],
			accent_colors[index],
			float(index) / 3.0,
			circuits[index],
			heats[index],
			apexes[index],
			float(index) * 2.17
		)
		_add_engine_trails(ship, energy_colors[index], 0.72 + index * 0.18)
		_add_target_ring(Vector3(positions[index], -0.52, 0.25), energy_colors[index], 1.02 + index * 0.05)


func _build_fleet_mockup() -> void:
	camera.size = 11.8
	camera.position = Vector3(0.0, 11.4, 7.4)
	camera.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	_set_floor_palette(Color(0.04, 0.26, 0.76), Color(0.16, 0.07, 0.60), Color(0.42, 0.11, 0.78))

	var entries := [
		[PLAYER_MODEL, "Player", Vector3(-4.4, 0.0, -2.55), CYAN, ICE, 0.25],
		[BASIC_MODEL, "Basic", Vector3(0.0, 0.0, -2.55), RED, Color(1.0, 0.58, 0.68), 0.45],
		[FAST_MODEL, "Fast", Vector3(4.4, 0.0, -2.55), ORANGE, Color(1.0, 0.86, 0.28), 0.65],
		[BOMBER_MODEL, "Bomber", Vector3(-4.4, 0.0, 2.45), LIME, Color(0.78, 1.0, 0.44), 0.55],
		[TANK_MODEL, "Tank", Vector3(0.0, 0.0, 2.45), VIOLET, Color(0.92, 0.64, 1.0), 0.76],
		[SNIPER_MODEL, "Sniper", Vector3(4.4, 0.0, 2.45), CYAN, Color(0.74, 0.98, 1.0), 0.88],
	]
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var ship := _spawn_ship(
			entry[0] as PackedScene,
			entry[1] as String,
			entry[2] as Vector3,
			Vector3(0.93, 0.93, 0.93),
			entry[3] as Color,
			entry[4] as Color,
			entry[5] as float,
			0.34 + float(index) * 0.08,
			0.15 if index >= 3 else 0.02,
			0.18 if index == 4 or index == 5 else 0.0,
			float(index) * 1.31
		)
		ship.rotation.y = deg_to_rad(-7.0 + float(index % 3) * 7.0)
		_add_target_ring((entry[2] as Vector3) + Vector3(0.0, -0.52, 0.0), entry[3] as Color, 0.92)


func _spawn_ship(
	scene: PackedScene,
	display_name: String,
	spawn_position: Vector3,
	spawn_scale: Vector3,
	energy_color: Color,
	accent_color: Color,
	evolution_level: float,
	circuit_amount: float,
	heat_amount: float,
	apex_amount: float,
	phase_offset: float
) -> Node3D:
	var ship := scene.instantiate() as Node3D
	ship.name = display_name
	ship.position = spawn_position
	ship.scale = spawn_scale
	fleet.add_child(ship)
	_apply_ship_materials(
		ship,
		energy_color,
		accent_color,
		evolution_level,
		circuit_amount,
		heat_amount,
		apex_amount,
		phase_offset
	)
	_animated_models.append(ship)
	return ship


func _apply_ship_materials(
	root: Node3D,
	energy_color: Color,
	accent_color: Color,
	evolution_level: float,
	circuit_amount: float,
	heat_amount: float,
	apex_amount: float,
	phase_offset: float
) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	for mesh_instance in meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index)
			var shader_material := ShaderMaterial.new()
			shader_material.shader = SHIP_SHADER

			var base_color := Color(0.18, 0.24, 0.34)
			var metallic := 0.55
			var roughness := 0.30
			var surface_emission := 0.0
			if source is BaseMaterial3D:
				var source_3d := source as BaseMaterial3D
				base_color = source_3d.albedo_color
				metallic = source_3d.metallic
				roughness = source_3d.roughness
				if source_3d.emission_enabled:
					surface_emission = 1.45

			shader_material.set_shader_parameter("base_color", base_color)
			shader_material.set_shader_parameter("energy_color", energy_color)
			shader_material.set_shader_parameter("accent_color", accent_color)
			shader_material.set_shader_parameter("metallic", metallic)
			shader_material.set_shader_parameter("roughness", roughness)
			shader_material.set_shader_parameter("evolution_level", evolution_level)
			shader_material.set_shader_parameter("circuit_amount", circuit_amount)
			shader_material.set_shader_parameter("heat_amount", heat_amount)
			shader_material.set_shader_parameter("apex_amount", apex_amount)
			shader_material.set_shader_parameter(
				"emission_strength",
				0.58 + evolution_level * 0.72 + surface_emission
			)
			shader_material.set_shader_parameter("phase_offset", phase_offset)
			mesh_instance.set_surface_override_material(surface_index, shader_material)

		var outline := MeshInstance3D.new()
		outline.name = "%s_NeonOutline" % mesh_instance.name
		outline.mesh = mesh_instance.mesh
		outline.transform = mesh_instance.transform
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var outline_material := ShaderMaterial.new()
		outline_material.shader = OUTLINE_SHADER
		outline_material.set_shader_parameter("outline_color", energy_color)
		outline_material.set_shader_parameter("outline_width", 0.026 + evolution_level * 0.016)
		outline_material.set_shader_parameter("outline_energy", 1.35 + evolution_level)
		outline.material_override = outline_material
		mesh_instance.get_parent().add_child(outline)


func _collect_meshes(root: Node, output: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D:
		output.append(root as MeshInstance3D)
	for child in root.get_children():
		_collect_meshes(child, output)


func _add_engine_trails(ship: Node3D, color: Color, length: float) -> void:
	for x_offset in [-0.24, 0.24]:
		var trail := MeshInstance3D.new()
		trail.name = "EngineTrail"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.035, length)
		trail.mesh = mesh
		trail.position = Vector3(x_offset, -0.04, 1.22 + length * 0.5)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(color.r, color.g, color.b, 0.42)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.8
		trail.material_override = material
		ship.add_child(trail)


func _add_target_ring(ring_position: Vector3, color: Color, radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "TargetRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.035
	mesh.outer_radius = radius
	mesh.rings = 32
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.position = ring_position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.45
	ring.material_override = material
	fleet.add_child(ring)


func _add_targeting_beam(beam_position: Vector3, length: float, color: Color) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "SniperTargetingBeam"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.025, length)
	beam.mesh = mesh
	beam.position = beam_position
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.68)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.5
	beam.material_override = material
	fleet.add_child(beam)


func _add_energy_bolt(bolt_position: Vector3, color: Color, length: float) -> void:
	var bolt := MeshInstance3D.new()
	bolt.name = "PlayerEnergyBolt"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.055
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 2
	bolt.mesh = mesh
	bolt.position = bolt_position
	bolt.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	bolt.material_override = material
	fleet.add_child(bolt)


func _set_floor_palette(blue: Color, violet: Color, pink: Color) -> void:
	var material := galaxy_floor.get_active_material(0) as ShaderMaterial
	if material != null:
		material.set_shader_parameter("nebula_blue", blue)
		material.set_shader_parameter("nebula_violet", violet)
		material.set_shader_parameter("nebula_pink", pink)


func _build_ui(mode: StringName) -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "MockupUI"
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var title := Label.new()
	title.position = Vector2(42.0, 28.0)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.45, 1.0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_ui_layer.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(44.0, 61.0)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.70, 0.88))
	_ui_layer.add_child(subtitle)

	match mode:
		&"evolution":
			title.text = "3D EVOLUTION SHADER // FOUR GENERATIONS"
			subtitle.text = "CURRENT CIRCUIT • HEAT VEIN • APEX INTERFERENCE LANGUAGE ON LOW-POLY HULLS"
			_add_evolution_labels()
		&"fleet":
			title.text = "FLEET MATERIAL STUDY // NEON 2.5D"
			subtitle.text = "AUTHORED GLB COLORWAYS + FRESNEL RIMS + SHADER-LOCKED CIRCUIT BUSES"
			_add_fleet_labels()
		_:
			title.text = "GAMEPLAY LOOK MOCKUP // 3D SHIPS"
			subtitle.text = "GALACTIC STARFIELD • EMISSIVE OUTLINES • PROJECTILE GLOW • CRT SCANLINES"
			_add_gameplay_labels()

	var footer := Label.new()
	footer.position = Vector2(43.0, 682.0)
	footer.text = "FARINUFF FLIGHT  /  IN-ENGINE LOOK DEVELOPMENT  /  GLB SOURCE ASSETS UNCHANGED"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.30, 0.53, 0.70))
	_ui_layer.add_child(footer)


func _add_gameplay_labels() -> void:
	_add_badge(Vector2(535.0, 584.0), "PLAYER // CYAN ENERGY", CYAN)
	_add_badge(Vector2(120.0, 122.0), "GEN I // REDJACK", RED)
	_add_badge(Vector2(536.0, 97.0), "GEN II // RAZOR", ORANGE)
	_add_badge(Vector2(946.0, 122.0), "GEN IV // LONGBOW", CYAN)


func _add_evolution_labels() -> void:
	var labels := [
		["GEN I", "SUBTLE BODY EMISSION", CYAN],
		["GEN II", "ANIMATED CIRCUIT BUSES", Color(0.18, 0.62, 1.0)],
		["GEN III", "REACTOR HEAT VEINS", ORANGE],
		["GEN IV", "APEX INTERFERENCE", MAGENTA],
	]
	var positions := [Vector2(78.0, 555.0), Vector2(370.0, 555.0), Vector2(665.0, 555.0), Vector2(960.0, 555.0)]
	for index in range(labels.size()):
		var entry: Array = labels[index]
		_add_badge(positions[index], "%s // %s" % [entry[0], entry[1]], entry[2] as Color)


func _add_fleet_labels() -> void:
	var labels := [
		["STARLANCE", CYAN],
		["REDJACK", RED],
		["RAZOR", ORANGE],
		["MANTIS", LIME],
		["BULWARK", VIOLET],
		["LONGBOW", CYAN],
	]
	var positions := [
		Vector2(118.0, 244.0),
		Vector2(541.0, 244.0),
		Vector2(970.0, 244.0),
		Vector2(118.0, 594.0),
		Vector2(541.0, 594.0),
		Vector2(970.0, 594.0),
	]
	for index in range(labels.size()):
		var entry: Array = labels[index]
		_add_badge(positions[index], entry[0] as String, entry[1] as Color)


func _add_badge(position: Vector2, text: String, color: Color) -> void:
	var badge := Label.new()
	badge.position = position
	badge.text = "  %s  " % text
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.9))
	badge.add_theme_constant_override("outline_size", 4)
	_ui_layer.add_child(badge)


func _build_crt_overlay() -> void:
	_crt_layer = CanvasLayer.new()
	_crt_layer.name = "CRTOverlay"
	_crt_layer.layer = 20
	add_child(_crt_layer)
	var overlay := ColorRect.new()
	overlay.name = "Scanlines"
	overlay.position = Vector2.ZERO
	overlay.size = get_viewport().get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = CRT_SHADER
	material.set_shader_parameter("apply_distortion", false)
	material.set_shader_parameter("aberration_strength", 0.0014)
	material.set_shader_parameter("scanline_intensity", 0.13)
	material.set_shader_parameter("scanline_count", 240.0)
	material.set_shader_parameter("vignette_strength", 0.34)
	material.set_shader_parameter("contrast", 1.08)
	material.set_shader_parameter("brightness", 1.02)
	overlay.material = material
	_crt_layer.add_child(overlay)


func _capture_mockup() -> void:
	var image := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(
		"%sshader_3d_%s_mockup.png" % [CAPTURE_ROOT, _mode]
	)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save shader 3D mockup: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("CODEX_SHADER_3D_CAPTURE_PASS: %s" % output_path)
	get_tree().quit()


func _run_smoke_check() -> void:
	var mesh_count := _count_type(fleet, MeshInstance3D)
	var shader_surface_count := 0
	for child in fleet.get_children():
		if child is Node3D:
			var meshes: Array[MeshInstance3D] = []
			_collect_meshes(child, meshes)
			for mesh_instance in meshes:
				if mesh_instance.name.ends_with("_NeonOutline"):
					continue
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					if mesh_instance.get_surface_override_material(surface_index) is ShaderMaterial:
						shader_surface_count += 1
	if mesh_count < 8 or shader_surface_count < 4:
		push_error(
			"Shader mockup validation failed: %d meshes, %d shader surfaces"
			% [mesh_count, shader_surface_count]
		)
		get_tree().quit(1)
		return
	print(
		"CODEX_SHADER_3D_MOCKUP_PASS: %s mode, %d meshes, %d shader surfaces"
		% [_mode, mesh_count, shader_surface_count]
	)
	get_tree().quit()


func _count_type(root: Node, node_type: Variant) -> int:
	var count := 1 if is_instance_of(root, node_type) else 0
	for child in root.get_children():
		count += _count_type(child, node_type)
	return count
