extends Node
class_name PickupPool3D

const IndexedNodes := preload("res://systems/indexed_nodes.gd")
## Shared bounded pickup lifecycle. Subclasses provide the pickup scene and
## collection policy; warmup and checkout accounting have one implementation.

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const FrameWorkBudget := preload("res://systems/frame_work_budget.gd")

@export_range(1, 128, 1) var pool_size: int = 32

var is_ready := false
var _warming := false
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _combat_bounds := Rect2()
var _checked_out: Array[Area3D] = []
var _checked_out_indices: Dictionary[int, int] = {}
var _warmed_ids: Dictionary[int, bool] = {}
var _pool_growth := 0
var _collected := 0


func configure(flight_space: FlightSpace, active_parent: Node3D, idle_parent: Node3D) -> void:
	_flight_space = flight_space
	_active_parent = active_parent
	_idle_parent = idle_parent
	_refresh_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_bounds):
		get_viewport().size_changed.connect(_refresh_bounds)


func warm_pool() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[Area3D] = []
	var budget := FrameWorkBudget.new()
	for index in range(pool_size):
		var pickup = ObjectPool.acquire(_pickup_scene(), _active_parent)
		if pickup == null:
			_warming = false
			return false
		pickup.configure_pool(_idle_parent)
		pickup.connect(&"collected", _on_pickup_collected)
		pickup.connect(&"returned_to_pool", _untrack_checkout)
		pickup.prepare_visual_warmup()
		warm_nodes.append(pickup)
		_track_checkout(pickup)
		_warmed_ids[pickup.get_instance_id()] = true
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


func _spawn_pickup(
	combat_position: Vector3,
	value: int,
	drift_direction: Vector3 = Vector3.BACK
) -> Area3D:
	if not is_ready or not GameManager.is_game_active:
		return null
	if _checked_out.size() >= _warmed_ids.size():
		return null
	var pickup = ObjectPool.acquire(_pickup_scene(), _active_parent)
	if pickup == null:
		return null
	if not _warmed_ids.has(pickup.get_instance_id()):
		_pool_growth += 1
		_warmed_ids[pickup.get_instance_id()] = true
	pickup.configure_pool(_idle_parent)
	_track_checkout(pickup)
	if not pickup.pool_activate(_flight_space, combat_position, value, drift_direction, _combat_bounds):
		_untrack_checkout(pickup)
		ObjectPool.release(pickup, _idle_parent)
		return null
	return pickup


func clear_pickups() -> void:
	for pickup in _checked_out:
		if is_instance_valid(pickup):
			pickup.despawn()


func get_metrics() -> Dictionary:
	var active := 0
	for pickup in _checked_out:
		if pickup.get("is_active"):
			active += 1
	return {
		"pool_size": _warmed_ids.size(),
		"active": active,
		"returning": _checked_out.size() - active,
		"idle": _warmed_ids.size() - _checked_out.size(),
		"collected": _collected,
		"pool_growth_after_warmup": _pool_growth,
	}


func _pickup_scene() -> PackedScene:
	return null


func _on_pickup_collected(_value: int, _combat_position: Vector3) -> void:
	_collected += 1


func _track_checkout(pickup: Area3D) -> void:
	IndexedNodes.add(pickup, _checked_out, _checked_out_indices)


func _untrack_checkout(pickup: Area3D) -> void:
	IndexedNodes.remove(pickup, _checked_out, _checked_out_indices)


func _refresh_bounds() -> void:
	if _flight_space == null or _flight_space.configuration == null:
		return
	if not _flight_space.bounds_changed.is_connected(_refresh_bounds):
		_flight_space.bounds_changed.connect(_refresh_bounds)
	_combat_bounds = _flight_space.get_combat_bounds(_flight_space.configuration.despawn_margin_pixels)
