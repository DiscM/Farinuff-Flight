extends Node
class_name XPOrbManager3D
## Scene-owned bounded XP Orb policy around the shared ObjectPool. The
## manager routes the wrapper's local collection event to the existing global
## XP signal without adding a second progression authority.

signal xp_orb_collected(orb_value: int, combat_position: Vector3)

const XP_ORB_SCENE := preload("res://entities/collectibles/xp_orb_3d.tscn")
const XPOrb := preload("res://entities/collectibles/xp_orb_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const FrameWorkBudget := preload("res://systems/frame_work_budget.gd")

@export_range(1, 128, 1) var pool_size: int = 32
## Legacy inspector setting retained for scene compatibility. Warmup now yields
## from the shared elapsed-work budget instead of a fixed item count.
@export_range(1, 16, 1) var warm_batch_size: int = 8

var is_ready := false
var _warming := false
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _combat_bounds := Rect2()
var _checked_out: Array[XPOrb] = []
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


func warm_orb_pool() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[XPOrb] = []
	var budget := FrameWorkBudget.new()
	for index in range(pool_size):
		var orb := ObjectPool.acquire(XP_ORB_SCENE, _active_parent) as XPOrb
		if orb == null:
			_warming = false
			return false
		orb.configure_pool(_idle_parent)
		orb.collected.connect(_on_orb_collected.bind(orb))
		orb.returned_to_pool.connect(_on_orb_returned)
		orb.prepare_visual_warmup()
		warm_nodes.append(orb)
		_track_checkout(orb)
		_warmed_ids[orb.get_instance_id()] = true
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


func spawn_xp_orb(
	combat_position: Vector3,
	value: int,
	drift_direction: Vector3 = Vector3.BACK
) -> XPOrb:
	if not is_ready or not GameManager.is_game_active:
		return null
	if _checked_out.size() >= _warmed_ids.size():
		return null
	var orb := ObjectPool.acquire(XP_ORB_SCENE, _active_parent) as XPOrb
	if orb == null:
		return null
	if not _warmed_ids.has(orb.get_instance_id()):
		_pool_growth += 1
		_warmed_ids[orb.get_instance_id()] = true
	orb.configure_pool(_idle_parent)
	_track_checkout(orb)
	if not orb.pool_activate(_flight_space, combat_position, value, drift_direction, _combat_bounds):
		_untrack_checkout(orb)
		ObjectPool.release(orb, _idle_parent)
		return null
	return orb


func clear_orbs() -> void:
	for orb in _checked_out:
		if is_instance_valid(orb):
			orb.despawn()


func get_metrics() -> Dictionary:
	var active := 0
	for orb in _checked_out:
		if orb.is_active:
			active += 1
	return {
		"pool_size": _warmed_ids.size(),
		"active": active,
		"returning": _checked_out.size() - active,
		"idle": _warmed_ids.size() - _checked_out.size(),
		"collected": _collected,
		"pool_growth_after_warmup": _pool_growth,
	}


func _on_orb_collected(value: int, combat_position: Vector3, _orb: XPOrb) -> void:
	_collected += 1
	AudioManager.play_xp_orb()
	SignalBus.xp_orb_collected.emit(value)
	xp_orb_collected.emit(value, combat_position)


func _on_orb_returned(orb: Area3D) -> void:
	_untrack_checkout(orb as XPOrb)


func _track_checkout(orb: XPOrb) -> void:
	var instance_id := orb.get_instance_id()
	_checked_out_indices[instance_id] = _checked_out.size()
	_checked_out.append(orb)


func _untrack_checkout(orb: XPOrb) -> void:
	if orb == null:
		return
	var instance_id := orb.get_instance_id()
	if not _checked_out_indices.has(instance_id):
		return
	var index := int(_checked_out_indices[instance_id])
	var last_index := _checked_out.size() - 1
	if index != last_index:
		var last_orb := _checked_out[last_index]
		_checked_out[index] = last_orb
		_checked_out_indices[last_orb.get_instance_id()] = index
	_checked_out.pop_back()
	_checked_out_indices.erase(instance_id)


func _refresh_bounds() -> void:
	if _flight_space == null or _flight_space.configuration == null:
		return
	_combat_bounds = _flight_space.get_combat_bounds(_flight_space.configuration.despawn_margin_pixels)
