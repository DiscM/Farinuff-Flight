extends Area3D
class_name TankPlate3D
## Native one-hit armor plate orbiting a Tank Enemy generation II-IV hull.
## The wrapper owns only the plate's visual, collision, and orbit state; the
## native projectile manager remains the sole Player Projectile hit router.

signal destroyed(combat_position: Vector3)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(0.0, 180.0, 1.0) var orbit_speed_degrees: float = 40.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var plate_mesh: MeshInstance3D = $Visuals/PlateMesh

var is_active := false
var orbit_angle := 0.0
var orbit_radius_pixels := 43.0

var _tank: Node3D
var _flight_space: FlightSpace
var _plate_material: StandardMaterial3D
var _base_color := Color.WHITE


func _ready() -> void:
	# Plates are scene-authored children of the Tank wrapper and remain inert
	# until a generation II-IV Tank explicitly configures them.
	var source_material := plate_mesh.get_active_material(0) as StandardMaterial3D
	if source_material != null:
		_plate_material = source_material.duplicate() as StandardMaterial3D
		plate_mesh.material_override = _plate_material
		_base_color = _plate_material.albedo_color
	set_physics_process(false)
	_disable_collision_immediately()
	visible = false


func configure(
	tank: Node3D,
	flight_space: FlightSpace,
	initial_angle: float,
	radius_pixels: float
) -> bool:
	if tank == null or flight_space == null or flight_space.configuration == null:
		push_error("TankPlate3D requires a Tank parent and configured FlightSpace3D")
		return false
	_tank = tank
	_flight_space = flight_space
	orbit_angle = initial_angle
	orbit_radius_pixels = radius_pixels
	_set_plate_alpha(1.0)
	is_active = true
	_set_collision_active(true)
	set_physics_process(true)
	add_to_group(&"native_3d_enemy_armor")
	add_to_group(&"native_3d_tank_armor")
	show()
	_update_orbit_transform()
	return true


func deactivate() -> void:
	if not is_active and not visible:
		return
	is_active = false
	set_physics_process(false)
	remove_from_group(&"native_3d_enemy_armor")
	remove_from_group(&"native_3d_tank_armor")
	_set_collision_active(false)
	_tank = null
	_flight_space = null
	hide()


func _physics_process(delta: float) -> void:
	if not is_active or _tank == null or not is_instance_valid(_tank):
		deactivate()
		return
	if not _tank.get("is_active"):
		deactivate()
		return
	if not GameManager.is_game_active:
		return
	orbit_angle = wrapf(orbit_angle + deg_to_rad(orbit_speed_degrees) * delta, 0.0, TAU)
	_update_orbit_transform()
	var pulse := 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.006 + orbit_angle))
	_set_plate_alpha(pulse)


func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	var combat_position := get_combat_position()
	is_active = false
	set_physics_process(false)
	remove_from_group(&"native_3d_enemy_armor")
	remove_from_group(&"native_3d_tank_armor")
	hide()
	# The hit can arrive during a ShapeCast/physics flush. Defer only the
	# physics mutations; the logical state and public signal change now.
	_set_collision_active(false)
	destroyed.emit(combat_position)


func get_combat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func _update_orbit_transform() -> void:
	if _flight_space == null:
		return
	# Keep the orbit authored in baseline screen pixels. FlightSpace3D maps the
	# screen-space circle through the camera basis, preserving the reference
	# radius at every supported output resolution and camera foreshortening.
	var screen_offset := Vector2.from_angle(orbit_angle) * orbit_radius_pixels
	var combat_offset := _flight_space.screen_motion_to_combat(screen_offset)
	position = Vector3(combat_offset.x, 0.0, combat_offset.z)
	# The long axis follows the orbit tangent while the Tank's wrapper yaw is
	# inherited through the ArmorPlates attachment container.
	rotation.y = orbit_angle + PI * 0.5
	global_position.y = 0.0
	force_update_transform()


func _set_collision_active(active: bool) -> void:
	if active:
		collision_layer = PhysicsLayers.ENEMY_CRAFT
		collision_mask = PhysicsLayers.PLAYER_PROJECTILE
		monitoring = false
		monitorable = true
		collision_shape.disabled = false
	else:
		collision_shape.set_deferred("disabled", true)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)


func _disable_collision_immediately() -> void:
	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false


func _set_plate_alpha(alpha: float) -> void:
	if _plate_material == null:
		return
	var color := _base_color
	color.a = alpha
	_plate_material.albedo_color = color
