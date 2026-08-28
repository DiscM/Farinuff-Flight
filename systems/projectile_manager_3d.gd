extends Node
class_name ProjectileManager3D
## Scene-owned native projectile policy around the shared ObjectPool.
## This first slice enables only Player Projectiles; enemy policy follows later.

signal player_projectile_hit(target: Area3D, combat_position: Vector3)

const Projectile := preload("res://entities/projectiles/player_projectile_3d.gd")
const PLAYER_PROJECTILE_SCENE := preload("res://entities/projectiles/player_projectile_3d.tscn")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")

@export_range(1, 128, 1) var player_pool_size: int = 64
@export_range(1, 16, 1) var warm_batch_size: int = 8

var is_ready := false
var _warming := false
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _combat_bounds := Rect2()
# Includes deferred returns until ObjectPool has actually made them available.
var _checked_out: Array[Projectile] = []
var _warmed_ids: Array[int] = []
var _shots_fired := 0
var _rejected_shots := 0
var _peak_active := 0
var _pool_growth := 0


func configure(flight_space: FlightSpace, active_parent: Node3D, idle_parent: Node3D) -> void:
	_flight_space = flight_space
	_active_parent = active_parent
	_idle_parent = idle_parent
	_refresh_bounds()
	get_viewport().size_changed.connect(_refresh_bounds)


func warm_player_pool() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[Projectile] = []
	for index in range(player_pool_size):
		var projectile := ObjectPool.acquire(PLAYER_PROJECTILE_SCENE, _active_parent) as Projectile
		if projectile == null:
			_warming = false
			return false
		projectile.configure_pool(_idle_parent)
		projectile.hit.connect(_on_projectile_hit)
		projectile.returned_to_pool.connect(_on_projectile_returned)
		projectile.prepare_visual_warmup()
		warm_nodes.append(projectile)
		_warmed_ids.append(projectile.get_instance_id())
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	# Warm the draw pipeline under the cover, not just resource/physics setup.
	# A covered/minimized window may stop drawing entirely. Force this one
	# transition-only frame instead of awaiting a post-draw signal indefinitely.
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	for index in range(warm_nodes.size()):
		warm_nodes[index].despawn()
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	_warming = false
	is_ready = true
	return true


func fire_player_projectile(combat_position: Vector3, direction: Vector3) -> void:
	if not is_ready or not GameManager.is_game_active:
		return
	# Never instantiate on first fire or grow a pool during combat. The normal
	# base weapon fits this budget; overload is observable and safely bounded.
	if _checked_out.size() >= _warmed_ids.size():
		_rejected_shots += 1
		return
	var projectile := ObjectPool.acquire(PLAYER_PROJECTILE_SCENE, _active_parent) as Projectile
	if projectile == null:
		return
	if not _warmed_ids.has(projectile.get_instance_id()):
		_pool_growth += 1
	var screen_direction := _flight_space.combat_motion_to_screen(direction).normalized()
	if screen_direction.is_zero_approx():
		screen_direction = Vector2.UP
	var projectile_velocity := _flight_space.screen_motion_to_combat(
		screen_direction * WeaponTuning.PROJECTILE_SPEED
	)
	_checked_out.append(projectile)
	projectile.pool_activate(combat_position, projectile_velocity, _combat_bounds)
	_shots_fired += 1
	_peak_active = maxi(_peak_active, _checked_out.size())


func _on_projectile_hit(target: Area3D, combat_position: Vector3) -> void:
	player_projectile_hit.emit(target, combat_position)


func _on_projectile_returned(projectile: Area3D) -> void:
	_checked_out.erase(projectile)


func _refresh_bounds() -> void:
	_combat_bounds = _flight_space.get_combat_bounds()
	for projectile in _checked_out:
		projectile.update_combat_bounds(_combat_bounds)


## Snapshot only on request, not a dictionary allocation per projectile/tick.
func get_metrics() -> Dictionary:
	var active := 0
	var armed := 0
	var step_usec := 0
	for projectile in _checked_out:
		if projectile.is_active:
			active += 1
			step_usec += projectile.last_step_usec
		if projectile.monitoring and not projectile.collision_shape.disabled:
			armed += 1
	return {
		"pool_size": _warmed_ids.size(),
		"active": active,
		"armed": armed,
		"returning": _checked_out.size() - active,
		"idle": _warmed_ids.size() - _checked_out.size(),
		"peak_active": _peak_active,
		"shots_fired": _shots_fired,
		"rejected_shots": _rejected_shots,
		"pool_growth_after_warmup": _pool_growth,
		"projectile_step_usec": step_usec,
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}
