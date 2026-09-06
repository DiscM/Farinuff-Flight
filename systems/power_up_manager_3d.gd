extends Node
class_name PowerUpManager3D
## Scene-owned bounded PowerUp3D policy around the shared ObjectPool. The
## manager keeps pickup lifetime/pool state local while collection remains
## authoritative through SignalBus.power_up_collected.

signal power_up_collected(power_up_type: int, combat_position: Vector3)

const POWER_UP_SCENE := preload("res://entities/powerups/power_up_3d.tscn")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const FrameWorkBudget := preload("res://systems/frame_work_budget.gd")

@export_range(1, 64, 1) var pool_size: int = 16
## Legacy inspector setting retained for scene compatibility. Warmup now yields
## from the shared elapsed-work budget instead of a fixed item count.
@export_range(1, 16, 1) var warm_batch_size: int = 8

var is_ready := false
var _warming := false
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _combat_bounds := Rect2()
var _checked_out: Array[PowerUp3D] = []
var _checked_out_indices: Dictionary[int, int] = {}
var _warmed_ids: Dictionary[int, bool] = {}
var _pool_growth := 0
var _spawned := 0
var _collected := 0
var _type_counts: Dictionary[int, int] = {}


func configure(flight_space: FlightSpace, active_parent: Node3D, idle_parent: Node3D) -> void:
	_flight_space = flight_space
	_active_parent = active_parent
	_idle_parent = idle_parent
	_refresh_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_bounds):
		get_viewport().size_changed.connect(_refresh_bounds)


func warm_power_up_pool() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[PowerUp3D] = []
	var budget := FrameWorkBudget.new()
	for index in range(pool_size):
		var power_up := ObjectPool.acquire(POWER_UP_SCENE, _active_parent) as PowerUp3D
		if power_up == null:
			_warming = false
			return false
		power_up.configure_pool(_idle_parent)
		power_up.collected.connect(_on_power_up_collected.bind(power_up))
		power_up.returned_to_pool.connect(_on_power_up_returned)
		power_up.prepare_visual_warmup()
		warm_nodes.append(power_up)
		_track_checkout(power_up)
		_warmed_ids[power_up.get_instance_id()] = true
		if budget.should_yield():
			await get_tree().process_frame
			budget.reset()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	budget.reset()
	for index in range(warm_nodes.size()):
		warm_nodes[index].despawn()
		if budget.should_yield():
			await get_tree().process_frame
			budget.reset()
	await get_tree().process_frame
	_warming = false
	is_ready = true
	return true


func spawn_power_up(
	combat_position: Vector3,
	power_up_type: int,
	drift_direction: Vector3 = Vector3.BACK
) -> PowerUp3D:
	if not is_ready or not GameManager.is_game_active:
		return null
	if _checked_out.size() >= _warmed_ids.size():
		return null
	var power_up := ObjectPool.acquire(POWER_UP_SCENE, _active_parent) as PowerUp3D
	if power_up == null:
		return null
	if not _warmed_ids.has(power_up.get_instance_id()):
		_pool_growth += 1
		_warmed_ids[power_up.get_instance_id()] = true
	power_up.configure_pool(_idle_parent)
	_track_checkout(power_up)
	if not power_up.pool_activate(_flight_space, combat_position, power_up_type, drift_direction, _combat_bounds):
		_untrack_checkout(power_up)
		ObjectPool.release(power_up, _idle_parent)
		return null
	_spawned += 1
	_type_counts[clampi(power_up_type, 0, 5)] = int(_type_counts.get(clampi(power_up_type, 0, 5), 0)) + 1
	return power_up


func clear_power_ups() -> void:
	for power_up in _checked_out:
		if is_instance_valid(power_up):
			power_up.despawn()


func get_metrics() -> Dictionary:
	var active := 0
	for power_up in _checked_out:
		if power_up.is_active:
			active += 1
	return {
		"pool_size": _warmed_ids.size(),
		"active": active,
		"returning": _checked_out.size() - active,
		"idle": _warmed_ids.size() - _checked_out.size(),
		"spawned": _spawned,
		"collected": _collected,
		"type_counts": _type_counts.duplicate(),
		"pool_growth_after_warmup": _pool_growth,
	}


func _on_power_up_collected(power_up_type: int, combat_position: Vector3, _power_up: PowerUp3D) -> void:
	_collected += 1
	power_up_collected.emit(power_up_type, combat_position)


func _on_power_up_returned(power_up: PowerUp3D) -> void:
	_untrack_checkout(power_up)


func _track_checkout(power_up: PowerUp3D) -> void:
	var instance_id := power_up.get_instance_id()
	_checked_out_indices[instance_id] = _checked_out.size()
	_checked_out.append(power_up)


func _untrack_checkout(power_up: PowerUp3D) -> void:
	if power_up == null:
		return
	var instance_id := power_up.get_instance_id()
	if not _checked_out_indices.has(instance_id):
		return
	var index := int(_checked_out_indices[instance_id])
	var last_index := _checked_out.size() - 1
	if index != last_index:
		var last_power_up := _checked_out[last_index]
		_checked_out[index] = last_power_up
		_checked_out_indices[last_power_up.get_instance_id()] = index
	_checked_out.pop_back()
	_checked_out_indices.erase(instance_id)


func _refresh_bounds() -> void:
	if _flight_space == null or _flight_space.configuration == null:
		return
	_combat_bounds = _flight_space.get_combat_bounds(_flight_space.configuration.despawn_margin_pixels)
