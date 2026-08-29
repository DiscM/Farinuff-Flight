extends Node
class_name NativeHazardManager3D
## Scene-owned bounded pool for rare native hostile ordnance.

const Fragment := preload("res://entities/enemies/seeker_fragment_3d.gd")
const FRAGMENT_SCENE := preload("res://entities/enemies/seeker_fragment_3d.tscn")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(1, 32, 1) var fragment_pool_size: int = 6
@export_range(1, 8, 1) var warm_batch_size: int = 4

var is_ready := false
var _warming := false
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _combat_bounds := Rect2()
var _checked_out: Array[Fragment] = []
var _warmed_ids: Dictionary[int, bool] = {}
var _pool_growth := 0
var _rejected := 0
var _spawned := 0


func _ready() -> void:
	add_to_group(&"native_3d_hazard_manager")


func configure(flight_space: FlightSpace, active_parent: Node3D, idle_parent: Node3D) -> void:
	_flight_space = flight_space
	_active_parent = active_parent
	_idle_parent = idle_parent
	_refresh_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_bounds):
		get_viewport().size_changed.connect(_refresh_bounds)


func warm_hazard_pool() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[Fragment] = []
	for index in range(fragment_pool_size):
		var fragment := ObjectPool.acquire(FRAGMENT_SCENE, _active_parent) as Fragment
		if fragment == null:
			_warming = false
			return false
		fragment.configure_pool(_idle_parent)
		if not fragment.returned_to_pool.is_connected(_on_fragment_returned):
			fragment.returned_to_pool.connect(_on_fragment_returned)
		fragment.prepare_visual_warmup()
		warm_nodes.append(fragment)
		_checked_out.append(fragment)
		_warmed_ids[fragment.get_instance_id()] = true
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
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


func spawn_seeker_fragment(spawn_position: Vector3, direction: Vector3) -> Fragment:
	if not is_ready or not GameManager.is_game_active or _checked_out.size() >= _warmed_ids.size():
		_rejected += 1
		return null
	var fragment := ObjectPool.acquire(FRAGMENT_SCENE, _active_parent) as Fragment
	if fragment == null:
		_rejected += 1
		return null
	if not _warmed_ids.has(fragment.get_instance_id()):
		_pool_growth += 1
		_warmed_ids[fragment.get_instance_id()] = true
	fragment.configure_pool(_idle_parent)
	if not fragment.returned_to_pool.is_connected(_on_fragment_returned):
		fragment.returned_to_pool.connect(_on_fragment_returned)
	_checked_out.append(fragment)
	if not fragment.pool_activate(_flight_space, spawn_position, direction, _combat_bounds):
		_checked_out.erase(fragment)
		ObjectPool.release(fragment, _idle_parent)
		_rejected += 1
		return null
	_spawned += 1
	return fragment


func clear_hazards() -> void:
	for fragment in _checked_out.duplicate():
		if is_instance_valid(fragment):
			fragment.despawn()


func get_metrics() -> Dictionary:
	var active := 0
	for fragment in _checked_out:
		if fragment.is_active:
			active += 1
	return {
		"pool_size": _warmed_ids.size(),
		"active": active,
		"returning": _checked_out.size() - active,
		"idle": _warmed_ids.size() - _checked_out.size(),
		"spawned": _spawned,
		"rejected": _rejected,
		"pool_growth_after_warmup": _pool_growth,
	}


func _on_fragment_returned(fragment: Fragment) -> void:
	_checked_out.erase(fragment)


func _refresh_bounds() -> void:
	if _flight_space == null or _flight_space.configuration == null:
		return
	_combat_bounds = _flight_space.get_combat_bounds(_flight_space.configuration.despawn_margin_pixels)
