extends "res://scenes/native_3d_run.gd"
## Crescent Harbor at its home-port scale, with the native encounter/run systems.

const HarborLayout := preload("res://systems/crescent_harbor_layout.gd")
const HarborVisuals := preload("res://systems/crescent_harbor_visuals.gd")

var harbor: HarborVisuals
var _harbor_sky: ShaderMaterial
var _harbor_time := 0.0


func _ready() -> void:
	await super._ready()
	_spawn_harbor_patrol()


func _configure_combat_presentation() -> void:
	super._configure_combat_presentation()
	$Backdrop.hide()
	$Backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	var landmarks := $World3D/FrontierLandmarks
	$World3D.remove_child(landmarks)
	landmarks.free()
	_harbor_sky = PortPresentation.build_backdrop(self, $World3D)
	harbor = HarborVisuals.new()
	harbor.name = "CrescentHarbor"
	harbor.scale = Vector3.ONE * HarborLayout.STATION_SCALE
	harbor.position = HarborLayout.MODEL_OFFSET
	$World3D.add_child(harbor)
	harbor.load_harbor()
	var center := Vector2(HarborLayout.FLIGHT_CENTER.x, HarborLayout.FLIGHT_CENTER.z)
	flight_space.arena_bounds_override = Rect2(center - Vector2.ONE * HarborLayout.FLIGHT_RADIUS, Vector2.ONE * HarborLayout.FLIGHT_RADIUS * 2.0)
	camera_rig.harbor_overview = true
	player.flight_constraint = _constrain_flight
	player.set_combat_position(HarborLayout.INITIAL_POSITION)


func _process(delta: float) -> void:
	super._process(delta)
	if harbor == null:
		return
	var reduced_motion := bool(SaveManager.get_setting("reduced_motion", false))
	_harbor_time += delta
	harbor.advance(delta, reduced_motion)
	_harbor_sky.set_shader_parameter("u_time", 0.0 if reduced_motion else _harbor_time)


func _constrain_flight(point: Vector3) -> Vector3:
	var constrained := HarborLayout.constrain(point)
	var correction := constrained - Vector3(point.x, 0.0, point.z)
	if not correction.is_zero_approx():
		var normal := correction.normalized()
		player.velocity -= normal * minf(player.velocity.dot(normal), 0.0)
	return constrained


func _spawn_harbor_patrol() -> void:
	if encounters == null or not encounters.started:
		return
	var right := camera_rig.view_pivot.basis.x
	var down := camera_rig.view_pivot.basis.z
	down.y = 0.0
	down = down.normalized()
	# The harbor arrival sits at the lower left of the overview. Patrol the open
	# approach above/right of it so all three enemies appear in the starting view.
	for offset in [Vector2(12.0, -30.0), Vector2(38.0, -50.0), Vector2(64.0, -35.0)]:
		var enemy := encounters.spawn_enemy(&"basic", 0, 0.5)
		if enemy != null:
			enemy.global_position = HarborLayout.constrain(HarborLayout.INITIAL_POSITION + right * offset.x + down * offset.y)
