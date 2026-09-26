extends RefCounted
## Shared camera, lighting and sky for the peaceful harbor and combat level.
const Layout := preload("res://systems/crescent_harbor_layout.gd")
const INITIAL_ZOOM := 220.0
const MIN_ZOOM := 130.0
const MAX_ZOOM := 260.0
const CAMERA_OFFSET := Vector3(150.0, 180.0, 200.0) * 1.4
const NEAR_CLIP := 0.1
const FAR_CLIP := 650.0


static func pilot_frame_correction(camera: Camera3D, pilot_position: Vector3) -> Vector3:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var safe := Rect2(viewport_size * Vector2(0.055, 0.18), viewport_size * Vector2(0.89, 0.60))
	var projected := camera.unproject_position(pilot_position)
	var clamped := projected.clamp(safe.position, safe.end)
	if projected.is_equal_approx(clamped):
		return Vector3.ZERO
	var target: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(clamped), camera.project_ray_normal(clamped))
	return pilot_position - target if target is Vector3 else Vector3.ZERO


static func overview_target(aspect: float, zoom: float = INITIAL_ZOOM) -> Vector3:
	return Layout.CAMERA_TARGET + Vector3(0.8, 0.0, -0.6) * (zoom * aspect * 0.10)


static func configure_camera(camera: Camera3D, target: Vector3, zoom: float = INITIAL_ZOOM) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.near = NEAR_CLIP
	camera.far = FAR_CLIP
	camera.position = target + CAMERA_OFFSET
	camera.look_at(target)


static func build_environment(owner: Node, world: Node3D) -> ShaderMaterial:
	build_lighting(world)
	return build_backdrop(owner, world)


static func build_backdrop(owner: Node, world: Node3D) -> ShaderMaterial:
	var background := CanvasLayer.new()
	background.name = "DeepSpace"
	background.layer = -10
	background.process_mode = Node.PROCESS_MODE_PAUSABLE
	owner.add_child(background)
	var field := ColorRect.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://effects/shaders/galactic_starfield.gdshader")
	sky_material.set_shader_parameter("space_color", Color("030911"))
	sky_material.set_shader_parameter("nebula_blue", Color("163a48"))
	sky_material.set_shader_parameter("nebula_violet", Color("26243f"))
	sky_material.set_shader_parameter("nebula_pink", Color("425061"))
	sky_material.set_shader_parameter("nebula_strength", 0.28)
	sky_material.set_shader_parameter("star_brightness", 0.72)
	sky_material.set_shader_parameter("drift_speed", 0.004)
	field.material = sky_material
	background.add_child(field)
	_build_distant_stars(world)
	return sky_material


static func build_lighting(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = -1
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9bacbd")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.32
	environment.glow_strength = 0.75
	environment.glow_hdr_threshold = 1.5
	var environment_node := WorldEnvironment.new()
	environment_node.environment = environment
	world.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.name = "WarmStarlight"
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("ffe5b8")
	key.light_energy = 1.8
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 600.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "BlueNebulaFill"
	fill.rotation_degrees = Vector3(-24, 145, 0)
	fill.light_color = Color("83c5ed")
	fill.light_energy = 0.75
	world.add_child(fill)


static func _build_distant_stars(world: Node3D) -> void:
	# One draw surface provides subtle world-space parallax below the flyable plane.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("98bbc9")
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	cube.material = material
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = cube
	mesh.instance_count = 380
	var random := RandomNumberGenerator.new()
	random.seed = 42217
	for index in mesh.instance_count:
		var size := random.randf_range(0.08, 0.27)
		var point := Vector3(random.randf_range(-240.0, 240.0), random.randf_range(-65.0, -26.0), random.randf_range(-230.0, 230.0))
		mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
		mesh.set_instance_color(index, Color.WHITE.lerp(Color("59879a"), random.randf()))
	var stars := MultiMeshInstance3D.new()
	stars.name = "ParallaxStars"
	stars.multimesh = mesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(stars)
