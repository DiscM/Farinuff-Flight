extends Node
class_name NativeHazardManager3D
## Scene-owned bounded pools for native hostile ordnance. Seeker fragments,
## Bomber mines, and the mine's short-lived plasma field share the same
## manager so reset, telemetry, and pool growth remain observable together.

signal mine_detonated(combat_position: Vector3, is_cluster: bool, leaves_plasma: bool)

const Fragment := preload("res://entities/enemies/seeker_fragment_3d.gd")
const FRAGMENT_SCENE := preload("res://entities/enemies/seeker_fragment_3d.tscn")
const Mine := preload("res://entities/enemies/enemy_mine_3d.gd")
const MINE_SCENE := preload("res://entities/enemies/enemy_mine_3d.tscn")
const PlasmaField3DWrapper := preload("res://entities/enemies/plasma_field_3d.gd")
const PLASMA_FIELD_SCENE := preload("res://entities/enemies/plasma_field_3d.tscn")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(1, 32, 1) var fragment_pool_size: int = 6
@export_range(1, 32, 1) var mine_pool_size: int = 6
@export_range(1, 8, 1) var plasma_field_pool_size: int = 2
@export_range(1, 8, 1) var warm_batch_size: int = 4

var is_ready := false
var _warming := false
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _coordinator: SpecialAttackCoordinator
var _combat_bounds := Rect2()

var _checked_out_fragments: Array[Fragment] = []
var _checked_out_mines: Array[Mine] = []
var _checked_out_fields: Array[PlasmaField3DWrapper] = []
var _warmed_fragment_ids: Dictionary[int, bool] = {}
var _fragment_cap_ids: Dictionary[int, bool] = {}
var _warmed_mine_ids: Dictionary[int, bool] = {}
var _warmed_field_ids: Dictionary[int, bool] = {}
var _pool_growth := 0
var _fragment_pool_growth := 0
var _mine_pool_growth := 0
var _field_pool_growth := 0
var _payload_generation := 0
var _rejected := 0
var _spawned_fragments := 0
var _spawned_mines := 0
var _spawned_fields := 0


func _ready() -> void:
	add_to_group(&"native_3d_hazard_manager")


func configure(
	flight_space: FlightSpace,
	active_parent: Node3D,
	idle_parent: Node3D,
	shared_coordinator: SpecialAttackCoordinator = null
) -> void:
	_flight_space = flight_space
	_active_parent = active_parent
	_idle_parent = idle_parent
	_coordinator = shared_coordinator
	if _coordinator == null:
		_coordinator = SpecialAttackCoordinator.new()
		_coordinator.name = "NativeHazardCoordinator"
		add_child(_coordinator)
	_refresh_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_bounds):
		get_viewport().size_changed.connect(_refresh_bounds)


func warm_hazard_pool() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[Node] = []
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
		_checked_out_fragments.append(fragment)
		_warmed_fragment_ids[fragment.get_instance_id()] = true
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	for index in range(mine_pool_size):
		var mine := ObjectPool.acquire(MINE_SCENE, _active_parent) as Mine
		if mine == null:
			_warming = false
			return false
		mine.configure_pool(_idle_parent, _coordinator)
		if not mine.detonated.is_connected(_on_mine_detonated):
			mine.detonated.connect(_on_mine_detonated)
		if not mine.returned_to_pool.is_connected(_on_mine_returned):
			mine.returned_to_pool.connect(_on_mine_returned)
		mine.prepare_visual_warmup()
		warm_nodes.append(mine)
		_checked_out_mines.append(mine)
		_warmed_mine_ids[mine.get_instance_id()] = true
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	for index in range(plasma_field_pool_size):
		var field := ObjectPool.acquire(PLASMA_FIELD_SCENE, _active_parent) as PlasmaField3DWrapper
		if field == null:
			_warming = false
			return false
		field.configure_pool(_idle_parent, _coordinator)
		if not field.returned_to_pool.is_connected(_on_field_returned):
			field.returned_to_pool.connect(_on_field_returned)
		field.prepare_visual_warmup()
		warm_nodes.append(field)
		_checked_out_fields.append(field)
		_warmed_field_ids[field.get_instance_id()] = true
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	for index in range(warm_nodes.size()):
		var node := warm_nodes[index]
		if node.has_method("despawn"):
			node.despawn()
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	_warming = false
	is_ready = true
	return true


func spawn_seeker_fragment(spawn_position: Vector3, direction: Vector3) -> Fragment:
	if not is_ready or not GameManager.is_game_active or _checked_out_fragments.size() >= _warmed_fragment_ids.size():
		_rejected += 1
		return null
	if _coordinator == null or not _coordinator.request_hazard(&"seeker_fragment"):
		_rejected += 1
		return null
	var fragment := ObjectPool.acquire(FRAGMENT_SCENE, _active_parent) as Fragment
	if fragment == null:
		_coordinator.release_hazard(&"seeker_fragment")
		_rejected += 1
		return null
	if not _warmed_fragment_ids.has(fragment.get_instance_id()):
		_pool_growth += 1
		_fragment_pool_growth += 1
		_warmed_fragment_ids[fragment.get_instance_id()] = true
	fragment.configure_pool(_idle_parent)
	if not fragment.returned_to_pool.is_connected(_on_fragment_returned):
		fragment.returned_to_pool.connect(_on_fragment_returned)
	_checked_out_fragments.append(fragment)
	_fragment_cap_ids[fragment.get_instance_id()] = true
	if not fragment.pool_activate(_flight_space, spawn_position, direction, _combat_bounds):
		_checked_out_fragments.erase(fragment)
		_fragment_cap_ids.erase(fragment.get_instance_id())
		_coordinator.release_hazard(&"seeker_fragment")
		ObjectPool.release(fragment, _idle_parent)
		_rejected += 1
		return null
	_spawned_fragments += 1
	return fragment


func spawn_mine(
	spawn_position: Vector3,
	cluster: bool = false,
	leaves_plasma: bool = false
) -> Mine:
	if not is_ready or not GameManager.is_game_active or _checked_out_mines.size() >= _warmed_mine_ids.size():
		_rejected += 1
		return null
	if _coordinator == null or not _coordinator.request_hazard(&"mine"):
		_rejected += 1
		return null
	if cluster and not _coordinator.request_hazard(&"cluster_mine"):
		_coordinator.release_hazard(&"mine")
		_rejected += 1
		return null
	var mine := ObjectPool.acquire(MINE_SCENE, _active_parent) as Mine
	if mine == null:
		_release_mine_caps(cluster)
		_rejected += 1
		return null
	if not _warmed_mine_ids.has(mine.get_instance_id()):
		_pool_growth += 1
		_mine_pool_growth += 1
		_warmed_mine_ids[mine.get_instance_id()] = true
	mine.configure_pool(_idle_parent, _coordinator)
	if not mine.detonated.is_connected(_on_mine_detonated):
		mine.detonated.connect(_on_mine_detonated)
	if not mine.returned_to_pool.is_connected(_on_mine_returned):
		mine.returned_to_pool.connect(_on_mine_returned)
	_checked_out_mines.append(mine)
	if not mine.pool_activate(_flight_space, spawn_position, cluster, leaves_plasma, _combat_bounds):
		_checked_out_mines.erase(mine)
		_release_mine_caps(cluster)
		ObjectPool.release(mine, _idle_parent)
		_rejected += 1
		return null
	_spawned_mines += 1
	return mine


func spawn_plasma_field(spawn_position: Vector3) -> PlasmaField3DWrapper:
	if not is_ready or not GameManager.is_game_active or _checked_out_fields.size() >= _warmed_field_ids.size():
		_rejected += 1
		return null
	if _coordinator == null or not _coordinator.request_hazard(&"plasma_field"):
		_rejected += 1
		return null
	var field := ObjectPool.acquire(PLASMA_FIELD_SCENE, _active_parent) as PlasmaField3DWrapper
	if field == null:
		_coordinator.release_hazard(&"plasma_field")
		_rejected += 1
		return null
	if not _warmed_field_ids.has(field.get_instance_id()):
		_pool_growth += 1
		_field_pool_growth += 1
		_warmed_field_ids[field.get_instance_id()] = true
	field.configure_pool(_idle_parent, _coordinator)
	if not field.returned_to_pool.is_connected(_on_field_returned):
		field.returned_to_pool.connect(_on_field_returned)
	_checked_out_fields.append(field)
	if not field.pool_activate(spawn_position):
		_checked_out_fields.erase(field)
		_coordinator.release_hazard(&"plasma_field")
		ObjectPool.release(field, _idle_parent)
		_rejected += 1
		return null
	_spawned_fields += 1
	return field


func clear_hazards() -> void:
	cancel_pending_payloads()
	for fragment in _checked_out_fragments.duplicate():
		if is_instance_valid(fragment):
			fragment.despawn()
	for mine in _checked_out_mines.duplicate():
		if is_instance_valid(mine):
			mine.despawn()
	for field in _checked_out_fields.duplicate():
		if is_instance_valid(field):
			field.despawn()


func cancel_pending_payloads() -> void:
	_payload_generation += 1


func get_metrics() -> Dictionary:
	var fragment_active := _active_count(_checked_out_fragments)
	var mine_active := _active_count(_checked_out_mines)
	var field_active := _active_count(_checked_out_fields)
	return {
		# Keep the original fragment keys stable for the Basic Enemy review.
		"pool_size": _warmed_fragment_ids.size(),
		"active": fragment_active,
		"returning": _checked_out_fragments.size() - fragment_active,
		"idle": _warmed_fragment_ids.size() - _checked_out_fragments.size(),
		"fragment_active": fragment_active,
		"fragment_pool_growth_after_warmup": _fragment_pool_growth,
		"mine_pool_size": _warmed_mine_ids.size(),
		"mine_active": mine_active,
		"mine_returning": _checked_out_mines.size() - mine_active,
		"mine_idle": _warmed_mine_ids.size() - _checked_out_mines.size(),
		"mine_pool_growth_after_warmup": _mine_pool_growth,
		"field_pool_size": _warmed_field_ids.size(),
		"field_active": field_active,
		"field_returning": _checked_out_fields.size() - field_active,
		"field_idle": _warmed_field_ids.size() - _checked_out_fields.size(),
		"field_pool_growth_after_warmup": _field_pool_growth,
		"total_active": fragment_active + mine_active + field_active,
		"spawned": _spawned_fragments + _spawned_mines + _spawned_fields,
		"spawned_fragments": _spawned_fragments,
		"spawned_mines": _spawned_mines,
		"spawned_fields": _spawned_fields,
		"rejected": _rejected,
		"pool_growth_after_warmup": _pool_growth,
	}


func _on_mine_detonated(
	combat_position: Vector3,
	is_cluster: bool,
	leaves_plasma: bool
) -> void:
	mine_detonated.emit(combat_position, is_cluster, leaves_plasma)
	# Mine detonation may originate in an Area3D callback. Resolve its pooled
	# projectile/field payload after the current physics query flush.
	_resolve_mine_detonation.call_deferred(
		combat_position, is_cluster, leaves_plasma, _payload_generation
	)


func _resolve_mine_detonation(
	combat_position: Vector3,
	is_cluster: bool,
	leaves_plasma: bool,
	payload_generation: int
) -> void:
	if not GameManager.is_game_active or payload_generation != _payload_generation:
		return
	var projectile_manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager")
	if projectile_manager != null and projectile_manager.has_method("fire_enemy_projectile") and _flight_space != null:
		for index in range(8):
			var screen_direction := Vector2.from_angle(TAU * float(index) / 8.0)
			projectile_manager.fire_enemy_projectile(
				combat_position,
				_flight_space.input_to_combat_direction(screen_direction),
				165.0
			)
		if is_cluster:
			for index in range(4):
				var cluster_direction := Vector2.from_angle(PI * 0.25 + TAU * float(index) / 4.0)
				projectile_manager.fire_enemy_projectile(
					combat_position,
					_flight_space.input_to_combat_direction(cluster_direction),
					105.0
				)
	if leaves_plasma:
		spawn_plasma_field(combat_position)


func _on_fragment_returned(fragment: Fragment) -> void:
	_checked_out_fragments.erase(fragment)
	if _fragment_cap_ids.has(fragment.get_instance_id()):
		_fragment_cap_ids.erase(fragment.get_instance_id())
		if _coordinator != null and is_instance_valid(_coordinator):
			_coordinator.release_hazard(&"seeker_fragment")


func _on_mine_returned(mine: Mine) -> void:
	_checked_out_mines.erase(mine)


func _on_field_returned(field: PlasmaField3DWrapper) -> void:
	_checked_out_fields.erase(field)


func _release_mine_caps(cluster: bool) -> void:
	if _coordinator == null or not is_instance_valid(_coordinator):
		return
	_coordinator.release_hazard(&"mine")
	if cluster:
		_coordinator.release_hazard(&"cluster_mine")


func _active_count(nodes: Array) -> int:
	var active := 0
	for node in nodes:
		if node != null and bool(node.is_active):
			active += 1
	return active


func _refresh_bounds() -> void:
	if _flight_space == null or _flight_space.configuration == null:
		return
	_combat_bounds = _flight_space.get_combat_bounds(_flight_space.configuration.despawn_margin_pixels)
