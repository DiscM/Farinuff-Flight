extends Node3D
## A peaceful, non-banking flight space. Deliberately owns no combat managers.

const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const ShipMotion := preload("res://effects/ship_motion_3d.gd")
const ShipMaterials := preload("res://effects/rendering/frontier_ship_materials.gd")
const Ribbons := preload("res://effects/engine_ribbons_3d.gd")
const Sections := preload("res://systems/home_port_sections.gd")
const ModalFocus := preload("res://ui/shared/modal_focus.gd")
const HarborVisuals := preload("res://systems/crescent_harbor_visuals.gd")
const Layout := preload("res://systems/crescent_harbor_layout.gd")
const SHIPS := {
	"ship_swallowtail": "res://assets/models/animated/player_butterfly.glb",
	"ship_interceptor": "res://assets/models/animated/player_butterfly_morpho.glb",
	"ship_bulwark": "res://assets/models/animated/player_butterfly_monarch.glb",
}
const DOCK_POSITION := Layout.DOCK_POSITION
const DOCK_RADIUS := Sections.INTERACTION_RADIUS
const FLIGHT_RADIUS := Layout.FLIGHT_RADIUS
const INITIAL_POSITION := Layout.INITIAL_POSITION
const INITIAL_ZOOM := 220.0
const MIN_ZOOM := 130.0
const MAX_ZOOM := 260.0
const CRUISE_SPEED := FlightTuning.SPEED / 15.0
const BOOST_SPEED := FlightTuning.BOOST_SPEED / 15.0
const CAMERA_OFFSET := Vector3(150.0, 180.0, 200.0) * 1.4


class PilotLocator extends Node2D:
	## Four quiet corners remain visible when the ship passes behind the station.
	func _draw() -> void:
		var cyan := Color(0.49, 0.94, 1.0, 0.88)
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				var corner := Vector2(x, y) * 12.0
				draw_line(corner, corner - Vector2(x * 5.0, 0.0), cyan, 1.35, true)
				draw_line(corner, corner - Vector2(0.0, y * 5.0), cyan, 1.35, true)

var player: Node3D
var station: Node3D
var camera: Camera3D
var hud: Control
var world: Node3D
var velocity := Vector3.ZERO
var heading := Vector3.FORWARD
var is_boosting := false
var _boost_released := true
var is_docked := false
var _menu_open := false
var _leaving := false
var _elapsed := 0.0
var _zoom := INITIAL_ZOOM
var _camera_target := Vector3.ZERO
var _motion: ShipMotion
var _ribbons: Ribbons
var _engine_left: Marker3D
var _engine_right: Marker3D
var _left_authored: Node3D
var _right_authored: Node3D
var _traffic: Array[Dictionary] = []
var _harbor_visuals: HarborVisuals
var _dock_material: StandardMaterial3D
var _sky_material: ShaderMaterial
var _previous_hdr := false
var _hud_clock := 0.0
var _pilot_locator: PilotLocator
var _section_signs: Array[Dictionary] = []
var _active_section: Dictionary = {}
var _navigation_target: StringName = &"launch_bay"
var _services: CanvasLayer
var _selected_ship := ""
var _quit_layer: CanvasLayer
var _previous_auto_accept_quit := true
var _quit_focus: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.is_game_active = false
	_previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_previous_hdr = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_build_environment()
	_build_station()
	_build_player()
	_build_camera()
	_build_pilot_locator()
	_build_navigation()
	_build_hud()
	_services = load("res://ui/home_base_services.gd").new()
	_services.name = "StationServices"
	add_child(_services)
	_services.closed.connect(_close_service)
	if DisplayServer.get_name() != "headless":
		get_window().focus_exited.connect(_pause_for_interruption)
	InputBindings.active_gamepad_disconnected.connect(_pause_for_interruption)
	InputBindings.bindings_changed.connect(_reset_input)
	_refresh_hud()
	_consume_return_request.call_deferred()


func _build_environment() -> void:
	var background := CanvasLayer.new()
	background.name = "DeepSpace"
	background.layer = -10
	background.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(background)
	var field := ColorRect.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = preload("res://effects/shaders/galactic_starfield.gdshader")
	_sky_material.set_shader_parameter("space_color", Color("030911"))
	_sky_material.set_shader_parameter("nebula_blue", Color("163a48"))
	_sky_material.set_shader_parameter("nebula_violet", Color("26243f"))
	_sky_material.set_shader_parameter("nebula_pink", Color("425061"))
	_sky_material.set_shader_parameter("nebula_strength", 0.28)
	_sky_material.set_shader_parameter("star_brightness", 0.72)
	_sky_material.set_shader_parameter("drift_speed", 0.004)
	field.material = _sky_material
	background.add_child(field)
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
	_build_distant_stars()


func _build_distant_stars() -> void:
	# One draw surface provides subtle world-space parallax below the flyable plane.
	var material := _emissive_material(Color("98bbc9"), 0.8)
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


func _build_station() -> void:
	_harbor_visuals = HarborVisuals.new()
	_harbor_visuals.name = "CrescentHarbor"
	_harbor_visuals.scale = Vector3.ONE * Sections.STATION_SCALE
	_harbor_visuals.position = Layout.MODEL_OFFSET
	world.add_child(_harbor_visuals)
	station = _harbor_visuals.load_harbor()
	if station == null:
		return
	for root: Node3D in _harbor_visuals.get_authored_roots().values():
		if str(root.name).begins_with("Ship_") and int(str(root.name).get_slice("_", 1)) in range(5, 14):
			_traffic.append({"node": root})


func _build_player() -> void:
	player = Node3D.new()
	player.name = "Pilot"
	player.position = INITIAL_POSITION
	world.add_child(player)
	var path: String = SHIPS.get(MetaProgression.selected_ship, SHIPS.ship_swallowtail)
	_selected_ship = MetaProgression.selected_ship
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = "Hull"
	player.add_child(model)
	ShipMaterials.apply(model)
	_motion = ShipMotion.new(model)
	_left_authored = model.find_child("Socket_EngineLeft", true, false) as Node3D
	_right_authored = model.find_child("Socket_EngineRight", true, false) as Node3D
	_engine_left = Marker3D.new()
	_engine_right = Marker3D.new()
	_engine_left.position = Vector3(-1.05, 0.08, 1.88)
	_engine_right.position = Vector3(1.05, 0.08, 1.88)
	player.add_child(_engine_left)
	player.add_child(_engine_right)
	_ribbons = Ribbons.new()
	_ribbons.name = "EngineWake"
	world.add_child(_ribbons)
	_ribbons.configure(_engine_left, _engine_right)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "HarborCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	camera.near = 0.1
	camera.far = 650.0
	world.add_child(camera)
	_camera_target = _overview_target() + (player.position - Layout.FLIGHT_CENTER) * _camera_follow_factor()
	camera.position = _camera_target + CAMERA_OFFSET
	camera.look_at(_camera_target)
	camera.make_current()


func _build_pilot_locator() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PilotLocatorLayer"
	layer.layer = 5
	layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(layer)
	_pilot_locator = PilotLocator.new()
	_pilot_locator.name = "PilotPosition"
	layer.add_child(_pilot_locator)
	_update_pilot_locator()
	get_viewport().size_changed.connect(_update_pilot_locator)


func _build_navigation() -> void:
	_dock_material = _emissive_material(Color("58e8da"), 1.8)
	var sign_layer := CanvasLayer.new()
	sign_layer.name = "StationSigns"
	sign_layer.layer = 6
	add_child(sign_layer)
	for index in Sections.SECTIONS.size():
		var section: Dictionary = Sections.SECTIONS[index]
		var color: Color = section.color
		var material := _emissive_material(color, 1.5)
		var berth := Node3D.new()
		berth.name = str(section.id).to_pascal_case() + "Berth"
		berth.position = section.position
		world.add_child(berth)
		# Holographic corners mark the service approach, clear of the station hull.
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				_box(berth, Vector3(x * 7.5, 0.3, z * 6.0), Vector3(0.45, 0.3, 3), material)
				_box(berth, Vector3(x * 6.0, 0.3, z * 7.5), Vector3(3, 0.3, 0.45), material)
		var placard := PanelContainer.new()
		placard.name = str(section.id).to_pascal_case() + "Sign"
		placard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.012, 0.026, 0.043, 0.90)
		style.border_color = color.darkened(0.35)
		style.set_border_width_all(1)
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		placard.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "%02d  /  %s" % [index + 1, section.title]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("e0eef2"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placard.add_child(label)
		sign_layer.add_child(placard)
		_section_signs.append({"section": section, "node": placard, "style": style})
	_update_section_signs()


func _update_section_signs() -> void:
	var frame := get_viewport().get_visible_rect().grow(-10)
	for entry in _section_signs:
		var placard: PanelContainer = entry.node
		var section: Dictionary = entry.section
		var point: Vector3 = section.position
		var projected := camera.unproject_position(point + Vector3(0, 6, 0))
		placard.position = projected - Vector2(placard.size.x * 0.5, placard.size.y + 12)
		placard.visible = frame.has_point(projected) and not _menu_open and not (_services != null and _services.is_open())
		var selected: bool = section.id == _navigation_target
		var nearby: bool = not _active_section.is_empty() and section.id == _active_section.id and is_docked
		entry.style.border_color = section.color if selected or nearby else section.color.darkened(0.55)
		entry.style.set_border_width_all(2 if nearby else 1)
		placard.modulate.a = 1.0 if selected or nearby else 0.96


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HomeBaseHUD"
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = load("res://ui/home_base_hud.gd").new() as Control
	hud.name = "HarborHUD"
	layer.add_child(hud)
	hud.menu_requested.connect(func(): set_menu_open(true))
	hud.resume_requested.connect(func(): set_menu_open(false))
	hud.quit_requested.connect(request_quit)
	hud.interact_requested.connect(interact_with_section)
	hud.section_selected.connect(select_section)


func _physics_process(delta: float) -> void:
	if _leaving or get_tree().paused or player == null:
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var controls_focused := get_viewport().gui_get_focus_owner() != null
	if controls_focused:
		input_direction = Vector2.ZERO
	var boost_held := not controls_focused and Input.is_action_pressed("boost")
	step_flight(input_direction, boost_held, delta)
	_update_visuals(delta)
	_update_camera(delta)
	_update_pilot_locator()
	_update_section_signs()
	_hud_clock += delta
	if _hud_clock >= 0.1:
		_hud_clock = 0.0
		_refresh_hud()


func step_flight(input_direction: Vector2, boost_held: bool, delta: float) -> void:
	# Camera projection affects heading only; neither zoom nor aspect alters speed.
	var direction := screen_direction_to_world(input_direction)
	# Wayfarer's boost bar is unlimited: hold to fly fast, with no meter and no
	# recharge. Combat keeps the consumable meter on Player3D.
	if not Input.is_action_pressed("boost"):
		_boost_released = true
	if boost_held and not is_boosting and not _boost_released:
		boost_held = false
	if boost_held and not is_boosting:
		_boost_released = false
	var boosting := boost_held
	if boosting and not is_boosting:
		if not direction.is_zero_approx():
			heading = direction.normalized()
		_ribbons.ignite()
		AudioManager.play_boost()
	is_boosting = boosting
	if boosting:
		if not direction.is_zero_approx():
			heading = heading.lerp(direction.normalized(), 1.0 - exp(-FlightTuning.BOOST_STEER_RATE * delta)).normalized()
		velocity = heading * BOOST_SPEED
	else:
		var rate: float = FlightTuning.DRAG if direction.is_zero_approx() else FlightTuning.ACCELERATION
		velocity = velocity.lerp(direction * CRUISE_SPEED, 1.0 - exp(-rate * delta))
		if not direction.is_zero_approx():
			heading = direction.normalized()
	var displacement := velocity * delta
	# Small swept increments keep boosts from tunnelling through station towers.
	var steps := maxi(1, ceili(displacement.length() / 1.0))
	for step in steps:
		player.position = constrain_flight_position(player.position + displacement / float(steps))
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-heading.x, -heading.z), 1.0 - exp(-delta * 13.0))
	_active_section = Sections.nearest(player.position)
	is_docked = player.position.distance_to(_active_section.position) <= DOCK_RADIUS
	_motion.set_boost(boosting)


func screen_direction_to_world(screen_direction: Vector2) -> Vector3:
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0.0
	down.y = 0.0
	return (right.normalized() * screen_direction.x + down.normalized() * screen_direction.y).limit_length()


func constrain_flight_position(point: Vector3) -> Vector3:
	var constrained := Layout.constrain(point)
	var correction := constrained - Vector3(point.x, 0.0, point.z)
	if not correction.is_zero_approx():
		var normal := correction.normalized()
		velocity -= normal * minf(velocity.dot(normal), 0.0)
	return constrained


func _update_visuals(delta: float) -> void:
	var reduced_motion := bool(SaveManager.get_setting("reduced_motion", false))
	_elapsed += delta
	_motion.advance(delta)
	if _left_authored != null:
		_engine_left.global_transform = ShipMotion.socket_transform(_left_authored)
	if _right_authored != null:
		_engine_right.global_transform = ShipMotion.socket_transform(_right_authored)
	_ribbons.advance(delta, velocity.length() / CRUISE_SPEED, is_boosting, true)
	_harbor_visuals.advance(delta, reduced_motion)
	_dock_material.emission_energy_multiplier = 1.8 if reduced_motion else 1.8 + sin(_elapsed * 1.8) * 0.25
	_sky_material.set_shader_parameter("u_time", 0.0 if reduced_motion else _elapsed)


func _update_camera(delta: float) -> void:
	var target := _overview_target() + (player.position - Layout.FLIGHT_CENTER) * _camera_follow_factor()
	var smooth := 1.0 - exp(-delta * 2.7)
	if not bool(SaveManager.get_setting("reduced_motion", false)):
		target += velocity * 0.12
	_camera_target = _camera_target.lerp(target, smooth)
	camera.position = _camera_target + CAMERA_OFFSET
	camera.size = lerpf(camera.size, _zoom, 1.0 - exp(-delta * 7.0))
	_keep_pilot_in_frame()


func _camera_follow_factor() -> float:
	# The overview holds the whole asymmetric port. Close zoom follows the pilot;
	# the screen margin handles travel to the perimeter without hiding the start view.
	return 0.22 * clampf((INITIAL_ZOOM - _zoom) / (INITIAL_ZOOM - MIN_ZOOM), 0.0, 1.0)


func _overview_target() -> Vector3:
	# Reserve the right-hand directory column while keeping the model large.
	var aspect := get_viewport().get_visible_rect().size.aspect()
	return Layout.CAMERA_TARGET + Vector3(0.8, 0.0, -0.6) * (_zoom * aspect * 0.10)


func _keep_pilot_in_frame() -> void:
	# Close zoom and narrow windows need a little more follow at the perimeter.
	# Keep the intended station framing everywhere else, including the arrival view.
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := Rect2(viewport_size * Vector2(0.055, 0.18), viewport_size * Vector2(0.89, 0.60))
	var projected := camera.unproject_position(player.global_position)
	var clamped := projected.clamp(safe.position, safe.end)
	if projected.is_equal_approx(clamped):
		return
	var target_point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(clamped), camera.project_ray_normal(clamped))
	if target_point is Vector3:
		var correction: Vector3 = player.global_position - target_point
		_camera_target += correction
		camera.position += correction


func _update_pilot_locator() -> void:
	if _pilot_locator == null or player == null or camera == null:
		return
	_pilot_locator.visible = true
	_pilot_locator.position = camera.unproject_position(player.global_position)


func adjust_zoom(change: float) -> void:
	_zoom = clampf(_zoom + change, MIN_ZOOM, MAX_ZOOM)


func _refresh_hud() -> void:
	if hud == null:
		return
	_active_section = Sections.nearest(player.position)
	var distance: float = player.position.distance_to(_active_section.position)
	is_docked = distance <= DOCK_RADIUS
	hud.set_active_section(_active_section, distance, is_docked)
	hud.set_flight_status(velocity.length(), player.position.distance_to(Layout.FLIGHT_CENTER))
	hud.set_boost_state(true, 1.0)
	var entries: Array = []
	for section in Sections.SECTIONS:
		var entry: Dictionary = section.duplicate()
		entry["distance"] = player.position.distance_to(section.position)
		entry["selected"] = section.id == _navigation_target
		entries.append(entry)
	hud.set_sections_status(entries)
	var target := Sections.find(_navigation_target)
	var navigation := "Fly to a named section and interact to enter."
	if not target.is_empty():
		navigation = "%s · %d m" % [target.title, ceili(player.position.distance_to(target.position))]
	if player.position.distance_to(Layout.FLIGHT_CENTER) >= FLIGHT_RADIUS - 16.0:
		navigation = "HARBOR PERIMETER · turn toward the station"
	elif not SaveManager.has_seen_flight_school and not is_docked:
		navigation += " · New pilot? Visit Flight School."
	hud.set_navigation_hint(navigation)
	_update_section_signs()


func select_section(section_id: StringName) -> void:
	if Sections.find(section_id).is_empty():
		return
	_navigation_target = section_id
	get_viewport().gui_release_focus()
	_refresh_hud()


func interact_with_section() -> void:
	# Recheck distance on the press, rather than trusting a tenth-second-old HUD.
	if _menu_open or _leaving or _services.is_open():
		return
	_active_section = Sections.nearest(player.position)
	if player.position.distance_to(_active_section.position) > DOCK_RADIUS:
		return
	open_service(_active_section.id)


func _input(event: InputEvent) -> void:
	if _leaving or _menu_open or _services.is_open() or is_instance_valid(_quit_layer):
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if _is_flight_event(event):
		# Input keeps action state even when an event is handled. Prevent the GUI
		# from stealing a remapped Tab/A before the flight tick reads that state.
		get_viewport().set_input_as_handled()
		return
	var service_event: InputEvent = hud.get_service_event(InputBindings.event_family(event))
	if service_event != null and event.is_pressed() and not event.is_echo() and service_event.is_match(event):
		interact_with_section()
		get_viewport().set_input_as_handled()


func _is_flight_event(event: InputEvent) -> bool:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "boost"]:
		if event.is_action(action):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _services.is_open() or is_instance_valid(_quit_layer):
		return
	if not _menu_open and event.is_action_pressed("ui_cancel") and get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()
		return
	if InputBindings.is_pause_event(event) or (_menu_open and event.is_action_pressed("ui_cancel")):
		if event.is_echo():
			return
		set_menu_open(not _menu_open)
		get_viewport().set_input_as_handled()
		return
	if _menu_open:
		return
	if _is_flight_event(event):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			adjust_zoom(-8.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 8.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_MINUS, KEY_EQUAL]:
			adjust_zoom(8.0 if event.physical_keycode == KEY_MINUS else -8.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			adjust_zoom(8.0 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else -8.0)
			get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	if _leaving or _menu_open == open or _services.is_open() or is_instance_valid(_quit_layer):
		return
	_menu_open = open
	get_tree().paused = open
	_reset_input()
	hud.set_menu_open(open)
	_update_section_signs()


func _pause_for_interruption() -> void:
	set_menu_open(true)


func _reset_input() -> void:
	is_boosting = false
	_boost_released = false
	velocity = Vector3.ZERO
	if _ribbons != null:
		_ribbons.reset()


func open_service(page: StringName) -> void:
	if _leaving or _services.is_open() or Sections.find(page).is_empty():
		return
	_menu_open = false
	hud.set_menu_open(false)
	_reset_input()
	hud.hide()
	get_tree().paused = true
	_services.open_service(page, {"first_flight": not SaveManager.has_seen_flight_school})
	_update_section_signs()


func _close_service() -> void:
	get_tree().paused = false
	hud.show()
	get_viewport().gui_release_focus()
	_reset_input()
	if _selected_ship != MetaProgression.selected_ship:
		var position_before := player.position
		var rotation_before := player.rotation
		world.remove_child(player)
		player.queue_free()
		world.remove_child(_ribbons)
		_ribbons.queue_free()
		_build_player()
		player.position = position_before
		player.rotation = rotation_before
	_refresh_hud()


func _consume_return_request() -> void:
	var page: StringName = &""
	if GameManager.return_to_flight_school:
		page = &"flight_school"
	if GameManager.return_to_launch_bay:
		page = &"launch_bay"
	GameManager.return_to_flight_school = false
	GameManager.return_to_launch_bay = false
	if GameManager.has_meta(&"home_base_return_page"):
		var requested := StringName(GameManager.get_meta(&"home_base_return_page"))
		if not Sections.find(requested).is_empty():
			page = requested
		GameManager.remove_meta(&"home_base_return_page")
	if not SaveManager.has_seen_flight_school:
		_navigation_target = &"flight_school"
	if not page.is_empty():
		var section := Sections.find(page)
		player.position = section.position
		_navigation_target = page
		open_service(page)
	_refresh_hud()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		request_quit()


func request_quit() -> void:
	if is_instance_valid(_quit_layer) or _leaving:
		return
	_services.cancel_preparation()
	_reset_input()
	get_tree().paused = true
	_quit_layer = CanvasLayer.new()
	_quit_layer.layer = 100
	_quit_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_quit_layer)
	var dialog := preload("res://ui/shared/run_confirmation.gd").new()
	dialog.title = "Leave Wayfarer?"
	dialog.dialog_text = "Save your progress and settings, then close the game."
	dialog.confirm_text = "SAVE & QUIT"
	dialog.confirmed.connect(_attempt_quit)
	dialog.canceled.connect(_cancel_quit)
	_quit_layer.add_child(dialog)
	_focus_quit_dialog(dialog)


func _focus_quit_dialog(dialog: Control) -> void:
	# A canceled loading screen rebuilds its service on a deferred callback.
	# Wait for that callback before isolating focus in the quit decision.
	await get_tree().process_frame
	if not is_instance_valid(dialog) or not is_instance_valid(_quit_layer):
		return
	# The port restores flight/service focus after cancel; the generic dialog
	# must not try to focus an invoker while that invoker is suspended.
	dialog._return_focus = null
	_quit_focus = ModalFocus.suspend_outside(dialog)
	for button in dialog.find_children("*", "Button", true, false):
		if button.text == dialog.cancel_text:
			button.grab_focus()
			break


func _cancel_quit() -> void:
	ModalFocus.restore(_quit_focus)
	_quit_focus.clear()
	_quit_layer.queue_free()
	_quit_layer = null
	get_tree().paused = _menu_open or _services.is_open()
	if _menu_open:
		hud.focus_primary()
	elif _services.is_open():
		_services.frontend.call_deferred("_focus_page_primary")
	else:
		get_viewport().gui_release_focus()


func _attempt_quit() -> void:
	if SaveManager.save_before_quit():
		get_tree().quit()
		return
	_show_save_failure.call_deferred()


func _show_save_failure() -> void:
	var dialog := preload("res://ui/shared/run_confirmation.gd").new()
	dialog.title = "Progress could not be saved"
	dialog.dialog_text = SaveManager.get_storage_notice() + "\nYour game remains open. Check storage and retry."
	dialog.confirm_text = "RETRY SAVE"
	dialog.cancel_text = "RETURN TO STATION"
	dialog.confirmed.connect(_attempt_quit)
	dialog.canceled.connect(_cancel_quit)
	_quit_layer.add_child(dialog)


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _box(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = point
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _exit_tree() -> void:
	get_tree().auto_accept_quit = _previous_auto_accept_quit
	get_tree().paused = false
	get_viewport().use_hdr_2d = _previous_hdr
