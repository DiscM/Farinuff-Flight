extends BasicEnemy3D
class_name TankEnemy3D
## Native Tank. The reference's slow straight entry and timed radial projectile
## bursts are retained; generation II-IV orbiting armor plates are native while
## double rings and overload remain deferred.

signal burst_fired(shot_count: int)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const Plate3D := preload("res://entities/enemies/tank_plate_3d.gd")
const TankStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const TANK_GENERATION_STATS := [
	preload("res://entities/enemies/tank_enemy_generation_1.tres"),
	preload("res://entities/enemies/tank_enemy_generation_2.tres"),
	preload("res://entities/enemies/tank_enemy_generation_3.tres"),
	preload("res://entities/enemies/tank_enemy_generation_4.tres"),
]

const FIRST_BURST_MIN_SECONDS := 0.5
const ARMOR_PLATE_COUNT := 3
const ARMOR_ORBIT_RADIUS_PIXELS := 43.0
const ARMOR_RADIUS_STEP_PIXELS := 3.0
const SHOT_SPEED_EVEN_PIXELS := 245.0
const SHOT_SPEED_ODD_PIXELS := 305.0
const SHOT_SPEED_VARIANCE_PIXELS := 8.0

signal armor_plate_destroyed(combat_position: Vector3, remaining_plates: int)

@export_range(1, 16, 1) var bullet_count: int = 8
@export_range(0.1, 10.0, 0.1) var burst_interval: float = 2.5

@onready var armor_plates_root: Node3D = $Attachments/ArmorPlates

var _burst_timer := 0.0
var _armor_plates: Array[Plate3D] = []


func _ready() -> void:
	super._ready()
	for child in armor_plates_root.get_children():
		var plate := child as Plate3D
		if plate == null:
			continue
		_armor_plates.append(plate)
		plate.destroyed.connect(_on_armor_plate_destroyed)


func activate_generation(
	flight_space: FlightSpace,
	combat_position: Vector3,
	direction: Vector3,
	generation_override: int
) -> bool:
	var activated := super.activate_generation(
		flight_space, combat_position, direction, generation_override
	)
	if activated:
		_configure_armor_plates()
	return activated


func _is_basic_lineage() -> bool:
	return false


func _get_generation_stats() -> TankStats:
	if generation == 1 and gameplay_stats != null:
		return gameplay_stats
	return TANK_GENERATION_STATS[generation - 1] as TankStats


func _configure_movement() -> void:
	super._configure_movement()
	_burst_timer = randf_range(FIRST_BURST_MIN_SECONDS, burst_interval)


func _configure_armor_plates() -> void:
	var plates_enabled := generation >= 2
	var radius := ARMOR_ORBIT_RADIUS_PIXELS + float(generation - 2) * ARMOR_RADIUS_STEP_PIXELS
	for index in _armor_plates.size():
		var plate := _armor_plates[index]
		if not is_instance_valid(plate):
			continue
		if not plates_enabled:
			plate.deactivate()
			continue
		plate.configure(self, _flight_space, TAU * float(index) / float(ARMOR_PLATE_COUNT), radius)


func get_armor_plates() -> Array[Plate3D]:
	return _armor_plates


func get_active_armor_plate_count() -> int:
	var active_count := 0
	for plate in _armor_plates:
		if is_instance_valid(plate) and plate.is_active:
			active_count += 1
	return active_count


func _finish(reason: FinishReason) -> void:
	for plate in _armor_plates:
		if is_instance_valid(plate):
			plate.deactivate()
	super._finish(reason)


func _on_armor_plate_destroyed(combat_position: Vector3) -> void:
	armor_plate_destroyed.emit(combat_position, get_active_armor_plate_count())


func _advance_movement(delta: float) -> void:
	super._advance_movement(delta)
	if not _is_inside_combat_view():
		return
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = burst_interval
		_fire_radial_burst()


func _is_inside_combat_view() -> bool:
	var bounds := _flight_space.get_combat_bounds()
	return bounds.has_point(Vector2(global_position.x, global_position.z))


func _fire_radial_burst() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	var muzzle := sockets.get_node_or_null("MuzzleCenter") as Marker3D
	if manager == null or not manager.is_ready or muzzle == null:
		return
	for index in range(bullet_count):
		var angle := (TAU / float(bullet_count)) * float(index)
		# Match the 2D reference's angle convention: angle zero travels down.
		var screen_direction := Vector2(sin(angle), cos(angle))
		var combat_direction := _flight_space.screen_motion_to_combat(screen_direction)
		var base_speed := SHOT_SPEED_EVEN_PIXELS if index % 2 == 0 else SHOT_SPEED_ODD_PIXELS
		var shot_speed := base_speed + randf_range(-SHOT_SPEED_VARIANCE_PIXELS, SHOT_SPEED_VARIANCE_PIXELS)
		manager.fire_enemy_projectile(muzzle.global_position, combat_direction, shot_speed)
	burst_fired.emit(bullet_count)
